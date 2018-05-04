pragma solidity ^0.4.23;

contract RegistryUtil {

  function registerApp(bytes32, address, bytes, bytes memory) public pure returns (bytes memory) {
    return msg.data;
  }

  function registerVersion(bytes32, bytes32, address, bytes, bytes memory) public pure returns (bytes memory) {
    return msg.data;
  }

  function finalizeVersion(bytes32, bytes32, address, bytes4, bytes) public pure returns (bytes memory) {
    return msg.data;
  }

  function addFunctions(bytes32, bytes32, bytes4[] memory,  address[] memory, bytes) public pure returns (bytes memory) {
    return msg.data;
  }
}
