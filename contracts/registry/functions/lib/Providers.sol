pragma solidity ^0.4.23;

import "./features/ProviderConsole.sol";
import "./App.sol";

library App {

  using Abstract for Abstract.Class;
  using Abstract for Abstract.Pointer;
  using AppConsole for Abstract.Feature;
}

library Provider {

  using Abstract for Abstract.Class;

  // The '_class' function function relevant to the external call and returns its reference
  function _class(Abstract.Class memory _ptr) internal pure returns (
    function (Abstract.Feature memory) pure returns (Abstract.Function memory)
  ) {
    // Tell the execution pointer where this class is located -
    _ptr.classAt();

    // Return reference to ProviderConsole -
    return ProviderConsole._feature;
  }

  // Exposes Apps.app_name for ProviderConsole -
  /* function app_name(Abstract.Feature memory _ptr) internal pure returns (bytes32) {

  }

  function registered_apps(Abstract.Pointer memory _ptr) private pure returns (bytes32) {

  } */
}

library ProviderConsole {

  // Expected function selector for registerApp
  bytes4 private constant REGISTER_APP
          = bytes4(keccak256('registerApp(bytes32,address,bytes,bytes)'));

  function _feature(Abstract.Feature memory _ptr) internal pure returns (
    function (Abstract.Function memory) view
  ) {
    // Tell the execution pointer where this feature is located -
    _ptr.featureAt();
    // Validate external calldata selector matches expected 'registerApp' -
    /* if (msg.sig != REGISTER_APP) {
      _ptr.throws({
        message: 'invalid selector',
        expected: REGISTER_APP.primitive(),
        got: msg.sig.primitive()
      });
    } */

    // Validate calldata TODO

    // Return reference to registerApp -
    return registerApp;
  }

  struct Calldata {
    bytes32 app_name;
    address app_storage;
    bytes app_description;
  }

  function calldata() private pure returns (Calldata memory) {

  }

  function app_name()

  /*
  Initializes a new application under the provider
  */
  function registerApp(Abstract.Pointer memory _ptr) private view {
    // Tell the execution pointer where this function is located -
    _ptr.functionAt();

    // Begin storing values -
    _ptr.storing();

    // Store new app name -
    _ptr.set(app_name).to(calldata.app_name)
  }
}
