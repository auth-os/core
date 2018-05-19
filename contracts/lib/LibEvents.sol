pragma solidity ^0.4.23;

library LibEvents {

  // ACTION REQUESTORS //

  bytes4 internal constant EMITS = bytes4(keccak256('emits:'));

  // Takes an existing or empty buffer stored at the buffer and adds an EMITS
  // requestor to the end
  function emits(uint _ptr) internal pure {
    bytes4 action_req = EMITS;
    assembly {
      // Get end of buffer - 32 bytes plus the length stored at the pointer
      let len := add(0x20, mload(_ptr))
      // Push requestor to the of buffer
      mstore(add(_ptr, len), action_req)
      // Push '0' to the end of the 4 bytes just pushed - this will be the length of the EMITS action
      mstore(add(_ptr, add(0x04, len)), 0)
      // Increment buffer length
      mstore(_ptr, add(0x04, len))
      // Set a pointer to EMITS action length in the free slot before _ptr
      mstore(sub(_ptr, 0x20), add(_ptr, add(0x04, len)))
      // If the free-memory pointer does not point beyond the buffer's current size, update it
      if lt(mload(0x40), add(add(0x44, _ptr), len)) {
        mstore(0x40, add(add(0x44, _ptr), len))
      }
    }
  }

  function topics(uint _ptr) internal pure returns (uint) {
    assembly {
      // Get end of buffer - 32 bytes plus the length stored at the pointer
      let len := add(0x20, mload(_ptr))
      // Push 0 to the end of the buffer - event will have no topics
      mstore(add(_ptr, len), 0)
      // Increment buffer length
      mstore(_ptr, len)
      // Increment EMITS action length (pointer to length stored before _ptr)
      let _len_ptr := mload(sub(_ptr, 0x20))
      mstore(_len_ptr, add(1, mload(_len_ptr)))
      // If the free-memory pointer does not point beyond the buffer's current size, update it
      if lt(mload(0x40), add(add(0x40, _ptr), len)) {
        mstore(0x40, add(add(0x40, _ptr), len))
      }
    }
    return _ptr;
  }

  function topics(uint _ptr, bytes32[1] memory _topics) internal pure returns (uint) {
    assembly {
      // Get end of buffer - 32 bytes plus the length stored at the pointer
      let len := add(0x20, mload(_ptr))
      // Push 1 to the end of the buffer - event will have 1 topics
      mstore(add(_ptr, len), 1)
      // Push topic to end of buffer
      mstore(add(_ptr, add(0x20, len)), mload(_topics))
      // Increment buffer length
      mstore(_ptr, add(0x20, len))
      // If the free-memory pointer does not point beyond the buffer's current size, update it
      if lt(mload(0x40), add(add(0x60, _ptr), len)) {
        mstore(0x40, add(add(0x60, _ptr), len))
      }
      // Increment EMITS action length (pointer to length stored before _ptr)
      len := mload(sub(_ptr, 0x20))
      mstore(len, add(1, mload(len)))
    }
    return _ptr;
  }

  function topics(uint _ptr, bytes32[2] memory _topics) internal pure returns (uint) {
    assembly {
      // Get end of buffer - 32 bytes plus the length stored at the pointer
      let len := add(0x20, mload(_ptr))
      // Push 2 to the end of the buffer - event will have 2 topics
      mstore(add(_ptr, len), 2)
      // Push topics to end of buffer
      mstore(add(_ptr, add(0x20, len)), mload(_topics))
      mstore(add(_ptr, add(0x40, len)), mload(add(0x20, _topics)))
      // Increment buffer length
      mstore(_ptr, add(0x40, len))
      // If the free-memory pointer does not point beyond the buffer's current size, update it
      if lt(mload(0x40), add(add(0x80, _ptr), len)) {
        mstore(0x40, add(add(0x80, _ptr), len))
      }
      // Increment EMITS action length (pointer to length stored before _ptr)
      len := mload(sub(_ptr, 0x20))
      mstore(len, add(1, mload(len)))
    }
    return _ptr;
  }

  function topics(uint _ptr, bytes32[3] memory _topics) internal pure returns (uint) {
    assembly {
      // Get end of buffer - 32 bytes plus the length stored at the pointer
      let len := add(0x20, mload(_ptr))
      // Push 3 to the end of the buffer - event will have 3 topics
      mstore(add(_ptr, len), 3)
      // Push topics to end of buffer
      mstore(add(_ptr, add(0x20, len)), mload(_topics))
      mstore(add(_ptr, add(0x40, len)), mload(add(0x20, _topics)))
      mstore(add(_ptr, add(0x60, len)), mload(add(0x40, _topics)))
      // Increment buffer length
      mstore(_ptr, add(0x60, len))
      // If the free-memory pointer does not point beyond the buffer's current size, update it
      if lt(mload(0x40), add(add(0xa0, _ptr), len)) {
        mstore(0x40, add(add(0xa0, _ptr), len))
      }
      // Increment EMITS action length (pointer to length stored before _ptr)
      len := mload(sub(_ptr, 0x20))
      mstore(len, add(1, mload(len)))
    }
    return _ptr;
  }

  function topics(uint _ptr, bytes32[4] memory _topics) internal pure returns (uint) {
    assembly {
      // Get end of buffer - 32 bytes plus the length stored at the pointer
      let len := add(0x20, mload(_ptr))
      // Push 4 to the end of the buffer - event will have 4 topics
      mstore(add(_ptr, len), 4)
      // Push topics to end of buffer
      mstore(add(_ptr, add(0x20, len)), mload(_topics))
      mstore(add(_ptr, add(0x40, len)), mload(add(0x20, _topics)))
      mstore(add(_ptr, add(0x60, len)), mload(add(0x40, _topics)))
      mstore(add(_ptr, add(0x80, len)), mload(add(0x60, _topics)))
      // Increment buffer length
      mstore(_ptr, add(0x80, len))
      // If the free-memory pointer does not point beyond the buffer's current size, update it
      if lt(mload(0x40), add(add(0xc0, _ptr), len)) {
        mstore(0x40, add(add(0xc0, _ptr), len))
      }
      // Increment EMITS action length (pointer to length stored before _ptr)
      len := mload(sub(_ptr, 0x20))
      mstore(len, add(1, mload(len)))
    }
    return _ptr;
  }

  function data(uint _ptr, bytes memory _data) internal pure returns (uint) {
    assembly {
      // Loop over bytes array, and push each value to storage buffer
      let offset := 0x0
      for { } lt(offset, add(0x20, mload(_data))) { offset := add(0x20, offset) } {
        // Push bytes array chunk to buffer
        mstore(add(add(add(0x20, mload(_ptr)), offset), _ptr), mload(add(offset, _data)))
      }
      // Increment buffer length
      mstore(_ptr, add(offset, mload(_ptr)))
      // If the free-memory pointer does not point beyond the buffer's current size, update it
      if lt(mload(0x40), add(add(0x40, _ptr), mload(_ptr))) {
        mstore(0x40, add(add(0x40, _ptr), mload(_ptr)))
      }
    }
    return _ptr;
  }

  function data(uint _ptr, bytes32 _data) internal pure returns (uint) {
    assembly {
      // Get end of buffer - 32 bytes plus the length stored at the pointer
      let len := add(0x20, mload(_ptr))
      // Push data size (32 bytes) to end of buffer
      mstore(add(_ptr, len), 0x20)
      // Push value to the end of the buffer
      mstore(add(_ptr, add(0x20, len)), _data)
      // Increment buffer length
      mstore(_ptr, add(0x20, len))
      // If the free-memory pointer does not point beyond the buffer's current size, update it
      if lt(mload(0x40), add(add(0x60, _ptr), len)) {
        mstore(0x40, add(add(0x60, _ptr), len))
      }
    }
    return _ptr;
  }

  function data(uint _ptr, uint _data) internal pure returns (uint) {
    assembly {
      // Get end of buffer - 32 bytes plus the length stored at the pointer
      let len := add(0x20, mload(_ptr))
      // Push data size (32 bytes) to end of buffer
      mstore(add(_ptr, len), 0x20)
      // Push value to the end of the buffer
      mstore(add(_ptr, add(0x20, len)), _data)
      // Increment buffer length
      mstore(_ptr, add(0x20, len))
      // If the free-memory pointer does not point beyond the buffer's current size, update it
      if lt(mload(0x40), add(add(0x60, _ptr), len)) {
        mstore(0x40, add(add(0x60, _ptr), len))
      }
    }
    return _ptr;
  }

  function data(uint _ptr, address _data) internal pure returns (uint) {
    assembly {
      // Get end of buffer - 32 bytes plus the length stored at the pointer
      let len := add(0x20, mload(_ptr))
      // Push data size (32 bytes) to end of buffer
      mstore(add(_ptr, len), 0x20)
      // Push value to the end of the buffer
      mstore(add(_ptr, add(0x20, len)), _data)
      // Increment buffer length
      mstore(_ptr, add(0x20, len))
      // If the free-memory pointer does not point beyond the buffer's current size, update it
      if lt(mload(0x40), add(add(0x60, _ptr), len)) {
        mstore(0x40, add(add(0x60, _ptr), len))
      }
    }
    return _ptr;
  }
}
