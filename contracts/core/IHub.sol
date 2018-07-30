pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

contract IHub {
  /// STATE VARS ///
  bytes32 exec_id;
  bytes32 exec_as;
  uint nonce;

  /// CONSTANTS ///
  bytes32 constant IMPLEMENTATIONS = keccak256("implementation");
  bytes4 constant ERROR = bytes4(keccak256("Error(string)"));
  bytes4 constant RETURN_DATA = bytes4(keccak256("Return(bytes)"));
  bytes4 constant STORE = bytes4(keccak256("Store(bytes32[2][])"));
  bytes4 constant SAFE_EXECUTE = bytes4(keccak256("Execute(bytes32,bytes32,bytes)"));
  bytes4 constant EXT_CALL = bytes4(keccak256("Call(address,uint256,uint256,bytes)"));

  /// EVENTS ///
  event Initialize(bytes32 indexed initializer, bytes32 new_execution_id);

  /// STATEFUL FUNCTIONS ///
  function createInstance(bytes32 _exec_as, address _target, bytes _calldata) external payable returns (bytes[] memory data);
  function exec(bytes32 _exec_as, bytes32 _exec_id, bytes memory _calldata) public payable returns (bytes[] memory data);
  /// VIEW FUNCTIONS ///
  function read(bytes32 _exec_id, bytes32 _location) public view returns (bytes32 data);
  function readMulti(bytes32 _exec_id, bytes32[] memory _locations) public view returns (bytes32[] memory data);
  function execRead(bytes32 _read_as, bytes32 _exec_id, bytes memory _calldata) public view returns (bytes[] memory data);
}
