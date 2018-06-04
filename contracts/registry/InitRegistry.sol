pragma solidity ^0.4.23;

import "./lib/Contract.sol";
import "./Registry.sol";

library Initialize {

  using Contract for *;

  bytes32 internal constant EXEC_PERMISSIONS = keccak256('script_exec_permissions');

  // Returns the storage location of a script execution address's permissions -
  function execPermissions(address _exec) internal pure returns (bytes32 location) {
    location = keccak256(_exec, EXEC_PERMISSIONS);
  }

  // Token pre/post conditions for execution -

  // No preconditions for execution of the constructor -
  function first() internal pure { }

  // Ensure that the constructor will store data -
  function last() internal pure {
    if (Contract.stored() != 1)
      revert('Invalid state change');
  }

  // Simple init function - sets the sender as a script executor for this instance
  function init() internal view {
    // Begin storing init information -
    Contract.storing();

    // Authorize sender as an executor for this instance -
    Contract.set(execPermissions(msg.sender)).to(true);
  }
}
