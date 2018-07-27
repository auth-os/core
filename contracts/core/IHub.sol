pragma solidity ^0.4.23;

contract IHub {
  /// EVENTS ///
  event Initialize(bytes32 indexed initializer, bytes32 new_execution_id);
  /// STATEFUL FUNCTIONS ///
  function createInstance(bytes32 exec_as, address target, bytes memory calldata) public payable returns (bytes[] memory data);
  function exec(bytes32 exec_as, bytes32 exec_id, bytes memory calldata) public payable returns (bytes[] memory data);
  /// VIEW FUNCTIONS ///
  function read(bytes32 exec_id, bytes32 location) external view returns (bytes32 data);
  function readMulti(bytes32 exec_id, bytes32[] location) external view returns (bytes32[] data);
  function execRead(bytes32 read_as, bytes32 exec_id, bytes calldata) external view returns (bytes data);
}
