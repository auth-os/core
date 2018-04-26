let AbstractStorage = artifacts.require('./mock/AbstractStorageMock')
let ApplicationMockInit = artifacts.require('./mock/ApplicationMockInit')

contract('AbstractStorage', function (accounts) {

    let appInit // mock application
    let appInitCalldata // calldata for mock application initializer
    let appUpdater = accounts[Math.ceil(accounts.length / 2)] // grab an account from the middle

    let storage

    beforeEach(async () => {
        storage = await AbstractStorage.new()

        appInit = await ApplicationMockInit.new().should.be.fulfilled
        appInit.should.not.eq(null)
        appInitCalldata = '0xe1c7392a' // bytes4(keccak256("init()"));
    })

    describe('#initAndFinalize', async () => {
        context('when the given calldata is valid for the app init function', async () => {
            let execId
            let appInitializedEvent
            let appFinalizedEvent

            beforeEach(async () => {
                events = await storage.initAndFinalize(appUpdater, false, appInit.address, appInitCalldata, []).should.be.fulfilled.then((tx) => {
                    return tx.logs
                })

                events.should.not.eq(null)
                events.length.should.eq(2)

                appInitializedEvent = events[0]
                appFinalizedEvent = events[1]
            })

            it('should emit an ApplicationInitialized event', async () => {
                appInitializedEvent.should.not.eq(null)
                appInitializedEvent.event.should.be.eq('ApplicationInitialized')
            })

            it('should emit an ApplicationFinalization event', async () => {
                appFinalizedEvent.should.not.eq(null)
                appFinalizedEvent.event.should.be.eq('ApplicationFinalization')
            })

            describe('ApplicationInitialized event', async () => {
                it('should include an indexed exec id for the initialized application', async () => {
                    let execId = appInitializedEvent.args['execution_id']
                    execId.should.not.eq(null)
                })

                it('should include an indexed initializer address for the initialized application', async () => {
                    let initAddr = appInitializedEvent.args['init_address']
                    initAddr.should.not.eq(null)
                    initAddr.should.be.deep.eq(appInit.address)
                })

                it('should include an indexed script exec contract address for the initialized application', async () => {
                    let scriptExec = appInitializedEvent.args['script_exec']
                    scriptExec.should.not.eq(null)
                })

                it('should include an indexed updater address for the initialized application', async () => {
                    let updaterAddr = appInitializedEvent.args['updater']
                    updaterAddr.should.not.eq(null)
                    updaterAddr.should.be.deep.eq(appUpdater)
                })
            })

            describe('ApplicationFinalization event', async () => {
                it('should include an indexed exec id for the finalized application', async () => {
                    let execId = appFinalizedEvent.args['execution_id']
                    execId.should.not.eq(null)
                })

                it('should include an indexed initializer address for the finalized application', async () => {
                    let initAddr = appFinalizedEvent.args['init_address']
                    initAddr.should.not.eq(null)
                    initAddr.should.be.deep.eq(appInit.address)
                })
            })

            it('should return the exec id of the initialized application', async () => {
                let execId = await storage.initAndFinalize(appUpdater, false, appInit.address, appInitCalldata, []).should.be.fulfilled
                execId.should.not.eq(null)
            })
        })

        context('when the given calldata is invalid for the app init function', async () => {
            it('should revert the tx', async () => {
                let invalidCalldata = '' // should be, at a minimum, bytes4(keccak256("init()")) for default application initializer
                await storage.initAndFinalize(appUpdater, false, appInit.address, invalidCalldata, []).should.be.rejectedWith(exports.EVM_ERR_REVERT)
            })
        })
    })

    // The following methods are covered or will be covereed by way of tests which exercise the registry:
    // describe('#changeScriptExec', async () => {})
    // describe('#changeInitAddr', async () => {})

    /// The following methods will soon be covered below :

    describe('#pauseAppInstance', async () => {
        // TODO: add test coverage
    })

    describe('#unpauseAppInstance', async () => {
        // TODO: add test coverage
    })

    describe('#addAllowed', async () => {
        // TODO: add test coverage
    })

    describe('#removeAllowed', async () => {
        // TODO: add test coverage
    })

    describe('#withdraw', async () => {
        // FIXME-- this puts any Ether up for grabs to the first person to call #withdraw
    })
})
