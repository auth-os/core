pragma solidity ^0.4.21;

library AppConsole {

  /// PROVIDER STORAGE ///

  // Provider namespace - all app and version storage is seeded to a provider
  // [PROVIDERS][provider_id]
  bytes32 public constant PROVIDERS = keccak256("registry_providers");

  // Storage location for a list of all applications released by this provider
  // [PROVIDERS][provider_id][PROVIDER_APP_LIST] = bytes32[] registered_apps
  bytes32 public constant PROVIDER_APP_LIST = keccak256("provider_app_list");

  /// APPLICATION STORAGE ///

  // Application namespace - all app info and version storage is mapped here
  // [PROVIDERS][provider_id][APPS][app_name]
  bytes32 public constant APPS = keccak256("apps");

  // Application description location - (bytes array)
  // [PROVIDERS][provider_id][APPS][app_name][APP_DESC] = bytes description
  bytes32 public constant APP_DESC = keccak256("app_desc");

  // Application version list location - (bytes32 array)
  // [PROVIDERS][provider_id][APPS][app_name][APP_VERSIONS_LIST] = bytes32[] version_names
  bytes32 public constant APP_VERSIONS_LIST = keccak256("app_versions_list");

  // Application storage address location - address
  // [PROVIDERS][provider_id][APPS][app_name][APP_STORAGE_IMPL] = address app_default_storage_addr
  bytes32 public constant APP_STORAGE_IMPL = keccak256("app_storage_impl");

  /// FUNCTION SELECTORS ///

  // Function selector for storage 'readMulti'
  // readMulti(bytes32 exec_id, bytes32[] locations)
  bytes4 public constant RD_MULTI = bytes4(keccak256("readMulti(bytes32,bytes32[])"));

  /// FUNCTIONS ///

  struct AppReg {
    bytes4 rd_multi;
    bytes32 provider_storage_loc;
    bytes32 provider_app_list_loc;
    bytes32 app_storage_loc;
    bytes32 app_description_loc;
    bytes32 app_default_storage_loc;
  }

  /*
  Registers an application under the sender's provider id

  @param _context: A 64-byte array containing execution context for the application. In order:
    1. Registry application execution id
    2. Original script sender (address, padded to 32 bytes)
  @param _app_name: The name of the application to be registered
  @param _app_storage: The storage address this application will use
  @param _app_desc: The description of the application
  @return store_data: A formatted storage request, which will be interpreted by the sender storage proxy to store app info
  */
  function registerApp(bytes _context, bytes32 _app_name, address _app_storage, bytes _app_desc) public view
  returns (bytes32[] store_data) {
    // Ensure input is correctly formatted
    require(_context.length == 64);
    require(_app_name != bytes32(0) && _app_desc.length > 0 && _app_storage != address(0));

    address provider;
    bytes32 exec_id;

    // Parse context array and get sender address and execution id
    (provider, exec_id) = parse(_context);

    // Initialize struct in memory to hold values
    AppReg memory app_reg = AppReg({
      rd_multi: RD_MULTI,
      provider_storage_loc: keccak256(keccak256(provider), PROVIDERS),
      // Placeholders
      provider_app_list_loc: 0,
      app_storage_loc: 0,
      app_description_loc: 0,
      app_default_storage_loc: 0
    });

    // Get provider app list storage location
    app_reg.provider_app_list_loc = keccak256(PROVIDER_APP_LIST, app_reg.provider_storage_loc);
    // Get app base storage location
    app_reg.app_storage_loc = keccak256(APPS, app_reg.provider_storage_loc);
    app_reg.app_storage_loc = keccak256(keccak256(_app_name), app_reg.app_storage_loc);
    // Get app description and default storage address storage locations
    app_reg.app_description_loc = keccak256(APP_DESC, app_reg.app_storage_loc);
    app_reg.app_default_storage_loc = keccak256(APP_STORAGE_IMPL, app_reg.app_storage_loc);

    uint num_apps;

    assembly {
      // Ensure application is not already registered by this provider, and get provider app list length -

      // Get pointer to store calldata in
      let ptr := mload(0x40)
      // Place 'readMulti' selector, registry execution id, data read offset, and read size in calldata
      mstore(ptr, mload(app_reg))
      mstore(add(0x04, ptr), exec_id)
      mstore(add(0x24, ptr), 0x40)
      mstore(add(0x44, ptr), 2)
      // Place app storage and provider app list length storage locations in calldata
      mstore(add(0x64, ptr), mload(add(0x60, app_reg)))
      mstore(add(0x84, ptr), mload(add(0x40, app_reg)))

      // Read from storage and check return value. Store returned data at pointer
      if iszero(
        staticcall(gas, caller, ptr, 0xa4, ptr, 0x80)
      ) { revert (0, 0) }

      // Get returned app storage location value - if nonzero, app is already registered: revert
      if gt(mload(add(0x40, ptr)), 0) { revert (0, 0) }
      // Get returned provider app list length
      num_apps := mload(add(0x60, ptr))

      // Application is unregistered - register application

      // Get return write size -
      let size := add(10, div(mload(_app_desc), 0x20))
      if gt(mod(mload(_app_desc), 0x20), 0) { size := add(2, size) }

      // Allocate space for return storage request
      store_data := add(0x20, msize)
      // Set return length
      mstore(store_data, size)

      // Set return values -

      // Push app name to end of provider app list
      mstore(add(0x20, store_data), add(add(0x20, mul(0x20, num_apps)), mload(add(0x40, app_reg))))
      mstore(add(0x40, store_data), _app_name)
      // Place app name in app base storage location
      mstore(add(0x60, store_data), mload(add(0x60, app_reg)))
      mstore(add(0x80, store_data), _app_name)
      // Store app default storage address
      mstore(add(0xa0, store_data), mload(add(0xa0, app_reg)))
      mstore(add(0xc0, store_data), _app_storage)
      // Increment provider app list length
      mstore(add(0xe0, store_data), mload(add(0x40, app_reg)))
      mstore(add(0x0100, store_data), add(1, num_apps))

      // Loop through description and place in return request
      for { let offset := 0x00 } lt(offset, add(0x20, mload(_app_desc))) { offset := add(0x20, offset) } {
        // Place description storage location in return request
        mstore(add(add(0x0120, mul(2, offset)), store_data), add(offset, mload(add(0x80, app_reg))))
        // Place description chunk in return request
        mstore(add(add(0x0140, mul(2, offset)), store_data), mload(add(offset, _app_desc)))
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
