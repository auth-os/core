pragma solidity ^0.4.23;

interface IHub {
  /// EVENTS ///
  event Send(bytes32 indexed execution_id, address indexed destination, address indexed sender, uint value);
  event Initialize(bytes32 indexed initializer, bytes32 new_execution_id);
  /// STATEFUL FUNCTIONS ///
  function createInstance(address _sender, address _target, bytes _calldata) external payable returns (bytes32 new_exec_id, bytes data);
  function exec(address _sender, bytes32 _exec_id, bytes _calldata) external payable returns (bytes data);
  /// VIEW FUNCTIONS ///
  function read(bytes32 _exec_id, bytes32 _location) external view returns (bytes32 data);
  function readMulti(bytes32 _exec_id, bytes32[] _location) external view returns (bytes32[] data);
  function execRead(address _sender, bytes32 _exec_id, bytes _calldata) external view returns (bytes data);
}
