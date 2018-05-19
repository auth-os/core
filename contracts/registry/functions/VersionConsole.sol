pragma solidity ^0.4.23;

import "../../lib/Pointers.sol";
import "../../lib/LibEvents.sol";
import "../../lib/LibStorage.sol";

library VersionConsole {

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

  // Application version list location - (bytes32 array)
  // [PROVIDERS][provider_id][APPS][app_name][APP_VERSIONS_LIST] = bytes32[] version_names
  bytes32 internal constant APP_VERSIONS_LIST = keccak256("app_versions_list");

  // Application storage address location - address
  // [PROVIDERS][provider_id][APPS][app_name][APP_STORAGE_IMPL] = address app_default_storage_addr
  bytes32 internal constant APP_STORAGE_IMPL = keccak256("app_storage_impl");

  /// VERSION STORAGE ///

  // Version namespace - all version and function info is mapped here
  // [PROVIDERS][provider_id][APPS][app_hash][VERSIONS]
  bytes32 internal constant VERSIONS = keccak256("versions");

  // Version description location - (bytes array)
  // [PROVIDERS][provider_id][APPS][app_hash][VERSIONS][ver_hash][VER_DESC] = bytes description
  bytes32 internal constant VER_DESC = keccak256("ver_desc");

  // Version "is finalized" location - whether a version is ready for use (all intended functions implemented)
  // [PROVIDERS][provider_id][APPS][app_hash][VERSIONS][ver_name][VER_IS_FINALIZED] = bool is_finalized
  bytes32 internal constant VER_IS_FINALIZED = keccak256("ver_is_finalized");

  // Version storage address - if nonzero, overrides application-specified storage address
  // [PROVIDERS][provider_id][APPS][app_hash][VERSIONS][ver_name][VER_PERMISSIONED] = address version_storage_addr
  bytes32 internal constant VER_STORAGE_IMPL = keccak256("ver_storage_impl");

  // Version initialization address location - contains the version's 'init' function
  // [PROVIDERS][provider_id][APPS][app_hash][VERSIONS][ver_name][VER_INIT_ADDR] = address ver_init_addr
  bytes32 internal constant VER_INIT_ADDR = keccak256("ver_init_addr");

  // Version initialization function signature - called when initializing an instance of a version
  // [PROVIDERS][provider_id][APPS][app_hash][VERSIONS][ver_name][VER_INIT_SIG] = bytes4 init_signature
  bytes32 internal constant VER_INIT_SIG = keccak256("ver_init_signature");

  // Version 'init' function description location - bytes of a version's initialization function description
  // [PROVIDERS][provider_id][APPS][app_hash][VERSIONS][ver_name][VER_INIT_DESC] = bytes description
  bytes32 internal constant VER_INIT_DESC = keccak256("ver_init_desc");

  /// EVENT TOPICS ///

  // event VersionRegistered(bytes32 indexed execution_id, bytes32 indexed provider_id, bytes32 indexed app_name, bytes32 version_name);
  bytes32 internal constant VERSION_REGISTERED = keccak256("VersionRegistered(bytes32,bytes32,bytes32,bytes32)");

  // event VersionReleased(bytes32 indexed execution_id, bytes32 indexed provider_id, bytes32 indexed app_name, bytes32 version_name);
  bytes32 internal constant VERSION_RELEASED = keccak256("VersionReleased(bytes32,bytes32,bytes32,bytes32)");

  /// FUNCTION SELECTORS ///

  // Function selector for storage 'readMulti'
  // readMulti(bytes32 exec_id, bytes32[] locations)
  bytes4 internal constant RD_MULTI = bytes4(keccak256("readMulti(bytes32,bytes32[])"));

  /// FUNCTIONS ///

  /*
  Registers a version of an application under the sender's provider id

  @param _app: The name of the application under which the version will be registered
  @param _ver_name: The name of the version to register
  @param _ver_storage: The storage address to use for this version. If left empty, storage uses application default address
  @param _ver_desc: The decsription of the version
  @param _context: The execution context for this application - a 96-byte array containing (in order):
    1. Application execution id
    2. Original script sender (address, padded to 32 bytes)
    3. Wei amount sent with transaction to storage
  @return bytes: A formatted bytes array that will be parsed by storage to emit events, forward payment, and store data
  */
  function registerVersion(bytes32 _app, bytes32 _ver_name, address _ver_storage, bytes memory _ver_desc, bytes memory _context) public view
  returns (bytes memory) {
    // Ensure input is correctly formatted
    require(_context.length == 96);
    require(_app != bytes32(0) && _ver_name != bytes32(0) && _ver_desc.length > 0);

    bytes32 exec_id;
    bytes32 provider;

    // Parse context array and get execution id and provider
    (exec_id, provider, ) = parse(_context);

    // Place app storage location in calldata
    bytes32 temp = keccak256(keccak256(provider), PROVIDERS); // Use a temporary var to get app base storage location
    temp = keccak256(keccak256(_app), keccak256(APPS, temp));

    /// Ensure application is already registered, and that the version name is unique.
    /// Additionally, get the app's default storage address, and the app's version list length -

    // Create 'readMulti' calldata buffer in memory
    uint ptr = cdBuff(RD_MULTI);
    // Place exec id, data read offset, and read size to calldata
    cdPush(ptr, exec_id);
    cdPush(ptr, 0x40);
    cdPush(ptr, 4);
    cdPush(ptr, temp); // Push app base storage location to read buffer
    cdPush(ptr, keccak256(keccak256(_ver_name), keccak256(VERSIONS, temp))); // Push version base storage location to buffer
    cdPush(ptr, keccak256(APP_STORAGE_IMPL, temp)); // App default storage address location
    cdPush(ptr, keccak256(APP_VERSIONS_LIST, temp)); // App version list storage location
    // Read from storage and store return in buffer
    bytes32[] memory read_values = readMulti(ptr);
    // Check returned values -
    if (
      read_values[0] == bytes32(0) // Application does not exist
      || read_values[1] != bytes32(0) // Version name already exists
    ) {
      triggerException(bytes32("InsufficientPermissions"));
    }

    // If passed in version storage address is zero, set version storage address to returned app default storage address
    if (_ver_storage == address(0))
      _ver_storage = address(read_values[2]);

    // Get app version list length
    uint num_versions = uint(read_values[3]);

    /// App is registered, and version name is unique - store version information:

    // Get pointer to free memory
    ptr = ptr.clear();

    // Set up STORES action requests -
    ptr.stores();
    // Push each storage location and value to the STORES request buffer:

    // Place incremented app version list length at app version list storage location
    ptr.store(
      num_versions + 1
    ).at(keccak256(APP_VERSIONS_LIST, temp));

    // Push new version name to end of app version list
    ptr.store(
      _ver_name
    ).at(bytes32(32 * (1 + num_versions) + uint(keccak256(APP_VERSIONS_LIST, temp))));

    // Place version name in version base storage location
    temp = keccak256(keccak256(_ver_name), keccak256(VERSIONS, temp));
    ptr.store(
      _ver_name
    ).at(temp);

    // Place version storage address in version storage address location
    ptr.store(
      _ver_storage
    ).at(keccak256(VER_STORAGE_IMPL, temp));

    // Store entirety of version description
    temp = keccak256(VER_DESC, temp);
    ptr.storeBytesAt(_ver_desc, temp);

    // Done with STORES action - set up EMITS action
    ptr.emits();

    // Add VERSION_REGISTERED topics
    ptr.topics(
      [VERSION_REGISTERED, exec_id, keccak256(provider), _app]
    );
    // Add VERSION_REGISTERED data (version name)
    // Separate line to avoid 'Stack too deep' issues
    ptr.data(_ver_name);

    // Return formatted action requests to storage
    return ptr.getBuffer();
  }

  /*
  Finalizes a registered version by providing instance initialization information

  @param _app: The name of the application under which the version is registered
  @param _ver_name: The name of the version to finalize
  @param _ver_init_address: The address which contains the version's initialization function
  @param _init_sig: The function signature for the version's initialization function
  @param _init_description: A description of the version's initialization function and parameters
  @param _context: The execution context for this application - a 96-byte array containing (in order):
    1. Application execution id
    2. Original script sender (address, padded to 32 bytes)
    3. Wei amount sent with transaction to storage
  @return bytes: A formatted bytes array that will be parsed by storage to emit events, forward payment, and store data
  */
  function finalizeVersion(bytes32 _app, bytes32 _ver_name, address _ver_init_address, bytes4 _init_sig, bytes memory _init_description, bytes memory _context) public view
  returns (bytes memory) {
    // Ensure input is correctly formatted
    require(_context.length == 96);
    require(_app != bytes32(0) && _ver_name != bytes32(0));
    require(_ver_init_address != address(0) && _init_sig != bytes4(0) && _init_description.length > 0);

    bytes32 exec_id;
    bytes32 provider;

    // Parse context array and get execution id and provider
    (exec_id, provider, ) = parse(_context);

    /// Ensure application and version are registered, and that the version is not already finalized -

    // Create 'readMulti' calldata buffer in memory
    uint ptr = cdBuff(RD_MULTI);
    // Place exec id, data read offset, and read size in buffer
    cdPush(ptr, exec_id);
    cdPush(ptr, 0x40);
    cdPush(ptr, 3);
    // Push app base storage, version base storage, and version finalization status storage locations to buffer
    // Get app base storage -
    bytes32 temp = keccak256(keccak256(provider), PROVIDERS);
    temp = keccak256(keccak256(_app), keccak256(APPS, temp));
    cdPush(ptr, temp);
    // Get version base storage -
    temp = keccak256(keccak256(_ver_name), keccak256(VERSIONS, temp));
    cdPush(ptr, temp);
    cdPush(ptr, keccak256(VER_IS_FINALIZED, temp));
    // Read from storage and store return in buffer
    bytes32[] memory read_values = readMulti(ptr);
    // Check returned values -
    if (
      read_values[0] == bytes32(0) // Application does not exist
      || read_values[1] == bytes32(0) // Version does not exist
      || read_values[2] != bytes32(0) // Version already finalized
    ) {
      triggerException(bytes32("InsufficientPermissions"));
    }

    /// App and version are registered, and version is ready to be finalized -

    // Get pointer to free memory
    ptr = ptr.clear();

    // Set up STORES action requests -
    ptr.stores();
    // Push each storage location and value to the STORES request buffer:

    // Store version finalization status
    ptr.store(
      true
    ).at(keccak256(VER_IS_FINALIZED, temp));

    // Store version initialization address
    ptr.store(
      _ver_init_address
    ).at(keccak256(VER_INIT_ADDR, temp));

    // Store version initialization function selector
    ptr.store(
      _init_sig
    ).at(keccak256(VER_INIT_SIG, temp));

    // Store entirety of version initialization function description
    ptr.storeBytesAt(_init_description, keccak256(VER_INIT_DESC, temp));

    // Done with STORES action - set up EMITS action
    ptr.emits();

    // Add VERSION_RELEASED topics
    ptr.topics(
      [VERSION_RELEASED, exec_id, keccak256(provider), _app]
    );
    // Add VERSION_RELEASED data (version name)
    // Separate line to avoid 'Stack too deep' issues
    ptr.data(_ver_name);

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
    // Ensure exec id and provider are valid
    if (provider == bytes32(0) || exec_id == bytes32(0))
      triggerException(bytes32("UnknownContext"));
  }
}
