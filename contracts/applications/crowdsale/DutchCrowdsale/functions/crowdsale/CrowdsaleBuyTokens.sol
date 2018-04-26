pragma solidity ^0.4.23;

import "../../../../../lib/MemoryBuffers.sol";
import "../../../../../lib/ArrayUtils.sol";

library CrowdsaleBuyTokens {

  using MemoryBuffers for uint;
  using ArrayUtils for bytes32[];
  using Exceptions for bytes32;

  /// CROWDSALE STORAGE ///

  // Whether the crowdsale and token are initialized, and the application is ready to run
  bytes32 internal constant CROWDSALE_IS_INIT = keccak256("crowdsale_is_init");

  // Whether or not the crowdsale is post-purchase
  bytes32 internal constant CROWDSALE_IS_FINALIZED = keccak256("crowdsale_is_finalized");

  // Storage location for the amount of tokens still available for purchase in this crowdsale
  bytes32 internal constant TOKENS_REMAINING = keccak256("crowdsale_tokens_remaining");

  // Storage location of the minimum amount of tokens allowed to be purchased
  bytes32 internal constant CROWDSALE_MINIMUM_CONTRIBUTION = keccak256("crowdsale_min_cap");

  // Maps addresses to a boolean indicating whether or not this address has contributed
  // At its base location, stores the amount of unique contributors so far in this crowdsale
  bytes32 internal constant CROWDSALE_UNIQUE_CONTRIBUTORS = keccak256("crowdsale_contributors");

  // Storage location of crowdsale start time
  bytes32 internal constant CROWDSALE_STARTS_AT = keccak256("crowdsale_starts_at");

  // Storage location of duration of crowdsale
  bytes32 internal constant CROWDSALE_DURATION = keccak256("crowdsale_duration");

  // Storage location of the token/wei rate at the beginning of the sale
  bytes32 internal constant STARTING_SALE_RATE = keccak256("crowdsale_start_rate");

  // Storage location of the token/wei rate at the beginning of the sale
  bytes32 internal constant ENDING_SALE_RATE = keccak256("crowdsale_end_rate");

  // Storage location of team funds wallet
  bytes32 internal constant WALLET = keccak256("crowdsale_wallet");

  // Storage location of amount of wei raised during the crowdsale, total
  bytes32 internal constant WEI_RAISED = keccak256("crowdsale_wei_raised");

  // Whether or not the crowdsale is whitelist-enabled
  bytes32 internal constant SALE_IS_WHITELISTED = keccak256("crowdsale_is_whitelisted");

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

  // Storage seed for user balances mapping
  bytes32 internal constant TOKEN_BALANCES = keccak256("token_balances");

  /// FUNCTION SELECTORS ///

  // Function selector for storage 'readMulti'
  // readMulti(bytes32 exec_id, bytes32[] locations)
  bytes4 internal constant RD_MULTI = bytes4(keccak256("readMulti(bytes32,bytes32[])"));

  struct CrowdsaleInfo {
    address team_wallet;
    uint wei_raised;
    uint tokens_remaining;
    uint token_decimals;
    uint start_time;
    uint start_rate;
    uint end_rate;
    uint sale_duration;
    bool sale_is_whitelisted;
  }

  struct SpendInfo {
    uint spender_token_balance;
    uint spend_amount;
    uint tokens_purchased;
    uint current_rate;
    bool sender_has_contributed;
    uint num_contributors;
    uint minimum_contribution_amount;
    uint spend_amount_remaining;
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

    /// Get crowdsale information and place in CrowdsaleInfo struct
    CrowdsaleInfo memory sale_stat = getCrowdsaleInfo(exec_id);
    /// Get sender and spend information and place in SpendInfo struct
    SpendInfo memory spend_stat = getSpendInfo(sender, exec_id, sale_stat.sale_is_whitelisted);

    /// Crowdsale is in a valid purchase satte - get current sale rate:
    getCurrentRate(sale_stat, spend_stat);

    // Sanity check - current rate should be between the starting and ending rates
    assert(sale_stat.start_rate >= spend_stat.current_rate && spend_stat.current_rate >= sale_stat.end_rate);

    /// Get total amount of wei that can be spent, given the amount sent and the number of tokens remaining -
    getPurchaseInfo(wei_sent, sale_stat, spend_stat);

    /// Amount to spend and amount of tokens to purchase have been calculated - prepare storage return buffer
    uint ptr = MemoryBuffers.stBuff(sale_stat.team_wallet, spend_stat.spend_amount);

    // Safely add purchased tokens to purchaser's balance, and check for overflow
    require(spend_stat.tokens_purchased + spend_stat.spender_token_balance > spend_stat.spender_token_balance);
    ptr.stPush(
      keccak256(keccak256(sender), TOKEN_BALANCES),
      bytes32(spend_stat.spender_token_balance + spend_stat.tokens_purchased)
    );
    // Safely subtract purchased token amount from tokens_remaining
    require(spend_stat.tokens_purchased <= sale_stat.tokens_remaining);
    ptr.stPush(TOKENS_REMAINING, bytes32(sale_stat.tokens_remaining - spend_stat.tokens_purchased));
    // Safely add wei spent to total wei raised, and check for overflow
    require(spend_stat.spend_amount + sale_stat.wei_raised > sale_stat.wei_raised);
    ptr.stPush(WEI_RAISED, bytes32(spend_stat.spend_amount + sale_stat.wei_raised));

    // If the sender had not previously contributed, add them as a unique contributor -
    if (spend_stat.sender_has_contributed == false) {
      ptr.stPush(CROWDSALE_UNIQUE_CONTRIBUTORS, bytes32(spend_stat.num_contributors + 1));
      ptr.stPush(keccak256(keccak256(sender), CROWDSALE_UNIQUE_CONTRIBUTORS), bytes32(1));
    }

    // If the crowdsale is whitelisted, update the sender's minimum and maximum contribution amounts-
    if (sale_stat.sale_is_whitelisted) {
      ptr.stPush(keccak256(keccak256(sender), SALE_WHITELIST), 0); // Sender's new minimum contribution amount - 0
      ptr.stPush(
        bytes32(32 + uint(keccak256(keccak256(sender), SALE_WHITELIST))),
        bytes32(spend_stat.spend_amount_remaining)
      );
    }

    // Get bytes32[] representation of storage buffer
    store_data = ptr.getBuffer();
  }

  /*
  Given information about a crowdsale, loads information about purchase amounts into SpendInfo

  @param _wei_sent: The amount of wei sent to purchase with
  @param _sale_stat: A CrowdsaleInfo struct holding various information about the ongoing crowdsale
  @param _spend_stat: A SpendInfo struct holding information about the sender
  */
  function getPurchaseInfo(
    uint _wei_sent,
    CrowdsaleInfo memory _sale_stat,
    SpendInfo memory _spend_stat
  ) internal pure {
    // Get amount of wei able to be spent, given the number of tokens remaining -
    if ((_wei_sent * (10 ** _sale_stat.token_decimals) / _spend_stat.current_rate) > _sale_stat.tokens_remaining) {
      // The amount that can be purchased is more than the number of tokens remaining:
      _spend_stat.spend_amount =
        (_spend_stat.current_rate * _sale_stat.tokens_remaining) / (10 ** _sale_stat.token_decimals);
    } else {
      // All of the wei sent can be used to purchase -
      _spend_stat.spend_amount =
        _wei_sent - (_wei_sent * (10 ** _sale_stat.token_decimals)) % _spend_stat.current_rate;
    }

    // If the sale is whitelisted, ensure the sender is not going over their spend cap -
    if (_sale_stat.sale_is_whitelisted) {
      if (_spend_stat.spend_amount > _spend_stat.spend_amount_remaining) {
        _spend_stat.spend_amount =
          _spend_stat.spend_amount_remaining -
          (_spend_stat.spend_amount_remaining * (10 ** _sale_stat.token_decimals)) % _spend_stat.current_rate;
      }

      // Decrease sender's spend amount remaining
      assert(_spend_stat.spend_amount_remaining >= _spend_stat.spend_amount);
      _spend_stat.spend_amount_remaining -= _spend_stat.spend_amount;
    }

    // Ensure spend amount is valid -
    if (_spend_stat.spend_amount == 0 || _spend_stat.spend_amount > _wei_sent)
      bytes32("InvalidSpendAmount").trigger();

    // Get number of tokens able to be purchased with the amount spent -
    _spend_stat.tokens_purchased =
      (_spend_stat.spend_amount * (10 ** _sale_stat.token_decimals)) / _spend_stat.current_rate;

    // Ensure amount of tokens to purchase is not greater than the amount of tokens remaining in the sale -
    if (_spend_stat.tokens_purchased > _sale_stat.tokens_remaining)
      bytes32("InvalidPurchaseAmount").trigger();

    // Ensure the number of tokens purchased meets the sender's minimum contribution requirement
    if (_spend_stat.tokens_purchased < _spend_stat.minimum_contribution_amount)
      bytes32("UnderMinCap").trigger();
  }

  /*
  Returns general information on the ongoing crowdsale and stores it in a CrowdsaleInfo struct

  @param _exec_id: The execution id under which the crowdsale is registered
  @return sale_stat: A struct containing information about the ongoing crowdsale
  */
  function getCrowdsaleInfo(bytes32 _exec_id) internal view returns (CrowdsaleInfo memory sale_stat) {
    // Create 'readMulti' calldata buffer in memory -
    uint ptr = MemoryBuffers.cdBuff(RD_MULTI);
    // Push exec id, data read offset, and read size to buffer
    ptr.cdPush(_exec_id);
    ptr.cdPush(0x40);
    ptr.cdPush(bytes32(11));
    // Push team wallet, wei raised, tokens remaining, token decimals, and crowdsale start time to buffer
    ptr.cdPush(WALLET);
    ptr.cdPush(WEI_RAISED);
    ptr.cdPush(TOKENS_REMAINING);
    ptr.cdPush(TOKEN_DECIMALS);
    ptr.cdPush(CROWDSALE_STARTS_AT);
    // Push crowdsale start rate, end rate, sale duration, and whitelist status to buffer
    ptr.cdPush(STARTING_SALE_RATE);
    ptr.cdPush(ENDING_SALE_RATE);
    ptr.cdPush(CROWDSALE_DURATION);
    ptr.cdPush(SALE_IS_WHITELISTED);
    // Push crowdsale initialization and finalization status locations to buffer
    ptr.cdPush(CROWDSALE_IS_INIT);
    ptr.cdPush(CROWDSALE_IS_FINALIZED);
    // Read from storage
    uint[] memory crowdsale_info = ptr.readMulti().toUintArr();
    // Ensure valid read size
    assert(crowdsale_info.length == 11);

    /// Assign members to struct -
    sale_stat = CrowdsaleInfo({
      team_wallet: address(crowdsale_info[0]),
      wei_raised: crowdsale_info[1],
      tokens_remaining: crowdsale_info[2],
      token_decimals: crowdsale_info[3],
      start_time: crowdsale_info[4],
      start_rate: crowdsale_info[5],
      end_rate: crowdsale_info[6],
      sale_duration: crowdsale_info[7],
      sale_is_whitelisted: crowdsale_info[8] == 0 ? false : true
    });

    // Ensure valid crowdsale setup -
    if (
      sale_stat.team_wallet == address(0)                        // Invalid team wallet address
      || sale_stat.token_decimals > 18                           // Invalid token decimal amount
      || sale_stat.start_time == 0                               // Invalid crowdsale start time
      || sale_stat.end_rate == 0                                 // Invalid crowdsale ending rate
      || sale_stat.start_rate <= sale_stat.end_rate              // State rate must be larger than end rate
      || sale_stat.sale_duration == 0                            // Invalid crowdsale duration
    ) bytes32("InvalidCrowdsaleSetup").trigger();

    // Ensure crowdsale is in a purchasable state -
    if (now < sale_stat.start_time)
      bytes32("BeforeStartTime").trigger();
    if (
      sale_stat.tokens_remaining == 0                            // No tokens remaining for purchase
      || now >= sale_stat.start_time + sale_stat.sale_duration   // Crowddsale has already ended
      || crowdsale_info[9] == 0                                  // Crowdsale is not initialized
      || crowdsale_info[10] != 0                                 // Crowdsale is already finalized
    ) bytes32("CrowdsaleFinished").trigger();
  }

  /*
  Gets information about the sender, crowdsale whitelist, and contributor count and stores it in a SpendInfo struct

  @param _sender: The original script executor
  @param _exec_id: The execution id under which the crowdsale is registered
  @param _sale_is_whitelisted: Whether or not the crowdsale is whitelisted
  @return spend_stat: A struct holding information about the sender
  */
  function getSpendInfo(address _sender, bytes32 _exec_id, bool _sale_is_whitelisted) internal view
  returns (SpendInfo memory spend_stat) {
    // Create 'readMulti' calldata buffer in memory -
    uint ptr = MemoryBuffers.cdBuff(RD_MULTI);
    // Push exec id, data read offset, and read size to buffer
    ptr.cdPush(_exec_id);
    ptr.cdPush(0x40);
    // If the sale is whitelisted, read size is one more than if it is not
    if (_sale_is_whitelisted) {
      ptr.cdPush(bytes32(5));
    } else {
      ptr.cdPush(bytes32(4));
    }
    // Push sender token balance, sender unique contribution location, and number of unique contributors to buffer
    ptr.cdPush(keccak256(keccak256(_sender), TOKEN_BALANCES));
    ptr.cdPush(keccak256(keccak256(_sender), CROWDSALE_UNIQUE_CONTRIBUTORS));
    ptr.cdPush(CROWDSALE_UNIQUE_CONTRIBUTORS);
    // If the crowdsale is whitelisted, push whitelist information locations for the sender to the buffer
    if (_sale_is_whitelisted) {
      ptr.cdPush(keccak256(keccak256(_sender), SALE_WHITELIST));
      ptr.cdPush(bytes32(32 + uint(keccak256(keccak256(_sender), SALE_WHITELIST))));
    } else {
      // If the sale is not whitelisted, push the sale global minimum purchase amount cap to the buffer
      ptr.cdPush(CROWDSALE_MINIMUM_CONTRIBUTION);
    }
    // Read from storage
    uint[] memory spend_info = ptr.readMulti().toUintArr();
    // Ensure valid read size
    assert(_sale_is_whitelisted ? spend_info.length == 5 : spend_info.length == 4);

    /// Assign members to struct -
    spend_stat = SpendInfo({
      spender_token_balance: spend_info[0],
      spend_amount: 0,
      tokens_purchased: 0,
      current_rate: 0,
      sender_has_contributed: (spend_info[1] == 0 ? false : true),
      num_contributors: spend_info[2],
      minimum_contribution_amount: spend_info[3],
      spend_amount_remaining: (_sale_is_whitelisted ? spend_info[4] : 0)
    });

    // If the crowdsale is whitelisted and the sender has no remaining spend amount, revert
    if (_sale_is_whitelisted && spend_stat.spend_amount_remaining == 0)
      bytes32("SpendAmountExceeded").trigger();
  }

  /*
  Gets the current sale rate and places it in _sale_stat.current_rate

  @param _sale_stat: A CrowdsaleInfo struct holding various information about the ongoing crowdsale
  @param _spend_stat: A SpendInfo struct holding information about the sender
  */
  function getCurrentRate(CrowdsaleInfo memory _sale_stat, SpendInfo memory _spend_stat) internal view {
    // If the sale has not started, set current rate to 0
    if (now <= _sale_stat.start_time) {
      _spend_stat.current_rate = 0;
      return;
    }

    // Get amount of time elapsed
    uint elapsed = now - _sale_stat.start_time;
    // If the sale has ended, set current rate to 0
    if (elapsed >= _sale_stat.sale_duration) {
      _spend_stat.current_rate = 0;
      return;
    }

    // Add precision to time elapsed -
    require(elapsed * (10 ** 18) > elapsed);
    elapsed *= (10 ** 18);

    // Crowdsale is active - calculate current rate, adding decimals for precision
    assert(_sale_stat.start_rate > _sale_stat.end_rate);
    uint temp_rate = (_sale_stat.start_rate - _sale_stat.end_rate)
                                * (elapsed / _sale_stat.sale_duration);

    temp_rate /= (10**18);

    assert(temp_rate <= _sale_stat.start_rate);
    // Current rate is start rate minus temp rate
    _spend_stat.current_rate = _sale_stat.start_rate - temp_rate;
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
