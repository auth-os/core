pragma solidity ^0.4.23;

interface StorageInterface {
  function getTarget(bytes32 exec_id, bytes4 selector)
      external view returns (address implementation);
  function getIndex(bytes32 exec_id) external view returns (address index);
  function createInstance(address sender, bytes32 app_name, address provider, bytes32 registry_exec_id, bytes calldata)
      external payable returns (bytes32 instance_exec_id, bytes32 version);
  function updateInstance(address _sender, bytes32 _exec_id, bytes32 _app_name, address _provider, bytes32 _registry_id) external 
  returns (bytes32 version);
  function updateExec(bytes32 exec_id, address new_exec) external;
  function createRegistry(address index, address implementation) external returns (bytes32 exec_id);
  function exec(address sender, bytes32 exec_id, bytes calldata)
      external payable returns (uint emitted, uint paid, uint stored);
}
