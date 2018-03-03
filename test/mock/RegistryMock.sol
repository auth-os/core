pragma solidity ^0.4.20;

import '../../contracts/registry/Registry.sol';

contract RegistryMock is Registry {
    function RegistryMock(address _abs_storage) Registry(_abs_storage) public {}
}
