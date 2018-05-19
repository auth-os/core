pragma solidity ^0.4.23;

contract AppInitUtil {

  function init() public pure returns (bytes memory) { return msg.data; }

  function initInvalid() public pure returns (bytes memory) { return msg.data; }

  function initNullAction() public pure returns (bytes memory) { return msg.data; }

  function initThrowsAction() public pure returns (bytes memory) { return msg.data; }

  function initEmits(bytes32) public pure returns (bytes memory) { return msg.data; }

  function initPays(address, uint) public pure returns (bytes memory) { return msg.data; }

  function initStores(bytes32, bytes32) public pure returns (bytes memory) { return msg.data; }

  function parseInit(bytes memory _data) public pure returns (address exec, address updater) {
    assembly {
      exec := mload(add(0x20, _data))
      updater := mload(add(0x40, _data))
    }
  }
}
