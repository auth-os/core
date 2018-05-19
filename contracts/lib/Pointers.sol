pragma solidity ^0.4.23;

library Pointers {

  function getBuffer(uint _ptr) internal pure returns (bytes memory buffer) {
    assembly {
      buffer := _ptr
    }
  }

  function toPointer(bytes memory _buffer) internal pure returns (uint _ptr) {
    assembly {
      _ptr := _buffer
    }
  }

  function clear(uint _ptr) internal pure returns (uint) {
    assembly {
      _ptr := add(0x20, msize)
      mstore(_ptr, 0)
      mstore(0x40, add(0x20, _ptr))
    }
    return _ptr;
  }

  function end(uint _ptr) internal pure returns (uint buffer_end) {
    assembly {
      let len := mload(_ptr)
      buffer_end := add(0x20, add(len, _ptr))
    }
  }
}
