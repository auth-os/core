pragma solidity ^0.4.23;

contract TestUtils {

  function getContextFromAddr(bytes32 _exec_id, address _sender, uint _val) public pure returns (bytes context) {
    context = new bytes(96);
    assembly {
      mstore(add(0x20, context), _exec_id)
      mstore(add(0x40, context), _sender)
      mstore(add(0x60, context), _val)
    }
  }

  function getContext(bytes32 _exec_id, bytes32 _sender, uint _val) public pure returns (bytes context) {
    context = new bytes(96);
    assembly {
      mstore(add(0x20, context), _exec_id)
      mstore(add(0x40, context), _sender)
      mstore(add(0x60, context), _val)
    }
  }

  function getInvalidContext(bytes32 _exec_id, address _sender, uint _val) public pure returns (bytes memory context) {
    context = new bytes(95); // Invalid length
    assembly {
      mstore(add(0x20, context), _exec_id)
      mstore(add(0x40, context), _sender)
      mstore(add(0x60, context), _val)
    }
  }

  function getAppProviderHash(address _provider) public pure returns (bytes32 provider) {
    provider = keccak256(bytes32(_provider));
  }

  function parseStorageExceptionData(bytes memory _data) public pure returns (address sender, uint wei_sent) {
    require(_data.length == 64);
    assembly {
      sender := mload(add(0x20, _data))
      wei_sent := mload(add(0x40, _data))
    }
  }
}
