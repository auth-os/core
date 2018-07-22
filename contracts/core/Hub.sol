pragma solidity ^0.4.23;
pragma experimental ABIEncoderV2;

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
  bytes4 internal constant STORE = bytes4(keccak256('Store(bytes32[2][])')); // Store data
  bytes4 internal constant SAFE_EXECUTE = bytes4(keccak256('Execute(address,bytes32,bytes)')); // Execute another app
  bytes4 internal constant CREATE_INSTANCE = bytes4(keccak256('CreateInstance(address,address,bytes)')); // Create an instance of an app
  bytes4 internal constant RETURN_DATA = bytes4(keccak256('Return(bytes)')); // Return data

  /**
   * @dev Executes an application and handles the returned commands
   * @param _sender The address reported to be the sender by the caller
   * @param _exec_id The execution id of the application to execute
   * @param _calldata The calldata to forward to the application
   * @return data The data specified by the application to be returned to the caller
   */
  function exec(address _sender, bytes32 _exec_id, bytes memory _calldata) public payable returns(bytes[] memory data){
    // Input validation
    require(_exec_id != 0 && _calldata.length >= 4, "Input invalid");
    // Get execution target from calldata function selector
    address target = getTarget(_exec_id, _calldata.getSelector());
    // Ensure valid target for execution
    require(target != 0, "Application does not implement requested function");

    // Update the internal variables so the application has access to them
    sender = _sender;
    exec_id = _exec_id;

    // Execute application and retrieve commands from its returned data
    Command[] memory commands = target.safeDelegateCall(_calldata);

    // Execute each command returned
    for(uint i = 0; i < commands.length; i++) {
      if(commands[i].type == STORE)
        doStore(commands[i], _exec_id);                 // Store data in this application
      else if(commands[i].type == SAFE_EXECUTE)
        data.join(doExec(commands[i]));                 // Execute another function in this application
      else if(commands[i].type == CREATE_INSTANCE)
        doCreate(commands[i], _exec_id);                // Create a new application instance
      else if(commands[i].type == RETURN_DATA)
        data.append(doReturn(commands[i]));             // Add to the data to be returned
      else
        revert("Error: Invalid Command");               // Invalid command - revert
    }
    // Transfer Hub balance to caller (Ether should not be in this contract)
    msg.sender.transfer(address(this).balance);
    // Return data to caller and end execution
    return data;
  }

  /**
   * @dev Handles a doStore Command
   * @param _command The command struct holding the data to handle
   * @param _exec_id The execution id of the application
   */
  function doStore(Command memory _command, bytes32 _exec_id) internal {
    // Obtains locations and values to store
    bytes32[2][] memory store_info_arr = _command.data.toStoreFormat();
    // Executes store for each location-value pair
    for (uint i = 0; i < store_info_arr.length; i++)
      store(_exec_id, store_info_arr[i][0], store_info_arr[i][1]);
  }

  /**
   * @dev Stores a value at a specific location under the given execution id
   * @param _exec_id The execution id of the application
   * @param _location The location to store at
   * @param _value The value to store
   */
  function store(bytes32 _exec_id, bytes32 _location, bytes32 _value) internal {
    // Obtain the actual location to store _value at
    bytes32 loc = keccak256(_location, _exec_id);
    // Store _value at this hashed location
    assembly { sstore(loc, _value) }
  }

  /**
   * @dev Executes a callback into another application
   * @param _command The command struct holding the data to handle
   * @return data The data returned by the executed application
   */
  function doExec(Command memory _command) internal returns (bytes[] memory data) {
    address sender;
    bytes32 exec_id;
    bytes memory exec_calldata;
    // Parse the sender, execution id, and execution calldata from the command struct
    (sender, exec_id, exec_calldata) = _command.data.toExecFormat();
    // Execute the application and return its data
    data = exec(sender, exec_id, exec_calldata);
    return data;
  }

  /**
   * @dev Creates an instance of another application
   * @param _command The command struct holding the data to handle
   * @param _exec_id The execution id of the application
   * @return data The data returned by the created instance
   */
  function doCreate(Command memory _command, bytes32 _exec_id) internal returns (bytes[] memory data) {
    address sender;
    address target;
    bytes memory create_calldata;
    // Parse the sender, target address, and creation calldata from the command struct
    (sender, target, create_calldata) = _command.data.toCreateFormat();
    // Create the application instance and return its data
    data = createInstance(sender, target, create_calldata);
    return data;
  }

  /**
   * @dev Extracts the data to be returned
   * @param _command The command struct holding the data to handle
   * @return data The return data extracted from the command struct
   */
  function doReturn(Command memory _command) internal pure returns (bytes memory data) {
    // Extract and return the data from the command struct
    data = _command.data;
    return data;
  }



  /// INTERNAL FUNCTIONS ///
  function getTarget(bytes32 _exec_id, bytes4 _selector) internal returns (address target);
}
