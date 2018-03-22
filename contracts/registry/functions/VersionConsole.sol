pragma solidity ^0.4.21;

library VersionConsole {

  /// PROVIDER STORAGE ///

  // Provider namespace - all app and version storage is seeded to a provider
  // [PROVIDERS][provider_id]
  bytes32 public constant PROVIDERS = keccak256("registry_providers");

  /// APPLICATION STORAGE ///

  // Application namespace - all app info and version storage is mapped here
  // [PROVIDERS][provider_id][APPS][app_name]
  bytes32 public constant APPS = keccak256("apps");

  // Application version list location - (bytes32 array)
  // [PROVIDERS][provider_id][APPS][app_name][APP_VERSIONS_LIST] = bytes32[] version_names
  bytes32 public constant APP_VERSIONS_LIST = keccak256("app_versions_list");

  // Application storage address location - address
  // [PROVIDERS][provider_id][APPS][app_name][APP_STORAGE_IMPL] = address app_default_storage_addr
  bytes32 public constant APP_STORAGE_IMPL = keccak256("app_storage_impl");

  /// VERSION STORAGE ///

  // Version namespace - all version and function info is mapped here
  // [PROVIDERS][provider_id][APPS][app_hash][VERSIONS]
  bytes32 public constant VERSIONS = keccak256("versions");

  // Version description location - (bytes array)
  // [PROVIDERS][provider_id][APPS][app_hash][VERSIONS][ver_hash][VER_DESC] = bytes description
  bytes32 public constant VER_DESC = keccak256("ver_desc");

  // Version "is finalized" location - whether a version is ready for use (all intended functions implemented)
  // [PROVIDERS][provider_id][APPS][app_hash][VERSIONS][ver_name][VER_IS_FINALIZED] = bool is_finalized
  bytes32 public constant VER_IS_FINALIZED = keccak256("ver_is_finalized");

  // Version function list location - (bytes4 array)
  // [PROVIDERS][provider_id][APPS][app_hash][VERSIONS][ver_name][VER_FUNCTION_LIST] = bytes4[] function_signatures
  bytes32 public constant VER_FUNCTION_LIST = keccak256("ver_functions_list");

  // Version function address location - stores the address where each corresponding version's function is located
  // [PROVIDERS][provider_id][APPS][app_hash][VERSIONS][ver_name][VER_FUNCTION_ADDRESSES] = address[] function_addresses
  bytes32 public constant VER_FUNCTION_ADDRESSES = keccak256("ver_function_addrs");

  // Version storage address - if nonzero, overrides application-specified storage address
  // [PROVIDERS][provider_id][APPS][app_hash][VERSIONS][ver_name][VER_PERMISSIONED] = address version_storage_addr
  bytes32 public constant VER_STORAGE_IMPL = keccak256("ver_storage_impl");

  // Version initialization address location - contains the version's 'init' function
  // [PROVIDERS][provider_id][APPS][app_hash][VERSIONS][ver_name][VER_INIT_ADDR] = address ver_init_addr
  bytes32 public constant VER_INIT_ADDR = keccak256("ver_init_addr");

  // Version initialization function signature - called when initializing an instance of a version
  // [PROVIDERS][provider_id][APPS][app_hash][VERSIONS][ver_name][VER_INIT_SIG] = bytes4 init_signature
  bytes32 public constant VER_INIT_SIG = keccak256("ver_init_signature");

  // Version 'init' function description location - bytes of a version's initialization function description
  // [PROVIDERS][provider_id][APPS][app_hash][VERSIONS][ver_name][VER_INIT_DESC] = bytes description
  bytes32 public constant VER_INIT_DESC = keccak256("ver_init_desc");

  /// FUNCTION SELECTORS ///

  // Function selector for storage 'readMulti'
  // readMulti(bytes32 exec_id, bytes32[] locations)
  bytes4 public constant RD_MULTI = bytes4(keccak256("readMulti(bytes32,bytes32[])"));

  /// FUNCTIONS ///

  struct VerReg {
    bytes4 rd_multi;
    bytes32 app_storage_loc;
    bytes32 app_ver_list_loc;
    bytes32 app_default_storage_loc;
    bytes32 ver_storage_loc;
    bytes32 ver_description_loc;
    bytes32 ver_storage_impl_loc;
  }

  /*
  Registers a version of an application under the sender's provider id

  @param _context: A 64-byte array containing execution context for the application. In order:
    1. Registry application execution id
    2. Original script sender (address, padded to 32 bytes)
  @param _app: The name of the application under which the version will be registered
  @param _ver_name: The name of the version to register
  @param _ver_storage: The storage address to use for this version. If left empty, storage uses application default address
  @param _ver_desc: The decsription of the version
  @return store_data: A formatted storage request, which will be interpreted by the sender storage proxy to store version info
  */
  function registerVersion(bytes _context, bytes32 _app, bytes32 _ver_name, address _ver_storage, bytes _ver_desc) public view
  returns (bytes32[] store_data) {
    // Ensure input is correctly formatted
    require(_context.length == 64);
    require(_app != bytes32(0) && _ver_name != bytes32(0) && _ver_desc.length > 0);

    address provider;
    bytes32 exec_id;

    // Parse context array and get sender address and execution id
    (provider, exec_id) = parse(_context);

    // Initialize struct in memory to hold values
    VerReg memory ver_reg = VerReg({
      rd_multi: RD_MULTI,
      app_storage_loc: keccak256(keccak256(provider), PROVIDERS),
      // Placeholders
      app_ver_list_loc: 0,
      app_default_storage_loc: 0,
      ver_storage_loc: 0,
      ver_description_loc: 0,
      ver_storage_impl_loc: 0
    });

    // Get app base storage location
    ver_reg.app_storage_loc = keccak256(APPS, ver_reg.app_storage_loc);
    ver_reg.app_storage_loc = keccak256(keccak256(_app), ver_reg.app_storage_loc);
    // Get app version list and default storage address locations
    ver_reg.app_ver_list_loc = keccak256(APP_VERSIONS_LIST, ver_reg.app_storage_loc);
    ver_reg.app_default_storage_loc = keccak256(APP_STORAGE_IMPL, ver_reg.app_storage_loc);
    // Get version base storage location
    ver_reg.ver_storage_loc = keccak256(VERSIONS, ver_reg.app_storage_loc);
    ver_reg.ver_storage_loc = keccak256(keccak256(_ver_name), ver_reg.ver_storage_loc);
    // Get version description and storage address locations
    ver_reg.ver_description_loc = keccak256(VER_DESC, ver_reg.ver_storage_loc);
    ver_reg.ver_storage_impl_loc = keccak256(VER_STORAGE_IMPL, ver_reg.ver_storage_loc);

    uint num_versions;

    assembly {
      // Ensure application is registered, and version name is unique. Additionally, get
      // app default storage address, and app version list length -

      // Get pointer to store calldata in
      let ptr := mload(0x40)
      // Place 'readMulti' selector, registry execution id, data read offset, and read size in calldata
      mstore(ptr, mload(ver_reg))
      mstore(add(0x04, ptr), exec_id)
      mstore(add(0x24, ptr), 0x40)
      mstore(add(0x44, ptr), 4)
      // Place app base storage, version base storage, app default storage address, and app version list length storage locations in calldata
      mstore(add(0x64, ptr), mload(add(0x20, ver_reg)))
      mstore(add(0x84, ptr), mload(add(0x80, ver_reg)))
      mstore(add(0xa4, ptr), mload(add(0x60, ver_reg)))
      mstore(add(0xc4, ptr), mload(add(0x40, ver_reg)))

      // Read from storage and check return value. Store returned data at pointer
      if iszero(
        staticcall(gas, caller, ptr, 0xe4, ptr, 0xc0)
      ) { revert (0, 0) }

      // Get returned app storage value - if zero, app is not registered: revert
      if iszero(mload(add(0x40, ptr))) { revert (0, 0) }
      // Get returned version storage value - if nonzero, version is already registered: revert
      if gt(mload(add(0x60, ptr)), 0) { revert (0, 0) }
      // If provided version storage address is zero, set version storage address to returned app default storage address
      if iszero(_ver_storage) {
        _ver_storage := mload(add(0x80, ptr))
      }
      // Get app version count
      num_versions := mload(add(0xa0, ptr))

      // App is registered, version name is unique - register version:

      // Get return write size -
      let size := add(10, mul(2, div(mload(_ver_desc), 0x20)))
      if gt(mod(mload(_ver_desc), 0x20), 0) { size := add(2, size) }

      // Allocate space for return storage request
      store_data := add(0x20, msize)
      // Set return length
      mstore(store_data, size)

      // Set return values -

      // Push version name to end of app version list
      mstore(add(0x20, store_data), add(add(0x20, mul(0x20, num_versions)), mload(add(0x40, ver_reg))))
      mstore(add(0x40, store_data), _ver_name)
      // Place version name in version base storage location
      mstore(add(0x60, store_data), mload(add(0x80, ver_reg)))
      mstore(add(0x80, store_data), _ver_name)
      // Store version storage address
      mstore(add(0xa0, store_data), mload(add(0xc0, ver_reg)))
      mstore(add(0xc0, store_data), _ver_storage)
      // Increment app version list length
      mstore(add(0xe0, store_data), mload(add(0x40, ver_reg)))
      mstore(add(0x0100, store_data), add(1, num_versions))

      // Loop through description and place in return request
      for { let offset := 0x00 } lt(offset, add(0x20, mload(_ver_desc))) { offset := add(0x20, offset) } {
        // Place description storage location in return request
        mstore(add(add(0x0120, mul(2, offset)), store_data), add(offset, mload(add(0xa0, ver_reg))))
        // Place description chunk in return request
        mstore(add(add(0x0140, mul(2, offset)), store_data), mload(add(offset, _ver_desc)))
      }
    }
  }

  struct VerFinalize {
    bytes4 rd_multi;
    bytes32 app_storage_loc;
    bytes32 ver_storage_loc;
    bytes32 ver_status_loc;
    bytes32 ver_init_addr_loc;
    bytes32 ver_init_sig_loc;
    bytes32 ver_init_desc_loc;
  }

  /*
  Finalizes a registered version by providing instance initialization information

  @param _context: A 64-byte array containing execution context for the application. In order:
    1. Registry application execution id
    2. Original script sender (address, padded to 32 bytes)
  @param _app: The name of the application under which the version is registered
  @param _ver_name: The name of the version to finalize
  @param _ver_init_address: The address which contains the version's initialization function
  @param _init_sig: The function signature for the version's initialization function
  @param _init_description: A description of the version's initialization function and parameters
  @return store_data: A formatted storage request, which will be interpreted by the sender storage proxy to store version info
  */
  function finalizeVersion(bytes _context, bytes32 _app, bytes32 _ver_name, address _ver_init_address, bytes4 _init_sig, bytes _init_description) public view
  returns (bytes32[] store_data) {
    // Ensure input is correctly formatted
    require(_context.length == 64);
    require(_app != bytes32(0) && _ver_name != bytes32(0));
    require(_ver_init_address != address(0) && _init_sig != bytes4(0) && _init_description.length > 0);

    address provider;
    bytes32 exec_id;

    // Parse context array and get sender address and execution id
    (provider, exec_id) = parse(_context);

    // Initialize struct in memory to hold values
    VerFinalize memory ver_reg = VerFinalize({
      rd_multi: RD_MULTI,
      app_storage_loc: keccak256(keccak256(provider), PROVIDERS),
      // Placeholders
      ver_storage_loc: 0,
      ver_status_loc: 0,
      ver_init_addr_loc: 0,
      ver_init_sig_loc: 0,
      ver_init_desc_loc: 0
    });

    // Get app base storage location
    ver_reg.app_storage_loc = keccak256(APPS, ver_reg.app_storage_loc);
    ver_reg.app_storage_loc = keccak256(keccak256(_app), ver_reg.app_storage_loc);
    // Get version base storage location
    ver_reg.ver_storage_loc = keccak256(VERSIONS, ver_reg.app_storage_loc);
    ver_reg.ver_storage_loc = keccak256(keccak256(_ver_name), ver_reg.ver_storage_loc);
    // Get version status, init address, init signature, and init description storage locations
    ver_reg.ver_status_loc = keccak256(VER_IS_FINALIZED, ver_reg.ver_storage_loc);
    ver_reg.ver_init_addr_loc = keccak256(VER_INIT_ADDR, ver_reg.ver_storage_loc);
    ver_reg.ver_init_sig_loc = keccak256(VER_INIT_SIG, ver_reg.ver_storage_loc);
    ver_reg.ver_init_desc_loc = keccak256(VER_INIT_DESC, ver_reg.ver_storage_loc);

    assembly {
      // Ensure application and version are registered, and that the version is not already finalized -

      // Get pointer to store calldata in
      let ptr := mload(0x40)
      // Place 'readMulti' selector, registry execution id, data read offset, and read size in calldata
      mstore(ptr, mload(ver_reg))
      mstore(add(0x04, ptr), exec_id)
      mstore(add(0x24, ptr), 0x40)
      mstore(add(0x44, ptr), 3)
      // Place app base storage, version base storage, and version finalization status storage locations in calldata
      mstore(add(0x64, ptr), mload(add(0x20, ver_reg)))
      mstore(add(0x84, ptr), mload(add(0x40, ver_reg)))
      mstore(add(0xa4, ptr), mload(add(0x60, ver_reg)))

      // Read from storage and check return value. Store returned data at pointer
      if iszero(
        staticcall(gas, caller, ptr, 0xc4, ptr, 0xa0)
      ) { revert (0, 0) }

      // Get returned app storage value - if zero, app is not registered: revert
      if iszero(mload(add(0x40, ptr))) { revert (0, 0) }
      // Get returned version storage value - if zero, version is not registered: revert
      if iszero(mload(add(0x60, ptr))) { revert (0, 0) }
      // Get returned version status - if nonzero, version is already finalized: revert
      if gt(mload(add(0x80, ptr)), 0) { revert (0, 0) }

      // App and version are registered, and version is ready to be finalized -

      // Get return write size -
      let size := add(8, mul(2, div(mload(_init_description), 0x20)))
      if gt(mod(mload(_init_description), 0x20), 0) { size := add(2, size) }

      // Allocate space for return storage request
      store_data := add(0x20, msize)
      // Set return length
      mstore(store_data, size)

      // Set return values -

      // Set new version finalization status: true
      mstore(add(0x20, store_data), mload(add(0x60, ver_reg)))
      mstore(add(0x40, store_data), 1)
      // Set version initialization address
      mstore(add(0x60, store_data), mload(add(0x80, ver_reg)))
      mstore(add(0x80, store_data), _ver_init_address)
      // Set version initialization function signature
      mstore(add(0xa0, store_data), mload(add(0xa0, ver_reg)))
      mstore(add(0xc0, store_data), _init_sig)

      // Loop through description and place in return request
      for { let offset := 0x00 } lt(offset, add(0x20, mload(_init_description))) { offset := add(0x20, offset) } {
        // Place description storage location in return request
        mstore(add(add(0xe0, mul(2, offset)), store_data), add(offset, mload(add(0xc0, ver_reg))))
        // Place description chunk in return request
        mstore(add(add(0x0100, mul(2, offset)), store_data), mload(add(offset, _init_description)))
      }
    }
  }

  // Parses context array and returns sender address and execution id
  function parse(bytes _context) internal pure returns (address from, bytes32 exec_id) {
    assembly {
      exec_id := mload(add(0x20, _context))
      from := mload(add(0x40, _context))
    }
    // Ensure neither field is zero
    require(from != address(0) && exec_id != bytes32(0));
  }
}
