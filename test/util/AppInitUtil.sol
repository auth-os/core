pragma solidity ^0.4.23;

contract AppInitUtil {

  function init() public pure returns (bytes memory) { return msg.data; }

  function initInvalid() public pure returns (bytes memory) { return msg.data; }

  function initPayment() public pure returns (bytes memory) { return msg.data; }

  function initValidSingle(bytes32, bytes32) public pure returns (bytes memory) { return msg.data; }

  function initValidMulti(bytes32, bytes32, bytes32, bytes32) public pure returns (bytes memory) { return msg.data; }
}
