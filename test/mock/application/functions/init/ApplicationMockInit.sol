pragma solidity ^0.4.21;

import "../../../../../contracts/lib/StorageUtils.sol";


library ApplicationMockInit {
    using StorageUtils for uint;

    bytes32 public constant MOCK_APP_INIT_LOCATION = keccak256("mock_app_init_loc");

    function init() public pure returns (bytes32[] store_data) {
        uint ptr = StorageUtils.stBuff();
        ptr.stPush(MOCK_APP_INIT_LOCATION, 0);
        ptr.stPush(MOCK_APP_INIT_LOCATION, 0);
        store_data = ptr.getBuffer();
    }
}
