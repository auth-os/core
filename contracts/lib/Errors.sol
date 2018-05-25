pragma solidity ^0.4.23;

library Errors {

  // ACTION REQUESTORS //

  bytes4 internal constant THROWS = bytes4(keccak256('throws:'));

  function except(string memory _error) internal pure {
    bytes4 action = THROWS;
    assembly {
      // Data read offset
      mstore(0, 0x20)
      // Revert length
      mstore(0x20, add(0x24, mload(_error)))
      // Action requestor
      mstore(0x40, action)
      let offset := 0x00
      for { } lt(offset, add(0x20, mload(_error))) { offset := add(0x20, offset) } {
        mstore(add(0x44, offset), mload(add(offset, _error)))
      }
      revert(0, add(0x44, offset))
    }
  }
}
