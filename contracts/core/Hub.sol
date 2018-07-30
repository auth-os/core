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

  /* Public Functions */

  /**
   * @dev Creates an exec_id then exeuctes calldata via that exec id
   * @param _exec_as The address or execution id by which the application will be executed
   * @param _target The address which holds the app logic
   * @param _calldata The calldata to forward to the application
   * @return bytes[] The data specified by the application to be returned to the caller
   */
  function createInstance(bytes32 _exec_as, address _target, bytes _calldata) external payable returns (bytes[] memory){
    // Input validation
    require(_target != 0 && _calldata.length >= 4, "Input invalid");
    // Calculate new execution id
    bytes32 new_exec_id = keccak256(abi.encodePacked(++nonce, address(this)));
    // Emits the Initialize event
    emit Initialize(_exec_as, new_exec_id);

    // Call the internal exec function
    return execProtected(_exec_as, new_exec_id, _target, _calldata);
  }

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

    // Call the internal exec function
    return execProtected(_exec_as, _exec_id, target, _calldata);
  }

  function read(bytes32 _exec_id, bytes32 _location) public view returns (bytes32 data);

  function readMulti(bytes32 _exec_id, bytes32[] memory _locations) public view returns (bytes32[] memory data);

  function execRead(bytes32 _read_as, bytes32 _exec_id, bytes memory _calldata) public view returns (bytes[] memory data);

  /* Internal Functions */

  /**
   * @dev Internal exec function. Contains the logic for executing an application
   * @param _exec_as The address or execution id by which the application is being executed
   * @param _exec_id The execution id of the application to execute
   * @param _target The target address to execute for the application
   * @param _calldata The calldata to forward to the application
   * @return bytes[] The data returned by the application call or calls
   */
  function execProtected(bytes32 _exec_as, bytes32 _exec_id, address _target, bytes memory _calldata) internal returns (bytes[] memory) {
    // Set state variables
    exec_as = _exec_as;
    exec_id = _exec_id;

    // Execute application and retrieve commands from its returned data
    CommandsLib.CommandIterator memory iter = _target.safeDelegateCall(_calldata);

    // Declare singly-linked list for returndata
    ListLib.LinkedList memory list;

    // Execute each command returned
    while (iter.hasNext()) {
      // Get 4-byte action from command
      bytes4 action = iter.getAction();

      // TODO implement ERROR handling
      if (action == STORE) {
        doStore(iter.toStoreFormat(), _exec_id);
      } else if (action == SAFE_EXECUTE) {
        (bytes32 target_exec_id, bytes memory exec_calldata)
            = iter.toExecFormat();
        list.join(doExec(_exec_id, target_exec_id, exec_calldata));
      } else if (action == EXT_CALL) {
        (address target, uint amt_gas, uint value, bytes memory ext_calldata)
            = iter.toExtCallFormat();
        doExtCall(target, amt_gas, value, ext_calldata);
      } else if (action == RETURN_DATA) {
        list.append(iter.toReturnFormat());
      } else {
        revert("Invalid Command");
      }

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
   * @dev Executes a callback into another application as the current application
   * @param _exec_as The executor of the application
   * @param _exec_id The execution id of the application which will be called
   * @param _calldata The calldata to forward to the application
   * @return bytes[] The data returned by the executed application
   */
  function doExec(bytes32 _exec_as, bytes32 _exec_id, bytes memory _calldata) internal returns (bytes[] memory) {
    return exec(_exec_as, _exec_id, _calldata);
  }

  /**
   * @dev Allow an application to perform an external call. Enforces success and ignores return
   * @param _target The target address to call
   * @param _gas The amount of gas to send with the call
   * @param _value The amount of ETH to send with the call
   * @param _calldata The data to send with the call
   */
  function doExtCall(address _target, uint _gas, uint _value, bytes memory _calldata) internal {
    require(_target.call.value(_value).gas(_gas)(_calldata), "External call failed");
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
   * @dev Gets the target address for an exec id and function selector
   * @param _exec_id  The exec id
   * @param _selector The function _selector
   * @return address The address of the appliciation logic
   */
  function getTarget(bytes32 _exec_id, bytes4 _selector) internal view returns (address) {
    return address(read(_exec_id, keccak256(abi.encodePacked(_selector, IMPLEMENTATIONS))));
  }
}
