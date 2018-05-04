pragma solidity ^0.4.23;

library MockAppThree {

  function funcOneAppThree() public pure returns (bytes32[] memory) {
    return new bytes32[](4);
  }
}
