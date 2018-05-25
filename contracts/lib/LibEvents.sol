pragma solidity ^0.4.23;

import "./Pointers.sol";

library LibEvents {

  // ACTION REQUESTORS //

  bytes4 internal constant EMITS = bytes4(keccak256('emits:'));

  // FLAGS //

  bytes4 internal constant APPEND_DATA = bytes4(keccak256('APPEND_DATA'));

  // Takes an existing or empty buffer stored at the buffer and adds an EMITS
  // requestor to the end
  function emits(Pointers.ActionPtr _ptr) internal pure {
    // Ensures the flag stored at the pointer is empty
    _ptr.expect(0x00);
    // Set next flag to Pointers.ACTION_APPEND
    _ptr.next_flag = Pointers.ACTION_APPEND;
    bytes4 action_req = EMITS;
    assembly {
      // Get end of buffer -
      let end := add(0x80, mload(add(0x60, _ptr)))
      // Push requestor to the of buffer
      mstore(add(_ptr, end), action_req)
      // Push '0' to the end of the 4 bytes just pushed - this will be the length of the STORES action
      mstore(add(_ptr, add(0x04, end)), 0)
      // Increment buffer length (0x24 plus previous length)
      mstore(add(0x60, _ptr), sub(end, 0x5C))
      // Set a pointer to EMITS action length at _ptr.buffer_ptr
      mstore(add(0x20, _ptr), add(_ptr, add(0x04, end)))
      // If the free-memory pointer does not point beyond the buffer's current size, update it
      if lt(mload(0x40), add(_ptr, add(0x44, end))) {
        mstore(0x40, add(_ptr, add(0x44, end)))
      }
    }
  }

  function topics(Pointers.ActionPtr _ptr) internal pure returns (Pointers.ActionPtr) {
    // Ensures the flag stored at the pointer is Pointers.ACTION_APPEND
    _ptr.expect(Pointers.ACTION_APPEND);
    // Set next flag to APPEND_DATA
    _ptr.next_flag = APPEND_DATA;
    assembly {
      // Get end of buffer -
      let end := add(0x80, mload(add(0x60, _ptr)))
      // Push 0 to the end of the buffer - event will have no topics
      mstore(add(_ptr, end), 0)
      // Increment buffer length (0x20 plus previous length)
      mstore(add(0x60, _ptr), sub(end, 0x60))
      // Increment EMITS action length
      mstore(
        mload(add(0x20, _ptr)),
        add(1, mload(mload(add(0x20, _ptr))))
      )
      // If the free-memory pointer does not point beyond the buffer's current size, update it
      if lt(mload(0x40), add(_ptr, add(0x40, end))) {
        mstore(0x40, add(_ptr, add(0x40, end)))
      }
    }
    return _ptr;
  }

  function topics(Pointers.ActionPtr _ptr, bytes32[1] memory _topics) internal pure returns (Pointers.ActionPtr) {
    // Ensures the flag stored at the pointer is Pointers.ACTION_APPEND
    _ptr.expect(Pointers.ACTION_APPEND);
    // Set next flag to APPEND_DATA
    _ptr.next_flag = APPEND_DATA;
    assembly {
      // Get end of buffer -
      let end := add(0x80, mload(add(0x60, _ptr)))
      // Push 1 to the end of the buffer - event will have 1 topic
      mstore(add(_ptr, end), 1)
      // Push topic to end of buffer
      mstore(add(_ptr, add(0x20, end)), mload(_topics))
      // Increment buffer length (0x40 plus previous length)
      mstore(add(0x60, _ptr), sub(end, 0x40))
      // Increment EMITS action length
      mstore(
        mload(add(0x20, _ptr)),
        add(1, mload(mload(add(0x20, _ptr))))
      )
      // If the free-memory pointer does not point beyond the buffer's current size, update it
      if lt(mload(0x40), add(_ptr, add(0x60, end))) {
        mstore(0x40, add(_ptr, add(0x60, end)))
      }
    }
    return _ptr;
  }

  function topics(Pointers.ActionPtr _ptr, bytes32[2] memory _topics) internal pure returns (Pointers.ActionPtr) {
    // Ensures the flag stored at the pointer is Pointers.ACTION_APPEND
    _ptr.expect(Pointers.ACTION_APPEND);
    // Set next flag to APPEND_DATA
    _ptr.next_flag = APPEND_DATA;
    assembly {
      // Get end of buffer -
      let end := add(0x80, mload(add(0x60, _ptr)))
      // Push 2 to the end of the buffer - event will have 2 topics
      mstore(add(_ptr, end), 2)
      // Push topics to end of buffer
      mstore(add(_ptr, add(0x20, end)), mload(_topics))
      mstore(add(_ptr, add(0x40, end)), mload(add(0x20, _topics)))
      // Increment buffer length (0x60 plus previous length)
      mstore(add(0x60, _ptr), sub(end, 0x20))
      // Increment EMITS action length
      mstore(
        mload(add(0x20, _ptr)),
        add(1, mload(mload(add(0x20, _ptr))))
      )
      // If the free-memory pointer does not point beyond the buffer's current size, update it
      if lt(mload(0x40), add(_ptr, add(0x80, end))) {
        mstore(0x40, add(_ptr, add(0x80, end)))
      }
    }
    return _ptr;
  }

  function topics(Pointers.ActionPtr _ptr, bytes32[3] memory _topics) internal pure returns (Pointers.ActionPtr) {
    // Ensures the flag stored at the pointer is Pointers.ACTION_APPEND
    _ptr.expect(Pointers.ACTION_APPEND);
    // Set next flag to APPEND_DATA
    _ptr.next_flag = APPEND_DATA;
    assembly {
      // Get end of buffer -
      let end := add(0x80, mload(add(0x60, _ptr)))
      // Push 3 to the end of the buffer - event will have 3 topics
      mstore(add(_ptr, end), 3)
      // Push topics to end of buffer
      mstore(add(_ptr, add(0x20, end)), mload(_topics))
      mstore(add(_ptr, add(0x40, end)), mload(add(0x20, _topics)))
      mstore(add(_ptr, add(0x60, end)), mload(add(0x40, _topics)))
      // Increment buffer length (0x80 plus previous length)
      mstore(add(0x60, _ptr), end)
      // Increment EMITS action length
      mstore(
        mload(add(0x20, _ptr)),
        add(1, mload(mload(add(0x20, _ptr))))
      )
      // If the free-memory pointer does not point beyond the buffer's current size, update it
      if lt(mload(0x40), add(_ptr, add(0xa0, end))) {
        mstore(0x40, add(_ptr, add(0xa0, end)))
      }
    }
    return _ptr;
  }

  function topics(Pointers.ActionPtr _ptr, bytes32[4] memory _topics) internal pure returns (Pointers.ActionPtr) {
    // Ensures the flag stored at the pointer is Pointers.ACTION_APPEND
    _ptr.expect(Pointers.ACTION_APPEND);
    // Set next flag to APPEND_DATA
    _ptr.next_flag = APPEND_DATA;
    assembly {
      // Get end of buffer -
      let end := add(0x80, mload(add(0x60, _ptr)))
      // Push 4 to the end of the buffer - event will have 4 topics
      mstore(add(_ptr, end), 4)
      // Push topics to end of buffer
      mstore(add(_ptr, add(0x20, end)), mload(_topics))
      mstore(add(_ptr, add(0x40, end)), mload(add(0x20, _topics)))
      mstore(add(_ptr, add(0x60, end)), mload(add(0x40, _topics)))
      mstore(add(_ptr, add(0x80, end)), mload(add(0x60, _topics)))
      // Increment buffer length (0xa0 plus previous length)
      mstore(add(0x60, _ptr), add(0x20, end))
      // Increment EMITS action length
      mstore(
        mload(add(0x20, _ptr)),
        add(1, mload(mload(add(0x20, _ptr))))
      )
      // If the free-memory pointer does not point beyond the buffer's current size, update it
      if lt(mload(0x40), add(_ptr, add(0xc0, end))) {
        mstore(0x40, add(_ptr, add(0xc0, end)))
      }
    }
    return _ptr;
  }

  function data(Pointers.ActionPtr _ptr) internal pure {
    // Ensures the flag stored at the pointer is APPEND_DATA
    _ptr.expect(APPEND_DATA);
    // Set next flag to Pointers.ACTION_APPEND
    _ptr.next_flag = Pointers.ACTION_APPEND;
    assembly {
      // Get end of buffer -
      let end := add(0x80, mload(add(0x60, _ptr)))
      // Push data size (0 bytes) to end of buffer
      mstore(add(_ptr, end), 0)
      // Increment buffer length (0x20 plus previous length)
      mstore(add(0x60, _ptr), sub(end, 0x60))
      // If the free-memory pointer does not point beyond the buffer's current size, update it
      if lt(mload(0x40), add(_ptr, add(0x40, end))) {
        mstore(0x40, add(_ptr, add(0x40, end)))
      }
    }
  }

  function data(Pointers.ActionPtr _ptr, bytes memory _data) internal pure {
    // Ensures the flag stored at the pointer is APPEND_DATA
    _ptr.expect(APPEND_DATA);
    // Set next flag to Pointers.ACTION_APPEND
    _ptr.next_flag = Pointers.ACTION_APPEND;
    assembly {
      // Get end of buffer -
      let end := add(0x80, mload(add(0x60, _ptr)))
      // Loop over bytes array, and push each value to storage buffer
      let offset := 0x0
      for { } lt(offset, add(0x20, mload(_data))) { offset := add(0x20, offset) } {
        // Push bytes array chunk to buffer
        mstore(
          add(_ptr, add(offset, add(0x80, mload(add(0x60, _ptr))))),
          mload(add(offset, _data))
        )
      }
      // Increment buffer length
      mstore(add(0x60, _ptr), add(offset, mload(add(0x60, _ptr))))
      // If the free-memory pointer does not point beyond the buffer's current size, update it
      if lt(mload(0x40), add(add(0x40, _ptr), mload(add(0x60, _ptr)))) {
        mstore(0x40, add(add(0x40, _ptr), mload(add(0x60, _ptr))))
      }
    }
  }

  function data(Pointers.ActionPtr _ptr, bytes32 _data) internal pure {
    // Ensures the flag stored at the pointer is APPEND_DATA
    _ptr.expect(APPEND_DATA);
    // Set next flag to Pointers.ACTION_APPEND
    _ptr.next_flag = Pointers.ACTION_APPEND;
    assembly {
      // Get end of buffer -
      let end := add(0x80, mload(add(0x60, _ptr)))
      // Push data size (32 bytes) to end of buffer
      mstore(add(_ptr, end), 0x20)
      // Push value to the end of the buffer
      mstore(add(_ptr, add(0x20, end)), _data)
      // Increment buffer length (0x40 plus previous length)
      mstore(add(0x60, _ptr), sub(end, 0x40))
      // If the free-memory pointer does not point beyond the buffer's current size, update it
      if lt(mload(0x40), add(_ptr, add(0x60, end))) {
        mstore(0x40, add(_ptr, add(0x60, end)))
      }
    }
  }

  function data(Pointers.ActionPtr _ptr, uint _data) internal pure {
    // Ensures the flag stored at the pointer is APPEND_DATA
    _ptr.expect(APPEND_DATA);
    // Set next flag to Pointers.ACTION_APPEND
    _ptr.next_flag = Pointers.ACTION_APPEND;
    assembly {
      // Get end of buffer -
      let end := add(0x80, mload(add(0x60, _ptr)))
      // Push data size (32 bytes) to end of buffer
      mstore(add(_ptr, end), 0x20)
      // Push value to the end of the buffer
      mstore(add(_ptr, add(0x20, end)), _data)
      // Increment buffer length (0x40 plus previous length)
      mstore(add(0x60, _ptr), sub(end, 0x40))
      // If the free-memory pointer does not point beyond the buffer's current size, update it
      if lt(mload(0x40), add(_ptr, add(0x60, end))) {
        mstore(0x40, add(_ptr, add(0x60, end)))
      }
    }
  }

  function data(Pointers.ActionPtr _ptr, address _data) internal pure {
    // Ensures the flag stored at the pointer is APPEND_DATA
    _ptr.expect(APPEND_DATA);
    // Set next flag to Pointers.ACTION_APPEND
    _ptr.next_flag = Pointers.ACTION_APPEND;
    assembly {
      // Get end of buffer -
      let end := add(0x80, mload(add(0x60, _ptr)))
      // Push data size (32 bytes) to end of buffer
      mstore(add(_ptr, end), 0x20)
      // Push value to the end of the buffer
      mstore(add(_ptr, add(0x20, end)), _data)
      // Increment buffer length (0x40 plus previous length)
      mstore(add(0x60, _ptr), sub(end, 0x40))
      // If the free-memory pointer does not point beyond the buffer's current size, update it
      if lt(mload(0x40), add(_ptr, add(0x60, end))) {
        mstore(0x40, add(_ptr, add(0x60, end)))
      }
    }
  }

  function data(Pointers.ActionPtr _ptr, bool _data) internal pure {
    // Ensures the flag stored at the pointer is APPEND_DATA
    _ptr.expect(APPEND_DATA);
    // Set next flag to Pointers.ACTION_APPEND
    _ptr.next_flag = Pointers.ACTION_APPEND;
    assembly {
      // Get end of buffer -
      let end := add(0x80, mload(add(0x60, _ptr)))
      // Push data size (32 bytes) to end of buffer
      mstore(add(_ptr, end), 0x20)
      // Push value to the end of the buffer
      mstore(add(_ptr, add(0x20, end)), _data)
      // Increment buffer length (0x40 plus previous length)
      mstore(add(0x60, _ptr), sub(end, 0x40))
      // If the free-memory pointer does not point beyond the buffer's current size, update it
      if lt(mload(0x40), add(_ptr, add(0x60, end))) {
        mstore(0x40, add(_ptr, add(0x60, end)))
      }
    }
  }
}
