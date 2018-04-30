let AbstractStorage = artifacts.require('./mock/AbstractStorageMock')
let ApplicationMockInit = artifacts.require('./mock/ApplicationMockInit')
let ApplicationFuncLib = artifacts.require('./mock/ApplicationMockFuncLib')
let ApplicationPayableLib = artifacts.require('./mock/ApplicationMockPayableLib')
let ApplicationMockErrorLib = artifacts.require('./mock/ApplicationMockErrorLib')
let ApplicationMockStorageLib = artifacts.require('./mock/ApplicationMockStoreData')
let ForceSendEther = artifacts.require('./mock/ForceSendEther')


contract('AbstractStorage', function (accounts) {
    let script_exec_addr = accounts[0]
    let non_script_exec = accounts[1]
    let app_updater_addr = accounts[accounts.length - 1]
    let non_updater_addr = accounts[accounts.length - 2]
    let app_func_lib
    let app_func_calldata = '0x0f0558ba'
    let appInit // mock application
    let appInitCalldata // calldata for mock application initializer

    let storage

    beforeEach(async () => {
        storage = await AbstractStorage.new()

        appInit = await ApplicationMockInit.new().should.be.fulfilled
        appInit.should.not.eq(null)
        appInitCalldata = '0xe1c7392a' // bytes4(keccak256("init()"));
        app_func_lib = await ApplicationFuncLib.new().should.be.fulfilled
    })

    describe('#initAndFinalize', async () => {
        context('when the given calldata is valid for the app init function', async () => {
            let execId
            let appInitializedEvent
            let appFinalizedEvent

            beforeEach(async () => {
                events = await storage.initAndFinalize(
                  app_updater_addr, false, appInit.address, appInitCalldata, [app_func_lib.address], { from: script_exec_addr }
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
                    updaterAddr.should.be.deep.eq(app_updater_addr)
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
                let execId = await storage.initAndFinalize.call(app_updater_addr, false, appInit.address, appInitCalldata, [])
                execId.should.not.eq(null)
            })

            it('should correctly set the app_info struct for the new application', async() => {
                let execId = appFinalizedEvent.args['execution_id']
                let app_struct = await storage.app_info(execId)
                app_struct.should.not.eq(null)
                app_struct[0].should.be.eq(false)
                app_struct[1].should.be.eq(true)
                app_struct[2].should.be.eq(false)
                app_struct[3].should.be.eq(app_updater_addr)
                app_struct[4].should.be.eq(script_exec_addr)
                app_struct[5].should.be.eq(appInit.address)
            })
        })

        context('when the given calldata is invalid for the app init function', async () => {
            it('should revert the tx', async () => {
                let invalidCalldata = '' // should be, at a minimum, bytes4(keccak256("init()")) for default application initializer
                await storage.initAndFinalize(app_updater_addr, false, appInit.address, invalidCalldata, []).should.be.rejectedWith(exports.EVM_ERR_REVERT)
            })
        })
    })

    describe('#exec: non-payable', async () => {
        let instance_exec_id

        beforeEach(async () => {
            instance_exec_id = await storage.initAndFinalize.call(
                app_updater_addr, false, appInit.address, appInitCalldata, [app_func_lib.address], { from: script_exec_addr }
            ).should.be.fulfilled
            await storage.initAndFinalize(
                app_updater_addr, false, appInit.address, appInitCalldata, [app_func_lib.address], { from: script_exec_addr }
            ).should.be.fulfilled
        })

        context('when the sender is the script exec contract', async () => {
            let app_execution_event

            beforeEach(async () => {
                let exec_events = await storage.exec(
                    app_func_lib.address, instance_exec_id, app_func_calldata, { from: script_exec_addr }
                ).should.be.fulfilled.then((tx) => {
                    return tx.logs;
                })

                exec_events.should.not.eq(null)
                exec_events.length.should.eq(1)

                app_execution_event = exec_events[0]
            })

            it('should emit an ApplicationExecution event', async () => {
                app_execution_event.should.not.eq(null)
                app_execution_event.event.should.be.eq('ApplicationExecution')
            })

            describe('ApplicationExecution event', async() => {
                it('should contain an indexed execution id', async () => {
                    let event_exec_id = app_execution_event.args['execution_id']
                    event_exec_id.should.not.eq(null)
                    event_exec_id.should.be.deep.eq(instance_exec_id)
                })

                it('should contain an indexed target address', async () => {
                    let event_target_addr = app_execution_event.args['script_target']
                    event_target_addr.should.not.eq(null)
                    event_target_addr.should.be.deep.eq(app_func_lib.address)
                })
            })

            it('should allow execution of the application', async () => {
                let returned = await storage.exec.call(
                    app_func_lib.address, instance_exec_id, app_func_calldata, { from: script_exec_addr }
                )
                returned.should.not.eq(null)
                returned[0].should.be.eq(true)
                returned[1].s.should.be.eq(1)
                returned[2].should.be.eq('0x')
            })

            context('when the app is paused', async () => {

                it('should not allowed execution', async () => {
                    await storage.pauseAppInstance(instance_exec_id, { from: app_updater_addr }).should.be.fulfilled
                    await storage.exec(
                      app_func_lib.address, instance_exec_id, app_func_calldata, { from: script_exec_addr }
                    ).should.not.be.fulfilled
                })
            })

            context('when ether is sent', async () => {

                it('should not allow execution', async () => {
                  await storage.exec(
                    app_func_lib.address, instance_exec_id, app_func_calldata, { from: script_exec_addr, value: 1 }
                  ).should.not.be.fulfilled
                })
            })
        })


        context('when the sender is not the script exec contract', async () => {
            let app_execution_event

            it('should not allow execution from addresses not registered as the script exec', async () => {
                await storage.exec(
                  app_func_lib.address, instance_exec_id, app_func_calldata, { from: non_script_exec }
                ).should.not.be.fulfilled
            })

            context('when the app is paused', async () => {

                it('should not allowed execution', async () => {
                    await storage.pauseAppInstance(instance_exec_id, { from: app_updater_addr }).should.be.fulfilled
                    await storage.exec(
                      app_func_lib.address, instance_exec_id, app_func_calldata, { from: non_script_exec }
                    ).should.not.be.fulfilled
                })
            })

            context('when ether is sent', async () => {

                it('should not allow execution', async () => {
                  await storage.exec(
                    app_func_lib.address, instance_exec_id, app_func_calldata, { from: non_script_exec, value: 1 }
                  ).should.not.be.fulfilled
                })
            })
        })
    })

    describe('#exec: payable', async () => {

        let payout_to = accounts[3]

        let payout_calldata
        let payout_and_store_calldata


        let payable_app_lib

        let instance_exec_id

        beforeEach(async () => {
            payout_calldata = await storage.mockPayoutCalldata.call(payout_to, 5)
            payout_and_store_calldata = await storage.mockPayoutAndStoreCalldata.call(payout_to, 6)
            payout_calldata.should.not.eq(null)
            payout_and_store_calldata.should.not.eq(null)

            payable_app_lib = await ApplicationPayableLib.new().should.be.fulfilled

            instance_exec_id = await storage.initAndFinalize.call(
                app_updater_addr, true, appInit.address, appInitCalldata, [payable_app_lib.address], { from: script_exec_addr }
            ).should.be.fulfilled
            await storage.initAndFinalize(
                app_updater_addr, true, appInit.address, appInitCalldata, [payable_app_lib.address], { from: script_exec_addr }
            ).should.be.fulfilled
        })

        context('#payout - when the sender is the script exec contract', async () => {
            let app_exec_event
            let payout_event

            let payout_addr_prev_bal

            let exec_return

            beforeEach(async () => {
                payout_addr_prev_bal = await web3.eth.getBalance(payout_to).toNumber()

                exec_return = await storage.exec.call(
                    payable_app_lib.address, instance_exec_id, payout_calldata, { from: script_exec_addr, value: web3.fromWei('5', 'wei') }
                )

                let exec_events = await storage.exec(
                    payable_app_lib.address, instance_exec_id, payout_calldata, { from: script_exec_addr, value: web3.fromWei('5', 'wei') }
                ).should.be.fulfilled.then((tx) => {
                    return tx.logs;
                })

                exec_events.should.not.eq(null)
                exec_events.length.should.be.eq(2)

                payout_event = exec_events[0]
                app_exec_event = exec_events[1]
            })

            it('should have valid return data', async () => {
                exec_return.length.should.be.eq(3)
                exec_return[0].should.be.eq(true)
                exec_return[1].toNumber().should.be.eq(0)
                exec_return[2].length.should.be.eq(130)
                let amt_and_dest = await storage.mockGetPaymentInfo(exec_return[2]).should.be.fulfilled
                amt_and_dest[0].toNumber().should.be.eq(5)
                amt_and_dest[1].should.be.eq(payout_to)
            })

            it('should emit a DeliveredPayment event', async () => {
                payout_event.should.not.eq(null)
                payout_event.event.should.be.eq('DeliveredPayment')
            })

            it('should emit an ApplicationExecution event', async () => {
                app_exec_event.should.not.eq(null)
                app_exec_event.event.should.be.eq('ApplicationExecution')
            })

            it('should send ether to the destination', async () => {
                let payout_addr_new_bal = await web3.eth.getBalance(payout_to).toNumber()
                payout_addr_new_bal.should.not.eq(0)
                payout_addr_new_bal.should.be.eq(payout_addr_prev_bal + 5)
            })

            it('should leave no ether in the storage contract', async () => {
                let storage_bal = await web3.eth.getBalance(storage.address).toNumber()
                storage_bal.should.be.eq(0)
            })

            describe('DeliveredPayment event', async () => {
                it('should contain an indexed execution id', async () => {
                    let event_exec_id = payout_event.args['execution_id']
                    event_exec_id.should.not.eq(null)
                    event_exec_id.should.be.deep.eq(instance_exec_id)
                })

                it('should contain an indexed destination address', async () => {
                    let event_destination_addr = payout_event.args['destination']
                    event_destination_addr.should.not.eq(null)
                    event_destination_addr.should.be.deep.eq(payout_to)
                })
            })


            describe('ApplicationExecution event', async () => {
                it('should contain an indexed execution id', async () => {
                    let event_exec_id = app_exec_event.args['execution_id']
                    event_exec_id.should.not.eq(null)
                    event_exec_id.should.be.deep.eq(instance_exec_id)
                })

                it('should contain an indexed target address', async () => {
                    let event_target_addr = app_exec_event.args['script_target']
                    event_target_addr.should.not.eq(null)
                    event_target_addr.should.be.deep.eq(payable_app_lib.address)
                })
            })

            context('when the app is paused', async () => {

                it('should not allowed execution', async () => {
                    await storage.pauseAppInstance(instance_exec_id, { from: app_updater_addr }).should.be.fulfilled
                    await storage.exec(
                      payable_app_lib.address, instance_exec_id, payout_calldata, { from: script_exec_addr, value: web3.fromWei('5', 'wei') }
                    ).should.not.be.fulfilled
                })
            })
        })

        context('#payout - when the sender is not the script exec contract', async () => {

            it('should not allow execution', async () => {
                await storage.exec(
                    payable_app_lib.address, instance_exec_id, payout_calldata, { from: non_script_exec, value: web3.fromWei('5', 'wei') }
                ).should.not.be.fulfilled
            })
        })

        context('#payoutAndStore - when the sender is the script exec contract', async () => {
          let app_exec_event
          let payout_and_store_event

          let payout_addr_prev_bal

          let exec_return

          beforeEach(async () => {
              payout_addr_prev_bal = await web3.eth.getBalance(payout_to).toNumber()

              exec_return = await storage.exec.call(
                  payable_app_lib.address, instance_exec_id, payout_and_store_calldata, { from: script_exec_addr, value: web3.fromWei('6', 'wei') }
              )

              let exec_events = await storage.exec(
                  payable_app_lib.address, instance_exec_id, payout_and_store_calldata, { from: script_exec_addr, value: web3.fromWei('6', 'wei') }
              ).should.be.fulfilled.then((tx) => {
                  return tx.logs;
              })

              exec_events.should.not.eq(null)
              exec_events.length.should.be.eq(2)

              payout_and_store_event = exec_events[0]
              app_exec_event = exec_events[1]
          })

          it('should have valid return data', async () => {
              exec_return.length.should.be.eq(3)
              exec_return[0].should.be.eq(true)
              exec_return[1].toNumber().should.be.eq(1)
              exec_return[2].length.should.be.eq(130)
              let amt_and_dest = await storage.mockGetPaymentInfo(exec_return[2]).should.be.fulfilled
              amt_and_dest[0].toNumber().should.be.eq(6)
              amt_and_dest[1].should.be.eq(payout_to)
          })

          it('should emit a DeliveredPayment event', async () => {
              payout_and_store_event.should.not.eq(null)
              payout_and_store_event.event.should.be.eq('DeliveredPayment')
          })

          it('should emit an ApplicationExecution event', async () => {
              app_exec_event.should.not.eq(null)
              app_exec_event.event.should.be.eq('ApplicationExecution')
          })

          it('should send ether to the destination', async () => {
              let payout_addr_new_bal = await web3.eth.getBalance(payout_to).toNumber()
              payout_addr_new_bal.should.not.eq(0)
              payout_addr_new_bal.should.be.eq(payout_addr_prev_bal + 6)
          })

          it('should leave no ether in the storage contract', async () => {
              let storage_bal = await web3.eth.getBalance(storage.address).toNumber()
              storage_bal.should.be.eq(0)
          })

          describe('DeliveredPayment event', async () => {
              it('should contain an indexed execution id', async () => {
                  let event_exec_id = payout_and_store_event.args['execution_id']
                  event_exec_id.should.not.eq(null)
                  event_exec_id.should.be.deep.eq(instance_exec_id)
              })

              it('should contain an indexed destination address', async () => {
                  let event_destination_addr = payout_and_store_event.args['destination']
                  event_destination_addr.should.not.eq(null)
                  event_destination_addr.should.be.deep.eq(payout_to)
              })
          })


          describe('ApplicationExecution event', async () => {
              it('should contain an indexed execution id', async () => {
                  let event_exec_id = app_exec_event.args['execution_id']
                  event_exec_id.should.not.eq(null)
                  event_exec_id.should.be.deep.eq(instance_exec_id)
              })

              it('should contain an indexed target address', async () => {
                  let event_target_addr = app_exec_event.args['script_target']
                  event_target_addr.should.not.eq(null)
                  event_target_addr.should.be.deep.eq(payable_app_lib.address)
              })
          })

          context('when the app is paused', async () => {

              it('should not allowed execution', async () => {
                  await storage.pauseAppInstance(instance_exec_id, { from: app_updater_addr }).should.be.fulfilled
                  await storage.exec(
                    payable_app_lib.address, instance_exec_id, payout_and_store_calldata, { from: script_exec_addr, value: web3.fromWei('6', 'wei') }
                  ).should.not.be.fulfilled
              })
          })
        })

        context('#payoutAndStore - when the sender is not the script exec contract', async () => {

            it('should not allow execution', async () => {
                await storage.exec(
                    payable_app_lib.address, instance_exec_id, payout_and_store_calldata, { from: non_script_exec, value: web3.fromWei('6', 'wei') }
                ).should.not.be.fulfilled
            })
        })
    })

    describe('#handleException', async () => {
        let app_exception_event

        let app_error_lib
        let generic_calldata = '0x87ee7d10'
        let error_with_message_calldata = '0xb91f6cc7'

        let generic_error = 'DefaultException'
        let custom_error = 'TestingErrorMessage'

        let instance_exec_id

        beforeEach(async () => {
            app_error_lib = await ApplicationMockErrorLib.new().should.be.fulfilled

            instance_exec_id = await storage.initAndFinalize.call(
                app_updater_addr, false, appInit.address, appInitCalldata, [app_error_lib.address], { from: script_exec_addr }
            ).should.be.fulfilled
            await storage.initAndFinalize(
                app_updater_addr, false, appInit.address, appInitCalldata, [app_error_lib.address], { from: script_exec_addr }
            ).should.be.fulfilled
        })

        context('DefaultException', async () => {
            let exec_return

            beforeEach(async () => {
                exec_return = await storage.exec.call(
                    app_error_lib.address, instance_exec_id, generic_calldata, { from: script_exec_addr }
                )

                let exec_events = await storage.exec(
                    app_error_lib.address, instance_exec_id, generic_calldata, { from: script_exec_addr }
                ).should.be.fulfilled.then((tx) => {
                    return tx.logs;
                })

                exec_events.should.not.eq(null)
                exec_events.length.should.be.eq(1)

                app_exception_event = exec_events[0]

            })

            it('should have valid return data', async () => {
                exec_return.length.should.be.eq(3)
                exec_return[0].should.be.eq(false)
                exec_return[1].toNumber().should.be.eq(0)
                exec_return[2].should.be.eq('0x')
            })

            it('should emit an ApplicationException event', async () => {
                app_exception_event.should.not.eq(null)
                app_exception_event.event.should.be.eq('ApplicationException')
            })

            describe('ApplicationException event', async () => {
                it('should contain an indexed application address', async () => {
                    let event_application_addr = app_exception_event.args['application_address']
                    event_application_addr.should.not.eq(null)
                    event_application_addr.should.be.deep.eq(app_error_lib.address)
                })

                it('should contain an indexed execution id', async () => {
                    let event_exec_id = app_exception_event.args['execution_id']
                    event_exec_id.should.not.eq(null)
                    event_exec_id.should.be.deep.eq(instance_exec_id)
                })

                it('should contain a generic indexed error messsage', async () => {
                    let event_error_message = app_exception_event.args['message']
                    event_error_message.should.not.eq(null)
                    web3.toAscii(event_error_message).substring(
                      0,
                      'DefaultException'.length
                    ).should.be.deep.eq(generic_error)
                })
            })
        })

        context('TestingErrorMessage', async () => {
            let exec_return

            beforeEach(async () => {
                exec_return = await storage.exec.call(
                    app_error_lib.address, instance_exec_id, error_with_message_calldata, { from: script_exec_addr }
                )

                let exec_events = await storage.exec(
                    app_error_lib.address, instance_exec_id, error_with_message_calldata, { from: script_exec_addr }
                ).should.be.fulfilled.then((tx) => {
                    return tx.logs;
                })

                exec_events.should.not.eq(null)
                exec_events.length.should.be.eq(1)

                app_exception_event = exec_events[0]

            })

            it('should have valid return data', async () => {
                exec_return.length.should.be.eq(3)
                exec_return[0].should.be.eq(false)
                exec_return[1].toNumber().should.be.eq(0)
                exec_return[2].should.be.eq('0x')
            })

            it('should emit an ApplicationException event', async () => {
                app_exception_event.should.not.eq(null)
                app_exception_event.event.should.be.eq('ApplicationException')
            })

            describe('ApplicationException event', async () => {
                it('should contain an indexed application address', async () => {
                    let event_application_addr = app_exception_event.args['application_address']
                    event_application_addr.should.not.eq(null)
                    event_application_addr.should.be.deep.eq(app_error_lib.address)
                })

                it('should contain an indexed execution id', async () => {
                    let event_exec_id = app_exception_event.args['execution_id']
                    event_exec_id.should.not.eq(null)
                    event_exec_id.should.be.deep.eq(instance_exec_id)
                })

                it('should contain a custom indexed error messsage', async () => {
                    let event_error_message = app_exception_event.args['message']
                    event_error_message.should.not.eq(null)
                    web3.toAscii(event_error_message).substring(
                      0,
                      'TestingErrorMessage'.length
                    ).should.be.deep.eq(custom_error)
                })
            })
        })
    })

    describe('#store', async () => {
        let app_storage_lib

        let instance_exec_id

        let store_single_calldata
        let store_multi_calldata
        let store_var_calldata
        let store_invalid_calldata

        let single_storage_loc = web3.sha3('single_storage');
        let multi_storage_loc = web3.sha3('multi_storage');
        let var_storage_loc = web3.sha3('variable_storage');

        beforeEach(async () => {
            store_single_calldata = await storage.mockGetStoreSingleCalldata(5).should.be.fulfilled
            store_multi_calldata = await storage.mockGetStoreMultiCalldata(6).should.be.fulfilled
            store_var_calldata = await storage.mockGetStoreVariableCalldata(3, 7).should.be.fulfilled
            store_invalid_calldata = await storage.mockGetStoreInvalidCalldata().should.be.fulfilled

            app_storage_lib = await ApplicationMockStorageLib.new().should.be.fulfilled

            instance_exec_id = await storage.initAndFinalize.call(
                app_updater_addr, false, appInit.address, appInitCalldata, [app_storage_lib.address], { from: script_exec_addr }
            ).should.be.fulfilled
            await storage.initAndFinalize(
                app_updater_addr, false, appInit.address, appInitCalldata, [app_storage_lib.address], { from: script_exec_addr }
            ).should.be.fulfilled
        })

        context('when the application stores to a single slot in storage', async () => {
            let app_exec_event

            let exec_return

            beforeEach(async () => {
                exec_return = await storage.exec.call(
                    app_storage_lib.address, instance_exec_id, store_single_calldata, { from: script_exec_addr }
                )

                let exec_events = await storage.exec(
                    app_storage_lib.address, instance_exec_id, store_single_calldata, { from: script_exec_addr }
                ).should.be.fulfilled.then((tx) => {
                    return tx.logs;
                })

                exec_events.should.not.eq(null)
                exec_events.length.should.be.eq(1)

                app_exec_event = exec_events[0]
            })

            it('should have valid return data', async () => {
                exec_return.length.should.be.eq(3)
                exec_return[0].should.be.eq(true)
                exec_return[1].toNumber().should.be.eq(1)
                exec_return[2].should.be.eq('0x')
            })

            it('should emit an ApplicationExecution event', async () => {
                app_exec_event.should.not.eq(null)
                app_exec_event.event.should.be.eq('ApplicationExecution')
            })

            describe('ApplicationExecution event', async () => {
                it('should contain an indexed execution id', async () => {
                    let event_exec_id = app_exec_event.args['execution_id']
                    event_exec_id.should.not.eq(null)
                    event_exec_id.should.be.deep.eq(instance_exec_id)
                })

                it('should contain an indexed target address', async () => {
                    let event_target_addr = app_exec_event.args['script_target']
                    event_target_addr.should.not.eq(null)
                    event_target_addr.should.be.deep.eq(app_storage_lib.address)
                })
            })

            it('should read the correct value from storage', async () => {
                let read_data = await storage.read.call(instance_exec_id, single_storage_loc)
                web3.toBigNumber(read_data).toNumber().should.be.eq(5)
            })
        })

        context('when the application stores to multiple slots in storage', async () => {
            let app_exec_event

            let exec_return

            beforeEach(async () => {
                exec_return = await storage.exec.call(
                    app_storage_lib.address, instance_exec_id, store_multi_calldata, { from: script_exec_addr }
                )

                let exec_events = await storage.exec(
                    app_storage_lib.address, instance_exec_id, store_multi_calldata, { from: script_exec_addr }
                ).should.be.fulfilled.then((tx) => {
                    return tx.logs;
                })

                exec_events.should.not.eq(null)
                exec_events.length.should.be.eq(1)

                app_exec_event = exec_events[0]
            })

            it('should have valid return data', async () => {
                exec_return.length.should.be.eq(3)
                exec_return[0].should.be.eq(true)
                exec_return[1].toNumber().should.be.eq(2)
                exec_return[2].should.be.eq('0x')
            })

            it('should emit an ApplicationExecution event', async () => {
                app_exec_event.should.not.eq(null)
                app_exec_event.event.should.be.eq('ApplicationExecution')
            })

            describe('ApplicationExecution event', async () => {
                it('should contain an indexed execution id', async () => {
                    let event_exec_id = app_exec_event.args['execution_id']
                    event_exec_id.should.not.eq(null)
                    event_exec_id.should.be.deep.eq(instance_exec_id)
                })

                it('should contain an indexed target address', async () => {
                    let event_target_addr = app_exec_event.args['script_target']
                    event_target_addr.should.not.eq(null)
                    event_target_addr.should.be.deep.eq(app_storage_lib.address)
                })
            })

            it('should read the correct values from storage', async () => {
                let second_storage_loc = await storage.addToBytes32.call(multi_storage_loc)
                let read_data = await storage.readMulti.call(
                    instance_exec_id, [
                        multi_storage_loc,
                        second_storage_loc
                    ]
                )
                read_data.length.should.be.eq(2)
                web3.toDecimal(read_data[0]).should.be.eq(6)
                web3.toDecimal(read_data[1]).should.be.eq(7)
            })
        })

        context('when the application stores to variable slots in storage', async () => {
            let app_exec_event

            let exec_return

            beforeEach(async () => {
                exec_return = await storage.exec.call(
                    app_storage_lib.address, instance_exec_id, store_var_calldata, { from: script_exec_addr }
                )

                let exec_events = await storage.exec(
                    app_storage_lib.address, instance_exec_id, store_var_calldata, { from: script_exec_addr }
                ).should.be.fulfilled.then((tx) => {
                    return tx.logs;
                })

                exec_events.should.not.eq(null)
                exec_events.length.should.be.eq(1)

                app_exec_event = exec_events[0]
            })

            it('should have valid return data', async () => {
                exec_return.length.should.be.eq(3)
                exec_return[0].should.be.eq(true)
                exec_return[1].toNumber().should.be.eq(3)
                exec_return[2].should.be.eq('0x')
            })

            it('should emit an ApplicationExecution event', async () => {
                app_exec_event.should.not.eq(null)
                app_exec_event.event.should.be.eq('ApplicationExecution')
            })

            describe('ApplicationExecution event', async () => {
                it('should contain an indexed execution id', async () => {
                    let event_exec_id = app_exec_event.args['execution_id']
                    event_exec_id.should.not.eq(null)
                    event_exec_id.should.be.deep.eq(instance_exec_id)
                })

                it('should contain an indexed target address', async () => {
                    let event_target_addr = app_exec_event.args['script_target']
                    event_target_addr.should.not.eq(null)
                    event_target_addr.should.be.deep.eq(app_storage_lib.address)
                })
            })

            it('should read the correct values from storage', async () => {
                let second_storage_loc = await storage.addToBytes32.call(var_storage_loc)
                let third_storage_loc = await storage.addToBytes32.call(second_storage_loc)
                let read_data = await storage.readMulti.call(
                    instance_exec_id, [
                        var_storage_loc,
                        second_storage_loc,
                        third_storage_loc
                    ]
                )
                read_data.length.should.be.eq(3)
                web3.toDecimal(read_data[0]).should.be.eq(7)
                web3.toDecimal(read_data[1]).should.be.eq(8)
                web3.toDecimal(read_data[2]).should.be.eq(9)
            })
        })

        context('when the application returns an invalid storage request', async () => {

            it('should not allow execution', async () => {
                await storage.exec(
                  app_storage_lib.address,
                  instance_exec_id,
                  store_invalid_calldata,
                  { from: script_exec_addr }
                ).should.not.be.fulfilled
            })
        })
    })

    describe('#changeInitAddr', async () => {
        let instance_exec_id
        let new_app_init

        beforeEach(async() => {
            instance_exec_id = await storage.initAndFinalize.call(
                app_updater_addr, false, appInit.address, appInitCalldata, [app_func_lib.address], { from: script_exec_addr }
            ).should.be.fulfilled
            await storage.initAndFinalize(
                app_updater_addr, false, appInit.address, appInitCalldata, [app_func_lib.address], { from: script_exec_addr }
            ).should.be.fulfilled

            new_app_init = await ApplicationMockInit.new().should.be.fulfilled
            new_app_init.should.not.eq(null)
        })

        context('when the app is paused', async () => {
            beforeEach(async () => {
                await storage.pauseAppInstance(instance_exec_id, { from: app_updater_addr }).should.be.fulfilled
            })

            context('when the sender is the updater address', async () => {
                beforeEach(async () => {
                    await storage.changeInitAddr(instance_exec_id, new_app_init.address, { from: app_updater_addr }).should.be.fulfilled
                })

                it('should update the app init address', async () => {
                    let stored_init =  await storage.app_info(instance_exec_id).should.be.fulfilled
                    stored_init[0].should.be.eq(true)
                    stored_init[5].should.not.eq(0)
                    stored_init[5].should.not.eq(appInit.address)
                    stored_init[5].should.be.eq(new_app_init.address)
                })
            })

            context('when the sender is not the updater address', async () => {
                beforeEach(async () => {
                    await storage.changeInitAddr(instance_exec_id, new_app_init.address, { from: non_updater_addr }).should.not.be.fulfilled
                })

                it('should not update the app init address', async () => {
                    let stored_init =  await storage.app_info(instance_exec_id).should.be.fulfilled
                    stored_init[0].should.be.eq(true)
                    stored_init[5].should.not.eq(0)
                    stored_init[5].should.be.eq(appInit.address)
                    stored_init[5].should.not.eq(new_app_init.address)
                })
            })
        })

        context('when the app is unpaused', async () => {
            beforeEach(async () => {
                await storage.unpauseAppInstance(instance_exec_id, { from: app_updater_addr })
            })

            context('when the sender is the updater address', async () => {
                beforeEach(async () => {
                    await storage.changeInitAddr(instance_exec_id, new_app_init.address, { from: app_updater_addr }).should.not.be.fulfilled
                })

                it('should not update the app init address', async () => {
                    let stored_init =  await storage.app_info(instance_exec_id).should.be.fulfilled
                    stored_init[0].should.be.eq(false)
                    stored_init[5].should.not.eq(0)
                    stored_init[5].should.be.eq(appInit.address)
                    stored_init[5].should.not.eq(new_app_init.address)
                })
            })

            context('when the sender is not the updater address', async () => {
                beforeEach(async () => {
                    await storage.changeInitAddr(instance_exec_id, new_app_init.address, { from: non_updater_addr }).should.not.be.fulfilled
                })

                it('should not update the app init address', async () => {
                    let stored_init =  await storage.app_info(instance_exec_id).should.be.fulfilled
                    stored_init[0].should.be.eq(false)
                    stored_init[5].should.not.eq(0)
                    stored_init[5].should.be.eq(appInit.address)
                    stored_init[5].should.not.eq(new_app_init.address)
                })
            })
        })
    })

    describe('#changeScriptExec', async () => {
        let instance_exec_id
        let new_script_exec_addr = accounts[2]

        beforeEach(async () => {
            instance_exec_id = await storage.initAndFinalize.call(
                app_updater_addr, false, appInit.address, appInitCalldata, [app_func_lib.address], { from: script_exec_addr }
            ).should.be.fulfilled
            await storage.initAndFinalize(
                app_updater_addr, false, appInit.address, appInitCalldata, [app_func_lib.address], { from: script_exec_addr }
            ).should.be.fulfilled
        })

        context('sender is the script exec address', async () => {
            beforeEach(async () => {
                await storage.changeScriptExec(instance_exec_id, new_script_exec_addr, { from: script_exec_addr }).should.be.fulfilled
            })

            it('should modify a script exec address', async () => {
                let stored_exec_addr = await storage.app_info(instance_exec_id).should.be.fulfilled
                stored_exec_addr[4].should.be.eq(new_script_exec_addr)
            })

            it('should allow the new script exec address to change the script exec address', async () => {
                await storage.changeScriptExec(instance_exec_id, accounts[3], { from: new_script_exec_addr }).should.be.fulfilled
                let stored_exec_addr = await storage.app_info(instance_exec_id).should.be.fulfilled
                stored_exec_addr[4].should.be.eq(accounts[3])
            })
        })

        context('sender is not the script exec address', async () => {
            beforeEach(async () => {
                await storage.changeScriptExec(instance_exec_id, new_script_exec_addr, { from: non_script_exec }).should.not.be.fulfilled
            })

            it('should not modify a script exec address', async () => {
                let stored_exec_addr = await storage.app_info(instance_exec_id).should.be.fulfilled
                stored_exec_addr[4].should.not.be.eq(new_script_exec_addr)
            })

            it('should not allow the new script exec address to change the script exec address', async () => {
                await storage.changeScriptExec(instance_exec_id, accounts[3], { from: new_script_exec_addr }).should.not.be.fulfilled
                let stored_exec_addr = await storage.app_info(instance_exec_id).should.be.fulfilled
                stored_exec_addr[4].should.not.be.eq(accounts[3])
            })
        })
    })

    describe('#pauseAppInstance', async () => {
        let instance_exec_id

        beforeEach(async() => {
            instance_exec_id = await storage.initAndFinalize.call(
                app_updater_addr, false, appInit.address, appInitCalldata, [app_func_lib.address], { from: script_exec_addr }
            ).should.be.fulfilled
            await storage.initAndFinalize(
                app_updater_addr, false, appInit.address, appInitCalldata, [app_func_lib.address], { from: script_exec_addr }
            ).should.be.fulfilled
        })

        context('when the sender is the updater address', async () => {
            beforeEach(async () => {
                await storage.pauseAppInstance(instance_exec_id, { from: app_updater_addr }).should.be.fulfilled
            })

            it('should allow the sender to pause the application', async () => {
                let application_info = await storage.app_info(instance_exec_id).should.be.fulfilled
                application_info[0].should.be.eq(true)
                application_info[1].should.be.eq(true)
                application_info[2].should.be.eq(false)
                application_info[3].should.be.eq(app_updater_addr)
                application_info[4].should.be.eq(script_exec_addr)
                application_info[5].should.be.eq(appInit.address)
            })

            it('should not allow the script exec contract to access "exec" for the paused exec id', async () => {
                await storage.exec(app_func_lib.address, instance_exec_id, app_func_calldata, { from: script_exec_addr }).should.not.be.fulfilled
            })
        })

        context('when the sender is not the updater address', async () => {
            beforeEach(async () => {
                await storage.pauseAppInstance(instance_exec_id, { from: non_updater_addr }).should.not.be.fulfilled
            })

            it('should not allow the sender to pause the application', async () => {
                let application_info = await storage.app_info(instance_exec_id).should.be.fulfilled
                application_info[0].should.be.eq(false)
                application_info[1].should.be.eq(true)
                application_info[2].should.be.eq(false)
                application_info[3].should.be.eq(app_updater_addr)
                application_info[4].should.be.eq(script_exec_addr)
                application_info[5].should.be.eq(appInit.address)
            })

          it('should allow the script exec address to execute the application', async () => {
              await storage.exec(app_func_lib.address, instance_exec_id, app_func_calldata, { from: script_exec_addr }).should.be.fulfilled
          })
        })
    })

    describe('#unpauseAppInstance', async () => {
        let instance_exec_id

        beforeEach(async () => {
            instance_exec_id = await storage.initAndFinalize.call(
                app_updater_addr, false, appInit.address, appInitCalldata, [app_func_lib.address], { from: script_exec_addr }
            ).should.be.fulfilled
            await storage.initAndFinalize(
                app_updater_addr, false, appInit.address, appInitCalldata, [app_func_lib.address], { from: script_exec_addr }
            ).should.be.fulfilled

            await storage.pauseAppInstance(instance_exec_id, { from: app_updater_addr }).should.be.fulfilled
            await storage.exec(app_func_lib.address, instance_exec_id, app_func_calldata, { from: script_exec_addr }).should.not.be.fulfilled
        })

        context('when the sender is the updater address', async () => {
            beforeEach(async () => {
                await storage.unpauseAppInstance(instance_exec_id, { from: app_updater_addr }).should.be.fulfilled
            })

            it('should allow the sender to unpause the application', async () => {
                let application_info = await storage.app_info(instance_exec_id).should.be.fulfilled
                application_info[0].should.be.eq(false)
                application_info[1].should.be.eq(true)
                application_info[2].should.be.eq(false)
                application_info[3].should.be.eq(app_updater_addr)
                application_info[4].should.be.eq(script_exec_addr)
                application_info[5].should.be.eq(appInit.address)
            })

            it('should allow the script exec address to execute the application', async () => {
                await storage.exec(app_func_lib.address, instance_exec_id, app_func_calldata, { from: script_exec_addr }).should.be.fulfilled
            })
        })

        context('when the sender is not the updater address', async () => {
            beforeEach(async () => {
                await storage.unpauseAppInstance(instance_exec_id, { from: non_updater_addr }).should.not.be.fulfilled
            })

            it('should not allow the sender to unpause the application', async () => {
                let application_info = await storage.app_info(instance_exec_id).should.be.fulfilled
                application_info[0].should.be.eq(true)
                application_info[1].should.be.eq(true)
                application_info[2].should.be.eq(false)
                application_info[3].should.be.eq(app_updater_addr)
                application_info[4].should.be.eq(script_exec_addr)
                application_info[5].should.be.eq(appInit.address)
            })

            it('should not allow the script exec address to execute the application', async () => {
                await storage.exec(app_func_lib.address, instance_exec_id, app_func_calldata, { from: script_exec_addr }).should.not.be.fulfilled
            })
        })

    })

    describe('#addAllowed', async () => {
        let instance_exec_id
        let app_func_lib_a
        let app_func_lib_b
        let app_func_lib_c

        beforeEach(async () => {
            instance_exec_id = await storage.initAndFinalize.call(
                app_updater_addr, false, appInit.address, appInitCalldata, [app_func_lib.address], { from: script_exec_addr }
            ).should.be.fulfilled
            await storage.initAndFinalize(
                app_updater_addr, false, appInit.address, appInitCalldata, [app_func_lib.address], { from: script_exec_addr }
            ).should.be.fulfilled

            app_func_lib_a = await ApplicationFuncLib.new().should.be.fulfilled
            app_func_lib_b = await ApplicationFuncLib.new().should.be.fulfilled
            app_func_lib_c = await ApplicationFuncLib.new().should.be.fulfilled
        })

        context('app is paused', async () => {

            beforeEach(async () => {
                await storage.pauseAppInstance(instance_exec_id, { from: app_updater_addr }).should.be.fulfilled
            })

            context('sender is updater address', async () => {
                beforeEach(async () => {
                    await storage.addAllowed(
                        instance_exec_id, [
                          app_func_lib_a.address,
                          app_func_lib_b.address,
                          app_func_lib_c.address
                        ], { from: app_updater_addr }
                    ).should.be.fulfilled
                })

                it('should allow addresses to be added', async () => {
                    let allowed_addrs = await storage.getExecAllowed(instance_exec_id).should.be.fulfilled
                    let app_struct = await storage.app_info(instance_exec_id).should.be.fulfilled
                    app_struct[0].should.be.eq(true)
                    allowed_addrs.length.should.be.eq(4)
                    allowed_addrs[0].should.be.eq(app_func_lib.address)
                    allowed_addrs[1].should.be.eq(app_func_lib_a.address)
                    allowed_addrs[2].should.be.eq(app_func_lib_b.address)
                    allowed_addrs[3].should.be.eq(app_func_lib_c.address)
                })
            })

            context('sender is not updater address', async () => {
                beforeEach(async () => {
                    await storage.addAllowed(
                        instance_exec_id, [
                          app_func_lib_a.address,
                          app_func_lib_b.address,
                          app_func_lib_c.address
                        ], { from: non_updater_addr }
                    ).should.not.be.fulfilled
                })

                it('should not allow addresses to be added', async () => {
                    let allowed_addrs = await storage.getExecAllowed(instance_exec_id).should.be.fulfilled
                    let app_struct = await storage.app_info(instance_exec_id).should.be.fulfilled
                    app_struct[0].should.be.eq(true)
                    allowed_addrs.length.should.be.eq(1)
                    allowed_addrs[0].should.be.eq(app_func_lib.address)
                })
            })
        })

        context('app is not paused', async () => {

            beforeEach(async () => {
                await storage.unpauseAppInstance(instance_exec_id, { from: app_updater_addr })
            })

            context('sender is updater address', async () => {
                beforeEach(async () => {
                    await storage.addAllowed(
                        instance_exec_id, [
                          app_func_lib_a.address,
                          app_func_lib_b.address,
                          app_func_lib_c.address
                        ], { from: app_updater_addr }
                    ).should.not.be.fulfilled
                })

                it('should not allow addresses to be added', async () => {
                    let allowed_addrs = await storage.getExecAllowed(instance_exec_id).should.be.fulfilled
                    let app_struct = await storage.app_info(instance_exec_id).should.be.fulfilled
                    app_struct[0].should.be.eq(false)
                    allowed_addrs.length.should.be.eq(1)
                    allowed_addrs[0].should.be.eq(app_func_lib.address)
                })
            })

            context('sender is not updater address', async () => {
                beforeEach(async () => {
                    await storage.addAllowed(
                        instance_exec_id, [
                          app_func_lib_a.address,
                          app_func_lib_b.address,
                          app_func_lib_c.address
                        ], { from: non_updater_addr }
                    ).should.not.be.fulfilled
                })

                it('should not allow addresses to be added', async () => {
                    let allowed_addrs = await storage.getExecAllowed(instance_exec_id).should.be.fulfilled
                    let app_struct = await storage.app_info(instance_exec_id).should.be.fulfilled
                    app_struct[0].should.be.eq(false)
                    allowed_addrs.length.should.be.eq(1)
                    allowed_addrs[0].should.be.eq(app_func_lib.address)
                })
            })
        })
    })

    describe('#removeAllowed', async () => {
        let instance_exec_id
        let app_func_lib_a
        let app_func_lib_b
        let app_func_lib_c

        beforeEach(async () => {
            app_func_lib_a = await ApplicationFuncLib.new().should.be.fulfilled
            app_func_lib_b = await ApplicationFuncLib.new().should.be.fulfilled
            app_func_lib_c = await ApplicationFuncLib.new().should.be.fulfilled

            instance_exec_id = await storage.initAndFinalize.call(
                app_updater_addr, false, appInit.address, appInitCalldata, [
                    app_func_lib.address,
                    app_func_lib_a.address,
                    app_func_lib_b.address,
                    app_func_lib_c.address
                ], { from: script_exec_addr }
            ).should.be.fulfilled
            await storage.initAndFinalize(
                app_updater_addr, false, appInit.address, appInitCalldata, [
                    app_func_lib.address,
                    app_func_lib_a.address,
                    app_func_lib_b.address,
                    app_func_lib_c.address
                ], { from: script_exec_addr }
            ).should.be.fulfilled

            let num_addrs = await storage.getExecAllowed(instance_exec_id).should.be.fulfilled
            num_addrs.length.should.be.eq(4)
        })

        context('app is paused', async () => {

            beforeEach(async () => {
                await storage.pauseAppInstance(instance_exec_id, { from: app_updater_addr }).should.be.fulfilled
            })

            context('sender is updater address', async () => {
                beforeEach(async () => {
                    await storage.removeAllowed(
                        instance_exec_id, [
                            app_func_lib_a.address,
                            app_func_lib_b.address,
                            app_func_lib_c.address
                        ], { from: app_updater_addr }
                    ).should.be.fulfilled
                })

                it('should allow addresses to be removed', async () => {
                    let allowed_addrs = await storage.getExecAllowed(instance_exec_id).should.be.fulfilled
                    let app_struct = await storage.app_info(instance_exec_id).should.be.fulfilled
                    app_struct[0].should.be.eq(true)
                    allowed_addrs.length.should.be.eq(1)
                    allowed_addrs[0].should.be.eq(app_func_lib.address)
                })
            })

            context('sender is not updater address', async () => {
                beforeEach(async () => {
                    await storage.removeAllowed(
                        instance_exec_id, [
                          app_func_lib_a.address,
                          app_func_lib_b.address,
                          app_func_lib_c.address
                        ], { from: non_updater_addr }
                    ).should.not.be.fulfilled
                })

                it('should not allow addresses to be removed', async () => {
                    let allowed_addrs = await storage.getExecAllowed(instance_exec_id).should.be.fulfilled
                    let app_struct = await storage.app_info(instance_exec_id).should.be.fulfilled
                    app_struct[0].should.be.eq(true)
                    allowed_addrs.length.should.be.eq(4)
                    allowed_addrs[0].should.be.eq(app_func_lib.address)
                    allowed_addrs[1].should.be.eq(app_func_lib_a.address)
                    allowed_addrs[2].should.be.eq(app_func_lib_b.address)
                    allowed_addrs[3].should.be.eq(app_func_lib_c.address)
                })
            })
        })

        context('app is not paused', async () => {

            beforeEach(async () => {
                await storage.unpauseAppInstance(instance_exec_id, { from: app_updater_addr })
            })

            context('sender is updater address', async () => {
                beforeEach(async () => {
                    await storage.removeAllowed(
                        instance_exec_id, [
                          app_func_lib_a.address,
                          app_func_lib_b.address,
                          app_func_lib_c.address
                        ], { from: app_updater_addr }
                    ).should.not.be.fulfilled
                })

                it('should not allow addresses to be removed', async () => {
                    let allowed_addrs = await storage.getExecAllowed(instance_exec_id).should.be.fulfilled
                    let app_struct = await storage.app_info(instance_exec_id).should.be.fulfilled
                    app_struct[0].should.be.eq(false)
                    allowed_addrs.length.should.be.eq(4)
                    allowed_addrs[0].should.be.eq(app_func_lib.address)
                    allowed_addrs[1].should.be.eq(app_func_lib_a.address)
                    allowed_addrs[2].should.be.eq(app_func_lib_b.address)
                    allowed_addrs[3].should.be.eq(app_func_lib_c.address)
                })
            })

            context('sender is not updater address', async () => {
                beforeEach(async () => {
                    await storage.removeAllowed(
                        instance_exec_id, [
                          app_func_lib_a.address,
                          app_func_lib_b.address,
                          app_func_lib_c.address
                        ], { from: non_updater_addr }
                    ).should.not.be.fulfilled
                })

                it('should not allow addresses to be removed', async () => {
                    let allowed_addrs = await storage.getExecAllowed(instance_exec_id).should.be.fulfilled
                    let app_struct = await storage.app_info(instance_exec_id).should.be.fulfilled
                    app_struct[0].should.be.eq(false)
                    allowed_addrs.length.should.be.eq(4)
                    allowed_addrs[0].should.be.eq(app_func_lib.address)
                    allowed_addrs[1].should.be.eq(app_func_lib_a.address)
                    allowed_addrs[2].should.be.eq(app_func_lib_b.address)
                    allowed_addrs[3].should.be.eq(app_func_lib_c.address)
                })
            })
        })
    })

    describe('#withdraw', async () => {
        beforeEach(async () => {
            storage = await AbstractStorage.new().should.be.fulfilled
        })

        context('contract has nonzero balance', async () => {
            let force_send_ether
            let storage_balance

            beforeEach(async () => {
                force_send_ether = await ForceSendEther.new().should.be.fulfilled
                await force_send_ether.forcePay(storage.address, { value: web3.toWei('1','ether'), from: accounts[0] }).should.be.fulfilled
            })

            it('should withdraw to the calling address', async () => {
                let sender_balance = await web3.eth.getBalance(accounts[1]).toNumber()
                await storage.withdraw({ from: accounts[1] })
                let sender_updated_balance = await web3.eth.getBalance(accounts[1]).toNumber()
                sender_updated_balance.should.be.above(sender_balance)
            })
        })

        context('contract has zero balance', async () => {
            let force_send_ether
            let storage_balance

            beforeEach(async () => {
                force_send_ether = await ForceSendEther.new().should.be.fulfilled
                await force_send_ether.forcePay(storage.address, { from: accounts[0] }).should.be.fulfilled
                storage_balance = await web3.eth.getBalance(storage.address).toNumber()
                storage_balance.should.be.eq(0)
                // web3.toWei(storage_balance).should.be.eq(web3.toWei('0','ether'))
            })

            it('should not withdraw to the calling address', async () => {
                let sender_balance = await web3.eth.getBalance(accounts[1]).toNumber()
                await storage.withdraw({ from: accounts[1] })
                let sender_updated_balance = await web3.eth.getBalance(accounts[1]).toNumber()
                sender_updated_balance.should.not.eq(0)
                sender_updated_balance.should.be.below(sender_balance)
            })
        })
    })
})
