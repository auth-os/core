pragma solidity ^0.4.23;

import '../../lib/LibRegistry.sol';

library AppConsole {

  using LibRegistry for *;
  using Pointers for *;
  /* using LibEvents for Pointers.ActionPtr; */
  using LibStorage for Pointers.ActionPtr;

  /// FUNCTIONS ///

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
    require(_app_name != bytes32(0) && _app_desc.length > 0 && _app_storage != address(0));

    // Get pointer to provider base storage location
    Pointers.StoragePtr memory provider_apps = _context.provider_apps();
    // Get pointer to application base storage location
    Pointers.StoragePtr memory app_base = provider_apps.applications(_app_name);

    Virtual.Struct memory application = _context.provider();

    // Ensure application is not already registered under this provider -
    if (app_base.read() != bytes32(0))
      Errors.fail('App already registered');

    /// Application is unregistered - register application -

    // Get pointer to free memory and set up STORES action requests -
    Pointers.ActionPtr memory ptr = Pointers.clear(_context);
    ptr.stores();

    // Store app name in app base storage location
    ptr.store(_app_name).at(app_base);

    // Store app default storage address
    ptr.store(_app_storage).at(app_base.default_storage_addr());

    // Push app name to end of provider's app list -
    ptr.push(_app_name).toEnd(provider_apps);

    // Store application description
    ptr.storeBytesAt(_app_desc, app_base.app_description());

    /* // Finish STORES action and set up EMITS requests -
    ptr.nextAction().emits();

    // Add APP_REGISTERED event topics and data (app name)
    ptr.topics(
      [APP_REGISTERED, _context.exec_id(), _context.provider()]
    ).data(_app_name); */

    // Revert formatted action request to storage
    ptr.finalize();
  }
}
