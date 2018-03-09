pragma solidity ^0.4.20;

library RegisterApp {

  /// PROVIDER STORAGE ///

  // Provider namespace - all app and version storage is seeded to a provider
  // [PROVIDERS][$provider_id]
  bytes32 public constant PROVIDERS = keccak256("providers");

  /// APPLICATION STORAGE ///

  // Application namespace - all app info and version storage is mapped here
  // [PROVIDERS][$provider_id][APPS][$app_name]
  bytes32 public constant APPS = keccak256("apps");

  // Application description location - (bytes array)
  // [PROVIDERS][$provider_id][APPS][$app_name][APP_DESC] = ["description"]
  bytes32 public constant APP_DESC = keccak256("app_desc");

  // Application version list location - (bytes32 array)
  // [PROVIDERS][$provider_id][APPS][$app_name][APP_VERSIONS_LIST] = ["v_name1", "v_name2", ...]
  bytes32 public constant APP_VERSIONS_LIST = keccak256("app_versions_list");

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

  struct AppReg {
    bytes4 rd_sel;
    bytes32 app_storage;
    bytes32 desc_storage;
  }

  /*
  Registers an application under the sender's provider id

  @param _storage_interface: The contract to send read requests to, which acts as an interface to application storage
  @param _abs_storage: The storage address for this application
  @param _exec_id: The id of the registry application being used
  @param _provider: The address registering the app
  @param _app_name: The name of the application to be registered
  @param _app_desc: The description of the application
  @return: 'writeMulti' storage request, returned to script exec, which requests storage from the storage interface
  */
  function registerApp(address _storage_interface, address _abs_storage, bytes32 _exec_id, address _provider, bytes32 _app_name, bytes _app_desc) public view
  returns (bytes32 request_storage, bytes32[] store_data) {
    // Ensure valid app name and description length
    require(_app_name != bytes32(0));
    require(_app_desc.length != 0);

    AppReg memory app_reg = AppReg({
      // Place 'read' function selector in memory
      rd_sel: RD_SEL,
      // Place app storage location in memory
      app_storage: keccak256(keccak256(_provider), PROVIDERS),
      // Place description storage location in memory
      desc_storage: 0
    });

    // Get app and description storage locations - mapped to the provider's location
    app_reg.app_storage = keccak256(APPS, app_reg.app_storage);
    app_reg.app_storage = keccak256(keccak256(_app_name), app_reg.app_storage);
    app_reg.desc_storage = keccak256(APP_DESC, app_reg.app_storage);

    assembly {
      // Ensure application is not already registered -
      let sel_ptr := mload(0x40)
      // Store 'read' function selector in calldata
      mstore(sel_ptr, mload(app_reg))
      // Store storage address in calldata
      mstore(add(0x04, sel_ptr), _abs_storage)
      // Store exec id in calldata
      mstore(add(0x24, sel_ptr), _exec_id)
      // Store app storage location
      mstore(add(0x44, sel_ptr), mload(add(0x20, app_reg)))
      // Call abstract storage, and return data to sel_ptr
      let ret := staticcall(gas, _storage_interface, sel_ptr, 0x64, sel_ptr, 0x20)
      // Read return - if zero, call failed: revert
      if iszero(ret) { revert (0, 0) }
      // Read returned data - if nonzero, application is already registered: revert
      if gt(mload(sel_ptr), 0) { revert (0, 0) }

      // Get length of writeMulti input array - 2 for every nonzero 32-byte slot in _app_desc, plus 4 for app name and description length
      let write_size := add(4, mul(2, div(mload(_app_desc), 0x20)))
      // If the description does not evenly fit in 32 byte slots, write size is two larger (location and data)
      if gt(mod(mload(_app_desc), 0x20), 0) {
        write_size := add(2, write_size)
      }

      // Get pointer in free memory to return request
      store_data := add(0x20, msize)
      // Store write size at pointer
      mstore(store_data, write_size)

      // Place app name storage location and app name in return request
      mstore(add(0x20, store_data), mload(add(0x20, app_reg)))
      mstore(add(0x40, store_data), _app_name)
      // Loop over description and add to calldata in "writeMulti" format: [location][data]...
      for { let offset := 0x00 } lt(offset, add(0x20, mload(_app_desc))) { offset := add(0x20, offset) } {
        // Store location (desc_storage[offset]) in calldata
        mstore(add(add(0x60, mul(2, offset)), store_data), add(offset, mload(add(0x40, app_reg))))
        // Store description chunk in calldata
        mstore(add(add(0x80, mul(2, offset)), store_data), mload(add(offset, _app_desc)))
      }
    }
    // Set storage marker for return data
    request_storage = REQUEST_STORAGE;
  }

  struct AppInfo {
    bytes4 rd_sel;
    bytes4 rd_multi_sel;
    bytes4 true_location_sel;
    bytes32 app_storage;
    bytes32 desc_storage;
    bytes32 desc_length;
  }

  /*
  Returns simple information on a registered application

  @param _storage_interface: The contract to send read requests to, which acts as an interface to application storage
  @param _abs_storage: The storage address for this application
  @param _exec_id: The id of the registry application being used
  @param _provider: The address registering the app
  @param _app_name: Plaintext name of the application to look up
  @return true_location_app: The true storage location of the application namespace
  @return app_name: The name of the application, pulled from storage
  @return num_versions: The number of versions in the application
  @return description: Bytes of description
  */
  function getAppInfo(address _storage_interface, address _abs_storage, bytes32 _exec_id, address _provider, bytes32 _app_name) public view
  returns (bytes32 const_return, bytes32 true_location_app, bytes description) {
    // Set up struct to hold multiple variables in memory
    AppInfo memory app_info = AppInfo({
      // Place READ selector in memory
      rd_sel: RD_SEL,
      // Place READ MULTI selector in memory
      rd_multi_sel: RD_MULTI_SEL,
      // Place GET TRUE LOCATION selector in memory
      true_location_sel: GET_TRUE_LOC_SEL,
      // Place app storage location in memory
      app_storage: keccak256(keccak256(_provider), PROVIDERS),
      // Place app description location in memory
      desc_storage: 0,
      // Place description length in memory
      desc_length: 0
    });

    // Set app storage location
    app_info.app_storage = keccak256(APPS, app_info.app_storage);
    app_info.app_storage = keccak256(keccak256(_app_name), app_info.app_storage);
    // Set app description storage location
    app_info.desc_storage = keccak256(APP_DESC, app_info.app_storage);

    assembly {
      // Get free-memory pointer to store calldata in
      let sel_ptr := mload(0x40)
      // Store 'getTrueLocation' function selector at pointer
      mstore(sel_ptr, mload(add(0x40, app_info)))
      // Store abstract storage address in calldata
      mstore(add(0x04, sel_ptr), _abs_storage)
      // Store exec id in calldata
      mstore(add(0x24, sel_ptr), _exec_id)
      // Store app storage location at pointer
      mstore(add(0x44, sel_ptr), mload(add(0x60, app_info)))
      // Staticcall storage interface, and store return data at pointer
      let ret := staticcall(gas, _storage_interface, sel_ptr, 0x64, sel_ptr, 0x20)
      // Check return value - if zero, read failed: revert
      if iszero(ret) { revert (0, 0) }
      // Assign return value for true_location_app
      true_location_app := mload(sel_ptr)

      // Get description length -
      // Store 'read' function selector at pointer
      mstore(sel_ptr, mload(app_info))
      // Store abstract storage address in calldata
      mstore(add(0x04, sel_ptr), _abs_storage)
      // Store exec id in calldata
      mstore(add(0x24, sel_ptr), _exec_id)
      // Store description location in calldata
      mstore(add(0x44, sel_ptr), mload(add(0x80, app_info)))
      // Staticcall storage interface, and store return data at pointer
      ret := staticcall(gas, _storage_interface, sel_ptr, 0x64, sel_ptr, 0x20)
      // Check return value - if zero, read failed: revert
      if iszero(ret) { revert (0, 0) }
      // Check return value (desscription length) - description should never be 0
      if iszero(mload(sel_ptr)) { revert (0, 0) }
      // Place return value (description length) in app_info
      mstore(add(0xa0, app_info), mload(sel_ptr))

      // Get 'readMulti' location array length
      // Array length is 1 for each nonzero slot taken up by the description, as well as 2 for app name and description length
      let input_length := add(2, div(mload(add(0xa0, app_info)), 0x20))
      if gt(mod(mload(add(0xa0, app_info)), 0x20), 0) {
        input_length := add(1, input_length)
      }

      // Store 'readMulti' function selector at pointer
      mstore(sel_ptr, mload(add(0x20, app_info)))
      // Store abstract storage address in calldata
      mstore(add(0x04, sel_ptr), _abs_storage)
      // Store exec id in calldata
      mstore(add(0x24, sel_ptr), _exec_id)
      // Store data read offset in calldata
      mstore(add(0x44, sel_ptr), 0x60)
      // Store input length in calldata
      mstore(add(0x64, sel_ptr), input_length)
      // Store app storage location in calldata
      mstore(add(0x84, sel_ptr), mload(add(0x60, app_info)))
      // For each slot in the description, get its storage location and add it to calldata
      for { let offset := 0x00 } lt(offset, add(1, mul(0x20, sub(input_length, 1)))) { offset := add(0x20, offset) } {
        mstore(add(add(offset, 0xa4), sel_ptr), add(offset, mload(add(0x80, app_info))))
      }
      // Staticcall storage interface
      ret := staticcall(gas, _storage_interface, sel_ptr, add(0x84, mul(0x20, input_length)), 0, 0)
      // Check return value - if zero, read failed: revert
      if iszero(ret) { revert (0, 0) }

      // Copy returned app name from storage into sel_ptr
      returndatacopy(sel_ptr, 0x40, 0x20)
      // Check that returned app name is equal to passed-in name
      if iszero(eq(_app_name, mload(sel_ptr))) { revert (0, 0) }
      // Allocate space for description
      description := add(0x20, msize)
      // Copy description from returned data to return array
      returndatacopy(description, 0x60, sub(returndatasize, 0x60))
    }
    // Set constant marker for return data
    const_return = CONST_RETURN;
  }
}
