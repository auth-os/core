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

  // Function selector for registry 'getAppInitInfo' - returns information necessary to initialization
  bytes4 public constant GET_INIT_INFO = bytes4(keccak256("getAppInitInfo(bytes32,bytes32,bytes32)"));

  // Function selector for zero-arg application initializer
  bytes4 public constant DEFAULT_INIT = bytes4(keccak256(("init()")));

  // Function selector for application storage 'initAndFinalize' - registers an application and returns a unique execution id
  bytes4 public constant INIT_APP = bytes4(keccak256("initAndFinalize(address,bool,address,bytes,address[])"));

  // Function selector for app storage "exec" - verifies sender and target address, then executes application
  bytes4 public constant APP_EXEC = bytes4(keccak256("exec(address,bytes32,bytes)"));

  // Function selector for app console "registerApp"
  bytes4 public constant REGISTER_APP = bytes4(keccak256("registerApp(bytes32,address,bytes,bytes)"));

  // Function selector for version console "registerVersion"
  bytes4 public constant REGISTER_VERSION = bytes4(keccak256("registerVersion(bytes32,bytes32,address,bytes,bytes)"));

  // Function selector for implementation console "addFunctions"
  bytes4 public constant ADD_FUNCTIONS = bytes4(keccak256("addFunctions(bytes32,bytes32,bytes4[],address[],bytes)"));

  // Function selector for version console "finalizeVersion"
  bytes4 public constant FINALIZE_VERSION = bytes4(keccak256("finalizeVersion(bytes32,bytes32,address,bytes4,bytes,bytes)"));

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

  /// REGISTRIES ///

  struct Registry {
    address init;
    address app_console;
    address version_console;
    address implementation_console;
    bytes32 exec_id;
    // TODO: consider adding additional registry meta, such as name, github repo etc
  }

  // Map of execution ids to registry metadata
  mapping (bytes32 => Registry) public registries;

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

  function initRegistry(address _init, address _app_console, address _version_console, address _impl_console) public onlyAdmin() returns (bytes32 exec_id) {
    require(_init != address(0) && _app_console != address(0) && _version_console != address(0) && _impl_console != address(0));
    require(default_storage != address(0) && default_updater != address(0));

    bytes4 _init_sel = INIT_APP;
    bytes4 _registry_init_sel = DEFAULT_INIT;

    address _registry_storage = default_storage;
    address _registry_updater = default_updater;

    address[3] memory _allowed = [_app_console, _version_console, _impl_console];

    assembly {
      let _ptr := mload(0x40)
      mstore(_ptr, _init_sel)
      mstore(add(0x04, _ptr), _registry_updater)
      mstore(add(0x24, _ptr), 0x0)
      mstore(add(0x44, _ptr), _init)

      // setup data read offsets...
      mstore(add(0x64, _ptr), 0xa0)
      mstore(add(0x84, _ptr), 0xe0)

      mstore(add(0xa4, _ptr), 0x04)
      mstore(add(0xc4, _ptr), _registry_init_sel)

      mstore(add(0xe4, _ptr), 0x03)

      let _offset := 0x0
      for { } lt(_offset, 0x60) { _offset := add(0x20, _offset) } {
        mstore(add(add(0x104, _offset), _ptr), mload(add(_offset, _allowed)))
      }

      let _ret := call(gas, _registry_storage, 0, _ptr, add(0x104, _offset), _ptr, 0x20)
      if iszero(_ret) { revert (0, 0) }
      exec_id := mload(_ptr)
    }

    require(exec_id != bytes32(0));
    default_registry_exec_id = exec_id;  // FIXME-- should this always happen? or only if previously unset?

    registries[exec_id] = Registry({
      exec_id: exec_id,
      init: _init,
      app_console: _app_console,
      version_console: _version_console,
      implementation_console: _impl_console
    });
  }

  function registerApp(bytes32 _app_name, bytes memory _app_description) public onlyAdmin() {
    require(_app_name != bytes32(0) && _app_description.length != 0);
    require(default_storage != address(0) && default_registry_exec_id != bytes32(0) && default_provider != bytes32(0) && default_updater != address(0));

    bytes4 _registry_exec_sel = APP_EXEC;
    bytes4 _register_app_sel = REGISTER_APP;

    address _registry_storage = default_storage;
    address _app_console = registries[default_registry_exec_id].app_console;
    require(_app_console != address(0));

    bytes32 _registry_exec_id = default_registry_exec_id;
    bytes memory _ctx = buildContext(_registry_exec_id, default_provider, 0);

    assembly {
      let _normalized_desc_len := mload(_app_description)
      if gt(mod(_normalized_desc_len, 0x20), 0) {
        _normalized_desc_len := sub(add(_normalized_desc_len, 0x20), mod(_normalized_desc_len, 0x20))
      }

      let _ptr_length := sub(add(add(0x128, add(0x20, _normalized_desc_len)), 0x80), 0x04)
      let _ptr := mload(0x40)
      mstore(_ptr, _registry_exec_sel)
      mstore(add(0x04, _ptr), _app_console)
      mstore(add(0x24, _ptr), _registry_exec_id)
      mstore(add(0x44, _ptr), 0x60) // data read offset
      mstore(add(0x64, _ptr), add(0x124, _normalized_desc_len))

      mstore(add(0x84, _ptr), _register_app_sel)  // registerApp()
      mstore(add(0x88, _ptr), _app_name)          // app name
      mstore(add(0xa8, _ptr), _registry_storage)  // app storage
      
      // setup data read offsets...
      mstore(add(0xc8, _ptr), 0x80)
      mstore(add(0xe8, _ptr), add(0xa0, _normalized_desc_len))

      // add _app_description to calldata
      mstore(add(0x108, _ptr), mload(_app_description))
      let _offset := 0x0
      for { } lt(_offset, _normalized_desc_len) { _offset := add(0x20, _offset) } {
        mstore(add(0x128, add(_offset, _ptr)), mload(add(0x20, add(_offset, _app_description))))
      }

      // add _ctx to calldata
      mstore(add(0x128, add(_offset, _ptr)), 0x60)
      mstore(add(0x20, add(0x128, add(_offset, _ptr))), mload(add(0x20, _ctx)))
      mstore(add(0x40, add(0x128, add(_offset, _ptr))), mload(add(0x40, _ctx)))
      mstore(add(0x60, add(0x128, add(_offset, _ptr))), mload(add(0x60, _ctx)))

      let _ret := call(gas, _registry_storage, 0, _ptr, _ptr_length, 0x0, 0x0)
      if iszero(_ret) { revert (0, 0) }

      log0(_ptr, _ptr_length)
    }
  }

  function registerVersion(bytes32 _app_name, bytes32 _version_name, address _version_storage, bytes memory _version_description) public onlyAdmin() {
    require(_app_name != bytes32(0) && _version_name != bytes32(0) && _version_description.length != 0);
    require(default_storage != address(0) && default_registry_exec_id != bytes32(0) && default_provider != bytes32(0) && default_updater != address(0));

    if (_version_storage == address(0)) {
      _version_storage = default_storage;
    }

    bytes4 _registry_exec_sel = APP_EXEC;
    bytes4 _register_version_sel = REGISTER_VERSION;

    address _registry_storage = default_storage;
    address _version_console = registries[default_registry_exec_id].version_console;
    require(_version_console != address(0));

    bytes32 _registry_exec_id = default_registry_exec_id;
    bytes memory _ctx = buildContext(default_registry_exec_id, default_provider, 0);

    assembly {
      let _normalized_desc_len := mload(_version_description)
      if gt(mod(_normalized_desc_len, 0x20), 0) {
        _normalized_desc_len := sub(add(_normalized_desc_len, 0x20), mod(_normalized_desc_len, 0x20))
      }

      let _ptr_length := sub(add(add(0x168, _normalized_desc_len), 0x80), 0x04)
      let _ptr := mload(0x40)
      mstore(_ptr, _registry_exec_sel)
      mstore(add(0x04, _ptr), _version_console)
      mstore(add(0x24, _ptr), _registry_exec_id)
      mstore(add(0x44, _ptr), 0x60)
      mstore(add(0x64, _ptr), add(0x144, _normalized_desc_len))

      mstore(add(0x84, _ptr), _register_version_sel)
      mstore(add(0x88, _ptr), _app_name)
      mstore(add(0xa8, _ptr), _version_name)
      mstore(add(0xc8, _ptr), _version_storage)

      // setup data read offsets...
      mstore(add(0xe8, _ptr), 0xa0)
      mstore(add(0x108, _ptr), add(0xc0, _normalized_desc_len))

      // add _version_description to calldata
      mstore(add(0x128, _ptr), mload(_version_description))
      let _offset := 0x0
      for { } lt(_offset, _normalized_desc_len) { _offset := add(0x20, _offset) } {
        mstore(add(0x148, add(_offset, _ptr)), mload(add(0x20, add(_offset, _version_description))))
      }

      // add _ctx to calldata
      mstore(add(0x148, add(_normalized_desc_len, _ptr)), 0x60)
      mstore(add(0x20, add(0x148, add(_normalized_desc_len, _ptr))), mload(add(0x20, _ctx)))
      mstore(add(0x40, add(0x148, add(_normalized_desc_len, _ptr))), mload(add(0x40, _ctx)))
      mstore(add(0x60, add(0x148, add(_normalized_desc_len, _ptr))), mload(add(0x60, _ctx)))

      let _ret := call(gas, _registry_storage, 0, _ptr, _ptr_length, 0x0, 0x0)
      if iszero(_ret) { revert (0, 0) }

      log0(_ptr, _ptr_length)
    }
  }

  function finalizeVersion(bytes32 _app_name, bytes32 _version_name, address _app_init, bytes memory _app_init_calldata, bytes memory _app_init_desc) public onlyAdmin() {
    require(_app_name != bytes32(0) && _version_name != bytes32(0) && _app_init != address(0) && _app_init_calldata.length != 0 && _app_init_desc.length != 0);
    require(default_storage != address(0) && default_registry_exec_id != bytes32(0) && default_provider != bytes32(0));

    bytes4 _registry_exec_sel = APP_EXEC;
    bytes4 _finalize_version_sel = FINALIZE_VERSION;

    address _registry_storage = default_storage;
    address _version_console = registries[default_registry_exec_id].version_console;
    require(_version_console != address(0));

    bytes32 _registry_exec_id = default_registry_exec_id;
    bytes memory _ctx = buildContext(default_registry_exec_id, default_provider, 0);

    assembly {
      let _normalized_calldata_len := mload(_app_init_calldata)
      if gt(mod(_normalized_calldata_len, 0x20), 0) {
        _normalized_calldata_len := sub(add(_normalized_calldata_len, 0x20), mod(_normalized_calldata_len, 0x20))
      }

      let _normalized_desc_len := mload(_app_init_desc)
      if gt(mod(_normalized_desc_len, 0x20), 0) {
        _normalized_desc_len := sub(add(_normalized_desc_len, 0x20), mod(_normalized_desc_len, 0x20))
      }

      let _ptr_length := sub(add(add(add(0x128, add(0x20, _normalized_calldata_len)), add(0x20, _normalized_desc_len)), 0x80), 0x04)
      let _ptr := mload(0x40)
      mstore(_ptr, _registry_exec_sel)
      mstore(add(0x04, _ptr), _version_console)
      mstore(add(0x24, _ptr), _registry_exec_id)
      mstore(add(0x44, _ptr), 0x60) // data read offset
      mstore(add(0x64, _ptr), add(0x144, add(_normalized_desc_len, _normalized_calldata_len)))

      mstore(add(0x84, _ptr), _finalize_version_sel)  // finalizeVersion()
      mstore(add(0x88, _ptr), _app_name)              // app name
      mstore(add(0xa8, _ptr), _version_name)          // version name
      mstore(add(0xc8, _ptr), _app_init)              // app initializer

      // add _app_init_calldata to calldata
      mstore(add(0xe8, _ptr), mload(_app_init_calldata))
      let _offset := 0x0
      for { } lt(_offset, _normalized_calldata_len) { _offset := add(0x20, _offset) } {
        mstore(add(0xe8, add(_offset, _ptr)), mload(add(0x20, add(_offset, _app_init_calldata))))
      }

      // setup data read offsets...
      mstore(add(0xe8, add(_normalized_calldata_len, _ptr)), 0xc0)
      mstore(add(0x108, add(_normalized_calldata_len, _ptr)), add(0xe0, _normalized_desc_len))

      // add _app_init_desc to calldata
      mstore(add(0x128, add(_normalized_calldata_len, _ptr)), mload(_app_init_desc))
      _offset := 0x0
      for { } lt(_offset, _normalized_desc_len) { _offset := add(0x20, _offset) } {
        mstore(add(add(0x148, add(_normalized_calldata_len, _ptr)), _offset), mload(add(0x20, add(_offset, _app_init_desc))))
      }

      // add _ctx to calldata
      mstore(add(add(0x148, add(_normalized_calldata_len, _ptr)), _offset), 0x60)
      mstore(add(0x20, add(add(0x148, add(_normalized_calldata_len, _ptr)), _offset)), mload(add(0x20, _ctx)))
      mstore(add(0x40, add(add(0x148, add(_normalized_calldata_len, _ptr)), _offset)), mload(add(0x40, _ctx)))
      mstore(add(0x60, add(add(0x148, add(_normalized_calldata_len, _ptr)), _offset)), mload(add(0x60, _ctx)))

      let _ret := call(gas, _registry_storage, 0, _ptr, _ptr_length, 0x0, 0x0)
      if iszero(_ret) { revert (0, 0) }

      log0(_ptr, _ptr_length)
    }
  }

  function addFunctions(bytes32 _app_name, bytes32 _version_name, bytes4[] memory _function_sigs, address[] memory _function_addrs) public onlyAdmin() {
    require(_app_name != bytes32(0) && _version_name != bytes32(0) && _function_sigs.length != 0 && _function_addrs.length != 0 && _function_sigs.length == _function_addrs.length);
    require(default_storage != address(0) && default_registry_exec_id != bytes32(0) && default_provider != bytes32(0));

    bytes4 _registry_exec_sel = APP_EXEC;
    bytes4 _add_functions_sel = ADD_FUNCTIONS;

    address _registry_storage = default_storage;
    address _impl_console = registries[default_registry_exec_id].implementation_console;
    require(_impl_console != address(0));

    bytes32 _registry_exec_id = default_registry_exec_id;
    bytes memory _ctx = buildContext(default_registry_exec_id, default_provider, 0);

    assembly {
      let _ptr_length := sub(add(add(add(0x148, add(0x20, mul(0x20, mload(_function_sigs)))), add(0x20, mul(0x20, mload(_function_addrs)))), 0x80), 0x04)
      let _ptr := mload(0x40)
      mstore(_ptr, _registry_exec_sel)
      mstore(add(0x04, _ptr), _impl_console)
      mstore(add(0x24, _ptr), _registry_exec_id)
      mstore(add(0x44, _ptr), 0x60) // data read offset
      mstore(add(0x64, _ptr), add(add(0x80, 0xe4), add(mul(0x20, mload(_function_sigs)), mul(0x20, mload(_function_addrs)))))

      mstore(add(0x84, _ptr), _add_functions_sel) // addFunctions()
      mstore(add(0x88, _ptr), _app_name)          // app name
      mstore(add(0xa8, _ptr), _version_name)      // version name

      // setup data read offsets...
      mstore(add(0xc8, _ptr), 0xa0)
      mstore(add(0xe8, _ptr), add(0xc0, mul(0x20, mload(_function_sigs))))
      mstore(add(0x108, _ptr), add(0xe0, add(mul(0x20, mload(_function_sigs)), mul(0x20, mload(_function_addrs)))))

      // add _function_sigs to calldata
      mstore(add(0x128, _ptr), mload(_function_sigs))
      let _offset := 0x0
      for { } lt(_offset, mul(0x20, mload(_function_sigs))) { _offset := add(0x20, _offset) } {
        mstore(add(add(0x20, 0x128), add(_offset, _ptr)), mload(add(0x20, add(_offset, _function_sigs))))
      }

      // add _function_addrs to calldata
      mstore(add(0x148, add(mul(0x20, mload(_function_sigs)), _ptr)), mload(_function_addrs))
      _offset := 0x0
      for { } lt(_offset, mul(0x20, mload(_function_addrs))) { _offset := add(0x20, _offset) } {
        mstore(add(add(0x20, add(0x148, mul(0x20, mload(_function_sigs)))), add(_offset, _ptr)), mload(add(0x20, add(_offset, _function_addrs))))
      }

      // add _ctx to calldata
      mstore(add(0x168, add(mul(0x20, mload(_function_sigs)), add(_offset, _ptr))), 0x60)
      mstore(add(0x20, add(0x168, add(mul(0x20, mload(_function_sigs)), add(_offset, _ptr)))), mload(add(0x20, _ctx)))
      mstore(add(0x40, add(0x168, add(mul(0x20, mload(_function_sigs)), add(_offset, _ptr)))), mload(add(0x40, _ctx)))
      mstore(add(0x60, add(0x168, add(mul(0x20, mload(_function_sigs)), add(_offset, _ptr)))), mload(add(0x60, _ctx)))

      let _ret := call(gas, _registry_storage, 0, _ptr, _ptr_length, 0x0, 0x0)
      if iszero(_ret) { revert (0, 0) }

      log0(_ptr, _ptr_length)
    }
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
      provider: keccak256(default_provider),
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
      app_exec_id := mload(ptr)
      if iszero(app_exec_id) { revert (0, 0) }
    }

    emit AppInstanceCreated(msg.sender, app_exec_id, app_storage, _app, ver_name);

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

  function buildContext(bytes32 _exec_id, bytes32 _provider, uint _val) internal pure returns (bytes memory _ctx) {
    bytes32 _provider_id = keccak256(_provider);
    _ctx = new bytes(96);
    assembly {
      mstore(add(0x20, _ctx), _exec_id)
      mstore(add(0x40, _ctx), _provider_id)
      mstore(add(0x60, _ctx), _val)
    }
  }

  // Parses payable app calldata and returns app exec id, sender address, and wei sent
  function parse(bytes _app_calldata) internal pure returns (bytes32 exec_id, bytes32 exec_as, uint wei_sent) {
    assembly {
      exec_id := mload(add(0x20, _app_calldata))
      exec_as := mload(add(0x40, _app_calldata))
      wei_sent := mload(add(0x60, _app_calldata))
    }
  }
}
