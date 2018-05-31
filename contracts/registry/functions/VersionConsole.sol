pragma solidity ^0.4.23;

import "../class/Registry.sol";

library VersionConsole {

  using Registry for Contract.Class;
  using Apps for Contract.Feature;

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
    // Declare Registry feature and task
    Contract.Feature memory app;
    Contract.Task memory task;
    // Initialize the application under which the version will be registered -
    app.init(_app, _context);
    // Set the app's task -
    app.prepares(task, Registry.registerVersion);

    // Begin task -
    app.begin(task);

    //

    // Begin storing values -
    task.storing();
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

  /*
  Finalizes a registered version by providing instance initialization information

  @param _app: The name of the application under which the version is registered
  @param _ver_name: The name of the version to finalize
  @param _ver_init_address: The address which contains the version's initialization function
  @param _init_sig: The function signature for the version's initialization function
  @param _context: The execution context for this application - a 96-byte array containing (in order):
    1. Application execution id
    2. Original script sender (address, padded to 32 bytes)
    3. Wei amount sent with transaction to storage
  */
  function finalizeVersion(bytes32 _app, bytes32 _ver_name, address _ver_init_address, bytes4 _init_sig, bytes memory _context) public view
  returns (bytes memory) {
    // Ensure input is correctly formatted
    require(_context.length == 96);
    require(_app != bytes32(0) && _ver_name != bytes32(0));
    require(_ver_init_address != address(0) && _init_sig != bytes4(0) && _init_description.length > 0);

    bytes32 exec_id;
    bytes32 provider;

    // Parse context array and get execution id and provider
    (exec_id, provider, ) = parse(_context);

    /// Ensure application and version are registered, and that the version is not already finalized -

    // Create 'readMulti' calldata buffer in memory
    uint ptr = cdBuff(RD_MULTI);
    // Place exec id, data read offset, and read size in buffer
    cdPush(ptr, exec_id);
    cdPush(ptr, 0x40);
    cdPush(ptr, 3);
    // Push app base storage, version base storage, and version finalization status storage locations to buffer
    // Get app base storage -
    bytes32 temp = keccak256(keccak256(provider), PROVIDERS);
    temp = keccak256(keccak256(_app), keccak256(APPS, temp));
    cdPush(ptr, temp);
    // Get version base storage -
    temp = keccak256(keccak256(_ver_name), keccak256(VERSIONS, temp));
    cdPush(ptr, temp);
    cdPush(ptr, keccak256(VER_IS_FINALIZED, temp));
    // Read from storage and store return in buffer
    bytes32[] memory read_values = readMulti(ptr);
    // Check returned values -
    if (
      read_values[0] == bytes32(0) // Application does not exist
      || read_values[1] == bytes32(0) // Version does not exist
      || read_values[2] != bytes32(0) // Version already finalized
    ) {
      triggerException(bytes32("InsufficientPermissions"));
    }

    /// App and version are registered, and version is ready to be finalized -

    // Get pointer to free memory
    ptr = ptr.clear();

    // Set up STORES action requests -
    ptr.stores();
    // Push each storage location and value to the STORES request buffer:

    // Store version finalization status
    ptr.store(
      true
    ).at(keccak256(VER_IS_FINALIZED, temp));

    // Store version initialization address
    ptr.store(
      _ver_init_address
    ).at(keccak256(VER_INIT_ADDR, temp));

    // Store version initialization function selector
    ptr.store(
      _init_sig
    ).at(keccak256(VER_INIT_SIG, temp));

    // Store entirety of version initialization function description
    ptr.storeBytesAt(_init_description, keccak256(VER_INIT_DESC, temp));

    // Done with STORES action - set up EMITS action
    ptr.emits();

    // Add VERSION_RELEASED topics
    ptr.topics(
      [VERSION_RELEASED, exec_id, keccak256(provider), _app]
    );
    // Add VERSION_RELEASED data (version name)
    // Separate line to avoid 'Stack too deep' issues
    ptr.data(_ver_name);

    // Return formatted action requests to storage
    return ptr.getBuffer();
  }
}
