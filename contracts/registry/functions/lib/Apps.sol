pragma solidity ^0.4.23;

import "../class/Registry.sol";

library Apps {

  using Registry for Contract.Class;
  using Providers for Contract.Feature;
  using Virtual for Virtual.Wrapper;

  // Application wrapper type -
  /* struct Application {
    Contract.Class registry;
    Contract.Feature self;
    Virtual.Word name;

    Virtual.Inherits provider;
    Virtual.Feature self; // Reference to the application's base storage location and exec id
    Virtual.Word name; // Reference to the application's name
    Virtual.Address storage_addr; // Reference to the application's default storage address
    Virtual.Words description; // Reference to the application's description
    Virtual.List version_list; // Reference to the application's version list
  } */

  function name(Contract.Feature memory _app) internal pure returns (Contract.Field memory) {

  }

  /*
  Initialize an Application Feature. The application must already exist in storage,
  and initialization of fields is disallowed. However, fields may be updated.

  @param _app: The feature to intialize
  @param _app_name: The name of an existing application
  @param _context: The execution context containing the provider that registered the app
  */
  function initExisting(Contract.Feature memory _app, bytes32 _app_name, bytes memory _context) internal pure {

  }

  /// Storage seeds

  // App base storage seed
  bytes32 internal constant APPS = keccak256("apps");
  // App description storage seed
  bytes32 internal constant APP_DESC = keccak256("app_desc");
  // App default storage address storage seed
  bytes32 internal constant APP_STORAGE_IMPL = keccak256("app_storage_impl");
  // App version list storage seed
  bytes32 internal constant APP_VERSIONS_LIST = keccak256("app_versions_list");

  /// Storage location resolution functions

  // An app's name is stored at the app's own base storage location
  function _name(Virtual.Wrapper memory _app) internal pure returns (bytes32) {
    return _app.base();
  }

  // An app's default storage address is stored at the hash of APP_STORAGE_IMPL
  // and the app's base storage location
  function _storage_addr(Virtual.Wrapper memory _app) internal pure returns (bytes32) {
    return keccak256(APP_STORAGE_IMPL, _app.base());
  }

  // An app's version list is stored at the hash of APP_VERSIONS_LIST and
  // the app's base storage location
  function _version_list(Virtual.Wrapper memory _app) internal pure returns (bytes32) {
    return keccak256(APP_VERSIONS_LIST, _app.base());
  }

  // An app's description is stored at the hash of APP_DESC and
  // the app's base storage location
  function _description(Virtual.Wrapper memory _app) internal pure returns (bytes32) {
    return keccak256(APP_DESC, _app.base());
  }

  /// Other functions

  // Returns the Application struct registered under the provider with the name _app_name
  function application(Providers.Provider memory _provider, bytes32 _app_name) internal pure returns (Application memory app) {
    // Create Application Wrapper pointer -
    // The base storage location hashes the app name with the APPS seed, as well as the
    // provider's base storage location
    app.self.initWrapper(
      keccak256(_app_name, APPS, _provider.self.base()),
      _provider.self.execID()
    );

    // Declare app fields in storage
    app.self.hasField(app.name, _name);
    app.self.hasField(app.storage_addr, _storage_addr);
    app.self.hasField(app.description, _description);
    app.self.hasField(app.version_list, _version_list);
  }
}
