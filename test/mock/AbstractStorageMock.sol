pragma solidity ^0.4.21;

import "../../contracts/storage/AbstractStorage.sol";
import "../../contracts/lib/StorageUtils.sol";


contract AbstractStorageMock is AbstractStorage {
    using StorageUtils for uint;

    bytes32 public constant INTERESTING_LOCATION_0 = keccak256("interesting_loc_0");
    bytes32 public constant INTERESTING_LOCATION_1 = keccak256("interesting_loc_1");
    bytes32 public constant INTERESTING_LOCATION_2 = keccak256("interesting_loc_2");

    bytes4 internal constant RD_MULTI = bytes4(keccak256("readMulti(bytes32,bytes32[])"));
}
