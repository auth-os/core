let AbstractStorage = artifacts.require('./mock/AbstractStorageMock')
let ApplicationMockInit = artifacts.require('./mock/ApplicationMockInit')
let ApplicationFuncLib = artifacts.require('./mock/ApplicationMockFuncLib')
let ApplicationPayableLib = artifacts.require('./mock/ApplicationMockPayableLib')
let ApplicationMockErrorLib = artifacts.require('./mock/ApplicationMockErrorLib')
let ApplicationMockStorageLib = artifacts.require('./mock/ApplicationMockStoreData')
let ForceSendEther = artifacts.require('./mock/ForceSendEther')


contract('AbstractStorage', function (accounts) {
    let scriptExecAddr = accounts[0]
    let nonScriptExec = accounts[1]
    let appUpdaterAddr = accounts[accounts.length - 1]
    let nonUpdaterAddr = accounts[accounts.length - 2]
    let appFuncLib
    let appFuncCalldata = '0x0f0558ba'
    let appInit // mock application
    let appInitCalldata // calldata for mock application initializer

    let storage

    beforeEach(async () => {
        storage = await AbstractStorage.new()

        appInit = await ApplicationMockInit.new().should.be.fulfilled
        appInit.should.not.eq(null)
        appInitCalldata = '0xe1c7392a' // bytes4(keccak256("init()"));
        appFuncLib = await ApplicationFuncLib.new().should.be.fulfilled
    })

    describe('#initAndFinalize', async () => {
        context('when the given calldata is valid for the app init function', async () => {
            let execId
            let appInitializedEvent
            let appFinalizedEvent

            beforeEach(async () => {
                events = await storage.initAndFinalize(
                  appUpdaterAddr, false, appInit.address, appInitCalldata, [appFuncLib.address], { from: scriptExecAddr }
                ).should.be.fulfilled.then((tx) => {
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
                    updaterAddr.should.be.deep.eq(appUpdaterAddr)
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
                let execId = await storage.initAndFinalize.call(appUpdaterAddr, false, appInit.address, appInitCalldata, [])
                execId.should.not.eq(null)
            })

            it('should correctly set the appInfo struct for the new application', async() => {
                let execId = appFinalizedEvent.args['execution_id']
                let appStruct = await storage.app_info(execId)
                appStruct.should.not.eq(null)
                appStruct[0].should.be.eq(false)
                appStruct[1].should.be.eq(true)
                appStruct[2].should.be.eq(false)
                appStruct[3].should.be.eq(appUpdaterAddr)
                appStruct[4].should.be.eq(scriptExecAddr)
                appStruct[5].should.be.eq(appInit.address)
            })
        })

        context('when the given calldata is invalid for the app init function', async () => {
            it('should revert the tx', async () => {
                let invalidCalldata = '' // should be, at a minimum, bytes4(keccak256("init()")) for default application initializer
                await storage.initAndFinalize(appUpdaterAddr, false, appInit.address, invalidCalldata, []).should.be.rejectedWith(exports.EVM_ERR_REVERT)
            })
        })
    })

    describe('#exec: non-payable', async () => {
        let instanceExecId

        beforeEach(async () => {
            instanceExecId = await storage.initAndFinalize.call(
                appUpdaterAddr, false, appInit.address, appInitCalldata, [appFuncLib.address], { from: scriptExecAddr }
            ).should.be.fulfilled
            await storage.initAndFinalize(
                appUpdaterAddr, false, appInit.address, appInitCalldata, [appFuncLib.address], { from: scriptExecAddr }
            ).should.be.fulfilled
        })

        context('when the sender is the script exec contract', async () => {
            let appExecutionEvent

            beforeEach(async () => {
                let execEvents = await storage.exec(
                    appFuncLib.address, instanceExecId, appFuncCalldata, { from: scriptExecAddr }
                ).should.be.fulfilled.then((tx) => {
                    return tx.logs;
                })

                execEvents.should.not.eq(null)
                execEvents.length.should.eq(1)

                appExecutionEvent = execEvents[0]
            })

            it('should emit an ApplicationExecution event', async () => {
                appExecutionEvent.should.not.eq(null)
                appExecutionEvent.event.should.be.eq('ApplicationExecution')
            })

            describe('ApplicationExecution event', async() => {
                it('should contain an indexed execution id', async () => {
                    let eventExecId = appExecutionEvent.args['execution_id']
                    eventExecId.should.not.eq(null)
                    eventExecId.should.be.deep.eq(instanceExecId)
                })

                it('should contain an indexed target address', async () => {
                    let eventTargetAddr = appExecutionEvent.args['script_target']
                    eventTargetAddr.should.not.eq(null)
                    eventTargetAddr.should.be.deep.eq(appFuncLib.address)
                })
            })

            it('should allow execution of the application', async () => {
                let returned = await storage.exec.call(
                    appFuncLib.address, instanceExecId, appFuncCalldata, { from: scriptExecAddr }
                )
                returned.should.not.eq(null)
                returned[0].should.be.eq(true)
                returned[1].s.should.be.eq(1)
                returned[2].should.be.eq('0x')
            })

            context('when the app is paused', async () => {

                it('should not allowed execution', async () => {
                    await storage.pauseAppInstance(instanceExecId, { from: appUpdaterAddr }).should.be.fulfilled
                    await storage.exec(
                      appFuncLib.address, instanceExecId, appFuncCalldata, { from: scriptExecAddr }
                    ).should.not.be.fulfilled
                })
            })

            context('when ether is sent', async () => {

                it('should not allow execution', async () => {
                  await storage.exec(
                    appFuncLib.address, instanceExecId, appFuncCalldata, { from: scriptExecAddr, value: 1 }
                  ).should.not.be.fulfilled
                })
            })
        })


        context('when the sender is not the script exec contract', async () => {
            let appExecutionEvent

            it('should not allow execution from addresses not registered as the script exec', async () => {
                await storage.exec(
                  appFuncLib.address, instanceExecId, appFuncCalldata, { from: nonScriptExec }
                ).should.not.be.fulfilled
            })

            context('when the app is paused', async () => {

                it('should not allowed execution', async () => {
                    await storage.pauseAppInstance(instanceExecId, { from: appUpdaterAddr }).should.be.fulfilled
                    await storage.exec(
                      appFuncLib.address, instanceExecId, appFuncCalldata, { from: nonScriptExec }
                    ).should.not.be.fulfilled
                })
            })

            context('when ether is sent', async () => {

                it('should not allow execution', async () => {
                  await storage.exec(
                    appFuncLib.address, instanceExecId, appFuncCalldata, { from: nonScriptExec, value: 1 }
                  ).should.not.be.fulfilled
                })
            })
        })
    })

    describe('#exec: payable', async () => {

        let payoutTo = accounts[3]

        let payoutCalldata
        let payoutAndStoreCalldata


        let payableAppLib

        let instanceExecId

        beforeEach(async () => {
            payoutCalldata = await storage.mockPayoutCalldata.call(payoutTo, 5)
            payoutAndStoreCalldata = await storage.mockPayoutAndStoreCalldata.call(payoutTo, 6)
            payoutCalldata.should.not.eq(null)
            payoutAndStoreCalldata.should.not.eq(null)

            payableAppLib = await ApplicationPayableLib.new().should.be.fulfilled

            instanceExecId = await storage.initAndFinalize.call(
                appUpdaterAddr, true, appInit.address, appInitCalldata, [payableAppLib.address], { from: scriptExecAddr }
            ).should.be.fulfilled
            await storage.initAndFinalize(
                appUpdaterAddr, true, appInit.address, appInitCalldata, [payableAppLib.address], { from: scriptExecAddr }
            ).should.be.fulfilled
        })

        context('#payout - when the sender is the script exec contract', async () => {
            let appExecEvent
            let payoutEvent

            let payoutAddrPrevBal

            let execReturn

            beforeEach(async () => {
                payoutAddrPrevBal = await web3.eth.getBalance(payoutTo).toNumber()

                execReturn = await storage.exec.call(
                    payableAppLib.address, instanceExecId, payoutCalldata, { from: scriptExecAddr, value: web3.fromWei('5', 'wei') }
                )

                let execEvents = await storage.exec(
                    payableAppLib.address, instanceExecId, payoutCalldata, { from: scriptExecAddr, value: web3.fromWei('5', 'wei') }
                ).should.be.fulfilled.then((tx) => {
                    return tx.logs;
                })

                execEvents.should.not.eq(null)
                execEvents.length.should.be.eq(2)

                payoutEvent = execEvents[0]
                appExecEvent = execEvents[1]
            })

            it('should have valid return data', async () => {
                execReturn.length.should.be.eq(3)
                execReturn[0].should.be.eq(true)
                execReturn[1].toNumber().should.be.eq(0)
                execReturn[2].length.should.be.eq(130)
                let amtAndDest = await storage.mockGetPaymentInfo(execReturn[2]).should.be.fulfilled
                amtAndDest[0].toNumber().should.be.eq(5)
                amtAndDest[1].should.be.eq(payoutTo)
            })

            it('should emit a DeliveredPayment event', async () => {
                payoutEvent.should.not.eq(null)
                payoutEvent.event.should.be.eq('DeliveredPayment')
            })

            it('should emit an ApplicationExecution event', async () => {
                appExecEvent.should.not.eq(null)
                appExecEvent.event.should.be.eq('ApplicationExecution')
            })

            it('should send ether to the destination', async () => {
                let payoutAddrNewBal = await web3.eth.getBalance(payoutTo).toNumber()
                payoutAddrNewBal.should.not.eq(0)
                payoutAddrNewBal.should.be.eq(payoutAddrPrevBal + 5)
            })

            it('should leave no ether in the storage contract', async () => {
                let storageBal = await web3.eth.getBalance(storage.address).toNumber()
                storageBal.should.be.eq(0)
            })

            describe('DeliveredPayment event', async () => {
                it('should contain an indexed execution id', async () => {
                    let eventExecId = payoutEvent.args['execution_id']
                    eventExecId.should.not.eq(null)
                    eventExecId.should.be.deep.eq(instanceExecId)
                })

                it('should contain an indexed destination address', async () => {
                    let eventDestinationAddr = payoutEvent.args['destination']
                    eventDestinationAddr.should.not.eq(null)
                    eventDestinationAddr.should.be.deep.eq(payoutTo)
                })
            })


            describe('ApplicationExecution event', async () => {
                it('should contain an indexed execution id', async () => {
                    let eventExecId = appExecEvent.args['execution_id']
                    eventExecId.should.not.eq(null)
                    eventExecId.should.be.deep.eq(instanceExecId)
                })

                it('should contain an indexed target address', async () => {
                    let eventTargetAddr = appExecEvent.args['script_target']
                    eventTargetAddr.should.not.eq(null)
                    eventTargetAddr.should.be.deep.eq(payableAppLib.address)
                })
            })

            context('when the app is paused', async () => {

                it('should not allowed execution', async () => {
                    await storage.pauseAppInstance(instanceExecId, { from: appUpdaterAddr }).should.be.fulfilled
                    await storage.exec(
                      payableAppLib.address, instanceExecId, payoutCalldata, { from: scriptExecAddr, value: web3.fromWei('5', 'wei') }
                    ).should.not.be.fulfilled
                })
            })
        })

        context('#payout - when the sender is not the script exec contract', async () => {

            it('should not allow execution', async () => {
                await storage.exec(
                    payableAppLib.address, instanceExecId, payoutCalldata, { from: nonScriptExec, value: web3.fromWei('5', 'wei') }
                ).should.not.be.fulfilled
            })
        })

        context('#payoutAndStore - when the sender is the script exec contract', async () => {
          let appExecEvent
          let payoutAndStoreEvent

          let payoutAddrPrevBal

          let execReturn

          beforeEach(async () => {
              payoutAddrPrevBal = await web3.eth.getBalance(payoutTo).toNumber()

              execReturn = await storage.exec.call(
                  payableAppLib.address, instanceExecId, payoutAndStoreCalldata, { from: scriptExecAddr, value: web3.fromWei('6', 'wei') }
              )

              let execEvents = await storage.exec(
                  payableAppLib.address, instanceExecId, payoutAndStoreCalldata, { from: scriptExecAddr, value: web3.fromWei('6', 'wei') }
              ).should.be.fulfilled.then((tx) => {
                  return tx.logs;
              })

              execEvents.should.not.eq(null)
              execEvents.length.should.be.eq(2)

              payoutAndStoreEvent = execEvents[0]
              appExecEvent = execEvents[1]
          })

          it('should have valid return data', async () => {
              execReturn.length.should.be.eq(3)
              execReturn[0].should.be.eq(true)
              execReturn[1].toNumber().should.be.eq(1)
              execReturn[2].length.should.be.eq(130)
              let amtAndDest = await storage.mockGetPaymentInfo(execReturn[2]).should.be.fulfilled
              amtAndDest[0].toNumber().should.be.eq(6)
              amtAndDest[1].should.be.eq(payoutTo)
          })

          it('should emit a DeliveredPayment event', async () => {
              payoutAndStoreEvent.should.not.eq(null)
              payoutAndStoreEvent.event.should.be.eq('DeliveredPayment')
          })

          it('should emit an ApplicationExecution event', async () => {
              appExecEvent.should.not.eq(null)
              appExecEvent.event.should.be.eq('ApplicationExecution')
          })

          it('should send ether to the destination', async () => {
              let payoutAddrNewBal = await web3.eth.getBalance(payoutTo).toNumber()
              payoutAddrNewBal.should.not.eq(0)
              payoutAddrNewBal.should.be.eq(payoutAddrPrevBal + 6)
          })

          it('should leave no ether in the storage contract', async () => {
              let storageBal = await web3.eth.getBalance(storage.address).toNumber()
              storageBal.should.be.eq(0)
          })

          describe('DeliveredPayment event', async () => {
              it('should contain an indexed execution id', async () => {
                  let eventExecId = payoutAndStoreEvent.args['execution_id']
                  eventExecId.should.not.eq(null)
                  eventExecId.should.be.deep.eq(instanceExecId)
              })

              it('should contain an indexed destination address', async () => {
                  let eventDestinationAddr = payoutAndStoreEvent.args['destination']
                  eventDestinationAddr.should.not.eq(null)
                  eventDestinationAddr.should.be.deep.eq(payoutTo)
              })
          })


          describe('ApplicationExecution event', async () => {
              it('should contain an indexed execution id', async () => {
                  let eventExecId = appExecEvent.args['execution_id']
                  eventExecId.should.not.eq(null)
                  eventExecId.should.be.deep.eq(instanceExecId)
              })

              it('should contain an indexed target address', async () => {
                  let eventTargetAddr = appExecEvent.args['script_target']
                  eventTargetAddr.should.not.eq(null)
                  eventTargetAddr.should.be.deep.eq(payableAppLib.address)
              })
          })

          context('when the app is paused', async () => {

              it('should not allowed execution', async () => {
                  await storage.pauseAppInstance(instanceExecId, { from: appUpdaterAddr }).should.be.fulfilled
                  await storage.exec(
                    payableAppLib.address, instanceExecId, payoutAndStoreCalldata, { from: scriptExecAddr, value: web3.fromWei('6', 'wei') }
                  ).should.not.be.fulfilled
              })
          })
        })

        context('#payoutAndStore - when the sender is not the script exec contract', async () => {

            it('should not allow execution', async () => {
                await storage.exec(
                    payableAppLib.address, instanceExecId, payoutAndStoreCalldata, { from: nonScriptExec, value: web3.fromWei('6', 'wei') }
                ).should.not.be.fulfilled
            })
        })
    })

    describe('#handleException', async () => {
        let appExceptionEvent

        let appErrorLib
        let genericCalldata = '0x87ee7d10'
        let errorWithMessageCalldata = '0xb91f6cc7'

        let genericError = 'DefaultException'
        let customError = 'TestingErrorMessage'

        let instanceExecId

        beforeEach(async () => {
            appErrorLib = await ApplicationMockErrorLib.new().should.be.fulfilled

            instanceExecId = await storage.initAndFinalize.call(
                appUpdaterAddr, false, appInit.address, appInitCalldata, [appErrorLib.address], { from: scriptExecAddr }
            ).should.be.fulfilled
            await storage.initAndFinalize(
                appUpdaterAddr, false, appInit.address, appInitCalldata, [appErrorLib.address], { from: scriptExecAddr }
            ).should.be.fulfilled
        })

        context('DefaultException', async () => {
            let execReturn

            beforeEach(async () => {
                execReturn = await storage.exec.call(
                    appErrorLib.address, instanceExecId, genericCalldata, { from: scriptExecAddr }
                )

                let execEvents = await storage.exec(
                    appErrorLib.address, instanceExecId, genericCalldata, { from: scriptExecAddr }
                ).should.be.fulfilled.then((tx) => {
                    return tx.logs;
                })

                execEvents.should.not.eq(null)
                execEvents.length.should.be.eq(1)

                appExceptionEvent = execEvents[0]

            })

            it('should have valid return data', async () => {
                execReturn.length.should.be.eq(3)
                execReturn[0].should.be.eq(false)
                execReturn[1].toNumber().should.be.eq(0)
                execReturn[2].should.be.eq('0x')
            })

            it('should emit an ApplicationException event', async () => {
                appExceptionEvent.should.not.eq(null)
                appExceptionEvent.event.should.be.eq('ApplicationException')
            })

            describe('ApplicationException event', async () => {
                it('should contain an indexed application address', async () => {
                    let eventApplicationAddr = appExceptionEvent.args['application_address']
                    eventApplicationAddr.should.not.eq(null)
                    eventApplicationAddr.should.be.deep.eq(appErrorLib.address)
                })

                it('should contain an indexed execution id', async () => {
                    let eventExecId = appExceptionEvent.args['execution_id']
                    eventExecId.should.not.eq(null)
                    eventExecId.should.be.deep.eq(instanceExecId)
                })

                it('should contain a generic indexed error messsage', async () => {
                    let eventErrorMessage = appExceptionEvent.args['message']
                    eventErrorMessage.should.not.eq(null)
                    web3.toAscii(eventErrorMessage).substring(
                      0,
                      'DefaultException'.length
                    ).should.be.deep.eq(genericError)
                })
            })
        })

        context('TestingErrorMessage', async () => {
            let execReturn

            beforeEach(async () => {
                execReturn = await storage.exec.call(
                    appErrorLib.address, instanceExecId, errorWithMessageCalldata, { from: scriptExecAddr }
                )

                let execEvents = await storage.exec(
                    appErrorLib.address, instanceExecId, errorWithMessageCalldata, { from: scriptExecAddr }
                ).should.be.fulfilled.then((tx) => {
                    return tx.logs;
                })

                execEvents.should.not.eq(null)
                execEvents.length.should.be.eq(1)

                appExceptionEvent = execEvents[0]

            })

            it('should have valid return data', async () => {
                execReturn.length.should.be.eq(3)
                execReturn[0].should.be.eq(false)
                execReturn[1].toNumber().should.be.eq(0)
                execReturn[2].should.be.eq('0x')
            })

            it('should emit an ApplicationException event', async () => {
                appExceptionEvent.should.not.eq(null)
                appExceptionEvent.event.should.be.eq('ApplicationException')
            })

            describe('ApplicationException event', async () => {
                it('should contain an indexed application address', async () => {
                    let eventApplicationAddr = appExceptionEvent.args['application_address']
                    eventApplicationAddr.should.not.eq(null)
                    eventApplicationAddr.should.be.deep.eq(appErrorLib.address)
                })

                it('should contain an indexed execution id', async () => {
                    let eventExecId = appExceptionEvent.args['execution_id']
                    eventExecId.should.not.eq(null)
                    eventExecId.should.be.deep.eq(instanceExecId)
                })

                it('should contain a custom indexed error messsage', async () => {
                    let eventErrorMessage = appExceptionEvent.args['message']
                    eventErrorMessage.should.not.eq(null)
                    web3.toAscii(eventErrorMessage).substring(
                      0,
                      'TestingErrorMessage'.length
                    ).should.be.deep.eq(customError)
                })
            })
        })
    })

    describe('#store', async () => {
        let appStorageLib

        let instanceExecId

        let storeSingleCalldata
        let storeMultiCalldata
        let storeVarCalldata
        let storeInvalidCalldata

        let singleStorageLoc = web3.sha3('single_storage');
        let multiStorageLoc = web3.sha3('multi_storage');
        let varStorageLoc = web3.sha3('variable_storage');

        beforeEach(async () => {
            storeSingleCalldata = await storage.mockGetStoreSingleCalldata(5).should.be.fulfilled
            storeMultiCalldata = await storage.mockGetStoreMultiCalldata(6).should.be.fulfilled
            storeVarCalldata = await storage.mockGetStoreVariableCalldata(3, 7).should.be.fulfilled
            storeInvalidCalldata = await storage.mockGetStoreInvalidCalldata().should.be.fulfilled

            appStorageLib = await ApplicationMockStorageLib.new().should.be.fulfilled

            instanceExecId = await storage.initAndFinalize.call(
                appUpdaterAddr, false, appInit.address, appInitCalldata, [appStorageLib.address], { from: scriptExecAddr }
            ).should.be.fulfilled
            await storage.initAndFinalize(
                appUpdaterAddr, false, appInit.address, appInitCalldata, [appStorageLib.address], { from: scriptExecAddr }
            ).should.be.fulfilled
        })

        context('when the application stores to a single slot in storage', async () => {
            let appExecEvent

            let execReturn

            beforeEach(async () => {
                execReturn = await storage.exec.call(
                    appStorageLib.address, instanceExecId, storeSingleCalldata, { from: scriptExecAddr }
                )

                let execEvents = await storage.exec(
                    appStorageLib.address, instanceExecId, storeSingleCalldata, { from: scriptExecAddr }
                ).should.be.fulfilled.then((tx) => {
                    return tx.logs;
                })

                execEvents.should.not.eq(null)
                execEvents.length.should.be.eq(1)

                appExecEvent = execEvents[0]
            })

            it('should have valid return data', async () => {
                execReturn.length.should.be.eq(3)
                execReturn[0].should.be.eq(true)
                execReturn[1].toNumber().should.be.eq(1)
                execReturn[2].should.be.eq('0x')
            })

            it('should emit an ApplicationExecution event', async () => {
                appExecEvent.should.not.eq(null)
                appExecEvent.event.should.be.eq('ApplicationExecution')
            })

            describe('ApplicationExecution event', async () => {
                it('should contain an indexed execution id', async () => {
                    let eventExecId = appExecEvent.args['execution_id']
                    eventExecId.should.not.eq(null)
                    eventExecId.should.be.deep.eq(instanceExecId)
                })

                it('should contain an indexed target address', async () => {
                    let eventTargetAddr = appExecEvent.args['script_target']
                    eventTargetAddr.should.not.eq(null)
                    eventTargetAddr.should.be.deep.eq(appStorageLib.address)
                })
            })

            it('should read the correct value from storage', async () => {
                let readData = await storage.read.call(instanceExecId, singleStorageLoc)
                web3.toBigNumber(readData).toNumber().should.be.eq(5)
            })
        })

        context('when the application stores to multiple slots in storage', async () => {
            let appExecEvent

            let execReturn

            beforeEach(async () => {
                execReturn = await storage.exec.call(
                    appStorageLib.address, instanceExecId, storeMultiCalldata, { from: scriptExecAddr }
                )

                let execEvents = await storage.exec(
                    appStorageLib.address, instanceExecId, storeMultiCalldata, { from: scriptExecAddr }
                ).should.be.fulfilled.then((tx) => {
                    return tx.logs;
                })

                execEvents.should.not.eq(null)
                execEvents.length.should.be.eq(1)

                appExecEvent = execEvents[0]
            })

            it('should have valid return data', async () => {
                execReturn.length.should.be.eq(3)
                execReturn[0].should.be.eq(true)
                execReturn[1].toNumber().should.be.eq(2)
                execReturn[2].should.be.eq('0x')
            })

            it('should emit an ApplicationExecution event', async () => {
                appExecEvent.should.not.eq(null)
                appExecEvent.event.should.be.eq('ApplicationExecution')
            })

            describe('ApplicationExecution event', async () => {
                it('should contain an indexed execution id', async () => {
                    let eventExecId = appExecEvent.args['execution_id']
                    eventExecId.should.not.eq(null)
                    eventExecId.should.be.deep.eq(instanceExecId)
                })

                it('should contain an indexed target address', async () => {
                    let eventTargetAddr = appExecEvent.args['script_target']
                    eventTargetAddr.should.not.eq(null)
                    eventTargetAddr.should.be.deep.eq(appStorageLib.address)
                })
            })

            it('should read the correct values from storage', async () => {
                let secondStorageLoc = await storage.addToBytes32.call(multiStorageLoc)
                let readData = await storage.readMulti.call(
                    instanceExecId, [
                        multiStorageLoc,
                        secondStorageLoc
                    ]
                )
                readData.length.should.be.eq(2)
                web3.toDecimal(readData[0]).should.be.eq(6)
                web3.toDecimal(readData[1]).should.be.eq(7)
            })
        })

        context('when the application stores to variable slots in storage', async () => {
            let appExecEvent

            let execReturn

            beforeEach(async () => {
                execReturn = await storage.exec.call(
                    appStorageLib.address, instanceExecId, storeVarCalldata, { from: scriptExecAddr }
                )

                let execEvents = await storage.exec(
                    appStorageLib.address, instanceExecId, storeVarCalldata, { from: scriptExecAddr }
                ).should.be.fulfilled.then((tx) => {
                    return tx.logs;
                })

                execEvents.should.not.eq(null)
                execEvents.length.should.be.eq(1)

                appExecEvent = execEvents[0]
            })

            it('should have valid return data', async () => {
                execReturn.length.should.be.eq(3)
                execReturn[0].should.be.eq(true)
                execReturn[1].toNumber().should.be.eq(3)
                execReturn[2].should.be.eq('0x')
            })

            it('should emit an ApplicationExecution event', async () => {
                appExecEvent.should.not.eq(null)
                appExecEvent.event.should.be.eq('ApplicationExecution')
            })

            describe('ApplicationExecution event', async () => {
                it('should contain an indexed execution id', async () => {
                    let eventExecId = appExecEvent.args['execution_id']
                    eventExecId.should.not.eq(null)
                    eventExecId.should.be.deep.eq(instanceExecId)
                })

                it('should contain an indexed target address', async () => {
                    let eventTargetAddr = appExecEvent.args['script_target']
                    eventTargetAddr.should.not.eq(null)
                    eventTargetAddr.should.be.deep.eq(appStorageLib.address)
                })
            })

            it('should read the correct values from storage', async () => {
                let secondStorageLoc = await storage.addToBytes32.call(varStorageLoc)
                let thirdStorageLoc = await storage.addToBytes32.call(secondStorageLoc)
                let readData = await storage.readMulti.call(
                    instanceExecId, [
                        varStorageLoc,
                        secondStorageLoc,
                        thirdStorageLoc
                    ]
                )
                readData.length.should.be.eq(3)
                web3.toDecimal(readData[0]).should.be.eq(7)
                web3.toDecimal(readData[1]).should.be.eq(8)
                web3.toDecimal(readData[2]).should.be.eq(9)
            })
        })

        context('when the application returns an invalid storage request', async () => {

            it('should not allow execution', async () => {
                await storage.exec(
                  appStorageLib.address,
                  instanceExecId,
                  storeInvalidCalldata,
                  { from: scriptExecAddr }
                ).should.not.be.fulfilled
            })
        })
    })

    describe('#changeInitAddr', async () => {
        let instanceExecId
        let newAppInit

        beforeEach(async() => {
            instanceExecId = await storage.initAndFinalize.call(
                appUpdaterAddr, false, appInit.address, appInitCalldata, [appFuncLib.address], { from: scriptExecAddr }
            ).should.be.fulfilled
            await storage.initAndFinalize(
                appUpdaterAddr, false, appInit.address, appInitCalldata, [appFuncLib.address], { from: scriptExecAddr }
            ).should.be.fulfilled

            newAppInit = await ApplicationMockInit.new().should.be.fulfilled
            newAppInit.should.not.eq(null)
        })

        context('when the app is paused', async () => {
            beforeEach(async () => {
                await storage.pauseAppInstance(instanceExecId, { from: appUpdaterAddr }).should.be.fulfilled
            })

            context('when the sender is the updater address', async () => {
                beforeEach(async () => {
                    await storage.changeInitAddr(instanceExecId, newAppInit.address, { from: appUpdaterAddr }).should.be.fulfilled
                })

                it('should update the app init address', async () => {
                    let storedInit =  await storage.app_info(instanceExecId).should.be.fulfilled
                    storedInit[0].should.be.eq(true)
                    storedInit[5].should.not.eq(0)
                    storedInit[5].should.not.eq(appInit.address)
                    storedInit[5].should.be.eq(newAppInit.address)
                })
            })

            context('when the sender is not the updater address', async () => {
                beforeEach(async () => {
                    await storage.changeInitAddr(instanceExecId, newAppInit.address, { from: nonUpdaterAddr }).should.not.be.fulfilled
                })

                it('should not update the app init address', async () => {
                    let storedInit =  await storage.app_info(instanceExecId).should.be.fulfilled
                    storedInit[0].should.be.eq(true)
                    storedInit[5].should.not.eq(0)
                    storedInit[5].should.be.eq(appInit.address)
                    storedInit[5].should.not.eq(newAppInit.address)
                })
            })
        })

        context('when the app is unpaused', async () => {
            beforeEach(async () => {
                await storage.unpauseAppInstance(instanceExecId, { from: appUpdaterAddr })
            })

            context('when the sender is the updater address', async () => {
                beforeEach(async () => {
                    await storage.changeInitAddr(instanceExecId, newAppInit.address, { from: appUpdaterAddr }).should.not.be.fulfilled
                })

                it('should not update the app init address', async () => {
                    let storedInit =  await storage.app_info(instanceExecId).should.be.fulfilled
                    storedInit[0].should.be.eq(false)
                    storedInit[5].should.not.eq(0)
                    storedInit[5].should.be.eq(appInit.address)
                    storedInit[5].should.not.eq(newAppInit.address)
                })
            })

            context('when the sender is not the updater address', async () => {
                beforeEach(async () => {
                    await storage.changeInitAddr(instanceExecId, newAppInit.address, { from: nonUpdaterAddr }).should.not.be.fulfilled
                })

                it('should not update the app init address', async () => {
                    let storedInit =  await storage.app_info(instanceExecId).should.be.fulfilled
                    storedInit[0].should.be.eq(false)
                    storedInit[5].should.not.eq(0)
                    storedInit[5].should.be.eq(appInit.address)
                    storedInit[5].should.not.eq(newAppInit.address)
                })
            })
        })
    })

    describe('#changeScriptExec', async () => {
        let instanceExecId
        let newScriptExecAddr = accounts[2]

        beforeEach(async () => {
            instanceExecId = await storage.initAndFinalize.call(
                appUpdaterAddr, false, appInit.address, appInitCalldata, [appFuncLib.address], { from: scriptExecAddr }
            ).should.be.fulfilled
            await storage.initAndFinalize(
                appUpdaterAddr, false, appInit.address, appInitCalldata, [appFuncLib.address], { from: scriptExecAddr }
            ).should.be.fulfilled
        })

        context('sender is the script exec address', async () => {
            beforeEach(async () => {
                await storage.changeScriptExec(instanceExecId, newScriptExecAddr, { from: scriptExecAddr }).should.be.fulfilled
            })

            it('should modify a script exec address', async () => {
                let storedExecAddr = await storage.app_info(instanceExecId).should.be.fulfilled
                storedExecAddr[4].should.be.eq(newScriptExecAddr)
            })

            it('should allow the new script exec address to change the script exec address', async () => {
                await storage.changeScriptExec(instanceExecId, accounts[3], { from: newScriptExecAddr }).should.be.fulfilled
                let storedExecAddr = await storage.app_info(instanceExecId).should.be.fulfilled
                storedExecAddr[4].should.be.eq(accounts[3])
            })
        })

        context('sender is not the script exec address', async () => {
            beforeEach(async () => {
                await storage.changeScriptExec(instanceExecId, newScriptExecAddr, { from: nonScriptExec }).should.not.be.fulfilled
            })

            it('should not modify a script exec address', async () => {
                let storedExecAddr = await storage.app_info(instanceExecId).should.be.fulfilled
                storedExecAddr[4].should.not.be.eq(newScriptExecAddr)
            })

            it('should not allow the new script exec address to change the script exec address', async () => {
                await storage.changeScriptExec(instanceExecId, accounts[3], { from: newScriptExecAddr }).should.not.be.fulfilled
                let storedExecAddr = await storage.app_info(instanceExecId).should.be.fulfilled
                storedExecAddr[4].should.not.be.eq(accounts[3])
            })
        })
    })

    describe('#pauseAppInstance', async () => {
        let instanceExecId

        beforeEach(async() => {
            instanceExecId = await storage.initAndFinalize.call(
                appUpdaterAddr, false, appInit.address, appInitCalldata, [appFuncLib.address], { from: scriptExecAddr }
            ).should.be.fulfilled
            await storage.initAndFinalize(
                appUpdaterAddr, false, appInit.address, appInitCalldata, [appFuncLib.address], { from: scriptExecAddr }
            ).should.be.fulfilled
        })

        context('when the sender is the updater address', async () => {
            beforeEach(async () => {
                await storage.pauseAppInstance(instanceExecId, { from: appUpdaterAddr }).should.be.fulfilled
            })

            it('should allow the sender to pause the application', async () => {
                let applicationInfo = await storage.app_info(instanceExecId).should.be.fulfilled
                applicationInfo[0].should.be.eq(true)
                applicationInfo[1].should.be.eq(true)
                applicationInfo[2].should.be.eq(false)
                applicationInfo[3].should.be.eq(appUpdaterAddr)
                applicationInfo[4].should.be.eq(scriptExecAddr)
                applicationInfo[5].should.be.eq(appInit.address)
            })

            it('should not allow the script exec contract to access "exec" for the paused exec id', async () => {
                await storage.exec(appFuncLib.address, instanceExecId, appFuncCalldata, { from: scriptExecAddr }).should.not.be.fulfilled
            })
        })

        context('when the sender is not the updater address', async () => {
            beforeEach(async () => {
                await storage.pauseAppInstance(instanceExecId, { from: nonUpdaterAddr }).should.not.be.fulfilled
            })

            it('should not allow the sender to pause the application', async () => {
                let applicationInfo = await storage.app_info(instanceExecId).should.be.fulfilled
                applicationInfo[0].should.be.eq(false)
                applicationInfo[1].should.be.eq(true)
                applicationInfo[2].should.be.eq(false)
                applicationInfo[3].should.be.eq(appUpdaterAddr)
                applicationInfo[4].should.be.eq(scriptExecAddr)
                applicationInfo[5].should.be.eq(appInit.address)
            })

          it('should allow the script exec address to execute the application', async () => {
              await storage.exec(appFuncLib.address, instanceExecId, appFuncCalldata, { from: scriptExecAddr }).should.be.fulfilled
          })
        })
    })

    describe('#unpauseAppInstance', async () => {
        let instanceExecId

        beforeEach(async () => {
            instanceExecId = await storage.initAndFinalize.call(
                appUpdaterAddr, false, appInit.address, appInitCalldata, [appFuncLib.address], { from: scriptExecAddr }
            ).should.be.fulfilled
            await storage.initAndFinalize(
                appUpdaterAddr, false, appInit.address, appInitCalldata, [appFuncLib.address], { from: scriptExecAddr }
            ).should.be.fulfilled

            await storage.pauseAppInstance(instanceExecId, { from: appUpdaterAddr }).should.be.fulfilled
            await storage.exec(appFuncLib.address, instanceExecId, appFuncCalldata, { from: scriptExecAddr }).should.not.be.fulfilled
        })

        context('when the sender is the updater address', async () => {
            beforeEach(async () => {
                await storage.unpauseAppInstance(instanceExecId, { from: appUpdaterAddr }).should.be.fulfilled
            })

            it('should allow the sender to unpause the application', async () => {
                let applicationInfo = await storage.app_info(instanceExecId).should.be.fulfilled
                applicationInfo[0].should.be.eq(false)
                applicationInfo[1].should.be.eq(true)
                applicationInfo[2].should.be.eq(false)
                applicationInfo[3].should.be.eq(appUpdaterAddr)
                applicationInfo[4].should.be.eq(scriptExecAddr)
                applicationInfo[5].should.be.eq(appInit.address)
            })

            it('should allow the script exec address to execute the application', async () => {
                await storage.exec(appFuncLib.address, instanceExecId, appFuncCalldata, { from: scriptExecAddr }).should.be.fulfilled
            })
        })

        context('when the sender is not the updater address', async () => {
            beforeEach(async () => {
                await storage.unpauseAppInstance(instanceExecId, { from: nonUpdaterAddr }).should.not.be.fulfilled
            })

            it('should not allow the sender to unpause the application', async () => {
                let applicationInfo = await storage.app_info(instanceExecId).should.be.fulfilled
                applicationInfo[0].should.be.eq(true)
                applicationInfo[1].should.be.eq(true)
                applicationInfo[2].should.be.eq(false)
                applicationInfo[3].should.be.eq(appUpdaterAddr)
                applicationInfo[4].should.be.eq(scriptExecAddr)
                applicationInfo[5].should.be.eq(appInit.address)
            })

            it('should not allow the script exec address to execute the application', async () => {
                await storage.exec(appFuncLib.address, instanceExecId, appFuncCalldata, { from: scriptExecAddr }).should.not.be.fulfilled
            })
        })

    })

    describe('#addAllowed', async () => {
        let instanceExecId
        let appFuncLibA
        let appFuncLibB
        let appFuncLibC

        beforeEach(async () => {
            instanceExecId = await storage.initAndFinalize.call(
                appUpdaterAddr, false, appInit.address, appInitCalldata, [appFuncLib.address], { from: scriptExecAddr }
            ).should.be.fulfilled
            await storage.initAndFinalize(
                appUpdaterAddr, false, appInit.address, appInitCalldata, [appFuncLib.address], { from: scriptExecAddr }
            ).should.be.fulfilled

            appFuncLibA = await ApplicationFuncLib.new().should.be.fulfilled
            appFuncLibB = await ApplicationFuncLib.new().should.be.fulfilled
            appFuncLibC = await ApplicationFuncLib.new().should.be.fulfilled
        })

        context('app is paused', async () => {

            beforeEach(async () => {
                await storage.pauseAppInstance(instanceExecId, { from: appUpdaterAddr }).should.be.fulfilled
            })

            context('sender is updater address', async () => {
                beforeEach(async () => {
                    await storage.addAllowed(
                        instanceExecId, [
                          appFuncLibA.address,
                          appFuncLibB.address,
                          appFuncLibC.address
                        ], { from: appUpdaterAddr }
                    ).should.be.fulfilled
                })

                it('should allow addresses to be added', async () => {
                    let allowedAddrs = await storage.getExecAllowed(instanceExecId).should.be.fulfilled
                    let appStruct = await storage.app_info(instanceExecId).should.be.fulfilled
                    appStruct[0].should.be.eq(true)
                    allowedAddrs.length.should.be.eq(4)
                    allowedAddrs[0].should.be.eq(appFuncLib.address)
                    allowedAddrs[1].should.be.eq(appFuncLibA.address)
                    allowedAddrs[2].should.be.eq(appFuncLibB.address)
                    allowedAddrs[3].should.be.eq(appFuncLibC.address)
                })
            })

            context('sender is not updater address', async () => {
                beforeEach(async () => {
                    await storage.addAllowed(
                        instanceExecId, [
                          appFuncLibA.address,
                          appFuncLibB.address,
                          appFuncLibC.address
                        ], { from: nonUpdaterAddr }
                    ).should.not.be.fulfilled
                })

                it('should not allow addresses to be added', async () => {
                    let allowedAddrs = await storage.getExecAllowed(instanceExecId).should.be.fulfilled
                    let appStruct = await storage.app_info(instanceExecId).should.be.fulfilled
                    appStruct[0].should.be.eq(true)
                    allowedAddrs.length.should.be.eq(1)
                    allowedAddrs[0].should.be.eq(appFuncLib.address)
                })
            })
        })

        context('app is not paused', async () => {

            beforeEach(async () => {
                await storage.unpauseAppInstance(instanceExecId, { from: appUpdaterAddr })
            })

            context('sender is updater address', async () => {
                beforeEach(async () => {
                    await storage.addAllowed(
                        instanceExecId, [
                          appFuncLibA.address,
                          appFuncLibB.address,
                          appFuncLibC.address
                        ], { from: appUpdaterAddr }
                    ).should.not.be.fulfilled
                })

                it('should not allow addresses to be added', async () => {
                    let allowedAddrs = await storage.getExecAllowed(instanceExecId).should.be.fulfilled
                    let appStruct = await storage.app_info(instanceExecId).should.be.fulfilled
                    appStruct[0].should.be.eq(false)
                    allowedAddrs.length.should.be.eq(1)
                    allowedAddrs[0].should.be.eq(appFuncLib.address)
                })
            })

            context('sender is not updater address', async () => {
                beforeEach(async () => {
                    await storage.addAllowed(
                        instanceExecId, [
                          appFuncLibA.address,
                          appFuncLibB.address,
                          appFuncLibC.address
                        ], { from: nonUpdaterAddr }
                    ).should.not.be.fulfilled
                })

                it('should not allow addresses to be added', async () => {
                    let allowedAddrs = await storage.getExecAllowed(instanceExecId).should.be.fulfilled
                    let appStruct = await storage.app_info(instanceExecId).should.be.fulfilled
                    appStruct[0].should.be.eq(false)
                    allowedAddrs.length.should.be.eq(1)
                    allowedAddrs[0].should.be.eq(appFuncLib.address)
                })
            })
        })
    })

    describe('#removeAllowed', async () => {
        let instanceExecId
        let appFuncLibA
        let appFuncLibB
        let appFuncLibC

        beforeEach(async () => {
            appFuncLibA = await ApplicationFuncLib.new().should.be.fulfilled
            appFuncLibB = await ApplicationFuncLib.new().should.be.fulfilled
            appFuncLibC = await ApplicationFuncLib.new().should.be.fulfilled

            instanceExecId = await storage.initAndFinalize.call(
                appUpdaterAddr, false, appInit.address, appInitCalldata, [
                    appFuncLib.address,
                    appFuncLibA.address,
                    appFuncLibB.address,
                    appFuncLibC.address
                ], { from: scriptExecAddr }
            ).should.be.fulfilled
            await storage.initAndFinalize(
                appUpdaterAddr, false, appInit.address, appInitCalldata, [
                    appFuncLib.address,
                    appFuncLibA.address,
                    appFuncLibB.address,
                    appFuncLibC.address
                ], { from: scriptExecAddr }
            ).should.be.fulfilled

            let numAddrs = await storage.getExecAllowed(instanceExecId).should.be.fulfilled
            numAddrs.length.should.be.eq(4)
        })

        context('app is paused', async () => {

            beforeEach(async () => {
                await storage.pauseAppInstance(instanceExecId, { from: appUpdaterAddr }).should.be.fulfilled
            })

            context('sender is updater address', async () => {
                beforeEach(async () => {
                    await storage.removeAllowed(
                        instanceExecId, [
                            appFuncLibA.address,
                            appFuncLibB.address,
                            appFuncLibC.address
                        ], { from: appUpdaterAddr }
                    ).should.be.fulfilled
                })

                it('should allow addresses to be removed', async () => {
                    let allowedAddrs = await storage.getExecAllowed(instanceExecId).should.be.fulfilled
                    let appStruct = await storage.app_info(instanceExecId).should.be.fulfilled
                    appStruct[0].should.be.eq(true)
                    allowedAddrs.length.should.be.eq(1)
                    allowedAddrs[0].should.be.eq(appFuncLib.address)
                })
            })

            context('sender is not updater address', async () => {
                beforeEach(async () => {
                    await storage.removeAllowed(
                        instanceExecId, [
                          appFuncLibA.address,
                          appFuncLibB.address,
                          appFuncLibC.address
                        ], { from: nonUpdaterAddr }
                    ).should.not.be.fulfilled
                })

                it('should not allow addresses to be removed', async () => {
                    let allowedAddrs = await storage.getExecAllowed(instanceExecId).should.be.fulfilled
                    let appStruct = await storage.app_info(instanceExecId).should.be.fulfilled
                    appStruct[0].should.be.eq(true)
                    allowedAddrs.length.should.be.eq(4)
                    allowedAddrs[0].should.be.eq(appFuncLib.address)
                    allowedAddrs[1].should.be.eq(appFuncLibA.address)
                    allowedAddrs[2].should.be.eq(appFuncLibB.address)
                    allowedAddrs[3].should.be.eq(appFuncLibC.address)
                })
            })
        })

        context('app is not paused', async () => {

            beforeEach(async () => {
                await storage.unpauseAppInstance(instanceExecId, { from: appUpdaterAddr })
            })

            context('sender is updater address', async () => {
                beforeEach(async () => {
                    await storage.removeAllowed(
                        instanceExecId, [
                          appFuncLibA.address,
                          appFuncLibB.address,
                          appFuncLibC.address
                        ], { from: appUpdaterAddr }
                    ).should.not.be.fulfilled
                })

                it('should not allow addresses to be removed', async () => {
                    let allowedAddrs = await storage.getExecAllowed(instanceExecId).should.be.fulfilled
                    let appStruct = await storage.app_info(instanceExecId).should.be.fulfilled
                    appStruct[0].should.be.eq(false)
                    allowedAddrs.length.should.be.eq(4)
                    allowedAddrs[0].should.be.eq(appFuncLib.address)
                    allowedAddrs[1].should.be.eq(appFuncLibA.address)
                    allowedAddrs[2].should.be.eq(appFuncLibB.address)
                    allowedAddrs[3].should.be.eq(appFuncLibC.address)
                })
            })

            context('sender is not updater address', async () => {
                beforeEach(async () => {
                    await storage.removeAllowed(
                        instanceExecId, [
                          appFuncLibA.address,
                          appFuncLibB.address,
                          appFuncLibC.address
                        ], { from: nonUpdaterAddr }
                    ).should.not.be.fulfilled
                })

                it('should not allow addresses to be removed', async () => {
                    let allowedAddrs = await storage.getExecAllowed(instanceExecId).should.be.fulfilled
                    let appStruct = await storage.app_info(instanceExecId).should.be.fulfilled
                    appStruct[0].should.be.eq(false)
                    allowedAddrs.length.should.be.eq(4)
                    allowedAddrs[0].should.be.eq(appFuncLib.address)
                    allowedAddrs[1].should.be.eq(appFuncLibA.address)
                    allowedAddrs[2].should.be.eq(appFuncLibB.address)
                    allowedAddrs[3].should.be.eq(appFuncLibC.address)
                })
            })
        })
    })

    describe('#withdraw', async () => {
        beforeEach(async () => {
            storage = await AbstractStorage.new().should.be.fulfilled
        })

        context('contract has nonzero balance', async () => {
            let forceSendEther
            let storageBalance

            beforeEach(async () => {
                forceSendEther = await ForceSendEther.new().should.be.fulfilled
                await forceSendEther.forcePay(storage.address, { value: web3.toWei('1','ether'), from: accounts[0] }).should.be.fulfilled
            })

            it('should withdraw to the calling address', async () => {
                let senderBalance = await web3.eth.getBalance(accounts[1]).toNumber()
                await storage.withdraw({ from: accounts[1] })
                let senderUpdatedBalance = await web3.eth.getBalance(accounts[1]).toNumber()
                senderUpdatedBalance.should.be.above(senderBalance)
            })
        })

        context('contract has zero balance', async () => {
            let forceSendEther
            let storageBalance

            beforeEach(async () => {
                forceSendEther = await ForceSendEther.new().should.be.fulfilled
                await forceSendEther.forcePay(storage.address, { from: accounts[0] }).should.be.fulfilled
                storageBalance = await web3.eth.getBalance(storage.address).toNumber()
                storageBalance.should.be.eq(0)
                // web3.toWei(storageBalance).should.be.eq(web3.toWei('0','ether'))
            })

            it('should not withdraw to the calling address', async () => {
                let senderBalance = await web3.eth.getBalance(accounts[1]).toNumber()
                await storage.withdraw({ from: accounts[1] })
                let senderUpdatedBalance = await web3.eth.getBalance(accounts[1]).toNumber()
                senderUpdatedBalance.should.not.eq(0)
                senderUpdatedBalance.should.be.below(senderBalance)
            })
        })
    })
})
