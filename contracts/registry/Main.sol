pragma solidity ^0.4.23;

import "../lib/Abstract.sol";
import "./classes/Provider.sol";
import "./classes/App.sol";

library Registry {

  using Abstract for Abstract.Contract;

  //// CLASS - Provider: ////

  /// Feature - Support: ///

  function supportApp(address app, bytes32 as_name) external view {
    // Execute using 'strict' specifications -
    Abstract.strictContract();
    // Invoke target class - Provider
    Abstract.invokeClass(Provider._class);
    // Forward calldata to Provider -
    Provider.registerApp(app_name, app_storage, app_desc);
    // Finish execution and finalize state -
    Abstract.finalize();
  }

  //// CLASS - App: ////

  /// Feature - Version: ///

  function version(address last, address latest) external view {

  }

  function release(address old, address stable) external view {

  }
}
