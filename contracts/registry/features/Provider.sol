pragma solidity ^0.4.23;

import '../../core/Contract.sol';

library Provider {

  using Contract for *;

  // Returns the location of a provider's list of registered applications in storage
  function registeredApps() internal pure returns (bytes32)
    { return keccak256(bytes32(Contract.sender()), 'app_list'); }

  // Returns the location of a registered app's name under a provider
  function appBase(bytes32 _app) internal pure returns (bytes32)
    { return keccak256(_app, keccak256(bytes32(Contract.sender()), 'app_base')); }

  // Returns the location of an app's list of versions
  function appVersionList(bytes32 _app) internal pure returns (bytes32)
    { return keccak256('versions', appBase(_app)); }

  // Returns the location of a version's name
  function versionBase(bytes32 _app, bytes32 _version) internal pure returns (bytes32)
    { return keccak256(_version, 'version', appBase(_app)); }

  // Returns the location of a registered app's index address under a provider
  function versionIndex(bytes32 _app, bytes32 _version) internal pure returns (bytes32)
    { return keccak256('index', versionBase(_app, _version)); }

  // Returns the location of an app's function selectors, registered under a provider
  function versionSelectors(bytes32 _app, bytes32 _version) internal pure returns (bytes32)
    { return keccak256('selectors', versionBase(_app, _version)); }

  // Returns the location of an app's implementing addresses, registered under a provider
  function versionAddresses(bytes32 _app, bytes32 _version) internal pure returns (bytes32)
    { return keccak256('addresses', versionBase(_app, _version)); }

  // Returns the location of the version before the current version
  function previousVersion(bytes32 _app, bytes32 _version) internal pure returns (bytes32)
    { return keccak256("previous version", versionBase(_app, _version)); }

  // Returns storage location of appversion list at a specific index
  function appVersionListAt(bytes32 _app, uint _index) internal pure returns (bytes32)
    { return bytes32((32 * _index) + uint(appVersionList(_app))); }

  // Registers an application under a given name for the sender
  function registerApp(bytes32 _app, address _index, bytes4[] _selectors, address[] _implementations) external view {
    // Begin execution -
    Contract.authorize(msg.sender);

    // Throw if the name has already been registered
    if (Contract.read(appBase(_app)) != bytes32(0))
      revert("app is already registered");

    if (_selectors.length != _implementations.length || _selectors.length == 0)
      revert("invalid input arrays");

    // Start storing values
    Contract.storing();

    // Store the app name in the list of registered app names
    uint num_registered_apps = uint(Contract.read(registeredApps()));

    Contract.increase(registeredApps()).by(uint(1));

    Contract.set(
      bytes32(32 * (num_registered_apps + 1) + uint(registeredApps()))
    ).to(_app);

    // Store the app name at app_base
    Contract.set(appBase(_app)).to(_app);

    // Set the first version to this app
    Contract.set(versionBase(_app, _app)).to(_app);

    // Push the app to its own version list as the first version
    Contract.set(appVersionList(_app)).to(uint(1));

    Contract.set(
      bytes32(32 + uint(appVersionList(_app)))
    ).to(_app);

    // Sets app index
    Contract.set(versionIndex(_app, _app)).to(_index);

    // Loop over the passed-in selectors and addresses and store them each at
    // version_selectors/version_addresses, respectively
    Contract.set(versionSelectors(_app, _app)).to(_selectors.length);
    Contract.set(versionAddresses(_app, _app)).to(_implementations.length);
    for (uint i = 0; i < _selectors.length; i++) {
      Contract.set(bytes32(32 * (i + 1) + uint(versionSelectors(_app, _app)))).to(_selectors[i]);
      Contract.set(bytes32(32 * (i + 1) + uint(versionAddresses(_app, _app)))).to(_implementations[i]);
    }

    // Set previous version to 0
    Contract.set(previousVersion(_app, _app)).to(uint(0));

    // End execution and commit state changes to storage -
    Contract.commit();
  }

  function registerAppVersion(bytes32 _app, bytes32 _version, address _index, bytes4[] _selectors, address[] _implementations) external view {
    // Begin execution -
    Contract.authorize(msg.sender);

    // Throw if the app has not been registered
    // Throw if the version has already been registered (check app_base)
    if (Contract.read(appBase(_app)) == bytes32(0))
      revert("App has not been registered");

    if (Contract.read(versionBase(_app, _version)) != bytes32(0))
      revert("Version already exists");

    if (
      _selectors.length != _implementations.length ||
      _selectors.length == 0
    ) revert("Invalid input array lengths");

    // Begin storing values
    Contract.storing();

    // Store the version name at version_base
    Contract.set(versionBase(_app, _version)).to(_version);

    // Push the version to the app's version list
    uint num_versions = uint(Contract.read(appVersionList(_app)));
    Contract.set(appVersionListAt(_app, (num_versions + 1))).to(_version);
    Contract.set(appVersionList(_app)).to(num_versions + 1);

    // Store the index at version_index
    Contract.set(versionIndex(_app, _version)).to(_index);

    // Loop over the passed-in selectors and addresses and store them each at
    // version_selectors/version_addresses, respectively
    Contract.set(versionSelectors(_app, _version)).to(_selectors.length);
    Contract.set(versionAddresses(_app, _version)).to(_implementations.length);
    for (uint i = 0; i < _selectors.length; i++) {
      Contract.set(bytes32(32 * (i + 1) + uint(versionSelectors(_app, _version)))).to(_selectors[i]);
      Contract.set(bytes32(32 * (i + 1) + uint(versionAddresses(_app, _version)))).to(_implementations[i]);
    }

    // Set the version's previous version
    bytes32 prev_version = Contract.read(bytes32(32 * num_versions + uint(appVersionList(_app))));
    Contract.set(previousVersion(_app, _version)).to(prev_version);

    // End execution and commit state changes to storage -
    Contract.commit();
  }

  /// Storage Seeds ///

  // Storage seed for the application's index address
  bytes32 internal constant APP_IDX_ADDR = keccak256('index');
  // Storage seed for the executive permissions mapping
  bytes32 internal constant EXEC_PERMISSIONS = keccak256('script_exec_permissions');
  // Returns the true storage location of a seed in Abstract Storage
  function registryLocation(bytes32 seed, bytes32 registry_id) internal pure returns (bytes32) {
    return keccak256(seed, registry_id);
  }

  // Storage 
  function execPermissions(address _exec) internal pure returns (bytes32) { 
    return keccak256(_exec, EXEC_PERMISSIONS); 
  }

  // Storage seed for a function selector's implementation address 
  function appSelectors(bytes32 _selector) internal pure returns (bytes32) {
    return keccak256(_selector, 'implementation');
  }

  /// Update Functions ///

  // Updates this application's versioning information in AbstractStorage to allow upgrading to occur
  // @param - This application's name
  // @param - The registry id of this application
  // @param - The provider of this application
  function updateInstance(bytes32 _app_name, bytes32 _registry_id, address _provider) internal view {
    // Authorize the sender and set up the run-time memory of this application
    Contract.authorize(msg.sender);

    // Set up a storage buffer
    Contract.storing(); 

    // Ensure valid input -
    require(_app_name != 0 && _provider != 0 && _registry_id != 0, 'invalid input');

    bytes32 version = getLatestVersion(_app_name, _registry_id);

    // Ensure a valid version name for the update - 
    require(version != bytes32(0), 'Invalid version name');

    address index = getVersionIndex(_app_name,  version, _registry_id);
    bytes4[] storage selectors = getVersionSelectors(_app_name,  version, _registry_id); 
    address[] storage implementations = getVersionImplementations(_app_name,  version, _registry_id);

    // Ensure a valid index address for the update -
    require(index != address(0), 'Invalid index address');

    // Set this application's index address to equal the latest version's index
    Contract.set(APP_IDX_ADDR).to(index); 

    // Ensure a nonzero number of allowed selectors and implementing addresses -
    require(selectors.length == implementations.length && selectors.length != 0, 'Invalid implementation length');

    // Loop over implementing addresses, and map each function selector to its corresponding address for the new instance
    for (uint i = 0; i < selectors.length; i++) {
      require(selectors[i] != 0 && implementations[i] != 0, 'invalid input - expected nonzero implementation');
      Contract.set(appSelectors(selectors[i])).to(implementations[i]);
    }

    /// MIGHT WANT: Event emission signaling that the application has been upgraded

    // Commit the changes to the storage contract
    Contract.commit();
  }


  // Replaces the current Script Executor with a new address
  // @param - newExec: The replacement Script Executor
  function updateExec(address newExec) internal view {
    // Authorize the sender and set up the run-time memory of this application
    Contract.authorize(msg.sender);

    // Set up a storage buffer
    Contract.storing();

    require(newExec != address(0), 'invalid replacement');

    ///FIXME Set the Script Exec's mapping value in exec Permissions to false
    // Zero out the executive permissions value for this 
    Contract.set(execPermissions(msg.sender)).to(bytes32(0));

    // Set the new exec as the Script Executor
    Contract.set(execPermissions(newExec)).to(bytes32(1));

    /// MIGHT WANT: Event emission signaling that the application's Script Exec has been upgraded

    // Commit the changes to the storage contract
    Contract.commit();
  }

  /// Registry Getters /// 

  // Returns the latest version of an application
  function getLatestVersion(bytes32 _app, bytes32 registry_id) internal view returns (bytes32) {
    // Get a seed to the start of this app's version list 
    uint seed = uint(appVersionList(_app));
    // Get the length of the version list
    uint length = uint(registryRead(bytes32(seed), registry_id));
    // Calculate a seed to get the most recent version registered under this app
    seed = (32 * length) + seed;
    // Return the latest version of this application
    return registryRead(bytes32(seed), registry_id);
  }

  // Reads the address of the Idx contract of this application
  function getVersionIndex(bytes32 _app, bytes32 _version, bytes32 registry_id) internal view returns (address index) {
    index = address(registryRead(versionIndex(_app, _version), registry_id));
  }

  // Returns a storage pointer to a version's implementation list
  // @param - _provider: The version's provider
  // @param - _app: The application name 
  // @param - _version: The version name 
  // @returns - The implementations list for the specified version
  function getVersionImplementations(bytes32 _app, bytes32 _version, bytes32 registry_id) internal pure 
  returns (address[] storage) {
    function (bytes32) internal pure returns (address[] storage) get;
    assembly {
      get := implementations
    }
    return get(registryLocation(versionAddresses(_app, _version), registry_id));
  }

  // A helper function for getVersionImplementations that returns address[] storage 
  function implementations(address[] storage _implementations) internal pure returns (address[] storage) {
    return _implementations;
  }

  // Returns a storage pointer to a version's selector list
  // @param - _provider: The version's provider
  // @param - _app: The application name 
  // @param - _version: The version name 
  // @returns - The selectors list for the specified version
  function getVersionSelectors(bytes32 _app, bytes32 _version, bytes32 registry_id) internal pure 
  returns (bytes4[] storage) {
    function (bytes32) internal pure returns (bytes4[] storage) get;
    assembly {
      get := selectors
    }
    return get(registryLocation(versionSelectors(_app, _version), registry_id)); 
  }

  // A helper function for getVersionSelectors that returns bytes4[] storage 
  function selectors(bytes4[] storage _selectors) internal pure returns (bytes4[] storage) {
    return _selectors;
  }

  /// Helpers ///

  function registryRead(bytes32 location, bytes32 registry_id) internal view returns (bytes32 value) {
    location = keccak256(location, registry_id);
    assembly {
      value := sload(location)
    }
  }
}
