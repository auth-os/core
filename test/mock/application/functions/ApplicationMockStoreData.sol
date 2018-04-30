pragma solidity ^0.4.23;

library ApplicationMockStoreData {

  bytes32 internal constant STORAGE_LOC_SING = keccak256('single_storage');
  bytes32 internal constant STORAGE_LOC_MULT = keccak256('multi_storage');
  bytes32 internal constant STORAGE_LOC_VAR = keccak256('variable_storage');
  bytes32 internal constant STORAGE_LOC_INVALID = keccak256('invalid_storage');

  function storeSingle(uint _store_val) public pure returns (bytes32[] memory store_data) {
    store_data = new bytes32[](4);
    store_data[2] = STORAGE_LOC_SING;
    store_data[3] = bytes32(_store_val);
  }

  function storeMulti(uint _store_val) public pure returns (bytes32[] memory store_data) {
    store_data = new bytes32[](6);
    store_data[2] = STORAGE_LOC_MULT;
    store_data[3] = bytes32(_store_val);
    store_data[4] = bytes32(32 + uint(STORAGE_LOC_MULT));
    store_data[5] = bytes32(1 + _store_val);
  }

  function storeVariable(uint _num_to_store, uint _store_val) public pure returns (bytes32[] memory store_data) {
    store_data = new bytes32[](2 + 2 * _num_to_store);
    uint storage_loc = uint(STORAGE_LOC_VAR);
    for (uint i = 0; i < _num_to_store; i++) {
      store_data[(i * 2) + 2] = bytes32((32 * i) + storage_loc);
      store_data[(i * 2) + 3] = bytes32(i + _store_val);
    }
  }

  function storeInvalid() public pure returns (bytes32[] memory store_data) {
    store_data = new bytes32[](3);
    store_data[2] = STORAGE_LOC_INVALID;
  }
}
