pragma solidity ^0.4.23;

import "../../../../../lib/MemoryBuffers.sol";
import "../../../../../lib/ArrayUtils.sol";

library TokenConsole {

  using MemoryBuffers for uint;
  using ArrayUtils for bytes32[];
  using Exceptions for bytes32;


  /// CROWDSALE STORAGE ///

  // Storage location of crowdsale admin address
  bytes32 internal constant ADMIN = keccak256("admin");

  /// TOKEN STORAGE ///

  // Storage seed for token 'transfer agent' status for any address
  // Transfer agents can transfer tokens, even if the crowdsale has not yet been finalized
  bytes32 internal constant TOKEN_TRANSFER_AGENTS = keccak256("token_transfer_agents");

  /// FUNCTION SELECTORS ///

  // Function selector for storage "read"
  // read(bytes32 _exec_id, bytes32 _location) view returns (bytes32 data_read);
  bytes4 internal constant RD_SING = bytes4(keccak256("read(bytes32,bytes32)"));

  /*
  Allows the admin to set an address's transfer agent status - transfer agents can transfer tokens prior to the end of the crowdsale

  @param _agent: The address whose transfer agent status will be updated
  @param _is_transfer_agent: If true, address will be set as a transfer agent
  @param _context: The execution context for this application - a 96-byte array containing (in order):
    1. Application execution id
    2. Original script sender (address, padded to 32 bytes)
    3. Wei amount sent with transaction to storage
  @return store_data: A formatted storage request - first 64 bytes designate a forwarding address (and amount) for any wei sent
  */
  function setTransferAgentStatus(address _agent, bool _is_transfer_agent, bytes memory _context) public view
  returns (bytes32[] memory store_data) {
    // Ensure valid input
    if (_agent == address(0))
      bytes32("InvalidTransferAgent").trigger();

    // Parse context array and get sender address and execution id
    address sender;
    bytes32 exec_id;
    (exec_id, sender, ) = parse(_context);

    // Create 'read' calldata buffer in memory
    uint ptr = MemoryBuffers.cdBuff(RD_SING);
    // Place exec id and admin storage address location in memory
    ptr.cdPush(exec_id);
    ptr.cdPush(ADMIN);

    // Read from storage and store return in buffer -
    // Check that sender is equal to the returned admin address
    if (bytes32(sender) != ptr.readSingle())
      bytes32("SenderIsNotAdmin").trigger();

      // Sender is admin address - create storage buffer (overwrite previous read buffer), and set return values -
      ptr.stOverwrite(0, 0);
      // Push address transfer agent status storage location in storage buffer, followed by the passed-in status
      ptr.stPush(keccak256(keccak256(_agent), TOKEN_TRANSFER_AGENTS), _is_transfer_agent ? bytes32(1) : bytes32(0));

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
