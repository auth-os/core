pragma solidity ^0.4.21;

import "../../contracts/core/AbstractStorage.sol";


contract AbstractStorageMock is AbstractStorage {

  function mockPayoutCalldata(address _pay_to, uint _amt) public pure returns (bytes memory calldata) {
    _pay_to;
    _amt;
    bytes4 selector = bytes4(keccak256('payout(address,uint256)'));
    calldata = new bytes(68);
    assembly {
      mstore(add(0x20, calldata), selector)
      calldatacopy(add(0x24, calldata), 0x04, sub(calldatasize, 0x04))
    }
  }

  function mockPayoutAndStoreCalldata(address _pay_to, uint _amt) public pure returns (bytes memory calldata) {
    _pay_to;
    _amt;
    bytes4 selector = bytes4(keccak256('payoutAndStore(address,uint256)'));
    calldata = new bytes(68);
    assembly {
      mstore(add(0x20, calldata), selector)
      calldatacopy(add(0x24, calldata), 0x04, sub(calldatasize, 0x04))
    }
  }

  function mockGetPaymentInfo(bytes _in) public pure returns (uint amt, address dest) {
    require(_in.length == 64);
    assembly {
      amt := mload(add(0x20, _in))
      dest := mload(add(0x40, _in))
    }
  }

  function mockGetStoreSingleCalldata(uint _val) public pure returns (bytes memory calldata) {
    calldata = new bytes(36);
    bytes4 selector = bytes4(keccak256('storeSingle(uint256)'));
    assembly {
      mstore(add(0x20, calldata), selector)
      mstore(add(0x24, calldata), _val)
    }
  }

  function mockGetStoreMultiCalldata(uint _val) public pure returns (bytes memory calldata) {
    calldata = new bytes(36);
    bytes4 selector = bytes4(keccak256('storeMulti(uint256)'));
    assembly {
      mstore(add(0x20, calldata), selector)
      mstore(add(0x24, calldata), _val)
    }
  }

  function mockGetStoreVariableCalldata(uint _amt, uint _val) public pure returns (bytes memory calldata) {
    calldata = new bytes(68);
    bytes4 selector = bytes4(keccak256('storeVariable(uint256,uint256)'));
    assembly {
      mstore(add(0x20, calldata), selector)
      mstore(add(0x24, calldata), _amt)
      mstore(add(0x44, calldata), _val)
    }
  }

  function mockGetStoreInvalidCalldata() public pure returns (bytes memory calldata) {
    calldata = new bytes(4);
    bytes4 selector = bytes4(keccak256('storeInvalid()'));
    assembly {
      mstore(add(0x20, calldata), selector)
    }
  }

  function addToBytes32(bytes32 _in) public pure returns (bytes32) {
    return bytes32(32 + uint(_in));
  }
}
