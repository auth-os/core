let AppConsole = artifacts.require('./AppConsole')
let ApplicationMockInit = artifacts.require('./mock/application/functions/init/ApplicationMockInit')
let ApplicationMockFuncLib = artifacts.require('./mock/application/functions/ApplicationMockFuncLib')
let ImplementationConsole = artifacts.require('./ImplementationConsole')
let InitRegistry = artifacts.require('./InitRegistry')
let RegistryStorage = artifacts.require('./mock/RegistryStorageMock')
let VersionConsole = artifacts.require('./VersionConsole')
let utils = require('./support/utils.js')


contract('RegistryStorage', function(accounts) {
    let storage

    let initRegistry
    let initRegistryCalldata
    let appConsole
    let implementationConsole
    let versionConsole

    let execAdmin = accounts[0]
    let updater = accounts[accounts.length - 1]

    beforeEach(async () => {
        storage = await RegistryStorage.new().should.be.fulfilled

        initRegistry = await InitRegistry.new().should.be.fulfilled
        initRegistry.should.not.eq(null)

        appConsole = await AppConsole.new().should.be.fulfilled
        implementationConsole = await ImplementationConsole.new().should.be.fulfilled
        versionConsole = await VersionConsole.new().should.be.fulfilled
    })

    describe('registry initialization', async () => {
        let events

        context('when #initAndFinalize is called with a valid registry initializer and valid app, implementation and version console addresses', async () => {
            let execId
            let initAddress

            beforeEach(async () => {
                events = await storage.initAndFinalize(updater, false, initRegistry.address, '0xe1c7392a',
                        [appConsole.address, implementationConsole.address, versionConsole.address]).should.be.fulfilled.then((tx) => {
                    return tx.logs
                })
            })

            describe('ApplicationInitialized event', async () => {
                let scriptExec
                let updaterAddr

                beforeEach(async () => {
                    event = events[0]
                    event.should.not.eq(null)

                    execId = event.args.execution_id
                    initAddr = event.args.init_address
                    scriptExec = event.args.script_exec
                    updaterAddr = event.args.updater
                })

                it('should emit an ApplicationInitialized event', async () => {
                    event.event.should.be.eq('ApplicationInitialized')
                })

                it('should generate a unique execution id for the registered app', async () => {
                    execId.should.not.eq(null)
                    execId.should.not.eq(utils.ADDRESS_0x)
                })

                it('should authorize an initializer at the given init address for the registered app', async () => {
                    initAddr.should.not.eq(null)
                    initAddr.should.not.eq(utils.ADDRESS_0x)
                    initAddr.should.be.eq(initRegistry.address)
                })

                it('should authorize the sender as the initial script executor on the registered app', async () => {
                    scriptExec.should.not.eq(null)
                    scriptExec.should.not.eq(utils.ADDRESS_0x)
                    scriptExec.should.be.eq(execAdmin)
                })

                it('should authorize the given app updater to make changes to the registered app', async () => {
                    updaterAddr.should.not.eq(null)
                    updaterAddr.should.not.eq(utils.ADDRESS_0x)
                    updaterAddr.should.be.eq(updater)
                })
            })

            describe('ApplicationFinalization event', async () => {
                beforeEach(async () => {
                    event = events[1]
                    event.should.not.eq(null)

                    execId = event.args.execution_id
                    initAddr = event.args.init_address
                })

                it('should emit an ApplicationFinalization event', async () => {
                    event.event.should.be.eq('ApplicationFinalization')
                })

                it('should index unique execution id for the registered app', async () => {
                    execId.should.not.eq(null)
                    execId.should.not.eq(utils.ADDRESS_0x)
                })

                it('should index the authorized initializer address for the registered app', async () => {
                    initAddr.should.not.eq(null)
                    initAddr.should.not.eq(utils.ADDRESS_0x)
                    initAddr.should.be.eq(initRegistry.address)
                })
            })
        })
    })

    describe('non-payable application initialization', async() => {
        let appInit
        let appFuncLib
        let events

        beforeEach(async () => {
            appInit = await ApplicationMockInit.new().should.be.fulfilled
            appInit.should.not.eq(null)

            appFuncLib = await ApplicationMockFuncLib.new().should.be.fulfilled
            appFuncLib.should.not.eq(null)
        })

        context('when #initAndFinalize is called with a valid application initializer and array of function implementation addresses', async () => {
            let execId
            let initAddress

            beforeEach(async () => {
                events = await storage.initAndFinalize(updater, false, appInit.address, '0xe1c7392a', [appFuncLib.address]).should.be.fulfilled.then((tx) => {
                    return tx.logs
                })
            })

            describe('ApplicationInitialized event', async () => {
                let scriptExec
                let updaterAddr

                beforeEach(async () => {
                    event = events[0]
                    event.should.not.eq(null)

                    execId = event.args.execution_id
                    initAddr = event.args.init_address
                    scriptExec = event.args.script_exec
                    updaterAddr = event.args.updater
                })

                it('should emit an ApplicationInitialized event', async () => {
                    event.event.should.be.eq('ApplicationInitialized')
                })

                it('should generate a unique execution id for the registered app', async () => {
                    execId.should.not.eq(null)
                    execId.should.not.eq(utils.ADDRESS_0x)
                })

                it('should authorize an initializer at the given init address for the registered app', async () => {
                    initAddr.should.not.eq(null)
                    initAddr.should.not.eq(utils.ADDRESS_0x)
                    initAddr.should.be.eq(appInit.address)
                })

                it('should authorize the sender as the initial script executor on the registered app', async () => {
                    scriptExec.should.not.eq(null)
                    scriptExec.should.not.eq(utils.ADDRESS_0x)
                    scriptExec.should.be.eq(execAdmin)
                })

                it('should authorize the given app updater to make changes to the registered app', async () => {
                    updaterAddr.should.not.eq(null)
                    updaterAddr.should.not.eq(utils.ADDRESS_0x)
                    updaterAddr.should.be.eq(updater)
                })
            })

            describe('ApplicationFinalization event', async () => {
                beforeEach(async () => {
                    event = events[1]
                    event.should.not.eq(null)

                    execId = event.args.execution_id
                    initAddr = event.args.init_address
                })

                it('should emit an ApplicationFinalization event', async () => {
                    event.event.should.be.eq('ApplicationFinalization')
                })

                it('should index unique execution id for the registered app', async () => {
                    execId.should.not.eq(null)
                    execId.should.not.eq(utils.ADDRESS_0x)
                })

                it('should index the authorized initializer address for the registered app', async () => {
                    initAddr.should.not.eq(null)
                    initAddr.should.not.eq(utils.ADDRESS_0x)
                    initAddr.should.be.eq(appInit.address)
                })
            })
        })
    })
})
