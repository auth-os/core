pragma solidity ^0.4.24;

/**
 * @title CommandsLib
 * @dev Handles the execution of applications using a safe delegatecall, and
 * provides an iterator for the reverted commands
 */
library CommandsLib {

  struct CommandIterator {
    uint cur;
    bytes[] commands;
  }

  /**
   * @dev Delegatecalls a target address with provided calldata and enforces a revert,
   * then returns the reverted data as a CommandIterator
   * @param _target The address to which the calldata will be delegatecalled
   * @param _calldata The data to send to the target address
   * @return iter A struct representing the data reverted by the target application
   */
  function safeDelegateCall(address _target, bytes memory _calldata) internal returns (CommandIterator memory iter) {
    // Safely delegatecall to the target
    require(_target.delegatecall(_calldata) == false, "Unsafe Execution");

    // Copy returndata to iter and return
    setReturnData(iter);
    return iter;
  }

  /**
   * @dev Copies returndata into CommandIterator bytes array
   * @param _iter A struct representing data reverted by the called application
   */
  function setReturnData(CommandIterator memory _iter) internal pure {
    assembly {
      // Get a pointer to the CommandIterator commands array
      let commands_ptr := add(0x20, _iter)
      // Set the pointer to free memory
      mstore(commands_ptr, mload(0x40))
      // Copy returndata to pointer
      returndatacopy(mload(commands_ptr), 0x20, sub(returndatasize, 0x20))
      // Update free memory pointer
      mstore(0x40, msize)
    }
  }

  /**
   * @dev Returns whether or not the iterator has another command to parse
   * @param _iter The CommandIterator struct
   * @return bool Whether the iterator has another command
   */
  function hasNext(CommandIterator memory _iter) internal pure returns (bool) {
    return _iter.commands.length > _iter.cur;
  }

  /**
   * @dev Increments the index pointer in the CommandIterator
   * @param _iter The iterator struct
   */
  function next(CommandIterator memory _iter) internal pure {
    _iter.cur++;
  }

  /**
   * FIXME - might be possible to force a read outside of returndata
   * @dev Interprets the data stored at the index as a bytes32[2][] and returns it
   * @param _iter The iterator struct
   * @return store_command A bytes32[2][] containing location-value pairs that was reverted by the application
   */
  function toStoreFormat(CommandIterator memory _iter) internal pure returns (bytes32[2][] memory store_command) {
    // Ensure data is not malformed - must be divisible by 64 bytes
    require(_iter.commands[_iter.cur].length % 64 == 0, "Expected store request");

    // Get a pointer to the length of the command and set store_command to point to it
    uint cmd_ptr = getPointer(_iter);
    assembly {
      store_command := cmd_ptr
      // Correct length - divide by 64
      mstore(store_command, div(mload(store_command), 64))
    }
  }

  /**
   * FIXME - might be possible to force a read outside of returndata
   * @dev Interprets the data stored at the current index as the parameters for the exec function
   * @param _iter The iterator struct
   * @return exec_id The execution id of the app to execute
   * @return calldata The calldata to send to the application
   */
  function toExecFormat(CommandIterator memory _iter) internal pure returns (bytes32 exec_id, bytes memory calldata) {
    // Ensure the returned data has sufficient length
    require(_iter.commands[_iter.cur].length > 100, "Expected exec request");

    // Get a pointer to the length of the command
    uint cmd_ptr = getPointer(_iter);
    assembly {
      exec_id := mload(add(0x40, cmd_ptr)) // Get exec_id from command
      calldata := add(0x60, cmd_ptr)       // Get calldata from command
    }
  }

  /**
   * FIXME - might be possible to force a read outside of returndata
   * @dev Interprets the data stored at the current index as the parameters for the doExtCall function
   * @param _iter The iterator struct
   * @return target The address to which the external call will be sent
   * @return amt_gas The amount of gas to send with the call
   * @return value The amount of wei to send with the call
   * @return exec_calldata The calldata to send with the call
   */
  function toExtCallFormat(CommandIterator memory _iter) internal pure
  returns (address target, uint amt_gas, uint value, bytes memory exec_calldata) {
    // Get a pointer to the length of the command
    uint cmd_ptr = getPointer(_iter);
    assembly {
      target := mload(add(0x40, cmd_ptr))
      amt_gas := mload(add(0x60, cmd_ptr))
      value := mload(add(0x80, cmd_ptr))
      exec_calldata := add(0xa0, cmd_ptr)
    }
  }

  /**
   * @dev Interprets the data stored at the current index as a bytes array and return it
   * @param _iter The iterator struct
   * @return bytes The bytes of data to be returned
   */
  function toReturnFormat(CommandIterator memory _iter) internal pure returns (bytes memory) {
    return _iter.commands[_iter.cur];
  }

  /**
   * @dev Gets a pointer to the command bytes at the current index
   * @param _iter The iterator struct
   * @return ptr A pointer to the command
   */
  function getPointer(CommandIterator memory _iter) internal pure returns (uint ptr) {
    // Calculate offset from index
    uint offset = 32 + (32 * _iter.cur);
    // Calculate pointer from offset and _iter
    assembly { ptr := add(offset, mload(add(0x20, _iter))) }
  }

  /**
   * @dev Returns the first 4 bytes of a passed-in array
   * @param _data The array
   * @return selector The first 4 bytes of the array
   */
  function getSelector(bytes memory _data) internal pure returns (bytes4 selector) {
    assembly { selector := mload(add(0x20, _data)) }
  }

  /**
   * @dev Returns the first 4 bytes of the current command
   * @param _iter The iterator struct
   * @return bytes4 The first 4 bytes of the current command
   */
  function getAction(CommandIterator memory _iter) internal pure returns (bytes4) {
    return getSelector(_iter.commands[_iter.cur]);
  }
}
