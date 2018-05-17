pragma solidity ^0.4.23;

library RevertApp {

  // Used to check errors when function does not exist
  /* function rev0() public pure { } */

  function rev1() public pure {
    revert();
  }

  function rev2(bytes32 _message) public pure {
    assembly {
      mstore(0, _message)
      revert(0, 0x20)
    }
  }
}
