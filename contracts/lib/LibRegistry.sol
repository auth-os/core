pragma solidity ^0.4.23;

/* import "./LibEvents.sol"; */
import "./LibStorage.sol";

library LibRegistry {

  enum Classes {
    INVALID, NONE, PROVIDER, PROVIDER_APP_LIST, APPLICATION
  }

  /// EVENT TOPICS ///

  // event AppRegistered(bytes32 indexed execution_id, bytes32 indexed provider_id, bytes32 app_name);
  bytes32 internal constant APP_REGISTERED = keccak256("AppRegistered(bytes32,bytes32,bytes32)");

  /// STORAGE SEEDS ///

  // Provider namespace - base storage location for providers. When hashed with a provider id,
  // is the location of the provider's registered app list
  bytes32 internal constant PROVIDERS = keccak256("registry_providers");

  // App namespace - base storage location for apps. When hashed with a provider's base storage
  // location, is the base storage location of an app registered by that provider
  bytes32 internal constant APPS = keccak256("apps");
  // App description storage - when hashed with an app's base storage location, is the storage
  // location where an app's description is stored
  bytes32 internal constant APP_DESC = keccak256("app_desc");
  // App default storage address - when hashed with an app's base storage location, is the storage
  // location where an app's recommended storage address is located
  bytes32 internal constant APP_STORAGE_IMPL = keccak256("app_storage_impl");

  bytes32 internal constant APP_VERSIONS_LIST = keccak256("app_versions_list");

  function provider(Context.Ctx memory _ctx) internal pure returns (Virtual.Struct memory) {
    if (_ctx.exec_id == bytes32(0) || _ctx.sender == bytes32(0))
      Errors.except('Error at LibRegistry.provider: invalid context');

    return Virtual.Struct({
      base_storage: keccak256(_ctx.sender, PROVIDERS),
      context: _ctx,
      class: uint(Classes.PROVIDER)
    });
  }

  function provider_app_list(Virtual.Struct memory _provider) internal pure returns (Virtual.Array memory) {
    if (_provider.class != uint(Classes.PROVIDER))
      Errors.except('Error at LibRegistry.provider_app_list: invalid class');

    return Virtual.Array({
      base_storage: keccak256(PROVIDER_APP_LIST, _provider.base_storage),
      context: _provider.context,
      class: uint(Classes.APP_LIST)
    });
  }

  function provider_application(Virtual.Struct memory _provider, bytes32 _app_name) internal pure returns (Virtual.Struct memory) {
    if (_provider.class != uint(Classes.PROVIDER))
      Errors.except('Error at LibRegistry.provider_application: invalid class');

    return Virtual.Struct({
      base_storage: keccak256(keccak256(_app_name, APPS), _provider.base_storage),
      context: _provider.context,
      class: uint(Classes.APPLICATION)
    });
  }

  function app_name(Virtual.Struct memory _app) internal pure returns (Virtual.Bytes32 memory) {
    if (_app.class != uint(Classes.APPLICATION))
      Errors.except('Error at LibRegistry.app_name: invalid class');

    return Virtual.Bytes32({
      base_storage: _app.base_storage,
      context: _app.context,
      value: bytes32(0)
    });
  }

  function app_description(Virtual.Struct memory _app) internal pure returns (Virtual.Bytes memory) {
    if (_app.class != uint(Classes.APPLICATION))
      Errors.except('Error at LibRegistry.app_description: invalid class');

    return Virtual.Bytes({
      base_storage: keccak256(APP_DESC, _app.base_storage),
      context: _app.context,
      value: ''
    });
  }

  function app_default_storage(Virtual.Struct memory _app) internal pure returns (Virtual.Address memory) {
    if (_app.class != uint(Classes.APPLICATION))
      Errors.except('Error at LibRegistry.app_default_storage: invalid class');

    return Virtual.Address({
      base_storage: keccak256(APP_STORAGE_IMPL, _app.base_storage),
      context: _app.context,
      value: address(0)
    });
  }

  function app_version_list(Virtual.Struct memory _app) internal pure returns (Virtual.Array memory) {
    if (_app.class != uint(Classes.APPLICATION))
      Errors.except('Error at LibRegistry.app_version_list: invalid class');

    return Virtual.Array({
      base_storage: keccak256(APP_VERSIONS_LIST, _app.base_storage),
      context: _app.context,
      class: uint(Classes.VERSION_LIST)
    });
  }

  /* bytes32 internal constant VERSIONS = keccak256("versions");

  bytes32 internal constant VER_DESC = keccak256("ver_desc");

  bytes32 internal constant VER_STORAGE_IMPL = keccak256("ver_storage_impl");

  bytes32 internal constant VER_INIT_ADDR = keccak256("ver_init_addr");

  bytes32 internal constant VER_INIT_SIG = keccak256("ver_init_signature");

  bytes32 internal constant VER_IS_FINALIZED = keccak256("ver_is_finalized");

  bytes32 internal constant VER_FUNCTION_LIST = keccak256("ver_functions_list");

  bytes32 internal constant VER_FUNCTION_ADDRESSES = keccak256("ver_function_addrs");

  function application_version(Virtual.Struct memory _app, bytes32 _version_name) internal pure returns (Virtual.Struct memory) {
    if (_app.class != Classes.APPLICATION)
      Errors.except('Error at LibRegistry.application_version: invalid class');

    return Virtual.Struct({
      base_storage: keccak256(keccak256(_version_name, VERSIONS), _app.base_storage),
      context: _app.context,
      class: Classes.VERSION
    });
  }

  function version_name(Virtual.Struct memory _version) internal pure returns (Virtual.Bytes32 memory) {
    if (_version.class != Classes.VERSION)
      Errors.except('Error at LibRegistry.version_name: invalid class');

    return Virtual.Bytes32({
      base_storage: _version.base_storage,
      context: _version.context,
      value: bytes32(0)
    });
  }

  function version_description(Virtual.Struct memory _version) internal pure returns (Virtual.Bytes memory) {
    if (_version.class != Classes.VERSION)
      Errors.except('Error at LibRegistry.version_description: invalid class');

    return Virtual.Bytes({
      base_storage: keccak256(VER_DESC, _version.base_storage),
      context: _version.context,
      value: ''
    });
  }

  function version_default_storage(Virtual.Struct memory _version) internal pure returns (Virtual.Address memory) {
    if (_version.class != Classes.VERSION)
      Errors.except('Error at LibRegistry.version_default_storage: invalid class');

    return Virtual.Address({
      base_storage: keccak256(VER_STORAGE_IMPL, _version.base_storage),
      context: _version.context,
      value: address(0)
    });
  }

  function version_init_address(Virtual.Struct memory _version) internal pure returns (Virtual.Address memory) {
    if (_version.class != Classes.VERSION)
      Errors.except('Error at LibRegistry.version_init_address: invalid class');

    return Virtual.Address({
      base_storage: keccak256(VER_INIT_ADDR, _version.base_storage),
      context: _version.context,
      value: address(0)
    });
  }

  function version_init_sig(Virtual.Struct memory _version) internal pure returns (Virtual.Bytes4 memory) {
    if (_version.class != Classes.VERSION)
      Errors.except('Error at LibRegistry.version_init_sig: invalid class');

    return Virtual.Bytes4({
      base_storage: keccak256(VER_INIT_SIG, _version.base_storage),
      context: _version.context,
      value: bytes4(0)
    });
  }

  function version_is_stable(Virtual.Struct memory _version) internal pure returns (Virtual.Bool memory) {
    if (_version.class != Classes.VERSION)
      Errors.except('Error at LibRegistry.version_is_stable: invalid class');

    return Virtual.Bool({
      base_storage: keccak256(VER_IS_FINALIZED, _version.base_storage),
      context: _version.context,
      value: false
    });
  }

  function version_function_list(Virtual.Struct memory _version) internal pure returns (Virtual.Array memory) {
    if (_version.class != Classes.VERSION)
      Errors.except('Error at LibRegistry.version_function_list: invalid class');

    return Virtual.Array({
      base_storage: keccak256(VER_FUNCTION_LIST, _version.base_storage),
      context: _version.context,
      class: Classes.FUNC_LIST
    });
  }

  function version_address_list(Virtual.Struct memory _version) internal pure returns (Virtual.Array memory) {
    if (_version.class != Classes.VERSION)
      Errors.except('Error at LibRegistry.version_address_list: invalid class');

    return Virtual.Array({
      base_storage: keccak256(VER_FUNCTION_ADDRESSES, _version.base_storage),
      context: _version.context,
      class: Classes.IMPL_LIST
    });
  } */
}
