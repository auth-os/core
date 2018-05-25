pragma solidity ^0.4.23;

/**
Written by: Alexander Wade

===
Implements an application build structure that enforces specifications for
execution, as well as type safety, and many other things not implemented by
vanilla Solidity.
===
Among other things, enforces some simple inheritance and process flow -

'Contracts' -> define -> 'Classes'
'Classes' -> implement -> 'Features'
'Features' -> execute -> 'Functions'

Each of these abstractions is allowed a set of functions, most of which must be
called in some particular order, so that the execution of an application happens
in a predictable, explicitly-defined manner.
===
- Process flow -

`Contract`:
A single file exposes the API of the `Contract` through external functions. These
external functions mirror what they would in a standard application. A 'Contract'
struct's lifetime is entirely within the confines of this function.
A 'Contract' expects its functions to be invoked in the following order -
Abstract.contractAt(string) -> contract.targets() -> contract.invokes() -> contract.finalize()
NOTE: `Contracts` do NOT allow memory allocation within the external function in which
they are initialized. This is to prevent unexpected memory allocation overwriting (or
being overwritten) by the memory buffers employed by this library. When a `Contract`
is initialized, it is initialized directly from 0x80, overwriting any values.
*/
library Abstract {

  // High-level 'Contract' struct
  struct Contract {
    uint ptr;
    function () pure target;
  }
  // 'Contracts' define 'Classes'
  struct Class {
    uint ptr;
    function () pure classAt;
  }
  // 'Classes' implement 'Features'
  struct Feature {
    uint ptr;
    function () pure featureAt;
  }
  // 'Features' execute 'Functions'
  struct Function {
    uint ptr;
    function () pure functionAt;
  }

  // Initializes a 'Contract' pointer at 0x80 in memory
  function contractAt() internal pure returns (Contract memory init) {
    assembly { init := 0xa0 }
  }

  // The central function for the `Contract` - routes all _ptr calls made
  // Valid function calls made should resolve to this function
  function control() private pure {
    // Expect a reference to this function to be stored at 0xc0
    assembly {
      let ref := mload(0xc0)
      if iszero(eq(ref, control)) {
        mstore(0, 'FUCK')
        revert(0, 0x20)
      }
    }
    //
  }

  function targets(
    Contract memory _self,
    function (Class memory) pure returns (
      function (Feature memory) pure returns (Function memory)
    ) _class
  ) internal pure {
    // _self should be 0xa0
    uint temp;
    assembly { temp := _self }
    if (temp != 0xa0) revert ('Invalid pointer - targets');

    // Set 'classAt' call destination to control
    assembly { mstore(0xc0, control) }
    // Create mock function for _class -
    function (uint) pure returns (uint) mock;
    assembly { mock := _class }
    // Call _class via the mock function -
    temp = mock(temp);
    // Reset mock function to call returned function
    assembly { mock := temp }
    // Call returned function -
    temp = mock(temp);
    // return value
    assembly { a := temp }
  }
}
