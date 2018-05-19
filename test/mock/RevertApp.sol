pragma solidity ^0.4.23;

library RevertApp {

  bytes4 internal constant THROWS = bytes4(keccak256('throws:'));
  bytes4 internal constant STORES = bytes4(keccak256('stores:'));

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

  function throws1(bytes memory _message) public pure returns (bytes memory) {
    return abi.encodePacked(THROWS, _message.length, _message);
  }

  function throws2(bytes memory _message) public pure returns (bytes memory) {
    bytes memory temp = abi.encodeWithSelector(STORES, uint(1), uint(1), uint(1));
    return abi.encodePacked(temp, THROWS, _message.length, _message);
  }
}
