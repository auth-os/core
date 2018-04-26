pragma solidity ^0.4.23;

import "../../../../../lib/MemoryBuffers.sol";
import "../../../../../lib/ArrayUtils.sol";

library TokenTransfer {

  using MemoryBuffers for uint;
  using ArrayUtils for bytes32[];
  using Exceptions for bytes32;

  /// CROWDSALE STORAGE ///

  // Whether or not the crowdsale is post-purchase
  bytes32 internal constant CROWDSALE_IS_FINALIZED = keccak256("crowdsale_is_finalized");

  /// TOKEN STORAGE ///

  // Storage seed for token 'transfer agent' status for any address
  // Transfer agents can transfer tokens, even if the crowdsale has not yet been finalized
  bytes32 internal constant TOKEN_TRANSFER_AGENTS = keccak256("token_transfer_agents");

  /// TOKEN STORAGE ///

  // Storage seed for user balances mapping
  bytes32 internal constant TOKEN_BALANCES = keccak256("token_balances");

  /// FUNCTION SELECTORS ///

  // Function selector for storage 'readMulti'
  // readMulti(bytes32 exec_id, bytes32[] locations)
  bytes4 internal constant RD_MULTI = bytes4(keccak256("readMulti(bytes32,bytes32[])"));

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
  function transfer(address _to, uint _amt, bytes memory _context) public view
  returns (bytes32[] memory store_data) {
    // Ensure valid inputs
    if (_to == address(0))
      bytes32("InvalidRecipient").trigger();

    address sender;
    bytes32 exec_id;
    // Parse context array and get sender address and execution id
    (exec_id, sender, ) = parse(_context);

    // Create 'readMulti' calldata buffer in memory
    uint ptr = MemoryBuffers.cdBuff(RD_MULTI);
    // Place exec id, data read offset, and read size to calldata
    ptr.cdPush(exec_id);
    ptr.cdPush(0x40);
    ptr.cdPush(bytes32(4));
    // Place sender and recipient balance locations in calldata buffer
    ptr.cdPush(keccak256(keccak256(sender), TOKEN_BALANCES));
    ptr.cdPush(keccak256(keccak256(_to), TOKEN_BALANCES));
    // Place crowdsale finalization status and sender transfer agent status storage locations in calldata buffer
    ptr.cdPush(CROWDSALE_IS_FINALIZED);
    ptr.cdPush(keccak256(keccak256(sender), TOKEN_TRANSFER_AGENTS));
    // Read from storage
    uint[] memory read_values = ptr.readMulti().toUintArr();
    // Ensure length of returned data is correct
    assert(read_values.length == 4);

    // If the crowdsale is not finalized, and the sender is not a transfer agent, throw exception
    if (read_values[2] == 0 && read_values[3] == 0)
      bytes32("TransfersLocked").trigger();

    // Read returned values -
    uint sender_bal = read_values[0];
    uint recipient_bal = read_values[1];

    // Ensure owner has sufficient balance to send, and recipient balance does not overflow
    require(sender_bal >= _amt && recipient_bal + _amt > recipient_bal);

    // Get updated balances -
    sender_bal -= _amt;
    recipient_bal += _amt;

    // Overwrite previous buffer, and create storage return buffer
    ptr.stOverwrite(0, 0);
    // Place owner balance location and updated balance in buffer
    ptr.stPush(keccak256(keccak256(sender), TOKEN_BALANCES), bytes32(sender_bal));
    // Place recipient balance location and updated balance in buffer
    ptr.stPush(keccak256(keccak256(_to), TOKEN_BALANCES), bytes32(recipient_bal));

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
