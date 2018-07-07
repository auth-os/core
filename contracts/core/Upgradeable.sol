pragma solidity ^0.4.23;

library Upgradeable {

  /// Storage Seeds ///

  // The signature of the STORES action request
  bytes4 internal constant STORES = bytes4(keccak256('Store(bytes32[])'));
  // Storage seed for the application's index address
  bytes32 internal constant APP_IDX_ADDR = keccak256('index');
  // Storage seed for the executive permissions mapping
  bytes32 internal constant EXEC_PERMISSIONS = keccak256('script_exec_permissions');

  // Returns the location of a registered app's name under a provider
  function appBase(bytes32 _app, address _provider) internal pure returns (bytes32)
    { return keccak256(_app, keccak256(bytes32(_provider), 'app_base')); }

  // Returns the location of an app's list of versions
  function appVersionList(bytes32 _app, address _provider) internal pure returns (bytes32)
    { return keccak256('versions', appBase(_app, _provider)); }

  // Returns the location of a version's name
  function versionBase(bytes32 _app, bytes32 _version, address _provider) internal pure returns (bytes32)
    { return keccak256(_version, 'version', appBase(_app, _provider)); }

  // Returns the location of a registered app's index address under a provider
  function versionIndex(bytes32 _app, bytes32 _version, address _provider) internal pure returns (bytes32)
    { return keccak256('index', versionBase(_app, _version, _provider)); }

  // Returns the location of an app's function selectors, registered under a provider
  function versionSelectors(bytes32 _app, bytes32 _version, address _provider) internal pure returns (bytes32)
    { return keccak256('selectors', versionBase(_app, _version, _provider)); }

  // Returns the location of an app's implementing addresses, registered under a provider
  function versionAddresses(bytes32 _app, bytes32 _version, address _provider) internal pure returns (bytes32)
    { return keccak256('addresses', versionBase(_app, _version, _provider)); }

  // Returns the true storage location of a seed in Abstract Storage
  function trueLocation(bytes32 seed) internal pure returns (bytes32) {
    return keccak256(seed, execID());
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

  // FIXME
  // Updates this application's versioning information in AbstractStorage to allow upgrading to occur
  // @param - This application's name
  // @param - The provider of this application
  // @param - The registry id of this application
  function updateInstance(bytes32 _app_name, bytes32 _registry_id, address _provider) external view {
    // Authorize the sender and set up the run-time memory of this application
    authorize(msg.sender);

    // Set up a storage buffer
    storing(); 

    // Ensure valid input -
    require(_app_name != 0 && _provider != 0 && _registry_id != 0, 'invalid input');

    // FIXME The execID check may be redundant
    // Ensure that the application has a valid execID and sender
    require(read(execPermissions(sender())) != 0, 'invalid execID or sender');

    bytes32 version = getLatestVersion(_provider, _app_name);

    // Ensure a valid version name for the update - 
    require(version != bytes32(0), 'Invalid version name');

    address index = getVersionIndex(_provider, _app_name,  version);
    bytes4[] storage selectors = getVersionSelectors(_provider, _app_name,  version); 
    address[] storage implementations = getVersionImplementations(_provider, _app_name,  version);

    // Ensure a valid index address for the update -
    require(index != address(0) && index != address(this), 'Invalid index address');

    // Set this application's index address to equal the latest version's index
    set(APP_IDX_ADDR);
    to(APP_IDX_ADDR, bytes32(index));

    // Ensure a nonzero number of allowed selectors and implementing addresses -
    require(selectors.length == implementations.length && selectors.length != 0, 'Invalid implementation length');

    // Loop over implementing addresses, and map each function selector to its corresponding address for the new instance
    for (uint i = 0; i < selectors.length; i++) {
      require(selectors[i] != 0 && implementations[i] != 0, 'invalid input - expected nonzero implementation');
      bytes32 seed = set(appSelectors(selectors[i]));
      to(seed, bytes32(implementations[i]));
    }

    /// MIGHT WANT: Event emission signaling that the application has been upgraded

    // Commit the changes to the storage contract
    commit();
  }


  // FIXME 
  // Replaces the current Script Executor with a new address
  // @param - newExec: The replacement Script Executor
  function updateExec(address newExec) external view {
    // Authorize the sender and set up the run-time memory of this application
    authorize(msg.sender);

    // Set up a storage buffer
    storing();

    address _sender = sender();
    require(newExec != address(0) && read(execPermissions(_sender)) != 0, 'sender is not exec or invalid replacement');

    // Zero out the executive permissions value for this 
    set(execPermissions(_sender));
    to(execPermissions(_sender), 0);

    // Set the new exec as the Script Executor
    set(execPermissions(newExec));
    to(execPermissions(newExec), 1);

    /// MIGHT WANT: Event emission signaling that the application's Script Exec has been upgraded

    // Commit the changes to the storage contract
    commit();
  }

  /// Registry Getters ///

  // Comment: I am aware that adding these functions may bloat this library, but these functions could drastically reduce the gas
  //          cost of the updateInstance and updateExec contracts by not forcing this contract to make an external call to RegistryIdx

  // FIXME
  // Returns the latest version of an application
  function getLatestVersion(address _provider, bytes32 _app) internal view returns (bytes32) {
    // Get a seed to the start of this app's version list 
    uint seed = uint(appVersionList(_app, _provider));
    // Get the lenght of the version list
    uint length = uint(read(bytes32(seed)));
    // Calculate a seed to get the most recent version registered under this app
    seed = (32 * length) + seed;
    // Return the latest version of this application
    return read(bytes32(seed));
  }

  // Reads the address of the Idx contract of this application
  function getVersionIndex(address _provider, bytes32 _app, bytes32 _version) internal view returns (address index) {
    index = address(read(versionIndex(_app, _version, _provider)));
  }


  // FIXME 
  // Returns a storage pointer to a version's implementation list
  // @param - _provider: The version's provider
  // @param - _app: The application name 
  // @param - _version: The version name 
  // @returns - The implementations list for the specified version
  function getVersionImplementations(address _provider, bytes32 _app, bytes32 _version) internal pure 
  returns (address[] storage) {
    function (bytes32) internal pure returns (address[] storage) get;
    assembly {
      get := implementations
    }
    return get(trueLocation(versionAddresses(_app, _version, _provider)));
  }

  // A helper function for getVersionImplementations that returns address[] storage 
  function implementations(address[] storage _implementations) internal pure returns (address[] storage) {
    return _implementations;
  }

  // FIXME
  // Returns a storage pointer to a version's selector list
  // @param - _provider: The version's provider
  // @param - _app: The application name 
  // @param - _version: The version name 
  // @returns - The selectors list for the specified version
  function getVersionSelectors(address _provider, bytes32 _app, bytes32 _version) internal pure 
  returns (bytes4[] storage) {
    function (bytes32) internal pure returns (bytes4[] storage) get;
    assembly {
      get := selectors
    }
    return get(trueLocation(versionSelectors(_app, _version, _provider))); 
  }

  // A helper function for getVersionSelectors that returns bytes4[] storage 
  function selectors(bytes4[] storage _selectors) internal pure returns (bytes4[] storage) {
    return _selectors;
  }

  /// Read Functions ///

  // Reads from the specified location in AbstractStorage
  function read(bytes32 _location) internal view returns (bytes32 data) {
    data = keccak256(_location, execID());
    assembly { data := sload(data) }
  }

  /// Storage Functions

  // Initializes a storage buffer in memory -
  function startBuffer() private pure {
    assembly {
      // Get a pointer to free memory, and place at 0xc0 (storage buffer pointer)
      let ptr := msize()
      mstore(0xc0, ptr)
      // Clear bytes at pointer -
      mstore(ptr, 0)            // temp ptr
      mstore(add(0x20, ptr), 0) // buffer length
      // Update free memory pointer -
      mstore(0x40, add(0x40, ptr))
      // Set expected next function to 'NONE' -
      mstore(0x100, 1)
    }
  }

  // Sets a passed in location to a value passed in via 'to'
  function set(bytes32 _field) conditions(validStoreDest, validStoreVal) internal pure returns (bytes32) {
    assembly {
      // Get pointer to buffer length -
      let ptr := add(0x20, mload(0xc0))
      // Push storage destination to the end of the buffer -
      mstore(add(0x20, add(ptr, mload(ptr))), _field)
      // Increment buffer length - 0x20 plus the previous length
      mstore(ptr, add(0x20, mload(ptr)))
      // Set the expected next function - VAL_SET
      mstore(0x100, 3)
      // Increment STORES action length -
      mstore(
        mload(sub(ptr, 0x20)),
        add(1, mload(mload(sub(ptr, 0x20))))
      )
      // Update number of storage slots pushed to -
      mstore(0x120, add(1, mload(0x120)))
      // If the free-memory pointer does not point beyond the buffer's current size, update it
      if lt(mload(0x40), add(0x20, add(ptr, mload(ptr)))) {
        mstore(0x40, add(0x20, add(ptr, mload(ptr))))
      }
    }
    return _field;
  }

  // Sets a previously-passed-in destination in storage to the value
  function to(bytes32, bytes32 _val) conditions(validStoreVal, validStoreDest) internal pure {
    assembly {
      // Get pointer to buffer length -
      let ptr := add(0x20, mload(0xc0))
      // Push storage value to the end of the buffer -
      mstore(add(0x20, add(ptr, mload(ptr))), _val)
      // Increment buffer length - 0x20 plus the previous length
      mstore(ptr, add(0x20, mload(ptr)))
      // Set the expected next function - STORE_DEST
      mstore(0x100, 2)
      // If the free-memory pointer does not point beyond the buffer's current size, update it
      if lt(mload(0x40), add(0x20, add(ptr, mload(ptr)))) {
        mstore(0x40, add(0x20, add(ptr, mload(ptr))))
      }
    }
  }

  // Begins creating a storage buffer - values and locations pushed will be committed
  // to storage at the end of execution
  function storing() conditions(validStoreBuff, isStoring) internal pure {
    bytes4 action_req = STORES;
    assembly {
      // Get pointer to buffer length -
      let ptr := add(0x20, mload(0xc0))
      // Push requestor to the end of buffer, as well as to the 'current action' slot -
      mstore(add(0x20, add(ptr, mload(ptr))), action_req)
      mstore(0xe0, action_req)
      // Push '0' to the end of the 4 bytes just pushed - this will be the length of the STORES action
      mstore(add(0x24, add(ptr, mload(ptr))), 0)
      // Increment buffer length - 0x24 plus the previous length
      mstore(ptr, add(0x24, mload(ptr)))
      // Set the current action being executed (STORES) -
      mstore(0xe0, action_req)
      // Set the expected next function - STORE_DEST
      mstore(0x100, 2)
      // Set a pointer to the length of the current request within the buffer
      mstore(sub(ptr, 0x20), add(ptr, mload(ptr)))
      // If the free-memory pointer does not point beyond the buffer's current size, update it
      if lt(mload(0x40), add(0x20, add(ptr, mload(ptr)))) {
        mstore(0x40, add(0x20, add(ptr, mload(ptr))))
      }
    }
  }
  
  // Ensures execution completed successfully, and reverts the created storage buffer
  // back to the sender.
  function commit() conditions(validState, none) internal pure {
    // Check value of storage buffer pointer - should be at least 0x180
    bytes32 ptr = buffPtr();
    require(ptr >= 0x180, "Invalid buffer pointer");

    assembly {
      // Get the size of the buffer
      let size := mload(add(0x20, ptr))
      mstore(ptr, 0x20) // Place dynamic data offset before buffer
      // Revert to storage
      revert(ptr, add(0x40, size))
    }
  }

  /// Authorization ///

  // Sets up contract execution - reads execution id and sender from storage and
  // places in memory, creating getters. Calling this function should be the first
  // action an application does as part of execution, as it sets up memory for
  // execution. Additionally, application functions in the main file should be
  // external, so that memory is not touched prior to calling this function.
  // The 3rd slot allocated will hold a pointer to a storage buffer, which will
  // be reverted to abstract storage to store data, emit events, and forward
  // wei on behalf of the application.
  function authorize(address _script_exec) internal view {
    // No memory should have been allocated yet - expect the free memory pointer
    // to point to 0x80 - and throw if it does not
    require(freeMem() == 0x80, "Memory allocated prior to execution");
    // Next, set up memory for execution
    bytes32 perms = EXEC_PERMISSIONS;
    assembly {
      mstore(0x80, sload(0))     // Execution id, read from storage
      mstore(0xa0, sload(1))     // Original sender address, read from storage
      mstore(0xc0, 0)            // Pointer to storage buffer
      mstore(0xe0, 0)            // Bytes4 value of the current action requestor being used
      mstore(0x100, 0)           // Enum representing the next type of function to be called (when pushing to buffer)
      mstore(0x120, 0)           // Number of storage slots written to in buffer
      mstore(0x140, 0)           // Number of events pushed to buffer
      mstore(0x160, 0)           // Number of payment destinations pushed to buffer

      // Update free memory pointer -
      mstore(0x40, 0x180)
    }
    // Ensure that the sender and execution id returned from storage are nonzero -
    assert(execID() != bytes32(0) && sender() != address(0));

    // Check that the sender is authorized as a script exec contract for this exec id
    bool authorized;
    assembly {
      // Place the script exec address at 0, and the exec permissions seed after it
      mstore(0, _script_exec)
      mstore(0x20, perms)
      // Hash the resulting 0x34 bytes, and place back into memory at 0
      mstore(0, keccak256(0x0c, 0x34))
      // Place the exec id after the hash -
      mstore(0x20, mload(0x80))
      // Hash the previous hash with the execution id, and check the result
      authorized := sload(keccak256(0, 0x40))
    }
    if (!authorized)
      revert("Sender is not authorized as a script exec address");
  }

  /// Conditions ///

  // Function enums -
  enum NextFunction {
    INVALID, NONE, STORE_DEST, VAL_SET, VAL_INC, VAL_DEC, EMIT_LOG, PAY_DEST, PAY_AMT
  }

  // Runs two functions before and after a function -
  modifier conditions(function () pure first, function () pure last) {
    first();
    _;
    last();
  }
  
  // Checks whether or not it is valid to create a STORES action request -
  function validStoreBuff() private pure {
    // Get pointer to current buffer - if zero, create a new buffer -
    if (buffPtr() == bytes32(0))
      startBuffer();

    // Ensure that the current action is not 'storing', and that the buffer has not already
    // completed a STORES action -
    if (stored() != 0 || currentAction() == STORES)
      revert('Duplicate request - stores');
  }

  // Checks that a call pushing a storage destination to the buffer is expected and valid
  function validStoreDest() private pure {
    // Ensure that the next function expected pushes a storage destination -
    if (expected() != NextFunction.STORE_DEST)
      revert('Unexpected function order - expected storage destination to be pushed');

    // Ensure that the current buffer is pushing STORES actions -
    isStoring();
  }

  // Checks that a call pushing a storage value to the buffer is expected and valid
  function validStoreVal() private pure {
    // Ensure that the next function expected pushes a storage value -
    if (
      expected() != NextFunction.VAL_SET &&
      expected() != NextFunction.VAL_INC &&
      expected() != NextFunction.VAL_DEC
    ) revert('Unexpected function order - expected storage value to be pushed');
    // Ensure that the current buffer is pushing STORES actions -
    isStoring();
  }

  // Checks to ensure the application was correctly executed -
  function validState() private pure {
    if (freeMem() < 0x180)
      revert('Expected Contract.execute()');

    if (buffPtr() != 0 && buffPtr() < 0x180)
      revert('Invalid buffer pointer');

    assert(execID() != bytes32(0) && sender() != address(0));
  }

  // Placeholder function when no pre or post condition for a function is needed
  function none() private pure { }

  /// Helpers ///

  // Returns a pointer to the execution storage buffer -
  function buffPtr() private pure returns (bytes32 ptr) {
    assembly { ptr := mload(0xc0) }
  }

  // Returns the current storage action
  function currentAction() private pure returns (bytes4 action) {
    if (buffPtr() == bytes32(0))
      return bytes4(0);

    assembly { action := mload(0xe0) }
  }

  // Returns a pointer to free memory
  function freeMem() private pure returns (bytes32 ptr) {
    assembly { ptr := mload(0x40) }
  }

  // Returns the number of storage slots pushed to the storage buffer -
  function stored() internal pure returns (uint num_stored) {
    if (buffPtr() == bytes32(0))
      return 0;

    // Load number stored from buffer -
    assembly { num_stored := mload(0x120) }
  }

  // If the current action is not storing, reverts
  function isStoring() private pure {
    if (currentAction() != STORES)
      revert('Invalid current action - expected STORES');
  }

  // Returns the enum representing the next expected function to be called -
  function expected() private pure returns (NextFunction next) {
    assembly { next := mload(0x100) }
  }

  // Returns the execution id from memory -
  function execID() internal pure returns (bytes32 exec_id) {
    assembly { exec_id := mload(0x80) }
    require(exec_id != bytes32(0), "Execution id overwritten, or not read");
  }

  // Returns the original sender from memory -
  function sender() internal pure returns (address addr) {
    assembly { addr := mload(0xa0) }
    require(addr != address(0), "Sender address overwritten, or not read");
  }

}
