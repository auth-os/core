pragma solidity ^0.4.21;

library TokenApprove {

  /// TOKEN STORAGE ///

  // Storage seed for user allowances mapping
  bytes32 public constant TOKEN_ALLOWANCES = keccak256("token_allowances");

  /// FUNCTION SELECTORS ///

  // Function selector for storage "read"
  // read(bytes32 _exec_id, bytes32 _location) view returns (bytes32 data_read);
  bytes4 public constant RD_SING = bytes4(keccak256("read(bytes32,bytes32)"));

  /// EXCEPTION MESSAGES ///

  bytes32 public constant ERR_UNKNOWN_CONTEXT = bytes32("UnknownContext"); // Malformed '_context' array
  bytes32 public constant ERR_INSUFFICIENT_PERMISSIONS = bytes32("InsufficientPermissions"); // Action not allowed
  bytes32 public constant ERR_READ_FAILED = bytes32("StorageReadFailed"); // Read from storage address failed

  /*
  Approves another address to spend tokens on the sender's behalf

  @param _spender: The address for which the amount will be approved
  @param _amt: The amount of tokens to approve for spending
  @param _context: The execution context for this application - a 96-byte array containing (in order):
    1. Application execution id
    2. Original script sender (address, padded to 32 bytes)
    3. Wei amount sent with transaction to storage
  @return store_data: A formatted storage request - first 64 bytes designate a forwarding address (and amount) for any wei sent
  */
  function approve(address _spender, uint _amt, bytes _context) public pure
  returns (bytes32[] store_data) {
    // Ensure valid inputs
    require(_spender != address(0) && _amt != 0);
    if (_context.length != 96)
      triggerException(ERR_UNKNOWN_CONTEXT);

    // Parse context array and get sender address and execution id
    address sender;
    bytes32 exec_id;
    (exec_id, sender, ) = parse(_context);

    store_data = new bytes32[](2);
    store_data[0] = keccak256(keccak256(_spender), keccak256(keccak256(sender), TOKEN_ALLOWANCES));
    store_data[1] = bytes32(_amt);
  }

  struct Approval {
    bytes4 rd_sing;
    bytes32 spender_allowance_loc;
    uint spender_allowance;
  }

  /*
  Increases the spending approval amount set by the sender for the _spender

  @param _spender: The address for which the allowance will be increased
  @param _amt: The amount to increase the allowance by
  @param _context: The execution context for this application - a 96-byte array containing (in order):
    1. Application execution id
    2. Original script sender (address, padded to 32 bytes)
    3. Wei amount sent with transaction to storage
  @return store_data: A formatted storage request - first 64 bytes designate a forwarding address (and amount) for any wei sent
  */
  function increaseApproval(address _spender, uint _amt, bytes _context) public view returns (bytes32[] store_data) {
    // Ensure valid inputs
    require(_spender != address(0) && _amt != 0);
    if (_context.length != 96)
      triggerException(ERR_UNKNOWN_CONTEXT);

    // Parse context array and get sender address and execution id
    address sender;
    bytes32 exec_id;
    (exec_id, sender, ) = parse(_context);

    // Create struct in memory to hold values. Values are stored in-order as they would be returned in the return storage request
    Approval memory tok_appr = Approval({
      rd_sing: RD_SING,
      spender_allowance_loc: keccak256(keccak256(_spender), keccak256(keccak256(sender), TOKEN_ALLOWANCES)),
      spender_allowance: 0
    });

    assembly {
      // Read spender's current allowance from storage -

      let ptr := mload(0x40)
      mstore(ptr, mload(tok_appr))
      mstore(add(0x04, ptr), exec_id)
      mstore(add(0x24, ptr), mload(add(0x20, tok_appr)))
      // Read from storage, and store return value directly to tok_appr
      let ret := staticcall(gas, caller, ptr, 0x44, add(0x40, tok_appr), 0x20)
      if iszero(ret) { revert (0, 0) }

      // Check safe addition of allowance increase
      if lt(add(_amt, mload(add(0x40, tok_appr))), mload(add(0x40, tok_appr))) { revert (0, 0) }
      // No overflow - add amount to return request
      mstore(add(0x40, tok_appr), add(_amt, mload(add(0x40, tok_appr))))

      // Set return data location, and return length -
      store_data := tok_appr
      mstore(store_data, 2)
    }
  }

  /*
  Decreases the spending approval amount set by the sender for the _spender

  @param _spender: The address for which the allowance will be increased
  @param _amt: The amount to decrease the allowance by
  @param _context: The execution context for this application - a 96-byte array containing (in order):
    1. Application execution id
    2. Original script sender (address, padded to 32 bytes)
    3. Wei amount sent with transaction to storage
  @return store_data: A formatted storage request - first 64 bytes designate a forwarding address (and amount) for any wei sent
  */
  function decreaseApproval(address _spender, uint _amt, bytes _context) public view returns (bytes32[] store_data) {
    // Ensure valid inputs
    require(_spender != address(0) && _amt != 0);
    if (_context.length != 96)
      triggerException(ERR_UNKNOWN_CONTEXT);

    // Parse context array and get sender address and execution id
    address sender;
    bytes32 exec_id;
    (exec_id, sender, ) = parse(_context);

    // Create struct in memory to hold values. Values are stored in-order as they would be returned in the return storage request
    Approval memory tok_appr = Approval({
      rd_sing: RD_SING,
      spender_allowance_loc: keccak256(keccak256(_spender), keccak256(keccak256(sender), TOKEN_ALLOWANCES)),
      spender_allowance: 0
    });

    assembly {
      // Read spender's current allowance from storage -

      let ptr := mload(0x40)
      mstore(ptr, mload(tok_appr))
      mstore(add(0x04, ptr), exec_id)
      mstore(add(0x24, ptr), mload(add(0x20, tok_appr)))
      // Read from storage, and store return value directly to tok_appr
      let ret := staticcall(gas, caller, ptr, 0x44, add(0x40, tok_appr), 0x20)
      if iszero(ret) { revert (0, 0) }

      // Check for underflow
      if gt(_amt, mload(add(0x40, tok_appr))) { revert (0, 0) }
      // No underflow - add amount to return request
      mstore(add(0x40, tok_appr), sub(mload(add(0x40, tok_appr)), _amt))

      // Set return data location, and return length -
      store_data := tok_appr
      mstore(store_data, 2)
    }
  }

  /*
  Reverts state changes, but passes message back to caller

  @param _message: The message to return to the caller
  */
  function triggerException(bytes32 _message) internal pure {
    assembly {
      mstore(0, _message)
      revert(0, 0x20)
    }
  }

  // Parses context array and returns execution id, sender address, and sent wei amount
  function parse(bytes _context) internal pure returns (bytes32 exec_id, address from, uint wei_sent) {
    assembly {
      exec_id := mload(add(0x20, _context))
      from := mload(add(0x40, _context))
      wei_sent := mload(add(0x60, _context))
    }
    // Ensure sender and exec id are valid
    if (from == address(0) || exec_id == bytes32(0))
      triggerException(ERR_UNKNOWN_CONTEXT);
  }
}
