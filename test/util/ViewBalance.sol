pragma solidity ^0.4.23;

contract ViewBalance {

  function viewOwnerBalance(address _owner) public view returns (uint bal) {
    bal = address(_owner).balance;
  }
}
