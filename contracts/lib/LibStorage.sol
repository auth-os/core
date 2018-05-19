pragma solidity ^0.4.23;

library LibStorage {

  // ACTION REQUESTORS //

  bytes4 internal constant STORES = bytes4(keccak256('stores:'));

  // Set up a STORES action request buffer
  function stores(uint _ptr) internal pure {
    bytes4 action_req = STORES;
    assembly {
      // Get end of buffer - 32 bytes plus the length stored at the pointer
      let len := add(0x20, mload(_ptr))
      // Push requestor to the of buffer
      mstore(add(_ptr, len), action_req)
      // Push '0' to the end of the 4 bytes just pushed - this will be the length of the STORES action
      mstore(add(_ptr, add(0x04, len)), 0)
      // Increment buffer length
      mstore(_ptr, add(0x04, len))
      // Set a pointer to STORES action length in the free slot before _ptr
      mstore(sub(_ptr, 0x20), add(_ptr, add(0x04, len)))
      // If the free-memory pointer does not point beyond the buffer's current size, update it
      if lt(mload(0x40), add(add(0x44, _ptr), len)) {
        mstore(0x40, add(add(0x44, _ptr), len))
      }
    }
  }

  function store(uint _ptr, bytes32 _val) internal pure returns (uint) {
    assembly {
      // Get end of buffer - 32 bytes plus the length stored at the pointer
      let len := add(0x20, mload(_ptr))
      // Push value to the end of the buffer
      mstore(add(_ptr, len), _val)
      // Increment buffer length
      mstore(_ptr, len)
      // Increment STORES action length (pointer to length stored before _ptr)
      let _len_ptr := mload(sub(_ptr, 0x20))
      mstore(_len_ptr, add(1, mload(_len_ptr)))
      // If the free-memory pointer does not point beyond the buffer's current size, update it
      if lt(mload(0x40), add(add(0x40, _ptr), len)) {
        mstore(0x40, add(add(0x40, _ptr), len))
      }
    }
    return _ptr;
  }

  function store(uint _ptr, address _val) internal pure returns (uint) {
    return store(_ptr, bytes32(_val));
  }

  function store(uint _ptr, uint _val) internal pure returns (uint) {
    return store(_ptr, bytes32(_val));
  }

  function store(uint _ptr, bool _val) internal pure returns (uint) {
    return store(
      _ptr,
      _val ? bytes32(1) : bytes32(0)
    );
  }

  function at(uint _ptr, bytes32 _loc) internal pure returns (uint) {
    assembly {
      // Get end of buffer - 32 bytes plus the length stored at the pointer
      let len := add(0x20, mload(_ptr))
      // Push storage location to the end of the buffer
      mstore(add(_ptr, len), _loc)
      // Increment buffer length
      mstore(_ptr, len)
      // If the free-memory pointer does not point beyond the buffer's current size, update it
      if lt(mload(0x40), add(add(0x40, _ptr), len)) {
        mstore(0x40, add(add(0x40, _ptr), len))
      }
    }
    return _ptr;
  }

  function storeBytesAt(uint _ptr, bytes memory _arr, bytes32 _base_location) internal pure returns (uint) {
    assembly {
      // Get end of buffer - 32 bytes plus the length stored at the pointer
      let len := add(0x20, mload(_ptr))
      // Loop over bytes array, and push each value and incremented storage location to storage buffer
      let offset := 0x0
      for { } lt(offset, add(0x20, mload(_arr))) { offset := add(0x20, offset) } {
        // Push incremented location to buffer
        mstore(add(add(add(0x20, len), mul(2, offset)), _ptr), add(offset, _base_location))
        // Push bytes array chunk to buffer
        mstore(add(add(len, mul(2, offset)), _ptr), mload(add(offset, _arr)))
      }
      // Increment buffer length
      mstore(_ptr, add(mul(2, offset), mload(_ptr)))
      // Increment STORES length
      let _len_ptr := mload(sub(_ptr, 0x20))
      len := add(div(offset, 0x20), mload(_len_ptr))
      mstore(_len_ptr, len)
      // If the free-memory pointer does not point beyond the buffer's current size, update it
      if lt(mload(0x40), add(add(0x40, _ptr), mload(_ptr))) {
        mstore(0x40, add(add(0x40, _ptr), mload(_ptr)))
      }
    }
    return _ptr;
  }
}
