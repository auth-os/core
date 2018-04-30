pragma solidity ^0.4.21;

import '../core/AbstractStorage.sol';

contract RegistryStorage is AbstractStorage {

  // Function selector for the registry 'getAppLatestInfo' function. Used to get information relevant to initialiazation of a registered app
  bytes4 public constant GET_APP_INIT_INFO = bytes4(keccak256("getAppLatestInfo(address,bytes32,bytes32,bytes32)"));

  /*
  Hardcoded function - calls InitRegistry.getAppLatestInfo, and returns information

  @param _registry_exec_id: The execution id used with this registry app
  @param _app_provider: The id of the provider under which the app is registered
  @param _app_name: The name of the application to get information on
  @return bool 'is_payable': Whether the application has payable functionality
  @return address 'app_storage_addr': The storage address to be used with the application
  @return bytes32 'latest_version': The name of the latest stable version of the application
  @return address 'app_init_addr': The address containing the application's initialization function, as well as its getters
  @return address[] 'allowed': An array of addresses allowed to access app storage through the app storage address and script exec contract
  */
  function getAppInitInfo(bytes32 _registry_exec_id, bytes32 _app_provider, bytes32 _app_name) public view
  returns (bool, address, bytes32, address, address[]) {
    // Ensure valid input
    require(_registry_exec_id != bytes32(0) && _app_provider != bytes32(0) && _app_name != bytes32(0));

    // Place function selector in memory
    bytes4 app_init = GET_APP_INIT_INFO;

    // Get registry init address
    address target = app_info[_registry_exec_id].init;
    bool is_payable = app_info[_registry_exec_id].is_payable;

    assembly {
      // Get pointer for calldata
      let ptr := mload(0x40)
      // Set function selector
      mstore(ptr, app_init)
      // Place registry address (this), registry exec id, app provider id, and app name in calldata
      mstore(add(0x04, ptr), address)
      calldatacopy(add(0x24, ptr), 0x04, sub(calldatasize, 0x04)) // Copy registry exec id, provider, and app name from calldata
      // Read from storage
      let ret := staticcall(gas, target, ptr, 0x84, 0, 0)
      if iszero(ret) { revert (0, 0) }

      // Copy returned data to pointer, set is_payable, and return
      mstore(ptr, is_payable)
      returndatacopy(add(0x20, ptr), 0, 0x60)
      mstore(add(0x80, ptr), 0xa0)
      returndatacopy(add(0xa0, ptr), 0x80, sub(returndatasize, 0x80))
      return (ptr, add(0x20, returndatasize))
    }
  }
}
