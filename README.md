![auth_os](https://media.discordapp.net/attachments/376127621940903958/418225246559272981/auth_os-Logo-Authio.png)

### Description:

**auth_os** is a framework for creating, managing, and using applications on the EVM securely. Applications are modular, upgradable, extensible, and highly secure by design: using abstract storage of application data, application logic libraries define standard interfaces through which to interact with storage. The entire system is designed around a premise of creating the "most general, most abstract" approach to application development and use - allowing for unparalleled flexibility and interoperability between applications.

This repository contains the beta version of a script registry application - the foundation for a larger network of applications.

### Explanation - Contracts and Functions:

##### RegistryScriptExec.sol:

The RegistryScriptExec contract implements logic for executing storage read and write requests from allowed sources. These allowed sources can be defined on a per-application basis using the 'initRegistryApp' function, which provides the caller with a unique 'exec id,' which seeds all storage requests for the given application.

The 'exec' function forwards input calldata ('script' parameter) to a target address. The target address returns data, designated by either a 'const_return' field (data is not stored, and is returned for the user to view), or a 'request_storage' field. If a 'request_storage' value is returned, the script exec contract expects another parameter - a bytes32[], with abstract storage 'writeMulti' format. This array is passed to the storage interface contract (PermissionedRegStorage), which determines whether the sender has permissions to write to the given exec id storage, and then executes the storage request.

Future versions of this contract will include capability to string together multiple exec calls, for more dynamic, extendable application interactions.

##### /registry/RegisterApp.sol:

The RegisterApp contract implements the logic required for application developers to create named applications, for which implementation details can be supplied.

* Applications are stored in ```/PROVIDERS/sha(provider_addr)/APPS/sha(app_name)/```, and have the following fields:

  * ```Name```: The name of an application. Serves as the basis for an application's storage: description, and version information.
    * Read size: 32 bytes
    * Storage type: ```bytes32```
    * Storage location: ```/APPS/sha(app_name)/```
  * ```Description```: A short description of what an application does. 
    * Read size: dynamic (length in bytes stored at base)
    * Storage type: ```bytes```
    * Storage location: ```/APPS/sha(app_name)/APP_DESC/```
  * ```Version list```: A list of all versions of this applications, in order. Versions store implementation and usage data.
    * Read size: dynamic
    * Storage type: ```bytes32[]```
    * Storage location: ```/APPS/sha(app_name)/APP_VERSIONS_LIST/```

##### /registry/RegisterVersion.sol:

The RegisterVersion contract implements the logic required for application developers to extend and upgrade registered applications, as well as define application implementation details. Future versions will include explicit fields where application upgrade and initialization behavior can occur.

* Versions are stored in ```/PROVIDERS/sha(provider_addr)/APPS/sha(app_name)/VERSIONS/sha(ver_name)/```, and have the following fields:

  * ```Name```: The name of the version. Serves as the basis for an application's storage: description, functions, and more.
    * Read size: 32 bytes
    * Storage type: ```bytes32```
    * Storage location: ```/VERSIONS/sha(ver_name)/```
  * ```Description```: A short description of a version. Can act as a change log from previous versions
    * Read size: dynamic (length in bytes stored at base)
    * Storage type: ```bytes```
    * Storage location: ```/VERSIONS/sha(ver_name)/VER_DESC/```
  * ```Status```: The status of a version - whether its creator has deemed it ready for deployment and use. Versions cannot be changed once they are initialized.
    * Read size: 32 bytes
    * Storage type: ```bool```
    * Storage location: ```/VERSIONS/sha(ver_name)/VER_IS_INIT/```
  * ```Function list```: A list of all functions this version implements. Functions are stored as plaintext, from which function signatures and parameter types can be derived. Eventually, function signatures will be improved to allow derivation of return values, as well as additional features.
    * Read size: dynamic (length in uint stored at base)
    * Storage type: ```bytes32[]```
    * Storage location: ```/VERSIONS/sha(ver_name)/VER_FUNCTION_LIST/```
  * ```Version index```: The index of this version in the parent application's ```Version list```.
    * Read size: 32 bytes
    * Storage type: ```uint256```
    * Storage location: ```/VERSIONS/sha(ver_name)/APP_VER_INDEX/```

##### /registry/ImplementVersion.sol:

The ImplementVersion contract contains the logic required for application developers to define application implementation details - including function signatures, function descriptions, and addresses which implement said functions.

* Functions are stored in ```/APPS/sha(app_name)/VERSIONS/sha(ver_name)/FUNCTIONS/sha(func_sig)```, and have the following fields:

  * ```Signature```: The plaintext signature of the function. Used to derive bytes4 function selector, as well as function parameters.
    * Read size: 32 bytes
    * Storage type: ```bytes32```
    * Storage location: ```/FUNCTIONS/sha(func_sig)/```
  * ```Description```: A short description of a function. Function descriptions are limited to 32 bytes, for the time being.
    * Read size: 32 bytes
    * Storage type: ```bytes32```
    * Storage location: ```/FUNCTIONS/sha(func_sig)/FUNC_DESC```
  * ```Implementing address```: The address which implements this function. Using this, along with the derived function signature an parameter list, a user can call the function located at the address.
    * Read size: 32 bytes
    * Storage type: ```address``` 
    * Storage location: ```/FUNCTIONS/sha(func_sig)/FUNC_IMPL_ADDR```
  * ```Function index```: The index of this function in the parent version's ```Function list```.
    * Read size: 32 bytes
    * Storage type: ```uint256```
    * Storage location: ```/FUNCTIONS/sha(func_sig)/VER_FUNC_INDEX```

##### /storage/PermissionedRegStorage.sol:

Registry storage uses a simple abstract storage contract, which is interacted with through the PermissionedRegStorage contract. PermissionedRegStorage implements storage permissions, which are tied to unique 'exec ids,' a list of 'allowed' addresses, and a script executor. Any address can request storage, but storage locations are seeded with the hash of the sender (and exec id), preventing over-writes. Theoretically, a single abstract storage contract could store all the data from every contract running on the network. In practice, this may prove to be unsafe in many situations.

Abstract storage defines the following functions for writing to storage (which PermissionedRegStorage mirrors, adding storage address and exec id parameters):

* ```write(bytes32 _location, bytes32 _data)```: Used to write to a single slot in storage.
  * Calldata size: 68 bytes (64-byte arguments, plus signature)
  * Returns: Location written to
  * Returndata size: 32 bytes
  * Return type: ```bytes32```
* ```writeMulti(bytes32[] _input)```: Used to write to several slots in storage. Format is defined as alternating indices of locations to store in, followed by the data to store in those locations. Each individual location in writeMulti is hashed in the same manner as ```write```.
  * Calldata size: dynamic, minimum 132 bytes (32-byte offset, 32-byte length, 64-byte location and data, plus signature)
  * Returns: Number of writes performed
  * Returndata size: 32 bytes
  * Return type: ```uint```

The following functions are defined for reading from storage:

* ```read(bytes32 _location)```: Used to read from a single slot in storage. Read requests are hashed with the address of the sender, so that contracts are able to read from the same locations they wrote to.
  * Calldata size: 36 bytes (32-byte argument, plus signature)
  * Returns: Data stored at location
  * Returndata size: 32 bytes
  * Return type: ```bytes32```
* ```readMulti(bytes32[] _locations)```: Used to read from several slots in storage. Each location is seeded in the same manner as in ```read```.
  * Calldata size: dynamic, minimum 100 bytes (32-byte offset, 32-byte length, 32-byte location, plus signature)
  * Returns: Array containing data stored in locations
  * Returndata size: dynamic, minimum 96 bytes (32-byte offse, 32-byte length, 32-byte data)
  * Return type: ```bytes32[]```
* ```readTrueLocation(bytes32 _location)```: Used to read directly from storage. Read request is not seeded, and will return data from the exact location specified.
  * Calldata size: 36 bytes (32-byte location, plus signature)
  * Returns: Data stored in unseeded location
  * Returndata size: 32 bytes
  * Return type: ```bytes32```

The following utility functions are defined:

* ```getTrueLocation(bytes32 _location)```: Returns the true storage location associated with the sender and the passed-in location.
  * Calldata size: 36 bytes (32-byte location, plus signature)
  * Returns: True storage location, hashed with the address of the sender
  * Returndata size: 32 bytes
  * Return type: ```bytes32```
* ```getLocationWithSeed(bytes32 _location, address _seed)```: Returns the true storage location associated with the passed-in location and seed. Future versions will move away from using addresses as seeds, at which point this function will be deprecated for a function which takes two bytes32 inputs.
  * Calldata size: 68 bytes (64-byte arguments, plus signature)
  * Returns: True storage location, hashed with the passed-in address
  * Returndata size: 32 bytes
  * Return type: ```bytes32```
