pragma solidity ^0.4.23;

library StdAppContext {

  bytes4 internal constant STORES = bytes4(keccak256('stores:'));

  // stores to 0 slots
  function std0(bytes memory) public pure returns (bytes memory) {
    return abi.encodeWithSelector(STORES, uint(0));
  }

  // stores to 1 slot
  function std1(bytes32 _location, bytes32 _val, bytes memory) public pure returns (bytes memory) {
    return abi.encodeWithSelector(STORES, uint(1), _val, _location);
  }

  // stores to 2 slots
  function std2(
    bytes32 _loc1, bytes32 _val1, bytes32 _loc2, bytes32 _val2, bytes memory
  ) public pure returns (bytes memory) {
    return abi.encodeWithSelector(
      STORES, uint(2), _val1, _loc1, _val2, _loc2
    );
  }
}
