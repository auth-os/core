![auth_os](https://media.discordapp.net/attachments/376127621940903958/418225246559272981/auth_os-Logo-Authio.png)

### Description:

**auth_os** is a framework for creating, managing, and using applications on the EVM securely. Applications are modular, upgradable, extensible, and highly secure by design: using abstract storage of application data, application logic libraries define standard interfaces through which to interact with storage. The entire system is designed around a premise of creating the "most general, most abstract" approach to application development and use - allowing for unparalleled flexibility and interoperability between applications.

This repository contains the beta version of a script registry application - the foundation for a larger network of applications.

### Explanation - Contracts and Functions:

##### General Structure:

Applications consist of 3 parts - a script executor, a storage address, and a logic address. The storage address uses abstract storage, and implements a permissioned system, where application instances have a defined set of contracts which can interact with the application. For example, a token contract may have 3 logic contracts (transfer, transferFrom, approve, for example), and one 'init' contract. An application's 'init' contract generally houses the majority of the getter functions for the application, as well as the 'init' function, which is called upon initialization from the storage contract. The init function acts as a constructor, setting important initial variables in an application's lifetime. The script executor contract manages on a high level application initialization, upgrades, and execution of application functions.

Application definitions (implementation details, versions, descriptions, etc) are generally stored in a script registry, which is itself an application in the system. All applications have execution ids - an id generated uniquely by the storage contract. The execution id is used as a seed for all storage - which means there is no upper limit on the number of active applications using storage - all application instances have a unique execution id, and so all application instances may use the same storage contract. When using an application, it is important to know which execution id the instance you are trying to use requires. Much like sending your transaction to the wrong contract address, you don't want to send your transaction using the wrong execution id.

##### Application Lifecycle - Registration, Implementation, and Release:

(Reference: /registry/functions/)

When using a script registry contract to store or read information on already-deployed applications, there are a few steps to take from registration to release. An application is initially registered by a 'provider.' The provider is simply an id generated from the address of the person who registered the application. Applications are registered under the provider, and only the provider may add versions, implementations, etc. The InitRegistry contract contains several useful getters for reading application and version information.

An application is first registered in AppConsole, using registerApp. The provider simply defines an application name, storage address, and description, which is placed in registry storage (the calling contract - these functions are executed through a RegistryStorage contract, or by proxy through ScriptExec).

Following application registration, a provider may register a version under that application, using VersionConsole. Versions are named, and are placed in a list within application storage. Registering a version simply sets the version's name, version storage address (optional - leave empty to use application storage address), and a version's description. Versions define implementations - using ImplementationConsole, a provider may add implemented functions, addresses where those functions are implemented, and descriptions of functions. A provider may add as much or as little implementation detail as they like, until the version is 'finalized.' Finalizing a version is done through VersionConsole.finalizeVersion, and locks version information storage. This version is now considered 'stable,' which others will likely use to determine whether or not to initialize the version.

##### Application Lifecycle - Initialization and Usage:

Applications are initialized through the ScriptExec contract - by specifying the registry storage address to pull app implementation and initialization details from, anyone can deploy an application by simply specifying the registry execution id where applications are registered. ScriptExec.sol currently handles many aspects of initalization, use,upgrading, and migration - but will be opened to more general-use functionality in the future.

Upon initializing an application, the specified storage address returns the app's unique execution id, through which application storage requests are made. The ScriptExec contract, application storage contract, and execution id form a key together: ensuring applications are only input data which is permitted by the ScriptExec contract, and that applications are only governed by logic addresses which are permitted by the storage contract.

Upon initialization of the application, the application can be used by calling the ScriptExec 'exec' function, targeting the desired address to forward the request to.

##### Conclusion:

Several of these contracts have been deployed to Ropsten, to allow for open testing. Below is a list of the verified contracts being used:

RegistryStorage: 0x253dc5A398ff89A0b1bD00DE73c8865a7C062aee
InitRegistry: 0x0B4567Ac84e2244f9C9c1169005b995102A9Bb1f
AppConsole: 0x2e75962C92662468722E5b50319141a6C214C91c
VersionConsole: 0x9bDddD9EBEaE1c4C7A3C5f75Dba092E7a827efE4
ImplementationConsole: 0x030CAf41dFEccb4EE6AA6f126e499f908Fd48099
TokenTransfer: 0xB62AF075e8EEa16154775F45F884865aD10d4d2B
InitToken: 0xE87e1565A9Ac331339A6015A50fe01aC6Cfd7387
ScriptExec: 0x3B9A54A62002bc6aC3a60E9744b20063B077b1aB

The 'default' variables in ScriptExec.sol can be examined for information on the registry's execution id, as well as the storage address of the registry. 

InitToken and TokenTransfer are both registered in the script registry, and serve as a very simple introductory application - an ERC20 contract, implementing only 'transfer' (and, of course, 'init'). They can be initialized through the ScriptExec 'initAppInstance' function, which requires InitToken.init calldata, as well as the name of the application ('erc20'). The ScriptExec contract will automatically pull the designated stable version from the registry.
