pragma solidity ^0.4.20;

contract PermissionedRegStorage {

  // Location of the number of app ids registered. Used to generate a unique id
  // [APP_ID_COUNT] = $num_ids_registered
  bytes32 public constant APP_ID_COUNT = keccak256("num_app_ids");

  // Namespace within an app id, where permissioned storage requestors are located
  // [$app_id_hash][PERMISSIONS]
  bytes32 public constant PERMISSIONS = keccak256("permissions");

  // Namespace within an app id, where data is stored
  // [$app_id_hash][ID_STORAGE]
  bytes32 public constant ID_STORAGE = keccak256("id_storage");

  /// FUNCTION SELECTORS ///

  // Function selector for abstract storage 'write'
  // write(bytes32 _location, bytes32 _data) returns (bytes32 location);
  bytes4 public constant WR_SEL = bytes4(keccak256("write(bytes32,bytes32)"));

  // Fucntion selector for abstract storage 'writeMulti'
  // writeMulti(bytes32[] _input) returns (uint num_writes);
  bytes4 public constant WR_MULTI_SEL = bytes4(keccak256("writeMulti(bytes32[])"));

  // Function selector for abstract storage 'read'
  // read(bytes32 _location) view returns (bytes32 data_read);
  bytes4 public constant RD_SEL = bytes4(keccak256("read(bytes32)"));

  // Function selector for abstract storage 'readMulti'
  // readMulti(bytes32[] _locations) view returns (bytes32[] data_read);
  bytes4 public constant RD_MULTI_SEL = bytes4(keccak256("readMulti(bytes32[])"));

  // Function selector for abstract storage "getTrueLocation"
  // getTrueLocation(bytes32 _location) view returns (bytes32 true_location);
  bytes4 public constant GET_TRUE_LOC_SEL = bytes4(keccak256("getTrueLocation(bytes32)"));

  struct InitApp {
    bytes4 rd_sel;
    bytes4 wr_multi_sel;
    bytes32 app_id_count_location;
    bytes32 permissions;
  }

  /*
  Initializes an application in a given storage address with a set of allowed addresses

  @param _storage: The storage address in which to initialize the app
  @param _allowed: The set of allowed requestors
  @return app_id: The unique app id under which the initialized app will be used
  */
  function initApp(address _storage, address[] _allowed) public returns (bytes32 app_id) {
    // Initialize struct to hold values, so that local variables are not exhausted
    InitApp memory init_app = InitApp({
      // Place 'read' function selector in memory
      rd_sel: RD_SEL,
      // Place 'writeMulti' function selector in memory
      wr_multi_sel: WR_MULTI_SEL,
      // Place app id count location in memory
      app_id_count_location: APP_ID_COUNT,
      // Place permissions namespace in memory
      permissions: PERMISSIONS
    });

    assembly {
      // Get a pointer to free memory for hashing
      let hash_ptr := mload(0x40)
      // Update free memory pointer to point after hash_ptr
      mstore(0x40, add(0x40, hash_ptr))
      // Get a pointer to free memory for calldata
      let sel_ptr := mload(0x40)
      let cd_ptr := add(0x04, sel_ptr)
      // Store 'read' function selector at pointer
      mstore(sel_ptr, mload(init_app))
      // Store app id count location in calldata
      mstore(cd_ptr, mload(add(0x40, init_app)))
      // Staticcall abstract storage, and store return at sel_ptr
      let ret := staticcall(gas, _storage, sel_ptr, 0x24, sel_ptr, 0x20)
      // Read return value - if zero, read failed: revert
      if iszero(ret) { revert (0, 0) }

      // Get number of registered apps
      let n_apps := mload(sel_ptr)
      // Increment, and hash. Resulting hash is the unique app id for this request
      n_apps := add(1, n_apps)
      app_id := keccak256(sel_ptr, 0x20)

      // Hash app_id and store in second part of hash_ptr
      mstore(add(0x20, hash_ptr), app_id)
      mstore(add(0x20, hash_ptr), keccak256(add(0x20, hash_ptr), 0x20))
      // Store permission location at hash ptr
      mstore(hash_ptr, mload(add(0x60, init_app)))
      // Hash app id and permission location, and store in second part of hash_ptr for further hashing
      mstore(add(0x20, hash_ptr), keccak256(hash_ptr, 0x40))

      // Store 'writeMulti' function selector at pointer
      mstore(sel_ptr, mload(add(0x20, init_app)))
      // Store data read offset in calldata
      mstore(cd_ptr, 0x20)
      // Store input length (uint) in calldata
      mstore(add(0x20, cd_ptr), add(4, mul(2, mload(_allowed))))
      // Store app id count location in calldata
      mstore(add(0x40, cd_ptr), mload(add(0x40, init_app)))
      // Store new app id count in calldata
      mstore(add(0x60, cd_ptr), n_apps)
      // Place sender storage location (currently stored in second slot of hash ptr)
      mstore(add(0x80, cd_ptr), mload(add(0x20, hash_ptr)))
      // Place sender address in calldata
      mstore(add(0xa0, cd_ptr), caller)

      // Loop over _allowed addresses, and place them and their permission location in calldata, in order
      for { let offset := 0x20 } lt(offset, add(0x20, mul(0x40, mload(_allowed)))) { offset := add(0x20, offset) } {
        // Disallow the sender as an "allowed" address
        if eq(caller, mload(add(offset, _allowed))) { revert (0, 0) }
        // Place allowed address at hash_ptr
        mstore(hash_ptr, mload(add(offset, _allowed)))
        // Hash allowed address and permission location, and place in calldata
        mstore(add(add(0xc0, mul(2, sub(offset, 0x20))), cd_ptr), keccak256(add(0x0c, hash_ptr), 0x34))
        // Place 'true' in calldata (1)
        mstore(add(add(0xe0, mul(2, sub(offset, 0x20))), cd_ptr), 1)
      }

      // Call abstract storage and store data
      ret := call(gas, _storage, 0, sel_ptr, add(0xc4, mul(0x40, mload(_allowed))), 0, 0)
      // Check return value - if zero, write failed: revert
      if iszero(ret) { revert (0, 0) }
    }
    // Ensure the app id is nonzero
    assert(app_id != bytes32(0));
  }

  /*
  Returns data read from a passed-in storage address, given an app id and location

  @param _storage: The storage address from which to read
  @param _app_id: The id of the app making the read request. Because this is a static call, we don't verify the sender is allowed to write to the app id
  @param _location: The location to read from within storage
  @return data_read: The data stored at the requested location
  */
  function read(address _storage, bytes32 _app_id, bytes32 _location) public view returns (bytes32 data_read) {
    // Place 'read' function selector in memory
    bytes4 rd_sel = RD_SEL;
    // Get storage location from app id and passed-in location
    bytes32 hashed_location = keccak256(ID_STORAGE, keccak256(_app_id));
    hashed_location = keccak256(_location, hashed_location);
    assembly {
      // Get a pointer to free memory for calldata
      let sel_ptr := mload(0x40)
      // Store 'read' fucntion selector at pointer
      mstore(sel_ptr, rd_sel)
      // Store location after function selector
      mstore(add(0x04, sel_ptr), hashed_location)
      // Read from storage using staticcall. Store return value at sel_ptr
      let ret := staticcall(gas, _storage, sel_ptr, 0x24, sel_ptr, 0x20)
      // Read return value - if zero, read failed: revert
      if iszero(ret) { revert (0, 0) }
      // Return data read
      data_read := mload(sel_ptr)
    }
  }

  /*
  Returns data read a passed-in storage address, given an app id and a set of locations to read from

  @param _storage: The storage address from which to read
  @param _app_id: The id of the app making the read request. Because this is a static call, we don't verify the sender is allowed to write to the app id
  @param _locations: An array of locations to read from in storage
  @return data_read: The data stored at the locations requested, in order
  */
  function readMulti(address _storage, bytes32 _app_id, bytes32[] _locations) public view returns (bytes32[] data_read) {
    // Place 'readMulti' function selector in memory
    bytes4 rd_multi_sel = RD_MULTI_SEL;
    // Get base storage location for the app id
    bytes32 storage_namespace = keccak256(ID_STORAGE, keccak256(_app_id));
    // Allocate memory for return data
    data_read = new bytes32[](_locations.length);
    assembly {
      // Get a pointer to free memory for hashing
      let hash_ptr := mload(0x40)
      // Store storage namespace in second slot of hash_ptr
      mstore(add(0x20, hash_ptr), storage_namespace)
      // Update free memory pointer to point after hash_ptr
      mstore(0x40, add(0x40, hash_ptr))
      // Get pointers to free memory for calldata
      let sel_ptr := mload(0x40)
      // Store 'readMulti' funciton selector at pointer
      mstore(sel_ptr, rd_multi_sel)
      // Store data read offset in calldata
      mstore(add(0x04, sel_ptr), 0x20)
      /* // Set return array location to after function signature and offset
      data_read := add(0x24, sel_ptr) */
      /* // Store length of input (uint) in calldata, and set return array length (equal to _locations length)
      mstore(data_read, mload(_locations)) */
      // Store length of input (uint) in calldata
      mstore(add(0x24, sel_ptr), mload(_locations))
      // Loop over _locations, hash with app_id to get storage location, and store in-order after function selector, in data_read
      for { let offset := 0x20 } lt(offset, add(0x20, mul(0x20, mload(_locations)))) { offset := add(0x20, offset) } {
        // Store _locations[offset] at hash_ptr, for hashing with app_id
        mstore(hash_ptr, mload(add(offset, _locations)))
        // Hash _app_id and location, and store in calldata
        mstore(add(add(0x24, offset), sel_ptr), keccak256(hash_ptr, 0x40))
      }
      // Staticcall abstract storage, and store return data in data_read array
      let ret := staticcall(gas, _storage, sel_ptr, add(0x44, mul(0x20, mload(_locations))), sub(data_read, 0x20), add(0x40, mul(0x20, mload(_locations))))
      // Check return value - if zero, read failed: revert
      if iszero(ret) { revert (0, 0) }
      // Fix overwritten return length
      mstore(data_read, mload(_locations))
    }
  }

  /*
  Gets the true, hashed storage location from storage, under a specific app id

  @param _storage: The storage address to which the request will be made
  @param _app_id: The id under which the request will be made
  @param _location: The location to get the true location of
  @return true_location: The true location, in storage, of the passed-in value
  */
  function getTrueLocation(address _storage, bytes32 _app_id, bytes32 _location) public view returns (bytes32 true_location) {
    // Place 'getTrueLocation' function selector in memory
    bytes4 get_true_loc_sel = GET_TRUE_LOC_SEL;
    // Get storage location from app id and passed-in location
    bytes32 hashed_location = keccak256(ID_STORAGE, keccak256(_app_id));
    hashed_location = keccak256(_location, hashed_location);
    assembly {
      // Get a pointer to free memory for calldata
      let sel_ptr := mload(0x40)
      // Store 'getTrueLocation' function selector at pointer
      mstore(sel_ptr, get_true_loc_sel)
      // Store location after function selector
      mstore(add(0x04, sel_ptr), hashed_location)
      // Read from storage using staticcall. Store return value at sel_ptr
      let ret := staticcall(gas, _storage, sel_ptr, 0x24, sel_ptr, 0x20)
      // Read return value - if zero, read failed: revert
      if iszero(ret) { revert (0, 0) }
      // Return true location
      true_location := mload(sel_ptr)
    }
  }

  /*
  Handles a write request - validates that the sender and passed-in address have sufficient write permissions under the given app-id

  @param _storage: The storage address to which the write request will be made
  @param _app_id: The id under which the write request will be made
  @param _requestor: The address through which the storage request is being made
  @param _location: The location to write to, in storage
  @param _data: The data to write in the location
  @returns location: The actual location stored to, returned by abstract storage
  */
  function write(address _storage, bytes32 _app_id, address _requestor, bytes32 _location, bytes32 _data) public returns (bytes32 location) {
    // Place 'write' function selector in memory
    bytes4 wr_sel = WR_SEL;
    // Ensure the sender and requestor are allowed write permissions under this app_id
    require(validPermissions(_storage, _app_id, _requestor));
    // Get storage location from app id and passed-in location
    bytes32 hashed_location = keccak256(ID_STORAGE, keccak256(_app_id));
    hashed_location = keccak256(_location, hashed_location);
    assembly {
      // Get a pointer to free memory for calldata
      let sel_ptr := mload(0x40)
      // Store 'write' function selector at pointer
      mstore(sel_ptr, wr_sel)
      // Store hashed_location in calldata
      mstore(add(0x04, sel_ptr), hashed_location)
      // Store data to store in calldata
      mstore(add(0x24, sel_ptr), _data)
      // Call abstract storage and store data. Store return at sel_ptr
      let ret := call(gas, _storage, 0, sel_ptr, 0x44, sel_ptr, 0x20)
      // Check return value - if zero, write failed: revert
      if iszero(ret) { revert (0, 0) }
      // Return location
      location := mload(sel_ptr)
    }
  }

  /*
  Handles a batch write request - validates that the sender and passed-in address have sufficient write permissions under the given app-id

  @param _storage: The storage address to which the write request will be made
  @param _app_id: The id under which the write request will be made
  @param _requestor: The address through which the storage request is being made
  @param _input: The locations and data to write to storage. Formatted as a bytes32 array: [location][data][location][data]...
  @returns num_writes: The number of writes performed in storage
  */
  function writeMulti(address _storage, bytes32 _app_id, address _requestor, bytes32[] _input) public returns (uint num_writes) {
    // Ensure input is well-formed
    require(_input.length != 0 && _input.length % 2 == 0);
    // Place 'writeMulti' function selector in memory
    bytes4 wr_multi_sel = WR_MULTI_SEL;
    // Ensure the sender and requestor are allowed write permissions under this app_id
    require(validPermissions(_storage, _app_id, _requestor));
    // Get app id storage location from app id and passed-in location
    bytes32 storage_namespace = keccak256(ID_STORAGE, keccak256(_app_id));
    assembly {
      // Get a pointer to free memory for hashing
      let hash_ptr := mload(0x40)
      // Store app id storage location in the second slot of hash_ptr
      mstore(add(0x20, hash_ptr), storage_namespace)
      // Update free-memory pointer
      mstore(0x40, add(0x40, hash_ptr))
      // Get a pointer to free memory for calldata
      let sel_ptr := mload(0x40)
      let cd_ptr := add(0x04, sel_ptr)

      // Store 'writeMulti' function selector at pointer
      mstore(sel_ptr, wr_multi_sel)
      // Store data read offset in calldata
      mstore(cd_ptr, 0x20)
      // Store input length in calldata
      mstore(add(0x20, cd_ptr), mload(_input))
      // Loop over input, hash locations with app id storage location, and add to calldata
      for { let offset := 0x00 } lt(offset, add(0x20, mul(0x20, mload(_input)))) { offset := add(0x40, offset) } {
        // Store location at hash_ptr
        mstore(hash_ptr, mload(add(add(0x20, offset), _input)))
        // Store resulting hash in calldata
        mstore(add(add(0x40, offset), cd_ptr), keccak256(hash_ptr, 0x40))
        // Store data in calldata
        mstore(add(add(0x60, offset), cd_ptr), mload(add(add(0x40, offset), _input)))
      }

      // Call abstract storage and store data
      let ret := call(gas, _storage, 0, sel_ptr, add(0x44, mul(0x20, mload(_input))), sel_ptr, 0x20)
      // Check return value - if zero, write failed: revert
      if iszero(ret) { revert (0, 0) }
      // Return number of writes
      num_writes := mload(sel_ptr)
    }
  }

  /*
  Checks that the sender and requestor can write to storage under the given app_id

  @param _storage: The storage address to which the write request is being made
  @param _app_id: The id under which the write request will be made
  @param _requestor: The address through which the storage request is beingmade
  @return can_write: Whether the sender and requestor can write to the app id
  */
  function validPermissions(address _storage, bytes32 _app_id, address _requestor) internal view returns (bool can_write) {
    // Place 'readMulti' function selector in memory
    bytes4 rd_multi_sel = RD_MULTI_SEL;
    // Get seed for permissioned namespace, and permission location for the sender
    bytes32 permissions = keccak256(PERMISSIONS, keccak256(_app_id));
    // Get permission location for requestor
    bytes32 requestor_permission = keccak256(_requestor, permissions);
    assembly {
      // Get a pointer to free memory for calldata
      let sel_ptr := mload(0x40)
      // Store 'readMulti' function selector at pointer
      mstore(sel_ptr, rd_multi_sel)
      // Store data read offset in calldata
      mstore(add(0x04, sel_ptr), 0x20)
      // Store input length in calldata
      mstore(add(0x24, sel_ptr), 2)
      // Store sender permission location in calldata
      mstore(add(0x44, sel_ptr), permissions)
      // Store requestor permission location in calldata
      mstore(add(0x64, sel_ptr), requestor_permission)
      // Staticcall abstract storage, and store return at sel_ptr
      let ret := staticcall(gas, _storage, sel_ptr, 0x84, sel_ptr, 0x80)
      // Read return value - if zero, read failed: revert
      if iszero(ret) { revert (0, 0) }
      // Read return values - if sender permission location is equal to the sender, and _requestor permission location is nonzero, return true
      if gt(mload(add(0x60, sel_ptr)), 0) {
        if eq(caller, mload(add(0x40, sel_ptr))) {
          can_write := 1
        }
      }
    }
  }
}
