pragma solidity ^0.4.23;

import "./Virtual.sol";

library Buffers {

  // ACTION REQUESTORS //

  bytes4 internal constant EMITS = bytes4(keccak256('emits:'));
  bytes4 internal constant STORES = bytes4(keccak256('stores:'));
  bytes4 internal constant PAYS = bytes4(keccak256('pays:'));
  bytes4 internal constant THROWS = bytes4(keccak256('throws:'));

  enum Flag {
    INVALID, NONE,
    STORAGE_VAL, STORAGE_DEST,
    BYTES_DEST, ARRAY_DEST,
    EVENT_DATA, EVENT_TOPICS,
    PAYOUT_DEST, PAYOUT_AMT
  }

  struct Buffer {
    Flag flag;
    uint ptr;
    bytes buffer;
  }

  function empty() internal pure returns (Buffer memory) {
    return Buffer(
      Flag.INVALID, 0, ''
    );
  }

  function stores(Buffer memory _buffer) internal pure {
    // Ensure the flag stored at the pointer is valid
    if (_buffer.flag != Flag.INVALID)
      Errors.except('Error at Buffers.stores(Buffer): invalid Flag');

    // Set next flag to STORAGE_VAL
    _buffer.flag = Flag.STORAGE_VAL;
    bytes4 req = STORES;
    bytes memory buff = _buffer.buffer;
    assembly {
      // Get size of buffer, plus 0x20 bytes
      let size := add(0x20, mload(buff))
      // Push requestor to the of buffer
      mstore(add(buff, size), req)
      // Push '0' to the end of the 4 bytes just pushed - this will be the length of the STORES action
      mstore(add(buff, add(0x04, size)), 0)
      // Increase buffer length by 0x24 bytes
      mstore(buff, add(0x04, size))
      // Set a pointer to STORES action length at _ptr.length_ptr
      mstore(add(0x20, _buffer), add(buff, add(0x04, size)))
      // Ensure the free memory pointer is pointing outside of the buffer
      if iszero(gt(mload(0x40), add(buff, add(0x20, mload(buff))))) {
        mstore(0x40, add(buff, add(0x20, mload(buff))))
      }
    }
  }

  function store(Buffer memory _buffer, bytes32 _val) internal pure returns (Buffer memory) {
    // Ensure the flag stored at the pointer is valid
    if (_buffer.flag != Flag.STORAGE_VAL)
      Errors.except('Error at Buffers.store(Buffer,bytes32): invalid Flag');

    // Set next flag to STORAGE_DEST
    _buffer.flag = Flag.STORAGE_DEST;
    bytes memory buff = _buffer.buffer;
    assembly {
      // Get size of buffer, plus 0x20 bytes
      let size := add(0x20, mload(buff))
      // Push value to the end of the buffer
      mstore(add(buff, size), _val)
      // Increase buffer length by 0x20 bytes
      mstore(buff, size)
      // Increase length of STORES action within buffer
      mstore(
        mload(add(0x20, _buffer)),
        add(1, mload(mload(add(0x20, _buffer))))
      )
      // Ensure the free memory pointer is pointing outside of the buffer
      if iszero(gt(mload(0x40), add(buff, add(0x20, size)))) {
        mstore(0x40, add(buff, add(0x20, size)))
      }
    }
    return _buffer;
  }

  function store(Buffer memory _buffer, address _val) internal pure returns (Buffer memory) {
    return store(_buffer, bytes32(_val));
  }

  function store(Buffer memory _buffer, uint _val) internal pure returns (Buffer memory) {
    return store(_buffer, bytes32(_val));
  }

  function store(Buffer memory _buffer, bool _val) internal pure returns (Buffer memory) {
    return store(_buffer, _val ? bytes32(1) : bytes32(0));
  }

  /* function storeBytes(Buffer memory _buffer, bytes memory _val) internal pure returns (Buffer memory) {
    // Ensure the flag stored at the pointer is valid
    if (_buffer.flag != Flag.STORAGE_VAL)
      Errors.except('Error at Buffers.storeBytes(Buffer,bytes): invalid Flag');

    // Set next flag to BYTES_DEST
    _buffer.flag = Flag.BYTES_DEST;
    // Simply sets the buffer's 'ptr' field to point to the bytes value
    assembly { mstore(add(0x20, _buffer), _val) }
    return _buffer;
  } */

  function at(Buffer memory _buffer, bytes32 _dest) internal pure {
    // Ensure the flag stored at the pointer is valid
    if (_buffer.flag != Flag.STORAGE_DEST)
      Errors.except('Error at Buffers.at(Buffer,bytes32): invalid Flag');

    // Set next flag to STORAGE_VAL
    _buffer.flag = Flag.STORAGE_VAL;
    bytes memory buff = _buffer.buffer;
    assembly {
      // Get size of buffer, plus 0x20 bytes
      let size := add(0x20, mload(buff))
      // Push storage destination to the end of the buffer
      mstore(add(buff, size), _dest)
      // Increment buffer length (0x20 plus previous length)
      mstore(buff, size)
      // Ensure the free memory pointer is pointing outside of the buffer
      if iszero(gt(mload(0x40), add(buff, add(0x20, size)))) {
        mstore(0x40, add(buff, add(0x20, size)))
      }
    }
  }

  /* function at(Buffer memory _buffer, Virtual.Bytes memory _arr) internal pure {
    // Ensure the flag stored at the pointer is valid
    if (_buffer.flag != Flag.BYTES_DEST)
      Errors.except('Error at Buffers.at(Buffer,Virtual.Bytes): invalid Flag');
    // Buffer ptr should be nonzero
    if (_buffer.ptr == 0)
      Errors.except('Error at Buffers.at(Buffer,Virtual.Bytes): invalid pointer');

    // Set next flag to STORAGE_VAL
    _buffer.flag = Flag.STORAGE_VAL;
    bytes32 base_location = _arr.ref();
    bytes memory buff = _buffer.buffer;
    bytes memory to_store;
    assembly {
      // Get reference to the array to store
      to_store := mload(add(0x20, _buffer))
      // Get size of buffer, plus 0x20 bytes
      let size := add(0x20, mload(buff))
      // Loop over the bytes array and push each value to storage buffer
      let offset := 0x0
      for { } lt(offset, add(0x20, mload(to_store))) { offset := add(0x20, offset) } {
        // Push bytes array chunk to buffer
        mstore(add(add(size, mul(2, offset)), buff), mload(add(offset, to_store)))
        // Push incremented location to buffer
        mstore(add(add(add(0x20, size), mul(2, offset)), buff), add(offset, base_location))
      }
      // Increment buffer length
      mstore(buff, add(mul(2, offset), mload(buff)))
      // Increase length of STORES action within buffer
      mstore(
        mload(add(0x20, _buffer)),
        add(div(offset, 0x20), mload(mload(add(0x20, _buffer))))
      )
      // Ensure the free memory pointer is pointing outside of the buffer
      if iszero(gt(mload(0x40), add(buff, add(0x20, mload(buff))))) {
        mstore(0x40, add(buff, add(0x20, mload(buff))))
      }
    }
    // Set Buffer ptr to 0
    _buffer.ptr = 0;
  } */
}
