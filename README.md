![auth_os](https://media.discordapp.net/attachments/376127621940903958/418225246559272981/auth_os-Logo-Authio.png)

### Description:

**auth_os** is a framework for creating, managing, and using applications on the EVM securely. Applications are modular, upgradable, extensible, and highly secure by design: using abstract storage of application data, application logic libraries define standard interfaces through which to interact with storage. The entire system is designed around a premise of creating the "most general, most abstract" approach to application development and use - allowing for unparalleled flexibility and interoperability between applications.

This repository contains the initial commits for a script Registry, as well as its storage contract.

### Explanation - Contracts and Functions:

##### Registry.sol:

The Registry contract implements the logic required for application developers to create, publish, and build on named applications. 

* Applications are stored in ```/APPS/sha(app_name)/```, and the following fields:

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

* Versions are stored in ```/APPS/sha(app_name)/VERSIONS/sha(ver_name)/```, and have the following fields:

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

* Functions are stored in ```/APPS/sha(app_name)/VERSIONS/sha(ver_name)/FUNCTIONS/sha(func_sig)```, and have the following fields:

  * ```Signature```: The plaintext signature of the function. Used to derive bytes4 function signature, as well as function parameters.
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

##### RegistryStorage.sol:

Registry storage is a simple abstract storage contract. Any address can request storage, but storage locations are seeded with the hash of the sender, preventing over-writes. Theoretically, a single abstract storage contract could store all the data from every contract running on the network. In practice, this may prove to be unsafe in many situations.

Abstract storage defines the following functions for writing to storage:

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
  
### Sample Inputs:

Below is a collection of sample inputs for a handful of Registry functions, along with explanations of their purpose.

* ```registerApp(bytes32 _app_name, bytes _app_desc)```:
  * Arguments:
    * ```_app_name```: "erc20basic"
    * ```_app_desc```: "A very basic erc20 application. Defines only the transfer and approve functions"
  * Purpose: Allows a developer to register an application name, similar to a 'repository' on github. Versions will be pushed into the application's storage namespace.
* ```registerVersion(bytes32 _app_name, bytes32 _ver_name, bytes _ver_desc)```:
  * Arguments:
    * ```_app_name```: "erc20basic"
    * ```_ver_name```: "v1.0"
    * ```_ver_desc```: "Initial version: implements transfer and approve"
  * Purpose: Allows a developer to register a named version with an existing application. Following version registry, the developer can provide implementation details, and release it for deployment.
* ```addVersionFunctions(bytes32 _app_name, bytes32 _ver_name, bytes32[] _func_sigs, bytes32[] _func_descs, address[] _func_impls)```:
  * Arguments:
    * ```_app_name```: "erc20basic"
    * ```_ver_name```: "v1.0"
    * ```_func_sigs```: ["transfer(address,uint256)", "approve(address,uint256)"]
    * ```_func_descs```: ["transfers tokens", "approves a spender"]
    * ```_func_impls```: ["0xabc", "0xdef"]
  * Purpose: Allows a developer to provide implementation details for a version, by providing function signatures, function descriptions, and implementing addresses. This function can be called repeatedly on one version to add more implementation details, but cannot be used after a version is initialized.
* ```initVersion(bytes32 _app_name, bytes32 _ver_name)```:
  * Arguments:
    * ```_app_name```: "erc20basic"
    * ```_ver_name```: "v1.0"
  * Purpose: Allows a developer to finalize a version, locking its implementation details and signifying that it is ready to be deployed and used. 
  
### Future Improvements:

The version presented here is fairly rough. Deployment cost for the Registry contract is high, and the onlyMod modifier limits use of the Registry structure to one party. Improving the Registry application will involve a few steps. Below is a list of a few preliminary ideas:

1. Implementation of Registry application using a library-interface structure:
  * Benefit: Lack of storage means that execution is truly dynamic, and more more in the spirit of the overall platform. Presumably, the user interacting with the Registry will provide the address of the storage contract they want to use, allowing for alternate storage addresses to be used with the same logic. Opening the system more means that anyone is free to develop and improve on the system.
  * Challenge: Using a library-interface structure means that the interfacing address will delegate calls to the Registry library logic, as well as call the storage contract directly to read/write data. This structure requires that the user keep track of more addresses, but this will hopefully be alleviated by application metadata contracts in the future.
2. Splitting the Registry application library logic into several different addresses:
  * Benefit: Allows for much more upgradability and extensibility, as smaller portions of the code can be upgraded at a time.
  * Challenge: Extending applications will require a much more involved permissioned read/write system than is currently implemented.
3. Creation of "fork" logic for developers:
  * Benefit: Allows developers to more easily build on top of other's work, by referencing parent applications and versions built by other developers.
  * Challenge: Requires some thought put into cross-seed reads and writes, so that forking is able to be done easily and efficiently.
4. Creation of a complimentary DNS-esque system:
  * Benefit: Creating a system where developers are able to register themselves, build and fork applications, and build identities within the network allows for much simpler collaboration between users of the network.
  * Challenge: Building this system requires a good amount of storage re-mapping, to accomodate DNS-based identities within applications

There are several other improvements and iterations to be made, but many involve the creation of other systems and applications. The important thing is to keep Registry (and platform) applications agile - so that when new standards and ideas are implemented, applications are not left obsolete.
