pragma solidity ^0.4.23;

import "./classes/Provider.sol";
import "./classes/App.sol";
import "./classes/Version.sol";

library ScriptRegistry {

  using Abstract for Abstract.Contract;

  function registerApp(bytes32 app_name, address app_storage, bytes memory app_desc, bytes memory context)
  external view {
    // Declare Registry instance -
    Abstract.Contract memory registry = Abstract.contractAt();
    // Initialize Provider as the effected class, and set the relevant feature as the target -
    registry.resolve(Provider._class);
    // Forward calldata to Provider -
    registry.invoke();
    // Finish execution and finalize state -
    registry.finalize();
  }

  function registerApp(bytes32 app_name, address app_storage, bytes memory app_desc, bytes memory context)
  external view {
    // Set initial state for memory, as well as initial context reference -
    Abstract.executing('ScriptRegistry');
    // Initialize Provider as the effected class, and set the relevant feature as the target -
    registry.resolve(Provider._class);
    // Forward calldata to Provider -
    registry.invoke();
    // Finish execution and finalize state -
    registry.finalize();
  }

  function registerVersion(bytes32 app_name, bytes32 ver_name, address ver_storage, bytes memory ver_desc, bytes memory context)
  external view {
    // Declare Registry instance -
    Abstract.Contract memory registry = Abstract.contractAt();
    // Initialize App as the effected class, and set the relevant feature as the target -
    registry.targets(App._class);
    // Forward calldata to App -
    registry.invokes(registry.target);
    // Finish execution and finalize state -
    registry.finalize();
  }

  /* function addFunctions() */

  /* function finalizeVersion(bytes32 app_name, bytes32 ver_name, address ver_main, bytes4 init_selector, bytes memory context)
  external view {
    // Declare Registry instance -
    Abstract.Contract memory registry = Abstract.contractAt();
    // Initialize App as the effected class, and set the relevant feature as the target -
    registry.targets(App._class);
    // Forward calldata to App -
    registry.invokes(registry.target);
    // Finish execution and finalize state -
    registry.finalize();
  } */


}
