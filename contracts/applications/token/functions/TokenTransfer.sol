pragma solidity ^0.4.21;

library TokenTransfer {

  /// TOKEN STORAGE ///

  // Storage seed for user balances mapping
  bytes32 public constant TOKEN_BALANCES = keccak256("token_balances");

  /// FUNCTION SELECTORS ///

  // Function selector for storage 'readMulti'
  // readMulti(bytes32 exec_id, bytes32[] locations)
  bytes4 public constant RD_MULTI = bytes4(keccak256("readMulti(bytes32,bytes32[])"));

  /*
  Transfers tokens from one address to another

  @param _context: A 64-byte array containing execution context for the application. In order:
    1. Application execution id
    2. Original script sender (address, padded to 32 bytes)
  @param _to: The destination address, to which tokens will be sent
  @param _amt: The amount of tokens to send
  @return store_data: A formatted storage request, which will be interpreted by storage to update balances
  */
  function transfer(bytes _context, address _to, uint _amt) public view
  returns (bytes32[] store_data) {
    // Ensure valid inputs
    require(_context.length == 64 && _to != address(0) && _amt != 0);

    // Allocate memory for storage request (2 slots for each balance update) -
    store_data = new bytes32[](4);

    address from;
    bytes32 exec_id;
    uint sender_bal;
    uint recipient_bal;

    // Parse context array and get sender address and execution id
    (from, exec_id) = parse(_context);

    // Get sender and recipient balance locations in storage -
    bytes32 sender_loc = keccak256(keccak256(from), TOKEN_BALANCES);
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

  // Parses context array and returns sender address and execution id
  function parse(bytes _context) internal pure returns (address from, bytes32 exec_id) {
    assembly {
      exec_id := mload(add(0x20, _context))
      from := mload(add(0x40, _context))
    }
    // Ensure neither field is zero
    require(from != address(0) && exec_id != bytes32(0));
  }
}
