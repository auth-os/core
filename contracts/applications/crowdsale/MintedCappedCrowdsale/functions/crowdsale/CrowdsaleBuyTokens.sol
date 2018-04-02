pragma solidity ^0.4.21;

library CrowdsaleBuyTokens {

  /// CROWDSALE STORAGE ///

  // Whether the crowdsale and token are initialized, and the sale is ready to run
  bytes32 public constant CROWDSALE_IS_INIT = keccak256("crowdsale_is_init");

  // Whether or not the crowdsale is post-purchase
  bytes32 public constant CROWDSALE_IS_FINALIZED = keccak256("crowdsale_is_finalized");

  // Storage location of the crowdsale's start time
  bytes32 public constant CROWDSALE_START_TIME = keccak256("crowdsale_start_time");

  // Storage location of a list of the tiers the crowdsale will have
  /* Each tier mimics the following struct:
  struct CrowdsaleTier {
    bytes32 _tier_name;                 // The name of the crowdsale tier
    uint _tier_token_sell_cap;          // The maximum number of tokens that will be sold during this tier
    uint _duration;                     // The amount of time this tier will be active for
    bool _tier_duration_is_modifiable;  // Whether the crowdsale admin is allowed to modify the duration of a tier before it goes live
    bool _tier_is_whitelist_enabled     // Whether this tier of the crowdsale requires users to be on a purchase whitelist
  }
  */
  bytes32 public constant CROWDSALE_TIERS = keccak256("crowdsale_tier_list");

  // Storage location of the CROWDSALE_TIERS index (-1) of the current tier. If zero, no tier is currently active
  bytes32 public constant CROWDSALE_CURRENT_TIER = keccak256("crowdsale_current_tier");

  // Storage location of the end time of the current tier. Purchase attempts beyond this time will update the current tier (if another is available)
  bytes32 public constant CURRENT_TIER_ENDS_AT = keccak256("crowdsale_tier_ends_at");

  // Storage location of the total number of tokens remaining for purchase in the current tier
  bytes32 public constant CURRENT_TIER_TOKENS_REMAINING = keccak256("crowdsale_tier_tokens_remaining");

  // Storage location of team funds wallet
  bytes32 public constant WALLET = keccak256("crowdsale_wallet");

  // Storage location of amount of wei raised during the crowdsale, total
  bytes32 public constant WEI_RAISED = keccak256("crowdsale_wei_raised");

  // Storage location of token per wei rate
  bytes32 public constant SALE_RATE = keccak256("crowdsale_sale_rate");

  // Storage seed for crowdsale whitelist mapping - maps addresses to a boolean value indicating whether they are on the whitelist
  bytes32 public constant SALE_WHITELIST = keccak256("crowdsale_purchase_whitelist");

  /// TOKEN STORAGE ///

  // Storage location for token totalSupply
  bytes32 public constant TOKEN_TOTAL_SUPPLY = keccak256("token_total_supply");

  // Storage seed for user balances mapping
  bytes32 public constant TOKEN_BALANCES = keccak256("token_balances");

  /// FUNCTION SELECTORS ///

  // Function selector for storage "read"
  // read(bytes32 _exec_id, bytes32 _location) view returns (bytes32 data_read);
  bytes4 public constant RD_SING = bytes4(keccak256("read(bytes32,bytes32)"));

  // Function selector for storage 'readMulti'
  // readMulti(bytes32 exec_id, bytes32[] locations)
  bytes4 public constant RD_MULTI = bytes4(keccak256("readMulti(bytes32,bytes32[])"));

  /// EXCEPTION MESSAGES ///

  bytes32 public constant ERR_UNKNOWN_CONTEXT = bytes32("UnknownContext"); // Malformed '_context' array
  bytes32 public constant ERR_INSUFFICIENT_PERMISSIONS = bytes32("InsufficientPermissions"); // Action not allowed
  bytes32 public constant ERR_READ_FAILED = bytes32("StorageReadFailed"); // Read from storage address failed
  bytes32 public constant ERR_INSUFFICIENT_FUNDS = bytes32("InsufficientFunds"); // Incorrect amount of wei sent
  bytes32 public constant ERR_SALE_SOLD_OUT = bytes32("CrowdsaleSoldOut"); // Crowdsale has no more tokens up for purchase
  bytes32 public constant ERR_TIER_SOLD_OUT = bytes32("TierSoldOut"); // Current tier has no more tokens up for purchase

  struct CrowdsaleTier {
    uint index;
    uint tokens_remaining;
    uint time_remaining;
    uint tier_ends_at;
    bool tier_is_whitelisted;
    bool updated_tier;
  }

  struct CrowdsaleInfo {
    address team_wallet;
    uint wei_raised;
    uint sale_rate;
    uint start_time;
    uint num_tiers;
  }

  struct SpendInfo {
    uint token_total_supply;
    uint sender_token_balance;
    uint spend_amount;
    uint tokens_purchased;
    bool valid_state;
  }

  /*
  Allows the sender to purchase tokens from the crowdsale, if it is active

  @param _context: The execution context for this application - a 96-byte array containing (in order):
    1. Application execution id
    2. Original script sender (address, padded to 32 bytes)
    3. Wei amount sent with transaction to storage
  @return store_data: A formatted storage request - first 64 bytes designate a forwarding address (and amount) for any wei sent
  */
  function buy(bytes _context) public view returns (bytes32[] store_data) {
    // Ensure valid input
    if (_context.length != 96)
      triggerException(ERR_UNKNOWN_CONTEXT);

    // Get original sender address, execution id, and wei sent from context array
    address sender;
    bytes32 exec_id;
    uint wei_sent;
    (exec_id, sender, wei_sent) = parse(_context);
    // Ensure nonzero amount of wei sent
    if (wei_sent == 0)
      triggerException(ERR_INSUFFICIENT_FUNDS);

    // Get CrowdsaleTier struct to hold returned data
    CrowdsaleTier memory cur_tier = CrowdsaleTier({
      index: 0,
      tokens_remaining: 0,
      time_remaining: 0,
      tier_ends_at: 0,
      tier_is_whitelisted: false,
      // In the event the current tier information retrieved from storage is incorrect, this flags storage of new 'current tier info'
      updated_tier: false
    });

    /// Read crowdsale and tier information from storage -

    // Initial read - current tier index
    // Create 'read' calldata buffer in memory
    uint ptr = cdBuff(RD_SING);
    // Push exec id and current tier index storage location to buffer
    cdPush(ptr, exec_id);
    cdPush(ptr, CROWDSALE_CURRENT_TIER);
    // Read from storage, and place return in CrowdsaleTier struct
    cur_tier.index = uint(readSingle(ptr));
    // Indexes are off by one in storage - if zero was returned, tier index is invalid
    require(cur_tier.index != 0);
    cur_tier.index--;

    // Create 'readMulti' calldata buffer in memory - overwrite previous buffer
    cdOverwrite(ptr, RD_MULTI);
    // Push exec id, data read offset, and read size to buffer
    cdPush(ptr, exec_id);
    cdPush(ptr, 0x40);
    cdPush(ptr, bytes32(12));
    // Push general crowdsale information storage locations to calldata buffer
    cdPush(ptr, WALLET); // Team funds wallet
    cdPush(ptr, WEI_RAISED); // Amount of wei raised during the crowdsale so far
    cdPush(ptr, SALE_RATE); // Sale rate - number of tokens recieved per wei spent
    // Push crowdsale status storage locations to calldata buffer
    cdPush(ptr, CROWDSALE_IS_INIT); // Whether the crowdsale is initialized or not
    cdPush(ptr, CROWDSALE_IS_FINALIZED); // Whether the crowdsale is finalized or not
    cdPush(ptr, CROWDSALE_START_TIME); // Start time for the crowdsale
    cdPush(ptr, CROWDSALE_TIERS); // Number of tiers in the crowdsale
    // Push crowdsale tier information storage locations to calldata buffer
    cdPush(ptr, bytes32(160 + (160 * cur_tier.index) + uint(CROWDSALE_TIERS))); // Location of current tier 'whitelist-enabled' storage location
    cdPush(ptr, CURRENT_TIER_ENDS_AT); // Time at which the current crowdsale tier ends
    cdPush(ptr, CURRENT_TIER_TOKENS_REMAINING); // Number of tokens remaining in the current tier
    // Push token information storage locations to calldata buffer
    cdPush(ptr, TOKEN_TOTAL_SUPPLY); // Total number of tokens existing so far
    cdPush(ptr, keccak256(keccak256(sender), TOKEN_BALANCES)); // Sender's token balance

    // Read from storage, and return data to buffer
    bytes32[] memory read_values = readMulti(ptr);

    // Get CrowdsaleInfo struct from returned crowdsale information
    CrowdsaleInfo memory sale_stat = CrowdsaleInfo({
      team_wallet: address(read_values[0]),
      wei_raised: uint(read_values[1]),
      sale_rate: uint(read_values[2]),
      start_time: uint(read_values[5]),
      num_tiers: uint(read_values[6])
    });

    // Update CrowdsaleTier struct with returned data
    cur_tier.tokens_remaining = uint(read_values[9]);
    cur_tier.time_remaining = (now < uint(read_values[8]) ? uint(read_values[8]) - now : 0);
    cur_tier.tier_ends_at = uint(read_values[8]);
    cur_tier.tier_is_whitelisted = (read_values[7] == bytes32(0) ? false : true);

    // Get SpendInfo struct from returned token and balance information
    SpendInfo memory spend_info = SpendInfo({
      token_total_supply: uint(read_values[10]),
      sender_token_balance: uint(read_values[11]),
      spend_amount: 0,
      tokens_purchased: 0,
      // This flag is updated if the crowdsale is in a valid state to execute purchase of tokens
      valid_state: false
    });

    /// Check values from storage for valid purchase state -
    if (
      read_values[3] == bytes32(0)              // Crowdsale is not yet initialized
      || read_values[4] != bytes32(0)           // Crowdsale has already been finalized
      || now < sale_stat.start_time             // Current time is prior to crowdsale start time
    ) triggerException(ERR_INSUFFICIENT_PERMISSIONS);

    // Sanity checks - sale rate, wallet, and number of tiers should be nonzero
    assert(sale_stat.team_wallet != address(0) && sale_stat.sale_rate > 0 && sale_stat.num_tiers != 0);
    // Ensure current tier index is valid -
    assert(cur_tier.index < sale_stat.num_tiers);

    /// Assess current tier state (2 scenarios):
    /*
    Assuming previous checks have passed -
    1. Current tier is the final tier:
      A. time_remaining == 0                    => Throw - crowdsale has ended
      B. tokens_remaining < sale_rate           => Throw - crowdsale is sold out
      C. tokens_remaining >= sale_rate          => Valid - execute purchase
    2. Current tier is not the final tier:
      A. time_remaining == 0                    => Update - get actual current tier info and update
      B. time_remaining != 0:
        a. tokens_remaining < sale_rate         => Throw - tier is sold out
        b. tokens_remaining >= sale_rate        => Valid - execute purchase

    */

    // Current tier is the final tier:
    if (cur_tier.index >= sale_stat.num_tiers) {
      // If no time remains in the current tier, the crowdsale has ended -
      if (cur_tier.time_remaining == 0)
        triggerException(ERR_INSUFFICIENT_PERMISSIONS);

      // If not enough tokens are available for purchase, the crowdsale has sold out -
      if (cur_tier.tokens_remaining < sale_stat.sale_rate)
        triggerException(ERR_SALE_SOLD_OUT);

      // Sanity check - then set 'valid_state' flag to true, so that spend amount and tokens purchased can be calculated
      assert(spend_info.valid_state == false);
      spend_info.valid_state = true;

    // Current tier is not the final tier in the crowdsale:
    } else {
      // If current tier time remaining is 0, read from storage and find the actual current tier, then update the information in cur_tier
      if (cur_tier.time_remaining == 0)
        getCurrentTier(cur_tier, sale_stat.num_tiers, exec_id);

      // If no tokens are available for sale, this tier is sold out
      if (cur_tier.tokens_remaining < sale_stat.sale_rate)
        triggerException(ERR_TIER_SOLD_OUT);

      // Sanity check - ensure current tier end time is in the future, and index is valid
      assert(cur_tier.tier_ends_at > now && cur_tier.index < sale_stat.num_tiers);

      // Sanity check - then set 'valid_state' flag to true, so that spend amount and tokens purchased can be calculated
      assert(spend_info.valid_state == false);
      spend_info.valid_state = true;
    }
    // 'valid state' flag must be true, and tokens purchased must be 0 -
    assert(spend_info.valid_state == true && spend_info.tokens_purchased == 0);

    /// Get amount of wei able to be spent from wei_sent, sale_rate, and tier tokens remaining

    // If amount to buy is over the amount of tokens remaining:
    if (wei_sent * sale_stat.sale_rate > cur_tier.tokens_remaining) {
      spend_info.spend_amount =
        (cur_tier.tokens_remaining - (cur_tier.tokens_remaining % sale_stat.sale_rate)) / sale_stat.sale_rate;

      // No tokens are able to be purchased
      if (spend_info.spend_amount == 0)
        triggerException(ERR_TIER_SOLD_OUT);
    } else {
      spend_info.spend_amount = wei_sent;
    }
    // Sanity check -
    assert(spend_info.spend_amount != 0 && spend_info.spend_amount <= wei_sent);
    spend_info.tokens_purchased = spend_info.spend_amount * sale_stat.sale_rate;

    /// If current tier is whitelisted, read sender's whitelist status storage location -

    if (cur_tier.tier_is_whitelisted == true) {
      // Overwrite previous buffer, and create 'read' calldata buffer
      cdOverwrite(ptr, RD_SING);
      // Push exec id and sender whitelist status storage location to buffer
      cdPush(ptr, exec_id);
      cdPush(ptr, keccak256(keccak256(sender), SALE_WHITELIST));
      // Read from storage - if returned value is false, sender cannot participate in this tier
      if (readSingle(ptr) == bytes32(0))
        triggerException(ERR_INSUFFICIENT_PERMISSIONS);
    }

    // Overwrite previous read buffer, and create storage return buffer
    stOverwrite(ptr);
    // Push payment information (team wallet address and spend amount) to storage buffer
    stPush(ptr, bytes32(sale_stat.team_wallet));
    stPush(ptr, bytes32(spend_info.spend_amount));
    // Safely add to sender's token balance, and push their new balance and balance storage location
    require(spend_info.tokens_purchased + spend_info.sender_token_balance > spend_info.sender_token_balance);
    stPush(ptr, keccak256(keccak256(sender), TOKEN_BALANCES));
    stPush(ptr, bytes32(spend_info.tokens_purchased + spend_info.sender_token_balance));
    // Safely subtract purchased token amount from tier tokens remaining
    require(cur_tier.tokens_remaining >= spend_info.tokens_purchased);
    stPush(ptr, CURRENT_TIER_TOKENS_REMAINING);
    stPush(ptr, bytes32(cur_tier.tokens_remaining - spend_info.tokens_purchased));
    // Safely add tokens purchased to total token supply
    require(spend_info.token_total_supply + spend_info.tokens_purchased > spend_info.token_total_supply);
    stPush(ptr, TOKEN_TOTAL_SUPPLY);
    stPush(ptr, bytes32(spend_info.token_total_supply + spend_info.tokens_purchased));
    // Safely add to amount of wei raised, total
    require(sale_stat.wei_raised + spend_info.spend_amount > sale_stat.wei_raised);
    stPush(ptr, WEI_RAISED);
    stPush(ptr, bytes32(sale_stat.wei_raised + spend_info.spend_amount));
    // If cur_tier.updated_tier is true, there is a new current crowdsale tier - push information to buffer
    if (cur_tier.updated_tier == true) {
      // Push new current tier index
      stPush(ptr, CROWDSALE_CURRENT_TIER);
      stPush(ptr, bytes32(cur_tier.index));
      // Push updated current tier end time
      stPush(ptr, CURRENT_TIER_ENDS_AT);
      stPush(ptr, bytes32(cur_tier.tier_ends_at));
    }

    // Get bytes32[] representation of storage buffer
    store_data = getBuffer(ptr);
  }

  /*
  Loops through tier information in storage, and retrieves information for the current crowdsale tier

  @param cur_tier: A struct with relevant information on the current crowdsale tier.
                    This is updated by reference when the actual current tier is found
  */
  function getCurrentTier(CrowdsaleTier memory cur_tier, uint _num_tiers, bytes32 _exec_id) internal view {
    // While the updated end time of each tier is still prior to the current time,
    // and while the updated tier's index is within a valid range -
    uint[] memory read_values;
    while (cur_tier.tier_ends_at < now && cur_tier.index < _num_tiers) {
      // Read next tier info from storage -
      uint ptr = cdBuff(RD_MULTI);
      // Push exec id, data read offset, and read size to calldata buffer
      cdPush(ptr, _exec_id);
      cdPush(ptr, 0x40);
      cdPush(ptr, bytes32(3));
      // Push tier duration storage location to buffer
      cdPush(ptr, bytes32(96 + (160 * cur_tier.index) + uint(CROWDSALE_TIERS)));
      // Push tier token sell cap storage location to buffer
      cdPush(ptr, bytes32(64 + (160 * cur_tier.index) + uint(CROWDSALE_TIERS)));
      // Push tier 'is-whitelisted' status storage location to buffer
      cdPush(ptr, bytes32(160 + (160 * cur_tier.index) + uint(CROWDSALE_TIERS)));
      // Read from storage, and store return to buffer
      read_values = readMultiUint(ptr);
      // Add returned duration to previous tier end time
      require(cur_tier.tier_ends_at + read_values[0] > cur_tier.tier_ends_at);
      cur_tier.tier_ends_at += read_values[0];
      // Increment tier index
      cur_tier.index++;
    }
    // If the updated current tier's index is not in the valid range, or the end time is still in the past, throw
    if (cur_tier.tier_ends_at < now || cur_tier.index >= _num_tiers)
      triggerException(ERR_INSUFFICIENT_PERMISSIONS);

    // Otherwise - update the CrowdsaleTier struct to reflect the actual current tier of the crowdsale
    assert(read_values[1] != 0);
    cur_tier.tokens_remaining = read_values[1];
    cur_tier.time_remaining = cur_tier.tier_ends_at - now;
    cur_tier.tier_is_whitelisted = (read_values[2] == 0 ? false : true);
    cur_tier.updated_tier = true;
  }

  /*
  Creates a new return data storage buffer at the position given by the pointer. Does not update free memory

  @param _ptr: A pointer to the location where the buffer will be created
  */
  function stOverwrite(uint _ptr) internal pure {
    assembly {
      // Simple set the initial length - 0
      mstore(_ptr, 0)
    }
  }

  /*
  Pushes a value to the end of a storage return buffer, and updates the length

  @param _ptr: A pointer to the start of the buffer
  @param _val: The value to push to the buffer
  */
  function stPush(uint _ptr, bytes32 _val) internal pure {
    assembly {
      // Get end of buffer - 32 bytes plus the length stored at the pointer
      let len := add(0x20, mload(_ptr))
      // Push value to end of buffer (overwrites memory - be careful!)
      mstore(add(_ptr, len), _val)
      // Increment buffer length
      mstore(_ptr, len)
      // If the free-memory pointer does not point beyond the buffer's current size, update it
      if lt(mload(0x40), add(add(0x20, _ptr), len)) {
        mstore(0x40, add(add(0x40, _ptr), len)) // Ensure free memory pointer points to the beginning of a memory slot
      }
    }
  }

  /*
  Returns the bytes32[] stored at the buffer

  @param _ptr: A pointer to the location in memory where the calldata for the call is stored
  @return store_data: The return values, which will be stored
  */
  function getBuffer(uint _ptr) internal pure returns (bytes32[] store_data){
    assembly {
      // If the size stored at the pointer is not evenly divislble into 32-byte segments, this was improperly constructed
      if gt(mod(mload(_ptr), 0x20), 0) { revert (0, 0) }
      mstore(_ptr, div(mload(_ptr), 0x20))
      store_data := _ptr
    }
  }

  /*
  Creates a calldata buffer in memory with the given function selector

  @param _selector: The function selector to push to the first location in the buffer
  @return ptr: The location in memory where the length of the buffer is stored - elements stored consecutively after this location
  */
  function cdBuff(bytes4 _selector) internal pure returns (uint ptr) {
    assembly {
      // Get buffer location - free memory
      ptr := mload(0x40)
      // Place initial length (4 bytes) in buffer
      mstore(ptr, 0x04)
      // Place function selector in buffer, after length
      mstore(add(0x20, ptr), _selector)
      // Update free-memory pointer - it's important to note that this is not actually free memory, if the pointer is meant to expand
      mstore(0x40, add(0x40, ptr))
    }
  }

  /*
  Creates a new calldata buffer at the pointer with the given selector. Does not update free memory

  @param _ptr: A pointer to the buffer to overwrite - will be the pointer to the new buffer as well
  @param _selector: The function selector to place in the buffer
  */
  function cdOverwrite(uint _ptr, bytes4 _selector) internal pure {
    assembly {
      // Store initial length of buffer - 4 bytes
      mstore(_ptr, 0x04)
      // Store function selector after length
      mstore(add(0x20, _ptr), _selector)
    }
  }

  /*
  Pushes a value to the end of a calldata buffer, and updates the length

  @param _ptr: A pointer to the start of the buffer
  @param _val: The value to push to the buffer
  */
  function cdPush(uint _ptr, bytes32 _val) internal pure {
    assembly {
      // Get end of buffer - 32 bytes plus the length stored at the pointer
      let len := add(0x20, mload(_ptr))
      // Push value to end of buffer (overwrites memory - be careful!)
      mstore(add(_ptr, len), _val)
      // Increment buffer length
      mstore(_ptr, len)
      // If the free-memory pointer does not point beyond the buffer's current size, update it
      if lt(mload(0x40), add(add(0x20, _ptr), len)) {
        mstore(0x40, add(add(0x2c, _ptr), len)) // Ensure free memory pointer points to the beginning of a memory slot
      }
    }
  }

  /*
  Executes a 'readMulti' function call, given a pointer to a calldata buffer

  @param _ptr: A pointer to the location in memory where the calldata for the call is stored
  @return read_values: The values read from storage
  */
  function readMulti(uint _ptr) internal view returns (bytes32[] read_values) {
    bool success;
    assembly {
      // Minimum length for 'readMulti' - 1 location is 0x84
      if lt(mload(_ptr), 0x84) { revert (0, 0) }
      // Read from storage
      success := staticcall(gas, caller, add(0x20, _ptr), mload(_ptr), 0, 0)
      // If call succeed, get return information
      if gt(success, 0) {
        // Ensure data will not be copied beyond the pointer
        if gt(sub(returndatasize, 0x20), mload(_ptr)) { revert (0, 0) }
        // Copy returned data to pointer, overwriting it in the process
        // Copies returndatasize, but ignores the initial read offset so that the bytes32[] returned in the read is sitting directly at the pointer
        returndatacopy(_ptr, 0x20, sub(returndatasize, 0x20))
        // Set return bytes32[] to pointer, which should now have the stored length of the returned array
        read_values := _ptr
      }
    }
    if (!success)
      triggerException(ERR_READ_FAILED);
  }

  /*
  Executes a 'readMulti' function call, given a pointer to a calldata buffer

  @param _ptr: A pointer to the location in memory where the calldata for the call is stored
  @return read_values: The values read from storage
  */
  function readMultiUint(uint _ptr) internal view returns (uint[] read_values) {
    bool success;
    assembly {
      // Minimum length for 'readMulti' - 1 location is 0x84
      if lt(mload(_ptr), 0x84) { revert (0, 0) }
      // Read from storage
      success := staticcall(gas, caller, add(0x20, _ptr), mload(_ptr), 0, 0)
      // If call succeed, get return information
      if gt(success, 0) {
        // Ensure data will not be copied beyond the pointer
        if gt(sub(returndatasize, 0x20), mload(_ptr)) { revert (0, 0) }
        // Copy returned data to pointer, overwriting it in the process
        // Copies returndatasize, but ignores the initial read offset so that the bytes32[] returned in the read is sitting directly at the pointer
        returndatacopy(_ptr, 0x20, sub(returndatasize, 0x20))
        // Set return bytes32[] to pointer, which should now have the stored length of the returned array
        read_values := _ptr
      }
    }
    if (!success)
      triggerException(ERR_READ_FAILED);
  }

  /*
  Executes a 'read' function call, given a pointer to a calldata buffer

  @param _ptr: A pointer to the location in memory where the calldata for the call is stored
  @return read_value: The value read from storage
  */
  function readSingle(uint _ptr) internal view returns (bytes32 read_value) {
    bool success;
    assembly {
      // Length for 'read' buffer must be 0x44
      if iszero(eq(mload(_ptr), 0x44)) { revert (0, 0) }
      // Read from storage, and store return to pointer
      success := staticcall(gas, caller, add(0x20, _ptr), mload(_ptr), _ptr, 0x20)
      // If call succeeded, store return at pointer
      if gt(success, 0) { read_value := mload(_ptr) }
    }
    if (!success)
      triggerException(ERR_READ_FAILED);
  }

  /*
  Reverts state changes, but passes message back to caller

  @param _message: The message to return to the caller
  */
  function triggerException(bytes32 _message) internal pure {
    assembly {
      mstore(0, _message)
      revert(0, 0x20)
    }
  }

  // Parses context array and returns execution id, sender address, and sent wei amount
  function parse(bytes _context) internal pure returns (bytes32 exec_id, address from, uint wei_sent) {
    assembly {
      exec_id := mload(add(0x20, _context))
      from := mload(add(0x40, _context))
      wei_sent := mload(add(0x60, _context))
    }
    // Ensure sender and exec id are valid
    if (from == address(0) || exec_id == bytes32(0))
      triggerException(ERR_UNKNOWN_CONTEXT);
  }
}
