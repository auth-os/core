pragma solidity ^0.4.20;

/*
Sample model for Registry.sol library
*/
library RegLibrarySample {

  ///
  // APPLICATION NAMESPACES:
  ///

  ///
  // VERSION NAMESPACES:
  ///

  ///
  // FUNCTION NAMESPACES:
  ///

  ///
  // OTHER CONSTANTS:
  ///

  bytes32 public constant MODERATOR = bytes32(keccak256("moderator"));

  bytes4 public constant READ_SIG = bytes4(keccak256("read(bytes32)"));

  // Sample onlyMod modifier - reads storage address, and checks that the sender is permissioned
  modifier onlyMod(address abstract_storage) {
    bytes4 read_sig = READ_SIG;
    bytes32 moderator = MODERATOR;
    bytes32 sender = bytes32(msg.sender);
    assembly {
      // Construct "read" calldata
      let ptr := mload(0x40)
      mstore(ptr, read_sig) // Place "read" funciton signature in memory
      mstore(add(0x04, ptr), moderator) // Place location (MODERATOR) in memory
      // Read from storage, overwrite ptr for return value
      let res := staticcall(gas, abstract_storage, ptr, 0x24, ptr, 0x20)
      // Read failed - revert
      if iszero(res) {
        revert (0, 0)
      }
      // If sender is not the moderator, revert
      if iszero(eq(sender, mload(ptr))) {
        revert (0, 0)
      }
    }
    _;
  }
}
