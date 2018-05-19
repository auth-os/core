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
    return abi.encodeWithSelector(THROWS, uint(4), bytes4(0xffffffff));
  }

  bytes32 internal constant EVENT_TOPIC = keccak256("EventEmitted(address)");

  /* function initEmits() public pure returns (bytes memory) {
    return abi.encodeWithSelector(EMITS, uint(1), uint(1), EVENT_TOPIC, )
  } */

  function initValidSingle(bytes32 _loc, bytes32 _val) public pure returns (bytes memory) {
    store_data = new bytes(4);
    store_data[2] = _loc;
    store_data[3] = _val;
    return store_data;
  }

  function initValidMulti(bytes32 _loc1, bytes32 _val1, bytes32 _loc2, bytes32 _val2) public pure returns (bytes memory) {
    store_data = new bytes(6);
    store_data[2] = _loc1;
    store_data[3] = _val1;
    store_data[4] = _loc2;
    store_data[5] = _val2;
    return store_data;
  }
}
