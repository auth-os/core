![auth_os](https://uploads-ssl.webflow.com/59fdc220cd54e70001a36846/5ac504590012b0bc9d789ab8_auth_os%20Logo%20Blue.png)

### Description:

**auth_os** is a framework for creating, managing, and using applications on the EVM securely. Applications are modular, upgradable, extensible, and highly secure by design: using abstract storage of application data, application logic libraries define standard interfaces through which to interact with storage. The entire system is designed around a premise of creating the "most general, most abstract" approach to application development and use - allowing for unparalleled flexibility and interoperability between applications.

This repository contains the beta version of a script registry application - the foundation for a larger network of applications.

### Explanation - Contracts and Functions:

##### General Structure:

Applications consist of 3 parts - a script executor, a storage address, and a set of logic addresses. The storage address uses abstract storage, and implements a permissioned system, where application instances have a defined set of contracts which can interact with the application. For example, a token contract may have 3 logic contracts (transfer, transferFrom, approve, for example), and one 'init' contract. An application's 'init' contract generally houses the majority of the getter functions for the application, as well as the 'init' function, which is called upon initialization from the storage contract. The init function acts as a constructor, setting important initial variables in an application's lifetime. The script executor contract manages on a high level application initialization, upgrades, and execution of application functions.

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

##### Testing:

Several of these contracts have been deployed to Ropsten, to allow for open testing. Below is a list of the verified contracts being used:

1. RegistryStorage: https://ropsten.etherscan.io/address/0x8d1084b586cb4b298bea5550ad020c9de7fc48c5#code
2. InitRegistry: https://ropsten.etherscan.io/address/0xf177bdb5b7f84f1f3b2c5e43a6a86ef1b799104d
3. AppConsole: https://ropsten.etherscan.io/address/0x55f5048168f8435e26b3d26a1c19175e1d9bb834#code
4. VersionConsole: https://ropsten.etherscan.io/address/0x19641c9158a9e0236191f746d562781ba8fa7b7b#code
5. ImplementationConsole: https://ropsten.etherscan.io/address/0x166dc2880f0b156bd2545fe02917f230a8713f09#code
6. InitCrowdsale: https://ropsten.etherscan.io/address/0x81e14e24c8148979507daee78f8558079e2f8c59#code
7. CrowdsaleConsole: https://ropsten.etherscan.io/address/0xe24c915d52ddc021ee7dc6401cd9a4e38a2cf27d#code
8. TokenConsole: https://ropsten.etherscan.io/address/0xcc0427b210564b2b099d2a70c7c6d07b1f03fef3#code
9. CrowdsaleBuyTokens: https://ropsten.etherscan.io/address/0x24901914fac3acf7d3d9ed6ed8687d3ad8527700#code
10. TokenTransfer: https://ropsten.etherscan.io/address/0x81b4bfe7c54bf2504d86563aeb0332a686bb8ee2#code
11. TokenTransferFrom: https://ropsten.etherscan.io/address/0x8800728cc4b7dad58983af0c6fec2aa1441d63e5#code
12. TokenApprove: https://ropsten.etherscan.io/address/0xe0af2a2670da0242c6c7914cc36b8cf4ad75742f#code
13. ScriptExec: https://ropsten.etherscan.io/address/0x7fc8ce5865bf0cac653e315f03beeef77d536075#code

The 'default' variables in ScriptExec.sol can be examined for information on the registry's execution id, as well as the storage address of the registry. 

###### Deployment -> Use of Script Registry and Crowdsale contracts:

A. Initial Deployment (storage contract, registry contracts, application contracts):
  1. We first deploy all contracts, except the Script Exec contract. The Script Exec contract is built in such a way that it depends on already-deployed contracts, as well as the Script Registry contracts being initialized and in use.
  2. First round of deployment - RegistryStorage, InitRegistry, AppConsole, VersionConsole, ImplementationConsole, InitCrowdsale, CrowdsaleConsole, TokenConsole, CrowdsaleBuyTokens, TokenTransfer, TokenTransferFrom, TokenApprove
  
B. Initialization of Script Registry and registration/implementation of crowdsale contracts:
  1. We now need to initialize the script registry contracts, so that the ScriptExec contract is able to read information about the crowdsale we want to deploy. This is called from your personal address, as ScriptExec currently does not support initializing the registry contracts (it tries to look up initialization information on the registry contracts, but the registry contracts are not yet initialized themselves!)
  2. Call: RegistryStorage.initAndFinalize
    - I set myself as the updater, so that I'm able to swap out faulty contracts if need be
    - is_payable should be false for the registry contracts
    - init is the address for InitRegistry, and init_calldata should be the calldata for InitRegistry.init (only 4 bytes - no params)
    - allowed addresses - AppConsole, VersionConsole, ImplementationConsole
  3. RegistryStorage should return an exec id - this will be the 'default_registry_exec_id' used with the ScriptExec contract. It is also the exec id used by you to register application information in the script registry app. Again, you will directly be using ScriptRegistry.exec for this.
  4. Time to register the crowdsale application - get the appropriate calldata for AppConsole.registerApp, and pass that through RegistryStorage.exec (of course, using the AppConsole address as the target). This sets up an unimplemented (but named) application in the script registry app. You can view information on it through these InitRegsitry functions:
    - getProviderInfo, getProviderInfoFromAddress, getAppInfo, getAppVersions (should be 0)
    - In the live contracts, the crowdsale app is called "MintedCappedCrowdsale"
  5. Next, we want to create the first version of our application - get the calldata for VersionConsole.registerVersion, and pass that through RegistryStorage.exec (using VersionConsole as the target). This sets up the first version of our app, which I called 'v1.0'. Information on this version can be viewed through these InitRegistry functions:
    - getVersionInfo, getAppVersions
  6. Now we need to specify where and which logic contracts belong to the app. Get calldata for ImplementationConsole.addFunctions, and pass it through the ScriptExec contract. For each function, provide the address where it can be called. It is also possible to add descriptions for each function, through ImplementationConsole.describeFunction. Use these functions for information:
    - getVersionImplementation, getImplementationInfo
    - The live crowdsale application was implemented in 3 'addFunction' batches - first, the token and purchase contracts, then the TokenConsole functions and address, and finally the CrowdsaleConsole functions and address.
  7. Finally - we want to finalize our version, marking it as the latest, 'stable' version. This finalization allows the ScriptExec contract to view the app we just registered. Call VersionConsole.finalizeVersion through the storage exec function.
    - View init information: getVersionInitInfo, getAppLatestInfo
    
C. Deployment of ScriptExec, and initialization of crowdsale app:
  1. We now have the registry storage address, an exec id we've been using with the registry, and the id of the the provider that registered the apps we want to initialize (the hash of the address that called all the RegistryStorage.exec functions). Put the appropriate informatino in the constructor, and deploy
  2. To initialize our application - get the calldata you want for the crowdsale, from InitCrowdsale.init. Pass that, and the app's name (MintedCappedCrowdsale), as well as 'true' for is_payable, into ScriptExec.initAppInstance. You should get back an exec id - this it the crowdsale's exec id, to be used only through the ScriptExec contract
  
D. Initialization of MintedCappedCrowdsale:
  1. MintedCappedCrowdsale's 'InitCrowdsale.init' function was already called during the previous step. However, we can now do a few things to finish the job and get an up-and-running crowdsale app. First, we need to initialize the crowdsale token. Get the calldata for CrowdsaleConsole.initCrowdsaleToken, and pass that through ScriptExec.exec, with CrowdsaleConsole as the target address.
    - You can view info on the created token in InitCrowdsale: getCrowdsaleInfo, getCrowdsaleStartTime, getCurrentTierInfo, getCrowdsaleTier, getTokenInfo
  2. We can now call CrowdsaleConsole.initializeCrowdsale, or we can do any of the following:
    - Add whitelisted tiers and users (CrowdsaleConsole.createCrowdsaleTiers and CrowdsaleConsole.whitelistMulti)
    - Update tier duration (must be before tier begins) (CrowdsaleConsole.updateTierDuration)
    - Set, update, or delete reserved tokens: (TokenConsole.updateMultipleReservedTokens, removeReservedTokens)
  3. Finally - call CrowdsaleConsole.initializeCrowdsale. This will open the app for purchasing (once the start time is reached)
  
E. Buying tokens:
  1. Buying tokens is done through the CrowdsaleBuyTokens.buy function. It takes simply the context array, which should be the crowdsale app's exec id, the sender's address, and the amount of wei sent. Passing this into ScriptExec.exec and sending the correct amount of wei should net the sender tokens (if there are some to be sold)
  
F. Finalization of crowdsale and ditribution of reserved tokens:
  1. The owner can finalize the crowdsale at any point - by calling CrowdsaleConsole.finalizeCrowdsale (through ScriptExec.exec). Finalization unlocks tokens for transfer, and allows reserved tokens to be distributed.
  2. Reserved tokens are distributed through TokenConsole.distributeReservedTokens. The function takes an 'amount' of destinations you want to cycle through and distribute to - so that batching is possible in the event of several destinations.

That's it! Typically, of course, only C.2. and onwards will need to be done - everything else is already there.
