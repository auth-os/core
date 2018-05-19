pragma solidity ^0.4.23;

import "../../lib/Pointers.sol";
import "../../lib/LibEvents.sol";
import "../../lib/LibStorage.sol";

library ImplementationConsole {

  using Pointers for *;
  using LibEvents for uint;
  using LibStorage for uint;

  /// PROVIDER STORAGE ///

  // Provider namespace - all app and version storage is seeded to a provider
  // [PROVIDERS][provider_id]
  bytes32 internal constant PROVIDERS = keccak256("registry_providers");

  /// APPLICATION STORAGE ///

  // Application namespace - all app info and version storage is mapped here
  // [PROVIDERS][provider_id][APPS][app_name]
  bytes32 internal constant APPS = keccak256("apps");

  /// VERSION STORAGE ///

  // Version namespace - all version and function info is mapped here
  // [PROVIDERS][provider_id][APPS][app_hash][VERSIONS]
  bytes32 internal constant VERSIONS = keccak256("versions");

  // Version "is finalized" location - whether a version is ready for use (all intended functions implemented)
  // [PROVIDERS][provider_id][APPS][app_hash][VERSIONS][ver_name][VER_IS_FINALIZED] = bool is_finalized
  bytes32 internal constant VER_IS_FINALIZED = keccak256("ver_is_finalized");

  // Version function list location - (bytes4 array)
  // [PROVIDERS][provider_id][APPS][app_hash][VERSIONS][ver_name][VER_FUNCTION_LIST] = bytes4[] function_signatures
  bytes32 internal constant VER_FUNCTION_LIST = keccak256("ver_functions_list");

  // Version function address location - stores the address where each corresponding version's function is located
  // [PROVIDERS][provider_id][APPS][app_hash][VERSIONS][ver_name][VER_FUNCTION_ADDRESSES] = address[] function_addresses
  bytes32 internal constant VER_FUNCTION_ADDRESSES = keccak256("ver_function_addrs");

  /// FUNCTION SELECTORS ///

  // Function selector for storage 'readMulti'
  // readMulti(bytes32 exec_id, bytes32[] locations)
  bytes4 internal constant RD_MULTI = bytes4(keccak256("readMulti(bytes32,bytes32[])"));

  /// FUNCTIONS ///

  /*
  Adds functions and their implementing addresses to a non-finalized version

  @param _app: The name of the application under which the version is registered
  @param _version: The name of the version to add functions to
  @param _function_sigs: An array of function selectors the version will implement
  @param _function_addrs: The corresponding addresses which implement the given functions
  @param _context: The execution context for this application - a 96-byte array containing (in order):
    1. Application execution id
    2. Original script sender (address, padded to 32 bytes)
    3. Wei amount sent with transaction to storage
  @return bytes: A formatted bytes array that will be parsed by storage to emit events, forward payment, and store data
  */
  function addFunctions(bytes32 _app, bytes32 _version, bytes4[] memory _function_sigs, address[] memory _function_addrs, bytes memory _context) public view
  returns (bytes memory) {
    // Ensure input is correctly formatted
    require(_context.length == 96);
    require(_app != bytes32(0) && _version != bytes32(0));
    require(_function_sigs.length == _function_addrs.length && _function_sigs.length > 0);

    bytes32 exec_id;
    bytes32 provider;

    // Parse context array and get provider and execution id
    (exec_id, provider, ) = parse(_context);

    // Get app base storage location -
    bytes32 temp = keccak256(keccak256(provider), PROVIDERS);
    temp = keccak256(keccak256(_app), keccak256(APPS, temp));

    /// Ensure application and version are registered, and version is not finalized
    /// Additionally, read version function and address list lengths -

    // Create 'readMulti' calldata buffer in memory
    uint ptr = cdBuff(RD_MULTI);
    // Place exec id, data read offset, and read size to calldata
    cdPush(ptr, exec_id);
    cdPush(ptr, 0x40);
    cdPush(ptr, 5);
    // Push app base storage, version base storage, and version finalization status storage locations to buffer
    cdPush(ptr, temp);
    // Get version base storage -
    temp = keccak256(keccak256(_version), keccak256(VERSIONS, temp));
    cdPush(ptr, temp);
    cdPush(ptr, keccak256(VER_IS_FINALIZED, temp));
    // Push version function and address list length storage locations to calldata
    cdPush(ptr, keccak256(VER_FUNCTION_LIST, temp));
    cdPush(ptr, keccak256(VER_FUNCTION_ADDRESSES, temp));

    // Read from storage and store return in buffer
    bytes32[] memory read_values = readMulti(ptr);
    // Check returned values
    if (
      read_values[0] == bytes32(0) // Application does not exist
      || read_values[1] == bytes32(0) // Version does not exist
      || read_values[2] != bytes32(0) // Version is already finalized
    ) {
      triggerException(bytes32("InsufficientPermissions"));
    }
    // Version function selector and address lists should always be equal
    assert(read_values[3] == read_values[4]);
    // Get version function and address list lengths
    uint list_lengths = uint(read_values[3]);

    /// App and version are registered, and version has not been finalized - store function information

    // Get pointer to free memory
    ptr = ptr.clear();

    // Set up STORES action requests -
    ptr.stores();
    // Push each storage location and value to the STORES request buffer:

    // Store new version list lengths
    ptr.store(
      list_lengths + _function_sigs.length
    ).at(keccak256(VER_FUNCTION_LIST, temp));
    ptr.store(
      list_lengths + _function_sigs.length
    ).at(keccak256(VER_FUNCTION_ADDRESSES, temp));

    // Loop through functions and addresses and push each to the end of their respective lists
    for (uint i = list_lengths; i < _function_sigs.length + list_lengths; i++) {
      // Push function selector to the end of the version function list
      ptr.store(
        _function_sigs[i - list_lengths]
      ).at(bytes32(32 + (i * 32) + uint(keccak256(VER_FUNCTION_LIST, temp))));
      // Push function implementing address to the end of the version address list
      ptr.store(
        _function_addrs[i - list_lengths]
      ).at(bytes32(32 + (i * 32) + uint(keccak256(VER_FUNCTION_ADDRESSES, temp))));
    }

    // Return formatted action requests to storage
    return ptr.getBuffer();
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
