pragma solidity ^0.4.23;

import "../class/Registry.sol";

library AppConsole {

  /* using Contract for Contract.Task; */
  using Registry for Contract.Class;
  using Providers for Contract.Feature;
  using Apps for Contract.Feature;

  /*
  Registers an application under the sender's provider id

  @param _app_name: The name of the application to be registered
  @param _app_storage: The storage address this application will use
  @param _app_desc: The description of the application (recommended: GitHub link)
  @param _context: The execution context for this application - a 96-byte array containing (in order):
    1. Application execution id
    2. Original script sender (address, padded to 32 bytes)
    3. Wei amount sent with transaction to storage
  */
  function registerApp(bytes32 _app_name, address _app_storage, bytes _app_desc, bytes memory _context) public view {
    // Declare instances
    Contract.Class memory registry;
    Contract.Feature memory provider;
    Contract.Feature memory app; // will be initialized by the provider
    Contract.Task memory task;
    // Initialize registry class by passing in a reference to this contract's supported features -
    registry.initFeatures(Registry.supported, this.registerApp.selector);
    // Initialize provider through Registry class -
    registry.initProvider(provider, _context);
    // Create new application instance through provider -
    provider.initApplication(app, _app_name);
    // Initialize task and assign to provider -
    provider.createTask(task, Providers.Tasks.REGISTERAPP);

    // Begin task with stores action, checking pre-conditions -
    provider.start(task.stores);

    // Store app name in application name storage location -
    task.store(_app_name).at(app.name);
    // Store application default storage address -
    task.store(_app_storage).at(app.storage_addr);
    // Store application description -
    task.store(_app_desc).at(app.description);
    // Push app name to provider's registered application list -
    task.push(_app_name).to(provider.registered_apps);

    // Finish storing values and begin emitting values -
    provider.next(task.emits);

    // Emit AppRegistered event TODO add func
    task.log(provider.appRegisteredEvent).with(_app_name);

    // Finish emitting values and declare end of task -
    provider.finally(task.ends);

    // Finalize state and end execution -
    Registry.finalize(provider);
  }
}
