pragma solidity ^0.4.21;

import "../../contracts/core/ScriptExec.sol";


contract ScriptExecMock is ScriptExec {

    constructor(address _update_source, address _registry_storage, bytes32 _app_provider_id) 
        ScriptExec(_update_source, _registry_storage, _app_provider_id) public 
    {}

    function mockContext(bytes32 _exec_id, address _sender, uint _val) public pure returns (bytes _ptr) {
        _ptr = new bytes(96);
        assembly {
            mstore(add(0x20, _ptr), _exec_id)
            mstore(add(0x40, _ptr), _sender)
            mstore(add(0x60, _ptr), _val)
        }
    }

    function mockRegisterAppCallData(bytes32 _app_name, address _storage, bytes _app_description, bytes _ctx) public returns (bytes _ptr) {
        bytes4 _sel = bytes4(keccak256("registerApp(bytes32,address,bytes,bytes)"));
        _ptr = new bytes(msg.data.length);
        assembly {
            mstore(add(0x20, _ptr), _sel)
            calldatacopy(add(0x24, _ptr), 0x04, sub(calldatasize, 0x04))
        }
    }
}
