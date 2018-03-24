pragma solidity ^0.4.21;

library TokenTransfer {

  /// TOKEN STORAGE ///

  // Storage seed for user balances mapping
  bytes32 public constant TOKEN_BALANCES = keccak256("token_balances");

  /// FUNCTION SELECTORS ///

  // Function selector for storage 'readMulti'
  // readMulti(bytes32 exec_id, bytes32[] locations)
  bytes4 public constant RD_MULTI = bytes4(keccak256("readMulti(bytes32,bytes32[])"));

  /// EXCEPTION MESSAGES ///

  bytes32 public constant ERR_UNKNOWN_CONTEXT = bytes32("UnknownContext"); // Malformed '_context' array
  bytes32 public constant ERR_INSUFFICIENT_PERMISSIONS = bytes32("InsufficientPermissions"); // Action not allowed
  bytes32 public constant ERR_READ_FAILED = bytes32("StorageReadFailed"); // Read from storage address failed

  /*
  Transfers tokens from one address to another

  @param _to: The destination address, to which tokens will be sent
  @param _amt: The amount of tokens to send
  @param _context: The execution context for this application - a 96-byte array containing (in order):
    1. Application execution id
    2. Original script sender (address, padded to 32 bytes)
    3. Wei amount sent with transaction to storage
  @return store_data: A formatted storage request - first 64 bytes designate a forwarding address (and amount) for any wei sent
  */
  function transfer(address _to, uint _amt, bytes _context) public view
  returns (bytes32[] store_data) {
    // Ensure valid inputs
    require(_to != address(0) && _amt != 0);
    if (_context.length != 96)
      triggerException(ERR_UNKNOWN_CONTEXT);

    // Allocate memory for storage request (2 slots for each balance update) -
    store_data = new bytes32[](4);

    // Parse context array and get sender address and execution id
    address sender;
    bytes32 exec_id;
    (exec_id, sender, ) = parse(_context);
    uint sender_bal;
    uint recipient_bal;

    // Get sender and recipient balance locations in storage -
    bytes32 sender_loc = keccak256(keccak256(sender), TOKEN_BALANCES);
    bytes32 recipient_loc = keccak256(keccak256(_to), TOKEN_BALANCES);

    // Place 'readMulti' selector in memory
    bytes4 rd_multi = RD_MULTI;

    // Create 'readMulti' calldata, and request sender and recipient balances from storage
    assembly {
      let ptr := mload(0x40)
      // Place 'readMulti' selector at pointer
      mstore(ptr, rd_multi)
      // Place exec id, data read offset, and read size in calldata
      mstore(add(0x04, ptr), exec_id)
      mstore(add(0x24, ptr), 0x40)
      mstore(add(0x44, ptr), 2)
      // Place sender and recipient balance locations in calldata
      mstore(add(0x64, ptr), sender_loc)
      mstore(add(0x84, ptr), recipient_loc)

      // Read from storage, and ensure call succeeds. Store returned data at pointer.
      let ret := staticcall(gas, caller, ptr, 0xa4, ptr, 0x80)
      if iszero(ret) { revert (0, 0) }

      // Get sender and recipient balances
      sender_bal := mload(add(0x40, ptr))
      recipient_bal := mload(add(0x60, ptr))
    }

    // Safely add and subtract from balances, and store in return storage request -
    require(recipient_bal + _amt > recipient_bal && _amt <= sender_bal);
    recipient_bal += _amt;
    sender_bal -= _amt;

    store_data[0] = sender_loc;
    store_data[1] = bytes32(sender_bal);
    store_data[2] = recipient_loc;
    store_data[3] = bytes32(recipient_bal);
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
