pragma solidity ^0.4.23;

import "../../../../../lib/MemoryBuffers.sol";
import "../../../../../lib/ArrayUtils.sol";

library TokenApprove {

  using MemoryBuffers for uint;
  using ArrayUtils for bytes32[];
  using Exceptions for bytes32;

  /// TOKEN STORAGE ///

  // Storage seed for user allowances mapping
  bytes32 internal constant TOKEN_ALLOWANCES = keccak256("token_allowances");

  /// FUNCTION SELECTORS ///

  // Function selector for storage "read"
  // read(bytes32 _exec_id, bytes32 _location) view returns (bytes32 data_read);
  bytes4 internal constant RD_SING = bytes4(keccak256("read(bytes32,bytes32)"));

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
  function approve(address _spender, uint _amt, bytes memory _context) public pure
  returns (bytes32[] memory store_data) {
    // Ensure valid inputs
    if (_spender == address(0))
      bytes32("InvalidSpender").trigger();

    address sender;
    bytes32 exec_id;
    // Parse context array and get sender address and execution id
    (exec_id, sender, ) = parse(_context);

    // Create storage return data buffer in memory
    uint ptr = MemoryBuffers.stBuff(0, 0);
    // Push spender allowance location to buffer
    ptr.stPush(
      keccak256(keccak256(_spender), keccak256(keccak256(sender), TOKEN_ALLOWANCES)),
      bytes32(_amt)
    );

    // Get bytes32[] representation of storage buffer
    store_data = ptr.getBuffer();
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
  function increaseApproval(address _spender, uint _amt, bytes memory _context) public view returns (bytes32[] memory store_data) {
    // Ensure valid inputs
    if (_spender == address(0) || _amt == 0)
      bytes32("InvalidSpenderOrAmt").trigger();

    address sender;
    bytes32 exec_id;
    // Parse context array and get sender address and execution id
    (exec_id, sender, ) = parse(_context);

    // Create 'read' calldata buffer in memory
    uint ptr = MemoryBuffers.cdBuff(RD_SING);
    // Push exec id and spender allowance location to buffer
    ptr.cdPush(exec_id);
    ptr.cdPush(keccak256(keccak256(_spender), keccak256(keccak256(sender), TOKEN_ALLOWANCES)));

    // Read spender allowance from storage
    uint spender_allowance = uint(ptr.readSingle());
    // Safely increase the spender's balance -
    require(spender_allowance + _amt > spender_allowance);
    spender_allowance += _amt;

    // Overwrite previous buffer, and create storage return buffer
    ptr.stOverwrite(0, 0);
    // Place spender allowance location and updated allowance in buffer
    ptr.stPush(
      keccak256(keccak256(_spender), keccak256(keccak256(sender), TOKEN_ALLOWANCES)),
      bytes32(spender_allowance)
    );

    // Get bytes32[] representation of storage buffer
    store_data = ptr.getBuffer();
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
  function decreaseApproval(address _spender, uint _amt, bytes memory _context) public view returns (bytes32[] memory store_data) {
    // Ensure valid inputs
    if (_spender == address(0) || _amt == 0)
      bytes32("InvalidSpenderOrAmt").trigger();

    address sender;
    bytes32 exec_id;
    // Parse context array and get sender address and execution id
    (exec_id, sender, ) = parse(_context);

    // Create 'read' calldata buffer in memory
    uint ptr = MemoryBuffers.cdBuff(RD_SING);
    // Push exec id and spender allowance location to buffer
    ptr.cdPush(exec_id);
    ptr.cdPush(keccak256(keccak256(_spender), keccak256(keccak256(sender), TOKEN_ALLOWANCES)));

    // Read spender allowance from storage
    uint spender_allowance = uint(ptr.readSingle());
    // Safely decrease the spender's balance -
    spender_allowance = (_amt > spender_allowance ? 0 : spender_allowance - _amt);

    // Overwrite previous buffer, and create storage return buffer
    ptr.stOverwrite(0, 0);
    // Place spender allowance location and updated allowance in buffer
    ptr.stPush(
      keccak256(keccak256(_spender), keccak256(keccak256(sender), TOKEN_ALLOWANCES)),
      bytes32(spender_allowance)
    );

    // Get bytes32[] representation of storage buffer
    store_data = ptr.getBuffer();
  }

  // Parses context array and returns execution id, sender address, and sent wei amount
  function parse(bytes memory _context) internal pure returns (bytes32 exec_id, address from, uint wei_sent) {
    if (_context.length != 96)
      bytes32("UnknownExecutionContext").trigger();

    assembly {
      exec_id := mload(add(0x20, _context))
      from := mload(add(0x40, _context))
      wei_sent := mload(add(0x60, _context))
    }

    // Ensure sender and exec id are valid
    if (from == address(0) || exec_id == 0)
      bytes32("UnknownExecutionContext").trigger();
  }
}
