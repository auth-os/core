pragma solidity ^0.4.21;

library CrowdsaleBuyTokens {

  /// CROWDSALE STORAGE ///

  // Whether the crowdsale and token are initialized, and the application is ready to run
  bytes32 public constant CROWDSALE_IS_INIT = keccak256("crowdsale_is_init");

  // Whether or not the crowdsale is post-purchase
  bytes32 public constant CROWDSALE_IS_FINALIZED = keccak256("crowdsale_is_finalized");

  // Storage location of team funds wallet
  bytes32 public constant WALLET = keccak256("crowdsale_wallet");

  // Storage location of amount of wei raised during the crowdsale, total
  bytes32 public constant WEI_RAISED = keccak256("crowdsale_wei_raised");

  // Storage location for the amount of tokens still available for purchase in this crowdsale
  bytes32 public constant TOKENS_REMAINING = keccak256("crowdsale_tokens_remaining");

  // Storage location of token per wei rate
  bytes32 public constant SALE_RATE = keccak256("crowdsale_sale_rate");

  // Storage location of crowdsale start time
  bytes32 public constant CROWDSALE_STARTS_AT = keccak256("crowdsale_starts_at");

  // Storage location of crowdsale end time
  bytes32 public constant CROWDSALE_ENDS_AT = keccak256("crowdsale_ends_at");

  /// TOKEN STORAGE ///

  // Storage location for token totalSupply
  bytes32 public constant TOKEN_TOTAL_SUPPLY = keccak256("token_total_supply");

  // Storage seed for user balances mapping
  bytes32 public constant TOKEN_BALANCES = keccak256("token_balances");

  /// FUNCTION SELECTORS ///

  // Function selector for storage 'readMulti'
  // readMulti(bytes32 exec_id, bytes32[] locations)
  bytes4 public constant RD_MULTI = bytes4(keccak256("readMulti(bytes32,bytes32[])"));

  /// EXCEPTION MESSAGES ///

  bytes32 public constant ERR_UNKNOWN_CONTEXT = bytes32("UnknownContext"); // Malformed '_context' array
  bytes32 public constant ERR_INSUFFICIENT_PERMISSIONS = bytes32("InsufficientPermissions"); // Action not allowed
  bytes32 public constant ERR_READ_FAILED = bytes32("StorageReadFailed"); // Read from storage address failed
  bytes32 public constant ERR_INSUFFICIENT_FUNDS = bytes32("InsufficientFunds"); // Incorrect amount of wei sent

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

    // Get the original sender address, execution id, and amount of wei sent to the storage contract by the sender
    address sender;
    bytes32 exec_id;
    uint wei_sent;
    (exec_id, sender, wei_sent) = parse(_context);
    // Ensure nonzero amount of wei sent
    if (wei_sent == 0)
      triggerException(ERR_INSUFFICIENT_FUNDS);

    // Create 'readMulti' calldata buffer in memory
    uint ptr = cdBuff(RD_MULTI);
    // Place exec id, data read offset, and read size in buffer
    cdPush(ptr, exec_id);
    cdPush(ptr, bytes32(64));
    cdPush(ptr, bytes32(10));
    // Place wei raised, tokens remaining, token total supply, and purchaser balance storage locations to calldata buffer
    cdPush(ptr, WEI_RAISED);
    cdPush(ptr, TOKENS_REMAINING);
    cdPush(ptr, TOKEN_TOTAL_SUPPLY);
    cdPush(ptr, keccak256(keccak256(sender), TOKEN_BALANCES));
    // Push crowdsale initialization and finalization status storage locations to calldata buffer
    cdPush(ptr, CROWDSALE_IS_INIT);
    cdPush(ptr, CROWDSALE_IS_FINALIZED);
    // Push token sale rate and crowdsale start and end time storage locations to calldata buffer
    cdPush(ptr, SALE_RATE);
    cdPush(ptr, CROWDSALE_STARTS_AT);
    cdPush(ptr, CROWDSALE_ENDS_AT);
    // Push team wallet storage location to calldata buffer
    cdPush(ptr, WALLET);

    // Read from storage, and store returned values in buffer
    bytes32[] memory read_values = readMulti(ptr);

    uint total_supply = uint(read_values[2]);
    uint tokens_remaining = uint(read_values[1]);
    uint spend_amount;
    uint sale_rate = uint(read_values[6]);


    // Check return values -

    // Ensure crowdsale is in a state that will allow purchase
    if (
        tokens_remaining == 0 || // No tokens remaining to purchase
        read_values[4] == bytes32(0) || // Crowdsale not yet initialized
        read_values[5] != bytes32(0) || // Crowdsale already finalized
        read_values[7] > bytes32(now) || // Crowdsale has not begun yet
        read_values[8] < bytes32(now) || // Crowdsale has already ended
        tokens_remaining < sale_rate // Fewer tokens remaining than sale rate
    ) {
      triggerException(ERR_INSUFFICIENT_PERMISSIONS);
    }
    // Sanity checks - sale rate and wallet should be nonzero
    assert(sale_rate != 0 && read_values[9] != bytes32(0));

    // Crowdsale is allowing purchases - get number of tokens that can be purchased

    // If wei_sent * sale_rate is more than the number of tokens remaining:
    if (wei_sent * sale_rate > tokens_remaining) {
      // Get amount of wei able to be spent
      spend_amount =
        (tokens_remaining - (tokens_remaining % sale_rate)) / sale_rate;

      // No tokens are able to be purchased
      if (spend_amount == 0)
        triggerException(ERR_INSUFFICIENT_PERMISSIONS);
    } else {
      spend_amount = wei_sent;
    }
    // Sanity check
    assert(spend_amount != 0 && spend_amount <= wei_sent);

    // Create storage return buffer
    ptr = stBuff();
    // Push team wallet address and spend_amount to buffer
    stPush(ptr, bytes32(read_values[9]));
    stPush(ptr, bytes32(spend_amount));
    // Add purchased tokens to purchaser's balance, and check for overflow
    stPush(ptr, keccak256(keccak256(sender), TOKEN_BALANCES));
    require((sale_rate * spend_amount) + uint(read_values[3]) > uint(read_values[3]));
    stPush(ptr, bytes32(sale_rate * spend_amount + uint(read_values[3])));
    // Subtract purchased token amount from tokens_remaining
    stPush(ptr, TOKENS_REMAINING);
    stPush(ptr, bytes32(tokens_remaining - (spend_amount * sale_rate)));
    // Add tokens minted to total token supply, and check for overflow
    stPush(ptr, TOKEN_TOTAL_SUPPLY);
    require((sale_rate * spend_amount) + total_supply > total_supply);
    stPush(ptr, bytes32(total_supply + (sale_rate * spend_amount)));
    // Add wei spent to total wei raised, and check for overflow
    stPush(ptr, WEI_RAISED);
    require(spend_amount + uint(read_values[0]) > uint(read_values[0]));
    stPush(ptr, bytes32(spend_amount + uint(read_values[0])));

    // Get bytes32[] representation of storage buffer
    store_data = getBuffer(ptr);
  }

  /*
  Returns the last value stored in the buffer

  @param _ptr: A pointer to the buffer
  @return last_val: The final value stored in the buffer
  */
  function top(uint _ptr) internal pure returns (bytes32 last_val) {
    assembly {
      let len := mload(_ptr)
      // Add 0x20 to length to account for the length itself
      last_val := mload(add(0x20, add(len, _ptr)))
    }
  }

  /*
  Creates a buffer for return data storage. Buffer pointer stores the lngth of the buffer

  @return ptr: The location in memory where the length of the buffer is stored - elements stored consecutively after this location
  */
  function stBuff() internal pure returns (uint ptr) {
    assembly {
      // Get buffer location - free memory
      ptr := mload(0x40)
      // Update free-memory pointer - it's important to note that this is not actually free memory, if the pointer is meant to expand
      mstore(0x40, add(0x20, ptr))
    }
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
      mstore(_ptr, div(0x20, mload(_ptr)))
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
