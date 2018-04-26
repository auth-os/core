pragma solidity ^0.4.23;

import "../../../../../lib/MemoryBuffers.sol";
import "../../../../../lib/ArrayUtils.sol";

library CrowdsaleBuyTokens {

  using MemoryBuffers for uint;
  using ArrayUtils for bytes32[];
  using Exceptions for bytes32;

  /// CROWDSALE STORAGE ///

  // Whether the crowdsale and token are initialized, and the sale is ready to run
  bytes32 internal constant CROWDSALE_IS_INIT = keccak256("crowdsale_is_init");

  // Whether or not the crowdsale is post-purchase
  bytes32 internal constant CROWDSALE_IS_FINALIZED = keccak256("crowdsale_is_finalized");

  // Storage location of the crowdsale's start time
  bytes32 internal constant CROWDSALE_START_TIME = keccak256("crowdsale_start_time");

  // Storage location of the amount of tokens sold in the crowdsale so far. Does not include reserved tokens
  bytes32 internal constant CROWDSALE_TOKENS_SOLD = keccak256("crowdsale_tokens_sold");

  // Storage location of the minimum amount of tokens allowed to be purchased
  bytes32 internal constant CROWDSALE_MINIMUM_CONTRIBUTION = keccak256("crowdsale_min_cap");

  // Maps addresses to a boolean indicating whether or not this address has contributed
  // At its base location, stores the amount of unique contributors so far in this crowdsale
  bytes32 internal constant CROWDSALE_UNIQUE_CONTRIBUTORS = keccak256("crowdsale_contributors");

  // Storage location of a list of the tiers the crowdsale will have
  /* Each tier mimics the following struct:
  struct CrowdsaleTier {
    bytes32 _tier_name;                 // The name of the crowdsale tier
    uint _tier_token_sell_cap;          // The maximum number of tokens that will be sold during this tier
    uint _tier_purchase_price;          // The price of a token in wei for this tier
    uint _duration;                     // The amount of time this tier will be active for
    bool _tier_duration_is_modifiable;  // Whether the crowdsale admin is allowed to modify the duration of a tier before it goes live
    bool _tier_is_whitelist_enabled;    // Whether this tier of the crowdsale requires users to be on a purchase whitelist
  }
  */
  bytes32 internal constant CROWDSALE_TIERS = keccak256("crowdsale_tier_list");

  // Storage location of the CROWDSALE_TIERS index (-1) of the current tier. If zero, no tier is currently active
  bytes32 internal constant CROWDSALE_CURRENT_TIER = keccak256("crowdsale_current_tier");

  // Storage location of the end time of the current tier. Purchase attempts beyond this time will update the current tier (if another is available)
  bytes32 internal constant CURRENT_TIER_ENDS_AT = keccak256("crowdsale_tier_ends_at");

  // Storage location of the total number of tokens remaining for purchase in the current tier
  bytes32 internal constant CURRENT_TIER_TOKENS_REMAINING = keccak256("crowdsale_tier_tokens_remaining");

  // Storage location of team funds wallet
  bytes32 internal constant WALLET = keccak256("crowdsale_wallet");

  // Storage location of amount of wei raised during the crowdsale, total
  bytes32 internal constant WEI_RAISED = keccak256("crowdsale_wei_raised");

  // Storage seed for crowdsale whitelist mappings - maps each tier's index to a mapping of addresses to whtielist information
  /* Each whitelist entry mimics this struct:
  struct WhitelistListing {
    uint minimum_contribution;
    uint max_contribution;
  }
  */
  bytes32 internal constant SALE_WHITELIST = keccak256("crowdsale_purchase_whitelist");

  /// TOKEN STORAGE ///

  // Storage location for token decimals
  bytes32 internal constant TOKEN_DECIMALS = keccak256("token_decimals");

  // Storage location for token totalSupply
  bytes32 internal constant TOKEN_TOTAL_SUPPLY = keccak256("token_total_supply");

  // Storage seed for user balances mapping
  bytes32 internal constant TOKEN_BALANCES = keccak256("token_balances");

  /// FUNCTION SELECTORS ///

  // Function selector for storage 'readMulti'
  // readMulti(bytes32 exec_id, bytes32[] locations)
  bytes4 internal constant RD_MULTI = bytes4(keccak256("readMulti(bytes32,bytes32[])"));

  struct CrowdsaleTier {
    uint num_tiers;
    uint index;
    uint tokens_remaining;
    uint purchase_price;
    uint tier_ends_at;
    bool tier_is_whitelisted;
    bool updated_tier;
  }

  struct CrowdsaleInfo {
    address team_wallet;
    uint wei_raised;
    uint token_total_supply;
    uint tokens_sold;
    uint token_decimals;
    uint start_time;
    uint num_contributors;
    bool sender_has_contributed;
  }

  struct SpendInfo {
    uint sender_token_balance;
    uint minimum_purchase_amount;
    uint maximum_spend_amount;
    uint amount_purchased;
    uint amount_spent;
  }

  /*
  Allows the sender to purchase tokens from the crowdsale, if it is active

  @param _context: The execution context for this application - a 96-byte array containing (in order):
    1. Application execution id
    2. Original script sender (address, padded to 32 bytes)
    3. Wei amount sent with transaction to storage
  @return store_data: A formatted storage request - first 64 bytes designate a forwarding address (and amount) for any wei sent
  */
  function buy(bytes memory _context) public view returns (bytes32[] memory store_data) {
    // Get original sender address, execution id, and wei sent from context array
    address sender;
    bytes32 exec_id;
    uint wei_sent;
    (exec_id, sender, wei_sent) = parse(_context);
    // Ensure nonzero amount of wei sent
    if (wei_sent == 0)
      bytes32("NoWeiSent").trigger();

    /// Get information on the current tier of the crowdsale, and create CrowdsaleTier struct to hold the information -
    CrowdsaleTier memory cur_tier = getCurrentTier(exec_id);

    /// Read crowdsale information from storage -
    CrowdsaleInfo memory sale_stat;
    SpendInfo memory spend_stat;
    (sale_stat, spend_stat) = getCrowdsaleInfo(exec_id, sender, cur_tier);

    /// Get amount of wei able to be spent, and tokens able to be purchased -
    getPurchaseInfo(wei_sent, sale_stat, cur_tier, spend_stat);

    /// Amount to spend and amount of tokens to purchase have been calculated - prepare storage return buffer
    uint ptr = MemoryBuffers.stBuff(sale_stat.team_wallet, spend_stat.amount_spent);

    // Safely add to sender's token balance, and push their new balance along with their balance storage location
    require(spend_stat.amount_purchased + spend_stat.sender_token_balance > spend_stat.sender_token_balance);
    ptr.stPush(
      keccak256(keccak256(sender), TOKEN_BALANCES),
      bytes32(spend_stat.amount_purchased + spend_stat.sender_token_balance)
    );
    // Safely subtract amount purchased from tier tokens remaining -
    require(cur_tier.tokens_remaining >= spend_stat.amount_purchased);
    ptr.stPush(CURRENT_TIER_TOKENS_REMAINING, bytes32(cur_tier.tokens_remaining - spend_stat.amount_purchased));
    // Safely add to the crowdsale's total tokens sold
    require(sale_stat.tokens_sold + spend_stat.amount_purchased > sale_stat.tokens_sold);
    ptr.stPush(CROWDSALE_TOKENS_SOLD, bytes32(sale_stat.tokens_sold + spend_stat.amount_purchased));
    // Safely add tokens purchased to total token supply
    require(sale_stat.token_total_supply + spend_stat.amount_purchased > sale_stat.token_total_supply);
    ptr.stPush(TOKEN_TOTAL_SUPPLY, bytes32(sale_stat.token_total_supply + spend_stat.amount_purchased));
    // Safely add to crowdsale wei raised
    require(sale_stat.wei_raised + spend_stat.amount_spent > sale_stat.wei_raised);
    ptr.stPush(WEI_RAISED, bytes32(sale_stat.wei_raised + spend_stat.amount_spent));

    // If the sender had not previously contributed to the sale, push new unique contributor count and sender contributor status to buffer
    if (sale_stat.sender_has_contributed == false) {
      ptr.stPush(CROWDSALE_UNIQUE_CONTRIBUTORS, bytes32(sale_stat.num_contributors + 1));
      ptr.stPush(keccak256(keccak256(sender), CROWDSALE_UNIQUE_CONTRIBUTORS), bytes32(1));
    }

    // If this tier was whitelisted, update sender's whitelist spend caps
    if (cur_tier.tier_is_whitelisted) {
      ptr.stPush(keccak256(keccak256(sender), keccak256(cur_tier.index, SALE_WHITELIST)), 0);
      ptr.stPush(
        bytes32(32 + uint(keccak256(keccak256(sender), keccak256(cur_tier.index, SALE_WHITELIST)))),
        bytes32(spend_stat.maximum_spend_amount)
      );
    }

    // If this tier was updated, set storage 'current tier' information -
    if (cur_tier.updated_tier) {
      ptr.stPush(CROWDSALE_CURRENT_TIER, bytes32(cur_tier.index + 1));
      ptr.stPush(CURRENT_TIER_ENDS_AT, bytes32(cur_tier.tier_ends_at));
    }

    // Get bytes32[] representation of storage buffer
    store_data = ptr.getBuffer();
  }

  /*
  Reads from storage and returns information about the current crowdsale tier

  @param _exec_id: The execution id under which the crowdsale is registered
  @returns cur_tier: A struct representing the current tier of the crowdsale
  */
  function getCurrentTier(bytes32 _exec_id) internal view returns (CrowdsaleTier memory cur_tier) {
    // Create 'readMulti' calldata buffer in memory -
    uint ptr = MemoryBuffers.cdBuff(RD_MULTI);
    // Push exec id, data read offset, and read size to buffer
    ptr.cdPush(_exec_id);
    ptr.cdPush(0x40);
    ptr.cdPush(bytes32(5));
    // Push locations to read from storage: tier list length, and current tier information
    ptr.cdPush(CROWDSALE_TIERS);
    ptr.cdPush(CROWDSALE_CURRENT_TIER);
    ptr.cdPush(CURRENT_TIER_ENDS_AT);
    ptr.cdPush(CURRENT_TIER_TOKENS_REMAINING);
    ptr.cdPush(CROWDSALE_START_TIME);
    // Read from storage and convert returned array to uint[]
    uint[] memory tier_info = ptr.readMulti().toUintArr();
    // Ensure valid read size
    assert(tier_info.length == 5);

    // Check returned values -

    assert(tier_info[0] > 0 && tier_info[1] > 0); // Number of tiers cannot be 0, and current tier index cannot be 0
    // If the current tier index (offset by 1) is greater than the tier list length, the crowdsale has already finished
    if (tier_info[1] > tier_info[0])
      bytes32("CrowdsaleFinished").trigger();

    // Ensure the crowdsale has started -
    if (now < tier_info[4])
      bytes32("BeforeStartTime").trigger();

    // Create cur_tier return struct -
    cur_tier = CrowdsaleTier({
      num_tiers: tier_info[0],
      index: tier_info[1] - 1, // Tier index is offset by 1
      tokens_remaining: tier_info[3],
      purchase_price: 0,
      tier_ends_at: tier_info[2],
      tier_is_whitelisted: false,
      updated_tier: false
    });

    // If the current tier has ended, we need to update the current tier in storage
    if (now >= tier_info[2])
      updateTier(_exec_id, ptr, tier_info, cur_tier);
    else
      getTierInfo(_exec_id, ptr, tier_info, cur_tier);

    // Ensure current tier information is valid -
    if (
      cur_tier.index >= cur_tier.num_tiers     // Invalid tier index
      && cur_tier.purchase_price == 0          // Invalid purchase price
      && cur_tier.tier_ends_at <= now          // Invalid tier end time
    ) bytes32("InvalidIndexPriceOrEndTime").trigger();

    // If the current tier does not have tokens remaining, revert
    if (cur_tier.tokens_remaining == 0)
      bytes32("TierSoldOut").trigger();
  }

  /*
  Loads information about the current crowdsale tier into the CrowdsaleTier struct

  @param _exec_id: The execution id under which this crowdsale application is registered
  @param _ptr: A pointer to a buffer in memory
  @param _tier_info: An array containing information about the current tier in memory
  @param _cur_tier: A struct representing information about the current crowdsale tier
  */
  function getTierInfo(bytes32 _exec_id, uint _ptr, uint[] memory _tier_info, CrowdsaleTier memory _cur_tier) internal view {
    // Overwrite previous pointer and create 'readMulti' calldata buffer
    _ptr.cdOverwrite(RD_MULTI);
    // Push exec id, data read offset, and read size to calldata buffer
    _ptr.cdPush(_exec_id);
    _ptr.cdPush(0x40);
    _ptr.cdPush(bytes32(2));
    // Read current tier purchase price and whether or not it is whitlisted
    _ptr.cdPush(bytes32(96 + (192 * _cur_tier.index) + uint(CROWDSALE_TIERS))); // Purchase price location
    _ptr.cdPush(bytes32(192 + (192 * _cur_tier.index) + uint(CROWDSALE_TIERS))); // Current tier whitelist status location
    // Read from memory
    _tier_info = _ptr.readMulti().toUintArr();
    // Ensure correct return length
    assert(_tier_info.length == 2);

    // Place purchase price and whitelist status in struct
    if (_tier_info[0] == 0) // Purchase price must be over 0
      bytes32("InvalidPurchasePrice").trigger();

    _cur_tier.purchase_price = _tier_info[0];
    _cur_tier.tier_is_whitelisted = (_tier_info[1] == 0 ? false : true);
  }

  /*
  Takes an input CrowdsaleTier struct and updates it to reflect information about the latest tier

  @param _exec_id: The execution id under which this crowdsale application is registered
  @param _ptr: A pointer to a buffer in memory
  @param _tier_info: An array containing information about the current tier in memory
  @param _cur_tier: A struct representing information about the current crowdsale tier
  */
  function updateTier(bytes32 _exec_id, uint _ptr, uint[] memory _tier_info, CrowdsaleTier memory _cur_tier) internal view {
    // While the current timestamp is beyond the current tier's end time, and while the current tier's index is within a valid range:
    while (now >= _cur_tier.tier_ends_at && ++_cur_tier.index < _cur_tier.num_tiers) {
      // Overwrite current pointer and create new 'readMulti' calldata buffer
      _ptr.cdOverwrite(RD_MULTI);
      // Push exec id, data read offset, and read size to calldata buffer
      _ptr.cdPush(_exec_id);
      _ptr.cdPush(0x40);
      _ptr.cdPush(bytes32(4));
      // Push tier token sell cap storage location to buffer
      _ptr.cdPush(bytes32(64 + (192 * _cur_tier.index) + uint(CROWDSALE_TIERS)));
      // Push tier token price storage location to buffer
      _ptr.cdPush(bytes32(96 + (192 * _cur_tier.index) + uint(CROWDSALE_TIERS)));
      // Push tier duration storage location to buffer
      _ptr.cdPush(bytes32(128 + (192 * _cur_tier.index) + uint(CROWDSALE_TIERS)));
      // Push tier 'is-whitelisted' status storage location to buffer
      _ptr.cdPush(bytes32(192 + (192 * _cur_tier.index) + uint(CROWDSALE_TIERS)));
      // Read from storage and convert returned array to uint[]
      _tier_info = _ptr.readMulti().toUintArr();
      // Ensure correct return length
      assert(_tier_info.length == 4);
      // Ensure valid tier setup
      if (_tier_info[0] == 0 || _tier_info[1] == 0 || _tier_info[2] == 0)
        bytes32("InvalidTier").trigger();
      // Add returned duration to previous tier end time
      if (_cur_tier.tier_ends_at + _tier_info[2] <= _cur_tier.tier_ends_at)
        bytes32("TierDurationOverflow").trigger();

      _cur_tier.tier_ends_at += _tier_info[2];
    }
    // If the updated current tier's index is not in the valid range, or the end time is still in the past, throw
    if (now >= _cur_tier.tier_ends_at || _cur_tier.index >= _cur_tier.num_tiers)
      bytes32("CrowdsaleFinished").trigger();

    // Otherwise - update the CrowdsaleTier struct to reflect the actual current tier of the crowdsale
    _cur_tier.tokens_remaining = _tier_info[0];
    _cur_tier.purchase_price = _tier_info[1];
    _cur_tier.tier_is_whitelisted = (_tier_info[3] == 0 ? false : true);
    _cur_tier.updated_tier = true;
  }

  /*
  Returns a struct containing information on the current crowdsale

  @param _exec_id: The execution id under which the crowdsale is registered
  @param _sender: The address purchasing the tokens
  @param _cur_tier: A struct representing the current tier of the crowdsale
  @returns sale_stat: A struct representing the current crowdsale
  @returns spend_stat: A struct representing information about the sender
  */
  function getCrowdsaleInfo(bytes32 _exec_id, address _sender, CrowdsaleTier memory _cur_tier) internal view
  returns (CrowdsaleInfo memory sale_stat, SpendInfo memory spend_stat) {
      // Create 'readMulti' calldata buffer
      uint ptr = MemoryBuffers.cdBuff(RD_MULTI);
      // Push exec id, data read offset, and read size to buffer
      ptr.cdPush(_exec_id);
      ptr.cdPush(0x40);
      // If the tier is whitelisted, we want to read the sender's whitelist information (+ 2 read locations)
      if (_cur_tier.tier_is_whitelisted)
        ptr.cdPush(bytes32(14));
      else
        ptr.cdPush(bytes32(12));
      // Push team wallet, wei raised, token total supply, and tokens sold read locations to buffer
      ptr.cdPush(WALLET);
      ptr.cdPush(WEI_RAISED);
      ptr.cdPush(TOKEN_TOTAL_SUPPLY);
      ptr.cdPush(CROWDSALE_TOKENS_SOLD);
      // Push token decimal count, crowdsale start time, crowdsale unique contributor count,
      // and sender 'unique contributor' status loactions to buffer
      ptr.cdPush(TOKEN_DECIMALS);
      ptr.cdPush(CROWDSALE_START_TIME);
      ptr.cdPush(CROWDSALE_UNIQUE_CONTRIBUTORS);
      ptr.cdPush(keccak256(keccak256(_sender), CROWDSALE_UNIQUE_CONTRIBUTORS));
      // Push crowdsale initialization and finalization read locations to buffer
      ptr.cdPush(CROWDSALE_IS_INIT);
      ptr.cdPush(CROWDSALE_IS_FINALIZED);
      // Push sender token balance and crowdsale global minimum token purchase amount to buffer
      ptr.cdPush(keccak256(keccak256(_sender), TOKEN_BALANCES));
      ptr.cdPush(CROWDSALE_MINIMUM_CONTRIBUTION);
      // If the tier is whitelisted, push the sender's whitelist information (minimum contribution cap and maximum spend amount)
      if (_cur_tier.tier_is_whitelisted) {
        ptr.cdPush(keccak256(keccak256(_sender), keccak256(_cur_tier.index, SALE_WHITELIST)));
        ptr.cdPush(bytes32(32 + uint(keccak256(keccak256(_sender), keccak256(_cur_tier.index, SALE_WHITELIST)))));
      }
      // Read from storage -
      bytes32[] memory read_values = ptr.readMulti();
      // Ensure valid return length
      assert(_cur_tier.tier_is_whitelisted ? read_values.length == 14 : read_values.length == 12);

      // If the crowdsale is not initialized, is finalized, or has not yet begun, throw
      if (
        read_values[8] == 0            // Crowdsale is not yet initialized
        || read_values[9] != 0         // Crowdsale is already finalized
      ) bytes32("CrowdsaleInvalidState").trigger();

      // Get returned info and place in CrowdsaleInfo and SpendInfo structs
      sale_stat = CrowdsaleInfo({
        team_wallet: address(read_values[0]),
        wei_raised: uint(read_values[1]),
        token_total_supply: uint(read_values[2]),
        tokens_sold: uint(read_values[3]),
        token_decimals: uint(read_values[4]),
        start_time: uint(read_values[5]),
        num_contributors: uint(read_values[6]),
        sender_has_contributed: (read_values[7] == 0 ? false : true)
      });
      spend_stat = SpendInfo({
        sender_token_balance: uint(read_values[10]),
        minimum_purchase_amount: (_cur_tier.tier_is_whitelisted ? uint(read_values[12]) : uint(read_values[11])),
        maximum_spend_amount: (_cur_tier.tier_is_whitelisted ? uint(read_values[13]) : 0),
        amount_purchased: 0,
        amount_spent: 0
      });

      // Ensure team wallet and token decimal count are valid -
      if (
        sale_stat.team_wallet == address(0)          // Invalid team wallet address
        || sale_stat.token_decimals > 18             // Invalid token decimal count
      ) bytes32("InvalidWalletOrDecimals").trigger();
  }

  /*
  Gets the amount of tokens able to be purchased and the amount of wei able to be spent -

  @param _wei_sent: The amount of wei sent to purchase tokens
  @param _sale_stat: A struct representing crowdsale information
  @param _cur_tier: A struct representing the current crowdsale tier
  @param _spend_stat: A struct holding information on the sender and token
  */
  function getPurchaseInfo(
    uint _wei_sent,
    CrowdsaleInfo memory _sale_stat,
    CrowdsaleTier memory _cur_tier,
    SpendInfo memory _spend_stat
  ) internal pure {
    // Get amount of wei able to be spent, given the number of tokens remaining -
    if ((_wei_sent * (10 ** _sale_stat.token_decimals)) / _cur_tier.purchase_price > _cur_tier.tokens_remaining) {
      // wei sent is able to purchase more tokens than are remaining in this tier -
      _spend_stat.amount_spent =
        (_cur_tier.purchase_price * _cur_tier.tokens_remaining) / (10 ** _sale_stat.token_decimals);
    } else {
      // All of the wei sent can be used to purchase tokens
      _spend_stat.amount_spent =
        _wei_sent - (_wei_sent * (10 ** _sale_stat.token_decimals)) % _cur_tier.purchase_price;
    }

    // If the current tier is whitelisted, the sender has a maximum wei contribution cap. If amount spent exceeds this cap, adjust amount spent -
    if (_cur_tier.tier_is_whitelisted) {
      if (_spend_stat.amount_spent > _spend_stat.maximum_spend_amount) {
        _spend_stat.amount_spent =
          _spend_stat.maximum_spend_amount - (_spend_stat.maximum_spend_amount * (10 ** _sale_stat.token_decimals))
          % _cur_tier.purchase_price;
      }
      // Decrease spender's spend amount remaining by the amount spent
      _spend_stat.maximum_spend_amount -= _spend_stat.amount_spent;
    }

    // Ensure spend amount is valid -
    if (_spend_stat.amount_spent == 0 || _spend_stat.amount_spent > _wei_sent)
      bytes32("InvalidSpendAmount").trigger();

    // Get number of tokens able to be purchased with the amount spent -
    _spend_stat.amount_purchased =
      (_spend_stat.amount_spent * (10 ** _sale_stat.token_decimals) / _cur_tier.purchase_price);

    // Ensure amount of tokens to purchase is not greater than the amount of tokens remaining in this tier -
    if (_spend_stat.amount_purchased > _cur_tier.tokens_remaining)
      bytes32("InvalidPurchaseAmount").trigger();

    // Ensure amount of tokens to purchase is greater than the spender's minimum contribution cap -
    if (_spend_stat.amount_purchased < _spend_stat.minimum_purchase_amount)
      bytes32("UnderMinCap").trigger();
  }

  // Parses context array and returns execution id, sender address, and sent wei amount
  function parse(bytes memory _context) internal pure returns (bytes32 exec_id, address from, uint wei_sent) {
    if (_context.length != 96)
      bytes32("UnknownExecutionContext").trigger();

    assembly {
      exec_id := mload(add(0x20, _context))
      from := mload(add(0x40, _context))
      wei_sent := mload(add(0x60, _context))
    }

    // Ensure sender and exec id are valid
    if (from == address(0) || exec_id == 0)
      bytes32("UnknownExecutionContext").trigger();
  }
}
