pragma solidity ^0.4.23;

library Contract {

  // Modifiers: //

  // Runs two functions before and after a function -
  modifier conditions(function () pure first, function () pure last) {
    first();
    _;
    last();
  }

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
    // Next, reads the execution id and sender address from the first two slots
    // of storage, and places them in memory at 0x80 and 0xa0, respectively
    assembly {
      mstore(0x80, sload(0))
      mstore(0xa0, sload(0x20))
      mstore(0xc0, 0)
      // Update free memory pointer -
      mstore(0x40, 0xe0)
    }
    // Ensure that the sender and execution id returned from storage are nonzero -
    assert(execID() != bytes32(0) && sender() != address(0));

    // Check that the sender is authorized as a script exec contract for this exec id
    bool authorized;
    assembly {
      // Clear first 32 bytes, then place the exec id in the next slot in memory
      mstore(0, 0)
      mstore(0x20, mload(0xa0))
      // Hash the resulting first 64 bytes, and place back into memory at 0x20
      mstore(0x20, keccak256(0, 0x40))
      // Place the script exec address before the hash -
      mstore(0, _script_exec)
      // Hash the script exec address and the previous hash, and check the result
      authorized := sload(keccak256(0, 0x40))
    }
    if (!authorized)
      revert("Sender is not authorized as a script exec address");
  }

  // Sets up contract execution when initializing an instance of the application
  // First, reads execution id and sender from storage (execution id should be 0xDEAD),
  // then places them in memory, creating getters. Calling this function should be the first
  // action an application does as part of execution, as it sets up memory for
  // execution. Additionally, application functions in the main file should be
  // external, so that memory is not touched prior to calling this function.
  // The 3rd slot allocated will hold a pointer to a storage buffer, which will
  // be reverted to abstract storage to store data, emit events, and forward
  // wei on behalf of the application.
  function initialize() internal view {
    // No memory should have been allocated yet - expect the free memory pointer
    // to point to 0x80 - and throw if it does not
    require(freeMem() == 0x80, "Memory allocated prior to execution");
    // Next, reads the execution id and sender address from the first two slots
    // of storage, and places them in memory at 0x80 and 0xa0, respectively
    assembly {
      mstore(0x80, sload(0))
      mstore(0xa0, sload(0x20))
      mstore(0xc0, 0)
      // Update free memory pointer -
      mstore(0x40, 0xe0)
    }
    // Ensure that the sender and execution id returned from storage are expected values -
    assert(execID() == bytes32(0xDEAD) && sender() != address(0));
  }

  // Calls the passed-in function, performing a memory state check before and after the check
  // is executed.
  function checks(function () view _check) conditions(validState, validState) internal view {
    _check();
  }

  // Calls the passed-in function, performing a memory state check before and after the check
  // is executed.
  function checks(function () pure _check) conditions(validState, validState) internal view {
    _check();
  }

  // Ensures execution completed successfully, and reverts the created storage buffer
  // back to the sender.
  function commit() conditions(validState, none) internal pure {
    // Check value of storage buffer pointer - should be at least 0xe0
    bytes32 ptr = buffPtr();
    require(ptr >= 0xe0, "Invalid buffer pointer");

    assembly {
      // Get the size of the buffer
      let size := mload(ptr)
      mstore(sub(ptr, 0x20), 0x20) // Place dynamic data offset before buffer
      // Revert to storage
      revert(sub(ptr, 0x20), add(0x40, size))
    }
  }

  // Helpers: //

  // Checks to ensure the application was correctly executed -
  function validState() private pure {
    if (freeMem() < 0xe0)
      revert('Expected Contract.execute()');

    if (buffPtr() != 0 && buffPtr() < 0xc0)
      revert('Invalid buffer pointer');

    assert(execID() != bytes32(0) && sender() != address(0));
  }

  // Returns a pointer to the execution storage buffer -
  function buffPtr() private pure returns (bytes32 ptr) {
    assembly { ptr := mload(0xc0) }
  }

  // Returns the location pointed to by the free memory pointer -
  function freeMem() private pure returns (bytes32 ptr) {
    assembly { ptr := mload(0x40) }
  }

  // Returns the current storage action
  function currentAction() private pure returns (bytes4 action) {
    if (buffPtr() == bytes32(0))
      return bytes4(0);

    assembly { action := mload(mload(0xc0)) }
  }

  // If the current action is not storing, reverts
  function isStoring() private pure {
    if (currentAction() != STORES)
      revert('Invalid current action - expected STORES');
  }

  // If the current action is not emitting, reverts
  function isEmitting() private pure {
    if (currentAction() != EMITS)
      revert('Invalid current action - expected EMITS');
  }

  // If the current action is not paying, reverts
  function isPaying() private pure {
    if (currentAction() != PAYS)
      revert('Invalid current action - expected PAYS');
  }

  // Initializes a storage buffer in memory -
  function startBuffer() private pure {
    assembly {
      // Get a pointer to free memory, and place at 0xc0 (storage buffer pointer)
      let ptr := msize()
      mstore(0xc0, ptr)
      // Clear bytes at pointer -
      mstore(ptr, 0) // current-buffer-action
      // Clear next 0x80 bytes -
      mstore(add(0x20, ptr), 0) // num-stored
      mstore(add(0x40, ptr), 0) // num-emitted
      mstore(add(0x60, ptr), 0) // num-paid
      mstore(add(0x80, ptr), 0) // temp ptr
      mstore(add(0xa0, ptr), 0) // buffer length
      // Update free memory pointer -
      mstore(0x40, add(0xc0, ptr))
    }
  }

  function validStoreBuff() private pure {
    // Get pointer to current buffer - if zero, create a new buffer -
    if (buffPtr() == bytes32(0))
      startBuffer();

    // Ensure that the current action is not 'storing', and that the buffer has not already
    // completed a STORES action -
    if (stored() != 0 || currentAction() == STORES)
      revert('Duplicate request - stores');
  }

  function validEmitBuff() private pure {
    // Get pointer to current buffer - if zero, create a new buffer -
    if (buffPtr() == bytes32(0))
      startBuffer();

    // Ensure that the current action is not 'emitting', and that the buffer has not already
    // completed an EMITS action -
    if (emitted() != 0 || currentAction() == EMITS)
      revert('Duplicate request - emits');
  }

  function validPayBuff() private pure {
    // Get pointer to current buffer - if zero, create a new buffer -
    if (buffPtr() == bytes32(0))
      startBuffer();

    // Ensure that the current action is not 'paying', and that the buffer has not already
    // completed an PAYS action -
    if (paid() != 0 || currentAction() == PAYS)
      revert('Duplicate request - pays');
  }

  // Placeholder function when no pre or post condition for a function is needed
  function none() private pure { }

  // Runtime getters: //

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

  // Reading from storage: //

  // Reads from storage, resolving the passed-in location to its true location in storage
  // by hashing with the exec id. Returns the data read from that location
  function read(bytes32 _location) internal view returns (bytes32 data) {
    _location = keccak256(_location, execID());
    assembly { data := sload(_location) }
  }

  // Storing data, emitting events, and forwarding payments: //

  bytes4 internal constant EMITS = bytes4(keccak256('Emit((bytes32[],bytes)[])'));
  bytes4 internal constant STORES = bytes4(keccak256('Store(bytes32[])'));
  bytes4 internal constant PAYS = bytes4(keccak256('Pay(bytes32[])'));
  bytes4 internal constant THROWS = bytes4(keccak256('Error(string)'));

  // Begins creating a storage buffer - values and locations pushed will be committed
  // to storage at the end of execution
  function storing() conditions(validStoreBuff, isStoring) internal pure {
    bytes4 action_req = STORES;
    assembly {
      // Get pointer to buffer length -
      let ptr := add(0x80, mload(0xc0))
      // Push requestor to the of buffer, as well as to the 'current action' slot -
      mstore(mload(0xc0), action_req)
      mstore(add(0x20, add(ptr, mload(ptr))), action_req)
      // Push '0' to the end of the 4 bytes just pushed - this will be the length of the STORES action
      mstore(add(0x24, add(ptr, mload(ptr))), 0)
      // Increment buffer length - 0x24 plus the previous length
      mstore(ptr, add(0x24, mload(ptr)))
      // Set a pointer to STORES action length in the free slot at mload(0xc0)
      mstore(mload(0xc0), add(ptr, add(0x04, mload(ptr))))
      // If the free-memory pointer does not point beyond the buffer's current size, update it
      if lt(mload(0x40), add(add(0x44, ptr), mload(ptr))) {
        mstore(0x40, add(add(0x44, ptr), mload(ptr)))
      }
    }
  }

  function authorizeExec(address _script_exec) internal pure {

  }

  function increase(bytes32 _field) conditions(isStoring, isStoring) internal view returns (bytes32 func) {
    assembly {
      // Set pointer to expected next function - 'by'
      func := by
      // Get pointer to buffer length -
      let ptr := add(0x80, mload(0xc0))
      // Push location to the end of the buffer -
      mstore(add(0x20, add(ptr, mload(ptr))), _field)
      // Increment buffer length (0x20 plus previous length)

    }
  }

  function decrease(bytes32 _field) internal view returns (bytes32 ptr) {
    // TODO
  }

  function by(bytes32 _ptr, uint _amt) internal view {
    // TODO
  }

  function emitting() internal pure {
    // TODO
  }

  function log(bytes32[3] memory _topics, bytes32 _data) internal view {
    // TODO
  }

  function paying() internal pure {

  }

  function pay(uint _amount) internal pure returns (Contract) {

  }

  function to(address _dest) internal pure returns (Contract) {

  }

  // Returns the number of events pushed to the storage buffer -
  function emitted() internal pure returns (uint num_emitted) {
    if (buffPtr() == bytes32(0))
      return 0;

    // Load number emitted from buffer -
    assembly { num_emitted := mload(add(0x40, mload(0xc0))) }
  }

  // Returns the number of storage slots pushed to the storage buffer -
  function stored() internal pure returns (uint num_stored) {
    if (buffPtr() == bytes32(0))
      return 0;

    // Load number stored from buffer -
    assembly { num_stored := mload(add(0x20, mload(0xc0))) }
  }

  // Returns the number of payment destinations and amounts pushed to the storage buffer -
  function paid() internal pure returns (uint num_paid) {
    if (buffPtr() == bytes32(0))
      return 0;

    // Load number paid from buffer -
    assembly { num_paid := mload(add(0x60, mload(0xc0))) }
  }
}
