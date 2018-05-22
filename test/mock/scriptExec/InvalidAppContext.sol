pragma solidity ^0.4.23;

library InvalidAppContext {

  bytes4 internal constant EMITS = bytes4(keccak256('emits:'));
  bytes4 internal constant STORES = bytes4(keccak256('stores:'));
  bytes4 internal constant PAYS = bytes4(keccak256('pays:'));

  // attempts to pay the storage contract
  function inv1(bytes memory) public view returns (bytes memory) {
    return abi.encodeWithSelector(
      PAYS, uint(1), msg.sender, uint(5)
    );
  }

  // does not change state
  function inv2(bytes memory) public pure returns (bytes memory) {
    return abi.encodeWithSelector(
      EMITS, uint(0), STORES, uint(0), PAYS, uint(0)
    );
  }
}
