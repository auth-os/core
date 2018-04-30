pragma solidity ^0.4.23;

library ApplicationMockErrorLib {

  function generic() public pure returns (bytes32[] memory) {
    revert();
  }

  function withMessage() public pure returns (bytes32[] memory) {
    bytes32 error = bytes32('TestingErrorMessage');
    assembly {
      mstore(0, error)
      revert(0, 0x20)
    }
  }
}
