pragma solidity ^0.4.23;

library InitRegistry {

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

  // Version function list location - (bytes4 array)
  // [PROVIDERS][provider_id][APPS][app_hash][VERSIONS][ver_name][VER_FUNCTION_LIST] = bytes4[] function_signatures
  bytes32 internal constant VER_FUNCTION_LIST = keccak256("ver_functions_list");

  // Version function address location - stores the address where each corresponding version's function is located
  // [PROVIDERS][provider_id][APPS][app_hash][VERSIONS][ver_name][VER_FUNCTION_ADDRESSES] = address[] function_addresses
  bytes32 internal constant VER_FUNCTION_ADDRESSES = keccak256("ver_function_addrs");

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

  /// FUNCTION SELECTORS ///

  bytes4 internal constant RD_SING = bytes4(keccak256("read(bytes32,bytes32)"));
  bytes4 internal constant RD_MULTI = bytes4(keccak256("readMulti(bytes32,bytes32[])"));

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
  returns (bytes32[] memory registered_apps) {
    // Ensure valid input
    require(_storage != address(0) && _exec_id != bytes32(0) && _provider != bytes32(0));

    // Create 'read' calldata buffer in memory
    uint ptr = cdBuff(RD_SING);
    // Push exec id to calldata buffer
    cdPush(ptr, _exec_id);
    // Place provider app list storage location in calldata buffer
    cdPush(ptr, keccak256(PROVIDER_APP_LIST, keccak256(_provider, PROVIDERS)));
    // Read single value from storage, and place return in buffer
    uint app_count = uint(readSingleFrom(ptr, _storage));

    // If the provider has not registered any applications, return an empty array
    if (app_count == 0)
      return registered_apps;

    // Overwrite previous read buffer with readMulti buffer
    cdOverwrite(ptr, RD_MULTI);
    // Place exec id, data read offset, and read size in calldata buffer
    cdPush(ptr, _exec_id);
    cdPush(ptr, 0x40);
    cdPush(ptr, bytes32(app_count));
    // Get base storage location for provider app list
    uint provider_list_storage = uint(keccak256(PROVIDER_APP_LIST, keccak256(_provider, PROVIDERS)));
    // Loop over app coutn and store list index locations in calldata buffer
    for (uint i = 1; i <= app_count; i++)
      cdPush(ptr, bytes32((32 * i) + provider_list_storage));

    // Read from storage and store return in buffer
    registered_apps = readMultiFrom(ptr, _storage);
  }

  /*
  Returns a list of all applications registered by the provider

  @param _storage: The address where the registry's storage is located
  @param _exec_id: The execution id associated with the registry
  @param _provider: The provider
  @return provider: The hash id associated with this provider
  @return registered_apps: A list of the names of all applications registered by this provider
  */
  function getProviderInfoFromAddress(address _storage, bytes32 _exec_id, address _provider) public view
  returns (bytes32 provider, bytes32[] memory registered_apps) {
    // Ensure valid input
    require(_storage != address(0) && _exec_id != bytes32(0) && bytes32(_provider) != bytes32(0));
    // Get provider id from provider address
    provider = keccak256(bytes32(_provider));

    // Create 'read' calldata buffer in memory
    uint ptr = cdBuff(RD_SING);
    // Push exec id to calldata buffer
    cdPush(ptr, _exec_id);
    // Place provider app list storage location in calldata buffer
    cdPush(ptr, keccak256(PROVIDER_APP_LIST, keccak256(provider, PROVIDERS)));
    // Read single value from storage, and place return in buffer
    uint app_count = uint(readSingleFrom(ptr, _storage));

    // If the provider has not registered any applications, return an empty array
    if (app_count == 0)
      return (provider, registered_apps);

    // Overwrite previous read buffer with readMulti buffer
    cdOverwrite(ptr, RD_MULTI);
    // Place exec id, data read offset, and read size in calldata buffer
    cdPush(ptr, _exec_id);
    cdPush(ptr, 0x40);
    cdPush(ptr, bytes32(app_count));
    // Get base storage location for provider app list
    uint provider_list_storage = uint(keccak256(PROVIDER_APP_LIST, keccak256(provider, PROVIDERS)));
    // Loop over app coutn and store list index locations in calldata buffer
    for (uint i = 1; i <= app_count; i++)
      cdPush(ptr, bytes32((32 * i) + provider_list_storage));

    // Read from storage and store return in buffer
    registered_apps = readMultiFrom(ptr, _storage);
  }

  /// APPLICATION INFORMATION ///

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
  returns (uint num_versions, address app_default_storage, bytes memory app_description) {
    // Ensure valid input
    require(_storage != address(0) && _exec_id != bytes32(0));
    require(_provider != bytes32(0) && _app != bytes32(0));

    // Create 'readMulti' calldata buffer in memory
    uint ptr = cdBuff(RD_MULTI);
    // Place exec id, data read offset, and read size to calldata
    cdPush(ptr, _exec_id);
    cdPush(ptr, 0x40);
    cdPush(ptr, 3);
    // Push app version list count, app default storage, and app description size storage locations to calldata buffer
    // Get app base storage -
    bytes32 temp = keccak256(_provider, PROVIDERS);
    temp = keccak256(keccak256(_app), keccak256(APPS, temp));
    cdPush(ptr, keccak256(APP_VERSIONS_LIST, temp)); // App version list location
    cdPush(ptr, keccak256(APP_STORAGE_IMPL, temp)); // App default storage address location
    cdPush(ptr, keccak256(APP_DESC, temp)); // App description size location

    // Read from storage and store return in buffer
    bytes32[] memory read_values = readMultiFrom(ptr, _storage);

    // Get returned values
    num_versions = uint(read_values[0]);
    app_default_storage = address(read_values[1]);
    uint desc_size = uint(read_values[2]);

    // Normalize description size to 32-byte chunks for next readMulti
    uint desc_size_norm = desc_size / 32;
    if (desc_size % 32 != 0)
      desc_size_norm++;

    // Overwrite previous buffer to create a new readMulti buffer
    cdOverwrite(ptr, RD_MULTI);
    // Push exec id, data read offset, and normalized read size to buffer
    cdPush(ptr, _exec_id);
    cdPush(ptr, 0x40);
    cdPush(ptr, bytes32(desc_size_norm));
    // Get app description base storage location
    temp = keccak256(APP_DESC, temp);
    // Loop over description size and add storage locations to buffer
    for (uint i = 1; i <= desc_size_norm; i++)
      cdPush(ptr, bytes32((32 * i) + uint(temp)));

    // Read from storage, and store return in buffer
    app_description = readMultiBytesFrom(ptr, desc_size, _storage);
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
  returns (uint app_version_count, bytes32[] memory version_list) {
    // Ensure valid input
    require(_storage != address(0) && _exec_id != bytes32(0));
    require(_provider != bytes32(0) && _app != bytes32(0));

    // Create 'read' calldata buffer in memory
    uint ptr = cdBuff(RD_SING);
    // Push exec id and app version list count location to buffer
    cdPush(ptr, _exec_id);
    // Get app base storage location
    bytes32 temp = keccak256(_provider, PROVIDERS);
    temp = keccak256(APPS, temp);
    temp = keccak256(keccak256(_app), temp);
    cdPush(ptr, keccak256(APP_VERSIONS_LIST, temp));
    // Read from storage and place return in buffer
    app_version_count = uint(readSingleFrom(ptr, _storage));

    // If an application has no registered versions, return an empty array
    if (app_version_count == 0)
      return (app_version_count, version_list);

    // Overwrite previous buffer with readMulti calldata buffer
    cdOverwrite(ptr, RD_MULTI);
    // Push exec id, data read offset, and read size to calldata buffer
    cdPush(ptr, _exec_id);
    cdPush(ptr, 0x40);
    cdPush(ptr, bytes32(app_version_count));
    // Get app version list base storage location
    temp = keccak256(APP_VERSIONS_LIST, temp);
    // Loop over version count and store each list index location in calldata buffer
    for (uint i = 1; i <= app_version_count; i++)
      cdPush(ptr, bytes32((i * 32) + uint(temp)));

    // Read from storage and store return in buffer
    version_list = readMultiFrom(ptr, _storage);
  }

  struct AppInfoHelper {
    bytes32 temp;
    uint list_length;
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
  returns (address app_storage_addr, bytes32 latest_version, address app_init_addr, address[] memory allowed) {
    // Ensure valid input
    require(_storage != address(0) && _exec_id != bytes32(0));
    require(_provider != bytes32(0) && _app != bytes32(0));

    // Create struct in memory to hold values
    AppInfoHelper memory app_helper = AppInfoHelper({
      temp: keccak256(_provider, PROVIDERS),
      list_length: 0
    });

    // Create 'readMulti' calldata buffer in memory
    uint ptr = cdBuff(RD_MULTI);
    // Push exec id, data read offset, and read size to calldata
    cdPush(ptr, _exec_id);
    cdPush(ptr, 0x40);
    cdPush(ptr, 2);
    // Get app base storage location
    app_helper.temp = keccak256(_provider, PROVIDERS);
    app_helper.temp = keccak256(APPS, app_helper.temp);
    app_helper.temp = keccak256(keccak256(_app), app_helper.temp);
    // Push app default storage address location and app version list locations to buffer
    cdPush(ptr, keccak256(APP_STORAGE_IMPL, app_helper.temp));
    cdPush(ptr, keccak256(APP_VERSIONS_LIST, app_helper.temp));
    // Read froms storage and store return in buffer
    bytes32[] memory read_values = readMultiFrom(ptr, _storage);

    // Read returned values -
    app_storage_addr = address(read_values[0]);
    app_helper.list_length = uint(read_values[1]);
    // If list length is zero, no versions have been registered - return
    if (app_helper.list_length == 0)
      return;

    // Get app version list location
    bytes32 app_list_storage_loc = keccak256(APP_VERSIONS_LIST, app_helper.temp);
    // Get version storage seed
    app_helper.temp = keccak256(VERSIONS, app_helper.temp);
    // Loop backwards through app version list, and find the last 'finalized' version
    for (uint i = app_helper.list_length; i > 0; i--) {
      // Overwrite last buffer with a 'read' buffer
      cdOverwrite(ptr, RD_SING);
      // Push exec id and read location (app_versions_list[length - i])
      cdPush(ptr, _exec_id);
      cdPush(ptr, bytes32(uint(app_list_storage_loc) + (32 * i)));
      // Read from storage, and store return in buffer
      latest_version = readSingleFrom(ptr, _storage);

      // Hash returned version name and version storage seed
      bytes32 latest_ver_storage = keccak256(keccak256(latest_version), app_helper.temp);

      // Construct 'readMulti' calldata by overwriting previous 'read' calldata buffer
      cdOverwrite(ptr, RD_MULTI);
      // Push exec id, data read offset, and read size to buffer
      cdPush(ptr, _exec_id);
      cdPush(ptr, 0x40);
      cdPush(ptr, 4);
      // Push version status storage location to buffer
      cdPush(ptr, keccak256(VER_IS_FINALIZED, latest_ver_storage));
      // Push version init address storage location to buffer
      cdPush(ptr, keccak256(VER_INIT_ADDR, latest_ver_storage));
      // Push version address list location to buffer
      cdPush(ptr, keccak256(VER_FUNCTION_ADDRESSES, latest_ver_storage));
      // Push version storage address location to buffer
      cdPush(ptr, keccak256(VER_STORAGE_IMPL, latest_ver_storage));
      // Read from storage, and store return in buffer
      read_values = readMultiFrom(ptr, _storage);

      // Check version 'is finalized' status - if true, this is the latest version
      if (read_values[0] != bytes32(0)) {
        // Get initialization address for this version
        app_init_addr = address(read_values[1]);
        // Get version address list length
        app_helper.list_length = uint(read_values[2]);
        // Get storage address for this version
        app_storage_addr = address(read_values[3]);
        // Exit loop
        break;
      }
    }
    // If app_init_addr is still 0, no version was found - return
    if (app_init_addr == address(0)) {
      latest_version = bytes32(0);
      app_storage_addr = address(0);
      return;
    }

    /// Otherwise - get version allowed addresses

    // If the version has no allowed addresses, return
    if (app_helper.list_length == 0)
      return;

    // Overwrite previous buffers with 'readMulti' buffer
    cdOverwrite(ptr, RD_MULTI);
    // Push exec id, data read offset, and read size to buffer
    cdPush(ptr, _exec_id);
    cdPush(ptr, 0x40);
    cdPush(ptr, bytes32(app_helper.list_length));
    // Get version addresses list base location
    app_helper.temp = keccak256(keccak256(latest_version), app_helper.temp);
    app_helper.temp = keccak256(VER_FUNCTION_ADDRESSES, app_helper.temp);
    // Loop over list length and place each index storage location in buffer
    for (i = 1; i <= app_helper.list_length; i++)
      cdPush(ptr, bytes32((32 * i) + uint(app_helper.temp)));

    // Read from storage, and store return in buffer
    allowed = readMultiAddressFrom(ptr, _storage);
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

  struct StackVarHelper {
    bytes32 temp;
    uint desc_size;
    uint desc_size_norm;
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
  returns (bool is_finalized, uint num_functions, address version_storage, bytes memory version_description) {
    // Ensure valid input
    require(_storage != address(0) && _exec_id != bytes32(0));
    require(_provider != bytes32(0) && _app != bytes32(0) && _version != bytes32(0));

    // Create struct in memory to hold values
    StackVarHelper memory v_helper = StackVarHelper({
      temp: keccak256(_provider, PROVIDERS),
      desc_size: 1,
      desc_size_norm: 1
    });
    // Get version base storage location
    v_helper.temp = keccak256(APPS, v_helper.temp);
    v_helper.temp = keccak256(keccak256(_app), v_helper.temp);
    v_helper.temp = keccak256(VERSIONS, v_helper.temp);
    v_helper.temp = keccak256(keccak256(_version), v_helper.temp);

    // Create 'readMulti' calldata buffer in memory
    uint ptr = cdBuff(RD_MULTI);
    // Push exec id, data read offset, and read size to buffer
    cdPush(ptr, _exec_id);
    cdPush(ptr, 0x40);
    cdPush(ptr, 4);
    // Push version status, function count, storage address, and description array size storage locations to calldata buffer
    cdPush(ptr, keccak256(VER_IS_FINALIZED, v_helper.temp));
    cdPush(ptr, keccak256(VER_FUNCTION_LIST, v_helper.temp));
    cdPush(ptr, keccak256(VER_STORAGE_IMPL, v_helper.temp));
    cdPush(ptr, keccak256(VER_DESC, v_helper.temp));
    // Read from storage and store return in buffer
    bytes32[] memory read_values = readMultiFrom(ptr, _storage);

    // Read returned values -
    is_finalized = (read_values[0] != bytes32(0));
    num_functions = uint(read_values[1]);
    version_storage = address(read_values[2]);
    v_helper.desc_size = uint(read_values[3]);

    // Normalize description size to 32-byte chunks for next readMulti
    v_helper.desc_size_norm = v_helper.desc_size / 32;
    if (v_helper.desc_size % 32 != 0)
      v_helper.desc_size_norm++;

    // Create new readMulti calldata buffer, overwriting the previous buffer
    cdOverwrite(ptr, RD_MULTI);
    // Push exec id, data read offset, and read size to buffer
    cdPush(ptr, _exec_id);
    cdPush(ptr, 0x40);
    cdPush(ptr, bytes32(v_helper.desc_size_norm));
    // Get version description base storage location
    v_helper.temp = keccak256(VER_DESC, v_helper.temp);
    // Loop over description size and add storage locations to readMulti buffer
    for (uint i = 1; i <= v_helper.desc_size_norm; i++)
      cdPush(ptr, bytes32((32 * i) + uint(v_helper.temp)));

    // Read from storage, and store return in buffer
    version_description = readMultiBytesFrom(ptr, v_helper.desc_size, _storage);
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
  returns (address init_impl, bytes4 init_signature, bytes memory init_description) {
    // Ensure valid input
    require(_storage != address(0) && _exec_id != bytes32(0));
    require(_provider != bytes32(0) && _app != bytes32(0) && _version != bytes32(0));

    // Create struct in memory to hold values
    StackVarHelper memory v_helper = StackVarHelper({
      temp: keccak256(_provider, PROVIDERS),
      desc_size: 1,
      desc_size_norm: 1
    });
    // Get version base storage location
    v_helper.temp = keccak256(_provider, PROVIDERS);
    v_helper.temp = keccak256(APPS, v_helper.temp);
    v_helper.temp = keccak256(keccak256(_app), v_helper.temp);
    v_helper.temp = keccak256(VERSIONS, v_helper.temp);
    v_helper.temp = keccak256(keccak256(_version), v_helper.temp);
    // Create 'readMulti' calldata buffer in memory
    uint ptr = cdBuff(RD_MULTI);
    // Push exec id, data read offset, and read size to buffer
    cdPush(ptr, _exec_id);
    cdPush(ptr, 0x40);
    cdPush(ptr, 3);
    // Push init implementing address, init function signature, and init description size storage locations to calldata buffer
    cdPush(ptr, keccak256(VER_INIT_ADDR, v_helper.temp));
    cdPush(ptr, keccak256(VER_INIT_SIG, v_helper.temp));
    cdPush(ptr, keccak256(VER_INIT_DESC, v_helper.temp));
    // Read from storage, and store return in buffer
    bytes32[] memory read_values = readMultiFrom(ptr, _storage);

    // Get returned values -
    init_impl = address(read_values[0]);
    init_signature = bytes4(read_values[1]);
    v_helper.desc_size = uint(read_values[2]);

    // Normalize description size to 32-byte chunks for next readMulti
    v_helper.desc_size_norm = v_helper.desc_size / 32;
    if (v_helper.desc_size % 32 != 0)
      v_helper.desc_size_norm++;

    if (v_helper.desc_size_norm == 0)
      return;

    // Create new readMulti calldata buffer, overwriting the previous buffer
    cdOverwrite(ptr, RD_MULTI);
    // Push exec id, data read offset, and read size to buffer
    cdPush(ptr, _exec_id);
    cdPush(ptr, 0x40);
    cdPush(ptr, bytes32(v_helper.desc_size_norm));
    // Get version init description base storage location
    v_helper.temp = keccak256(VER_INIT_DESC, v_helper.temp);
    // Loop over description size and add storage locations to readMulti buffer
    for (uint i = 1; i <= v_helper.desc_size_norm; i++)
      cdPush(ptr, bytes32((32 * i) + uint(v_helper.temp)));

    // Read from storage, and store return in buffer
    init_description = readMultiBytesFrom(ptr, v_helper.desc_size, _storage);
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
  returns (bytes4[] memory function_signatures, address[] memory function_locations) {
    // Ensure valid input
    require(_storage != address(0) && _exec_id != bytes32(0));
    require(_provider != bytes32(0) && _app != bytes32(0) && _version != bytes32(0));

    // Get version base storage location
    bytes32 temp = keccak256(_provider, PROVIDERS);
    temp = keccak256(APPS, temp);
    temp = keccak256(keccak256(_app), temp);
    temp = keccak256(VERSIONS, temp);
    temp = keccak256(keccak256(_version), temp);

    // Create 'readMulti' calldata buffer in memory
    uint ptr = cdBuff(RD_MULTI);
    // Push exec id, data read offset, and read size to calldata buffer
    cdPush(ptr, _exec_id);
    cdPush(ptr, 0x40);
    cdPush(ptr, 2);
    // Push version signature and address list storage locations to calldata
    cdPush(ptr, keccak256(VER_FUNCTION_LIST, temp));
    cdPush(ptr, keccak256(VER_FUNCTION_ADDRESSES, temp));
    // Read from storage, and store return in buffer
    bytes32[] memory read_values = readMultiFrom(ptr, _storage);

    // Get return lengths - should always be equal
    uint list_length = uint(read_values[0]);
    assert(list_length == uint(read_values[1]));

    // If the version has not implemented functions, return
    if (list_length == 0)
      return;

    // Create new 'readMulti' calldata buffer, overwriting the previous buffer
    cdOverwrite(ptr, RD_MULTI);
    // Push exec id, data read offset, and read size to calldata buffer
    cdPush(ptr, _exec_id);
    cdPush(ptr, 0x40);
    cdPush(ptr, bytes32(list_length));
    // Get function
    // Loop over read size and place function signature list index storage locations in calldata buffer
    for (uint i = 1; i <= list_length; i++) {
      cdPush(ptr, bytes32((i * 32) + uint(keccak256(VER_FUNCTION_LIST, temp))));
    }
    // Read from storage, and store return in buffer
    function_signatures = readMultiBytes4From(ptr, _storage);

    // Create new 'readMulti' calldata buffer in free memory
    ptr = cdBuff(RD_MULTI);
    // Push exec id, data read offset, and read size to calldata buffer
    cdPush(ptr, _exec_id);
    cdPush(ptr, 0x40);
    cdPush(ptr, bytes32(list_length));
    // Get function
    // Loop over read size and place function signature list index storage locations in calldata buffer
    for (i = 1; i <= list_length; i++)
      cdPush(ptr, bytes32((i * 32) + uint(keccak256(VER_FUNCTION_ADDRESSES, temp))));

    // Read from storage, and store return in buffer
    function_locations = readMultiAddressFrom(ptr, _storage);
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
  @param _storage: The address to read from
  @return read_values: The values read from storage
  */
  function readMultiFrom(uint _ptr, address _storage) internal view returns (bytes32[] memory read_values) {
    bool success;
    assembly {
      // Minimum length for 'readMulti' - 1 location is 0x84
      if lt(mload(_ptr), 0x84) { revert (0, 0) }
      // Read from storage
      success := staticcall(gas, _storage, add(0x20, _ptr), mload(_ptr), 0, 0)
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
  Executes a 'readMulti' function call, given a pointer to a calldata buffer

  @param _ptr: A pointer to the location in memory where the calldata for the call is stored
  @param _storage: The address to read from
  @return read_values: The values read from storage
  */
  function readMultiBytes4From(uint _ptr, address _storage) internal view returns (bytes4[] memory read_values) {
    bool success;
    assembly {
      // Minimum length for 'readMulti' - 1 location is 0x84
      if lt(mload(_ptr), 0x84) { revert (0, 0) }
      // Read from storage
      success := staticcall(gas, _storage, add(0x20, _ptr), mload(_ptr), 0, 0)
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
  Executes a 'readMulti' function call, given a pointer to a calldata buffer

  @param _ptr: A pointer to the location in memory where the calldata for the call is stored
  @param _storage: The address to read from
  @return read_values: The values read from storage
  */
  function readMultiAddressFrom(uint _ptr, address _storage) internal view returns (address[] memory read_values) {
    bool success;
    assembly {
      // Minimum length for 'readMulti' - 1 location is 0x84
      if lt(mload(_ptr), 0x84) { revert (0, 0) }
      // Read from storage
      success := staticcall(gas, _storage, add(0x20, _ptr), mload(_ptr), 0, 0)
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
  Executes a 'readMulti' function call, given a pointer to a calldata buffer

  @param _ptr: A pointer to the location in memory where the calldata for the call is stored
  @param _arr_len: The actual length of the bytes array being returned
  @param _storage: The address to read from
  @return read_values: The bytes array read from storage
  */
  function readMultiBytesFrom(uint _ptr, uint _arr_len, address _storage) internal view returns (bytes memory read_values) {
    bool success;
    assembly {
      // Minimum length for 'readMulti' - 1 location is 0x84
      if lt(mload(_ptr), 0x84) { revert (0, 0) }
      // Read from storage
      success := staticcall(gas, _storage, add(0x20, _ptr), mload(_ptr), 0, 0)
      // If call succeed, get return information
      if gt(success, 0) {
        // Ensure data will not be copied beyond the pointer
        if gt(sub(returndatasize, 0x20), mload(_ptr)) { revert (0, 0) }
        // Copy returned data to pointer, overwriting it in the process
        // Copies returndatasize, but ignores the initial read offset so that the bytes32[] returned in the read is sitting directly at the pointer
        returndatacopy(_ptr, 0x20, sub(returndatasize, 0x20))
        // Set return bytes32[] to pointer, which should now have the stored length of the returned array
        read_values := _ptr
        // Copy input length to read_values - corrects length
        mstore(read_values, _arr_len)
      }
    }
    if (!success)
      triggerException(bytes32("StorageReadFailed"));
  }

  /*
  Executes a 'read' function call, given a pointer to a calldata buffer

  @param _ptr: A pointer to the location in memory where the calldata for the call is stored
  @param _storage: The address to read from
  @return read_value: The value read from storage
  */
  function readSingleFrom(uint _ptr, address _storage) internal view returns (bytes32 read_value) {
    bool success;
    assembly {
      // Length for 'read' buffer must be 0x44
      if iszero(eq(mload(_ptr), 0x44)) { revert (0, 0) }
      // Read from storage, and store return to pointer
      success := staticcall(gas, _storage, add(0x20, _ptr), mload(_ptr), _ptr, 0x20)
      // If call succeeded, store return at pointer
      if gt(success, 0) { read_value := mload(_ptr) }
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
}
