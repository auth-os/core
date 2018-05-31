pragma solidity ^0.4.23;

import "./features/ProviderConsole.sol";
import "./App.sol";

library Provider {

  using Abstract for Abstract.Class;
  using ProviderConsole for Abstract.Feature;

  // The 'class' function function relevant to the external call and returns its reference
  function class(Abstract.Pointer memory _ptr) internal pure returns (
    function (Abstract.Pointer memory) pure returns (something)
  ) {
    // Tell the execution pointer where this class is located -
    _ptr.classAt('Provider');

    // Ensure calldata is valid

    // Return reference to registerApp -
    return ProviderConsole.feature;
  }

  /* //
  function registerApp(Abstract.Pointer memory _ptr) private view returns (smth) {
    //
  } */
}

library ProviderConsole {

  // Expected function selector for registerApp
  bytes4 private constant REGISTER_APP
          = bytes4(keccak256('registerApp(bytes32,address,bytes,bytes)'));

  function feature(Abstract.Pointer memory _ptr) internal pure returns (
    function (Abstract.Pointer memory) view
  ) {
    // Tell the execution pointer where this feature is located -
    _ptr.featureAt('ProviderConsole');
    // Validate external calldata selector matches expected 'registerApp' -
    if (msg.sig != REGISTER_APP) {
      _ptr.throws({
        message: 'invalid selector',
        expected: REGISTER_APP.primitive(),
        got: msg.sig.primitive()
      });
    }
  }

  /*
  Executes
  */
  function registerApp(Abstract.Pointer memory _ptr) private view returns (smth) {

  }
}
