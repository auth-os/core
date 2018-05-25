pragma solidity ^0.4.23;

import "./Virtual.sol";

library LibStorage {

  /* using Pointers for *; */

  // ACTION REQUESTORS //

  bytes4 internal constant STORES = bytes4(keccak256('stores:'));

  // FLAGS //

  bytes32 internal constant STORES_READY = keccak256('STORES_READY');
  bytes32 internal constant STOREDEST = keccak256('STOREDEST');
  bytes32 internal constant ARRAY_PTR = keccak256('ARRAY_PTR');

  // Set up a STORES action request buffer
  function stores(Pointers.ActionPtr _ptr) internal pure {
    // Ensures the flag stored at the is valid
    Errors.failIf(_ptr.next_flag != bytes32(1), 'Error at LibStorage.stores: invalid flag');
    // Set next flag to STORES_READY
    _ptr.next_flag = STORES_READY;
    bytes4 action_req = STORES;
    assembly {
      // Get size of buffer, plus 0x20 bytes -
      let size := add(0x20, mload(_ptr))
      // Push requestor to the of buffer
      mstore(add(_ptr, size), action_req)
      // Push '0' to the end of the 4 bytes just pushed - this will be the length of the STORES action
      mstore(add(_ptr, add(0x04, size)), 0)
      // Increment buffer length (0x24 plus previous length)
      mstore(_ptr, add(0x04, size))
      // Set a pointer to STORES action length at _ptr.length_ptr
      mstore(add(0x20, _ptr), add(_ptr, add(0x04, size)))
      // If the free-memory pointer does not point beyond the buffer's current size, update it
      if lt(mload(0x40), add(_ptr, add(0x44, size))) {
        mstore(0x40, add(_ptr, add(0x44, size)))
      }
    }
  }

  function store(Pointers.ActionPtr _ptr, bytes32 _val) internal pure
  returns (Pointers.ActionPtr) {
    // Ensures the flag stored at the pointer is valid
    Errors.failIf(_ptr.next_flag != STORES_READY, 'Error at LibStorage.store: invalid flag');
    // Set flag to STOREDEST - expecting a destination to be pushed next
    _ptr.next_flag = STOREDEST;
    assembly {
      // Get size of buffer, plus 0x20 bytes -
      let size := add(0x20, mload(_ptr))
      // Push value to the end of the buffer
      mstore(add(_ptr, size), _val)
      // Increment buffer length (0x20 plus previous length)
      mstore(_ptr, size)
      // Increment STORES action length
      mstore(
        mload(add(0x20, _ptr)),
        add(1, mload(mload(add(0x20, _ptr))))
      )
      // If the free-memory pointer does not point beyond the buffer's current size, update it
      if lt(mload(0x40), add(_ptr, add(0x40, size))) {
        mstore(0x40, add(_ptr, add(0x40, size)))
      }
    }
    return _ptr;
  }

  function store(Pointers.ActionPtr _ptr, address _val) internal pure returns (Pointers.ActionPtr) {
    return store(_ptr, bytes32(_val));
  }

  function store(Pointers.ActionPtr _ptr, uint _val) internal pure returns (Pointers.ActionPtr) {
    return store(_ptr, bytes32(_val));
  }

  function store(Pointers.ActionPtr _ptr, bool _val) internal pure returns (Pointers.ActionPtr) {
    return store(
      _ptr,
      _val ? bytes32(1) : bytes32(0)
    );
  }

  function at(Pointers.ActionPtr _ptr, Pointers.StoragePtr _loc) internal pure {
    // Ensures the flag stored at the pointer is valid
    Errors.failIf(_ptr.next_flag != STOREDEST, 'Error at LibStorage.at: invalid flag');
    // Set flag to STORES_READY
    _ptr.next_flag = STORES_READY;
    assembly {
      // Get size of buffer, plus 0x20 bytes -
      let size := add(0x20, mload(_ptr))
      // Push storage location to the end of the buffer
      mstore(add(_ptr, size), mload(_loc))
      // Increment buffer length (0x20 plus previous length)
      mstore(_ptr, size)
      // If the free-memory pointer does not point beyond the buffer's current size, update it
      if lt(mload(0x40), add(_ptr, add(0x40, size))) {
        mstore(0x40, add(_ptr, add(0x40, size)))
      }
    }
  }

  function storeBytesAt(Pointers.ActionPtr _ptr, bytes memory _arr, Pointers.StoragePtr _base_location) internal pure {
    // Ensures the flag stored at the pointer is valid
    Errors.failIf(_ptr.next_flag != STORES_READY, 'Error at LibStorage.storeBytesAt: invalid flag');
    assembly {
      // Get size of buffer, plus 0x20 bytes -
      let size := add(0x20, mload(_ptr))
      // Loop over bytes array, and push each value and incremented storage location to storage buffer
      let offset := 0x0
      for { } lt(offset, add(0x20, mload(_arr))) { offset := add(0x20, offset) } {
        // Push bytes array chunk to buffer
        mstore(add(add(size, mul(2, offset)), _ptr), mload(add(offset, _arr)))
        // Push incremented location to buffer
        mstore(add(add(add(0x20, size), mul(2, offset)), _ptr), add(offset, mload(_base_location)))
      }
      // Increment buffer length
      mstore(_ptr, add(mul(2, offset), mload(_ptr)))
      // Increment STORES action length
      mstore(
        mload(add(0x20, _ptr)),
        add(div(offset, 0x20), mload(mload(add(0x20, _ptr))))
      )
      // If the free-memory pointer does not point beyond the buffer's current size, update it
      if lt(mload(0x40), add(add(0x40, _ptr), mload(_ptr))) {
        mstore(0x40, add(add(0x40, _ptr), mload(_ptr)))
      }
    }
  }

  function push(Pointers.ActionPtr _ptr, bytes32 _val) internal pure returns (Pointers.ActionPtr) {
    // Ensures the flag stored at the pointer is valid
    Errors.failIf(_ptr.next_flag != STORES_READY, 'Error at LibStorage.push: invalid flag');
    // Set next flag to ARRAY_PTR
    _ptr.next_flag = ARRAY_PTR;
    assembly {
      // Get size of buffer, plus 0x20 bytes -
      let size := add(0x20, mload(_ptr))
      // Push value to the end of the buffer
      mstore(add(_ptr, size), _val)
      // Increment buffer length (0x20 plus previous length)
      mstore(_ptr, size)
      // Increment STORES action length
      mstore(
        mload(add(0x20, _ptr)),
        add(2, mload(mload(add(0x20, _ptr))))
      )
      // If the free-memory pointer does not point beyond the buffer's current size, update it
      if lt(mload(0x40), add(_ptr, add(0x40, size))) {
        mstore(0x40, add(_ptr, add(0x40, size)))
      }
    }
    return _ptr;
  }

  function toEnd(Pointers.ActionPtr _ptr, Pointers.StoragePtr _array_base_loc) internal view {
    // Ensures the flag stored at the pointer is valid
    Errors.failIf(_ptr.next_flag != ARRAY_PTR, 'Error at LibStorage.toEnd: invalid flag');
    // Set next flag to STORES_READY
    _ptr.next_flag = STORES_READY;
    uint length = _array_base_loc.length();
    assembly {
      // Get size of buffer, plus 0x20 bytes -
      let size := add(0x20, mload(_ptr))
      // Push location of the end of the array to buffer
      mstore(
        add(_ptr, size),
        add(0x20, add(mul(0x20, length), mload(_array_base_loc)))
      )
      // Push new array length to buffer
      mstore(add(_ptr, add(0x20, size)), add(1, length))
      // Push array length storage location to buffer
      mstore(add(_ptr, add(0x40, size)), mload(_array_base_loc))
      // Increment buffer length (0x60 plus previous length)
      mstore(_ptr, add(0x40, size))
      // If the free-memory pointer does not point beyond the buffer's current size, update it
      if lt(mload(0x40), add(add(0x40, _ptr), mload(_ptr))) {
        mstore(0x40, add(add(0x40, _ptr), mload(_ptr)))
      }
    }
  }
}
