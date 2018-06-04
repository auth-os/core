pragma solidity ^0.4.23;

contract AbstractStorage {

  // Special storage locations - applications can read from 0x0 to get the execution id, and 0x20
  // to get the sender from which the call originated
  bytes32 private exec_id;
  address private sender;

  // Keeps track of the number of applicaions initialized, so that each application has a unique execution id
  uint private nonce;

  /// CONSTANTS ///

  // ACTION REQUESTORS //

  bytes4 internal constant EMITS = bytes4(keccak256('Emit((bytes32[],bytes)[])'));
  bytes4 internal constant STORES = bytes4(keccak256('Store(bytes32[])'));
  bytes4 internal constant PAYS = bytes4(keccak256('Pay(bytes32[])'));
  bytes4 internal constant THROWS = bytes4(keccak256('Error(string)'));

  // Used as a nonzero 'invalid' value, which will represent the exec id in the case that the application should
  // treat the input as an instance initialization
  bytes32 internal constant INVALID = bytes32(0xDEAD);

  /// APPLICATION INSTANCE INITIALIZATION ///

  /*
  Executes an initialization function of an application, generating a new exec id that will be associated with that address

  @param _sender: The sender of the transaction, as reported by the script exec contract
  @param _application: The target application to which the calldata will be forwarded
  @param _calldata: The calldata to forward to the application
  @return new_exec_id: A new, unique execution id paired with the created instance of the application
  */
  function createInstance(address _sender, address _application, bytes _calldata) external payable returns (bytes32 new_exec_id) {
    // Ensure valid input -
    require(_sender != address(0) && _application != address(0) && _calldata.length >= 4);

    // Create new exec id by incrementing the nonce -
    new_exec_id = keccak256(++nonce);

    // Sanity check - verify that this exec id is not linked to an existing application -
    assert(getTarget(new_exec_id) == address(0));

    // Set the exec id and sender addresses for the target application -
    setContext(INVALID, _sender);

    // Execute application, create a new exec id, and commit the returned data to storage -
    require(address(_application).delegatecall(_calldata) == false, 'Unsafe execution');
    // Get data returned from call revert and perform requested actions -
    executeAppReturn(new_exec_id);

    // Set the targeted application address as the new target for the created exec id -
    setTarget(new_exec_id, _application);

    // If execution reaches this point, newly generated exec id should be valid -
    assert(new_exec_id != bytes32(0));
  }

  /// APPLICATION EXECUTION ///

  /*
  Executes an initialized application associated with the given exec id, under the sender's address and with
  the given calldata

  @param _sender: The address reported as the call sender by the script exec contract
  @param _exec_id: The execution id corresponding to an instance of the application
  @param _calldata: The calldata to forward to the application
  @return n_emitted: The number of events emitted on behalf of the application
  @return n_paid: The number of destinations ETH was forwarded to on behalf of the application
  @return n_stored: The number of storage slots written to on behalf of the application
  */
  function exec(address _sender, bytes32 _exec_id, bytes _calldata) external payable returns (uint n_emitted, uint n_paid, uint n_stored) {
    // Ensure valid input and input size - minimum 4 bytes
    require(_calldata.length >= 4 && _sender != address(0) && _exec_id != bytes32(0));

    // Get the target address associated with the given exec id
    address target = getTarget(_exec_id);
    require(target != address(0), 'Uninitialized application');

    // Set the exec id and sender addresses for the target application -
    setContext(_exec_id, _sender);

    // Execute application and commit returned data to storage -
    require(address(target).delegatecall(_calldata) == false, 'Unsafe execution');
    (n_emitted, n_paid, n_stored) = executeAppReturn(_exec_id);

    // If no events were emitted, no wei was forwarded, and no storage was changed, revert -
    if (n_emitted == 0 && n_paid == 0 && n_stored == 0)
      revert('No state change occured');
  }

  // Given an exec id, returns the application address associated with that id
  function getTarget(bytes32 _exec_id) public view returns (address target) {
    assembly {
      // Clear first 32 bytes, then place the exec id in the next slot in memory
      mstore(0, 0)
      mstore(0x20, _exec_id)
      // An execution id's associated address is stored at the hash of '0' and the exec id
      target := sload(keccak256(0, 0x40))
    }
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
          (_ptr, n_paid) = doPay(_ptr, ptr_bound);
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
    assembly { length := mload(_ptr) }
  }

  // Executes the THROWS action, reverting any returned data back to the caller
  function doThrow(uint _ptr) internal pure {
    assert(getAction(_ptr) == THROWS);
    assembly {
      // The data following the action requestor is a bytes array with the data to be reverted to caller
      // The size of the error is located before the pointer -
      let size := mload(sub(_ptr, 0x20))
      revert(_ptr, size)
    }
  }

  /*
  Parses and executes a PAYS action copied from returndata and located at the pointer
  A PAYS action provides a set of addresses and corresponding amounts of ETH to send to those
  addresses. The sender must ensure the call has sufficient funds, or the call will fail
  PAYS actions follow a format of: [amt_0][address_0]...[amt_n][address_n]

  @param _ptr: A pointer in memory to an application's returned payment request
  @param _ptr_bound: The upper bound on the value for _ptr before it is reading invalid data
  @return ptr: An updated pointer, pointing to the end of the PAYS action request in memory
  @return n_paid: The number of destinations paid out to from the returned PAYS request
  */
  function doPay(uint _ptr, uint _ptr_bound) internal returns (uint ptr, uint n_paid) {
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
    }
    ptr = _ptr;
    assert(n_paid == num_destinations);
  }

  /*
  Parses and executes a STORES action copied from returndata and located at the pointer
  A STORES action provides a set of storage locations and corresponding values to store at those locations
  true storage locations within this contract are first hashed with the application's execution id to prevent
  storage overlaps between applications sharing the contract
  STORES actions follow a format of: [location_0][val_0]...[location_n][val_n]

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
        location := mload(_ptr)
        value := mload(add(0x20, _ptr))
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

  // Used by the createInstance function to associate a target with an execution id
  // The instance's associated address is stored at the hash of the execution id -
  // This means that the instance is able to incorporate upgradability features and change
  // its own target address
  function setTarget(bytes32 _exec_id, address _target) internal {
    assembly {
      // Clear first 32 bytes, then place the exec id in the next slot in memory
      mstore(0, 0)
      mstore(0x20, _exec_id)
      // Store the new target address for the exec id
      sstore(keccak256(0, 0x40), _target)
    }
  }

  // Sets the execution id and sender address in special storage locations, so that
  // they are able to be read by the target application
  function setContext(bytes32 _exec_id, address _sender) internal {
    // Ensure the exec id and sender are nonzero
    assert(_exec_id != bytes32(0) && _sender != address(0));
    exec_id = _exec_id;
    sender = _sender;
  }

  // Stores data to a given location, with a key (exec id)
  function store(bytes32 _exec_id, bytes32 _location, bytes32 _data) internal {
    // Get true location to store data to - hash of location hashed with exec id
    _location = keccak256(_location, _exec_id);
    // Store data at location
    assembly { sstore(_location, _data) }
  }
}
