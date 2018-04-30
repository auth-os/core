pragma solidity ^0.4.21;

library AppConsole {

  /// PROVIDER STORAGE ///

  // Provider namespace - all app and version storage is seeded to a provider
  // [PROVIDERS][provider_id]
  bytes32 internal constant PROVIDERS = keccak256("registry_providers");

  // Storage location for a list of all applications released by this provider
  // [PROVIDERS][provider_id][PROVIDER_APP_LIST] = bytes32[] registered_apps
  bytes32 internal constant PROVIDER_APP_LIST = keccak256("provider_app_list");

  /// APPLICATION STORAGE ///

  // Application namespace - all app info and version storage is mapped here
  // [PROVIDERS][provider_id][APPS][app_name]
  bytes32 internal constant APPS = keccak256("apps");

  // Application description location - (bytes array)
  // [PROVIDERS][provider_id][APPS][app_name][APP_DESC] = bytes description
  bytes32 internal constant APP_DESC = keccak256("app_desc");

  // Application storage address location - address
  // [PROVIDERS][provider_id][APPS][app_name][APP_STORAGE_IMPL] = address app_default_storage_addr
  bytes32 internal constant APP_STORAGE_IMPL = keccak256("app_storage_impl");

  /// FUNCTION SELECTORS ///

  // Function selector for storage 'readMulti'
  // readMulti(bytes32 exec_id, bytes32[] locations)
  bytes4 internal constant RD_MULTI = bytes4(keccak256("readMulti(bytes32,bytes32[])"));

  /// FUNCTIONS ///

  /*
  Registers an application under the sender's provider id

  @param _app_name: The name of the application to be registered
  @param _app_storage: The storage address this application will use
  @param _app_desc: The description of the application
  @param _context: The execution context for this application - a 96-byte array containing (in order):
    1. Application execution id
    2. Original script sender (address, padded to 32 bytes)
    3. Wei amount sent with transaction to storage
  @return store_data: A formatted storage request - first 64 bytes designate a forwarding address (and amount) for any wei sent
  */
  function registerApp(bytes32 _app_name, address _app_storage, bytes _app_desc, bytes memory _context) public view
  returns (bytes32[] memory store_data) {
    // Ensure input is correctly formatted
    require(_context.length == 96);
    require(_app_name != bytes32(0) && _app_desc.length > 0 && _app_storage != address(0));

    bytes32 exec_id;
    bytes32 provider;

    // Parse context array and get execution id and provider
    (exec_id, provider, ) = parse(_context);

    /// Ensure application is not already registered under this provider -

    // Create 'readMulti' calldata buffer in memory
    uint ptr = cdBuff(RD_MULTI);
    // Place exec id, data read offset, and read size to calldata
    cdPush(ptr, exec_id);
    cdPush(ptr, 0x40);
    cdPush(ptr, 2);
    // Place app storage location, and provider app list length in calldata
    bytes32 temp = keccak256(keccak256(provider), PROVIDERS); // Use a temporary var to get provider storage location
    cdPush(ptr, keccak256(keccak256(_app_name), keccak256(APPS, temp))); // Push application storage location to buffer
    cdPush(ptr, keccak256(PROVIDER_APP_LIST, temp)); // Push provider app list locaiton to calldata
    // Read from storage and store return in buffer
    bytes32[] memory read_values = readMulti(ptr);
    // Check returned app storage location - if nonzero, application is already registered
    if (read_values[0] != bytes32(0))
      triggerException(bytes32("InsufficientPermissions"));

    // Get returned provider app list length
    uint num_apps = uint(read_values[1]);

    /// Application is unregistered - register application -

    // Overwrite previous buffer with storage buffer
    stOverwrite(ptr);
    // Place payment amount and destination (0, 0) in buffer
    stPush(ptr, 0);
    stPush(ptr, 0);
    // Place app name in app storage location
    // Get app storage location
    temp = keccak256(keccak256(_app_name), keccak256(APPS, temp));
    stPush(ptr, temp);
    stPush(ptr, _app_name);
    // Place app storage address in app default storage address location
    stPush(ptr, keccak256(APP_STORAGE_IMPL, temp));
    stPush(ptr, bytes32(_app_storage));
    // Increment provider app list length
    // Get provider app list storage location
    temp = keccak256(keccak256(provider), PROVIDERS);
    temp = keccak256(PROVIDER_APP_LIST, temp);
    stPush(ptr, temp);
    stPush(ptr, bytes32(1 + num_apps));
    // Push app name to the end of the provider's app list
    // Get end of list -
    stPush(ptr, bytes32(32 + 32 * num_apps + uint(temp)));
    stPush(ptr, _app_name);
    // Push description to storage buffer
    // Get app description storage location
    temp = keccak256(keccak256(provider), PROVIDERS);
    temp = keccak256(keccak256(_app_name), keccak256(APPS, temp));
    temp = keccak256(APP_DESC, temp);
    stPushBytes(ptr, temp, _app_desc);

    // Get bytes32[] representation of storage buffer
    store_data = getBuffer(ptr);
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
  Pushes a bytes array to the storage buffer, including its length. Uses the given base location to get the storage locations for each
  index in the array

  @param _ptr: A pointer to the start of the buffer
  @param _base_location: The storage location of the length of the array
  @param _arr: The bytes array to push
  */
  function stPushBytes(uint _ptr, bytes32 _base_location, bytes _arr) internal pure {
    assembly {
      // Get end of buffer - 32 bytes plus the length stored at the pointer
      let len := add(0x20, mload(_ptr))
      // Loop over bytes array, and push each value to storage buffer, while incrementing the current storage location
      let offset := 0x00
      for { } lt(offset, add(0x20, mload(_arr))) { offset := add(0x20, offset) } {
        // Push incremented location to buffer
        mstore(add(add(len, mul(2, offset)), _ptr), add(offset, _base_location))
        // Push bytes array chunk to buffer
        mstore(add(add(add(0x20, len), mul(2, offset)), _ptr), mload(add(offset, _arr)))
      }
      // Increment buffer length
      mstore(_ptr, add(mul(2, offset), mload(_ptr)))
      // If the free-memory pointer does not point beyond the buffer's current size, update it
      if lt(mload(0x40), add(add(0x20, _ptr), mload(_ptr))) {
        mstore(0x40, add(add(0x40, _ptr), mload(_ptr))) // Ensure free memory pointer points to the beginning of a memory slot
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


  // Parses context array and returns execution id, provider, and sent wei amount
  function parse(bytes memory _context) internal pure returns (bytes32 exec_id, bytes32 provider, uint wei_sent) {
    assembly {
      exec_id := mload(add(0x20, _context))
      provider := mload(add(0x40, _context))
      wei_sent := mload(add(0x60, _context))
    }
    // Ensure sender and exec id are valid
    if (provider == bytes32(0) || exec_id == bytes32(0))
      triggerException(bytes32("UnknownContext"));
  }
}
