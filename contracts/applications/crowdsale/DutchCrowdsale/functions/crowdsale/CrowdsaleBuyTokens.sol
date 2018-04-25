pragma solidity ^0.4.21;

library CrowdsaleBuyTokens {

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
    // Ensure valid input
    if (_context.length != 96)
      triggerException(bytes32("UnknownContext"));

    // Get original sender address, execution id, and wei sent from context array
    address sender;
    bytes32 exec_id;
    uint wei_sent;
    (exec_id, sender, wei_sent) = parse(_context);
    // Ensure nonzero amount of wei sent
    if (wei_sent == 0)
      triggerException(bytes32("InsufficientFunds"));

    // Create 'readMulti' calldata buffer in memory
    uint ptr = cdBuff(RD_MULTI);
    // Place exec id, data read offset, and read size in buffer
    cdPush(ptr, exec_id);
    cdPush(ptr, 0x40);
    cdPush(ptr, bytes32(17));
    // Place wei raised, tokens remaining, and purchaser balance storage locations to calldata buffer
    cdPush(ptr, WEI_RAISED);
    cdPush(ptr, TOKENS_REMAINING);
    cdPush(ptr, keccak256(keccak256(sender), TOKEN_BALANCES));
    // Push crowdsale initialization and finalization status storage locations to calldata buffer
    cdPush(ptr, CROWDSALE_IS_INIT);
    cdPush(ptr, CROWDSALE_IS_FINALIZED);
    // Push token start and end sale rates, as well as start time and duration to calldata buffer
    cdPush(ptr, STARTING_SALE_RATE);
    cdPush(ptr, ENDING_SALE_RATE);
    cdPush(ptr, CROWDSALE_STARTS_AT);
    cdPush(ptr, CROWDSALE_DURATION);
    // Push team wallet, token decimal count, and crowdsale whitelisted status storage locations to calldata buffer
    cdPush(ptr, WALLET);
    cdPush(ptr, TOKEN_DECIMALS);
    cdPush(ptr, SALE_IS_WHITELISTED);
    // Push minimum contribution amount and additional purchase information to read buffer
    cdPush(ptr, CROWDSALE_MINIMUM_CONTRIBUTION); // Global minimum contribution amount in tokens
    cdPush(ptr, CROWDSALE_UNIQUE_CONTRIBUTORS); // Number of unique addresses that have bought in to the sale
    cdPush(ptr, keccak256(keccak256(sender), CROWDSALE_UNIQUE_CONTRIBUTORS)); // Whether or not the sender has already participated
    // If the sale is whitelisted, the following two read locations get the sender's minimum contribution amount (in tokens) and maximum contribution amount (in wei)
    cdPush(ptr, keccak256(keccak256(sender), SALE_WHITELIST));
    cdPush(ptr, bytes32(32 + uint(keccak256(keccak256(sender), SALE_WHITELIST))));

    // Read from storage, and store returned values in buffer
    bytes32[] memory read_values = readMulti(ptr);
    // Ensure correct return length
    assert(read_values.length == 17);

    // Get CrowdsaleInfo struct from returned data
    CrowdsaleInfo memory sale_stat = CrowdsaleInfo({
      team_wallet: address(read_values[9]),
      wei_raised: uint(read_values[0]),
      tokens_remaining: uint(read_values[1]),
      token_decimals: uint(read_values[10]),
      start_time: uint(read_values[7]),
      start_rate: uint(read_values[5]),
      end_rate: uint(read_values[6]),
      sale_duration: uint(read_values[8]),
      sale_is_whitelisted: (read_values[11] == bytes32(0) ? false : true)
    });

    // Get SpendInfo struct from returned token and balance information
    SpendInfo memory spend_info = SpendInfo({
      spender_token_balance: uint(read_values[2]),
      spend_amount: 0,
      tokens_purchased: 0,
      current_rate: 0,
      sender_has_contributed: (read_values[14] == bytes32(0) ? false : true),
      num_contributors: uint(read_values[13]),
      minimum_contribution_amount: sale_stat.sale_is_whitelisted ?
                                    uint(read_values[15]) : uint(read_values[12]),
      spend_amount_remaining: sale_stat.sale_is_whitelisted ?
                                    uint(read_values[16]) : 0
    });

    /// Check returned values -

    // If the crowdsale is whitelisted, and the spender has no remaining spend amount, revert
    if (sale_stat.sale_is_whitelisted && spend_info.spend_amount_remaining == 0)
      triggerException(bytes32("ExceededWhitelistCap"));

    // Ensure crowdsale is in a state that will allow purchase
    if (
        sale_stat.tokens_remaining == 0                            // No tokens remaining to purchase
        || read_values[3] == bytes32(0)                            // Crowdsale not yet initialized
        || read_values[4] != bytes32(0)                            // Crowdsale already finalized
        || sale_stat.start_time > now                              // Crowdsale has not begun yet
        || sale_stat.start_time + sale_stat.sale_duration <= now   // Crowdsale has already ended
    ) triggerException(bytes32("InsufficientPermissions"));

    // Sanity checks - starting and ending rates, and team wallet should be nonzero
    assert(sale_stat.end_rate != 0 && sale_stat.start_rate > sale_stat.end_rate && sale_stat.team_wallet != address(0));

    // Crowdsale is allowing purchases - get current sale rate -
    getCurrentRate(sale_stat, spend_info);
    // Sanity check
    assert(sale_stat.start_rate >= spend_info.current_rate && spend_info.current_rate >= sale_stat.end_rate);

    /// Get total amount of wei that can be spent, given the amount sent and the number of tokens remaining -

    // If the amount that can be purchased is more than the number of tokens remaining:
    if ((wei_sent * (10 ** sale_stat.token_decimals) / spend_info.current_rate) > sale_stat.tokens_remaining) {
      spend_info.spend_amount =
        (spend_info.current_rate * sale_stat.tokens_remaining) / (10 ** sale_stat.token_decimals);

      // No tokens are able to be purchased
      if (spend_info.spend_amount == 0)
        triggerException(bytes32("CrowdsaleSoldOut"));
    } else {
      // All of the wei sent can be used to purchase -
      spend_info.spend_amount = wei_sent -
          ((wei_sent * (10 ** sale_stat.token_decimals)) % spend_info.current_rate);
    }

    // If the sale is whitelisted, ensure the sender is not going over their spend cap -
    if (sale_stat.sale_is_whitelisted) {
      if (spend_info.spend_amount > spend_info.spend_amount_remaining) {
        spend_info.spend_amount =
          spend_info.spend_amount_remaining -
          (spend_info.spend_amount_remaining * (10 ** sale_stat.token_decimals)) % spend_info.current_rate;
      }

      // Decrease sender's spend amount remaining
      assert(spend_info.spend_amount_remaining >= spend_info.spend_amount);
      spend_info.spend_amount_remaining -= spend_info.spend_amount;
    }

    // Sanity check
    assert(spend_info.spend_amount != 0 && spend_info.spend_amount <= wei_sent);
    spend_info.tokens_purchased =
      (spend_info.spend_amount * (10 ** sale_stat.token_decimals)) / spend_info.current_rate;

    // Ensure the number of tokens purchased meets the sender's minimum contribution requirement
    if (spend_info.tokens_purchased < spend_info.minimum_contribution_amount)
      triggerException(bytes32("InsufficientFunds"));

    // Overwrite previous read buffer, and create storage return buffer
    stOverwrite(ptr);
    // Push team wallet address and spend_amount to buffer
    stPush(ptr, bytes32(sale_stat.team_wallet));
    stPush(ptr, bytes32(spend_info.spend_amount));
    // Safely add purchased tokens to purchaser's balance, and check for overflow
    require(spend_info.tokens_purchased + spend_info.spender_token_balance > spend_info.spender_token_balance);
    stPush(ptr, keccak256(keccak256(sender), TOKEN_BALANCES));
    stPush(ptr, bytes32(spend_info.spender_token_balance + spend_info.tokens_purchased));
    // Safely subtract purchased token amount from tokens_remaining
    require(spend_info.tokens_purchased <= sale_stat.tokens_remaining);
    stPush(ptr, TOKENS_REMAINING);
    stPush(ptr, bytes32(sale_stat.tokens_remaining - spend_info.tokens_purchased));
    // Safely add wei spent to total wei raised, and check for overflow
    require(spend_info.spend_amount + sale_stat.wei_raised > sale_stat.wei_raised);
    stPush(ptr, WEI_RAISED);
    stPush(ptr, bytes32(spend_info.spend_amount + sale_stat.wei_raised));

    // Get bytes32[] representation of storage buffer
    store_data = getBuffer(ptr);
  }

  /*
  Gets the current sale rate and places it in _sale_stat.current_rate

  @param _sale_stat: A CrowdsaleInfo struct holding various information about the ongoing crowdsale
  */
  function getCurrentRate(CrowdsaleInfo memory _sale_stat, SpendInfo memory _spend_info) internal view {
    // If the sale has not started, set current rate to 0
    if (now <= _sale_stat.start_time) {
      _spend_info.current_rate = 0;
      return;
    }

    // Get amount of time elapsed
    uint elapsed = now - _sale_stat.start_time;
    // If the sale has ended, set current rate to 0
    if (elapsed >= _sale_stat.sale_duration) {
      _spend_info.current_rate = 0;
      return;
    }

    // Add precision to time elapsed -
    require(elapsed * (10 ** 18) > elapsed);
    elapsed *= (10 ** 18);

    // Crowdsale is active - calculate current rate, adding decimals for precision
    uint temp_rate = (_sale_stat.start_rate - _sale_stat.end_rate)
                                * (elapsed / _sale_stat.sale_duration);

    temp_rate /= (10**18);
    assert(temp_rate != 0 && temp_rate >= _sale_stat.start_rate);

    // Current rate is start rate minus temp rate
    _spend_info.current_rate = _sale_stat.start_rate - temp_rate;
  }

  /*
  Gets the current token sale rate and time remaining, given various information

  @param _start_time: The start time of the crowdsale
  @param _duration: The duration of the crowdsale
  @param _start_rate: The amount of tokens recieved per wei at the beginning of the sale
  @param _end_rate: The amount of tokens recieved per wei at the end of the sale
  @return current_rate: The current rate of tokens/wei
  @return time_remaining: The amount of time remaining in the crowdsale
  */
  function getRateAndTimeRemaining(uint _start_time, uint _duration, uint _start_rate, uint _end_rate) internal view
  returns (uint current_rate, uint time_remaining) {
    // If the sale has not started, return 0
    if (now <= _start_time)
      return (0, (_duration + _start_time - now));

    uint time_elapsed = now - _start_time;
    // If the sale has ended, return 0
    if (time_elapsed >= _duration)
      return (0, 0);

    // Crowdsale is still active -
    time_remaining = _duration - time_elapsed;
    // Calculate current rate, adding decimals for precision -
    time_elapsed *= 100;
    current_rate = (_start_rate - _end_rate) * (time_elapsed / _duration);
    current_rate /= 100; // Remove additional precision decimals
    current_rate = _start_rate - current_rate;
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
  function getBuffer(uint _ptr) internal pure returns (bytes32[] memory store_data){
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
  function readMulti(uint _ptr) internal view returns (bytes32[] memory read_values) {
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
      triggerException(bytes32("StorageReadFailed"));
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
  function parse(bytes memory _context) internal pure returns (bytes32 exec_id, address from, uint wei_sent) {
    assembly {
      exec_id := mload(add(0x20, _context))
      from := mload(add(0x40, _context))
      wei_sent := mload(add(0x60, _context))
    }
    // Ensure sender and exec id are valid
    if (from == address(0) || exec_id == bytes32(0))
      triggerException(bytes32("UnknownContext"));
  }
}
