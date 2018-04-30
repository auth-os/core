pragma solidity ^0.4.23;

contract ForceSendEther {

  function forcePay(address _a) public payable {
    selfdestruct(_a);
  }
}
