pragma solidity ^0.4.23;

import "../../../../../lib/MemoryBuffers.sol";
import "../../../../../lib/ArrayUtils.sol";

library TokenTransferFrom {

  using MemoryBuffers for uint;
  using ArrayUtils for bytes32[];
  using Exceptions for bytes32;

  /// TOKEN STORAGE ///

  // Storage seed for user balances mapping
  bytes32 internal constant TOKEN_BALANCES = keccak256("token_balances");

  // Storage seed for user allowances mapping
  bytes32 internal constant TOKEN_ALLOWANCES = keccak256("token_allowances");

  // Storage seed for token 'transfer agent' status for any address
  // Transfer agents can transfer tokens, even if the crowdsale has not yet been finalized
  bytes32 internal constant TOKEN_TRANSFER_AGENTS = keccak256("token_transfer_agents");

  // Whether or not the token is unlocked for transfers
  bytes32 internal constant TOKENS_ARE_UNLOCKED = keccak256("tokens_are_unlocked");

  /// FUNCTION SELECTORS ///

  // Function selector for storage 'readMulti'
  // readMulti(bytes32 exec_id, bytes32[] locations)
  bytes4 internal constant RD_MULTI = bytes4(keccak256("readMulti(bytes32,bytes32[])"));

  /*
  Transfers tokens from an owner's balance to a recipient, provided the sender has suffcient allowance

  @param _from: The address from which tokens will be sent
  @param _to: The destination address, to which tokens will be sent
  @param _amt: The amount of tokens to send
  @param _context: The execution context for this application - a 96-byte array containing (in order):
    1. Application execution id
    2. Original script sender (address, padded to 32 bytes)
    3. Wei amount sent with transaction to storage
  @return store_data: A formatted storage request - first 64 bytes designate a forwarding address (and amount) for any wei sent
  */
  function transferFrom(address _from, address _to, uint _amt, bytes memory _context) public view
  returns (bytes32[] memory store_data) {
    // Ensure valid inputs
    if (_to == address(0) || _from == address(0))
      bytes32("InvalidSenderOrRecipient").trigger();

    address sender;
    bytes32 exec_id;
    // Parse context array and get sender address and execution id
    (exec_id, sender, ) = parse(_context);

    // Create 'readMulti' calldata buffer in memory
    uint ptr = MemoryBuffers.cdBuff(RD_MULTI);
    // Place exec id, data read offset, and read size to calldata
    ptr.cdPush(exec_id);
    ptr.cdPush(0x40);
    ptr.cdPush(bytes32(5));
    // Place owner and recipient balance locations, and sender allowance location in calldata buffer
    ptr.cdPush(keccak256(keccak256(_from), TOKEN_BALANCES));
    ptr.cdPush(keccak256(keccak256(_to), TOKEN_BALANCES));
    ptr.cdPush(keccak256(keccak256(sender), keccak256(keccak256(_from), TOKEN_ALLOWANCES)));
    // Place token unlock status and owner transfer agent status storage locations in calldata buffer
    ptr.cdPush(TOKENS_ARE_UNLOCKED);
    ptr.cdPush(keccak256(keccak256(_from), TOKEN_TRANSFER_AGENTS));
    // Read from storage
    uint[] memory read_values = ptr.readMulti().toUintArr();
    // Ensure length of returned data is correct
    assert(read_values.length == 5);

    // If the token is not unlocked, and the token owner is not a transfer agent, throw exception
    if (read_values[3] == 0 && read_values[4] == 0)
      bytes32("TransfersLocked").trigger();

    // Read returned balances and allowance -
    uint owner_bal = read_values[0];
    uint recipient_bal = read_values[1];
    uint sender_allowance = read_values[2];

    // Ensure owner has sufficient balance to send, and recipient balance does not overflow
    // Additionally, ensure sender has sufficient allowance
    require(owner_bal >= _amt && recipient_bal + _amt > recipient_bal && sender_allowance >= _amt);

    // Get updated balances -
    owner_bal -= _amt;
    recipient_bal += _amt;
    // Get updated allowance -
    sender_allowance -= _amt;

    // Overwrite previous buffer, and create storage return buffer
    ptr.stOverwrite(0, 0);
    // Place owner balance location and updated balance in buffer
    ptr.stPush(keccak256(keccak256(_from), TOKEN_BALANCES), bytes32(owner_bal));
    // Place recipient balance location and updated balance in buffer
    ptr.stPush(keccak256(keccak256(_to), TOKEN_BALANCES), bytes32(recipient_bal));
    // Place sender allowance location and updated allowance in buffer
    ptr.stPush(keccak256(keccak256(sender), keccak256(keccak256(_from), TOKEN_ALLOWANCES)), bytes32(sender_allowance));

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
