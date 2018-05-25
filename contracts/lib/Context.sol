pragma solidity ^0.4.23;

import "./Errors.sol";

library Context {

  struct Ctx {
    bytes32 exec_id;
    bytes32 sender;
    uint wei_sent;
  }

  function toCtx(bytes memory _context) internal pure returns (Ctx memory) {
    if (_context.length != 96)
      Errors.except('Error at Context.toCtx: invalid context');

    Ctx memory ret;
    assembly {
      ret := msize
      mstore(ret, add(0x20, _context))
      mstore(add(0x20, ret), add(0x40, _context))
      mstore(add(0x40, ret), add(0x60, _context))
      mstore(0x40, add(0x60, ret))
    }
    if (ret.exec_id == bytes32(0) || ret.sender == bytes32(0))
      Errors.except('Error at Context.toCtx: invalid context');

    return ret;
  }
}
