![auth_os](https://uploads-ssl.webflow.com/59fdc220cd54e70001a36846/5ac504590012b0bc9d789ab8_auth_os%20Logo%20Blue.png)

# auth_os core:

This package contains a set of contracts, libraries, and interfaces used in the development of auth_os applications. auth_os utilizes a unique application architecture to facilitate the building of contracts that are truly modular, as well as interoperable.

### Install:

`npm install authos-solidity`

### About:

auth_os combines a traditional 'upgrade by proxy' architecture with a new method for defining storage locations within an application - 'abstract storage'. This combination allows applications to be completely upgradable: application logic, storage targets for data, and data types can all be upgraded without fear of overwriting previously-defined values. This is accomplished in abstract storage through the use of relative storage locations, which emulate Solidity mappings save for the fact that these locations are able to define their own 'starting seed' for storage.

For example, defining a state variable creates, for that contract, a fixed point referencing a location in storage:
```Solidity
contract A {
  uint public a; // Will always reference storage slot 0
  uint public b; // Will always reference storage slot 1
}
```
The drawback of this is that changing the size of the data stored in `a` in a consecutive version will likely overwrite the value stored at `b`. In order to avoid this limitation, auth_os applications declare their data fields to be located at some hash, which is fed some unique, identifying seed. Any files referencing that seed will be able to read and interact with the same data as other files, though they may choose to interpret it in a different way. As an example:
```Solidity
// DO NOT USE IN PRODUCTION
library B {
  bytes32 constant NUM_OWNERS = keccak256("owner_list");

  // Get the number of owners`
  function getNumOwners() public view returns (uint num) {
    bytes32 owners = NUM_OWNERS;
    assembly { num := sload(owners) }
  }
}

library C {
  bytes32 constant OWNER_LIST = keccak256("owner_list");

  // Returns the location of the list index
  function ownerAt(uint _idx) internal pure returns (bytes32)
    { return bytes32(32 + (32 * _idx) + uint(OWNER_LIST)); }

  // Get the list of owners
  function getOwners() public view returns (address[] owners) {
    uint len;
    bytes32 list = OWNER_LIST;
    assembly { len := sload(list) }
    owners = new address[](len);
    for (uint i = 0; i < owners.length; i++) {
      bytes32 loc = ownerAt(i);
      address owner;
      assembly { owner := sload(loc) }
      owners[i] = owner;
    }
  }
}
```
In the above files, `B.getNumOwners()` will interpret the value stored at `NUM_OWNERS` as a simple `uint`. This is in contrast to `C.getOwners()`, which interprets the value stored there as a list, and returns the entire list to the caller. This concept allows for the implementation of complex types not supported in standard Solidity - the only prerequisite is to build the functions that interpret these locations in storage correctly. As a result of using this structure, applications can be sure that any upgrade they make will be overwrite-safe - as the hashed locations will take care of any potential overlaps between an applications fields.

Extending this concept, it is possible to implement a protocol through which unrelated applications can store their data in the same contract (same address) while still being able to deterministically read from these locations, as well as direct storage to write to these locations. Plainly, if abstract storage assigns a unique `id` to each instance of each application created within itself, we know that if storage location hashing is able to be enforced, applications can share the same storage contract without the risk of malicious (or unintentional) data overwrites.

Enforcing this behavior is simple - the basic premise is that the application, following execution, will return a formatted request to storage, which will ensure that each location to which data must be stored is first hashed with the application's unique `execution_id`. What is not so simple is: allowing for this open instantiation of applications within storage and enforcing this behavior, while remaining fairly efficient. Applications can be instantiated by anyone - and as a result must be treated with the utmost caution. Applications may attempt to overwrite data stored in other applications: it is imperative that the storage contract have safeguards in place to ensure that this is not possible.

The safeguards set in place depend primarily on the method of 'running' these instantiated applications. Initially, the storage contract used a `staticcall` to call the target application, while ensuring that no state change would occur as a result of running this external code. While this method works very well to ensure that executed applications are unable to call back into storage, or change the state of other apps, there is an unfortunate drawback in efficiency. Because `staticcall` does not use the calling contract's context, the executed application cannot read directly from storage and must rely on expensive external calls to read from storage. `AbstractStorage` exposes two functions for this - `read` and `readMulti`, which hash a location (or locations) with the passed-in `execution_id`, read the resulting data from storage, and return to the calling contract. Upon completion of execution, an application should have some list of storage locations along with data to commit to those locations. Instead of simply storing this data locally (not possible, as the app is a library and cannot change its state), the application `return`s a formatted request to storage, which parses and *safely* executes the instructions contained in this request. The parser is still being used, and its current current implementation can be found here: https://github.com/auth-os/core/blob/dev/contracts/core/AbstractStorage.sol#L174.

The obvious downside of these applications is the quickly-building cost of reading large amounts of data from storage. The implementing code required building buffers in runtime memory, which would be formatted to correctly request `read`s from storage. This, too, is a downside, as it requires building via a library that implements memory buffers - which is neither clean, nor simple to use.

Instead of using `staticcall` to execute applications, it would be much more efficient to use `delegatecall`. `delegatecall` allows external code to be executed in the context of the calling contract. In essence, executed applications would be able to read from state locally, without the overhead of an external call. While this operation drastically improves the efficiency of these applications, `delegatecall` poses its own risks. A contract called with `delegatecall` has near-complete autonomy over the calling contract's state. It can `sstore` to arbitrary locations and execute external code with unexpected effects. For example, a `delegatecall`ed application could execute the `selfdestruct` opcode, destroying the storage contract and removing the accumulated state of all of its hosted app instances. Clearly, `delegatecall` is dangerous - but if we could enforce a method by which a `delegatecall`ed application could not affect state, the efficiency increase would make this implementation a clear winner.

As it turns out, the same way that previously-described `staticcall`ed applications would return requests to store (and perform other actions) to storage following execution, a `delegatecall`ed application can incorporate the same mechanism by simply `revert`ing the same request to storage. `revert` can return data in exactly the same way `return` can - with the added effect that any state changes that took place during the call's execution, are reversed/removed. To add to this, the calling contract (`AbstractStorage`) can verify that this revert takes place - `delegatecall` will push a `0` (`false`) to the stack in the event that the call failed, and a `1` (`true`) on success. If storage sees that an application did not `revert` following execution, it is then able to `revert`, itself - ensuring that no unexpected state changes took place. If the storage contract observes a `revert` from its executed application, it can be sure that no malicious state change occured, and safely parse and execute its returned data.

### Benefits of upgrade by proxy + abstract storage + forced-revert delegatecall:

1. Applications should be able to be created in a way that makes re-using code not only trivial, but core to the implementation of the platform. Developers and users should have access to widely-used, templated contracts which can be simply, safely extended (without regard for changes in storage footprint).
2. Applications are built on a framework that is inherently receptive to upgradability - whether the application defines its own implementation of an upgrade protocol, or delegates this responsibility to some DAO or other authoritative body, upgradability itself should not be limited by types, storage footprint, locations, or anything else.
3. There is potential for serious interoperability between applications. Applications share the same storage contract - enabling other applications to directly view their data (with some pre-requisite knowledge of some interface or storage footprint). Before, this would require not only that the 'read target' define an explicit `get` function for the data being accessed, but also the gas overhead of an external call. Eliminating these requirements allows applications to read data stored by other applications in a vastly-more efficient and effective manner than before.
- It is interesting to note that combining the `execution_id`s of two or more applications results in a set of locations that can be stored to, that is unique to that combination of `execution_id`s. Using an XOR, this combination becomes commutative and associative (`a^b == b^a` and `a^(b^c) == (a^b)^c`) - meaning that it should be fairly straightforward for applications to come to some agreement about the locations and protocols governing these shared storage locations. It may be possible for applications to implement their own versions of inheritance within storage, whereby applications can instantiate a set of 'child' applications which all share some set of locations in storage, and where the protocol for reading/writing to these locations (i.e. the protocol for inter-application-communication) would be defined and enforced by the parent application.
- One interesting potential use-case is the creation of application-specific DAOs, where a set of similar applications would form their own 'DAO'. For example, perhaps every `ERC20` application together formed a DAO through which the `ERC20` standard itself could be upgraded or changed - then automatically carry out this upgrade, all without the pain of various 'custom' implementations lagging behind or not being supported.

### Downsides:

1. Currently, applications are not quite as readable as standard Solidity: https://github.com/auth-os/core/blob/dev/contracts/registry/features/Provider.sol#L55, as they must define and push to runtime memory buffers which hold formatted requests that will be parsed by storage (buffers were removed when reading data, but still exist when needing to `revert` data back to storage).
- They are also not as easy to write. Developers would do well to keep a careful eye on the order in which these buffers are added to - allocating memory unexpectedly (for example, declaring or returning a `struct`) could likely result in the allocated memory being overwritten as the buffer expands. Currently, there are a few basic checks in place to ensure that execution follows at least a very basic standard pattern, but this will need to be improved upon significantly if the system is to be usable by most developers.
- Some of the problems with readability lie with Solidity itself: lack of truly-usable memory and storage pointer types, as well as no real model for library inheritance, and no real 'generic' types means that in order to abstract auth_os' application implementations to a level where readability, writeability, and auditability find a happy balance, helper libraries chock full of assembly and low-level compiler manipulation must be incorporated (`Contract.sol`). Many of the aforementioned features are being actively worked on, but the current solutions for these problems are lacking.
2. `AbstractStorage` could be a single point of failure for several applications. While this is a very valid concern, this is exacerbated in a large amount by the current implementation of `AbstractStorage`. It incorporates an overly-complicated `bytes` parser which handles an application's output. While the current implementation is a large step up from the previous implementation (the last change abstracted a large portion of `AbstractStorage` and now allows applications to define many of these checks, requirements, and functions for themselves. This is a small step, but a step in the right direction - the implementation of `AbstractStorage` really deserves to be defined in hand-written bytecode - for maximum efficiency, and minimum complexity. Restricting functionality to a very small set of actions and treating `AbstractStorage` more as general I/O would hopefully simplify the implementation enough to be sure of security (especially with review from many developers).
- Still, the idea of a single point of failure is a large one to simply dismiss. Further work will be required to narrow down the functionality of `AbstractStorage` enough to consider

### Conclusion:

The combination of abstract storage, upgrade-by-proxy, and forced-revert delegatecall has the potential to define the kernel for a wide variety of truly modular applications. Applications built using this framework have the potential to be the most interoperable, extensible, and upgradable applications currently being built. There is still much to be learned as far as specific use-cases for this unique structure, but the potential it affords is too large to ignore.

With further development of Solidity, further protocol upgrades, and further second-layer solutions put in place, I believe that a version of this framework could serve as a cornerstone upon which many other upgradable, extensible, and inter-operable applications are built.
