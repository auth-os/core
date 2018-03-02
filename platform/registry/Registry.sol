pragma solidity ^0.4.20;

/* NOTE: THIS CODE HAS NOT BEEN AUDITED, AND IS BEING ACTIVELY DEVELOPED AS AN EXPERIMENTAL NEW FRAMEWORK. DO NOT USE IN PRODUCTION.  */

/*
Script Registry contract - allows privileged access to create and version applications

Contract storage uses abstract storage. Mappings and storage locations are made deterministic by defining several constants,
which can be used to access locations in a predictable manner.

This contract will eventually be split into several library contracts, as well as a single interfacing contract.
*/
contract Registry {

  // Allowed to publish and update applications
  address public moderator;

  // Abstract storage contract for the registry
  address public abstract_storage;

  ///
  // APPLICATION NAMESPACES:
  ///

  // Namespace for applications
  // [APPS][$app_hash]
  bytes32 public constant APPS = keccak256("apps");

  // Location of an application's description (stored as a bytes32[])
  // [APPS][$app_hash][APP_DESC] = ["description"]
  bytes32 public constant APP_DESC = keccak256("app_desc");

  // Location of an application's version list
  // [APPS][$app_hash][APP_VERSIONS_LIST] = ["v_name1", "v_name2", ...]
  bytes32 public constant APP_VERSIONS_LIST = keccak256("app_versions_list");

  ///
  // VERSION NAMESPACES:
  ///

  // Namespace for an application's versions
  // [APPS][$app_hash][VERSIONS][$ver_hash] = uint $app_ver_list_index
  bytes32 public constant VERSIONS = keccak256("versions");

  // Location of a version's description (stored as a bytes32[])
  // [APPS][$app_hash][VERSIONS][$ver_hash][VER_DESC] = ["description"]
  bytes32 public constant VER_DESC = keccak256("ver_desc");

  // Location of whether or not a version is initialized (has defined functions)
  // [APPS][$app_hash][VERSIONS][$ver_name][VER_IS_INIT] = bool $is_init
  bytes32 public constant VER_IS_INIT = keccak256("ver_is_init");

  // Location of a version's function list
  // [APPS][$app_hash][VERSIONS][$ver_name][VER_FUNCTION_LIST] = ["f_sig1", "f_sig2", ...]
  bytes32 public constant VER_FUNCTION_LIST = keccak256("ver_functions_list");

  // Location of a version's index in its application's versions list
  // [APPS][$app_hash][VERSIONS][$ver_name][APP_VER_INDEX] = uint $app_ver_list_index
  bytes32 public constant APP_VER_INDEX = keccak256("app_ver_index");

  ///
  // FUNCTION NAMESPACES:
  ///

  // Namespace for a version's functions
  // [APPS][$app_hash][VERSIONS][$ver_name][FUNCTIONS] = uint $ver_function_list_index
  bytes32 public constant FUNCTIONS = keccak256("functions");

  // Location of a function's description (stored as a bytes32[])
  // [APPS][$app_hash][VERSIONS][$ver_name][FUNCTIONS][$f_hash][FUNC_DESC] = ["description"]
  bytes32 public constant FUNC_DESC = keccak256("func_desc");

  // Location of a function's implementing address
  // [APPS][$app_hash][VERSIONS][$ver_name][FUNCTIONS][$f_hash][FUNC_IMPL_ADDR] = $f_impl_addr
  bytes32 public constant FUNC_IMPL_ADDR = keccak256("func_impl_addr");

  // Location of a function's index in its version's functions list
  // [APPS][$app_hash][VERSIONS][$ver_name][FUNCTIONS][$f_hash][VER_FUNC_INDEX] = $f_impl_addr
  bytes32 public constant VER_FUNC_INDEX = keccak256("ver_func_index");

  ///
  // OTHER CONSTANTS:
  ///

  /* TODO combine Multi and Consecutive to allow larger batch read/writes */

  // Function signature for Abstract Storage "write" - returns bytes32 'location'
  bytes4 public constant WR_SIG = bytes4(keccak256("write(bytes32,bytes32)"));

  // Function signature for Abstract Storage "writeMulti" - returns bytes32 'location_hash'
  bytes4 public constant WR_MULTI_SIG = bytes4(keccak256("writeMulti(bytes32[])"));

  // Function signature for Abstract Storage "read" - returns bytes32 'data'
  bytes4 public constant RD_SIG = bytes4(keccak256("read(bytes32)"));

  // Function signature for Abstract Storage "readMulti" - returns bytes32[] 'data_read'
  bytes4 public constant RD_MULTI_SIG = bytes4(keccak256("readMulti(bytes32[])"));

  // Function signature for Abstract Storage "readTrueLocation" - returns bytes32 'data_read'
  bytes4 public constant RD_TRUE_LOC_SIG = bytes4(keccak256("readTrueLocation(bytes32)"));

  // Function signature for Abstract Storage "getTrueLocation" - returns bytes32 'true_location'
  bytes4 public constant GET_TRUE_LOC_SIG = bytes4(keccak256("getTrueLocation(bytes32)"));

  // Ensures only the moderator can release applicaitons and versions
  modifier onlyMod() {
    require(msg.sender == moderator);
    _;
  }

  // Constructor: sets the sender as the moderator, as well as the abstract storage address
  function Registry(address _abs_storage) public {
    moderator = msg.sender;
    abstract_storage = _abs_storage;
  }

  // Allows the moderator to name a new moderator
  function changeMod(address _new_mod) public onlyMod() {
    moderator = _new_mod;
  }

  // Allows the moderator to change the storage address this contract points at
  function changeStorage(address _new_storage) public onlyMod() {
    abstract_storage = _new_storage;
  }

  // Contains several fields important for app registration
  struct AppRegistration {
    bytes4 wr_multi_sig;
    bytes4 rd_sig;
    address abs_storage;
  }

  /*
  Allows a moderator to register an application by providing a name and description of the application

  @param _app_name: Plaintext name of the application to be registered
  @param _app_desc: Bytes of application description
  @return app_storage: The storage seed of the application registered
  @return desc_storage: The storage seed of the base of the application's dscription array
  */
  function registerApp(bytes32 _app_name, bytes _app_desc) public onlyMod() returns (bytes32 app_storage, bytes32 desc_storage) {
    // Ensure valid app name
    require(_app_name != bytes32(0));
    // Ensure valid app description size: nonzero length
    require(_app_desc.length != 0);

    // Get new app storage and description (defined in return params) location:
    app_storage = keccak256(keccak256(_app_name), APPS);
    desc_storage = keccak256(APP_DESC, app_storage);

    // Create AppRegistration struct to hold multiple variables in memory without exhausting local variables
    AppRegistration memory app_reg = AppRegistration({
      // Place WRITE MULTI sig in memory
      wr_multi_sig: WR_MULTI_SIG,
      // Place READ sig in memory
      rd_sig: RD_SIG,
      // Place abstract storage address in memory
      abs_storage: abstract_storage
    });

    // Using assembly: make calls to Abstract Storage to store app name and description information
    assembly {
      // Free-memory function signature pointer
      let sig_ptr := mload(0x40)
      // Pointer to calldata
      let cd_ptr := add(0x04, sig_ptr)

      // 1. Ensure application is not already registered -
      /// Construct "read" calldata
      mstore(sig_ptr, mload(add(0x20, app_reg))) // Place "read" function signature at sig ptr
      mstore(cd_ptr, app_storage) // Place location (app_storage) as argument one in calldata
      /// Call Abstract Storage with calldata, and store return in cd_ptr
      let ret := staticcall(gas, mload(add(0x40, app_reg)), sig_ptr, 0x24, cd_ptr, 0x20)
      /// Read return value: if zero, read failed - revert
      if iszero(ret) {
        revert (0, 0)
      }
      /// Read returned data: if nonzero, app is already registered - revert
      if iszero(iszero(mload(cd_ptr))) {
        revert (0, 0)
      }

      // 2. Application is not registered - Store application name and description -
      /// Construct "writeMulti" calldata
      mstore(sig_ptr, mload(app_reg)) // Place "writeMulti" function signature at sig_ptr
      mstore(cd_ptr, 0x20) // Store offset of writeMulti input in calldata, in calldata
      /// Get length of writeMulti input array - 2 for every 32-byte slot in _app_desc, plus 4 for app name and description length (location and data)
      let write_size := add(4, mul(2, div(mload(_app_desc), 0x20)))
      /// If the description does not evenly fit in 32 byte slots, write size is two larger (location and data)
      if gt(mod(mload(_app_desc), 0x20), 0) {
        write_size := add(2, write_size)
      }
      mstore(add(0x20, cd_ptr), write_size) // Store length of input (uint) in calldata
      /// Place app name storage location in calldata
      mstore(add(0x40, cd_ptr), app_storage)
      /// Place app name in calldata
      mstore(add(0x60, cd_ptr), _app_name)
      /// Loop over description and add to calldata in "writeMulti" format [location][data]...
      for { let offset := 0x00 } lt(offset, add(0x20, mload(_app_desc))) { offset := add(0x20, offset) } {
        /// Store location in calldata
        mstore(add(add(0x80, mul(2, offset)), cd_ptr), add(offset, desc_storage))
        /// Store description slot in calldata
        mstore(add(add(0xa0, mul(2, offset)), cd_ptr), mload(add(offset, _app_desc)))
      }
      /// Call Abstract Storage with calldata
      ret := call(gas, mload(add(0x40, app_reg)), 0, sig_ptr, add(0x44, mul(0x20, write_size)), 0, 0)
      /// Read return value: if zero, write failed - revert
      if iszero(ret) {
        revert (0, 0)
      }
    }
  }

  // Contains several fields important for getting application information
  struct AppInfo {
    bytes4 rd_multi_sig;
    bytes4 true_location_sig;
    address abs_storage;
    bytes32 app_desc_location;
    bytes32 ver_list_location;
  }

  /*
  Returns simple information on a registered application

  @param _app_name: Plaintext name of the application to look up
  @return true_location: The true storage location of the application namespace, in Abstract Storage
  @return description: Bytes of description
  @return app_name: The name of the application, pulled from storage
  @return desc_length: The length of the app's description, in bytes
  @return num_versions: The number of versions in the application
  */
  function getAppInfo(bytes32 _app_name) public constant
  returns (bytes32 true_location, bytes description, bytes32 app_name, bytes32 desc_length, uint num_versions) {
    // Get app storage location
    bytes32 app_storage = keccak256(keccak256(_app_name), APPS);

    // Create AppInfo struct to hold multiple variables in memory without exhausting local variables
    AppInfo memory app_info = AppInfo({
      // Place READ_MULTI sig in memory
      rd_multi_sig: RD_MULTI_SIG,
      // Place GET_TRUE_LOC_SIG in memory
      true_location_sig: GET_TRUE_LOC_SIG,
      // Place abstract storage address in memory
      abs_storage: abstract_storage,
      // Get app description location
      app_desc_location: keccak256(APP_DESC, app_storage),
      // Place app version list location in struct
      ver_list_location: keccak256(APP_VERSIONS_LIST, app_storage)
    });

    assembly {
      // Free-memory function signature pointer
      let sig_ptr := mload(0x40)
      // Pointer to calldata
      let cd_ptr := add(0x04, sig_ptr)
      // Place "get true location" function signature at sig_ptr
      mstore(sig_ptr, mload(add(0x20, app_info)))

      // 1. Get true storage location for application -
      /// Construct "get true location" calldata (signature already in place)
      mstore(cd_ptr, app_storage)
      /// Call Abstract Storage with calldata, and store return in cd_ptr
      let ret := staticcall(gas, mload(add(0x40, app_info)), sig_ptr, 0x24, cd_ptr, 0x20)
      /// Return true_location
      true_location := mload(cd_ptr)

      // 2. Get rest of app info by constructing "readMulti" calldata -
      mstore(sig_ptr, mload(app_info))
      mstore(cd_ptr, 0x20) // Store offset of input data in calldata, in calldata
      mstore(add(0x20, cd_ptr), 4) // Store size of input in calldata (4 reads)
      /// Store app name location in calldata
      mstore(add(0x40, cd_ptr), app_storage)
      /// Store app description location in calldata
      mstore(add(0x60, cd_ptr), mload(add(0x60, app_info)))
      /// Store version list location in calldata
      mstore(add(0x80, cd_ptr), mload(add(0x80, app_info)))
      /// Call Abstract Storage with calldata, and store return in cd_ptr in corresponding locations
      ret := staticcall(gas, mload(add(0x40, app_info)), sig_ptr, 0xa4, cd_ptr, 0xa0)
      /// Assign return values
      app_name := mload(add(0x40, cd_ptr))
      desc_length := mload(add(0x60, cd_ptr))
      num_versions := mload(add(0x80, cd_ptr))

      // 3. Get application description -
      /// Construct "readMulti" calldata (signature already in place)
      mstore(cd_ptr, 0x20) // Store offset of input data in calldata, in calldata
      /// Calculate input data size - 1 read for every non-zero 32-byte slot
      let input_size := div(desc_length, 0x20)
      if gt(mod(desc_length, 0x20), 0) {
        input_size := add(1, input_size)
      }
      mstore(add(0x20, cd_ptr), input_size) // Store size of input data in calldata
      for { let offset := 0x20 } lt(offset, add(0x20, desc_length)) { offset := add(0x20, offset) } {
        /// Place location in calldata
        mstore(add(add(0x20, offset), cd_ptr), add(offset, mload(add(0x60, app_info))))
      }
      // Set description bytes return location
      description := add(0x20, msize)
      // Store description size
      mstore(description, desc_length)
      /// Call Abstract Storage with calldata, and store return in cd_ptr in corresponding locations
      ret := staticcall(gas, mload(add(0x40, app_info)), sig_ptr, add(0x44, mul(0x20, input_size)), sub(description, 0x20), add(0x40, mul(0x20, input_size)))
      /// Fix overwritten description length
      mstore(description, desc_length)
    }
  }

  struct VerRegistration {
    bytes4 wr_multi_sig;
    bytes4 rd_multi_sig;
    address abs_storage;
    bytes32 ver_list_location;
    bytes32 app_ver_index_location;
  }

  /*
  Allows a moderator to register a named version under an application by providing a name and description

  @param _app_name: Plaintext name of the application under which to release this version
  @param _ver_name: Plaintext name of the version to be registered
  @param _ver_desc: Bytes of version description
  @return ver_storage: Storage seed for new version namespace
  @return desc_storage: Storage seed for new version description location
  */
  function registerVersion(bytes32 _app_name, bytes32 _ver_name, bytes _ver_desc) public onlyMod() returns (bytes32 ver_storage, bytes32 desc_storage) {
    // Ensure valid app and version name
    require(_app_name != bytes32(0));
    require(_ver_name != bytes32(0));
    // Ensure valid version description input: nonzero length
    require(_ver_desc.length != 0);

    // Get app storage loaction:
    bytes32 app_storage = keccak256(keccak256(_app_name), APPS);
    // Get new version name and description storage (defined in return params) location;
    ver_storage = keccak256(VERSIONS, app_storage);
    ver_storage = keccak256(keccak256(_ver_name), ver_storage);
    desc_storage = keccak256(VER_DESC, ver_storage);

    // Create VerRegistration struct to hold multiple variables in memory without exhausting local variables
    VerRegistration memory ver_reg = VerRegistration({
      // Place WRITE_MULTI sig in memory
      wr_multi_sig: WR_MULTI_SIG,
      // Place READ_MULTI sig in memory
      rd_multi_sig: RD_MULTI_SIG,
      // Place abstract storage address in memory
      abs_storage: abstract_storage,
      // Place app version list location in struct
      ver_list_location: keccak256(APP_VERSIONS_LIST, app_storage),
      // Get new version's app_ver_index location
      app_ver_index_location: keccak256(APP_VER_INDEX, ver_storage)
    });

    // Using assembly: make calls to Abstract Storage to store version name and description information
    assembly {
      // Free-memory function signature pointer
      let sig_ptr := mload(0x40)
      // Pointer to calldata
      let cd_ptr := add(0x04, sig_ptr)

      // 1. Check application name, version name, and app version list length -
      /// Construct "readMulti" calldata
      mstore(sig_ptr, mload(add(0x20, ver_reg)))
      mstore(cd_ptr, 0x20) // Place offset of read locations in calldata, in calldata
      mstore(add(0x20, cd_ptr), 3) // Place size of "readMulti" input in calldata (3 reads)
      /// Store app name location in calldata
      mstore(add(0x40, cd_ptr), app_storage)
      /// Store version name location in calldata
      mstore(add(0x60, cd_ptr), ver_storage)
      /// Store app version list location in calldata
      mstore(add(0x80, cd_ptr), mload(add(0x60, ver_reg)))
      /// Call Abstract Storage with calldata, and store return in cd_ptr in corresponding locations
      let ret := staticcall(gas, mload(add(0x40, ver_reg)), sig_ptr, 0xa4, cd_ptr, 0xa0)
      /// Read return value: if zero, read failed - revert
      if iszero(ret) {
        revert (0, 0)
      }
      /// Check returned app storage - if zero, app does not exist - revert
      if iszero(mload(add(0x40, cd_ptr))) {
        revert (0, 0)
      }
      /// Check returned ver storage - if nonzero, version already exists - revert
      if iszero(iszero(mload(add(0x60, cd_ptr)))) {
        revert (0, 0)
      }
      /// Get app version list length
      let num_versions := mload(add(0x80, cd_ptr))

      // 2. App exists, version is unique. Store version information -
      /// Construct "writeMulti" calldata
      mstore(sig_ptr, mload(ver_reg)) // Place "writeMulti" function signature at sig_ptr
      mstore(cd_ptr, 0x20) // Place offset of write locations in calldata, in calldata
      /// Calculate size of writeMulti input (uint)
      let write_size := add(10, mul(2, div(mload(_ver_desc), 0x20)))
      /// If the description does not evenly fit in 32 byte slots, write size is two larger (location and data)
      if gt(mod(mload(_ver_desc), 0x20), 0) {
        write_size := add(2, write_size)
      }
      mstore(add(0x20, cd_ptr), write_size) // Place size of "writeMulti" input in calldata
      // 2.A. Push version name to list, and increment length -
      /// Place app version list location in calldata
      mstore(add(0x40, cd_ptr), mload(add(0x60, ver_reg)))
      /// Place new list length in calldata
      mstore(add(0x60, cd_ptr), add(1, num_versions))
      /// Place location of end of list in calldata
      mstore(add(0x80, cd_ptr), add(add(0x20, mul(0x20, num_versions)), mload(add(0x60, ver_reg))))
      /// Place version name in calldata, to be appended to the end of the app version list
      mstore(add(0xa0, cd_ptr), _ver_name)
      // 2.B. Store version index in version APP_VER_INDEX -
      /// Place location in calldata: app_ver_index_location
      mstore(add(0xc0, cd_ptr), mload(add(0x80, ver_reg)))
      /// Place version index in calldata
      mstore(add(0xe0, cd_ptr), num_versions)
      // 2.C. Store version name in ver storage -
      /// Place version storage in calldata
      mstore(add(0x0100, cd_ptr), ver_storage)
      /// Place version name in calldata
      mstore(add(0x0120, cd_ptr), _ver_name)

      /// Loop over description and add to calldata in "writeMulti" format [location][data]...
      for { let offset := 0x00 } lt(offset, add(0x20, mload(_ver_desc))) { offset := add(0x20, offset) } {
        /// Store location in calldata
        mstore(add(add(0x0140, mul(2, offset)), cd_ptr), add(offset, desc_storage))
        /// Store data in calldata
        mstore(add(add(0x0160, mul(2, offset)), cd_ptr), mload(add(offset, _ver_desc)))
      }

      /// Call Abstract Storage with calldata
      ret := call(gas, mload(add(0x40, ver_reg)), 0, sig_ptr, add(0x44, mul(0x20, write_size)), 0, 0)
      /// Read return value: if zero, write failed - revert
      if iszero(ret) {
        revert (0, 0)
      }
    }
  }

  struct VerInfo {
    bytes4 rd_multi_sig;
    bytes4 true_location_sig;
    address abs_storage;
    bytes32 ver_desc_location;
    bytes32 ver_is_init_location;
    bytes32 app_ver_index_location;
    bytes32 ver_function_list_location;
  }

  /*
  Returns simple information on a registered version

  @param _app_name: Plaintext name of the application under which the version is registered
  @param _ver_name: Plaintext name of the version to get info for
  @return true_ver_storage: The true storage location of the version namespace, in Abstract Storage
  @return description: Bytes of description
  @return ver_name: The name of the version, pulled from storage
  @return ver_desc_length: The length of the version's description, in bytes
  @return is_init: Whether the version is initialized (ready for deploy)
  @return app_ver_list_index: The index of this version in its app's version list
  @return true_func_list_ptr: The true storage location of this version's function list, in Abstract Storage
  */
  function getVerInfo(bytes32 _app_name, bytes32 _ver_name) public constant
  returns (bytes32 true_ver_storage, bytes description, bytes32 ver_name, bytes32 ver_desc_length, bool is_init, uint app_ver_list_index, uint num_functions, bytes32 true_func_list_ptr) {
    // Get app storage location:
    bytes32 app_storage = keccak256(keccak256(_app_name), APPS);
    // Get version storage location;
    bytes32 ver_storage = keccak256(VERSIONS, app_storage);
    ver_storage = keccak256(keccak256(_ver_name), ver_storage);

    // Create VerInfo struct to hold multiple variables in memory without exhausting local variables
    VerInfo memory ver_info = VerInfo({
      // Place READ sig in memory
      rd_multi_sig: RD_MULTI_SIG,
      // Place GET_TRUE_LOC_SIG in memory
      true_location_sig: GET_TRUE_LOC_SIG,
      // Place abstract storage address in memory
      abs_storage: abstract_storage,
      // Get version description location
      ver_desc_location: keccak256(VER_DESC, ver_storage),
      // Get version "is init" storage location
      ver_is_init_location: keccak256(VER_IS_INIT, ver_storage),
      // Get version's app_ver_index location
      app_ver_index_location: keccak256(APP_VER_INDEX, ver_storage),
      // Get version function list location
      ver_function_list_location: keccak256(VER_FUNCTION_LIST, ver_storage)
    });

    assembly {
      // Free-memory function signature pointer
      let sig_ptr := mload(0x40)
      // Pointer to calldata
      let cd_ptr := add(0x04, sig_ptr)
      // Place "read true location" function signature at sig_ptr
      mstore(sig_ptr, mload(add(0x20, ver_info)))

      // 1. Get true storage location for version -
      /// Construct "read true location" calldata (signature already in place)
      mstore(cd_ptr, ver_storage)
      /// Call Abstract Storage with calldata, and store return in cd_ptr
      let ret := staticcall(gas, mload(add(0x40, ver_info)), sig_ptr, 0x24, cd_ptr, 0x20)
      /// Return true_ver_storage
      true_ver_storage := mload(cd_ptr)

      // 2. Get true storage location for version's functions -
      /// Construct "read true location" calldata (signature already in place)
      mstore(cd_ptr, mload(add(0xc0, ver_info))) // Place location (ver_function_list_location) in calldata
      /// Call Abstract Storage with calldata, and store return in cd_ptr
      ret := staticcall(gas, mload(add(0x40, ver_info)), sig_ptr, 0x24, cd_ptr, 0x20)
      /// Return true_func_list_ptr
      true_func_list_ptr := mload(cd_ptr)

      // 3. Get rest of version info by constructing "readMulti" calldata
      /// Construct "readMulti" calldata
      mstore(sig_ptr, mload(ver_info)) // Place "readMulti" function signature at sig_ptr
      mstore(cd_ptr, 0x20) // Store offset of input data in calldata, in calldata
      mstore(add(0x20, cd_ptr), 5) // Store size of input data in caldata (5 reads)
      /// Store version name location in calldata
      mstore(add(0x40, cd_ptr), ver_storage)
      /// Store version description length location in calldata
      mstore(add(0x60, cd_ptr), mload(add(0x60, ver_info)))
      /// Store version is_init location in calldata
      mstore(add(0x80, cd_ptr), mload(add(0x80, ver_info)))
      /// Store version index in app version list, in calldata
      mstore(add(0xa0, cd_ptr), mload(add(0xa0, ver_info)))
      /// Store version function list length location in calldata
      mstore(add(0xc0, cd_ptr), mload(add(0xc0, ver_info)))
      /// Call Abstract Storage with calldata, and store return in cd_ptr
      ret := staticcall(gas, mload(add(0x40, ver_info)), sig_ptr, 0xe4, cd_ptr, 0xe0)
      /// Assign return values
      ver_name := mload(add(0x40, cd_ptr))
      ver_desc_length := mload(add(0x60, cd_ptr))
      is_init := mload(add(0x80, cd_ptr))
      app_ver_list_index := mload(add(0xa0, cd_ptr))
      num_functions := mload(add(0xc0, cd_ptr))

      // 4. Get version description -
      /// Construct "readMulti" calldata (signature already in place)
      mstore(cd_ptr, 0x20) // Store offset of input data in calldata, in calldata
      /// Calculate input data size - 1 read for every non-zero 32-byte slot
      let input_size := div(ver_desc_length, 0x20)
      if gt(mod(ver_desc_length, 0x20), 0) {
        input_size := add(1, input_size)
      }
      mstore(add(0x20, cd_ptr), input_size) // Store size of input data in calldata
      for { let offset := 0x20 } lt(offset, add(0x20, ver_desc_length)) { offset := add(0x20, offset) } {
        /// Place location in calldata
        mstore(add(add(0x20, offset), cd_ptr), add(offset, mload(add(0x60, ver_info))))
      }
      // Set description bytes return location
      description := add(0x20, msize)
      /// Call Abstract Storage with calldata, and store return in cd_ptr in corresponding locations
      ret := staticcall(gas, mload(add(0x40, ver_info)), sig_ptr, add(0x44, mul(0x20, input_size)), sub(description, 0x20), add(0x40, mul(0x20, input_size)))
      /// Fix overwritten description length
      mstore(description, ver_desc_length)
    }
  }

  struct FuncRegistration {
    bytes4 wr_multi_sig;
    bytes4 rd_multi_sig;
    address abs_storage;
    bytes32 ver_is_init_location;
    bytes32 func_desc_location;
    bytes32 func_impl_location;
    bytes32 ver_func_index_location;
  }

  /*
  Allows a moderator to add functions to a registered version, by providing function signatures, descriptions, and implemeting addresses

  @param _app_name: Plaintext name of the application under which this version is registered
  @param _ver_name: Plaintext name of the version under which to register the functions
  @param _func_sigs: An array of all plaintext function signatures to be added (EX: "transfer(address,uint256)")
  @param _func_descs: An array of all plaintext function descriptions to be added (EX: "transfers tokens")
  @param _func_impls: An array of all addresses implementing the corresponding functions listed in _func_sigs
  @return ver_func_list_location: The base location for a version's function list
  TODO dynamic function description size
  */
  function addVersionFunctions(bytes32 _app_name, bytes32 _ver_name, bytes32[] _func_sigs, bytes32[] _func_descs, address[] _func_impls) public onlyMod() returns (bytes32 ver_func_list_location) {
    // Ensure valid app and version name
    require(_app_name != bytes32(0));
    require(_ver_name != bytes32(0));
    // Check that sig, desc, and impl lengths are equal and nonzero
    require(_func_sigs.length != 0 && _func_sigs.length == _func_descs.length && _func_descs.length == _func_impls.length);

    // Get app storage location
    bytes32 app_storage = keccak256(keccak256(_app_name), APPS);
    // Get version storage location
    bytes32 ver_storage = keccak256(VERSIONS, app_storage);
    ver_storage = keccak256(keccak256(_ver_name), ver_storage);
    // Get version function list location
    ver_func_list_location = keccak256(VER_FUNCTION_LIST, ver_storage);
    // Get version function storage namespace location
    bytes32 func_storage = keccak256(FUNCTIONS, ver_storage);

    // Create FuncRegistration struct to hold multiple variables in memory without exhausting local variables
    FuncRegistration memory func_reg = FuncRegistration({
      // Place WRITE_MULTI sig in memory
      wr_multi_sig: WR_MULTI_SIG,
      // Place READ_MULTI sig in memory
      rd_multi_sig: RD_MULTI_SIG,
      // Place abstract storage address in memory
      abs_storage: abstract_storage,
      // Get version "is init" storage location
      ver_is_init_location: keccak256(VER_IS_INIT, ver_storage),
      // Place function description location seed in memory
      func_desc_location: FUNC_DESC,
      // Place function implementation location seed in memory
      func_impl_location: FUNC_IMPL_ADDR,
      // Place version func list index location seed in memory
      ver_func_index_location: VER_FUNC_INDEX
    });

    // Using assembly: make calls to Abstract Storage to store function information
    assembly {
      // Free-memory pointer to a location in which to hash function signatures
      let hash_ptr := mload(0x40)
      /// Place function storage namespace in second slot of hash_ptr
      mstore(add(0x20, hash_ptr), func_storage)
      // Pointer to function signatures in calldata
      let sig_ptr := add(0x40, hash_ptr)
      // Pointer to calldata
      let cd_ptr := add(0x04, sig_ptr)

      // 1. Check application and version exist, version is not initialized, and that all function signatures are unique
      /// Construct "readMulti" calldata
      mstore(sig_ptr, mload(add(0x20, func_reg)))
      mstore(cd_ptr, 0x20) // Place offset of read locations in calldata, in calldata
      mstore(add(0x20, cd_ptr), add(4, mload(_func_sigs))) // Place size of "readMulti" input in calldata (4 + num_sigs reads)
      /// Store app name location in calldata
      mstore(add(0x40, cd_ptr), app_storage)
      /// Store version name location in calldata
      mstore(add(0x60, cd_ptr), ver_storage)
      /// Store version is_init location in calldata
      mstore(add(0x80, cd_ptr), mload(add(0x60, func_reg)))
      /// Store version function list location in calldata
      mstore(add(0xa0, cd_ptr), ver_func_list_location)
      /// Loop over input function sig list, and ensure store all in calldata (to check for uniqueness)
      /// Additionally, ensure that all input sigs, descriptions, and implementing addresses are nonzero
      for { let offset := 0x20 } lt(offset, add(0x20, mul(0x20, mload(_func_sigs)))) { offset := add(0x20, offset) } {
        /// Check that no fields are zero
        if iszero(mload(add(offset, _func_sigs))) { revert (0, 0) }
        if iszero(mload(add(offset, _func_descs))) { revert (0, 0) }
        if iszero(mload(add(offset, _func_impls))) { revert (0, 0) }
        /// Place hash of function signature in first slot of hash_ptr
        mstore(hash_ptr, keccak256(add(offset, _func_sigs), 0x20))
        /// Add location to calldata
        mstore(add(add(0xa0, offset), cd_ptr), keccak256(hash_ptr, 0x40))
      }
      /// Call Abstract Storage with calldata, and store return in cd_ptr
      let ret := staticcall(gas, mload(add(0x40, func_reg)), sig_ptr, add(0xc4, mul(0x20, mload(_func_sigs))), cd_ptr, add(0xc0, mul(0x20, mload(_func_sigs))))
      /// Read return value: if zero, read failed - revert
      if iszero(ret) {
        revert (0, 0)
      }
      /// Check returned app storage - if zero, app does not exist - revert
      if iszero(mload(add(0x40, cd_ptr))) {
        revert (0, 0)
      }
      /// Check returned ver storage - if zero, version does not exist - revert
      if iszero(mload(add(0x60, cd_ptr))) {
        revert (0, 0)
      }
      /// Check is version is initialized - if nonzero, version is initialized - revert
      if iszero(iszero(mload(add(0x80, cd_ptr)))) {
        revert (0, 0)
      }
      /// Loop over returned function storage locations. If any locations are nonzero, function already exists - revert
      for { let offset := 0x00 } lt(offset, mul(0x20, mload(_func_sigs))) { offset := add(0x20, offset) } {
        if iszero(iszero(mload(add(add(0xc0, offset), cd_ptr)))) {
          revert (0, 0)
        }
      }
      /// Get version function list length
      let num_functions := mload(add(0xa0, cd_ptr))

      // 2. App exists, version exists and is not initialized, and function signatures are unique. Store all function information
      /// Construct "writeMulti" calldata
      mstore(sig_ptr, mload(func_reg)) // Place "writeMulti" function signature at sig_ptr
      mstore(cd_ptr, 0x20) // Place offset of write locations in calldata, in calldata
      /// Calculate size of writeMulti input (uint)
      /// Input size increases by 10 for every additional function signature, as well as 2 for version function list size
      let write_size := add(2, mul(10, mload(_func_sigs)))
      /// Store write size in calldata
      mstore(add(0x20, cd_ptr), write_size)
      /// Place version function list location in calldata
      mstore(add(0x40, cd_ptr), ver_func_list_location)
      /// Place new version function list length in calldata
      mstore(add(0x60, cd_ptr), add(num_functions, mload(_func_sigs)))
      /// Loop over function signature, description, and implementation arrays
      for { let offset := 0x00 } lt(offset, mul(0x20, mload(_func_sigs))) { offset := add(0x20, offset) } {
        // 2.A. Push function signature to version function list -
        /// Place version function list index in calldata
        mstore(add(add(0x80, mul(10, offset)), cd_ptr), add(ver_func_list_location, mul(0x20, add(num_functions, div(add(0x20, offset), 0x20)))))
        /// Place function signature in calldata
        mstore(add(add(0xa0, mul(10, offset)), cd_ptr), mload(add(add(0x20, offset), _func_sigs)))
        // 2.B. Calculate function storage namespace -
        /// Store function signature hash in first part of hash_ptr
        mstore(hash_ptr, keccak256(add(add(0x20, offset), _func_sigs), 0x20))
        /// Store function storage seed in second part of hash_ptr
        mstore(add(0x20, hash_ptr), func_storage)
        /// Store hash of hashed signature and function storage seed (function storage namespace) in second slot of hash_ptr, for further hashing
        mstore(add(0x20, hash_ptr), keccak256(hash_ptr, 0x40))
        // 2.C. Store function signature at function storage location -
        /// Place function storage location in calldata
        mstore(add(add(0xc0, mul(10, offset)), cd_ptr), mload(add(0x20, hash_ptr)))
        /// Place function signature in calldata
        mstore(add(add(0xe0, mul(10, offset)), cd_ptr), mload(add(add(0x20, offset), _func_sigs)))
        // 2.D. Store function index -
        /// Store function index seed in first part of hash_ptr
        mstore(hash_ptr, mload(add(0xc0, func_reg)))
        /// Hash function index seed and function storage namespace, and store in calldata
        mstore(add(add(0x0100, mul(10, offset)), cd_ptr), keccak256(hash_ptr, 0x40))
        /// Place function index in calldata
        mstore(add(add(0x0120, mul(10, offset)), cd_ptr), sub(add(num_functions, div(add(0x20, offset), 0x20)), 1))
        // 2.E. Store function description and implementing address
        /// Place function description seed in first part of hash_ptr
        mstore(hash_ptr, mload(add(0x80, func_reg)))
        /// Hash function description seed and function storage namespace, and store in calldata
        mstore(add(add(0x0140, mul(10, offset)), cd_ptr), keccak256(hash_ptr, 0x40))
        /// Place function description in calldata
        mstore(add(add(0x0160, mul(10, offset)), cd_ptr), mload(add(add(0x20, offset), _func_descs)))
        /// Place function implementing address seed in first part of hash_ptr
        mstore(hash_ptr, mload(add(0xa0, func_reg)))
        /// Hash function implementing address seed and function storage namespace, and store in calldata
        mstore(add(add(0x0180, mul(10, offset)), cd_ptr), keccak256(hash_ptr, 0x40))
        /// Place function implementing address in calldata
        mstore(add(add(0x01a0, mul(10, offset)), cd_ptr), mload(add(add(0x20, offset), _func_impls)))
      }
      /// Call Abstract Storage with calldata
      ret := call(gas, mload(add(0x40, func_reg)), 0, sig_ptr, add(0x44, mul(0x20, write_size)), 0, 0)
      /// Read return value: if zero, write failed - revert
      if iszero(ret) {
        revert (0, 0)
      }
    }
  }

  struct FuncInfo {
    bytes4 rd_multi_sig;
    bytes4 true_location_sig;
    address abs_storage;
    bytes32 func_desc_location;
    bytes32 func_impl_location;
    bytes32 ver_func_index_location;
  }

  /*
  Returns simple information on a function registered in a version

  @param _app_name: Plaintext name of the application under which the version is registered
  @param _ver_name: Plaintext name of the version under which the function is registered
  @param _func_sig: Plaintext function signature about which to look up information
  @return true_func_storage: The true storage location of the function namespace, in Abstract Storage
  @return func_sig: The signature of the function, pulled from storage
  @return func_desc: The function's description
  @return func_impl: The address which implements this function
  @return ver_func_index: The index of this function in the version's function list
  */
  function getFuncInfo(bytes32 _app_name, bytes32 _ver_name, bytes32 _func_sig) public constant
  returns (bytes32 true_func_storage, bytes32 func_sig, bytes32 func_desc, address func_impl, uint ver_func_index) {
    // Get app storage location:
    bytes32 app_storage = keccak256(keccak256(_app_name), APPS);
    // Get version storage location;
    bytes32 ver_storage = keccak256(VERSIONS, app_storage);
    ver_storage = keccak256(keccak256(_ver_name), ver_storage);
    // Get function storage location
    bytes32 func_storage = keccak256(FUNCTIONS, ver_storage);
    func_storage = keccak256(keccak256(_func_sig), func_storage);

    // Create FuncInfo struct to hold multiple variables in memory without exhausting local variables
    FuncInfo memory func_info = FuncInfo({
      // Place READ_MULTI sig in memory
      rd_multi_sig: RD_MULTI_SIG,
      // Place GET_TRUE_LOC_SIG in memory
      true_location_sig: GET_TRUE_LOC_SIG,
      // Place abstract storage address in memory
      abs_storage: abstract_storage,
      // Get func description location
      func_desc_location: keccak256(FUNC_DESC, func_storage),
      // Get func implementing address location
      func_impl_location: keccak256(FUNC_IMPL_ADDR, func_storage),
      // Get version function list index for this function
      ver_func_index_location: keccak256(VER_FUNC_INDEX, func_storage)
    });

    assembly {
      // Free-memory function signature pointer
      let sig_ptr := mload(0x40)
      // Pointer to calldata
      let cd_ptr := add(0x04, sig_ptr)
      // Place "read true location" function signature at sig_ptr
      mstore(sig_ptr, mload(add(0x20, func_info)))

      // 1. Get true storage location for function -
      /// Construct "read true location" calldata (signature already in place)
      mstore(cd_ptr, func_storage)
      /// Call Abstract Storage with calldata, and store return in cd_ptr
      let ret := staticcall(gas, mload(add(0x40, func_info)), sig_ptr, 0x24, cd_ptr, 0x20)
      /// Return true_func_ptr
      true_func_storage := mload(cd_ptr)

      // 2. Get rest of version ino by constructing "readMulti" calldata
      /// Construct "readMulti" calldata
      mstore(sig_ptr, mload(func_info)) // Place "readMulti" function signature at sig_ptr
      mstore(cd_ptr, 0x20) // Store offset of input data in calldata, in calldata
      mstore(add(0x20, cd_ptr), 4) // Store size of input data in caldata (4 reads)
      /// Store function signature location in calldata
      mstore(add(0x40, cd_ptr), func_storage)
      /// Store function description location in calldata
      mstore(add(0x60, cd_ptr), mload(add(0x60, func_info)))
      /// Store function implementing address location in calldata
      mstore(add(0x80, cd_ptr), mload(add(0x80, func_info)))
      /// Store function list index in calldata
      mstore(add(0xa0, cd_ptr), mload(add(0xa0, func_info)))
      /// Call Abstract Storage with calldata, and store return in cd_ptr
      ret := staticcall(gas, mload(add(0x40, func_info)), sig_ptr, 0xc4, cd_ptr, 0xc0)
      /// Assign return values
      func_sig := mload(add(0x40, cd_ptr))
      func_desc := mload(add(0x60, cd_ptr))
      func_impl := mload(add(0x80, cd_ptr))
      ver_func_index := mload(add(0xa0, cd_ptr))
    }
  }

  struct InitVer {
    bytes4 wr_sig;
    bytes4 rd_multi_sig;
    address abs_storage;
    bytes32 ver_is_init_location;
    bytes32 ver_func_list_location;
  }

  /*
  Allows a moderator to initialize a version, signifying it is ready for deployment

  @param _app_name: Plaintext name of the application under which the version is registered
  @param _ver_name: Plaintext name of the version to be initialized
  @return num_functions: The number of functions registered in this version
  */
  function initVersion(bytes32 _app_name, bytes32 _ver_name) public onlyMod() returns (uint num_functions) {
    // Ensure valid app and version name
    require(_app_name != bytes32(0));
    require(_ver_name != bytes32(0));

    // Get app storage loaction:
    bytes32 app_storage = keccak256(keccak256(_app_name), APPS);
    // Get version storage location;
    bytes32 ver_storage = keccak256(VERSIONS, app_storage);
    ver_storage = keccak256(keccak256(_ver_name), ver_storage);

    // Create InitVer struct to hold multiple variables in memory without exhausting local variables
    InitVer memory ver_init = InitVer({
      // Place WRITE sig in memory
      wr_sig: WR_SIG,
      // Place READ_MULTI sig in memory
      rd_multi_sig: RD_MULTI_SIG,
      // Place abstract storage address in memory
      abs_storage: abstract_storage,
      // Place ver is_init location in struct
      ver_is_init_location: keccak256(VER_IS_INIT, ver_storage),
      // Place version function list location in struct
      ver_func_list_location: keccak256(VER_FUNCTION_LIST, ver_storage)
    });

    assembly {
      // Free-memory function signature pointer
      let sig_ptr := mload(0x40)
      // Pointer to calldata
      let cd_ptr := add(0x04, sig_ptr)

      // 1. Check application name, version name, ver_is_init location, and ver function list location
      /// Construct "readMulti" calldata
      mstore(sig_ptr, mload(add(0x20, ver_init)))
      mstore(cd_ptr, 0x20) // Place offset of read locations in calldata, in calldata
      mstore(add(0x20, cd_ptr), 4) // Place size of "readMulti" input in calldata (3 reads)
      /// Store app name location in calldata
      mstore(add(0x40, cd_ptr), app_storage)
      /// Store version name location in calldata
      mstore(add(0x60, cd_ptr), ver_storage)
      /// Store version is_init location in calldata
      mstore(add(0x80, cd_ptr), mload(add(0x60, ver_init)))
      /// Store version function list location in calldata
      mstore(add(0xa0, cd_ptr), mload(add(0x80, ver_init)))
      /// Call Abstract Storage with calldata, and store return in cd_ptr in corresponding locations
      let ret := staticcall(gas, mload(add(0x40, ver_init)), sig_ptr, 0xc4, cd_ptr, 0xc0)
      /// Read return value: if zero, read failed - revert
      if iszero(ret) {
        revert (0, 0)
      }
      /// Check returned app storage - if zero, app does not exist - revert
      if iszero(mload(add(0x40, cd_ptr))) {
        revert (0, 0)
      }
      /// Check returned ver storage - if zero, version does not exist - revert
      if iszero(mload(add(0x60, cd_ptr))) {
        revert (0, 0)
      }
      /// Check version is_init location - if nonzero, version has already been initialized - revert
      if iszero(iszero(mload(add(0x80, cd_ptr)))) {
        revert (0, 0)
      }
      /// Get version function list length
      num_functions := mload(add(0xa0, cd_ptr))
      /// Check number of functions - if zero, no functions have been registered - revert
      if iszero(num_functions) {
        revert (0, 0)
      }

      // 2. Application and version exist, and version is ready to be initialized -
      /// Construct "write" calldata
      mstore(sig_ptr, mload(ver_init))
      /// Place location (ver is_init location) in calldata
      mstore(cd_ptr, mload(add(0x60, ver_init)))
      /// Place data (is_init = true) in calldata
      mstore(add(0x20, cd_ptr), 1)
      /// Call Abstract Storage with calldata
      ret := call(gas, mload(add(0x40, ver_init)), 0, sig_ptr, 0x44, cd_ptr, 0x20)
      /// Read return value: if zero, write failed - revert
      if iszero(ret) {
        revert (0, 0)
      }
    }
  }
}
