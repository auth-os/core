pragma solidity ^0.4.21;

library CrowdsaleConsole {

  /// CROWDSALE STORAGE ///

  // Storage location of crowdsale admin address
  bytes32 public constant ADMIN = keccak256("admin");

  // Whether the crowdsale and token are initialized, and the application is ready to run
  bytes32 public constant CROWDSALE_IS_INIT = keccak256("crowdsale_is_init");

  // Whether or not the crowdsale is post-purchase
  bytes32 public constant CROWDSALE_IS_FINALIZED = keccak256("crowdsale_is_finalized");

  // Storage location of a list of the tiers the crowdsale will have
  // Each tier mimics the following struct: { uint token_sell_cap; uint end_time; }
  bytes32 public constant CROWDSALE_TIERS = keccak256("crowdsale_tier_list");

  // Storage location of the current tier of the crowdsale, and its index in the crowdsale tier list
  // Mimics the following struct: { uint token_sell_cap; uint end_time; uint tier_list_index; }
  bytes32 public constant CROWDSALE_CURRENT_TIER = keccak256("crowdsale_current_tier");

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

  // Storage location for the number of tokens minted during the crowdsale
  bytes32 public constant TOTAL_TOKENS_MINTED = keccak256("crowdsale_tokens_minted");

  /// TOKEN STORAGE ///

  // Storage location for token name
  bytes32 public constant TOKEN_NAME = keccak256("token_name");

  // Storage location for token ticker symbol
  bytes32 public constant TOKEN_SYMBOL = keccak256("token_symbol");

  // Storage location for token decimals
  bytes32 public constant TOKEN_DECIMALS = keccak256("token_decimals");

  // Storage location for token totalSupply
  bytes32 public constant TOKEN_TOTAL_SUPPLY = keccak256("token_total_supply");

  // Storage seed for user balances mapping
  bytes32 public constant TOKEN_BALANCES = keccak256("token_balances");

  // Storage seed for user allowances mapping
  bytes32 public constant TOKEN_ALLOWANCES = keccak256("token_allowances");

  // Storage seed for token 'transfer agent' status for any address
  // Transfer agents can transfer tokens, even if the crowdsale has not yet been finalized
  bytes32 public constant TOKEN_TRANSFER_AGENTS = keccak256("token_transfer_agents");

  /// Storage location for an array of addresses with some form of reserved tokens
  bytes32 public constant TOKEN_RESERVED_DESTINATIONS = keccak256("token_reserved_dest_list");

  // Storage seed for reserved token information for a given address
  // Maps an address for which tokens are reserved to a struct:
  // ReservedInfo { uint destination_list_index; uint num_tokens; uint num_percent; uint percent_decimals; }
  // destination_list_index is the address's index in TOKEN_RESERVED_DESTINATIONS, plus 1. 0 means the address is not in the list
  bytes32 public constant TOKEN_RESERVED_ADDR_INFO = keccak256("token_reserved_addr_info");

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

  // Modifier - will only allow access to a crowdsale's admin address
  // Additionally, crowdasle must not be initialized
  modifier onlyAdminAndNotInit(bytes _context) {
    if (_context.length != 96)
      triggerException(ERR_UNKNOWN_CONTEXT);
    // Get sender and exec id for this instance
    address sender;
    bytes32 exec_id;
    (exec_id, sender, ) = parse(_context);

    // Create 'readMulti' calldata buffer in memory
    uint ptr = cdBuff(RD_MULTI);
    // Place exec id, data read offset, and read size in buffer
    cdPush(ptr, exec_id);
    cdPush(ptr, bytes32(64));
    cdPush(ptr, bytes32(2));
    // Place admin storage location and crowdsale status storage location in calldata
    cdPush(ptr, ADMIN);
    cdPush(ptr, CROWDSALE_IS_INIT);
    // Read from storage, and store return to buffer
    bytes32[] memory read_values = readMulti(ptr);

    // Check that the sender is the admin address and that the crowdsale is not yet initialized
    if (read_values[0] != bytes32(sender) || read_values[1] != bytes32(0))
      triggerException(ERR_INSUFFICIENT_PERMISSIONS);

    // All checks passed - sender is crowdsale admin, and crowdsale is not initialized
    _;
  }


  /*
  Allows the admin of a crowdsale to add token information, prior to crowdsale initialization completion

  @param _name: The name of the token to initialize
  @param _symbol: The ticker symbol of the token to initialize
  @param _context: The execution context for this application - a 96-byte array containing (in order):
    1. Application execution id
    2. Original script sender (address, padded to 32 bytes)
    3. Wei amount sent with transaction to storage
  @return store_data: A formatted storage request - first 64 bytes designate a forwarding address (and amount) for any wei sent
  */
  function initCrowdsaleToken(bytes32 _name, bytes32 _symbol, uint _decimals, bytes _context) public onlyAdminAndNotInit(_context) view
  returns (bytes32[] store_data) {
    // Ensure valid input
    require(_name != bytes32(0) && _symbol != bytes32(0) && _decimals > 0);

    // Create memory buffer for return data
    uint ptr = stBuff();

    // First two slots, information on wei sent and destination, are blank (this function does not use eth)
    stPush(ptr, 0);
    stPush(ptr, 0);
    // Place token name, symbol, and decimals in return data buffer
    stPush(ptr, TOKEN_NAME);
    stPush(ptr, _name);
    stPush(ptr, TOKEN_SYMBOL);
    stPush(ptr, _symbol);
    stPush(ptr, TOKEN_DECIMALS);
    stPush(ptr, _decimals);

    // Get bytes32[] storage request array from buffer
    store_data = getBuffer(ptr);
  }

  /*
  Allows the admin to create a new tier for the crowdsale and append it to the end of the list of crowdsale tiers

  @param _token_sell_cap: The maximum amount of tokens that will be sold this tier
  @param _end_time: The end time of this tier (must be after the end time of the previous tier)
  @param _context: The execution context for this application - a 96-byte array containing (in order):
    1. Application execution id
    2. Original script sender (address, padded to 32 bytes)
    3. Wei amount sent with transaction to storage
  @return store_data: A formatted storage request - first 64 bytes designate a forwarding address (and amount) for any wei sent
  */
  function createCrowdsaleTier(uint _token_sell_cap, uint _start_time, uint _end_time, bytes _context) public onlyAdminAndNotInit(_context) view
  returns (bytes32[] store_data) {

  }

  /*
  Allows the admin of a crowdsale to revise crowdsale start and end time, provided the crowdsale is not already initialized

  @param _start_time: The new start time of the crowdsale
  @param _end_time: The new end time of the crowdsale
  @param _context: The execution context for this application - a 96-byte array containing (in order):
    1. Application execution id
    2. Original script sender (address, padded to 32 bytes)
    3. Wei amount sent with transaction to storage
  @return store_data: A formatted storage request - first 64 bytes designate a forwarding address (and amount) for any wei sent
  */
  function setCrowdsaleTimes(uint _start_time, uint _end_time, bytes _context) public onlyAdminAndNotInit(_context) view returns (bytes32[] store_data) {
    // Ensure valid input
    require(_start_time >= now && _end_time > _start_time);

    // Allocate space for return storage request -
    store_data = new bytes32[](6);

    // First two slots are blank - this function does not accept eth
    // Store crowdsale start and end times
    store_data[2] = CROWDSALE_STARTS_AT;
    store_data[3] = bytes32(_start_time);
    store_data[4] = CROWDSALE_ENDS_AT;
    store_data[5] = bytes32(_end_time);
  }

  struct CrowdsaleInit {
    bytes4 rd_multi;
    bytes32 admin_storage;
    bytes32 crowdsale_init_status_storage;
    bytes32 token_name_storage;
  }

  /*
  Allows the admin of a crowdsale to finalize the initialization process for this crowdsale, locking its details

  @param _context: The execution context for this application - a 96-byte array containing (in order):
    1. Application execution id
    2. Original script sender (address, padded to 32 bytes)
    3. Wei amount sent with transaction to storage
  @return store_data: A formatted storage request - first 64 bytes designate a forwarding address (and amount) for any wei sent
  */
  function initializeCrowdsale(bytes _context) public onlyAdminAndNotInit(_context) view
  returns (bytes32[] store_data) {
    // Ensure valid input
    if (_context.length != 96)
      triggerException(ERR_UNKNOWN_CONTEXT);

    // Get execuion id from _context
    bytes32 exec_id;
    (exec_id, , ) = parse(_context);

    // Create 'read' calldata buffer in memory
    uint ptr = cdBuff(RD_SING);

    // Place exec id and token name storage location in buffer
    cdPush(ptr, exec_id);
    cdPush(ptr, TOKEN_NAME);

    // Read from storage and check that the token name is nonzero
    if (readSingle(ptr) == bytes32(0))
      triggerException(ERR_INSUFFICIENT_PERMISSIONS);

    // Overwrite read buffer with storage buffer
    stOverwrite(ptr);
    // Push payment information (wei sent and destination) to buffer
    stPush(ptr, 0);
    stPush(ptr, 0);
    // Push crowdsale initialization status location to buffer
    stPush(ptr, CROWDSALE_IS_INIT);
    stPush(ptr, bytes32(1));
    // Get bytes32[] storage request array from buffer
    store_data = getBuffer(ptr);
  }

  struct CrowdsaleFinalize {
    bytes4 rd_multi;
    bytes32 admin_storage;
    bytes32 crowdsale_init_status_storage;
    bytes32 crowdsale_finalized_status_storage;
    bytes32 token_total_supply_storage;
  }

  /*
  Allows the crowdsale admin to finalize a crowdsale, provided it is fully initialized, and not already finalized

  @param _context: The execution context for this application - a 96-byte array containing (in order):
    1. Application execution id
    2. Original script sender (address, padded to 32 bytes)
    3. Wei amount sent with transaction to storage
  @return store_data: A formatted storage request - first 64 bytes designate a forwarding address (and amount) for any wei sent
  */
  function finalizeCrowdsale(bytes _context) public view returns (bytes32[] store_data) {
    // Ensure valid input
    if (_context.length != 96)
      triggerException(ERR_UNKNOWN_CONTEXT);

    // Get sender and exec id for this app instance
    address sender;
    bytes32 exec_id;
    (exec_id, sender, ) = parse(_context);

    uint token_total_supply;

    // Create 'readMulti' calldata buffer in memory
    uint ptr = cdBuff(RD_MULTI);
    // Push exec id, data read offset, and read size to calldata buffer
    cdPush(ptr, exec_id);
    cdPush(ptr, bytes32(64));
    cdPush(ptr, bytes32(4));
    // Push admin address, crowdsale init status, crowdsale finalization status, and total token supply storage locations in calldata
    cdPush(ptr, ADMIN);
    cdPush(ptr, CROWDSALE_IS_INIT);
    cdPush(ptr, CROWDSALE_IS_FINALIZED);
    cdPush(ptr, TOKEN_TOTAL_SUPPLY);
    // Read from storage, and store returned data in buffer
    bytes32[] memory read_values = readMulti(ptr);
    // Check that the sender is the admin address, and that the crowdsale is initialized, but not finalized
    if (
      read_values[0] != bytes32(sender)
      || read_values[1] == bytes32(0) // Crowdsale init status is false
      || read_values[2] == bytes32(1) // Crowdsale finalization status is true
    ) {
      triggerException(ERR_INSUFFICIENT_PERMISSIONS);
    }

    // Get token total supply from returned data
    bytes32 token_total_supply = read_values[3];

    // Create storage buffer, overwriting the previous read buffer
    stOverwrite(ptr);
    // Push payment information (0 wei sent and 0 destination address) to storage buffer
    stPush(ptr, 0);
    stPush(ptr, 0);
    // Push crowdsale finalization status to buffer
    stPush(ptr, CROWDSALE_IS_FINALIZED);
    stPush(ptr, bytes32(1));
    // Push total number of tokens minted to buffer
    stPush(ptr, TOTAL_TOKENS_MINTED);
    stPush(ptr, token_total_supply);

    // Get bytes32[] storage request array from buffer
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
