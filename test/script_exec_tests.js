let ApplicationMockInit = artifacts.require('./mock/application/functions/init/ApplicationMockInit')
let ApplicationMockFuncLib = artifacts.require('./mock/application/functions/ApplicationMockFuncLib')
let RegistryStorage = artifacts.require('./mock/RegistryStorageMock')
let InitRegistry = artifacts.require('./InitRegistry')
let AppConsole = artifacts.require('./AppConsole')
let ImplementationConsole = artifacts.require('./ImplementationConsole')
let VersionConsole = artifacts.require('./VersionConsole')
let ScriptExec = artifacts.require('./mock/ScriptExecMock')
let utils = require('./support/utils.js')

contract('ScriptExec', function(accounts) {
    let storage
    let appConsole
    let implementationConsole
    let versionConsole

    let initRegistry
    let initRegistryCalldata
    let scriptExec
    let registryExecId

    let execAdmin = accounts[0]
    let provider = '0x000000000000000000000000' + execAdmin.substring(2)
    let updater = accounts[Math.ceil(accounts.length / 2)]

    beforeEach(async () => {
        storage = await RegistryStorage.new().should.be.fulfilled

        appConsole = await AppConsole.new().should.be.fulfilled
        implementationConsole = await ImplementationConsole.new().should.be.fulfilled
        versionConsole = await VersionConsole.new().should.be.fulfilled

        initRegistry = await InitRegistry.new().should.be.fulfilled
        initRegistry.should.not.eq(null)

        scriptExec = await ScriptExec.new(updater, storage.address, provider, { from: execAdmin }).should.be.fulfilled
        scriptExec.should.not.eq(null)

        registryInitAndFinalizeCalldata = await storage.initAndFinalize.request(updater, false, initRegistry.address, '0xe1c7392a', // bytes4(keccak256("init()"));
            [appConsole.address, implementationConsole.address, versionConsole.address]).params[0].data

        registryExecId = await scriptExec.initRegistryWithCalldata(registryInitAndFinalizeCalldata).should.be.fulfilled.then((tx) => {
            return tx.receipt.logs[0].topics[1]
        })
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
                scriptExec = await ScriptExec.new(utils.ADDRESS_0x, utils.ADDRESS_0x, 0, { from: execAdmin }).should.be.fulfilled
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
            let newRegistryExecId = utils.randomBytes(32)
            let newRegistryExecIdHex = web3.toHex(newRegistryExecId)
    
            context('when invoked by the script exec admin', async () => {
                beforeEach(async () => {
                    await scriptExec.changeRegistryExecId(newRegistryExecId, { from: execAdmin }).should.be.fulfilled
                })
    
                it('should change the default registry exec id on the script exec contract', async () => {
                    let defaultRegistryExecId = await scriptExec.default_registry_exec_id()
                    defaultRegistryExecId.should.eq(newRegistryExecIdHex)
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
        let appName = 'Mock App Instance @' + new Date().getTime()
        let appDescription = 'Mock App Description @' + new Date().getTime()
        let appInit
        let appFuncLib
        let _context

        beforeEach(async () => {
            appInit = await ApplicationMockInit.new().should.be.fulfilled
            appInit.should.not.eq(null)

            appFuncLib = await ApplicationMockFuncLib.new().should.be.fulfilled
            appFuncLib.should.not.eq(null)

            _context = await scriptExec.mockContext.call(registryExecId, provider, 0)

            registerAppCalldata = await appConsole.registerApp.request(appName, storage.address, appDescription, _context).params[0].data
            await scriptExec.exec(appConsole.address, registerAppCalldata).should.be.fulfilled.then((tx) => {

            })
        })

        // TODO: cover proper event emission for the following events:
        // ApplicationInitialized(execution_id: <indexed>, init_address: <indexed>, script_exec: 0x, updater: 0x)
        // ApplicationFinalization(execution_id: <indexed>, init_address: <indexed>)
        // ApplicationExecution(execution_id: <indexed>, script_target: <indexed>)

        describe('#initAppInstance', async () => {
            context('when the app has been initialized properly via registry contract', async () => {
                context ('when no app versions have been finalized', async () => {
                    it('should revert the tx', async () => {
                        await scriptExec.initAppInstance(appName, false, '0xe1c7392a', { from: execAdmin }).should.be.rejectedWith(exports.EVM_ERR_REVERT)
                    })
                })

                context('when one or more app versions have been finalized', async () => {
                    let appEvents
                    let appCreator
                    let appExecId
                    let appStorage
                    let versionName
                    let _appName

                    beforeEach(async () => {
                        addVersionCalldata = await versionConsole.registerVersion.request(appName, '0.0.1', storage.address, 'Alpha release', _context).params[0].data
                        await scriptExec.exec(versionConsole.address, addVersionCalldata).should.be.fulfilled.then((tx) => {

                        })

                        addFunctionsCalldata = await implementationConsole.addFunctions.request(appName, '0.0.1', ['0x0f0558ba'], [appFuncLib.address], _context).params[0].data
                        await scriptExec.exec(implementationConsole.address, addFunctionsCalldata).should.be.fulfilled.then((tx) => {

                        })

                        finalizeVersionCalldata = await versionConsole.finalizeVersion.request(appName, '0.0.1', appInit.address, '0xe1c7392a', 'Initializer', _context).params[0].data
                        await scriptExec.exec(versionConsole.address, finalizeVersionCalldata).should.be.fulfilled.then((tx) => {
                            
                        })
                    })

                    context('when the given calldata is valid for the app init function', async () => {
                        beforeEach(async () => {
                            appEvents = await scriptExec.initAppInstance(appName, false, '0xe1c7392a', { from: accounts[accounts.length - 1] }).should.be.fulfilled.then((tx) => {
                                return tx.logs
                            })
                            appCreator = appEvents[0].args.creator
                            appExecId = appEvents[0].args.exec_id
                            appStorage = appEvents[0].args.storage_addr
                            versionName = appEvents[0].args.version_name
                            _appName = appEvents[0].args.app_name
                        })

                        it('should emit an AppInstanceCreated event', async () => {
                            appEvents[0].event.should.be.eq('AppInstanceCreated')
                        })

                        it('should associate the initialized application instance with its creator', async () => {
                            appCreator.should.not.eq(null)
                            appCreator.should.be.eq(accounts[accounts.length - 1])
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
                            versionName.should.be.eq(web3.toHex('1.0.0'))
                        })
                    })

                    context('when the given calldata is invalid for the app init function', async () => {
                        it('should revert the tx', async () => {
                            let invalidCalldata = '' // should be, at a minimum, bytes4(keccak256("init()")) for default application initializer
                            await scriptExec.initAppInstance(appName, false, invalidCalldata).should.be.rejectedWith(exports.EVM_ERR_REVERT)
                        })
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
