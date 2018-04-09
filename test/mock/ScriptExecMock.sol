pragma solidity ^0.4.21;

import "../../contracts/exec/ScriptExec.sol";


contract ScriptExecMock is ScriptExec {

    function ScriptExecMock(address _update_source, address _registry_storage, bytes32 _registry_exec_id, bytes32 _app_provider_id) 
        ScriptExec(_update_source, _registry_storage, _registry_exec_id, _app_provider_id) public 
    {}
}
