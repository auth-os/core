pragma solidity ^0.4.23;

import '../core/ScriptExec.sol';


contract RegistryExec is ScriptExec {

  /// FUNCTION SELECTORS ///

  // Function selector for zero-arg application initializer
  bytes4 internal constant DEFAULT_INIT = bytes4(keccak256(("init()")));

  // Function selector for app console "registerApp"
  bytes4 internal constant REGISTER_APP = bytes4(keccak256("registerApp(bytes32,address,bytes,bytes)"));

  // Function selector for version console "registerVersion"
  bytes4 internal constant REGISTER_VERSION = bytes4(keccak256("registerVersion(bytes32,bytes32,address,bytes,bytes)"));

  // Function selector for implementation console "addFunctions"
  bytes4 internal constant ADD_FUNCTIONS = bytes4(keccak256("addFunctions(bytes32,bytes32,bytes4[],address[],bytes)"));

  // Function selector for version console "finalizeVersion"
  bytes4 internal constant FINALIZE_VERSION = bytes4(keccak256("finalizeVersion(bytes32,bytes32,address,bytes4,bytes,bytes)"));

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

  constructor(address _exec_admin, address _update_source, address _registry_storage, bytes32 _app_provider) 
    ScriptExec(_exec_admin, _update_source, _registry_storage, _app_provider) public 
  {}

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

    if (default_registry_exec_id == bytes32(0)) {
      default_registry_exec_id = exec_id;
    }

    require(exec_id != bytes32(0));
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
    bytes memory _ctx = buildContext(_registry_exec_id, bytes32(msg.sender), 0);

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
    }
  }

  function registerVersion(bytes32 _app_name, bytes32 _version_name, address _version_storage, bytes memory _version_description) public onlyAdmin() {
    require(_app_name != bytes32(0) && _version_name != bytes32(0) && _version_description.length != 0);
    require(default_storage != address(0) && default_registry_exec_id != bytes32(0) && default_provider != bytes32(0) && default_updater != address(0));

    address __version_storage = _version_storage;
    if (__version_storage == address(0)) {
      __version_storage = default_storage;
    }

    bytes4 _registry_exec_sel = APP_EXEC;
    bytes4 _register_version_sel = REGISTER_VERSION;

    address _registry_storage = default_storage;
    address _version_console = registries[default_registry_exec_id].version_console;
    require(_version_console != address(0));

    bytes32 _registry_exec_id = default_registry_exec_id;
    bytes memory _ctx = buildContext(default_registry_exec_id, bytes32(msg.sender), 0);

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
      mstore(add(0xc8, _ptr), __version_storage)

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
    }
  }

  function finalizeVersion(bytes32 _app_name, bytes32 _version_name, address _app_init, bytes4 _app_init_sel, bytes memory _app_init_desc) public onlyAdmin() {
    require(_app_name != bytes32(0) && _version_name != bytes32(0) && _app_init != address(0));
    require(default_storage != address(0) && default_registry_exec_id != bytes32(0) && default_provider != bytes32(0));

    bytes4 _registry_exec_sel = APP_EXEC;
    bytes4 _finalize_version_sel = FINALIZE_VERSION;

    address _registry_storage = default_storage;
    address _version_console = registries[default_registry_exec_id].version_console;
    require(_version_console != address(0));

    bytes32 _registry_exec_id = default_registry_exec_id;
    bytes memory _ctx = buildContext(default_registry_exec_id, bytes32(msg.sender), 0);

    assembly {
      let _normalized_desc_len := mload(_app_init_desc)
      if gt(mod(_normalized_desc_len, 0x20), 0) {
        _normalized_desc_len := sub(add(_normalized_desc_len, 0x20), mod(_normalized_desc_len, 0x20))
      }

      let _ptr_length := sub(add(add(0x168, add(0x20, _normalized_desc_len)), 0x80), 0x04)
      let _ptr := mload(0x40)
      mstore(_ptr, _registry_exec_sel)
      mstore(add(0x04, _ptr), _version_console)
      mstore(add(0x24, _ptr), _registry_exec_id)
      mstore(add(0x44, _ptr), 0x60) // data read offset
      mstore(add(0x64, _ptr), add(0x164, _normalized_desc_len))

      mstore(add(0x84, _ptr), _finalize_version_sel)  // finalizeVersion()
      mstore(add(0x88, _ptr), _app_name)              // app name
      mstore(add(0xa8, _ptr), _version_name)          // version name
      mstore(add(0xc8, _ptr), _app_init)              // app initializer

      // add _app_init_calldata to calldata
      mstore(add(0xe8, _ptr), _app_init_sel)

      // setup data read offsets...
      mstore(add(0x108, _ptr), 0xc0)
      mstore(add(0x128, _ptr), add(0xe0, _normalized_desc_len))

      // add _app_init_desc to calldata
      mstore(add(0x148, _ptr), mload(_app_init_desc))
      let _offset := 0x0
      for { } lt(_offset, _normalized_desc_len) { _offset := add(0x20, _offset) } {
        mstore(add(add(0x168, _ptr), _offset), mload(add(0x20, add(_offset, _app_init_desc))))
      }

      // add _ctx to calldata
      mstore(add(add(0x168, _ptr), _offset), 0x60)
      mstore(add(0x20, add(add(0x168, _ptr), _offset)), mload(add(0x20, _ctx)))
      mstore(add(0x40, add(add(0x168, _ptr), _offset)), mload(add(0x40, _ctx)))
      mstore(add(0x60, add(add(0x168, _ptr), _offset)), mload(add(0x60, _ctx)))

      let _ret := call(gas, _registry_storage, 0, _ptr, _ptr_length, 0x0, 0x0)
      if iszero(_ret) { revert (0, 0) }
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
    bytes memory _ctx = buildContext(default_registry_exec_id, bytes32(msg.sender), 0);

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
    }
  }

  function buildContext(bytes32 _exec_id, bytes32 _provider, uint _val) internal pure returns (bytes memory _ctx) {
    _ctx = new bytes(96);
    assembly {
      mstore(add(0x20, _ctx), _exec_id)
      mstore(add(0x40, _ctx), _provider)
      mstore(add(0x60, _ctx), _val)
    }
  }
}
