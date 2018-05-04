pragma solidity ^0.4.21;

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

  // Function selector for registry 'getAppInitInfo' - returns information necessary to initialization
  bytes4 public constant GET_INIT_INFO = bytes4(keccak256("getAppInitInfo(bytes32,bytes32,bytes32)"));

  // Function selector for application storage 'initAndFinalize' - registers an application and returns a unique execution id
  bytes4 public constant INIT_APP = bytes4(keccak256("initAndFinalize(address,bool,address,bytes,address[])"));

  // Function selector for app storage "exec" - verifies sender and target address, then executes application
  bytes4 public constant APP_EXEC = bytes4(keccak256("exec(address,bytes32,bytes)"));

  // Function selector for app storage "getExecAllowed" - retrieves the allowed addresses for a given application instance
  bytes4 public constant GET_ALLOWED = bytes4(keccak256("getExecAllowed(bytes32)"));

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
  constructor(address _update_source, address _registry_storage, bytes32 _app_provider_id) public {
    exec_admin = msg.sender;
    default_updater = _update_source;
    default_storage = _registry_storage;
    default_provider = _app_provider_id;
  }

  // Payable function - for abstract storage refunds
  function () public payable {
  }

  /// REGISTRY BOOTSTRAP ///

  function initRegistryWithCalldata(bytes _calldata) public onlyAdmin() returns (bytes32 exec_id) {
    require(default_storage != address(0) && default_updater != address(0));
    require(default_storage.call(_calldata));
    assembly {
      if eq(returndatasize, 0x20) {
        returndatacopy(0x0, 0x0, 0x20)
        exec_id := mload(0x0)
      }
    }
    default_registry_exec_id = exec_id;
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
  @return failed: Whether execution failed or not
  @return returned_data: Data returned from app storage
  */
  function exec(address _target, bytes _app_calldata) public payable returns (bool failed, bytes returned_data) {
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
    assembly {
      returned_data := add(0x20, msize)
      mstore(returned_data, returndatasize)
      returndatacopy(add(0x20, returned_data), 0, returndatasize)
      // If first 32 bytes of returned data are 0, and returndatasize is nonzero call failed
      if gt(returndatasize, 0x20) {
        if iszero(mload(add(0x20, returned_data))) {
          failed := 1
        }
      }
    }
    // If execution failed, emit event
    if (failed)
      emit StorageException(default_storage, exec_id, msg.sender, msg.value);

    // Transfer any returned wei back to the sender
    address(msg.sender).transfer(address(this).balance);
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
  @return app_storage: The storage address of the application - pulled from default_registry
  @return ver_name: The name of the most recent stable version of the application, which was used to register this app instance
  @return exec_id: The execution id (within the application's storage) of the created application instance
  */
  function initAppInstance(bytes32 _app, bool _is_payable, bytes _init_calldata) public returns (address app_storage, bytes32 ver_name, bytes32 app_exec_id) {
    // Ensure valid input
    require(_app != bytes32(0) && _init_calldata.length != 0);

    // Create struct in memory to hold values
    AppInit memory init_info = AppInit({
      get_init: GET_INIT_INFO,
      init_app: INIT_APP,
      registry_addr: default_storage,
      exec_id: default_registry_exec_id,
      provider: default_provider,
      updater: default_updater
    });

    assembly {
      // Call RegistryStorage.getAppInitInfo -

      // Get pointer for calldata
      let ptr := mload(0x40)
      // Store function selector, default registry exec id, default provider, and app name in calldata
      mstore(ptr, mload(init_info))
      mstore(add(0x04, ptr), mload(add(0x60, init_info)))
      mstore(add(0x24, ptr), mload(add(0x80, init_info)))
      mstore(add(0x44, ptr), _app)

      // Read app init info from registry storage
      let ret := staticcall(gas, mload(add(0x40, init_info)), ptr, 0x64, 0, 0)
      if iszero(ret) { revert (0, 0) }

      // Get returned app init info, and call application storage 'initAndFinalize' -

      // Copy returned payable status, storage address, version name, init address, and address array length to pointer
      // Returned data should also include a populated address[] of permissioned addresses, which will
      // be copied to calldata below
      returndatacopy(ptr, 0, 0xc0)

      // Get returned data -
      app_storage := mload(add(0x20, ptr))
      ver_name := mload(add(0x40, ptr))
      let app_init_addr := mload(add(0x60, ptr))
      let num_addrs := mload(add(0xa0, ptr))

      if iszero(app_storage) { revert (0, 0) }
      if iszero(ver_name) { revert (0, 0) }

      // Move pointer to free memory
      ptr := add(ptr, returndatasize)

      // Get init_calldata length, and normalize to 32-bytes
      let cd_len := mload(_init_calldata)
      if gt(mod(cd_len, 0x20), 0) {
        cd_len := sub(add(cd_len, 0x20), mod(cd_len, 0x20))
      }

      // Set up application storage 'initAndFinalize' call
      mstore(ptr, mload(add(0x20, init_info)))
      // Place updater address, payable status, app init address, init calldata, and allowed addresses in calldata
      mstore(add(0x04, ptr), mload(add(0xa0, init_info)))
      mstore(add(0x24, ptr), _is_payable)
      mstore(add(0x44, ptr), app_init_addr)
      // Get passed in init calldata, which will be forwarded to the application's init function
      mstore(add(0x64, ptr), 0xa0) // Data read offset - init calldata
      mstore(add(0x84, ptr), add(0xc0, cd_len)) // Data read offset - _allowed array
      calldatacopy(add(0xa4, ptr), 0x64, add(0x20, mload(_init_calldata)))
      // Get returned 'allowed' array list and add to calldata
      returndatacopy(add(add(0xc4, cd_len), ptr), 0xa0, sub(returndatasize, 0xa0))

      // Get total calldata size -
      // 0xe4 (args + length storage + offsets) + _init_calldata.length + 32 * allowed.length
      cd_len := add(0xe4, add(cd_len, mul(0x20, num_addrs)))

      // Initialize application and get returned unique app execution id -
      // Copy returned exec id to pointer
      ret := call(gas, app_storage, 0, ptr, cd_len, ptr, 0x20)
      if iszero(ret) { revert (0, 0) }
      // Get returned app_exec_id
      app_exec_id := mload(ptr)
    }
    // Emit event
    emit AppInstanceCreated(msg.sender, app_exec_id, app_storage, _app, ver_name);
    // Update sender's deployed instances
    deployed_apps[app_storage][app_exec_id] = AppInstance({
      deployer: msg.sender,
      app_name: _app,
      version_name: ver_name
    });
    exec_id_lists[app_storage].push(app_exec_id);
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
