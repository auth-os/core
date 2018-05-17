pragma solidity ^0.4.23;

library StdApp {

  // stores to 1 slot
  function std1(bytes32 _loc, bytes32 _val) public pure returns (bytes32[] memory store_data) {
    store_data = new bytes32[](4);
    store_data[2] = _loc;
    store_data[3] = _val;
    return store_data;
  }

  // stores to 2 slots
  function std2(
    bytes32 _loc1, bytes32 _val1,
    bytes32 _loc2, bytes32 _val2
  ) public pure returns (bytes32[] memory store_data) {
    store_data = new bytes32[](6);
    store_data[2] = _loc1;
    store_data[3] = _val1;
    store_data[4] = _loc2;
    store_data[5] = _val2;
    return store_data;
  }
}
