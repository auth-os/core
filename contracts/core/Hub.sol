pragma solidity ^0.4.23;

import "./IHub.sol";

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

  /**
   * @dev Executes an application and handles the returned commands
   * @param _sender The address reported to be the sender by the caller
   * @param _exec_id The execution id of the application to execute
   * @param _calldata The calldata to forward to the application
   * @return data The data specified by the application to be returned to the caller
   */
  function exec(address _sender, bytes32 _exec_id, bytes _calldata) external payable returns(bytes memory data){
     // Input validation
    require(_exec_id != 0 && _calldata.length >= 4, "Imput invalid");
    // Get execution target from calldata function selector
    address target = getTarget(_exec_id, _calldata.getSelector());
    // Ensure valid target for execution
    require(target != 0, "Application does not implement requested function");

    // Update the internal variables so the application has access to them
    sender = _sender;
    exec_id = _exec_id;

    // Execute application and retrieve commands from its returned data
    Command[] memory commands = target.safeDelegateCall( _calldata);

    // Execute each command returned
    for(uint i = 0; i < commands.length; i++) {
      if(commands[i].type == STORE)
        doStore(commands, i, _exec_id);                 // Store data in his application
      else if(commands[i].type == CALL_CONTRACT)
        doCall(commands, i, _exec_id);                  // Call an external address
      else if(commands[i].type == SAFE_EXECUTE)
        doExec(commands, i, _exec_id);                  // Execute another function in this application
      else if(commands[i].type == CREATE_INSTANCE)
        doCreate(commands, i, _exec_id);                // Create a new application instance
      else if(commands[i].type == RETURN_DATA)
        data.append(doReturn(commands, i, _exec_id));   // Add to the data to be returned
      else
        revert("Error: Invalid Command");               // Invalid command - revert
    }

    // Transfer Hub balance to caller (Ether should not be in this contract)
    msg.sender.transfer(address(this).balance);
    // Return data to caller and end execution
    return data;
  }

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
