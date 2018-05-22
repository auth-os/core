pragma solidity ^0.4.23;

contract ScriptExec {

  /// DEFAULT APPLICATION SOURCES ///

  // Framework bootstrap method - admin is able to change executor script source and registry address
  address public exec_admin;

  // Framework bootstrap method - applications default to pulling application registry information from a single source
  address public default_storage;

  // Framework bootstrap method - applications default to allowing app updates from a single source
  address public default_updater;

  // Framework bootstrap method - applications default to pull information from a registry with this specified execution id
  bytes32 public default_registry_exec_id;

  // Framework bootstrap method - application init and implementation data is pulled from a single provider by default
  bytes32 public default_provider;

  // If the exec admin wants to suggest a new script exec contract to migrate to, this address is set to the new address
  address public new_script_exec;

  /// FUNCTION SELECTORS ///

  // Function selector for registry 'getAppLatestInfo' - returns information necessary for initialization
  bytes4 internal constant GET_LATEST_INFO = bytes4(keccak256("getAppLatestInfo(address,bytes32,bytes32,bytes32)"));

  // Function selector for abstract storage 'app_info' mapping - returns information on an exec id
  bytes4 internal constant GET_APP_INFO = bytes4(keccak256("app_info(bytes32)"));

  // Function selector for zero-arg application initializer
  bytes4 internal constant DEFAULT_INIT = bytes4(keccak256(("init()")));

  // Function selector for application storage 'initAndFinalize' - registers an application and returns a unique execution id
  bytes4 internal constant INIT_APP = bytes4(keccak256("initAndFinalize(address,bool,address,bytes,address[])"));

  // // Function selector for app storage "exec" - verifies sender and target address, then executes application
  bytes4 internal constant APP_EXEC = bytes4(keccak256("exec(address,bytes32,bytes)"));

  // Function selector for app storage "getExecAllowed" - retrieves the allowed addresses for a given application instance
  bytes4 internal constant GET_ALLOWED = bytes4(keccak256("getExecAllowed(bytes32)"));

  /// EVENTS ///

  // UPGRADING //

  event ApplicationMigration(address indexed storage_addr, bytes32 indexed exec_id, address new_exec_addr, address original_deployer);

  // EXCEPTION HANDLING //

  event StorageException(address indexed storage_addr, bytes32 indexed exec_id, address sender, uint wei_sent);
  event AppInstanceCreated(address indexed creator, bytes32 indexed exec_id, address storage_addr, bytes32 app_name, bytes32 version_name);

  struct AppInstance {
    address deployer;
    bytes32 app_name;
    bytes32 version_name;
  }

  struct ActiveInstance {
    bytes32 exec_id;
    bytes32 app_name;
    bytes32 version_name;
  }

  // Framework bootstrap method - keeps track of all deployed apps (through exec ids), and information on them
  // Maps app storage address -> app execution id -> AppInstance
  mapping (address => mapping (bytes32 => AppInstance)) public deployed_apps;
  mapping (address => bytes32[]) public exec_id_lists;

  // Maps a deployer to an array of applications they have deployed
  mapping (address => ActiveInstance[]) public deployer_instances;

  // Modifier - The sender must be the contract administrator
  modifier onlyAdmin() {
    require(msg.sender == exec_admin);
    _;
  }

  // Constructor - gives the sender administrative permissions and sets default registry and update sources
  constructor(address _exec_admin, address _update_source, address _registry_storage, bytes32 _app_provider_id) public {
    exec_admin = _exec_admin;
    default_updater = _update_source;
    default_storage = _registry_storage;
    default_provider = _app_provider_id;

    if (exec_admin == address(0)) {
      exec_admin = msg.sender;
    }
  }

  // Payable function - for abstract storage refunds
  function () public payable {
  }

  /// APPLICATION EXECUTION ///

  /*
  ** 2 pieces of information are needed to execute a function of an application
  ** instance - its storage address, and the unique execution id associated with
  ** it. Because this version of auth_os is in beta, this contract does not
  ** allow for app storage addresses outside of the set default, but does allow
  ** for this restriction to be removed in the future by setting the default to 0,
  ** or by using the registry's update functionality to migrate to a new script
  ** execution contract.
  */

  /*
  Executes an application using its execution id and storage address. For non-payable execution, specifies that all _app_calldata
  arrays must contain, in order, the app execution id, and the 32-byte padded sender's address. For payable execution, this should
  be followed by the value sent, in wei.

  @param _target: The target address, which houses the function being called
  @param _app_calldata: The calldata to forward to the application target address
  @return success: Whether execution succeeded or not
  @return returned_data: Data returned from app storage
  */
  function exec(address _target, bytes _app_calldata) public payable returns (bool success) {
    bytes32 exec_id;
    bytes32 exec_as;
    uint wei_sent;
    // Ensure execution id and provider make up the calldata's first 64 bytes, after the function selector
    // Ensure the next 32 bytes is equal to msg.value
    (exec_id, exec_as, wei_sent) = parse(_app_calldata);
    require(exec_as == bytes32(msg.sender) && wei_sent == msg.value);
    // Call target with calldata
    bytes memory calldata = abi.encodeWithSelector(APP_EXEC, _target, exec_id, _app_calldata);
    require(default_storage.call.value(msg.value)(calldata));

    // Get returned data
    success = checkReturn();
    // If execution failed, emit event
    if (!success)
      emit StorageException(default_storage, exec_id, msg.sender, msg.value);

    // Transfer any returned wei back to the sender
    address(msg.sender).transfer(address(this).balance);
  }

  function checkReturn() internal pure returns (bool success) {
    success = false;
    assembly {
      // returndata size must be 0x60 bytes
      if eq(returndatasize, 0x60) {
        // Copy returned data to pointer and check that at least one value is nonzero
        let ptr := mload(0x40)
        returndatacopy(ptr, 0, returndatasize)
        if iszero(iszero(mload(ptr))) { success := 1 }
        if iszero(iszero(mload(add(0x20, ptr)))) { success := 1 }
        if iszero(iszero(mload(add(0x40, ptr)))) { success := 1 }
      }
    }
    return success;
  }

  /// APPLICATION INITIALIZATION ///

  struct AppInit {
    bytes4 get_init;
    bytes4 init_app;
    address registry_addr;
    bytes32 exec_id;
    bytes32 provider;
    address updater;
  }

  /*
  Initializes an instance of an application. Uses default app provider, script registry, app updater,
  and script registry exec id to get app information. Uses latest app version by default.

  @param _app: The name of the application to initialize
  @param _is_payable: Whether the app will accept ether
  @param _init_calldata: Calldata to be forwarded to an application's initialization function
  @return ver_name: The name of the most recent stable version of the application, which was used to register this app instance
  @return exec_id: The execution id (within the application's storage) of the created application instance
  */
  function initAppInstance(bytes32 _app, bool _is_payable, bytes _init_calldata) public returns (bytes32 ver_name, bytes32 app_exec_id) {
    // Ensure valid input
    require(_app != bytes32(0) && _init_calldata.length != 0);

    address init_registry;

    // Get registry application information from storage
    require(default_storage.call(abi.encodeWithSelector(GET_APP_INFO, default_registry_exec_id)), "app_info call failed");
    // Get init address from returned data
    assembly {
      // Check returndatasize - should be 0xc0 bytes
      if iszero(eq(returndatasize, 0xc0)) { revert (0, 0) }
      // Grab the last 32 bytes of returndata
      returndatacopy(0, sub(returndatasize, 0x20), 0x20)
      // Get InitRegistry address
      init_registry := mload(0)
    }
    // Ensure a valid registry init address
    require(init_registry != address(0), "Invalid registry init address");

    bytes memory calldata = abi.encodeWithSelector(
      GET_LATEST_INFO, default_storage, default_registry_exec_id,
      default_provider, _app
    );

    address app_init;
    address[] memory app_allowed;

    // Get information on latest version of application from InitRegistry
    assembly {
      // Set up staticcall to library
      let ret := staticcall(gas, init_registry, add(0x20, calldata), mload(calldata), 0, 0)
      // Ensure success
      if iszero(ret) { revert (0, 0) }
      // Check returndatasize - should be at least 0xc0 bytes
      if lt(returndatasize, 0xc0) { revert (0, 0) }

      // Copy returned data to free memory
      let ptr := mload(0x40)
      // (omitting app storage address in copy)
      returndatacopy(ptr, 0x20, sub(returndatasize, 0x20))
      // Update free memory pointer
      // Get version name from returned data
      ver_name := mload(ptr)
      // Get application init address from returned data
      app_init := mload(add(0x20, ptr))
      // Get app allowed addresses from returned data
      app_allowed := add(0x60, ptr)
      mstore(0x40, add(returndatasize, app_allowed))
    }
    // Ensure valid app init address, version name, and allowed address array
    require(ver_name != bytes32(0) && app_init != address(0) && app_allowed.length != 0, "invalid version info returned");

    // Call AbstractStorage.initAndFinalize
    require(default_storage.call(abi.encodeWithSelector(
      INIT_APP, default_updater, _is_payable, app_init, _init_calldata, app_allowed
    )), "initAndFinalize call failed");
    // Get returned execution id from calldata
    assembly {
      // Returned data should be 0x20 bytes
      if iszero(eq(returndatasize, 0x20)) { revert (0, 0) }
      // Copy returned data to memory
      returndatacopy(0, 0, 0x20)
      // Get returned execution id
      app_exec_id := mload(0)
    }
    // Ensure valid returned execution id
    require(app_exec_id != bytes32(0), "invalid exec id returned");

    // Emit event
    emit AppInstanceCreated(msg.sender, app_exec_id, default_storage, _app, ver_name);

    deployed_apps[default_storage][app_exec_id] = AppInstance({
      deployer: msg.sender,
      app_name: _app,
      version_name: ver_name
    });

    exec_id_lists[default_storage].push(app_exec_id);

    deployer_instances[msg.sender].push(ActiveInstance({
      exec_id: app_exec_id,
      app_name: _app,
      version_name: ver_name
    }));
  }

  /// STORAGE GETTERS ///

  function getAppAllowed(bytes32 _exec_id) public view returns (address[] allowed) {
    address _storage = default_storage;
    // Place 'getExecAllowed' function selector in memory
    bytes4 exec_allowed = GET_ALLOWED;
    assembly {
      // Get pointer to free memory for calldata
      let ptr := mload(0x40)
      // Store function selector and exec id in calldata
      mstore(ptr, exec_allowed)
      mstore(add(0x04, ptr), _exec_id)
      // Read from storage
      let ret := staticcall(gas, _storage, ptr, 0x24, 0, 0)
      // Allocate space for return, and copy returned data
      allowed := add(0x20, msize)
      returndatacopy(allowed, 0x20, sub(returndatasize, 0x20))
    }
  }

  /// INSTANCE DEPLOYER ///

  // Allows the deployer of an application instance to migrate to a new script exec contract, if the exec admin has provided one to migrate to
  function migrateApplication(bytes32 _exec_id) public {
    // Ensure sender is the app deployer
    require(deployed_apps[default_storage][_exec_id].deployer == msg.sender);
    // Ensure new script exec address has been set
    require(new_script_exec != address(0));

    // Call abstract storage and migrate the exec id
    bytes4 change_selector = bytes4(keccak256("changeScriptExec(bytes32,address)"));
    require(default_storage.call(change_selector, _exec_id, new_script_exec));

    // Emit event
    emit ApplicationMigration(default_storage, _exec_id, new_script_exec, msg.sender);
  }

  /// ADMIN ///

  // Allows the admin to suggest a new script exec contract, which instance deployers can then migrate to
  function changeExec(address _new_exec) public onlyAdmin() {
    new_script_exec = _new_exec;
  }

  // Allows the admin to change the registry storage for application registry
  function changeStorage(address _new_storage) public onlyAdmin() {
    default_storage = _new_storage;
  }

  // Allows the admin to change the default update address for applications
  function changeUpdater(address _new_updater) public onlyAdmin() {
    default_updater = _new_updater;
  }

  // Allows the admin to transfer permissions to a new address
  function changeAdmin(address _new_admin) public onlyAdmin() {
    exec_admin = _new_admin;
  }

  // Allows the admin to change the default provider information to pull application implementation details from
  function changeProvider(bytes32 _new_provider) public onlyAdmin() {
    default_provider = _new_provider;
  }

  // Allows the admin to change the default execution id used to interact with the registry application
  function changeRegistryExecId(bytes32 _new_id) public onlyAdmin() {
    default_registry_exec_id = _new_id;
  }

  /// HELPERS ///

  // Parses payable app calldata and returns app exec id, sender address, and wei sent
  function parse(bytes _app_calldata) internal pure returns (bytes32 exec_id, bytes32 exec_as, uint wei_sent) {
    assembly {
      exec_id := mload(sub(add(_app_calldata, mload(_app_calldata)), 0x40))
      exec_as := mload(sub(add(_app_calldata, mload(_app_calldata)), 0x20))
      wei_sent := mload(add(_app_calldata, mload(_app_calldata)))
    }
  }
}
