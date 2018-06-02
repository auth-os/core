pragma solidity ^0.4.23;

contract AbstractStorage {

  bytes32 private exec_id;
  address private sender;

  /* function () external payable { _exec(msg.data); } */

  // Keeps track of the number of applicaions initialized, so that each application has a unique execution id
  uint private nonce;

  /// CONSTANTS ///

  // ACTION REQUESTORS //

  bytes4 internal constant EMITS = bytes4(keccak256('emits:'));
  bytes4 internal constant STORES = bytes4(keccak256('stores:'));
  bytes4 internal constant PAYS = bytes4(keccak256('pays:'));
  bytes4 internal constant THROWS = bytes4(keccak256('throws:'));

  // OTHER //

  bytes internal constant DEFAULT_EXCEPTION = "DefaultException";

  /// APPLICATION EXECUTION ///

  /*
  ** Application execution follows a standard pattern:
  ** Application libraries are forwarded passed-in calldata via delegatecall.
  ** Application libraries are able to read from storage locally. In order to protect against
  ** malicious applications that might attempt to modify state, applications can only change
  ** state by reverting a formatted request back to the storage contract. This allows the
  ** storage contract to guaruntee that only safe state changes occur (for example, state
  ** changes that do not overwrite state from other applications).
  **
  ** As such, applications must tell the storage contract which of these events should
  ** occur upon successful execution so that the storage contract is able to handle them
  ** for the application library. This is done through the data returned by the application
  ** library. Returned data is formatted in such a way that the storage contract is able to
  ** parse the data and execute various actions.
  **
  ** Actions allowed are: EMITS, PAYS, STORES, and THROWS. More information on these is provided
  ** in the executeAppReturn function.
  */

  /*
  Executes an initialized application under a given execution id, with given logic target and calldata

  @param _target: The logic address for the application to execute. Passed-in calldata is forwarded here as a delegatecall, and the return value is parsed for executable actions.
  @param _exec_id: The application execution id under which action requests for this application are made
  @param _calldata: The calldata to forward to the application. Typically, this is created in the script exec contract and contains information about the original sender's address and execution id
  @mod validState(_exec_id): Ensures the application is active and unpaused, and that the sender is the script exec contract. Also ensures that if wei was sent, the app is registered as payable
  @return n_emitted: The number of events emitted on behalf of the application
  @return n_paid: The number of destinations ETH was forwarded to on behalf of the application
  @return n_stored: The number of storage slots written to on behalf of the application
  */
  function exec(address _target, bytes32 _exec_id, bytes _calldata) public payable validState(_exec_id) returns (uint n_emitted, uint n_paid, uint n_stored) {
    // Ensure valid input and input size - minimum 4 bytes
    require(_calldata.length >= 4 && _target != address(0) && _exec_id != bytes32(0));

    // Ensure sender is script executor for this exec id
    require(msg.sender == app_info[_exec_id].script_exec);

    // Ensure app logic address has been approved for this exec id
    require(allowed_addresses[_exec_id][_target] != 0);

    // Script executor and passed-in request are valid. Execute application and store return to this application's storage
    bool success;
    assembly {
      // Forward passed-in calldata to target contract
      success := delegatecall(gas, _target, add(0x20, _calldata), mload(_calldata), 0, 0)
    }
    // If the call to the application did not result in a revert, a state change may have occured: revert
    if (success) {
      revert('Unsafe execution');
    } else {
      (n_emitted, n_paid, n_stored) = executeAppReturn(_exec_id);
    }

    if (n_emitted == 0 && n_paid == 0 && n_stored == 0)
      revert('No state change occured');

    emit ApplicationExecution(_exec_id, _target);

    // If execution reaches this point, call should have reverted -
    assert(!success);
  }

  /// APPLICATION RETURNDATA HANDLING ///

  /*
  This function parses data returned by an application and executes requested actions. Because applications
  are assumed to be stateless, they cannot emit events, store data, or forward payment. Therefore, these
  steps to execution are handled in the storage contract by this function.

  Returned data can execute several actions requested by the application through the use of an 'action requestor':
  Some actions mirror nested dynamic return types, which are manually encoded and decoded as they are not supported
  1. THROWS  - App requests storage revert with a given message
      --Format: bytes
        --Payload is simply an array of bytes that will be reverted back to the caller
  2. EMITS   - App requests that events be emitted. Can provide topics to index, as well as arbitrary length data
      --Format: Event[]
        --Event format: [uint n_topics][bytes32 topic_0]...[bytes32 topic_n][uint data.length][bytes data]
  3. STORES  - App requests that data be stored to its storage. App storage locations are hashed with the app's exec id
      --Format: bytes32[]
        --bytes32[] consists of a data location followed by a value to place at that location
        --as such, its length must be even
        --Ex: [value_0][location_0]...[value_n][location_n]
  4. PAYS    - App requests that ETH sent to the contract be forwarded to other addresses.
      --Format: bytes32[]
        --bytes32[] consists of an address to send ETH to, followed by an amount to send to that address
        --As such, its length must be even
        --Ex: [amt_0][bytes32(destination_0)]...[amt_n][bytes32(destination_n)]

  Returndata is structured as an array of bytes, beginning with an action requestor ('THROWS', 'PAYS', etc)
  followed by that action's appropriately-formatted data (see above). Up to 3 actions with formatted data can be placed
  into returndata, and each must be unique (i.e. no two 'EMITS' actions).

  If the THROWS action is requested, it must be the first event requested. The event will be parsed
  and logged, and no other actions will be executed. If the THROWS requestor is not the first action
  requested, this function will throw

  @param _exec_id: The execution id which references this application's storage
  @return n_emitted: The number of events emitted on behalf of the application
  @return n_paid: The number of destinations ETH was forwarded to on behalf of the application
  @return n_stored: The number of storage slots written to on behalf of the application
  */
  function executeAppReturn(bytes32 _exec_id) internal returns (uint n_emitted, uint n_paid, uint n_stored) {
    uint _ptr;      // Will be a pointer to the data returned by the application call
    uint ptr_bound; // Will be the maximum value of the pointer possible (end of the memory stored in the pointer)
    (ptr_bound, _ptr) = getReturnedData();
    // Ensure there are at least 32 bytes stored at the pointer
    require(ptr_bound >= _ptr + 32, 'Malformed returndata - invalid size');
    _ptr += 32;

    // Iterate over returned data and execute actions
    bytes4 action;
    while (_ptr <= ptr_bound && (action = getAction(_ptr)) != 0x0) {
      if (action == THROWS) {
        // If the action is THROWS and any other action has been executed, throw
        require(n_emitted == 0 && n_paid == 0 && n_stored == 0, 'Malformed returndata - THROWS out of position');
        // Execute THROWS request
        doThrow(_ptr);
        // doThrow should revert, so we should never reach this point
        assert(false);
      } else {
        if (action == EMITS) {
          // If the action is EMITS, and this action has already been executed, throw
          require(n_emitted == 0, 'Duplicate action: EMITS');
          // Otherwise, emit events and get amount of events emitted
          // doEmit returns the pointer incremented to the end of the data portion of the action executed
          (_ptr, n_emitted) = doEmit(_ptr, ptr_bound);
          // If 0 events were emitted, returndata is malformed: throw
          require(n_emitted != 0, 'Unfulfilled action: EMITS');
        } else if (action == STORES) {
          // If the action is STORES, and this action has already been executed, throw
          require(n_stored == 0, 'Duplicate action: STORES');
          // Otherwise, store data and get amount of slots written to
          // doStore increments the pointer to the end of the data portion of the action executed
          (_ptr, n_stored) = doStore(_ptr, ptr_bound, _exec_id);
          // If no storage was performed, returndata is malformed: throw
          require(n_stored != 0, 'Unfulfilled action: STORES');
        } else if (action == PAYS) {
          // If the action is PAYS, and this action has already been executed, throw
          require(n_paid == 0, 'Duplicate action: PAYS');
          // Otherwise, forward ETH and get amount of addresses forwarded to
          // doPay increments the pointer to the end of the data portion of the action executed
          (_ptr, n_paid) = doPay(_ptr, ptr_bound, _exec_id);
          // If no destinations recieved ETH, returndata is malformed: throw
          require(n_paid != 0, 'Unfulfilled action: PAYS');
        } else {
          // Unrecognized action requested. returndata is malformed: throw
          revert('Malformed returndata - unknown action');
        }
      }
    }
    assert(n_emitted != 0 || n_paid != 0 || n_stored != 0);
  }

  /*
  After validating that returned data is larger than 32 bytes, returns a pointer to the returned data
  in memory, as well as a pointer to the end of returndata in memory

  @return ptr_bounds: The pointer cannot be this value and be reading from returndata
  @return _returndata_ptr: A pointer to the returned data in memory
  */
  function getReturnedData() internal pure returns (uint ptr_bounds, uint _returndata_ptr) {
    assembly {
      // returndatasize must be minimum 96 bytes (offset, length, and requestor)
      if lt(returndatasize, 0x60) {
        mstore(0, 'Insufficient return size')
        revert(0, 0x20)
      }
      // Get memory location to which returndata will be copied
      _returndata_ptr := msize
      // Copy returned data to pointer location, starting with length
      returndatacopy(_returndata_ptr, 0x20, sub(returndatasize, 0x20))
      // Get maximum memory location value for returndata
      ptr_bounds := add(_returndata_ptr, sub(returndatasize, 0x20))
      // Set new free-memory pointer to point after the returndata in memory
      // Returndata is automatically 32-bytes padded
      mstore(0x40, add(0x20, ptr_bounds))
    }
  }

  /*
  Returns the value stored in memory at the pointer. Used to determine the size of fields in returned data

  @param _ptr: A pointer to some location in memory containing returndata
  @return length: The value stored at that pointer
  */
  function getLength(uint _ptr) internal pure returns (uint length) {
    assembly {
      length := mload(_ptr)
    }
  }

  // Executes the THROWS action, reverting any returned data back to the caller
  function doThrow(uint _ptr) internal pure {
    assert(getAction(_ptr) == THROWS);
    _ptr += 4;
    assembly {
      // The data following the action requestor is a bytes array with the data to be reverted to caller
      // The first 32 bytes is the size of the data -
      let size := mload(_ptr)
      revert(add(0x20, _ptr), size)
    }
  }

  /*
  Parses and executes a PAYS action copied from returndata and located at the pointer
  A PAYS action provides a set of addresses and corresponding amounts of ETH to send to those
  addresses. The sender must ensure the call has sufficient funds, or the call will fail
  PAYS actions follow a format of: [amt_0][address_0]...[amt_n][address_n]

  @param _ptr: A pointer in memory to an application's returned payment request
  @param _ptr_bound: The upper bound on the value for _ptr before it is reading invalid data
  @param _exec_id: The execution id of the application which triggered the payment
  @return ptr: An updated pointer, pointing to the end of the PAYS action request in memory
  @return n_paid: The number of destinations paid out to from the returned PAYS request
  */
  function doPay(uint _ptr, uint _ptr_bound, bytes32 _exec_id) internal returns (uint ptr, uint n_paid) {
    // Ensure ETH was sent with the call
    require(msg.value > 0);
    assert(getAction(_ptr) == PAYS);
    _ptr += 4;
    // Get number of destinations
    uint num_destinations = getLength(_ptr);
    _ptr += 32;
    address pay_to;
    uint amt;
    // Loop over PAYS actions and process each one
    while (_ptr <= _ptr_bound && n_paid < num_destinations) {
      // Get the payment destination and amount from the pointer
      assembly {
        amt := mload(_ptr)
        pay_to := mload(add(0x20, _ptr))
      }
      // Invalid address was passed as a payment destination - throw
      if (pay_to == address(0) || pay_to == address(this))
        revert('PAYS: invalid destination');

      // Forward ETH and increment n_paid
      address(pay_to).transfer(amt);
      n_paid++;
      // Increment pointer
      _ptr += 64;
      // Emit event
      emit DeliveredPayment(_exec_id, pay_to, amt);
    }
    ptr = _ptr;
    assert(n_paid == num_destinations);
  }

  /*
  Parses and executes a STORES action copied from returndata and located at the pointer
  A STORES action provides a set of storage locations and corresponding values to store at those locations
  true storage locations within this contract are first hashed with the application's execution id to prevent
  storage overlaps between applications sharing the contract
  STORES actions follow a format of: [val_0][location_0]...[val_n][location_n]

  @param _ptr: A pointer in memory to an application's returned payment request
  @param _ptr_bound: The upper bound on the value for _ptr before it is reading invalid data
  @param _exec_id: The execution id under which storage is located
  @return ptr: An updated pointer, pointing to the end of the STORES action request in memory
  @return n_paid: The number of storage locations written to from the returned PAYS request
  */
  function doStore(uint _ptr, uint _ptr_bound, bytes32 _exec_id) internal returns (uint ptr, uint n_stored) {
    assert(getAction(_ptr) == STORES && _exec_id != bytes32(0));
    _ptr += 4;
    // Get number of locations to which data will be stored
    uint num_locations = getLength(_ptr);
    _ptr += 32;
    bytes32 location;
    bytes32 value;
    // Loop over STORES actions and process each one
    while (_ptr <= _ptr_bound && n_stored < num_locations) {
      // Get storage location and value to store from the pointer
      assembly {
        value := mload(_ptr)
        location := mload(add(0x20, _ptr))
      }
      // Store the data to the location hashed with the exec id
      store(_exec_id, location, value);
      // Increment n_stored and pointer
      n_stored++;
      _ptr += 64;
    }
    ptr = _ptr;
    require(n_stored == num_locations);
  }

  /*
  Parses and executes an EMITS action copied from returndata and located at the pointer
  An EMITS action is a list of bytes that are able to be processed and passed into logging functions (log0, log1, etc)
  EMITS actions follow a format of: [Event_0][Event_1]...[Event_n]
    where each Event_i follows the format: [topic_0]...[topic_4][data.length]<data>
    -The topics array is a bytes32 array of maximum length 4 and minimum 0
    -The final data parameter is a simple bytes array, and is emitted as a non-indexed parameter

  @param _ptr: A pointer in memory to an application's returned payment request
  @param _ptr_bound: The upper bound on the value for _ptr before it is reading invalid data
  @return ptr: An updated pointer, pointing to the end of the EMITS action request in memory
  @return n_paid: The number of events logged from the returned EMITS request
  */
  function doEmit(uint _ptr, uint _ptr_bound) internal returns (uint ptr, uint n_emitted) {
    assert(getAction(_ptr) == EMITS);
    _ptr += 4;
    // Converts number of events that will be emitted
    uint num_events = getLength(_ptr);
    _ptr += 32;
    bytes32[] memory topics;
    bytes memory data;
    // Loop over EMITS actions and process each one
    while (_ptr <= _ptr_bound && n_emitted < num_events) {
      // Get array of topics and additional data from the pointer
      assembly {
        topics := _ptr
        data := add(add(_ptr, 0x20), mul(0x20, mload(topics)))
      }
      // Get size of the Event's data in memory
      uint log_size = 32 + (32 * (1 + topics.length)) + data.length;
      assembly {
        switch mload(topics)                // topics.length
          case 0 {
            // Log Event.data array with no topics
            log0(
              add(0x20, data),              // data(ptr)
              mload(data)                   // data.length
            )
          }
          case 1 {
            // Log Event.data array with 1 topic
            log1(
              add(0x20, data),              // data(ptr)
              mload(data),                  // data.length
              mload(add(0x20, topics))      // topics[0]
            )
          }
          case 2 {
            // Log Event.data array with 2 topics
            log2(
              add(0x20, data),              // data(ptr)
              mload(data),                  // data.length
              mload(add(0x20, topics)),     // topics[0]
              mload(add(0x40, topics))      // topics[1]
            )
          }
          case 3 {
            // Log Event.data array with 3 topics
            log3(
              add(0x20, data),              // data(ptr)
              mload(data),                  // data.length
              mload(add(0x20, topics)),     // topics[0]
              mload(add(0x40, topics)),     // topics[1]
              mload(add(0x60, topics))      // topics[2]
            )
          }
          case 4 {
            // Log Event.data array with 4 topics
            log4(
              add(0x20, data),              // data(ptr)
              mload(data),                  // data.length
              mload(add(0x20, topics)),     // topics[0]
              mload(add(0x40, topics)),     // topics[1]
              mload(add(0x60, topics)),     // topics[2]
              mload(add(0x80, topics))      // topics[3]
            )
          }
          default {
            // Events must have 4 or fewer topics
            mstore(0, 'EMITS: invalid topic count')
            revert(0, 0x20)
          }
      }
      // Event emitted - increment n_emitted and pointer
      n_emitted++;
      _ptr += log_size;
    }
    ptr = _ptr;
    require(n_emitted == num_events);
  }

  // Return the bytes4 action requestor stored at the pointer, and cleans the remaining bytes
  function getAction(uint _ptr) internal pure returns (bytes4 action) {
    assembly {
      // Get the first 4 bytes stored at the pointer, and clean the rest of the bytes remaining
      action := and(mload(_ptr), 0xffffffff00000000000000000000000000000000000000000000000000000000)
    }
  }

  /// APPLICATION UPGRADING ///

  /*
  ** Application initializers may specify an address which is allowed to update
  ** the logic addresses which may be used with the application. These addresses
  ** could be as simple as someone's personal address, or as complicated as
  ** voting contracts with safe upgrade mechanisms.
  */

  // The script exec contract can update itself
  function changeScriptExec(bytes32 _exec_id, address _new_script_exec) public {
    // Ensure that only the script exec contract can update itself
    require(app_info[_exec_id].script_exec == msg.sender);

    app_info[_exec_id].script_exec = _new_script_exec;
  }

  // Stores data to a given location, with a key (exec id)
  function store(bytes32 _exec_id, bytes32 _location, bytes32 _data) internal {
    // Get true location to store data to - hash of location hashed with exec id
    _location = keccak256(_location, _exec_id);
    assembly {
      // Store data
      sstore(_location, _data)
    }
  }
}
