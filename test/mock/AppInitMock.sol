pragma solidity ^0.4.23;

library AppInitMock {

  bytes4 internal constant EMITS = bytes4(keccak256('emits:'));
  bytes4 internal constant STORES = bytes4(keccak256('stores:'));
  bytes4 internal constant PAYS = bytes4(keccak256('pays:'));
  bytes4 internal constant THROWS = bytes4(keccak256('throws:'));

  function init() public pure { }

  function initInvalid() public pure returns (bytes memory) {
    return new bytes(31);
  }

  function initNullAction() public pure returns (bytes memory) {
    return new bytes(36);
  }

  function initThrowsAction() public pure returns (bytes memory) {
    bytes memory temp = abi.encodeWithSelector(THROWS, uint(4));
    return abi.encodePacked(temp, bytes4(0xffffffff));
  }

  function initEmits(bytes32 _t1) public pure returns (bytes memory) {
    return abi.encodeWithSelector(EMITS, uint(1), uint(1), _t1, uint(0));
  }

  function initPays(address _dest, uint _amt) public pure returns (bytes memory) {
    return abi.encodeWithSelector(PAYS, uint(1), _amt, _dest);
  }

  function initStores(bytes32 _location, bytes32 _val) public pure returns (bytes memory) {
    return abi.encodeWithSelector(STORES, uint(1), _val, _location);
  }
}
