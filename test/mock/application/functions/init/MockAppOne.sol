pragma solidity ^0.4.23;

library MockAppOne {

  function funcOneAppOne() public pure returns (bytes32[] memory) {
    return new bytes32[](4);
  }


  function funcTwoAppOne() public pure returns (bytes32[] memory) {
    return new bytes32[](4);
  }
}
