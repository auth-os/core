pragma solidity ^0.4.23;

library MockAppTwo {

  function funcOneAppTwo() public pure returns (bytes32[] memory) {
    return new bytes32[](4);
  }

}
