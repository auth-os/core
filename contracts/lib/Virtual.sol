pragma solidity ^0.4.23;

import "./Context.sol";

library Virtual {

  // Custom

  struct Struct {
    bytes32 base_storage;
    Context.Ctx context;
    uint class;
  }

  struct Array {
    bytes32 base_storage;
    Context.Ctx context;
    uint class;
  }

  // Primitive

  struct Bytes {
    bytes32 base_storage;
    Context.Ctx context;
    bytes value;
  }

  struct Bytes4 {
    bytes32 base_storage;
    Context.Ctx context;
    bytes4 value;
  }

  struct Bytes32 {
    bytes32 base_storage;
    Context.Ctx context;
    bytes32 value;
  }

  struct Address {
    bytes32 base_storage;
    Context.Ctx context;
    address value;
  }

  struct Uint256 {
    bytes32 base_storage;
    Context.Ctx context;
    uint256 value;
  }

  struct Bool {
    bytes32 base_storage;
    Context.Ctx context;
    bool value;
  }

  function read(bytes32 _location, Context.Ctx memory _ctx) internal view returns (bytes32 value) {
    if (_ctx.exec_id == bytes32(0) || _ctx.sender == bytes32(0))
      Errors.except('Error at Virtual.read: invalid context');

    assembly {
      mstore(0, _location)
      mstore(0x20, mload(_ctx))
      value := sload(keccak256(0, 0x40))
    }
    return value;
  }

  function length(Array memory _ref) internal view returns (uint) {
    return uint(read(_ref.base_storage, _ref.context));
  }

  /* function read(Bytes memory _ref) internal view returns (bytes memory) {
    TODO
  } */

  function length(Bytes memory _ref) internal view returns (uint) {
    return uint(read(_ref.base_storage, _ref.context));
  }

  function read(Bytes4 memory _ref) internal view returns (bytes4) {
    _ref.value = bytes4(read(_ref.base_storage, _ref.context));
    return _ref.value;
  }

  function read(Bytes32 memory _ref) internal view returns (bytes32) {
    _ref.value = bytes32(read(_ref.base_storage, _ref.context));
    return _ref.value;
  }

  function read(Address memory _ref) internal view returns (address) {
    _ref.value = address(read(_ref.base_storage, _ref.context));
    return _ref.value;
  }

  function read(Uint256 memory _ref) internal view returns (uint256) {
    _ref.value = uint256(read(_ref.base_storage, _ref.context));
    return _ref.value;
  }

  function read(Bool memory _ref) internal view returns (bool) {
    _ref.value = read(_ref.base_storage, _ref.context) == bytes32(0)
                    ? false : true;
    return _ref.value;
  }
}
