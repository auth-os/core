pragma solidity ^0.4.21;

library InitRegistry {

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

  /// FUNCTION STORAGE ///

  // Function namespace - function information is mapped here
  // [PROVIDERS][provider_id][APPS][app_hash][VERSIONS][ver_hash][FUNCTIONS][func_signature]
  bytes32 public constant FUNCTIONS = keccak256("functions");

  // Storage location of a function's implementing address
  // [PROVIDERS][provider_id][APPS][app_hash][VERSIONS][ver_hash][FUNCTIONS][func_signature][FUNC_IMPL_ADDR] = address implementation
  bytes32 public constant FUNC_IMPL_ADDR = keccak256("function_impl_addr");

  // Storage location of a function's description
  // [PROVIDERS][provider_id][APPS][app_hash][VERSIONS][ver_hash][FUNCTIONS][func_signature][FUNC_DESC] = bytes description
  bytes32 public constant FUNC_DESC = keccak256("func_desc");

  /// FUNCTION SELECTORS ///

  // Function selector for storage "read"
  // read(bytes32 _exec_id, bytes32 _location) view returns (bytes32 data_read);
  bytes4 public constant RD_SING = bytes4(keccak256("read(bytes32,bytes32)"));

  // Function selector for storage "readMulti"
  // readMulti(bytes32 _exec_id, bytes32[] _locations) view returns (bytes32[] data_read)
  bytes4 public constant RD_MULTI = bytes4(keccak256("readMulti(bytes32,bytes32[])"));

  /// SCRIPT REGISTRY INIT ///

  // Empty init function for simple script registry
  function init() public pure { }

  /// PROVIDER INFORMATION ///

  /*
  Returns a list of all applications registered by the provider

  @param _storage: The address where the registry's storage is located
  @param _exec_id: The execution id associated with the registry
  @param _provider: The provider's id
  @return registered_apps: A list of the names of all applications registered by this provider
  */
  function getProviderInfo(address _storage, bytes32 _exec_id, bytes32 _provider) public view
  returns (bytes32[] registered_apps) {
    // Ensure valid input
    require(_storage != address(0) && _exec_id != bytes32(0) && _provider != bytes32(0));

    // Place 'read' and 'readMulti' function selectors in memory
    bytes4 rd_sing = RD_SING;
    bytes4 rd_multi = RD_MULTI;

    // Get provider base storage location
    bytes32 provider_storage = keccak256(_provider, PROVIDERS);
    // Get provider registered app list location
    bytes32 provider_apps = keccak256(PROVIDER_APP_LIST, provider_storage);

    assembly {
      // Read provider app list length from storage -

      // Get pointer to store calldata in
      let ptr := mload(0x40)
      // Place 'read' selector, exec id, and provider app list storage location in calldata
      mstore(ptr, rd_sing)
      mstore(add(0x04, ptr), _exec_id)
      mstore(add(0x24, ptr), provider_apps)

      // Read from storage and check return value. Store returned data at pointer
      if iszero(
        staticcall(gas, _storage, ptr, 0x44, ptr, 0x20)
      ) { revert (0, 0) }

      // Get provider app list length
      let app_count := mload(ptr)

      // Read app list from storage -

      // Place 'readMulti' selector, exec id, data read offset, and read size in calldata
      mstore(ptr, rd_multi)
      mstore(add(0x04, ptr), _exec_id)
      mstore(add(0x24, ptr), 0x40)
      mstore(add(0x44, ptr), app_count)
      // Loop over app count and store list offsets in calldata
      for { let offset := 0x20 } lt(offset, add(0x20, mul(0x20, app_count))) { offset := add(0x20, offset) } {
        mstore(add(add(0x44, offset), ptr), add(offset, provider_apps))
      }
      // Read from storage and check return value
      if iszero(
        staticcall(gas, _storage, ptr, add(0x64, mul(0x20, app_count)), 0, 0)
      ) { revert (0, 0) }

      // Get memory for return value and copy returned data to return value
      registered_apps := add(0x20, msize)
      mstore(registered_apps, app_count)
      returndatacopy(add(0x20, registered_apps), 0x40, sub(returndatasize, 0x40))
    }
  }

  /*
  Returns a list of all applications registered by the provider

  @param _storage: The address where the registry's storage is located
  @param _exec_id: The execution id associated with the registry
  @param _provider: The provider's address
  @return provider: The hash id associated with this provider
  @return registered_apps: A list of the names of all applications registered by this provider
  */
  function getProviderInfoFromAddress(address _storage, bytes32 _exec_id, address _provider) public view
  returns (bytes32 provider, bytes32[] registered_apps) {
    // Ensure valid input
    require(_storage != address(0) && _exec_id != bytes32(0) && _provider != address(0));

    // Place 'read' and 'readMulti' function selectors in memory
    bytes4 rd_sing = RD_SING;
    bytes4 rd_multi = RD_MULTI;

    // Get provider base storage location
    provider = keccak256(_provider);
    bytes32 provider_storage = keccak256(provider, PROVIDERS);
    // Get provider registered app list location
    bytes32 provider_apps = keccak256(PROVIDER_APP_LIST, provider_storage);

    assembly {
      // Read provider app list length from storage -

      // Get pointer to store calldata in
      let ptr := mload(0x40)
      // Place 'read' selector, exec id, and provider app list storage location in calldata
      mstore(ptr, rd_sing)
      mstore(add(0x04, ptr), _exec_id)
      mstore(add(0x24, ptr), provider_apps)

      // Read from storage and check return value. Store returned data at pointer
      if iszero(
        staticcall(gas, _storage, ptr, 0x44, ptr, 0x20)
      ) { revert (0, 0) }

      // Get provider app list length
      let app_count := mload(ptr)

      // Read app list from storage -

      // Place 'readMulti' selector, exec id, data read offset, and read size in calldata
      mstore(ptr, rd_multi)
      mstore(add(0x04, ptr), _exec_id)
      mstore(add(0x24, ptr), 0x40)
      mstore(add(0x44, ptr), app_count)
      // Loop over app count and store list offsets in calldata
      for { let offset := 0x20 } lt(offset, add(0x20, mul(0x20, app_count))) { offset := add(0x20, offset) } {
        mstore(add(add(0x44, offset), ptr), add(offset, provider_apps))
      }
      // Read from storage and check return value
      if iszero(
        staticcall(gas, _storage, ptr, add(0x64, mul(0x20, app_count)), 0, 0)
      ) { revert (0, 0) }

      // Get memory for return value and copy returned data to return value
      registered_apps := add(0x20, msize)
      // Copy app list length and data and store in return value
      returndatacopy(registered_apps, 0x20, sub(returndatasize, 0x20))
    }
  }

  /// APPLICATION INFORMATION ///

  struct AppInfo {
    bytes4 rd_multi;
    bytes32 app_storage_loc;
    bytes32 app_version_list_loc;
    bytes32 app_default_storage_loc;
    bytes32 app_description_loc;
  }

  /*
  Returns basic information on an application

  @param _storage: The address where the registry's storage is located
  @param _exec_id: The execution id associated with the registry
  @param _provider: The provider id under which the application was registered
  @param _app: The name of the application registered
  @return num_versions: The number of versions of an application
  @return app_default_storage: The default storage location for an application. All versions use this storage location, unless they specify otherwise
  @return app_description: The bytes of an application's description
  */
  function getAppInfo(address _storage, bytes32 _exec_id, bytes32 _provider, bytes32 _app) public view
  returns (uint num_versions, address app_default_storage, bytes app_description) {
    // Ensure valid input
    require(_storage != address(0) && _exec_id != bytes32(0));
    require(_provider != bytes32(0) && _app != bytes32(0));

    // Create struct in memory to hold values
    AppInfo memory app_info = AppInfo({
      rd_multi: RD_MULTI,
      app_storage_loc: keccak256(_provider, PROVIDERS),
      // Placeholders
      app_version_list_loc: 0,
      app_default_storage_loc: 0,
      app_description_loc: 0
    });

    // Get app base storage location
    app_info.app_storage_loc = keccak256(APPS, app_info.app_storage_loc);
    app_info.app_storage_loc = keccak256(keccak256(_app), app_info.app_storage_loc);

    // Get app version list size storage location
    app_info.app_version_list_loc = keccak256(APP_VERSIONS_LIST, app_info.app_storage_loc);
    // Get app default storage address storage location
    app_info.app_default_storage_loc = keccak256(APP_STORAGE_IMPL, app_info.app_storage_loc);
    // Get app description size storage location
    app_info.app_description_loc = keccak256(APP_DESC, app_info.app_storage_loc);

    assembly {
      // Read app version count, default storage addres, and description size -

      // Get pointer to store calldata in
      let ptr := mload(0x40)
      // Place 'readMulti' selector, exec id, data read offset, and read size in calldata
      mstore(ptr, mload(app_info))
      mstore(add(0x04, ptr), _exec_id)
      mstore(add(0x24, ptr), 0x40)
      mstore(add(0x44, ptr), 3)
      // Place app version list count, app default storage, and app description size storage locations in calldata
      mstore(add(0x64, ptr), mload(add(0x40, app_info)))
      mstore(add(0x84, ptr), mload(add(0x60, app_info)))
      mstore(add(0xa4, ptr), mload(add(0x80, app_info)))

      // Read from storage and check return value. Store returned data at pointer
      if iszero(
        staticcall(gas, _storage, ptr, 0xc4, ptr, 0xa0)
      ) { revert (0, 0) }

      // Get returned values
      num_versions := mload(add(0x40, ptr))
      app_default_storage := mload(add(0x60, ptr))
      let desc_size := mload(add(0x80, ptr))

      // Get memory for app description return value, and store description size
      app_description := add(0x20, msize)
      mstore(app_description, desc_size)

      // Normalize description size to read from 32-byte slots
      desc_size := div(desc_size, 0x20)
      if gt(mod(mload(app_description), 0x20), 0) { desc_size := add(1, desc_size) }

      // Read app description from storage -

      // Place 'readMulti' selector, exec id, data read offset, and read size in calldata
      mstore(ptr, mload(app_info))
      mstore(add(0x04, ptr), _exec_id)
      mstore(add(0x24, ptr), 0x40)
      mstore(add(0x44, ptr), desc_size)
      // Loop over description size and store list offsets in calldata
      for { let offset := 0x20 } lt(offset, add(0x20, mload(app_description))) { offset := add(0x20, offset) } {
        mstore(add(add(0x44, offset), ptr), add(offset, mload(add(0x80, app_info))))
      }
      // Read from storage and check return value
      if iszero(
        staticcall(gas, _storage, ptr, add(0x64, mul(0x20, desc_size)), 0, 0)
      ) { revert (0, 0) }

      // Copy description to return value
      returndatacopy(add(0x20, app_description), 0x40, sub(returndatasize, 0x40))
    }
  }

  /*
  Returns a list of all versions registered in an application

  @param _storage: The address where the registry's storage is located
  @param _exec_id: The execution id associated with the registry
  @param _provider: The provider id under which the application was registered
  @param _app: The name of the application registered
  @return version_list: A list of all version names associated with this application, in order from oldest to latest
  */
  function getAppVersions(address _storage, bytes32 _exec_id, bytes32 _provider, bytes32 _app) public view
  returns (uint app_version_count, bytes32[] version_list) {
    // Ensure valid input
    require(_storage != address(0) && _exec_id != bytes32(0));
    require(_provider != bytes32(0) && _app != bytes32(0));

    // Place 'read' and 'readMulti' function selectors in memory
    bytes4 rd_sing = RD_SING;
    bytes4 rd_multi = RD_MULTI;

    // Get app version list storage location
    bytes32 app_version_list_loc = keccak256(_provider, PROVIDERS);
    app_version_list_loc = keccak256(APPS, app_version_list_loc);
    app_version_list_loc = keccak256(keccak256(_app), app_version_list_loc);
    app_version_list_loc = keccak256(APP_VERSIONS_LIST, app_version_list_loc);

    assembly {
      // Read app version count from storage -

      // Get pointer to store calldata in
      let ptr := mload(0x40)
      // Place 'read' selector, and exec id in callata
      mstore(ptr, rd_sing)
      mstore(add(0x04, ptr), _exec_id)
      // Place app version list count location in calldata
      mstore(add(0x24, ptr), app_version_list_loc)

      // Read from storage and check return value. Store returned data at pointer
      if iszero(
        staticcall(gas, _storage, ptr, 0x44, ptr, 0x20)
      ) { revert (0, 0) }

      // Get app version count
      app_version_count := mload(ptr)

      // Read app version list from storage -

      // Place 'readMulti' selector, exec id, data read offset, and read size in calldata
      mstore(ptr, rd_multi)
      mstore(add(0x04, ptr), _exec_id)
      mstore(add(0x24, ptr), 0x40)
      mstore(add(0x44, ptr), app_version_count)
      // Loop over version count and store list offsets in calldata
      for { let offset := 0x20 } lt(offset, add(0x20, mul(0x20, app_version_count))) { offset := add(0x20, offset) } {
        mstore(add(add(0x44, offset), ptr), add(offset, app_version_list_loc))
      }
      // Read from storage and check return value
      if iszero(
        staticcall(gas, _storage, ptr, add(0x64, mul(0x20, app_version_count)), 0, 0)
      ) { revert (0, 0) }

      // Get memory for return value and copy returned data to return value
      version_list := add(0x20, msize)
      // Copy list length and data to return value
      returndatacopy(version_list, 0x20, sub(returndatasize, 0x20))
    }
  }

  struct AppLatest {
    bytes4 rd_multi;
    bytes4 rd_sing;
    bytes32 app_storage_loc;
    bytes32 app_default_storage_loc;
    bytes32 app_version_list_loc;
    bytes32 ver_storage_seed;
    bytes32 ver_status_loc;
    bytes32 ver_init_addr_loc;
    bytes32 ver_function_addrs_loc;
    bytes32 ver_storage_addr_loc;
  }

  /*
  Returns initialization and allowed addresses for the latest finalized version of an application

  @param _storage: The address where the registry's storage is located
  @param _exec_id: The execution id associated with the registry
  @param _provider: The provider id under which the application was registered
  @param _app: The name of the application registered
  @return app_storage_addr: The address where instance storage will be located
  @return latest_version: The name of the latest version of the application
  @return app_init_addr: The address which contains the application's init function
  @return allowed: An array of addresses whcih implement the application's functions
  */
  function getAppLatestInfo(address _storage, bytes32 _exec_id, bytes32 _provider, bytes32 _app) public view
  returns (address app_storage_addr, bytes32 latest_version, address app_init_addr, address[] allowed) {
    // Ensure valid input
    require(_storage != address(0) && _exec_id != bytes32(0));
    require(_provider != bytes32(0) && _app != bytes32(0));

    // Create struct in memory to hold values
    AppLatest memory app_info = AppLatest({
      rd_multi: RD_MULTI,
      rd_sing: RD_SING,
      app_storage_loc: keccak256(_provider, PROVIDERS),
      // Placeholders
      app_default_storage_loc: 0,
      app_version_list_loc: 0,
      ver_storage_seed: 0,
      ver_status_loc: VER_IS_FINALIZED,
      ver_init_addr_loc: VER_INIT_ADDR,
      ver_function_addrs_loc: VER_FUNCTION_ADDRESSES,
      ver_storage_addr_loc: VER_STORAGE_IMPL
    });

    // Get app base storage location
    app_info.app_storage_loc = keccak256(APPS, app_info.app_storage_loc);
    app_info.app_storage_loc = keccak256(keccak256(_app), app_info.app_storage_loc);
    // Get app default storage address storage location
    app_info.app_default_storage_loc = keccak256(APP_STORAGE_IMPL, app_info.app_storage_loc);
    // Get app version list size storage location
    app_info.app_version_list_loc = keccak256(APP_VERSIONS_LIST, app_info.app_storage_loc);
    // Get version base storage seed
    app_info.ver_storage_seed = keccak256(VERSIONS, app_info.app_storage_loc);

    assembly {
      // Check that application is registered, read app default storage address, and get app version list length -

      let offset := 0
      let list_length := 0
      // Get pointer to store calldata in
      let ptr := mload(0x40)
      // Place 'readMulti' selector, exec id, data read offset, and read size in calldata
      mstore(ptr, mload(app_info))
      mstore(add(0x04, ptr), _exec_id)
      mstore(add(0x24, ptr), 0x40)
      mstore(add(0x44, ptr), 3)
      // Place app storage location, app default storage address location, and app version list length locations in calldata
      mstore(add(0x64, ptr), mload(add(0x40, app_info)))
      mstore(add(0x84, ptr), mload(add(0x60, app_info)))
      mstore(add(0xa4, ptr), mload(add(0x80, app_info)))

      // Read from storage and check return value. Store returned data at pointer
      if iszero(
        staticcall(gas, _storage, ptr, 0xc4, ptr, 0xa0)
      ) { revert (0, 0) }

      // Get returned values -
      // Read returned app storage location - if zero, application is not registered: revert
      if iszero(mload(add(0x40, ptr))) { revert (0, 0) }
      // Get app default storage address
      app_storage_addr := mload(add(0x60, ptr))
      // Get app version list length
      list_length := mload(add(0x80, ptr))

      // If version list length is zero, no versions have been registered - revert
      if iszero(list_length) { revert (0, 0) }

      // Application is registered: find latest version information -

      // Loop backwards through each version to find the latest finalized version
      for { offset := mul(0x20, list_length) } gt(add(0x20, offset), 0x20) { offset := sub(offset, 0x20) } {
        // Read function name from app version list - construct 'read' calldata
        mstore(ptr, mload(add(0x20, app_info)))
        // Store exec id and version list location in calldata
        mstore(add(0x04, ptr), _exec_id)
        mstore(add(0x24, ptr), add(offset, mload(add(0x80, app_info))))
        // Read version name from storage and store return at pointer
        if iszero(
          staticcall(gas, _storage, ptr, 0x44, ptr, 0x20)
        ) { revert (0, 0) }
        // Get returned version name
        latest_version := mload(ptr)

        // Get version storage location -

        // Hash returned version name, and store in temporary location for further hashing
        mstore(0, latest_version)
        mstore(0, keccak256(0, 0x20))
        // Place version storage seed after hashed version name
        mstore(0x20, mload(add(0xa0, app_info)))
        // Hash version name and version storage seed, and place at 0x20 for further hashing. The result is the version base storage location
        mstore(0x20, keccak256(0, 0x40))

        // Get version information - construct 'readMulti' calldata
        mstore(ptr, mload(app_info))
        // Place exec id, data read offset, and read size in calldata
        mstore(add(0x04, ptr), _exec_id)
        mstore(add(0x24, ptr), 0x40)
        mstore(add(0x44, ptr), 4)
        // Get version status storage location, and store in calldata
        mstore(0, mload(add(0xc0, app_info)))
        mstore(add(0x64, ptr), keccak256(0, 0x40))
        // Get version init address storage location, and store in calldata
        mstore(0, mload(add(0xe0, app_info)))
        mstore(add(0x84, ptr), keccak256(0, 0x40))
        // Get version address list length location, and store in calldata
        mstore(0, mload(add(0x0100, app_info)))
        mstore(add(0xa4, ptr), keccak256(0, 0x40))
        // Get version storage address location, and store in calldata
        mstore(0, mload(add(0x0120, app_info)))
        mstore(add(0xc4, ptr), keccak256(0, 0x40))
        // Read from storage, and store return at pointer
        if iszero(
          staticcall(gas, _storage, ptr, 0xe4, ptr, 0xc0)
        ) { revert (0, 0) }
        // Check version status - if nonzero, this version is finalized and is the latest version
        if gt(mload(add(0x40, ptr)), 0) {
          // Set offset to 0x20 - will terminate the loop
          offset := 0x20
          // Get version initialization address from returned data
          app_init_addr := mload(add(0x60, ptr))
          // Get version address list length
          list_length := mload(add(0x80, ptr))
          // Get version specified storage address
          app_storage_addr := mload(add(0xa0, ptr))
        }
        // If version is finalized, offset is 0x20 and the loop will terminate. Otherwise, continue looping
      }

      // If app_init_addr is zero, a finalized version was not found - revert
      if iszero(app_init_addr) { revert (0, 0) }

      // Otherwise, get version allowed addresses -

      mstore(ptr, mload(app_info))
      // Store exec id, data read offset, and read size in calldata
      mstore(add(0x04, ptr), _exec_id)
      mstore(add(0x24, ptr), 0x40)
      mstore(add(0x44, ptr), list_length)
      // Get version address list storage location, and place in app_info
      mstore(0, mload(add(0x0100, app_info)))
      mstore(add(0x0100, app_info), keccak256(0, 0x40))
      // Loop over list length and place each index in calldata
      for { offset := 0x20 } lt(offset, add(0x20, mul(0x20, list_length))) { offset := add(0x20, offset) } {
        // Get list index location and tore in calldata
        mstore(add(add(0x44, offset), ptr), add(offset, mload(add(0x0100, app_info))))
      }
      // Read from storage and store return at pointer
      if iszero(
        staticcall(gas, _storage, ptr, add(0x64, mul(0x20, list_length)), ptr, add(0x40, mul(0x20, list_length)))
      ) { revert (0, 0) }

      // Allocate space for return allowed array
      allowed := add(0x20, msize)
      // Copy allowed addresses from returned data
      returndatacopy(allowed, 0x20, sub(returndatasize, 0x20))
    }
  }

  /// VERSION INFORMATION ///

  /*
  ** Applications are versioned. Each version may use its own storage address,
  ** overriding the designated application storage address. Versions may implement
  ** the same, or entirely different functions compared to other versions of the
  ** same application.
  **
  ** A provider may implement and alter a version as much as they want - but
  ** finalizing a version locks implementation details in stone. Versions have
  ** lists of functions they implement, along with the addresses which implement
  ** these functions, and descriptions of the implemented function.
  **
  ** An version instance is initialized through the version's 'init' function,
  ** which acts much like a constructor - but for a specific execution id.
  */

  struct VerInfo {
    bytes4 rd_multi;
    bytes32 ver_storage_loc;
    bytes32 ver_status_loc;
    bytes32 ver_function_list_loc;
    bytes32 ver_storage_addr_loc;
    bytes32 ver_description_loc;
  }

  /*
  Returns basic information on a version of an application

  @param _storage: The address where the registry's storage is located
  @param _exec_id: The execution id associated with the registry
  @param _provider: The provider id under which the application was registered
  @param _app: The name of the application registered
  @param _version: The name of the version registered
  @return is_finalized: Whether the provider has designated that this version is stable and ready for deployment and use
  @return num_functions: The number of functions this version implements
  @return version_storage: The storage address used by this version. Can be the same as, or different than the application's default storage address
  @return version_description: The bytes of a version's description
  */
  function getVersionInfo(address _storage, bytes32 _exec_id, bytes32 _provider, bytes32 _app, bytes32 _version) public view
  returns (bool is_finalized, uint num_functions, address version_storage, bytes version_description) {
    // Ensure valid input
    require(_storage != address(0) && _exec_id != bytes32(0));
    require(_provider != bytes32(0) && _app != bytes32(0) && _version != bytes32(0));

    // Create struct in memory to hold values
    VerInfo memory ver_info = VerInfo({
      rd_multi: RD_MULTI,
      // Placeholders
      ver_storage_loc: keccak256(_provider, PROVIDERS),
      ver_status_loc: 0,
      ver_function_list_loc: 0,
      ver_storage_addr_loc: 0,
      ver_description_loc: 0
    });

    // Get version base storage location
    ver_info.ver_storage_loc = keccak256(APPS, ver_info.ver_storage_loc);
    ver_info.ver_storage_loc = keccak256(keccak256(_app), ver_info.ver_storage_loc);
    ver_info.ver_storage_loc = keccak256(VERSIONS, ver_info.ver_storage_loc);
    ver_info.ver_storage_loc = keccak256(keccak256(_version), ver_info.ver_storage_loc);

    // Get version finalization status storage location
    ver_info.ver_status_loc = keccak256(VER_IS_FINALIZED, ver_info.ver_storage_loc);
    // Get version function list size storage location
    ver_info.ver_function_list_loc = keccak256(VER_FUNCTION_LIST, ver_info.ver_storage_loc);
    // Get version storage address location
    ver_info.ver_storage_addr_loc = keccak256(VER_STORAGE_IMPL, ver_info.ver_storage_loc);
    // Get version description storage location
    ver_info.ver_description_loc = keccak256(VER_DESC, ver_info.ver_storage_loc);

    assembly {
      // Read version finalization status, function count, storage address, and description size -

      // Get pointer to store calldata in
      let ptr := mload(0x40)
      // Place 'readMulti' selector, exec id, data read offset, and read size in calldata
      mstore(ptr, mload(ver_info))
      mstore(add(0x04, ptr), _exec_id)
      mstore(add(0x24, ptr), 0x40)
      mstore(add(0x44, ptr), 4)
      // Place version status, function count, storage address, and description size storage locations in calldata
      mstore(add(0x64, ptr), mload(add(0x40, ver_info)))
      mstore(add(0x84, ptr), mload(add(0x60, ver_info)))
      mstore(add(0xa4, ptr), mload(add(0x80, ver_info)))
      mstore(add(0xc4, ptr), mload(add(0xa0, ver_info)))

      // Read from storage and check return value. Store returned data at pointer
      if iszero(
        staticcall(gas, _storage, ptr, 0xe4, ptr, 0xc0)
      ) { revert (0, 0) }

      // Get returned values
      is_finalized := mload(add(0x40, ptr))
      num_functions := mload(add(0x60, ptr))
      version_storage := mload(add(0x80, ptr))
      let desc_size := mload(add(0xa0, ptr))

      // Get memory for return value. Set version description length
      version_description := add(0x20, msize)
      mstore(version_description, desc_size)

      // Normalize description size to read from 32-byte slots
      desc_size := div(desc_size, 0x20)
      if gt(mod(mload(version_description), 0x20), 0) { desc_size := add(1, desc_size) }

      // Read version description from storage -

      // Place 'readMulti' selector, exec id, data read offset, and read size in calldata
      mstore(ptr, mload(ver_info))
      mstore(add(0x04, ptr), _exec_id)
      mstore(add(0x24, ptr), 0x40)
      mstore(add(0x44, ptr), desc_size)
      // Loop over description size and store list offsets in calldata
      for { let offset := 0x20 } lt(offset, add(0x20, mload(version_description))) { offset := add(0x20, offset) } {
        mstore(add(add(0x44, offset), ptr), add(offset, mload(add(0xa0, ver_info))))
      }
      // Read from storage and check return value
      if iszero(
        staticcall(gas, _storage, ptr, add(0x64, mul(0x20, desc_size)), 0, 0)
      ) { revert (0, 0) }

      // Copy description data to return value
      returndatacopy(add(0x20, version_description), 0x40, sub(returndatasize, 0x40))
    }
  }

  struct VerInitInfo {
    bytes4 rd_multi;
    bytes32 ver_storage_loc;
    bytes32 ver_init_impl_loc;
    bytes32 ver_init_sig_loc;
    bytes32 ver_init_desc_loc;
  }

  /*
  Returns information on an version's initialization address and function. The initialization address and function are
  treated like a version's constructor.

  @param _storage: The address where the registry's storage is located
  @param _exec_id: The execution id associated with the registry
  @param _provider: The provider id under which the application was registered
  @param _app: The name of the application registered
  @param _version: The name of the version registered
  @return init_impl: The address where the version's init function is located
  @return init_signature: The 4-byte function selector used for the app's init function
  @return init_description: The bytes of the version's initialization description
  */
  function getVersionInitInfo(address _storage, bytes32 _exec_id, bytes32 _provider, bytes32 _app, bytes32 _version) public view
  returns (address init_impl, bytes4 init_signature, bytes init_description) {
    // Ensure valid input
    require(_storage != address(0) && _exec_id != bytes32(0));
    require(_provider != bytes32(0) && _app != bytes32(0) && _version != bytes32(0));

    // Create struct in memory to hold values
    VerInitInfo memory ver_info = VerInitInfo({
      rd_multi: RD_MULTI,
      // Placeholders
      ver_storage_loc: keccak256(_provider, PROVIDERS),
      ver_init_impl_loc: 0,
      ver_init_sig_loc: 0,
      ver_init_desc_loc: 0
    });

    // Get version base storage location
    ver_info.ver_storage_loc = keccak256(APPS, ver_info.ver_storage_loc);
    ver_info.ver_storage_loc = keccak256(keccak256(_app), ver_info.ver_storage_loc);
    ver_info.ver_storage_loc = keccak256(VERSIONS, ver_info.ver_storage_loc);
    ver_info.ver_storage_loc = keccak256(keccak256(_version), ver_info.ver_storage_loc);

    // Get version initialization implementing address locaiton
    ver_info.ver_init_impl_loc = keccak256(VER_INIT_ADDR, ver_info.ver_storage_loc);
    // Get version initialization signature location
    ver_info.ver_init_sig_loc = keccak256(VER_INIT_SIG, ver_info.ver_storage_loc);
    // Get version init function description location
    ver_info.ver_init_desc_loc = keccak256(VER_INIT_DESC, ver_info.ver_storage_loc);

    assembly {
      // Read version initialization address, initialization function signature, and init function description length -

      // Get pointer to store calldata in
      let ptr := mload(0x40)
      // Place 'readMulti' selector, exec id, data read offset, and read size in calldata
      mstore(ptr, mload(ver_info))
      mstore(add(0x04, ptr), _exec_id)
      mstore(add(0x24, ptr), 0x40)
      mstore(add(0x44, ptr), 3)
      // Place init implementating address, init function signature, and description size locations in calldata
      mstore(add(0x64, ptr), mload(add(0x40, ver_info)))
      mstore(add(0x84, ptr), mload(add(0x60, ver_info)))
      mstore(add(0xa4, ptr), mload(add(0x80, ver_info)))

      // Read from storage and check return value. Store returned data at pointer
      if iszero(
        staticcall(gas, _storage, ptr, 0xc4, ptr, 0xa0)
      ) { revert (0, 0) }

      // Get returned values
      init_impl := mload(add(0x40, ptr))
      init_signature := mload(add(0x60, ptr))
      let desc_size := mload(add(0x80, ptr))

      // Get memory for return value and set length
      init_description := add(0x20, msize)
      mstore(init_description, desc_size)

      // Normalize description size to read from 32-byte slots
      desc_size := div(desc_size, 0x20)
      if gt(mod(mload(init_description), 0x20), 0) { desc_size := add(1, desc_size) }

      // Read version init function description from storage -

      // Place 'readMulti' selector, exec id, data read offset, and read size in calldata
      mstore(ptr, mload(ver_info))
      mstore(add(0x04, ptr), _exec_id)
      mstore(add(0x24, ptr), 0x40)
      mstore(add(0x44, ptr), desc_size)
      // Loop over description size and store list offsets in calldata
      for { let offset := 0x20 } lt(offset, add(0x20, mload(init_description))) { offset := add(0x20, offset) } {
        mstore(add(add(0x44, offset), ptr), add(offset, mload(add(0x80, ver_info))))
      }
      // Read from storage and check return value
      if iszero(
        staticcall(gas, _storage, ptr, add(0x64, mul(0x20, desc_size)), 0, 0)
      ) { revert (0, 0) }

      // Copy description length and data to return value
      returndatacopy(add(0x20, init_description), 0x40, sub(returndatasize, 0x40))
    }
  }

  struct VerImplInfo {
    bytes4 rd_multi;
    bytes32 ver_storage_loc;
    bytes32 ver_function_list_loc;
    bytes32 ver_function_addr_list_loc;
  }

  /*
  Returns information on an version's implementation details: all implemented functions, and their addresses
  Descriptions for each function can be found by calling 'getImplementationInfo'

  @param _storage: The address where the registry's storage is located
  @param _exec_id: The execution id associated with the registry
  @param _provider: The provider id under which the application was registered
  @param _app: The name of the application registered
  @param _version: The name of the version registered
  @return function_signatures: A list of all the function selectors implemented in this version
  @return function_locations: The addresses where each corresponding function is implemented
  */
  function getVersionImplementation(address _storage, bytes32 _exec_id, bytes32 _provider, bytes32 _app, bytes32 _version) public view
  returns (bytes4[] function_signatures, address[] function_locations) {
    // Ensure valid input
    require(_storage != address(0) && _exec_id != bytes32(0));
    require(_provider != bytes32(0) && _app != bytes32(0) && _version != bytes32(0));

    // Place 'readMulti' function selector in memory
    bytes4 rd_multi = RD_MULTI;

    // Get version function signature and function address storage locations
    bytes32 ver_function_list_loc = keccak256(_provider, PROVIDERS);
    ver_function_list_loc = keccak256(APPS, ver_function_list_loc);
    ver_function_list_loc = keccak256(keccak256(_app), ver_function_list_loc);
    ver_function_list_loc = keccak256(VERSIONS, ver_function_list_loc);
    ver_function_list_loc = keccak256(keccak256(_version), ver_function_list_loc);

    bytes32 ver_function_addr_list_loc = keccak256(VER_FUNCTION_ADDRESSES, ver_function_list_loc);
    ver_function_list_loc = keccak256(VER_FUNCTION_LIST, ver_function_list_loc);

    assembly {
      // Read and compare version function list length and address list length -

      // Get pointer to store calldata in
      let ptr := mload(0x40)
      // Place 'readMulti' selector, exec id, data read offset, and read size in calldata
      mstore(ptr, rd_multi)
      mstore(add(0x04, ptr), _exec_id)
      mstore(add(0x24, ptr), 0x40)
      mstore(add(0x44, ptr), 2)
      // Place signature list and address list storage locations in calldata
      mstore(add(0x64, ptr), ver_function_list_loc)
      mstore(add(0x84, ptr), ver_function_addr_list_loc)

      // Read from storage and check return value. Store returned data at pointer
      if iszero(
        staticcall(gas, _storage, ptr, 0xa4, ptr, 0x80)
      ) { revert (0, 0) }

      // Get returned values, and ensure they are equal
      let read_size := mload(add(0x40, ptr))
      if iszero(eq(read_size, mload(add(0x60, ptr)))) { revert (0, 0) }

      // Read version function signature and address list from storage -

      // Place 'readMulti' selector, exec id, data read offset, and read size in calldata
      mstore(ptr, rd_multi)
      mstore(add(0x04, ptr), _exec_id)
      mstore(add(0x24, ptr), 0x40)
      mstore(add(0x44, ptr), mul(2, read_size))
      // Loop over read size - store function signature and address locations in calldata

      for { let offset := 0x20 } lt(offset, add(0x20, mul(0x20, read_size))) { offset := add(0x20, offset) } {
        mstore(add(add(0x44, offset), ptr), add(offset, ver_function_list_loc))
        mstore(add(add(add(0x44, mul(0x20, read_size)), offset), ptr), add(offset, ver_function_addr_list_loc))
      }
      // Read from storage and check return value
      if iszero(
        staticcall(gas, _storage, ptr, add(0x64, mul(0x40, read_size)), 0, 0)
      ) { revert (0, 0) }

      // Get memory for return values and copy returned data to return data
      function_signatures := add(0x20, msize)
      // Set list length
      mstore(function_signatures, read_size)
      // Copy signature list length and data to return value
      returndatacopy(
        add(0x20, function_signatures),
        0x40,
        mul(0x20, read_size)
      )
      function_locations := add(add(0x20, mul(0x20, read_size)), function_signatures)
      // Set list length
      mstore(function_locations, read_size)
      // Copy signature list length and data to return value
      returndatacopy(
        add(0x20, function_locations),
        sub(returndatasize, mul(0x20, read_size)),
        mul(0x20, read_size)
      )
    }
  }

  /*
  Returns information on an implemented function for a version

  @param _storage: The address where the registry's storage is located
  @param _exec_id: The execution id associated with the registry
  @param _provider: The provider id under which the application was registered
  @param _app: The name of the application registered
  @param _version: The name of the version registered
  @param _impl_signature: The 4-byte function selector about which information will be returned
  @return impl_location: The address which implements the given function
  @return impl_description: The bytes of the function's description
  */
  function getImplementationInfo(address _storage, bytes32 _exec_id, bytes32 _provider, bytes32 _app, bytes32 _version, bytes4 _impl_signature) public view
  returns (address impl_location, bytes impl_description) {
    // Ensure valid input
    require(_storage != address(0) && _exec_id != bytes32(0));
    require(_provider != bytes32(0) && _app != bytes32(0) && _version != bytes32(0) && _impl_signature != bytes4(0));

    // Place 'readMulti' function selector in memory
    bytes4 rd_multi = RD_MULTI;

    // Get function implementing address and function description locations
    bytes32 impl_storage_loc = keccak256(_provider, PROVIDERS);
    impl_storage_loc = keccak256(APPS, impl_storage_loc);
    impl_storage_loc = keccak256(keccak256(_app), impl_storage_loc);
    impl_storage_loc = keccak256(VERSIONS, impl_storage_loc);
    impl_storage_loc = keccak256(keccak256(_version), impl_storage_loc);
    impl_storage_loc = keccak256(FUNCTIONS, impl_storage_loc);
    impl_storage_loc = keccak256(keccak256(_impl_signature), impl_storage_loc);

    bytes32 impl_desc_loc = keccak256(FUNC_DESC, impl_storage_loc);
    impl_storage_loc = keccak256(FUNC_IMPL_ADDR, impl_storage_loc);

    assembly {
      // Read function implementing address and description size from storage -

      // Get pointer to store calldata in
      let ptr := mload(0x40)
      // Place 'readMulti' selector, exec id, data read offset, and read size in calldata
      mstore(ptr, rd_multi)
      mstore(add(0x04, ptr), _exec_id)
      mstore(add(0x24, ptr), 0x40)
      mstore(add(0x44, ptr), 2)
      // Place function implementing address and description length storage locations in calldata
      mstore(add(0x64, ptr), impl_storage_loc)
      mstore(add(0x84, ptr), impl_desc_loc)

      // Read from storage and check return value. Store returned data at pointer
      if iszero(
        staticcall(gas, _storage, ptr, 0xa4, ptr, 0x80)
      ) { revert (0, 0) }

      // Get returned values
      impl_location := mload(add(0x40, ptr))
      // Get memory for return value and set return length
      impl_description := add(mload(add(0x60, ptr)), msize)
      mstore(impl_description, mload(add(0x60, ptr)))

      // Read version init function description from storage -

      // Place 'readMulti' selector, exec id, and data read offset in calldata
      mstore(ptr, rd_multi)
      mstore(add(0x04, ptr), _exec_id)
      mstore(add(0x24, ptr), 0x40)
      // Normalize description length to read from 32-byte chunks, and store in calldata
      mstore(add(0x44, ptr), div(mload(impl_description), 0x20))
      if gt(mod(mload(impl_description), 0x20), 0) {
        mstore(add(0x44, ptr), add(1, mload(add(0x44, ptr))))
      }
      // Loop over description size and store list offsets in calldata
      // Use _app variable as a loop offset
      for { _app := 0x20 } lt(_app, add(0x20, mload(impl_description))) { _app := add(0x20, _app) } {
        mstore(add(add(0x44, _app), ptr), add(_app, impl_desc_loc))
      }
      // Read from storage and check return value
      if iszero(
        staticcall(gas, _storage, ptr, add(0x64, mul(0x20, mload(add(0x44, ptr)))), 0, 0)
      ) { revert (0, 0) }

      // Copy description data to return value
      returndatacopy(add(0x20, impl_description), 0x40, sub(returndatasize, 0x40))
    }
  }
}
