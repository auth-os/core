pragma solidity ^0.4.21;

library TokenConsole {

  /// CROWDSALE STORAGE ///

  // Storage location of crowdsale admin address
  bytes32 public constant ADMIN = keccak256("admin");

  // Whether the crowdsale and token are initialized, and the application is ready to run
  bytes32 public constant CROWDSALE_IS_INIT = keccak256("crowdsale_is_init");

  // Whether or not the crowdsale is post-purchase
  bytes32 public constant CROWDSALE_IS_FINALIZED = keccak256("crowdsale_is_finalized");

  // Storage location for the number of tokens minted during the crowdsale
  bytes32 public constant TOTAL_TOKENS_MINTED = keccak256("crowdsale_tokens_minted");

  /// TOKEN STORAGE ///

  // Storage seed for user balances mapping
  bytes32 public constant TOKEN_BALANCES = keccak256("token_balances");

  // Storage location for token totalSupply
  bytes32 public constant TOKEN_TOTAL_SUPPLY = keccak256("token_total_supply");

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

  /*
  Allows the admin to set an address's transfer agent status - transfer agents can transfer tokens prior to the end of the crowdsale

  @param _agent: The address whose transfer agent status will be updated
  @param _is_transfer_agent: If true, address will be set as a transfer agent
  @param _context: The execution context for this application - a 96-byte array containing (in order):
    1. Application execution id
    2. Original script sender (address, padded to 32 bytes)
    3. Wei amount sent with transaction to storage
  @return store_data: A formatted storage request - first 64 bytes designate a forwarding address (and amount) for any wei sent
  */
  function setTransferAgentStatus(address _agent, bool _is_transfer_agent, bytes _context) public view returns (bytes32[] store_data) {
    // Ensure valid input
    require(_agent != address(0));
    if (_context.length != 96)
      triggerException(ERR_UNKNOWN_CONTEXT);

    // Parse context array and get sender address and execution id
    address sender;
    bytes32 exec_id;
    (exec_id, sender, ) = parse(_context);

    // Create 'read' calldata buffer in memory
    uint ptr = cdBuff(RD_SING);
    // Place exec id and admin storage address location in memory
    cdPush(ptr, exec_id);
    cdPush(ptr, ADMIN);

    // Read from storage and store return in buffer -
    // Check that sender is equal to the returned admin address
    if (bytes32(sender) != readSingle(ptr))
      triggerException(ERR_INSUFFICIENT_PERMISSIONS);

    // Sender is admin address - create storage buffer (overwrite previous read buffer), and set return values -
    stOverwrite(ptr);
    // Push two empty slots to buffer, to represent payment infomation (this function does not accept ETH)
    stPush(ptr, 0);
    stPush(ptr, 0);
    // Push address transfer agent status storage location in storage buffer, followed by the passed-in status
    stPush(ptr, keccak256(keccak256(_agent), TOKEN_TRANSFER_AGENTS));
    stPush(ptr, (_is_transfer_agent ? bytes32(1) : bytes32(0))); // 1, if _is_transfer_agent - 2, otherwise

    // Get bytes32[] representation of storage buffer
    store_data = getBuffer(ptr);
  }

  /*
  Allows the admin to set multiple reserved token destinations for a crowdsale, which will be awarded at crowdsale finalization
  Each array index corresponds to the same indices in the other arrays
  If an address is repeated in _destinations, it will be ignored

  @param _destinations: An array of addresses for which tokens will be reserved
  @param _num_tokens: An array of token amounts to reserve for each address
  @param _num_percents: An array of percentages to reserve for each address. Percents are calculated as percent of tokens existing at end of crowdsale
  @param _percent_decimals: An array of decimal amounts coresponding to each percentage - used for precision
  @param _context: The execution context for this application - a 96-byte array containing (in order):
    1. Application execution id
    2. Original script sender (address, padded to 32 bytes)
    3. Wei amount sent with transaction to storage
  @return store_data: A formatted storage request - first 64 bytes designate a forwarding address (and amount) for any wei sents
  */
  function updateMultipleReservedTokens(address[] _destinations, uint[] _num_tokens, uint[] _num_percents, uint[] _percent_decimals, bytes _context) public view
  returns (bytes32[] store_data) {
    // Ensure valid input
    require(
      _destinations.length == _num_tokens.length
      && _num_tokens.length == _num_percents.length
      && _num_percents.length == _percent_decimals.length
      && _destinations.length > 0
    );
    if (_context.length != 96)
      triggerException(ERR_UNKNOWN_CONTEXT);

    // Parse context array and get sender address and execution id
    address sender;
    bytes32 exec_id;
    (exec_id, sender, ) = parse(_context);

    // Create 'readMulti' calldata buffer in memory
    uint ptr = cdBuff(RD_MULTI);
    // Place exec id, data read offset, and read size in buffer
    cdPush(ptr, exec_id);
    cdPush(ptr, bytes32(64));
    // Reading data for all input destinations, as well as crowdsale destinations list length, crowdsale admin address permission, and crowdsale initialization status locations
    cdPush(ptr, bytes32(3 + _destinations.length));
    // Push crowdsale admin address permission location to buffer
    cdPush(ptr, ADMIN);
    // Push crowdsale initialization status locaiton to buffer
    cdPush(ptr, CROWDSALE_IS_INIT);
    // Add crowdsale destinations list length location to buffer
    cdPush(ptr, TOKEN_RESERVED_DESTINATIONS);
    // Loop over destinations, calculate their reserved token data storage location, and add to buffer
    for (uint i = 0; i < _destinations.length ; i++) {
      // Ensure no invalid submitted addresses
      require(_destinations[i] != address(0));
      // Destination list index for all addresses is the first slot in the reserved address struct - no need to add an offset
      cdPush(ptr, keccak256(keccak256(_destinations[i]), TOKEN_RESERVED_ADDR_INFO));
    }
    // Read from storage, and store returned values in buffer
    bytes32[] memory read_values = readMulti(ptr);
    // Ensure correct read length -
    assert(read_values.length == 3 + _destinations.length);

    // Ensure sender is admin address, and crowdsale has not been initialized
    if (read_values[0] != bytes32(sender) || read_values[1] != bytes32(0))
      triggerException(ERR_INSUFFICIENT_PERMISSIONS);

    // Create buffer for store_data return value
    ptr = stBuff();
    // Push two empty slots to buffer, to represent payment infomation (this function does not accept ETH)
    stPush(ptr, 0);
    stPush(ptr, 0);

    // Loop over read_values and input arrays - for each address which is unique within the passed-in destinations list,
    // place its reservation information in the storage buffer. Ignore duplicates in passed-in array.
    // For every address which is not a local duplicate, and also does not exist yet in the crowdsale storage reserved destination list,
    // push it to the end of the list and increment list length (in storage buffer)
    // Addresses with nonzero values in read_values are already a 'reserved token destination' in storage
    // First 3 indices in read_values are admin address, crowdsale init status, and crowdsale reserved destinations list length - begin
    // reading destinations address indices from read_values[3]

    // Sanity check - read_values length should be 3 more than _destinations length -
    assert(read_values.length == _destinations.length + 3);
    for (i = 3; i < read_values.length; i++) {
      // If value is 0, address has not already been added to the crowdsale destinations list in storage
      address to_add = _destinations[i - 3];
      if (read_values[i] == bytes32(0)) {
        // Now, check the passed-in _destinations list to see if this address is listed multiple times in the input, as we only want to store information on unique addresses
        for (uint j = i + 1; j < _destinations.length; j--) {
          // address is not unique locally - found the same address in _destinations
          if (_destinations[j] == to_add) {
            to_add = address(0);
            break;
          }
        }

        // If is_unique is zero, this address is not unique within the passed-in list - skip any additions to storage buffer
        if (to_add == address(0))
          continue;

        // Increment length
        read_values[2] = bytes32(uint(read_values[2]) + 1);
        // Get storage position (end of TOKEN_RESERVED_DESTINATIONS list), and push to buffer
        stPush(ptr, bytes32(32 * uint(read_values[2]) + uint(TOKEN_RESERVED_DESTINATIONS)));
        stPush(ptr, bytes32(to_add));
        // Store reservation information in struct at TOKEN_RESERVED_ADDR_INFO
        stPush(ptr, keccak256(keccak256(to_add), TOKEN_RESERVED_ADDR_INFO));
        stPush(ptr, bytes32(uint(read_values[2])));
      }

      // Push reservation information to storage request buffer
      stPush(ptr, bytes32(32 + uint(keccak256(keccak256(to_add), TOKEN_RESERVED_ADDR_INFO))));
      stPush(ptr, bytes32(_num_tokens[i - 3]));
      stPush(ptr, bytes32(64 + uint(keccak256(keccak256(to_add), TOKEN_RESERVED_ADDR_INFO))));
      stPush(ptr, bytes32(_num_percents[i - 3]));
      stPush(ptr, bytes32(96 + uint(keccak256(keccak256(to_add), TOKEN_RESERVED_ADDR_INFO))));
      stPush(ptr, bytes32(_percent_decimals[i - 3]));
    }
    // Finally, push new array length to storage buffer
    stPush(ptr, TOKEN_RESERVED_DESTINATIONS);
    stPush(ptr, bytes32(uint(read_values[2])));

    // Get bytes32[] representation of storage buffer
    store_data = getBuffer(ptr);
  }

  /*
  Allows the admin to remove reserved tokens for a destination, prior to crowdsale initialization

  @param _destination: The address whos reserved listing will be removed
  @param _context: The execution context for this application - a 96-byte array containing (in order):
    1. Application execution id
    2. Original script sender (address, padded to 32 bytes)
    3. Wei amount sent with transaction to storage
  @return store_data: A formatted storage request - first 64 bytes designate a forwarding address (and amount) for any wei sents
  */
  function removeReservedTokens(address _destination, bytes _context) public view returns (bytes32[] store_data) {
    // Ensure valid input
    require(_destination != address(0));
    if (_context.length != 96)
      triggerException(ERR_UNKNOWN_CONTEXT);

    // Parse context array and get sender address and execution id
    address sender;
    bytes32 exec_id;
    (exec_id, sender, ) = parse(_context);

    // Create 'readMulti' calldata buffer in memory
    uint ptr = cdBuff(RD_MULTI);
    // Place exec id, data read offset, and read size in buffer
    cdPush(ptr, exec_id);
    cdPush(ptr, bytes32(64));
    cdPush(ptr, 4);
    // Place admin address, crowdsale initialization status, reserved token list length, and _destination list index storage locations in callata
    cdPush(ptr, ADMIN);
    cdPush(ptr, CROWDSALE_IS_INIT);
    cdPush(ptr, TOKEN_RESERVED_DESTINATIONS);
    cdPush(ptr, keccak256(keccak256(_destination), TOKEN_RESERVED_ADDR_INFO));
    // Read from storage, and store returned values in buffer
    bytes32[] memory read_values = readMulti(ptr);
    // Ensure the length is 4
    assert(read_values.length == 4);

    // Ensure sender is admin address, and crowdsale has not been initialized
    if (read_values[0] != bytes32(sender) || read_values[1] != bytes32(0))
      triggerException(ERR_INSUFFICIENT_PERMISSIONS);

    // Get reservation list length
    uint reservation_len = uint(read_values[2]);
    // Get index of passed-in destination. If zero, sender is not in reserved list - revert
    uint to_remove = uint(read_values[3]);
    // Ensure that to_remove is less than or equal to reservation list length (stored indices are offset by 1)
    assert(to_remove <= reservation_len && to_remove != 0);

    // If to_remove is the final index in the list, decrement the length and remove their reserved token information struct
    if (to_remove == reservation_len) {
      // Overwrite previous buffer, and create storage return buffer
      stOverwrite(ptr);

      // Push two empty slots to buffer, to represent payment infomation (this function does not accept ETH)
      stPush(ptr, 0);
      stPush(ptr, 0);
    } else {
      // to_remove is not the final index in the list - read the address stored at the final index in the list -

      // Overwrite previous 'readMulti' calldata buffer with a 'read' buffer
      cdOverwrite(ptr, RD_SING);
      // Push exec id to buffer
      cdPush(ptr, exec_id);
      // Push final index of reserved list location to calldata buffer
      cdPush(ptr, bytes32(32 * reservation_len + uint(TOKEN_RESERVED_DESTINATIONS)));
      // Execute read from storage, and store return in buffer
      address last_index = address(readSingle(ptr));

      // Overwrite buffer and create storage return buffer
      stOverwrite(ptr);

      // Push two empty slots to the buffer, to represent payment information (this function does not accept ETH)
      stPush(ptr, 0);
      stPush(ptr, 0);
      // Push updated index (to_remove) for the address that was the final index in the destination list
      stPush(ptr, keccak256(keccak256(last_index), TOKEN_RESERVED_ADDR_INFO));
      stPush(ptr, bytes32(to_remove));
      // Push last index address to correct spot in TOKEN_RESERVED_DESTINATIONS list
      stPush(ptr, bytes32(32 * to_remove + uint(TOKEN_RESERVED_DESTINATIONS)));
      stPush(ptr, bytes32(last_index));
    }
    // Push new destinations list length to storage buffer
    stPush(ptr, TOKEN_RESERVED_DESTINATIONS);
    stPush(ptr, bytes32(reservation_len - 1));
    // Push removed address's list index location and new value (0) to storage buffer
    stPush(ptr, keccak256(keccak256(_destination), TOKEN_RESERVED_ADDR_INFO));
    stPush(ptr, 0);

    // Get bytes32[] representation of storage buffer
    store_data = getBuffer(ptr);
  }

  /*
  Allows anyone to distribute reserved tokens to their respective destinations following the finalization of the crowdsale
  Providing an amount of tokens to distribute allows for batched distribution - given a long list, it may be costly to send the entire list at once
  Once tokens for an address are distributed, the list's length is decremented

  @param _amt: The number of indices in the reserved tokens list to distribute (allows for batching)
  @param _context: The execution context for this application - a 96-byte array containing (in order):
    1. Application execution id
    2. Original script sender (address, padded to 32 bytes)
    3. Wei amount sent with transaction to storage
  @return store_data: A formatted storage request - first 64 bytes designate a forwarding address (and amount) for any wei sents
  */
  function distributeReservedTokens(uint _amt, bytes _context) public view returns (bytes32[] store_data) {
    // Ensure valid input
    require(_amt > 0);
    if (_context.length != 96)
      triggerException(ERR_UNKNOWN_CONTEXT);

    // Parse context array and get sender address and execution id
    address sender;
    bytes32 exec_id;
    (exec_id, sender, ) = parse(_context);

    // Create 'readMulti' calldata buffer in memory
    uint ptr = cdBuff(RD_MULTI);
    // Place exec id, data read offset, and read size in buffer
    cdPush(ptr, exec_id);
    cdPush(ptr, bytes32(64));
    cdPush(ptr, 4);
    // Place crowdsale finalization status, total tokens minted location, total token supply, and reserved destination length storage locations to calldata
    cdPush(ptr, CROWDSALE_IS_FINALIZED);
    cdPush(ptr, TOTAL_TOKENS_MINTED);
    cdPush(ptr, TOKEN_TOTAL_SUPPLY);
    cdPush(ptr, TOKEN_RESERVED_DESTINATIONS);
    // Read from storage, and store returned values in buffer
    bytes32[] memory initial_read_values = readMulti(ptr);
    // Ensure the length is 4
    assert(initial_read_values.length == 4);

    // If the crowdsale is not finalized, revert
    if (initial_read_values[0] != bytes32(1))
      triggerException(ERR_INSUFFICIENT_PERMISSIONS);

    // Get total tokens minted, total token supply, and reserved destinations list length
    uint total_minted = uint(initial_read_values[1]);
    uint total_supply = uint(initial_read_values[2]);
    uint num_destinations = uint(initial_read_values[3]);

    // If _amt is greater than the reserved destinations list length, set amt equal to the list length
    if (_amt > num_destinations)
      _amt = num_destinations;

    // Overwrite calldata pointer to create new 'readMulti' request
    cdOverwrite(ptr, RD_MULTI);
    // Place exec id, data read offset, and read size in buffer
    cdPush(ptr, exec_id);
    cdPush(ptr, bytes32(64));
    cdPush(ptr, bytes32(_amt));
    // Get the locations of all destinations to be paid out, starting with the last destination and working backward (this allows us to simply decrement the length, instead of swapping entries)
    for (uint i = 0; i < _amt; i++) {
      // Get end of list (32 * num_destinations) and subtract multiples of i to get each consecutive index
      cdPush(ptr, bytes32(32 * (num_destinations - i) + uint(TOKEN_RESERVED_DESTINATIONS)));
    }
    // Read from storage, and store returned values in buffer
    initial_read_values = readMulti(ptr);
    // Ensure valid return length -
    assert(initial_read_values.length == _amt);

    // Finally - for each returned address, we want to read the reservation information for that address as well as that address's current token balance -

    // Create a new 'readMulti' buffer - we don't want to overwrite addresses
    ptr = cdBuff(RD_MULTI);
    // For each address returned, place the locations of their balance, reserved tokens, reserved percents, and percent's precision in 'readMulti' buffer
    for (i = 0; i < _amt; i++) {
      // Destination balance location
      cdPush(ptr, keccak256(keccak256(initial_read_values[i]), TOKEN_BALANCES));
      // Number of tokens reserved
      cdPush(ptr, keccak256(keccak256(initial_read_values[i]), TOKEN_RESERVED_ADDR_INFO));
      // Number of percent reserved - location is 32 bytes after number of tokens reserved
      cdPush(ptr, bytes32(32 + uint(top(ptr))));
      // Precision of percent - location is 32 bytes after number of percentage points reserved
      cdPush(ptr, bytes32(32 + uint(top(ptr))));
    }
    // Read from storage, and store return in buffer
    bytes32[] memory read_reserved_info = readMulti(ptr);
    // Ensure valid return length -
    assert(read_reserved_info.length == 4 * _amt);

    // Create storage buffer in free memory, to set up return value
    ptr = stBuff();
    // Push new list length to storage buffer
    stPush(ptr, TOKEN_RESERVED_DESTINATIONS);
    stPush(ptr, bytes32(num_destinations - _amt));
    // For each address, get their new balance and add to storage buffer
    for (i = 0; i < _amt; i++) {
      // Get percent reserved and precision
      uint to_add = uint(read_reserved_info[(i + 2) * 4]);
      // Two points of precision are added to ensure at least a percent out of 100
      uint precision = 2 + uint(read_reserved_info[(i + 3) * 4]);
      // Get percent divisor, and check for overflow
      assert(10 ** precision > precision);
      precision = 10 ** precision;

      // Get number of tokens to add frmo total_minted and precent reserved
      to_add = total_minted * to_add / precision;

      // Add number of tokens reserved, and check for overflow
      // Additionally, check that the added amount does not overflow total supply
      require(to_add + uint(read_reserved_info[(i + 1) * 4]) >= to_add);
      to_add += uint(read_reserved_info[(i + 1) * 4]);
      require(total_supply + to_add >= total_supply);
      // Increment total supply
      total_supply += to_add;

      // Add destination's current token balance to to_add, and check for overflow
      require(to_add + uint(read_reserved_info[i * 4]) >= uint(read_reserved_info[i * 4]));
      to_add += uint(read_reserved_info[i * 4]);
      // Add new balance and balance location to storage buffer
      stPush(ptr, keccak256(keccak256(address(initial_read_values[i])), TOKEN_BALANCES));
      stPush(ptr, bytes32(to_add));
    }
    // Add new total supply to storage buffer
    stPush(ptr, TOKEN_TOTAL_SUPPLY);
    stPush(ptr, bytes32(total_supply));
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
