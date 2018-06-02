pragma solidity ^0.4.23;

library Abstract {

  struct Contract { uint _; }
  struct Class {
    function (function (Class memory) view) view _before;
    function (function (Class memory) view) view _after;
  }
  struct Feature { uint _; }

  function toClass() private pure returns (uint) { return 0x80; }
  function expected()

  // Will need these getters for each struct -
  /* 'setRef' // rm
  '_before'
  '_after'
  'throws' */

  // Is passed pre and post conditions, which is executes -
  modifier conditions (function () pure first, function () pure last) {
    // Checked prior to function execution -
    first();
    _;
    // Checked once function execution is complete -
    last();
  }

  /// Workflow conditions: ///

  // Ensure execution id and sender address are valid -
  function validCtx() private pure {
    // Checks sender address for zero and invalid values
    if (sender() == address(0xDEAD) || sender() == address(0))
      fail('Sender address is invalid');
    // Checks execution id for zero and invalid values
    if (execID() == bytes32(0xDEAD) || execID() == bytes32(0))
      fail('Execution id is invalid');
  }

  // Ensure free memory pointer is what we expect it to be -
  function validMem() private pure {
    // Check that if execution is in strict mode, free memory pvalidCallbackointer matches
    // the expected value
    if (is_strict() && load(0x40) != load(0x140))
      fail('Undeclared memory allocation');
  }

  // Calls validCtx and validMem, as well as get
  function validClass() private pure {
    // Call validCtx and validMem
    validCtx();
    validMem();
    // Checks whether the proper workflow was maintained -
    // If is_strict, compare to expected callback:
    if (is_strict() && expected(invokeClass) == false)
      fail('Unexpected Class.invoke()');
  }

  /// Workflow: ///

  // Requires that _before and _after calls are made for each invocation
  // from Class -> Feature. Additionally, requires that any memory allocation be
  // declared through this class.
  function strictContract() conditions(none, validCtx) internal pure {
    // Initialize memory -
    assembly {
      mstore(0x40, 0x200)           // Update the location of the free memory pointer to 0x200
      mstore(0x80, 0)               // Empty - used for scratch space
      mstore(0xa0, 0)               // Empty
      mstore(0xc0, invokeClass)     // Points to the next expected callback in the workflow
      mstore(0xe0, 1)               // Whether `strict` features are enabled
      mstore(0x100, sload(0))       // exec_id - placed at 0x0 temporarily by AbstractStorage
      mstore(0x120, sload(0x20))    // sender - original sender address
      mstore(0x140, 0x200)          // Current expected value of free memory pointer
      mstore(0x160, 0)              // Will point to the feature-level `_after` hook
      mstore(0x180, 0)              // Will point to the class-level `_after` hook
      mstore(0x1a0, 0)              // Pointer to the beginning of the storage buffer
    }
  }

  // Does not require the use of _before and _after hooks for invocations, and allows
  // undeclared allocation of memory within features.
  function stdContract() conditions(none, validCtx) internal pure {
    // Initialize memory -
    assembly {
      mstore(0x40, 0x200)           // Update the location of the free memory pointer to 0x200
      mstore(0x80, 0)               // Empty - used for scratch space
      mstore(0xa0, 0)               // Empty
      mstore(0xc0, 0)               // Empty
      mstore(0xe0, 0)               // Empty
      mstore(0x100, sload(0))       // exec_id - placed at 0x0 temporarily by AbstractStorage
      mstore(0x120, sload(0x20))    // sender - original sender address
      mstore(0x140, 0x200)          // Current expected value of free memory pointer
      mstore(0x160, 0)              // Will point to the feature-level `_after` hook, if used
      mstore(0x180, 0)              // Will point to the class-level `_after` hook, if used
      mstore(0x1a0, 0)              // Pointer to the beginning of the storage buffer
    }
  }

  // Called at
  function invokeClass(function (Class memory) view _class)
  conditions(validClass, none) internal view {
    // Invoke _class, passing in a Class variable
    _class(toClass());

  }

  // Invokes a Feature which checks various conditions pertaining to function execution
  function invokeFeature(function (Feature memory) view _feature) conditions() internal view {

  }

  // Called at the end of execution lifecycle - validates post-conditions defined by
  // the function's Class and Feature.
  /* function finalize() validAfter(afterClass, afterFeature) internal pure {
    if ()
  } */

  /// Callbacks: ///

  // Calls the function
  function _before(function (Class memory) view _precondition) internal pure {

  }

  /// Exposed getters: ///

  // Returns the original sender from memory -
  function sender() internal pure returns (address addr) {
    assembly { addr := mload(0x120) }
  }

  // Returns the execution id from memory -
  function execID() internal pure returns (bytes32 exec_id) {
    assembly { exec_id := mload(0x100) }
  }

  // Returns whether the current execution requires _before and _after hooks
  function is_strict() internal pure returns (bool status) {
    assembly { status := mload(0xe0) }
  }

  // Returns the callback function expected at this point in the workflow -
  function expected_cb() internal pure returns (function (uint) view expects) {
    assembly { expects := mload(0xc0) }
  }

  /// Execution conditions: ///

  // Passed in when no suitable condition exists -
  function none() private pure { }

  function validCallback(function ()) private pure {

  }

  /// Other: ///

  //
  function fail() private pure {

  }

  // Loads a value stored in memory at the pointer
  function load(uint ptr) private pure returns (bytes32 value) {
    assembly { value := mload(ptr) }
  }
}
