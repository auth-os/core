pragma solidity ^0.4.23;

contract IHub {
  /// EVENTS ///
  event Initialize(bytes32 indexed initializer, bytes32 new_execution_id);
  /// STATEFUL FUNCTIONS ///
  function createInstance(address _sender, address _target, bytes memory _calldata) public payable returns (bytes[] memory data);
  function exec(address _sender, bytes32 _exec_id, bytes memory _calldata) public payable returns (bytes[] memory data);
  /// VIEW FUNCTIONS ///
  function read(bytes32 _exec_id, bytes32 _location) external view returns (bytes32 data);
  function readMulti(bytes32 _exec_id, bytes32[] _location) external view returns (bytes32[] data);
  function execRead(address _sender, bytes32 _exec_id, bytes _calldata) external view returns (bytes data);
}
