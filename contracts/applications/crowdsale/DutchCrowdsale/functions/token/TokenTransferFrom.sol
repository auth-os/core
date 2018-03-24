pragma solidity ^0.4.21;

library TokenTransferFrom {

  /// CROWDSALE STORAGE ///

  // Whether or not the crowdsale is post-purchase
  bytes32 public constant CROWDSALE_IS_FINALIZED = keccak256("crowdsale_is_finalized");

  /// TOKEN STORAGE ///

  // Storage seed for user balances mapping
  bytes32 public constant TOKEN_BALANCES = keccak256("token_balances");

  // Storage seed for token 'transfer agent' status for any address
  // Transfer agents can transfer tokens, even if the crowdsale has not yet been finalized
  bytes32 public constant TOKEN_TRANSFER_AGENTS = keccak256("token_transfer_agents");

  // Storage seed for user allowances mapping
  bytes32 public constant TOKEN_ALLOWANCES = keccak256("token_allowances");

  /// FUNCTION SELECTORS ///

  // Function selector for storage 'readMulti'
  // readMulti(bytes32 exec_id, bytes32[] locations)
  bytes4 public constant RD_MULTI = bytes4(keccak256("readMulti(bytes32,bytes32[])"));

  /// EXCEPTION MESSAGES ///

  bytes32 public constant ERR_UNKNOWN_CONTEXT = bytes32("UnknownContext"); // Malformed '_context' array
  bytes32 public constant ERR_INSUFFICIENT_PERMISSIONS = bytes32("InsufficientPermissions"); // Action not allowed
  bytes32 public constant ERR_READ_FAILED = bytes32("StorageReadFailed"); // Read from storage address failed

  struct TransferFrom {
    bytes4 rd_multi;
    bytes32 sender_allowance_loc;
    uint sender_allowance;
    bytes32 from_balance_loc;
    uint owner_bal;
    bytes32 to_balance_loc;
    uint recipient_bal;
    bytes32 crowdsale_finalized_status_storage;
    bytes32 from_transfer_agent_storage;
  }

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
  function transferFrom(address _from, address _to, uint _amt, bytes _context) public view
  returns (bytes32[] store_data) {
    // Ensure valid inputs
    require(_to != address(0) && _amt != 0 && _from != address(0));
    if (_context.length != 96)
      triggerException(ERR_UNKNOWN_CONTEXT);

    // Parse context array and get sender address and execution id
    address sender;
    bytes32 exec_id;
    (exec_id, sender, ) = parse(_context);

    // Create struct in memory to hold values. Values are stored in-order as they would be returned in the return storage request
    TransferFrom memory tok_trans = TransferFrom({
      rd_multi: RD_MULTI,
      sender_allowance_loc: keccak256(keccak256(sender), keccak256(keccak256(_from), TOKEN_ALLOWANCES)),
      sender_allowance: 0,
      from_balance_loc: keccak256(keccak256(_from), TOKEN_BALANCES),
      owner_bal: 0,
      to_balance_loc: keccak256(keccak256(_to), TOKEN_BALANCES),
      recipient_bal: 0,
      crowdsale_finalized_status_storage: CROWDSALE_IS_FINALIZED,
      from_transfer_agent_storage: keccak256(keccak256(_from), TOKEN_TRANSFER_AGENTS)
    });

    // Create 'readMulti' calldata, and request owner and recipient balances, and sender allowance from storage
    assembly {
      let ptr := mload(0x40)
      // Place 'readMulti' selector at pointer
      mstore(ptr, mload(tok_trans))
      // Place exec id, data read offset, and read size in calldata
      mstore(add(0x04, ptr), exec_id)
      mstore(add(0x24, ptr), 0x40)
      mstore(add(0x44, ptr), 4)
      // Place owner and recipient balances, and sender allowance storage locations in calldata
      mstore(add(0x64, ptr), mload(add(0x40, tok_trans)))
      mstore(add(0x84, ptr), mload(add(0x60, tok_trans)))
      mstore(add(0xa4, ptr), mload(add(0x20, tok_trans)))
      // Place crowdsale finalization status and owner transfer agent status storage locations in calldata
      mstore(add(0xc4, ptr), mload(add(0xe0, tok_trans)))
      mstore(add(0xe4, ptr), mload(add(0x0100, tok_trans)))

      // Read from storage, and ensure call succeeds. Store returned data at pointer.
      let ret := staticcall(gas, caller, ptr, 0x0104, ptr, 0xe0)
      if iszero(ret) { revert (0, 0) }

      // Ensure that if the crowdsale is not finalized, owner is a transfer agent
      if iszero(mload(add(0xa0, ptr))) {
        // Crowdsale is not finalized - check owner transfer agent status
        if iszero(mload(add(0xc0, ptr))) {
          revert (0, 0)
        }
      }

      // Copy returned values to tok_trans struct
      mstore(add(0x80, tok_trans), mload(add(0x40, ptr)))
      mstore(add(0xc0, tok_trans), mload(add(0x60, ptr)))
      mstore(add(0x40, tok_trans), mload(add(0x80, ptr)))

      // Ensure sender has sufficient allowance, owner has sufficient balance, and recipient does not overflow -
      if lt(mload(add(0x40, tok_trans)), _amt) { revert (0, 0) }
      if lt(mload(add(0x80, tok_trans)), _amt) { revert (0, 0) }
      if lt(add(mload(add(0xc0, tok_trans)), _amt), mload(add(0xc0, tok_trans))) { revert (0, 0) }

      // Update returned values - subtract from owner balance and sender allowance, and add to recipient balance
      mstore(add(0x80, tok_trans), sub(mload(add(0x80, tok_trans)), _amt)) // Owner balance
      mstore(add(0xc0, tok_trans), add(mload(add(0xc0, tok_trans)), _amt)) // Recipient balance
      mstore(add(0x40, tok_trans), sub(mload(add(0x40, tok_trans)), _amt)) // Sender allowance

      // Store size at head of return array
      store_data := tok_trans
      mstore(store_data, 6) // 3 locations, 3 chunks of data to write
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
