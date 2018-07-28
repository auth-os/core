pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

import "./IHub.sol";
import "./ListLib.sol";
import "./CommandsLib.sol";

/**
 * @title Hub
 * @dev A basic storage contract for an application or group of applications
 */
contract Hub is IHub {

  using CommandsLib for *;
  using ListLib for *;

  /// STATE VARS ///
  bytes32 private exec_id;
  bytes32 private exec_as;
  uint private nonce;

  /// PERMISSIONS ///

  // mapping (bytes32 => mapping (bytes4 => address))
  bytes32 internal constant IMPLEMENTATIONS = keccak256("implementation");

  /// ACTION REQUESTORS ///
  bytes4 internal constant STORE = bytes4(keccak256("Store(bytes32[2][])")); // Store data
  bytes4 internal constant SAFE_EXECUTE = bytes4(keccak256("Execute(bytes32,bytes32,bytes)")); // Execute another app
  bytes4 internal constant RETURN_DATA = bytes4(keccak256("Return(bytes)")); // Return data
  bytes4 internal constant EXT_CALL = bytes4(keccak256("Call(address,uint256,uint256,bytes)")); // External call

  function createInstance(bytes32 _sender, bytes _calldata) external payable returns (bytes[] memory data);

  /**
   * @dev Executes an application and handles the returned commands
   * @param _exec_as The address or execution id by which the application will be executed
   * @param _exec_id The execution id of the application to execute
   * @param _calldata The calldata to forward to the application
   * @return bytes[] The data specified by the application to be returned to the caller
   */
  function exec(bytes32 _exec_as, bytes32 _exec_id, bytes memory _calldata) public payable returns (bytes[] memory) {
    // Input validation
    require(_exec_id != 0 && _calldata.length >= 4, "Input invalid");
    // Get execution target from calldata function selector
    address target = getTarget(_exec_id, _calldata.getSelector());
    // Ensure valid target for execution
    require(target != 0, "Application does not implement requested function");

    // Update the internal variables so the application has access to them
    exec_as = _exec_as;
    exec_id = _exec_id;

    // Execute application and retrieve commands from its returned data
    CommandsLib.CommandIterator memory iter = target.safeDelegateCall(_calldata);

    // Declare singly-linked list for returndata
    ListLib.LinkedList memory list;

    // Execute each command returned
    while (iter.hasNext()) {
      // Get 4-byte action from command
      bytes4 action = iter.getAction();

      if (action == STORE)
        doStore(iter.toStoreFormat(), _exec_id);          // Store data in this application
      else if (action == SAFE_EXECUTE)
        list.join(doExec(iter.toExecFormat()));           // Have the current application execute another application
      else if (action == RETURN_DATA)
        list.append(iter.toReturnFormat());               // Add to the data to be returned
      else
        revert("Invalid Command");                        // Invalid command - revert

      // Move Iterator pointer to the next command
      iter.next();
    }
    // Transfer Hub balance to caller (Ether should not be in this contract)
    msg.sender.transfer(address(this).balance);
    // Return data to caller and end execution
    return list.toArray();
  }

  /**
   * @dev Handles a doStore Command
   * @param _store_arr An array with each location and value to store to ([location][value][location][value]...)
   * @param _exec_id The execution id of the application
   */
  function doStore(bytes32[2][] memory _store_arr, bytes32 _exec_id) internal {
    // Executes store for each location-value pair
    for (uint i = 0; i < _store_arr.length; i++)
      store(_exec_id, _store_arr[i][0], _store_arr[i][1]);
  }

  /**
   * @dev Stores a value at a specific location under the given execution id
   * @param _exec_id The execution id of the application
   * @param _location The location to store at
   * @param _value The value to store
   */
  function store(bytes32 _exec_id, bytes32 _location, bytes32 _value) internal {
    // Obtain the actual location to store _value at
    bytes32 loc = keccak256(abi.encodePacked(_location, _exec_id));
    // Store _value at this hashed location
    assembly { sstore(loc, _value) }
  }

  /**
   * @dev Executes a callback into another application as the current application
   * @param _exec_as The executor of the application
   * @param _exec_id The execution id of the application which will be called
   * @param _calldata The calldata to forward to the application
   * @return bytes[] The data returned by the executed application
   */
  function doExec(bytes32 _exec_as, bytes32 _exec_id, bytes memory _calldata) internal returns (bytes[] memory) {
    return exec(_exec_as, _exec_id, _calldata);
  }

  /// INTERNAL FUNCTIONS ///
  function getTarget(bytes32 _exec_id, bytes4 _selector) internal returns (address target);
}
