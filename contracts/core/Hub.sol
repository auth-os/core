pragma solidity ^0.4.23;

import "../interfaces/IHub.sol";

contract Hub is IHub {

  /// STATE VARS ///
  bytes32 private exec_id;
  address private sender;
  uint private nonce;

  /// PERMISSIONS ///

  // mapping (bytes32 => mapping (address => bool))
  bytes32 internal constant EXEC_PERMISSIONS = keccak256('script_exec_permissions');
  // mapping (bytes32 => mapping (bytes4 => address))
  bytes32 internal constant IMPLEMENTATIONS = keccak256('implementation');

  /// ACTION REQUESTORS ///
  bytes4 internal constant STORE = bytes4(keccak256('Store()')); // Store
  bytes4 internal constant CALL_CONTRACT = bytes4(keccak256('Call()')); // Ext call
  bytes4 internal constant SAFE_EXECUTE = bytes4(keccak256('Execute()')); // FRD
  bytes4 internal constant CREATE_INSTANCE = bytes4(keccak256('CreateInstance()'));
  bytes4 internal constant RETURN_DATA = bytes4(keccak256('Return()'));

  /// INTERNAL FUNCTIONS ///
  function handleReturn(bytes32 _exec_id) internal returns (bytes memory return_data);
  function store(bytes32 _exec_id, bytes32 _location, bytes32 _value) internal;
  function getTarget(bytes32 _exec_id, bytes4 _selector) internal returns (address target);
  function getAction(/*TODO params*/) internal returns (bytes4 action);
  function getLength(/*TODO params*/) internal returns (uint length);
  function doStore(/*TODO params*/) internal;
  function doCall(/*TODO params*/) internal;
  function doExec(/*TODO params*/) internal;
  function doCreate(/*TODO params*/) internal;
  function doReturn(/*TODO params*/) internal pure returns (bytes memory data);
}
