let ApplicationMockInit = artifacts.require('./mock/application/functions/init/ApplicationMockInit')
let ApplicationMockNonDefaultInit = artifacts.require('./mock/ApplicationMockNonDefaultInit')
let ApplicationMockFuncLib = artifacts.require('./mock/application/functions/ApplicationMockFuncLib')
let RegistryStorage = artifacts.require('./mock/RegistryStorageMock')
let InitRegistry = artifacts.require('./InitRegistry')
let AppConsole = artifacts.require('./AppConsole')
let ImplementationConsole = artifacts.require('./ImplementationConsole')
let VersionConsole = artifacts.require('./VersionConsole')
let RegistryExec = artifacts.require('./mock/RegistryExecMock')
let TestUtils = artifacts.require('./util/TestUtils')
let MockAppLibOne = artifacts.require('./mock/MockAppOne')
let MockAppLibTwo = artifacts.require('./mock/MockAppTwo')
let MockAppLibThree = artifacts.require('./mock/MockAppThree')
let utils = require('./support/utils.js')

contract('RegistryExec', function(accounts) {
    let storage
    let appConsole
    let implementationConsole
    let versionConsole

    let initRegistry
    let initRegistryCalldata
    let scriptExec
    let registryExecId

    let execAdmin = accounts[0]
    let provider
    let updater = accounts[Math.ceil(accounts.length / 2)]

    beforeEach(async () => {
        testUtils = await TestUtils.new().should.be.fulfilled
        provider = await testUtils.getAppProviderHash(execAdmin).should.be.fulfilled
        provider.should.not.eq(null)
        web3.toDecimal(provider).should.not.eq(0)

        storage = await RegistryStorage.new().should.be.fulfilled

        appConsole = await AppConsole.new().should.be.fulfilled
        implementationConsole = await ImplementationConsole.new().should.be.fulfilled
        versionConsole = await VersionConsole.new().should.be.fulfilled

        initRegistry = await InitRegistry.new().should.be.fulfilled
        initRegistry.should.not.eq(null)

        scriptExec = await RegistryExec.new(updater, storage.address, provider, { from: execAdmin }).should.be.fulfilled
        scriptExec.should.not.eq(null)

        registryExecId = await scriptExec.initRegistry(initRegistry.address, appConsole.address, versionConsole.address, implementationConsole.address, { from: execAdmin }).should.be.fulfilled.then((tx) => {
            return tx.receipt.logs[0].topics[1]
        })
        registryExecId.should.not.eq(null)
    })

    describe('#initRegistryWithCalldata', async() => {
        context('when the RegistryStorage#initAndFinalize calldata is well-formed', async () => {
            it('should result the deployment of a properly-configured registry-enabled script exec contract', async () => {
                registryExecId.should.not.eq(null)
            })
        })
    })

    describe('initialization', async () => {
        context('when the script exec contract is initialized with non-zero updater, registry storage and provider', async () => {
            it('should have initialized the script exec contract', async() => {
                scriptExec.should.not.eq(null)
            })

            it('should set the admin on the script exec contract to the creator', async() => {
                let execAdmin = await scriptExec.exec_admin()
                execAdmin.should.eq(execAdmin)
            })

            it('should set the given default registry storage contract on the script exec contract', async() => {
                let defaultStorage = await scriptExec.default_storage()
                defaultStorage.should.eq(storage.address)
            })

            it('should set the given default updater on the script exec contract', async() => {
                let defaultUpdater = await scriptExec.default_updater()
                defaultUpdater.should.eq(updater)
            })

            it('should set the given default registry exec id on the script exec contract', async() => {
                let defaultExecId = await scriptExec.default_registry_exec_id()
                defaultExecId.should.eq(registryExecId)
            })

            it('should set the given default provider on the script exec contract', async() => {
                let defaultProvider = await scriptExec.default_provider()
                defaultProvider.should.eq(provider)
            })
        })

        context('when the script exec contract is initialized with "zero-state" params', async () => {
            beforeEach(async () => {
                scriptExec = await RegistryExec.new(utils.ADDRESS_0x, utils.ADDRESS_0x, 0, { from: execAdmin }).should.be.fulfilled
            })

            it('should have initialized the script exec contract', async() => {
                scriptExec.should.not.eq(null)
            })

            it('should set the admin on the script exec contract to the creator', async() => {
                let execAdmin = await scriptExec.exec_admin()
                execAdmin.should.eq(execAdmin)
            })

            it('should not set a default registry storage contract on the script exec contract', async() => {
                let defaultStorage = await scriptExec.default_storage()
                defaultStorage.should.eq(utils.ADDRESS_0x)
            })

            it('should not set a default updater on the script exec contract', async() => {
                let defaultUpdater = await scriptExec.default_updater()
                defaultUpdater.should.eq(utils.ADDRESS_0x)
            })

            it('should not set a default registry exec id on the script exec contract', async() => {
                let defaultExecId = await scriptExec.default_registry_exec_id()
                defaultExecId.should.eq(utils.BYTES32_EMPTY)
            })

            it('should not set a default provider on the script exec contract', async() => {
                let defaultProvider = await scriptExec.default_provider()
                defaultProvider.should.eq(utils.BYTES32_EMPTY)
            })
        })
    })

    describe('script exec contract administration', async () => {
        describe('#changeStorage', async () => {
            let newStorage

            beforeEach(async () => {
                newStorage = await RegistryStorage.new().should.be.fulfilled
            })

            context('when invoked by the script exec admin', async () => {
                beforeEach(async () => {
                    await scriptExec.changeStorage(newStorage.address, { from: execAdmin }).should.be.fulfilled
                })

                it('should change the default registry storage address on the script exec contract', async () => {
                    let defaultStorage = await scriptExec.default_storage()
                    defaultStorage.should.not.deep.eq(utils.ADDRESS_0x)
                    defaultStorage.should.eq(newStorage.address)
                })
            })

            context('when invoked by someone other than the script exec admin', async () => {
                it('should revert the tx', async () => {
                    let unauthorized = accounts[accounts.length - 1]
                    await scriptExec.changeStorage(newStorage.address, { from: unauthorized }).should.be.rejectedWith(exports.EVM_ERR_REVERT)
                })
            })
        })

        describe('#changeUpdater', async () => {
            let newUpdater = accounts[accounts.length - 1]

            context('when invoked by the script exec admin', async () => {
                beforeEach(async () => {
                    await scriptExec.changeUpdater(newUpdater, { from: execAdmin }).should.be.fulfilled
                })

                it('should change the default updater address on the script exec contract', async () => {
                    let defaultUpdater = await scriptExec.default_updater()
                    defaultUpdater.should.not.eq(utils.ADDRESS_0x)
                    defaultUpdater.should.eq(newUpdater)
                })
            })

            context('when invoked by someone other than the script exec admin', async () => {
                it('should revert the tx', async () => {
                    let unauthorized = accounts[accounts.length - 1]
                    await scriptExec.changeUpdater(newUpdater, { from: unauthorized }).should.be.rejectedWith(exports.EVM_ERR_REVERT)
                })
            })
        })

        describe('#changeAdmin', async () => {
            let newExecAdmin = accounts[1]

            context('when invoked by the script exec admin', async () => {
                beforeEach(async () => {
                    initialExecAdmin = await scriptExec.exec_admin()
                    initialExecAdmin.should.eq(execAdmin)
                    await scriptExec.changeAdmin(newExecAdmin, { from: execAdmin }).should.be.fulfilled
                })

                it('should change the exec admin on the script exec contract', async () => {
                    let admin = await scriptExec.exec_admin()
                    admin.should.eq(newExecAdmin)
                })
            })

            context('when invoked by someone other than the script exec admin', async () => {
                it('should revert the tx', async () => {
                    let unauthorized = accounts[accounts.length - 1]
                    await scriptExec.changeAdmin(newExecAdmin, { from: unauthorized }).should.be.rejectedWith(exports.EVM_ERR_REVERT)
                })
            })
        })

        describe('#changeProvider', async () => {
            let newProvider = web3.toHex(utils.randomBytes(32))

            context('when invoked by the script exec admin', async () => {
                beforeEach(async () => {
                    await scriptExec.changeProvider(newProvider, { from: execAdmin }).should.be.fulfilled
                })

                it('should change the default provider on the script exec contract', async () => {
                    let defaultProvider = await scriptExec.default_provider()
                    defaultProvider.should.eq(newProvider)
                })
            })

            context('when invoked by someone other than the script exec admin', async () => {
                it('should revert the tx', async () => {
                    let unauthorized = accounts[accounts.length - 1]
                    await scriptExec.changeProvider(newProvider, { from: unauthorized }).should.be.rejectedWith(exports.EVM_ERR_REVERT)
                })
            })
        })

        describe('#changeRegistryExecId', async () => {
            let newRegistryExecId = web3.toHex(utils.randomBytes(32))

            context('when invoked by the script exec admin', async () => {
                beforeEach(async () => {
                    await scriptExec.changeRegistryExecId(newRegistryExecId, { from: execAdmin }).should.be.fulfilled
                })

                it('should change the default registry exec id on the script exec contract', async () => {
                    let defaultRegistryExecId = await scriptExec.default_registry_exec_id()
                    defaultRegistryExecId.should.eq(newRegistryExecId)
                })
            })

            context('when invoked by someone other than the script exec admin', async () => {
                it('should revert the tx', async () => {
                    let unauthorized = accounts[accounts.length - 1]
                    await scriptExec.changeRegistryExecId(newRegistryExecId, { from: unauthorized }).should.be.rejectedWith(exports.EVM_ERR_REVERT)
                })
            })
        })
    })

    describe('application context', async () => {
        let appName
        let appDescription
        let appInit
        let appFuncLib
        let appExecId
        let _context

        beforeEach(async () => {
            appInit = await ApplicationMockInit.new().should.be.fulfilled
            appInit.should.not.eq(null)

            appFuncLib = await ApplicationMockFuncLib.new().should.be.fulfilled
            appFuncLib.should.not.eq(null)

            appFuncLib2 = await MockAppLibOne.new().should.be.fulfilled
            appFuncLib2.should.not.eq(null)

            _context = await testUtils.getContextFromAddr.call(registryExecId, execAdmin, 0)
            _context.should.not.eq(null)

            appName = 'Mock App Instance @' + new Date().getTime()
            appDescription = 'Mock App Description @' + new Date().getTime()
        })

        describe('#initAppInstance', async () => {
            context ('when no app versions have been finalized', async () => {
                it('should reject the tx', async () => {
                    await scriptExec.initAppInstance(appName, false, '0xe1c7392a', { from: execAdmin }).should.be.rejectedWith(exports.EVM_ERR_REVERT)
                })
            })

            context('when one or more app versions have been finalized', async () => {
                let appEvents
                let appCreator

                let appStorage
                let versionName
                let _appName
                let _appInit

                beforeEach(async () => {
                    await scriptExec.registerApp(appName, appDescription).should.be.fulfilled.should.be.fulfilled.then((tx) => {
                        // registerAppCalldata = appConsole.registerApp.request(appName, storage.address, appDescription, _context).params[0].data
                        // registerAppCalldata = storage.exec.request(appConsole.address, registryExecId, registerAppCalldata).params[0].data
                        // calldata = tx.receipt.logs[tx.receipt.logs.length - 1].data
                        // calldata.should.be.eq(registerAppCalldata)
                    })

                    lengthyAppDesc = utils.randomBytes(512)
                    await scriptExec.registerApp('second registered app name', lengthyAppDesc).should.be.fulfilled.should.be.fulfilled.then((tx) => {
                        // registerAppCalldata = appConsole.registerApp.request('second registered app name', storage.address, lengthyAppDesc, _context).params[0].data
                        // registerAppCalldata = storage.exec.request(appConsole.address, registryExecId, registerAppCalldata).params[0].data
                        // calldata = tx.receipt.logs[tx.receipt.logs.length - 1].data
                        // calldata.should.be.eq(registerAppCalldata)
                    })

                    await scriptExec.registerVersion(appName, '0.0.1', storage.address, 'Alpha release').should.be.fulfilled.then((tx) => {
                        // registerVersionCalldata = versionConsole.registerVersion.request(appName, '0.0.1', storage.address, 'Alpha release', _context).params[0].data
                        // registerVersionCalldata = storage.exec.request(versionConsole.address, registryExecId, registerVersionCalldata).params[0].data
                        // calldata = tx.receipt.logs[tx.receipt.logs.length - 1].data
                        // calldata.should.be.eq(registerVersionCalldata)
                    })

                    await scriptExec.addFunctions(appName, '0.0.1', ['0x0f0558ba'], [appFuncLib.address]).should.be.fulfilled.then((tx) => {
                        // addFunctionsCalldata = implementationConsole.addFunctions.request(appName, '0.0.1', ['0x0f0558ba'], [appFuncLib.address], _context).params[0].data
                        // addFunctionsCalldata = storage.exec.request(implementationConsole.address, registryExecId, addFunctionsCalldata).params[0].data
                        // calldata = tx.receipt.logs[tx.receipt.logs.length - 1].data
                        // calldata.should.be.eq(addFunctionsCalldata)
                    })

                    await scriptExec.finalizeVersion(appName, '0.0.1', appInit.address, '0xe1c7392a', 'Initializer').should.be.fulfilled.then((tx) => {
                        // finalizeVersionCalldata = versionConsole.finalizeVersion.request(appName, '0.0.1', appInit.address, '0xe1c7392a', 'Initializer', _context).params[0].data
                        // finalizeVersionCalldata = storage.exec.request(versionConsole.address, registryExecId, finalizeVersionCalldata).params[0].data
                        // calldata = tx.receipt.logs[tx.receipt.logs.length - 1].data
                        // calldata.should.be.eq(finalizeVersionCalldata)
                    })

                    // setup version with lengthy description
                    lengthyVersionDesc = utils.randomBytes(750)
                    await scriptExec.registerVersion(appName, '0.0.2', storage.address, lengthyVersionDesc).should.be.fulfilled.then((tx) => {
                        // registerVersionCalldata = versionConsole.registerVersion.request(appName, '0.0.2', storage.address, lengthyVersionDesc, _context).params[0].data
                        // registerVersionCalldata = storage.exec.request(versionConsole.address, registryExecId, registerVersionCalldata).params[0].data
                        // calldata = tx.receipt.logs[tx.receipt.logs.length - 1].data
                        // calldata.should.be.eq(registerVersionCalldata)
                    })

                    // add plurality of functions to version
                    await scriptExec.addFunctions(appName, '0.0.2', ['0x0f0558ba', '0xe1c7392a'], [appFuncLib.address, appFuncLib2.address]).should.be.fulfilled.then((tx) => {
                        // addFunctionsCalldata = implementationConsole.addFunctions.request(appName, '0.0.2', ['0x0f0558ba',  '0xe1c7392a'], [appFuncLib.address, appFuncLib2.address], _context).params[0].data
                        // addFunctionsCalldata = storage.exec.request(implementationConsole.address, registryExecId, addFunctionsCalldata).params[0].data
                        // calldata = tx.receipt.logs[tx.receipt.logs.length - 1].data
                        // calldata.should.be.eq(addFunctionsCalldata)
                    })

                    // finalize version with lengthy init calldata and description
                    lengthyInitDesc = utils.randomBytes(32*256)
                    await scriptExec.finalizeVersion(appName, '0.0.2', appInit.address, '0xe1c7392a', lengthyInitDesc).should.be.fulfilled.then((tx) => {
                        // finalizeVersionCalldata = versionConsole.finalizeVersion.request(appName, '0.0.2', appInit.address, '0xe1c7392a', lengthyInitDesc, _context).params[0].data
                        // finalizeVersionCalldata = storage.exec.request(versionConsole.address, registryExecId, finalizeVersionCalldata).params[0].data
                        // calldata = tx.receipt.logs[tx.receipt.logs.length - 1].data
                        // calldata.should.be.eq(finalizeVersionCalldata)
                    })
                })

                describe('#getAppLatestInfo', async () => {
                    it('should return the latest finalized version of the requested application', async () => {
                        providerInfo = await initRegistry.getProviderInfoFromAddress(storage.address, registryExecId, execAdmin).should.be.fulfilled
                        providerInfo.should.not.eq(null)
                        providerInfo[1].length.should.be.eq(2)

                        appInfo = await initRegistry.getAppLatestInfo(storage.address, registryExecId, provider, appName).should.be.fulfilled
                        appInfo.should.not.eq(null)
                        appInfo[appInfo.length - 1].length.should.be.eq(2)
                    })
                })

                context('when the given calldata is valid for the app init function', async () => {
                    context('when the init function is the default, zero-argument initializer', async () => {
                        beforeEach(async () => {
                            appEvents = await scriptExec.initAppInstance(appName, false, '0xe1c7392a', { from: execAdmin }).should.be.fulfilled.then((tx) => {
                                return tx.logs
                            })

                            appCreator = appEvents[0].args.creator
                            appExecId = appEvents[0].args.exec_id
                            appStorage = appEvents[0].args.storage_addr
                            versionName = web3.toUtf8(appEvents[0].args.version_name)
                            _appName = appEvents[0].args.app_name
                        })

                        it('should emit an AppInstanceCreated event', async () => {
                            appEvents[0].event.should.be.eq('AppInstanceCreated')
                        })

                        it('should associate the initialized application instance with its creator', async () => {
                            appCreator.should.not.eq(null)
                            appCreator.should.be.eq(execAdmin)
                        })

                        it('should assign an exec id to the initialized application instance', async () => {
                            appExecId.should.not.eq(null)
                        })

                        it('should associate the initialized application instance with its designated storage contract', async () => {
                            appStorage.should.not.eq(null)
                            appStorage.should.be.eq(storage.address)
                        })

                        it('should associate the initialized application instance with the assigned app name', async () => {
                            _appName.should.not.eq(null)
                            _appName.should.be.eq(web3.toHex(appName))
                        })

                        it('should associate the initialized application instance with the latest finalized app version', async () => {
                            versionName.should.not.eq(null)
                            versionName.should.be.eq('0.0.2')
                        })
                    })

                    context('when the init function accepts parameters', async () => {
                        beforeEach(async () => {
                            let _appInit = await ApplicationMockNonDefaultInit.new().should.be.fulfilled;
                            let _init_sel = await _appInit.initSel.call().should.be.fulfilled
                            await scriptExec.registerVersion(appName, '0.0.3', storage.address, 'non-default initializer').should.be.fulfilled
                            await scriptExec.finalizeVersion(appName, '0.0.3', _appInit.address, _init_sel, 'non-default initializer').should.be.fulfilled

                            _init_calldata = _appInit.init.request('my init arg').params[0].data
                            appEvents = await scriptExec.initAppInstance(appName, false, _init_calldata, { from: execAdmin }).should.be.fulfilled.then((tx) => {
                                return tx.logs
                            })

                            appCreator = appEvents[0].args.creator
                            appExecId = appEvents[0].args.exec_id
                            appStorage = appEvents[0].args.storage_addr
                            versionName = web3.toUtf8(appEvents[0].args.version_name)
                            _appName = appEvents[0].args.app_name
                        })

                        it('should emit an AppInstanceCreated event', async () => {
                            appEvents[0].event.should.be.eq('AppInstanceCreated')
                        })

                        it('should associate the initialized application instance with its creator', async () => {
                            appCreator.should.not.eq(null)
                            appCreator.should.be.eq(execAdmin)
                        })

                        it('should assign an exec id to the initialized application instance', async () => {
                            appExecId.should.not.eq(null)
                        })

                        it('should associate the initialized application instance with its designated storage contract', async () => {
                            appStorage.should.not.eq(null)
                            appStorage.should.be.eq(storage.address)
                        })

                        it('should associate the initialized application instance with the assigned app name', async () => {
                            _appName.should.not.eq(null)
                            _appName.should.be.eq(web3.toHex(appName))
                        })

                        it('should associate the initialized application instance with the latest finalized app version', async () => {
                            versionName.should.not.eq(null)
                            versionName.should.be.eq('0.0.3')
                        })
                    })
                })

                context('when the given calldata is invalid for the app init function', async () => {
                    it('should revert the tx', async () => {
                        let invalidCalldata = '' // should be, at a minimum, bytes4(keccak256("init()")) for default application initializer
                        await scriptExec.initAppInstance(appName, false, invalidCalldata, { from: execAdmin }).should.be.rejectedWith(exports.EVM_ERR_REVERT)
                    })
                })
            })
        })

        describe('app-permissioned storage', async () => {
            // FIXME: this is still a stub, these tests are not yet fully setup and therefore do not yet provide any value

            describe('#getAppAllowed', async () => {
                let allowed

                context('when the given registry exec id is valid', async () => {
                    beforeEach(async () => {
                        allowed = await scriptExec.getAppAllowed(registryExecId)
                        allowed.should.not.eq(null)
                    })
                })

                context('when the given given registry exec id does not exist', async () => {
                    it('should return an empty array', async () => {
                        allowed = await scriptExec.getAppAllowed(utils.randomBytes(32))
                        allowed.should.be.deep.eq([])
                    })
                })
            })
        })
    })
})
