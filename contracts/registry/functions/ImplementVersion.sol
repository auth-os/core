pragma solidity ^0.4.20;

library ImplementVersion {

  /// PROVIDER STORAGE ///

  // Provider namespace - all app and version storage is seeded to a provider
  // [PROVIDERS][$provider_id]
  bytes32 public constant PROVIDERS = keccak256("providers");

  /// APPLICATION STORAGE ///

  // Application namespace - all app info and version storage is mapped here
  // [PROVIDERS][$provider_id][APPS][$app_name]
  bytes32 public constant APPS = keccak256("apps");

  // Application version list location - (bytes32 array)
  // [PROVIDERS][$provider_id][APPS][$app_name][APP_VERSIONS_LIST] = ["v_name1", "v_name2", ...]
  bytes32 public constant APP_VERSIONS_LIST = keccak256("app_versions_list");

  /// VERSION STORAGE ///

  // Version namespace - all version and function info is mapped here
  // [PROVIDERS][$provider_id][APPS][$app_hash][VERSIONS]
  bytes32 public constant VERSIONS = keccak256("versions");

  // Version description location - (bytes array)
  // [PROVIDERS][$provider_id][APPS][$app_hash][VERSIONS][$ver_hash][VER_DESC] = ["description"]
  bytes32 public constant VER_DESC = keccak256("ver_desc");

  // Version "is finalized" location - whether a version is ready for use (all intended functions implemented)
  // [PROVIDERS][$provider_id][APPS][$app_hash][VERSIONS][$ver_name][VER_IS_FINALIZED] = bool $is_finalized
  bytes32 public constant VER_IS_FINALIZED = keccak256("ver_is_finalized");

  // Version function list location - (bytes32 array)
  // [PROVIDERS][$provider_id][APPS][$app_hash][VERSIONS][$ver_name][VER_FUNCTION_LIST] = ["f_sig1", "f_sig2", ...]
  bytes32 public constant VER_FUNCTION_LIST = keccak256("ver_functions_list");

  // Version "app index" location - keeps track of a version's location in an app's version list
  // [PROVIDERS][$provider_id][APPS][$app_hash][VERSIONS][$ver_name][APP_VER_INDEX] = uint $app_ver_list_index
  bytes32 public constant APP_VER_INDEX = keccak256("app_ver_index");

  /// IMPLEMENTATION STORAGE ///

  // Function namespace - all version implementation info is mapped here
  // [PROVIDERS][$provider_id][APPS][$app_hash][VERSIONS][$ver_name][FUNCTIONS]
  bytes32 public constant FUNCTIONS = keccak256("functions");

  // Function description location - (bytes32)
  // [PROVIDERS][$provider_id][APPS][$app_hash][VERSIONS][$ver_name][FUNCTIONS][$f_hash][FUNC_DESC] = "description"
  bytes32 public constant FUNC_DESC = keccak256("func_desc");

  // Function implementing address location
  // [PROVIDERS][$provider_id][APPS][$app_hash][VERSIONS][$ver_name][FUNCTIONS][$f_hash][FUNC_IMPL_ADDR] = $f_impl_addr
  bytes32 public constant FUNC_IMPL_ADDR = keccak256("func_impl_addr");

  // Function "version index" location - keeps track of a function's location in a version's function list
  // [PROVIDERS][$provider_id][APPS][$app_hash][VERSIONS][$ver_name][FUNCTIONS][$f_hash][VER_FUNC_INDEX] = $f_ver_list_index
  bytes32 public constant VER_FUNC_INDEX = keccak256("ver_func_index");

  /// FUNCTION SELECTORS ///

  // Function selector for storage interface "read"
  // read(address _storage, bytes32 _app_id, bytes32 _location) view returns (bytes32 data_read);
  bytes4 public constant RD_SEL = bytes4(keccak256("read(address,bytes32,bytes32)"));

  // Function selector for storage interface "readMulti"
  // readMulti(bytes32[] _locations) view returns (bytes32[] data_read)
  bytes4 public constant RD_MULTI_SEL = bytes4(keccak256("readMulti(address,bytes32,bytes32[])"));

  // Function selector for storage interface "getTrueLocation"
  // getTrueLocation(address _storage, bytes32 _app_id, bytes32 _location) view returns (bytes32 true_location);
  bytes4 public constant GET_TRUE_LOC_SEL = bytes4(keccak256("getTrueLocation(address,bytes32,bytes32)"));

  /// OTHER CONSTANTS ///

  // Constant value returned by a function which is returning data and does not need storage
  bytes32 public constant CONST_RETURN = bytes32(keccak256("const_return"));

  // Constant value returned by a function which requests storage
  bytes32 public constant REQUEST_STORAGE = bytes32(keccak256("request_storage"));

  /// FUNCTIONS ///

  struct FuncReg {
    bytes4 rd_multi_sel;
    bytes32 app_storage;
    bytes32 ver_storage;
    bytes32 ver_is_finalized_storage;
    bytes32 ver_func_list_location;
    bytes32 func_storage;
    bytes32 func_desc_storage;
    bytes32 func_impl_storage;
    bytes32 func_index_storage;
  }

  /*
  Adds a set of implemenations to a registered version, provided the version has not been finalized

  @param _storage_information: A 96-byte array containing, in order, storage interface address, abstract storage address, and exec id
  @param _provider: The address registering the app
  @param _app_name: The name of the application under which the version is registered
  @param _ver_name: The name of the version under which to register the functions
  @param _func_sels: An array of plaintext function selectors to register (ex: 'transfer(address,uint256)')
  @param _func_descs: An array of function descriptions, corresponding to indices in _func_sels
  @param _func_impls: An array of addresses which implement the corresponding function selectors
  @return request_storage: Signals that the script executor should store the returned data
  @return store_data: 'writeMulti' storage request, returned to script exec, which requests storage from the storage interface
  */
  function addVersionFunctions(bytes _storage_information, address _provider, bytes32 _app_name, bytes32 _ver_name, bytes32[] _func_sels, bytes32[] _func_descs, address[] _func_impls) public view
  returns (bytes32 request_storage, bytes32[] store_data) {
    // Ensure input is correctly formatted
    require(_storage_information.length == 96);
    // Ensure valid app name, version name, and provider address
    require(_app_name != bytes32(0) && _ver_name != bytes32(0) && _provider != address(0));
    // Ensure implementation input is correctly formatted
    require(_func_sels.length != 0 && _func_sels.length == _func_descs.length && _func_descs.length == _func_impls.length);

    // Set up struct to hold multiple variables in memory
    FuncReg memory func_reg = FuncReg({
      // Place 'readMulti' function selector in memory
      rd_multi_sel: RD_MULTI_SEL,
      // Place app storage location in memory
      app_storage: keccak256(keccak256(_provider), PROVIDERS),
      // Place version storage location in memory
      ver_storage: 0,
      // Place version 'is finalized' storage location in memory
      ver_is_finalized_storage: 0,
      // Place version function list storage location in memory
      ver_func_list_location: 0,
      // Place function storage seed in memory
      func_storage: 0,
      // Place function description storage seed in memory
      func_desc_storage: FUNC_DESC,
      // Place function implementing address storage seed in memory
      func_impl_storage: FUNC_IMPL_ADDR,
      // Place function index storage seed in memory
      func_index_storage: VER_FUNC_INDEX
    });

    // Get app storage location - mapped to the provider's location
    func_reg.app_storage = keccak256(APPS, func_reg.app_storage);
    func_reg.app_storage = keccak256(keccak256(_app_name), func_reg.app_storage);
    // Get version storage location
    func_reg.ver_storage = keccak256(VERSIONS, func_reg.app_storage);
    func_reg.ver_storage = keccak256(keccak256(_ver_name), func_reg.ver_storage);
    // Get version 'is finalized' and function list storage locations
    func_reg.ver_func_list_location = keccak256(VER_FUNCTION_LIST, func_reg.ver_storage);
    func_reg.ver_is_finalized_storage = keccak256(VER_IS_FINALIZED, func_reg.ver_storage);
    // Get function storage seed
    func_reg.func_storage = keccak256(FUNCTIONS, func_reg.ver_storage);

    assembly {
      // Get a pointer to free memory for hashing
      let hash_ptr := mload(0x40)
      // Get a pointer to free memory to store calldata
      let sel_ptr := add(0x40, hash_ptr)

      // Check that the application and version exist, and that the version is not finalized -
      // Also, get version function list length

      // Store 'readMulti' function selector at pointer
      mstore(sel_ptr, mload(func_reg))
      // Place abstract storage address in calldata
      mstore(add(0x04, sel_ptr), mload(add(0x40, _storage_information)))
      // Place exec id in calldata
      mstore(add(0x24, sel_ptr), mload(add(0x60, _storage_information)))
      // Place data read offset in calldata
      mstore(add(0x44, sel_ptr), 0x60)
      // Get read length (uint), and place in calldata
      mstore(add(0x64, sel_ptr), 4)
      // Place app storage location in calldata
      mstore(add(0x84, sel_ptr), mload(add(0x20, func_reg)))
      // Place version storage location in calldata
      mstore(add(0xa4, sel_ptr), mload(add(0x40, func_reg)))
      // Place version 'is finalized' location in calldata
      mstore(add(0xc4, sel_ptr), mload(add(0x60, func_reg)))
      // Place version function list location in calldata
      mstore(add(0xe4, sel_ptr), mload(add(0x80, func_reg)))

      // Staticcall storage interface
      let ret := staticcall(gas, mload(add(0x20, _storage_information)), sel_ptr, 0x0104, 0, 0)
      // Check return value - if zero, call failed: revert
      if iszero(ret) { revert (0, 0) }
      // Copy returned values to sel_ptr ([app_storage][ver_storage][ver_is_finalized][ver_func_list][func_storages])
      returndatacopy(sel_ptr, 0x40, sub(returndatasize, 0x40))
      // Check that the application name in storage is the same as the passed-in name
      if iszero(eq(mload(sel_ptr), _app_name)) { revert (0, 0) }
      // Check that the version name in storage is the same as the passed-in name
      if iszero(eq(mload(add(0x20, sel_ptr)), _ver_name)) { revert (0, 0) }
      // Check that the version is not finalized
      if gt(mload(add(0x40, sel_ptr)), 0) { revert (0, 0) }
      // Get version function list length, and store at sel_ptr
      let ver_func_list_len := mload(add(0x60, sel_ptr))

      // Application and version are registered, and version is not finalized: store function information, and increase version function list length -

      // Get pointer in free memory for return storage request
      store_data := add(0x20, msize)

      // Get length of 'writeMulti' array, and store at return request pointer
      // Size increases by 10 for each function selector, as well as 2 for version function list length
      mstore(store_data, add(2, mul(10, mload(_func_sels))))

      // Place version function list length location in storage request
      mstore(add(0x20, store_data), mload(add(0x80, func_reg)))
      // Place updated function list length in storage request
      mstore(add(0x40, store_data), add(mload(_func_sels), ver_func_list_len))
      // Loop over function selectors, and store in storage request
      for { let offset := 0x00 } lt(offset, mul(0x20, mload(_func_sels))) { offset := add(0x20, offset) } {
        // Push function selector to end of version function list -
        /// New index - current length, plus number of loops so far (stored in a temporary location)
        mstore(hash_ptr, add(ver_func_list_len, div(add(0x20, offset), 0x20)))
        /// Index translated to storage location - multiplied by 32 bytes, and added to version function list storage location
        mstore(add(add(0x60, mul(10, offset)), store_data), add(mload(add(0x80, func_reg)), mul(0x20, mload(hash_ptr))))
        /// Place function selector in return request
        mstore(add(add(0x80, mul(10, offset)), store_data), mload(add(add(0x20, offset), _func_sels)))
        // Get function storage location, and place in hash pointer -
        /// Store function selector hash in first part of hash pointer
        mstore(hash_ptr, keccak256(add(add(0x20, offset), _func_sels), 0x20))
        /// Place function storage seed in second slot of hash pointer
        mstore(add(0x20, hash_ptr), mload(add(0xa0, func_reg)))
        /// Hash selector hash and storage seed to get function storage location, and store in second slot of hash pointer, for further hashing
        mstore(add(0x20, hash_ptr), keccak256(hash_ptr, 0x40))
        // Store function selector in function storage location
        /// Place function storage location in return request
        mstore(add(add(0xa0, mul(10, offset)), store_data), mload(add(0x20, hash_ptr)))
        /// Place function selector in return request
        mstore(add(add(0xc0, mul(10, offset)), store_data), mload(add(add(0x20, offset), _func_sels)))
        // Store function index
        /// Place function index storage seed in first part of hash pointer
        mstore(hash_ptr, mload(add(0x0100, func_reg)))
        /// Hash function index storage seed and function storage location to get function index storage location, and place in return request
        mstore(add(add(0xe0, mul(10, offset)), store_data), keccak256(hash_ptr, 0x40))
        /// Place function index in return request
        mstore(add(add(0x0100, mul(10, offset)), store_data), sub(add(ver_func_list_len, div(add(0x20, offset), 0x20)), 1))
        // Store function description
        /// Place function description storage seed in first part of hash pointer
        mstore(hash_ptr, mload(add(0xc0, func_reg)))
        /// Hash function description storage seed and function storage location to get function description storage location, and place in return request
        mstore(add(add(0x0120, mul(10, offset)), store_data), keccak256(hash_ptr, 0x40))
        /// Place function description in return request
        mstore(add(add(0x0140, mul(10, offset)), store_data), mload(add(add(0x20, offset), _func_descs)))
        // Store function implementing address
        /// Place function implementing address storage seed in first part of hash pointer
        mstore(hash_ptr, mload(add(0xe0, func_reg)))
        /// Hash function implementing address storage seed and function storage location to get function impl address storage location, and place in return request
        mstore(add(add(0x0160, mul(10, offset)), store_data), keccak256(hash_ptr, 0x40))
        /// Place function implementing address in return request
        mstore(add(add(0x0180, mul(10, offset)), store_data), mload(add(add(0x20, offset), _func_impls)))
      }
    }
    // Set storage marker for return data
    request_storage = REQUEST_STORAGE;
  }

  struct FuncInfo {
    bytes4 rd_multi_sel;
    bytes4 true_location_sel;
    bytes32 app_storage;
    bytes32 ver_storage;
    bytes32 func_storage;
    bytes32 func_desc_storage;
    bytes32 func_impl_storage;
  }

  /*
  Adds a set of implemenations to a registered version, provided the version has not been finalized

  @param _storage_information: A 96-byte array containing, in order, storage interface address, abstract storage address, and exec id
  @param _provider: The address registering the app
  @param _app_name: The name of the application under which the version is registered
  @param _ver_name: The name of the version under which to register the functions
  @param _func_sels: An array of plaintext function selectors to register (ex: 'transfer(address,uint256)')
  @param _func_descs: An array of function descriptions, corresponding to indices in _func_sels
  @param _func_impls: An array of addresses which implement the corresponding function selectors
  @return request_storage: Signals that the script executor should store the returned data
  @return store_data: 'writeMulti' storage request, returned to script exec, which requests storage from the storage interface
  */
  function getFunctionBasicInfo(bytes _storage_information, address _provider, bytes32 _app_name, bytes32 _ver_name, bytes32 _func_sel) public view
  returns (bytes32 const_return, bytes32 true_location_func, bytes32 func_description, address impl_address) {
    // Set up struct to hold multiple variables in memory
    FuncInfo memory func_info = FuncInfo({
      // Place 'readMulti' function selector in memory
      rd_multi_sel: RD_MULTI_SEL,
      // Place 'getTrueLocation' function selector in memory
      true_location_sel: GET_TRUE_LOC_SEL,
      // Place app storage location in memory
      app_storage: keccak256(keccak256(_provider), PROVIDERS),
      // Place version storage location in memory
      ver_storage: 0,
      // Place function storage location in memory
      func_storage: 0,
      // Place function description storage location in memory
      func_desc_storage: 0,
      // Place function implementing address storage location in memory
      func_impl_storage: 0
    });

    // Get app storage location - mapped to the provider's location
    func_info.app_storage = keccak256(APPS, func_info.app_storage);
    func_info.app_storage = keccak256(keccak256(_app_name), func_info.app_storage);
    // Get version storage location
    func_info.ver_storage = keccak256(VERSIONS, func_info.app_storage);
    func_info.ver_storage = keccak256(keccak256(_ver_name), func_info.ver_storage);
    // Get function storage location
    func_info.func_storage = keccak256(FUNCTIONS, func_info.ver_storage);
    func_info.func_storage = keccak256(keccak256(_func_sel), func_info.func_storage);
    // Get function description and implementation storage location
    func_info.func_desc_storage = keccak256(FUNC_DESC, func_info.func_storage);
    func_info.func_impl_storage = keccak256(FUNC_IMPL_ADDR, func_info.func_storage);

    assembly {
      // Get function true storage location -

      // Get free-memory pointer to store calldata in
      let sel_ptr := mload(0x40)
      // Store 'getTrueLocation' function selector at pointer
      mstore(sel_ptr, mload(add(0x20, func_info)))
      // Store abstract storage address in calldata
      mstore(add(0x04, sel_ptr), mload(add(0x40, _storage_information)))
      // Store exec id in calldata
      mstore(add(0x24, sel_ptr), mload(add(0x60, _storage_information)))
      // Store function storage location in calldata
      mstore(add(0x44, sel_ptr), mload(add(0x80, func_info)))
      // Staticcall storage interface, and store return at pointer
      let ret := staticcall(gas, mload(add(0x20, _storage_information)), sel_ptr, 0x64, sel_ptr, 0x20)
      // Check return value - if zero, read failed: revert
      if iszero(ret) { revert (0, 0) }
      // Assign return value for true_location_func
      true_location_func := mload(sel_ptr)

      // Get function description and implementing address -

      // Construct 'readMulti' calldata
      mstore(sel_ptr, mload(func_info))
      // Store abstract storage address in calldata
      mstore(add(0x04, sel_ptr), mload(add(0x40, _storage_information)))
      // Store exec id in calldata
      mstore(add(0x24, sel_ptr), mload(add(0x60, _storage_information)))
      // Store data read offset in calldata
      mstore(add(0x44, sel_ptr), 0x60)
      // Store input length in calldata
      mstore(add(0x64, sel_ptr), 3)
      // Store function storage location in calldata
      mstore(add(0x84, sel_ptr), mload(add(0x80, func_info)))
      // Store function description location in calldata
      mstore(add(0xa4, sel_ptr), mload(add(0xa0, func_info)))
      // Store function implementation location in calldata
      mstore(add(0xc4, sel_ptr), mload(add(0xc0, func_info)))
      // Staticcall storage interface
      ret := staticcall(gas, mload(add(0x20, _storage_information)), sel_ptr, 0xe4, 0, 0)
      // Check return value - if zero, read failed: revert
      if iszero(ret) { revert (0, 0) }
      // Copy returned data into sel_ptr
      returndatacopy(sel_ptr, 0x40, sub(returndatasize, 0x40))
      // Check that the returned function selector is equal to passed-in selector
      if iszero(eq(mload(sel_ptr), _func_sel)) { revert (0, 0) }
      // Get description from returned data
      func_description := mload(add(0x20, sel_ptr))
      // Get implementing address from returned data
      impl_address := mload(add(0x40, sel_ptr))
    }
    // Set constant marker for return data
    const_return = CONST_RETURN;
  }

}
