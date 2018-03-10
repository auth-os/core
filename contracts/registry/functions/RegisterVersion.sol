pragma solidity ^0.4.20;

library RegisterVersion {

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

  struct VerReg {
    bytes4 rd_multi_sel;
    bytes32 app_storage;
    bytes32 app_ver_list_storage;
    bytes32 ver_storage;
    bytes32 ver_desc_storage;
    bytes32 ver_index_storage;
  }

  /*
  Registers a version of an application under the sender's provider id

  @param _storage_interface: The contract to send read requests to, which acts as an interface to application storage
  @param _abs_storage: The storage address for this application
  @param _exec_id: The id of the registry application being used
  @param _provider: The address registering the app
  @param _app_name: The name of the application under which to register this version
  @param _ver_name: The name of the version to register
  @param _ver_desc: The description of the version
  @return request_storage: Signals that the script executor should store the returned data
  @return store_data: 'writeMulti' storage request, returned to script exec, which requests storage from the storage interface
  */
  function registerVersion(address _storage_interface, address _abs_storage, bytes32 _exec_id, address _provider, bytes32 _app_name, bytes32 _ver_name, bytes _ver_desc) public view
  returns (bytes32 request_storage, bytes32[] store_data) {
    // Ensure valid app and version names, and valid version description length
    require(_app_name != bytes32(0));
    require(_ver_name != bytes32(0));
    require(_ver_desc.length != 0);

    // Set up struct to hold multiple variables in memory
    VerReg memory ver_reg = VerReg({
      // Place 'readMulti' function selector in memory
      rd_multi_sel: RD_MULTI_SEL,
      // Place app storage location in memory
      app_storage: keccak256(keccak256(_provider), PROVIDERS),
      // Place app version list storage location in memory
      app_ver_list_storage: 0,
      // Place version storage location in memory
      ver_storage: 0,
      // Place version description storage location in memory
      ver_desc_storage: 0,
      // Place version index storage location in memory
      ver_index_storage: 0
    });

    // Get app and app version list storage locations - mapped to the provider's location
    ver_reg.app_storage = keccak256(APPS, ver_reg.app_storage);
    ver_reg.app_storage = keccak256(keccak256(_app_name), ver_reg.app_storage);
    ver_reg.app_ver_list_storage = keccak256(APP_VERSIONS_LIST, ver_reg.app_storage);
    // Get version and version description storage locations
    ver_reg.ver_storage = keccak256(VERSIONS, ver_reg.app_storage);
    ver_reg.ver_storage = keccak256(keccak256(_ver_name), ver_reg.ver_storage);
    ver_reg.ver_desc_storage = keccak256(VER_DESC, ver_reg.ver_storage);
    // Get version index storage location
    ver_reg.ver_index_storage = keccak256(APP_VER_INDEX, ver_reg.ver_storage);

    assembly {
      // Ensure application is registered, and version name is unique. Also, get app version list length
      let sel_ptr := mload(0x40)
      let cd_ptr := add(0x04, sel_ptr)
      // Store 'readMulti' function selector at pointer
      mstore(sel_ptr, mload(ver_reg))
      // Place abstract storage address in calldata
      mstore(cd_ptr, _abs_storage)
      // Place exec id in calldata
      mstore(add(0x20, cd_ptr), _exec_id)
      // Place data read offset in calldata
      mstore(add(0x40, cd_ptr), 0x60)
      // Place input length (uint) in calldata
      mstore(add(0x60, cd_ptr), 3)
      // Place app storage location in calldata
      mstore(add(0x80, cd_ptr), mload(add(0x20, ver_reg)))
      // Place app version list storage location in calldata
      mstore(add(0xa0, cd_ptr), mload(add(0x40, ver_reg)))
      // Place version storage location in calldata
      mstore(add(0xc0, cd_ptr), mload(add(0x60, ver_reg)))
      // Staticcall storage interface
      let ret := staticcall(gas, _storage_interface, sel_ptr, 0xe4, 0, 0)
      // Check call return - if zero, read failed: revert
      if iszero(ret) { revert (0, 0) }
      // Copy returned values to sel_ptr ([app_storage][app_ver_list_len][ver_storage])
      returndatacopy(sel_ptr, 0x40, sub(returndatasize, 0x40))
      // Check that the application name in storage is the same as the passed-in name
      if iszero(eq(mload(sel_ptr), _app_name)) { revert (0, 0) }
      // Check that version name is unique
      if gt(mload(add(0x40, sel_ptr)), 0) { revert (0, 0) }
      // Get app version list length
      let app_ver_list_len := mload(add(0x20, sel_ptr))

      // Get length of 'writeMulti' input array -
      // Size is 10 slots (version and app info), plus two for each nonzero 32-byte slot in _ver_desc
      let write_size := add(10, mul(2, div(mload(_ver_desc), 0x20)))
      if gt(mod(mload(_ver_desc), 0x20), 0) {
        write_size := add(2, write_size)
      }

      // Get pointer in free memory for return storage request
      store_data := add(0x20, msize)
      // Store write size at pointer
      mstore(store_data, write_size)

      // Place app version list length location in storage request
      mstore(add(0x20, store_data), mload(add(0x40, ver_reg)))
      // Place incremented app version list length in storage request
      mstore(add(0x40, store_data), add(1, app_ver_list_len))
      // Get location of end of app version list, and place in storage request
      mstore(add(0x60, store_data), add(add(0x20, mul(0x20, app_ver_list_len)), mload(add(0x40, ver_reg))))
      // Place version name in storage request (pushing version name to end of app version list)
      mstore(add(0x80, store_data), _ver_name)
      // Place version index location in storage request
      mstore(add(0xa0, store_data), mload(add(0xa0, ver_reg)))
      // Place version index (old app version list length) in storage request
      mstore(add(0xc0, store_data), app_ver_list_len)
      // Place version storage location in storage request
      mstore(add(0xe0, store_data), mload(add(0x60, ver_reg)))
      // Place version name in storage request
      mstore(add(0x0100, store_data), _ver_name)

      // Loop over version description and place storage location and description data in storage request
      for { let offset := 0x00 } lt(offset, add(0x20, mload(_ver_desc))) { offset := add(0x20, offset) } {
        // Place location (desc_storage[offset]) in return request
        mstore(add(add(0x0120, mul(2, offset)), store_data), add(offset, mload(add(0x80, ver_reg))))
        // Place description data in storage request
        mstore(add(add(0x0140, mul(2, offset)), store_data), mload(add(offset, _ver_desc)))
      }
    }
    // Set storage marker for return data
    request_storage = REQUEST_STORAGE;
  }

  struct VerFinalize {
    bytes4 rd_multi_sel;
    bytes32 app_storage;
    bytes32 ver_storage;
    bytes32 ver_func_list_storage;
    bytes32 ver_is_finalized_storage;
  }

  /*
  Finalizes a version, locking its implementation. Once a version is finalized, instances can be deployed and used

  @param _storage_interface: The contract to send read requests to, which acts as an interface to application storage
  @param _abs_storage: The storage address for this application
  @param _exec_id: The id of the registry application being used
  @param _provider: The address registering the app
  @param _app_name: The name of the application under which the version is registered
  @param _ver_name: The name of the version to finalized
  @return request_storage: Signals that the script executor should store the returned data
  @return store_data: 'writeMulti' storage request, returned to script exec, which requests storage from the storage interface
  */
  function finalizeVersion(address _storage_interface, address _abs_storage, bytes32 _exec_id, address _provider, bytes32 _app_name, bytes32 _ver_name) public view
  returns (bytes32 request_storage, bytes32[] store_data) {
    // Ensure valid app and version names, and valid version description length
    require(_app_name != bytes32(0));
    require(_ver_name != bytes32(0));

    // Set up struct to hold multiple variables in memory
    VerFinalize memory ver_reg = VerFinalize({
      // Place 'readMulti' function selector in memory
      rd_multi_sel: RD_MULTI_SEL,
      // Place app storage location in memory
      app_storage: keccak256(keccak256(_provider), PROVIDERS),
      // Place version storage location in memory
      ver_storage: 0,
      // Place version function list storage location in memory
      ver_func_list_storage: 0,
      // Place version 'is finalized' storage location in memory
      ver_is_finalized_storage: 0
    });

    // Get app storage location - mapped to the provider's location
    ver_reg.app_storage = keccak256(APPS, ver_reg.app_storage);
    ver_reg.app_storage = keccak256(keccak256(_app_name), ver_reg.app_storage);
    // Get version storage location
    ver_reg.ver_storage = keccak256(VERSIONS, ver_reg.app_storage);
    ver_reg.ver_storage = keccak256(keccak256(_ver_name), ver_reg.ver_storage);
    // Get version function list storage location
    ver_reg.ver_func_list_storage = keccak256(VER_FUNCTION_LIST, ver_reg.ver_storage);
    // Get version 'is finalized' storage location
    ver_reg.ver_is_finalized_storage = keccak256(VER_IS_FINALIZED, ver_reg.ver_storage);

    assembly {
      // Ensure application and version are registered, and get version function list length

      // Get free-memory pointer to hold calldata
      let sel_ptr := mload(0x40)
      // Place 'readMulti' function selector at pointer
      mstore(sel_ptr, mload(ver_reg))
      // Place abstract storage address in calldata
      mstore(add(0x04, sel_ptr), _abs_storage)
      // Place exec id in calldata
      mstore(add(0x24, sel_ptr), _exec_id)
      // Place data read offset in calldata
      mstore(add(0x44, sel_ptr), 0x60)
      // Place input length in calldata (3 read locations)
      mstore(add(0x64, sel_ptr), 3)
      // Place app storage location in calldata
      mstore(add(0x84, sel_ptr), mload(add(0x20, ver_reg)))
      // Place version storage location in calldata
      mstore(add(0xa0, sel_ptr), mload(add(0x40, ver_reg)))
      // Place version function list storage location in calldata
      mstore(add(0xc0, sel_ptr), mload(add(0x60, ver_reg)))
      // Staticcall storage interface
      let ret := staticcall(gas, _storage_interface, sel_ptr, 0xe4, 0, 0)
      // Check return value - if zero, read failed: revert
      if iszero(ret) { revert (0, 0) }
      // Copy returned data to sel_ptr
      returndatacopy(sel_ptr, 0x40, sub(returndatasize, 0x40))
      // Check that returned app name matches passed-in app name
      if iszero(eq(mload(sel_ptr), _app_name)) { revert (0, 0) }
      // Check that returned version name matches passed-in version name
      if iszero(eq(mload(add(0x20, sel_ptr)), _ver_name)) { revert (0, 0) }
      // Get version function list length
      let ver_func_list_len := mload(add(0x40, sel_ptr))
      // If there are no registered functions, version cannot be finalized: revert
      if iszero(ver_func_list_len) { revert (0, 0) }

      // Version can be finalized - return storage request

      // Get free space for return storage request
      store_data := add(0x20, msize)
      // Set storage request length
      mstore(store_data, 2)
      // Place version 'is finalized' location in storage request
      mstore(add(0x20, store_data), mload(add(0x80, ver_reg)))
      // Place '1' in storage request - signifying that the version is finalized
      mstore(add(0x40, store_data), 1)
    }
    // Set storage marker for return data
    request_storage = REQUEST_STORAGE;
  }

  struct VerInfo {
    bytes4 rd_sel;
    bytes4 rd_multi_sel;
    bytes4 true_location_sel;
    bytes32 app_storage;
    bytes32 ver_storage;
    bytes32 ver_desc_storage;
    bytes32 ver_desc_length;
  }

  /*
  Returns basic information on a registered version

  @param _storage_interface: The contract to send read requests to, which acts as an interface to application storage
  @param _abs_storage: The storage address for this application
  @param _exec_id: The id of the registry application being used
  @param _provider: The address registering the app
  @param _app_name: Plaintext name of the application under which the version is registered
  @param _ver_name: Plaintext name of the version to look up
  @return const_return: Signals that the script executor should not store the returned data
  @return true_location_ver: The true storage location of the version namespace
  @return description: Bytes of description
  */
  function getVersionBasicInfo(address _storage_interface, address _abs_storage, bytes32 _exec_id, address _provider, bytes32 _app_name, bytes32 _ver_name) public view
  returns (bytes32 const_return, bytes32 true_location_ver, bytes description) {
    // Set up struct to hold multiple variables in memory
    VerInfo memory ver_info = VerInfo({
      // Place 'read' function selector in memory
      rd_sel: RD_SEL,
      // Place 'readMulti' function selector in memory
      rd_multi_sel: RD_MULTI_SEL,
      // Place 'getTrueLocation' function selector in memory
      true_location_sel: GET_TRUE_LOC_SEL,
      // Place app storage location in memory
      app_storage: keccak256(keccak256(_provider), PROVIDERS),
      // Place version storage location in memory
      ver_storage: 0,
      // Place version description storage location in memory
      ver_desc_storage: 0,
      // Place version description length in memory
      ver_desc_length: 0
    });

    // Get app storage location - mapped to the provider's location
    ver_info.app_storage = keccak256(APPS, ver_info.app_storage);
    ver_info.app_storage = keccak256(keccak256(_app_name), ver_info.app_storage);
    // Get version and version description storage locations
    ver_info.ver_storage = keccak256(VERSIONS, ver_info.app_storage);
    ver_info.ver_storage = keccak256(keccak256(_ver_name), ver_info.ver_storage);
    ver_info.ver_desc_storage = keccak256(VER_DESC, ver_info.ver_storage);

    assembly {
      // Get version true storage location -

      // Get free-memory pointer to store call returns in
      let sel_ptr := mload(0x40)
      sel_ptr := add(0x20, sel_ptr)
      // Store 'getTrueLocation' function selector at pointer
      mstore(sel_ptr, mload(add(0x40, ver_info)))
      // Store abstract storage address in calldata
      mstore(add(0x04, sel_ptr), _abs_storage)
      // Store exec id in calldata
      mstore(add(0x24, sel_ptr), _exec_id)
      // Store version storage location in calldata
      mstore(add(0x44, sel_ptr), mload(add(0x80, ver_info)))
      // Staticcall storage interface, and store return at pointer
      mstore(sub(sel_ptr, 0x20), staticcall(gas, _storage_interface, sel_ptr, 0x64, sel_ptr, 0x20))
      // Check return value - if zero, read failed: revert
      if iszero(mload(sub(sel_ptr, 0x20))) { revert (0, 0) }
      // Assign return value for true_location_ver
      true_location_ver := mload(sel_ptr)

      // Get version description length -

      // Store 'read' function selector at pointer
      mstore(sel_ptr, mload(ver_info))
      // Store abstract storage address in calldata
      mstore(add(0x04, sel_ptr), _abs_storage)
      // Store exec id in calldata
      mstore(add(0x24, sel_ptr), _exec_id)
      // Store version description storage location in calldata
      mstore(add(0x44, sel_ptr), mload(add(0xa0, ver_info)))
      // Staticcall storage interface, and store return at pointer
      mstore(sub(sel_ptr, 0x20), staticcall(gas, _storage_interface, sel_ptr, 0x64, sel_ptr, 0x20))
      // Check return value - if zero, read failed: revert
      if iszero(mload(sub(sel_ptr, 0x20))) { revert (0, 0) }
      // Check return value (version description length) - should never be 0
      if iszero(mload(sel_ptr)) { revert (0, 0) }
      // Place return value (version description length) in ver_info
      mstore(add(0xc0, ver_info), mload(sel_ptr))

      // Get 'readMulti' input array length
      // Array length is 1 fo each nonzero slot taken up by the version description, as well as 2 for version name and version description length
      let read_size := add(2, div(mload(add(0xc0, ver_info)), 0x20))
      if gt(mod(mload(add(0xc0, ver_info)), 0x20), 0) {
        read_size := add(1, read_size)
      }

      // Store 'readMulti' function selector at pointer
      mstore(sel_ptr, mload(add(0x20, ver_info)))
      // Store abstract storage address in calldata
      mstore(add(0x04, sel_ptr), _abs_storage)
      // Store exec id in calldata
      mstore(add(0x24, sel_ptr), _exec_id)
      // Store data read offset in calldata
      mstore(add(0x44, sel_ptr), 0x60)
      // Store input length in calldata
      mstore(add(0x64, sel_ptr), read_size)
      // Store version storage location in calldata
      mstore(add(0x84, sel_ptr), mload(add(0x80, ver_info)))
      // For each slot in the version description, get its storage location and add it to calldata
      for { let offset := 0x00 } lt(offset, add(0x20, mul(0x20, sub(read_size, 1)))) { offset := add(0x20, offset) } {
        mstore(add(add(offset, 0xa4), sel_ptr), add(offset, mload(add(0xa0, ver_info))))
      }
      // Staticcall storage interface
      mstore(sub(sel_ptr, 0x20), staticcall(gas, _storage_interface, sel_ptr, add(0x84, mul(0x20, read_size)), 0, 0))
      // Check return value - if zero, read failed: revert
      if iszero(mload(sub(sel_ptr, 0x20))) { revert (0, 0) }

      // Copy returned version name into sel_ptr
      returndatacopy(sel_ptr, 0x40, 0x20)
      // Check that the returned version name is equal to passed-in name
      if iszero(eq(_ver_name, mload(sel_ptr))) { revert (0, 0) }
      // Allocate space for version description return
      description := add(0x20, msize)
      // Copy version description from returned data to return array
      returndatacopy(description, 0x60, sub(returndatasize, 0x60))
    }
    // Set constant marker for return data
    const_return = CONST_RETURN;
  }

  struct VerIndAndStatus {
    bytes4 rd_multi_sel;
    bytes32 app_storage;
    bytes32 ver_storage;
    bytes32 ver_is_finalized_storage;
    bytes32 ver_index_storage;
  }

  /*
  Returns version index in app version list, and whether the version has been finalized

  @param _storage_interface: The contract to send read requests to, which acts as an interface to application storage
  @param _abs_storage: The storage address for this application
  @param _exec_id: The id of the registry application being used
  @param _provider: The address registering the app
  @param _app_name: Plaintext name of the application under which the version is registered
  @param _ver_name: Plaintext name of the version to look up
  @return const_return: Signals that the script executor should not store the returned data
  @return ver_index: The index of the version in the application version list
  @return ver_is_finalized: Whether the version is finalized
  */
  function getVersionIndexAndStatus(address _storage_interface, address _abs_storage, bytes32 _exec_id, address _provider, bytes32 _app_name, bytes32 _ver_name) public view
  returns (bytes32 const_return, uint ver_index, bool ver_is_finalized) {
    // Set up struct to hold multiple variables in memory
    VerIndAndStatus memory ver_info = VerIndAndStatus({
      // Place 'readMulti' function selector in memory
      rd_multi_sel: RD_MULTI_SEL,
      // Place app storage location in memory
      app_storage: keccak256(keccak256(_provider), PROVIDERS),
      // Place version storage location in memory
      ver_storage: 0,
      // Place version 'is finalized' storage location in memory
      ver_is_finalized_storage: 0,
      // Place version index storage location in memory
      ver_index_storage: 0
    });

    // Get app storage location - mapped to the provider's location
    ver_info.app_storage = keccak256(APPS, ver_info.app_storage);
    ver_info.app_storage = keccak256(keccak256(_app_name), ver_info.app_storage);
    // Get version storage locations
    ver_info.ver_storage = keccak256(VERSIONS, ver_info.app_storage);
    ver_info.ver_storage = keccak256(keccak256(_ver_name), ver_info.ver_storage);
    // Get version 'is finalized' storage location, and version index location
    ver_info.ver_is_finalized_storage = keccak256(VER_IS_FINALIZED, ver_info.ver_storage);
    ver_info.ver_index_storage = keccak256(APP_VER_INDEX, ver_info.ver_storage);

    assembly {
      // Get version 'is finalized' and version index -

      // Get free-memory pointer to store calldata in
      let sel_ptr := mload(0x40)
      // Store 'readMulti' function selector at pointer
      mstore(sel_ptr, mload(ver_info))
      // Store abstract storage address in calldata
      mstore(add(0x04, sel_ptr), _abs_storage)
      // Store exec id in calldata
      mstore(add(0x24, sel_ptr), _exec_id)
      // Store data read offset in calldata
      mstore(add(0x44, sel_ptr), 0x60)
      // Store input size in calldata (2 locations to read from)
      mstore(add(0x64, sel_ptr), 2)
      // Store version 'is finalized' location in calldata
      mstore(add(0x84, sel_ptr), mload(add(0x60, ver_info)))
      // Store version index location in calldata
      mstore(add(0xa4, sel_ptr), mload(add(0x80, ver_info)))
      // Staticcall storage interface and store return at sel_ptr
      let ret := staticcall(gas, _storage_interface, sel_ptr, 0xc4, sel_ptr, 0x80)
      // Check return alue - if zero, read failed: revert
      if iszero(ret) { revert (0, 0) }
      // Assign return values
      ver_index := mload(add(0x60, sel_ptr))
      ver_is_finalized := mload(add(0x40, sel_ptr))
    }
    // Set constant marker for return data
    const_return = CONST_RETURN;
  }
}
