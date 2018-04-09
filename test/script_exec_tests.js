let ApplicationMockInit = artifacts.require('./mock/application/functions/init/ApplicationMockInit')
let RegistryStorage = artifacts.require('./mock/RegistryStorageMock')
let ScriptExec = artifacts.require('./mock/ScriptExecMock')
let utils = require('./support/utils.js')

contract('ScriptExec', function(accounts) {
    let storage
    let scriptExec

    let execAdmin = accounts[0]
    let provider = utils.randomBytes(32)
    let registryExecId = utils.randomBytes(32)
    let updater = accounts[Math.ceil(accounts.length / 2)]

    beforeEach(async () => {
        storage = await RegistryStorage.new({ gas: 3050000 }).should.be.fulfilled
        scriptExec = await ScriptExec.new(updater, storage.address, registryExecId, provider, { gas: 4700000, from: execAdmin }).should.be.fulfilled
    })

    describe('initialization', async () => {
        context('when the script exec contract is initialized with non-zero updater, storage, provider and registry exec ids', async () => {
            it('should have initialized the script exec contract', async() => {
                scriptExec.should.not.eq(null)
            })
    
            it('should set the admin on the script exec contract to the creator', async() => {
                let execAdmin = await scriptExec.exec_admin()
                execAdmin.should.eq(execAdmin)
            })
    
            it('should set the given default storage contract on the script exec contract', async() => {
                let defaultStorage = await scriptExec.default_storage()
                defaultStorage.should.eq(storage.address)
            })
    
            it('should set the given default updater on the script exec contract', async() => {
                let defaultUpdater = await scriptExec.default_updater()
                defaultUpdater.should.eq(updater)
            })
    
            it('should set the given default registry exec id on the script exec contract', async() => {
                let defaultExecId = await scriptExec.default_registry_exec_id()
                defaultExecId.should.eq(web3.toHex(registryExecId))
            })
        })

        context('when the script exec contract is initialized with "zero-state" params', async () => {
            beforeEach(async () => {
                scriptExec = await ScriptExec.new(utils.ADDRESS_0x, utils.ADDRESS_0x, 0, 0, { gas: 4700000, from: execAdmin }).should.be.fulfilled
            })

            it('should have initialized the script exec contract', async() => {
                scriptExec.should.not.eq(null)
            })
    
            it('should set the admin on the script exec contract to the creator', async() => {
                let execAdmin = await scriptExec.exec_admin()
                execAdmin.should.eq(execAdmin)
            })
    
            it('should not set a default storage contract on the script exec contract', async() => {
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
        })
    })

    describe('script exec contract administration', async () => {
        describe('#changeSource', async () => {
            let newStorage
    
            beforeEach(async () => {
                newStorage = await RegistryStorage.new({ gas: 3050000 }).should.be.fulfilled
            })
    
            context('when invoked by the script exec admin', async () => {
                beforeEach(async () => {
                    await scriptExec.changeSource(newStorage.address, { from: execAdmin }).should.be.fulfilled
                })
    
                it('should change the default storage address on the script exec contract', async () => {
                    let defaultStorage = await scriptExec.default_storage()
                    defaultStorage.should.not.deep.eq(utils.ADDRESS_0x)
                    defaultStorage.should.eq(newStorage.address)
                })
            })
    
            context('when invoked by someone other than the script exec admin', async () => {
                it('should revert the tx', async () => {
                    let unauthorized = accounts[accounts.length - 1]
                    await scriptExec.changeSource(newStorage.address, { from: unauthorized }).should.be.rejectedWith(exports.EVM_ERR_REVERT)
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
            let newProvider = utils.randomBytes(32)
            let newProviderHex = web3.toHex(newProvider)

            context('when invoked by the script exec admin', async () => {
                beforeEach(async () => {
                    await scriptExec.changeProvider(newProvider, { from: execAdmin }).should.be.fulfilled
                })
    
                it('should change the default provider on the script exec contract', async () => {
                    let defaultProvider = await scriptExec.default_provider()
                    defaultProvider.should.eq(newProviderHex)
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
        // FIXME-- cleanup context
        let app
        let appExecId
        let appName = 'Mock App Instance @' + new Date().getTime()
        let appInit
        let appInitCalldata
        let appInitInfo
        let appAllowed = []
        let appPayable = false
        let appStorage
        let appVersion

        beforeEach(async () => {
            appInit = await ApplicationMockInit.new().should.be.fulfilled
            appInit.should.not.eq(null)
            appInitCalldata = '0xe1c7392a' // bytes4(keccak256("init()"));

            appExecId = await storage.initAndFinalize(updater, appPayable, appInit.address, appInitCalldata, appAllowed).should.be.fulfilled // proper initialization via RegistryStorage
            appExecId.should.not.eq(null)

            appInitInfo = await storage.getAppInitInfo(registryExecId, provider, appName)
            appInitInfo.should.not.eq(null)
        })

        describe('#initAppInstance', async () => {
            context('when the app has been initialized properly via registry storage', async () => {
                context('when the given calldata is valid for the app init function', async () => {
                    beforeEach(async () => {
                        let { retvals } = await scriptExec.initAppInstance(appName, appPayable, appInitCalldata).should.be.fulfilled
                        console.log(retvals)
                        retvals.should.not.eq(null)
                        retvals.length.should.be.eq(3)

                        appStorage = retvals[0]
                        appVersion = retvals[1]
                        appExecId = retvals[2]
                    })

                    it('should return the storage address of the initialized application', async () => {
                        appStorage.should.not.eq(null)
                    })

                    it('should return the version of the initialized application', async () => {
                        appVersion.should.not.eq(null)
                    })

                    it('should return the exec id of the initialized application', async () => {
                        appExecId.should.not.eq(null)
                    })
                })

                context('when the given calldata is invalid for the app init function', async () => {
                    it('should revert the tx', async () => {
                        let invalidCalldata = '' // should be, at a minimum, bytes4(keccak256("init()")) for default application initializer
                        await scriptExec.initAppInstance(appName, appPayable, invalidCalldata).should.be.rejectedWith(exports.EVM_ERR_REVERT)
                    })
                })
            })
        
            context('when the app has not been initialized properly via registry storage', async () => {
                
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
