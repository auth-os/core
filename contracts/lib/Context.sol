pragma solidity ^0.4.23;

import "./Errors.sol";

library Context {

  // Parses context array and returns execution id, sender, and sent wei amount
  function parse(bytes memory _context) internal pure returns (bytes32 exec_id, bytes32 sender, uint wei_sent) {
    // Validate input
    if (_context.length != 96)
      Errors.except('Error at Context.parse: invalid context length');

    assembly {
      exec_id := mload(add(0x20, _context))
      sender := mload(add(0x40, _context))
      wei_sent := mload(add(0x60, _context))
    }
    // Validate result
    if (sender == bytes32(0))
      Errors.except('Error at Context.parse: invalid sender');
    if (exec_id == bytes32(0))
      Errors.except('Error at Context.parse: invalid exec_id');
  }
}
