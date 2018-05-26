pragma solidity ^0.4.23;

import "./Errors.sol";

library Pointers {

  struct ActionPtr {
    uint buffer;
    uint length_ptr;
    bytes32 next_flag;
    bytes32 exec_id;
  }

  bytes32 internal constant ACTION_APPEND = keccak256('ACTION_APPEND');
  bytes32 internal constant NEXT_ACTION = bytes32(1);

  // Initialize a new pointer in memory
  function clear(bytes memory _context) internal pure returns (ActionPtr) {
    // Ensure a valid input
    bytes32 exec_id;
    (exec_id, , ) = parse(_context);
    Errors.failIf(exec_id == bytes32(0), 'Error at Pointers.clear: invalid _exec_id');
    ActionPtr memory ptr;
    assembly {
      ptr := msize
      mstore(ptr, 0x60)
      mstore(0x40, add(ptr, 0x80))
    }
    ptr.next_flag = NEXT_ACTION;
    ptr.exec_id = exec_id;
    return ptr;
  }

  /* // If the pointer flag does not match the expected value, reverts with an error
  function expect(ActionPtr _ptr, bytes4 _expected) internal pure {
    Errors.failIf(_ptr.next_flag != _expected, 'PointerException');
  } */

  function nextAction(ActionPtr _ptr) internal pure returns (ActionPtr) {
    _ptr.next_flag = NEXT_ACTION;
    _ptr.length_ptr = 0;
    return _ptr;
  }

  function finalize(ActionPtr _ptr) internal pure {
    assembly {
      // Set data read offset
      mstore(add(0x40, _ptr), 0x20)
      // Set buffer size
      mstore(add(0x60, _ptr), sub(mload(_ptr), 0x60))
      // Revert buffer to storage
      revert(add(0x40, _ptr), sub(mload(_ptr), 0x40))
    }
  }
}
