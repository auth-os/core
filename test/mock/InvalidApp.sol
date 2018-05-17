pragma solidity ^0.4.23;

library InvalidApp {

  // attempts to pay the storage contract
  function inv1(uint _val) public view returns (bytes32[] memory store_data) {
    store_data = new bytes32[](2);
    store_data[0] = bytes32(msg.sender);
    store_data[1] = bytes32(_val);
    return store_data;
  }

  // attempts to pay no one and store no data
  function inv2() public pure returns (bytes32[] memory store_data) {
    store_data = new bytes32[](2);
    store_data[0] = bytes32(0);
    store_data[1] = bytes32(0);
    return store_data;
  }

  // returns an odd number of return slots
  function inv3() public pure returns (bytes32[] memory store_data) {
    store_data = new bytes32[](5);
    return store_data;
  }

  // returns with a size not divisible by 64 bytes
  function inv4() public pure returns (bytes memory) {
    return new bytes(13);
  }

  // returns with a size under 128 bytes (0x80)
  function inv5() public pure returns (bytes32[2] memory) {
    return [bytes32(1), bytes32(1)];
  }
}
