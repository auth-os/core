pragma solidity ^0.4.21;

// AbstractStorage with additional testing features
contract TestAbstractStorage {

  struct Application {
    bool is_paused;
    bool is_active;
    bool is_payable;
    address updater;
    address script_exec;
    address init;
  }

  // Keeps track of the number of applicaions initialized, so that each application has a unique execution id
  uint private nonce;

  // Maps execution ids to application information
  mapping (bytes32 => Application) public app_info;

  // Maps execution ids to permissioned storage addresses, to index in allowed_addr_list (if nonzero, can store)
  // Because uint value is 0 by default, this reference is 1-indexed (actual indices are minus 1)
  mapping (bytes32 => mapping (address => uint)) public allowed_addresses;

  // Maps execution ids to an array of allowed addresses
  mapping (bytes32 => address[]) public allowed_addr_list;

  /// EVENTS ///

  // GENERAL //

  event ApplicationInitialized(bytes32 indexed execution_id, address indexed init_address, address script_exec, address updater);
  event ApplicationFinalization(bytes32 indexed execution_id, address indexed init_address);
  event ApplicationExecution(bytes32 indexed execution_id, address indexed script_exec);

  // EXCEPTION HANDLING //

  event ApplicationException(address indexed application_address, bytes32 indexed execution_id, bytes32 indexed message); // Target execution address has emitted an exception, and reverted state

  // Modifier - ensures an application is not paused or inactive, and that the sender matches the script exec address
  // If value was sent, ensures the application is marked as payable
  modifier validState(bytes32 _exec_id) {
    require(
      app_info[_exec_id].is_paused == false
      && app_info[_exec_id].is_active == true
      && app_info[_exec_id].script_exec == msg.sender
    );

    // If value was sent, ensure application is marked payable
    if (msg.value > 0)
      require(app_info[_exec_id].is_payable);

    _;
  }

  // Modifier - ensures an application is paused, and that the sender is the app's updater address
  modifier onlyUpdate(bytes32 _exec_id) {
    require(app_info[_exec_id].is_paused && app_info[_exec_id].updater == msg.sender);
    _;
  }

  /// APPLICATION EXECUTION ///

  /*
  ** Application execution follows a standard pattern: applications are
  ** forwarded passed-in calldata as a static call (no state changes). The
  ** application reads from storage and generates return data, formatted as a
  ** storage request. Storage requests are handled by storeReturned.
  **
  */

  /*
  Executes an initialized application under a given execution id, with given logic target and calldata

  @param _target: The logic address for the application to execute. Passed-in calldata is forwarded here as a static call, and the return value is treated as a storage request. More information on return format in storeReturned
  @param _exec_id: The application execution id under which storage requests for this application are made
  @param _calldata: The calldata to forward to the application. Typically, this is created in the script exec contract and contains information about the original sender's address and execution id
  @mod validState(_exec_id): Ensures the application is active and unpaused, and that the sender is the script exec contract. Also ensures that if wei was sent, the app is registered as payable
  @return success: Whether the targeted application's call succeeded
  @return amount_written: The storage slots written to in this call
  @return ret_data: If the app is payable, returns payment information and storage slots written to
  */
  function exec(address _target, bytes32 _exec_id, bytes _calldata) public payable validState(_exec_id) returns (bool success, uint amount_written, bytes ret_data) {
    // Ensure valid input and input size - minimum 4 bytes
    require(_calldata.length >= 4 && _target != address(0) && _exec_id != bytes32(0));

    // Ensure sender is script executor for this exec id
    require(msg.sender == app_info[_exec_id].script_exec);

    // Ensure app logic address has been approved for this exec id
    require(allowed_addresses[_exec_id][_target] != 0);

    // Script executor and passed-in request are valid. Execute application and store return to this application's storage
    assembly {
      // Forward passed-in calldata to target contract
      success := call(gas, _target, 0, add(0x20, _calldata), mload(_calldata), 0, 0)
    }
    // If the call to the application failed, handle the exception and return
    if (!success) {
      handleException(_target, _exec_id);
      return(success, 0, new bytes(0));
    }

    // If value was sent, store returned data and get returned payment information
    if (msg.value > 0) {
      uint amount_paid;
      address paid_to;
      // Stores returned data and returns payment information and number of storage slots written to, to script exec contract
      (amount_paid, paid_to, amount_written) = storePayable(_exec_id);

      // Sanity check payment information
      assert(paid_to != address(0) && amount_paid != 0 && amount_paid <= msg.value && paid_to != address(this));

      // Forward payment to destination address - do not forward gas
      address(paid_to).transfer(amount_paid);

      // Return unspent wei to sender
      address(msg.sender).transfer(msg.value - amount_paid);

      assembly {
        ret_data := add(0x20, msize)
        mstore(ret_data, 0x40) // Set return size
        // Add amount paid and payment destination address written to to return data
        mstore(add(0x20, ret_data), amount_paid)
        mstore(add(0x40, ret_data), paid_to)
      }
    } else {
      // Store returned data, and return amount of storage slots written to
      amount_written = storeReturned(_exec_id);
    }
    // Emit event
    emit ApplicationExecution(_exec_id, _target);
    // If execution reaches this point, call should have succeeded -
    assert(success);
  }

  /// APPLICATION INITIALIZATION ///

  /*
  ** Applications are initialized by a script execution address (typically, a
  ** standard contract). The executor specifies a permissioned updater address,
  ** as well as an 'init' address and a set of 'allowed' permissioned addresses
  ** which can access app storage through exec calls made to this contract.
  ** The 'init' address acts as the constructor to the application, and will
  ** only be called once, with _init_calldata.
  **
  ** Script executor addresses, init addresses, and updater addresses cannot be
  ** permissioned storage addresses.
  */

  /*
  Initializes an application under a generated unique execution id. All storage requests for this application will use this execution context id.
  Applications are paused and inactive by default, and can be un-paused (and activated) by the script exec contract. This allows for fine-tuned control
  of allowed addresses prior to live functionality.

  @param _updater: This address can add or remove addresses from the exec id's allowed address list. The updater address can also pause app execution. Can be 0.
  @param _is_payable: Designates whether functions in these contracts should expect wei
  @param _init: This address contains logic for the application's initialize function, which sets up initial variables like a constructor
  @param _init_calldata: ABI-encoded calldata which will be forwarded to the init target address
  @param _allowed: These addresses can be called through this contract's exec function, and can access storage
  @return exec_id: The unique exec id to be used by this application
  */
  function initAppInstance(address _updater, bool _is_payable, address _init, bytes _init_calldata, address[] _allowed) public returns (bytes32 exec_id) {
    exec_id = keccak256(++nonce, address(this));

    uint size;
    // Execute application init call
    assembly {
      let ret := call(gas, _init, 0, add(0x20, _init_calldata), mload(_init_calldata), 0, 0)
      // Check return value - if zero, call failed
      if iszero(ret) { revert (0, 0) }
      size := returndatasize
    }
    // Store returned init app data
    if (size > 0) storeReturned(exec_id);

    // Set application information, and set app to paused and inactive
    app_info[exec_id] = Application({
      is_paused: true,
      is_active: false,
      is_payable: _is_payable,
      updater: _updater,
      script_exec: msg.sender,
      init: _init
    });

    // Loop over given allowed addresses, and add to mapping
    for (uint i = 0; i < _allowed.length; i++) {
      // Allowed addresses cannot be script executor, _init address, or _updater address
      require(msg.sender != _allowed[i] && _init != _allowed[i] && _updater != _allowed[i]);
      // Allowed addresses cannot be added several times - skip this iteration
      if (allowed_addresses[exec_id][_allowed[i]] != 0)
        continue;
      allowed_addresses[exec_id][_allowed[i]] = i + 1;
      allowed_addr_list[exec_id].push(_allowed[i]);
    }

    // emit Event
    emit ApplicationInitialized(exec_id, _init, msg.sender, _updater);
    // Sanity check - ensure valid exec id
    assert(exec_id != bytes32(0));
  }

  /*
  Initializes an application under a generated unique execution id, and finalizes it (disallows addition/removal of addresses). All storage requests for this application will use this execution context id.
  Applications are paused and inactive by default, and can be un-paused (and activated) by the script exec contract. This allows for fine-tuned control
  of allowed addresses prior to live functionality.

  @param _updater: This address can add or remove addresses from the exec id's allowed address list. The updater address can also pause app execution. Can be 0.
  @param _is_payable: Designates whether functions in these contracts should expect wei
  @param _init: This address contains logic for the application's initialize function, which sets up initial variables like a constructor
  @param _init_calldata: ABI-encoded calldata which will be forwarded to the init target address
  @param _allowed: These addresses can be called through this contract's exec function, and can access storage
  @return exec_id: The unique exec id to be used by this application
  */
  function initAndFinalize(address _updater, bool _is_payable, address _init, bytes _init_calldata, address[] _allowed) public returns (bytes32 exec_id) {
    exec_id = initAppInstance(_updater, _is_payable, _init, _init_calldata, _allowed);
    finalizeAppInstance(exec_id);
    assert(exec_id != bytes32(0));
  }

  /*
  Called by the an application's script exec contract: Activates an application and un-pauses it.

  @param _exec_id: The unique execution id under which the application stores data
  */
  function finalizeAppInstance(bytes32 _exec_id) public {
    // Ensure application is registered, inactive, and paused
    require(
      app_info[_exec_id].script_exec == msg.sender
      && app_info[_exec_id].is_active == false
      && app_info[_exec_id].is_paused == true
    );

    // Emit event
    emit ApplicationFinalization(_exec_id, app_info[_exec_id].init);
    // Set application status as active and unpaused
    app_info[_exec_id].is_paused = false;
    app_info[_exec_id].is_active = true;
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

  // The updater address may change an application's init address
  function changeInitAddr(bytes32 _exec_id, address _new_init) public onlyUpdate(_exec_id) {
    app_info[_exec_id].init = _new_init;
  }

  // Allows the designated updater address to pause an application
  function pauseAppInstance(bytes32 _exec_id) public {
    // Ensure sender is updater address, and app is active
    require(app_info[_exec_id].updater == msg.sender && app_info[_exec_id].is_active == true);

    // Set paused status
    app_info[_exec_id].is_paused = true;
  }

  // Allows the designated updater address to unpause an application
  function unpauseAppInstance(bytes32 _exec_id) public {
    // Ensure sender is updater address, and app is active
    require(app_info[_exec_id].updater == msg.sender && app_info[_exec_id].is_active == true);

    // Set unpaused status
    app_info[_exec_id].is_paused = false;
  }

  // Allows the designated updater address to update the application by removing allowed addresses
  function removeAllowed(bytes32 _exec_id, address[] _to_remove) public onlyUpdate(_exec_id) {
    // Loop over input addresses and delete their permissions for the given exec id
    for (uint i = 0; i < _to_remove.length; i++) {
      // Get the index of the address to remove
      uint remove_ind = allowed_addresses[_exec_id][_to_remove[i]];
      // If the index to remove is 0, this address does not exist in the application's allowed addresses. Skip this iteration
      if (remove_ind == 0)
        continue;

      // Otherwise, decrement remove_ind (allowed_addresses is 1-indexed)
      remove_ind--;
      // Remove address reference in allowed_addresses
      delete allowed_addresses[_exec_id][_to_remove[i]];

      // Get allowed address array length
      uint allowed_addr_length = allowed_addr_list[_exec_id].length;

      // The index to remove should never be out of bounds
      assert(remove_ind < allowed_addr_length);

      // If the allowed address list has length 1, simply delete the array reference and continue
      if (allowed_addr_length == 1) {
        delete allowed_addr_list[_exec_id];
        continue;
      }

      // If the index to remove is not the final index, grab the final element and swap
      if (remove_ind + 1 != allowed_addr_length) {
        address last_index = allowed_addr_list[_exec_id][allowed_addr_length - 1];
        allowed_addr_list[_exec_id][remove_ind] = last_index;
        // Update last_index mapping
        allowed_addresses[_exec_id][last_index] = remove_ind + 1;
      }

      // Decrease the array's length
      allowed_addr_list[_exec_id].length--;
    }
  }

  // Allows the designated updater address to update the application by adding allowed addresses
  function addAllowed(bytes32 _exec_id, address[] _to_add) public onlyUpdate(_exec_id) {
    // Loop over input addresses and add permissions for each address
    for (uint i = 0; i < _to_add.length; i++) {
      // Ensure the address to allow is not the script exec id, the updater, or the init address
      require(
        _to_add[i] != app_info[_exec_id].script_exec
        && _to_add[i] != app_info[_exec_id].init
        && _to_add[i] != msg.sender // Updater address
      );

      // Addresses cannot be added several times - skip this iteration
      if (allowed_addresses[_exec_id][_to_add[i]] != 0)
        continue;

      // Otherwise, push the new address to the allowed address list, and update its index
      allowed_addr_list[_exec_id].push(_to_add[i]);
      allowed_addresses[_exec_id][_to_add[i]] = allowed_addr_list[_exec_id].length;
    }
  }

  /*
  Handles an exception thrown by a deployed application - if the application provided a message, return the message
  If ether was sent, return the ether to the sender

  @param _application: The address which triggered the exception
  @param _execution_id: The execution id specified by the sender
  */
  function handleException(address _application, bytes32 _execution_id) internal {
    // If ether was sent, send it back with returnToSender
    if (msg.value > 0)
      address(msg.sender).transfer(msg.value);
    bytes32 message = bytes32("DefaultException");
    assembly {
      // If returned data exists, get first 32 bytes set message
      if eq(returndatasize, 0x20) {
        returndatacopy(message, 0, 0x20)
      }
    }
    emit ApplicationException(_application, _execution_id, message);
  }

  /*
  Reads returned data, and stores data to application id storage

  @param _exec_id: The application's execution context id - storage requests are seeded to this location
  @return amount_written: The number of storage slots written to
  */
  function storeReturned(bytes32 _exec_id) internal returns (uint amount_written) {
    // Ensure no value transfer
    assert(msg.value == 0);
    assembly {
      // Get pointer to free memory for hashing
      let hash_ptr := mload(0x40) // No need to update free memory pointer - it can be overwritten on completion of this function. If the pointer was valid before this function call, it will be valid after.
      // Hash exec id and store in second slot of pointer
      mstore(add(0x20, hash_ptr), _exec_id)
      mstore(add(0x20, hash_ptr), keccak256(add(0x20, hash_ptr), 0x20))
      // Get pointer to copy returned data to
      let returndata_ptr := add(0x40, hash_ptr)

      // Ensure correctly-formed returndata. Should be divisible by 64 bytes
      // Valid return data is either exactly 64 bytes (store 32 bytes of data to one location), or
      // a dynamic bytes32 array with format:
      // [data read offset][array length][location 0][data 0][location 1][data 1]...
      if gt(mod(returndatasize, 0x40), 0) { revert (0, 0) }

      // If returned data is larger than 64 bytes, assume a bytes32 array: [location][data][location][data]
      // Hash locations with exec id seed, and store data:
      if gt(returndatasize, 0x40) {

        // Copy returned data to pointer
        // Returned data should begin with a read offset, so we skip the first 32 bytes, but copy the rest (including array length)
        returndatacopy(returndata_ptr, 0x20, sub(returndatasize, 0x20))
        // Ensure return length is even (bytes32 array, in above-described format)
        if gt(mod(mload(returndata_ptr), 2), 0) { revert (0, 0) }

        // Loop from offset (0x20) to 0x20 + storage request length (stored at returndata_ptr)
        for { let offset := 0x20 } lt(offset, add(0x20, mul(0x20, mload(returndata_ptr)))) { offset := add(0x20, offset) } {
          // Place storage location at hash_ptr
          mstore(hash_ptr, mload(add(offset, returndata_ptr)))
          // Increment offset
          offset := add(0x20, offset)
          // Hash storage location and exec id seed, and store data
          sstore(keccak256(hash_ptr, 0x40), mload(add(offset, returndata_ptr)))
        }

        // Get return value - number of storage slots written to
        amount_written := div(sub(returndatasize, 0x40), 0x40)
      }
    }
    // Sanity check - ensure amount written is nonzero
    assert(amount_written > 1);
    // Remove payment fields from amount written
    amount_written -= 1;
  }

  /*
  Reads returned data, stores data to application storage, and returns the amount of funds to send to the provided destination address

  @param _exec_id: The application's execution context id - storage requests are seeded to this location
  @return amount_paid: The amount the application has designated be paid. Can be zero, if amount written is nonzero.
  @return paid_to: The destination address for payment. Must be nonzero, if payment amount is nonzero.
  @return amount_written: The number of storage slots written to. Can be 0, if payment information is valid.
  */
  function storePayable(bytes32 _exec_id) internal returns (uint amount_paid, address paid_to, uint amount_written) {

    assembly {
      // Get pointer to free memory for hashing
      let hash_ptr := mload(0x40) // No need to update free memory pointer - it can be overwritten on completion of this function. If the pointer was valid before this function call, it will be valid after.
      // Hash exec id and store in second slot of pointer
      mstore(add(0x20, hash_ptr), _exec_id)
      mstore(add(0x20, hash_ptr), keccak256(add(0x20, hash_ptr), 0x20))
      // Get pointer to copy returned data to
      let returndata_ptr := add(0x40, hash_ptr)

      // Ensure correctly-formed returndata. Should be divisible by 64 bytes
      // The first 64 bytes should designate an amount of ether (can be 0) to send to a target address (if ether is nonzero, cannot be 0) [destination][amount]
      // The rest of the data follows 'storeReturned' format.
      if gt(mod(returndatasize, 0x20), 0) { revert (0, 0) }

      // If returned data is exactly 64 bytes, assume single payment transfer: [destination][amount]
      // Check valid transfer data, and forward funds (with gas stipend). Return rest of funds to sender (script executor address)
      if eq(returndatasize, 0x40) {
        // Sanity checks
        if gt(amount_paid, 0) { revert (0, 0) }
        if gt(paid_to, 0) { revert (0, 0) }
        if gt(amount_written, 0) { revert (0, 0) }

        // Copy returned data to pointer
        returndatacopy(returndata_ptr, 0, returndatasize)

        // Get payment destination address
        paid_to := mload(returndata_ptr)
        // Get payment amount
        amount_paid := mload(add(0x20, returndata_ptr))
      }

      // If returned data is larger than 64 bytes, assume payment information, followed by a bytes32 array (ABI-encoded):
      // [destination][amount][offset][array length][location 0][data 0][location 1][data 1]
      // i.e: returned(address, uint, bytes32[])
      // Hash locations with exec id seed, and store data:
      if gt(returndatasize, 0x40) {
        // Sanity checks
        if gt(amount_paid, 0) { revert (0, 0) }
        if gt(paid_to, 0) { revert (0, 0) }
        if gt(amount_written, 0) { revert (0, 0) }

        // Copy all returned data to pointer and get payment information (destination and amount now stored consecutively at pointer)
        returndatacopy(returndata_ptr, 0, returndatasize)
        // Get payment destination address
        paid_to := mload(returndata_ptr)
        // Get payment amount
        amount_paid := mload(add(0x20, returndata_ptr))

        // Rest of data is a storage request - skip data read offset, and loop over bytes32 array. Increment pointer to point to array length
        returndata_ptr := add(0x60, returndata_ptr)

        // Ensure return length is even (bytes32 array, in above-described format)
        if gt(mod(mload(returndata_ptr), 2), 0) { revert (0, 0) }

        // Loop from offset (0x20) to 0x20 + storage request length (stored at returndata_ptr)
        for { let offset := 0x20 } lt(offset, add(0x20, mul(0x20, mload(returndata_ptr)))) { offset := add(0x20, offset) } {
          // Place storage location at hash_ptr
          mstore(hash_ptr, mload(add(offset, returndata_ptr)))
          // Increment offset
          offset := add(0x20, offset)
          // Hash storage location and exec id seed, and store data
          sstore(keccak256(hash_ptr, 0x40), mload(add(offset, returndata_ptr)))
        }

        // Get return value - number of storage slots written to
        amount_written := div(sub(returndatasize, 0x80), 0x40)

        // Sanity check - amount written must be nonzero
        if iszero(gt(amount_written, 1)) { revert (0, 0) }
        // Remove payment information from amount written
        amount_written := sub(amount_written, 1)
      }
    }
    // Sanity check - ensure valid, safe state change. If no storage occured, there must be valid payment. If storage occured, no payment is required
    assert(paid_to != address(this));
    assert(
      (amount_written != 0 && paid_to != address(0))
      || (amount_written == 0 && paid_to != address(0) && amount_paid != 0)
    );
  }

  /// GETTERS ///

  // Returns the addresses with permissioned storage access under the given execution id
  function getExecAllowed(bytes32 _exec_id) public view returns (address[] allowed) {
    allowed = new address[](allowed_addr_list[_exec_id].length);
    for (uint i = 0; i < allowed.length; i++) {
      allowed[i] = allowed_addr_list[_exec_id][i];
    }
  }

  /// STORAGE READS ///

  /*
  Returns data stored at a given location

  @param _location: The address to get data from
  @return data: The data stored at the location after hashing
  */
  function read(bytes32 _exec_id, bytes32 _location) public view returns (bytes32 data_read) {
    bytes32 storage_loc = keccak256(_exec_id);
    bytes32 location = keccak256(_location, storage_loc);
    assembly {
      data_read := sload(location)
    }
  }

  /*
  Returns data stored in several nonconsecutive locations

  @param _locations: A dynamic array of storage locations to read from
  @return data_read: The corresponding data stored in the requested locations
  */
  function readMulti(bytes32 _exec_id, bytes32[] _locations) public view returns (bytes32[] data_read) {
    bytes32 storage_loc = keccak256(_exec_id);
    data_read = new bytes32[](_locations.length);
    assembly {
      // Get free-memory pointer for a hash location
      let hash_loc := mload(0x40)
      // Store the hash of the exec id in the second slot of the hash pointer
      mstore(add(0x20, hash_loc), storage_loc)

      // Loop over input and store in return data
      for { let offset := 0x20 } lt(offset, add(0x20, mul(0x20, mload(_locations)))) { offset := add(0x20, offset) } {
        // Get storage location from hash location ptr
        mstore(hash_loc, mload(add(offset, _locations)))
        // Hash exec id and location to get storage location
        let storage_location := keccak256(hash_loc, 0x40)
        // Copy data from storage to return array
        mstore(add(offset, data_read), sload(storage_location))
      }
    }
  }

  // Ensure no funds are stuck in this address
  function withdraw() public {
    address(msg.sender).transfer(address(this).balance);
  }
}
