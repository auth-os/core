pragma solidity ^0.4.23;

/* import "./Process.sol";
import "./Versions.sol"; */

library VersionConsole {

  /* using Virtual for *;
  using Providers for Contract.Parent;
  using Application for Contract.Feature;
  using Process for *; */

  /// FUNCTIONS ///

  /*
  Registers a version of an application under the sender's provider id

  @param _app: The name of the application under which the version will be registered
  @param _ver_name: The name of the version to register
  @param _ver_storage: The storage address to use for this version. If left empty, storage uses application default address
  @param _ver_desc: The decsription of the version
  @param _context: The execution context for this application - a 96-byte array containing (in order):
    1. Application execution id
    2. Original script sender (address, padded to 32 bytes)
    3. Wei amount sent with transaction to storage
  */
  function registerVersion(bytes32 _app, bytes32 _ver_name, address _ver_storage, bytes memory _ver_desc, bytes memory _context) public view {
    // Initialize existing application with Apps.static (no initialization of fields)
    Contract.Feature memory app = Apps.static(app, _context);
    // Get application task -
    Contract.Task memory task = app.does(task, Apps.registerVersion);

    // Prepare task, validating preconditions, setting invariants, and initializing post-conditions
    task.prepare();
    // Begin storing values -
    task.storing();

    // Create an uninitialized 'Version' Feature under the application
    task.creating(app.version);
    // Set the initial values for the version
    task.set(Versions.name).to(_ver_name);
    task.set(Versions.storage_addr).to(_ver_storage);
    task.set(Versions.description).to(_ver_desc);
    // Begin updatng applcation -
    task.updating(app);
    // Push version name to app version list
    app.push(_ver_name).to(app.versions);

    // Begin emitting events -
    task.emitting();
    // Emit version registration event
    task.emit(Versions.registerVersion);

    // Validate and finalize state
    app.finish(task);
  }
}
