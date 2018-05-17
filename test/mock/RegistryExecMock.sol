pragma solidity ^0.4.21;

import "../../contracts/registry/RegistryExec.sol";


contract RegistryExecMock is RegistryExec {

    constructor(address _exec_admin, address _update_source, address _registry_storage, bytes32 _app_provider) 
        RegistryExec(_exec_admin, _update_source, _registry_storage, _app_provider) public 
    {}

    function mockContext(bytes32 _exec_id, bytes32 _provider, uint _val) public pure returns (bytes _ptr) {
        _ptr = new bytes(96);
        assembly {
            mstore(add(0x20, _ptr), _exec_id)
            mstore(add(0x40, _ptr), _provider)
            mstore(add(0x60, _ptr), _val)
        }
    }
}
