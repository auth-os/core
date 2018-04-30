pragma solidity ^0.4.23;

library ApplicationMockPayableLib {

  function payoutAndStore(address _pay_to, uint _amt) public pure returns (bytes32[] memory store_data) {
    store_data = new bytes32[](4);
    store_data[0] = bytes32(_pay_to);
    store_data[1] = bytes32(_amt);
    store_data[2] = bytes32(0);
    store_data[3] = bytes32(0);
  }

  function payout(address _pay_to, uint _amt) public pure returns (bytes32[] memory store_data) {
    store_data = new bytes32[](2);
    store_data[0] = bytes32(_pay_to);
    store_data[1] = bytes32(_amt);
  }
}
