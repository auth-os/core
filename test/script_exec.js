// let AbstractStorage = artifacts.require('./AbstractStorage')
// let ScriptExec = artifacts.require('./ScriptExec')
// // Script Registry
// let InitRegistry = artifacts.require('./InitRegistry')
// let AppConsole = artifacts.require('./AppConsole')
// let VersionConsole = artifacts.require('./VersionConsole')
// let ImplConsole = artifacts.require('./ImplementationConsole')
// // Mock
// let AppInitMock = artifacts.require('./mock/AppInitMock')
// let PayableApp = artifacts.require('./mock/scriptExec/PayableAppContext')
// let StdApp = artifacts.require('./mock/scriptExec/StdAppContext')
// let EmitsApp = artifacts.require('./mock/scriptExec/EmitsAppContext')
// let MixedApp = artifacts.require('./mock/scriptExec/MixedAppContext')
// let InvalidApp = artifacts.require('./mock/scriptExec/InvalidAppContext')
// let RevertApp = artifacts.require('./mock/scriptExec/RevertAppContext')
// // Util
// let TestUtils = artifacts.require('./util/TestUtils')
// let RegistryUtils = artifacts.require('./RegistryUtil')
// let AppInitUtil = artifacts.require('./util/AppInitUtil')
// let AppMockUtil = artifacts.require('./util/scriptExec/AppMockUtilContext')
//
// function getTime() {
//   let block = web3.eth.getBlock('latest')
//   return block.timestamp;
// }
//
// function zeroAddress() {
//   return web3.toHex(0)
// }
//
// function hexStrEquals(hex, expected) {
//   return web3.toAscii(hex).substring(0, expected.length) == expected;
// }
//
// function sendBalanceTo(_from, _to) {
//   let bal = web3.eth.getBalance(_from).toNumber()
//   web3.eth.sendTransaction({ from: _from, to: _to, value: bal, gasPrice: 0 })
// }
//
// contract('ScriptExec', function (accounts) {
//
//   let storage
//   let scriptExec
//
//   let execAdmin = accounts[0]
//   let updater = accounts[1]
//   let provider = accounts[2]
//   let registryExecID
//   let providerID
//   let testUtils
//
//   let sender = accounts[3]
//   let senderContext
//
//   // PayableApp
//   let payees = [accounts[4], accounts[5]]
//   let payouts = [111, 222]
//   // StdApp
//   let storageLocations = [web3.toHex('AA'), web3.toHex('BB')]
//   let storageValues = ['CC', 'DD']
//   // EmitsApp
//   let emitTopics = ['aaaaa', 'bbbbbb', 'ccccc', 'ddddd']
//   let emitData1 = 'tiny'
//   let emitData2 = 'much much much much much much much much larger'
//   // RevertApp
//   let revertMessage = 'appreverted'
//   let throwMessage = 'this application threw'
//
//   let otherAddr = accounts[accounts.length - 1]
//
//   // Event signatures
//   let initHash = web3.sha3('ApplicationInitialized(bytes32,address,address,address)')
//   let finalHash = web3.sha3('ApplicationFinalization(bytes32,address)')
//   let execHash = web3.sha3('ApplicationExecution(bytes32,address)')
//   let payHash = web3.sha3('DeliveredPayment(bytes32,address,uint256)')
//   let appExceptHash = web3.sha3('ApplicationException(address,bytes32,bytes)')
//   let storageExceptHash = web3.sha3('StorageException(address,bytes32,address,uint256)')
//   let appInstanceCreatedHash = web3.sha3('AppInstanceCreated(address,bytes32,address,bytes32,bytes32)')
//
//   let appInit
//   let appInitUtil
//
//   let initCalldata
//
//   let appMockUtil
//   let payableApp
//   let stdApp
//   let emitApp
//   let mixApp
//   let invalidApp
//   let revertApp
//
//   let allowedAddrs
//
//   let registryUtil
//   let initRegistry
//   let appConsole
//   let versionConsole
//   let implConsole
//
//   let registryAllowed
//
//   before(async () => {
//     storage = await AbstractStorage.new().should.be.fulfilled
//
//     appInit = await AppInitMock.new().should.be.fulfilled
//     appInitUtil = await AppInitUtil.new().should.be.fulfilled
//     testUtils = await TestUtils.new().should.be.fulfilled
//
//     providerID = await testUtils.getAppProviderHash.call(provider)
//     providerID.should.not.eq('0x')
//
//     appMockUtil = await AppMockUtil.new().should.be.fulfilled
//     payableApp = await PayableApp.new().should.be.fulfilled
//     stdApp = await StdApp.new().should.be.fulfilled
//     emitApp = await EmitsApp.new().should.be.fulfilled
//     mixApp = await MixedApp.new().should.be.fulfilled
//     invalidApp = await InvalidApp.new().should.be.fulfilled
//     revertApp = await RevertApp.new().should.be.fulfilled
//
//     initCalldata = await appInitUtil.init.call().should.be.fulfilled
//     initCalldata.should.not.eq('0x0')
//
//     allowedAddrs = [
//       stdApp.address,
//       payableApp.address,
//       emitApp.address,
//       mixApp.address,
//       invalidApp.address,
//       revertApp.address
//     ]
//
//     registryUtil = await RegistryUtils.new().should.be.fulfilled
//     initRegistry = await InitRegistry.new().should.be.fulfilled
//     appConsole = await AppConsole.new().should.be.fulfilled
//     versionConsole = await VersionConsole.new().should.be.fulfilled
//     implConsole = await ImplConsole.new().should.be.fulfilled
//
//     registryAllowed = [
//       appConsole.address, versionConsole.address, implConsole.address
//     ]
//   })
//
//   beforeEach(async () => {
//     scriptExec = await ScriptExec.new(
//       execAdmin, updater, storage.address, providerID,
//       { from: execAdmin }
//     ).should.be.fulfilled
//   })
//
//   describe('#constructor', async () => {
//
//     let testExec
//
//     context('when no exec admin is passed-in', async () => {
//
//       beforeEach(async () => {
//         testExec = await ScriptExec.new(
//           zeroAddress(), updater, storage.address, providerID,
//           { from: execAdmin }
//         ).should.be.fulfilled
//       })
//
//       it('should set the exec admin address as the sender', async () => {
//         let adminInfo = await testExec.exec_admin.call()
//         adminInfo.should.be.eq(execAdmin)
//       })
//
//       it('should correctly set other initial data', async () => {
//         let updaterInfo = await testExec.default_updater.call()
//         updaterInfo.should.be.eq(updater)
//         let storageInfo = await testExec.default_storage.call()
//         storageInfo.should.be.eq(storage.address)
//         let providerInfo = await testExec.default_provider.call()
//         providerInfo.should.be.eq(providerID)
//       })
//     })
//
//     context('when an exec admin is passed-in', async () => {
//
//       beforeEach(async () => {
//         testExec = await ScriptExec.new(
//           execAdmin, updater, storage.address, providerID,
//           { from: execAdmin }
//         ).should.be.fulfilled
//       })
//
//       it('should set the exec admin address as the passed-in address', async () => {
//         let adminInfo = await testExec.exec_admin.call()
//         adminInfo.should.be.eq(execAdmin)
//       })
//
//       it('should correctly set other initial data', async () => {
//         let updaterInfo = await testExec.default_updater.call()
//         updaterInfo.should.be.eq(updater)
//         let storageInfo = await testExec.default_storage.call()
//         storageInfo.should.be.eq(storage.address)
//         let providerInfo = await testExec.default_provider.call()
//         providerInfo.should.be.eq(providerID)
//       })
//     })
//   })
//
//   describe('#exec - payable', async () => {
//
//     let executionID
//     let target
//     let expectedStatus
//
//     beforeEach(async () => {
//       let events = await storage.initAndFinalize(
//         updater, true, appInit.address, initCalldata, allowedAddrs,
//         { from: execAdmin }
//       ).should.be.fulfilled.then((tx) => {
//         return tx.logs
//       })
//       events.should.not.eq(null)
//       events.length.should.be.eq(2)
//       events[0].event.should.be.eq('ApplicationInitialized')
//       events[1].event.should.be.eq('ApplicationFinalization')
//       executionID = events[0].args['execution_id']
//       web3.toDecimal(executionID).should.not.eq(0)
//
//       await storage.changeScriptExec(
//         executionID, scriptExec.address, { from: execAdmin }
//       ).should.be.fulfilled
//
//       senderContext = await testUtils.getContextFromAddr.call(
//         executionID, sender, 0
//       ).should.be.fulfilled
//       senderContext.should.not.eq('0x0')
//     })
//
//     describe('basic app info', async () => {
//
//       it('should correctly set the script exec to the deployed contract', async () => {
//         let appInfo = await storage.app_info.call(executionID)
//         appInfo[0].should.be.eq(false)
//         appInfo[1].should.be.eq(true)
//         appInfo[2].should.be.eq(true)
//         appInfo[3].should.be.eq(updater)
//         appInfo[4].should.be.eq(scriptExec.address)
//         appInfo[5].should.be.eq(appInit.address)
//       })
//     })
//
//     describe('invalid inputs or invalid state', async () => {
//
//       let calldata
//
//       beforeEach(async () => {
//         target = stdApp.address
//
//         calldata = await testUtils.getContextFromAddr(
//           executionID, sender, 0
//         ).should.be.fulfilled
//         calldata.should.not.eq('0x0')
//       })
//
//       context('sender passes in incorrect address with context', async () => {
//
//         let invalidContext
//         let invalidCalldata
//
//         beforeEach(async () => {
//           invalidContext = await testUtils.getContextFromAddr.call(
//             executionID, otherAddr, 0
//           ).should.be.fulfilled
//           invalidContext.should.not.eq('0x0')
//
//           invalidCalldata = await appMockUtil.std1.call(
//             storageLocations[0], storageValues[0], invalidContext
//           ).should.be.fulfilled
//           invalidCalldata.should.not.eq('0x0')
//         })
//
//         it('should throw', async () => {
//           await scriptExec.exec(
//             target, invalidCalldata,
//             { from: sender }
//           ).should.not.be.fulfilled
//         })
//       })
//
//       context('sender passes in incorrect wei amount with context', async () => {
//
//         let invalidContext
//         let invalidCalldata
//
//         beforeEach(async () => {
//           invalidContext = await testUtils.getContextFromAddr.call(
//             executionID, sender, 1
//           ).should.be.fulfilled
//           invalidContext.should.not.eq('0x0')
//
//           invalidCalldata = await appMockUtil.std1.call(
//             storageLocations[0], storageValues[0], invalidContext
//           ).should.be.fulfilled
//           invalidCalldata.should.not.eq('0x0')
//         })
//
//         it('should throw', async () => {
//           await scriptExec.exec(
//             target, invalidCalldata,
//             { from: sender }
//           ).should.not.be.fulfilled
//         })
//       })
//
//       context('target address is 0', async () => {
//
//         it('should throw', async () => {
//           await scriptExec.exec(
//             zeroAddress(), calldata,
//             { from: sender }
//           ).should.not.be.fulfilled
//         })
//       })
//
//       context('exec id is 0', async () => {
//
//         let invalidExecID = web3.toHex(0)
//         let invalidContext
//         let invalidCalldata
//
//         beforeEach(async () => {
//           invalidContext = await testUtils.getContextFromAddr.call(
//             invalidExecID, sender, 0
//           ).should.be.fulfilled
//           invalidContext.should.not.eq('0x0')
//
//           invalidCalldata = await appMockUtil.std1.call(
//             storageLocations[0], storageValues[0], invalidContext
//           ).should.be.fulfilled
//           calldata.should.not.be.eq('0x0')
//         })
//
//         it('should throw', async () => {
//           await scriptExec.exec(
//             target, invalidCalldata,
//             { from: sender }
//           ).should.not.be.fulfilled
//         })
//       })
//
//       context('script target not in exec id allowed list', async () => {
//
//         let invalidTarget
//
//         beforeEach(async () => {
//           invalidTarget = await StdApp.new().should.be.fulfilled
//         })
//
//         it('should throw', async () => {
//           await scriptExec.exec(
//             invalidTarget.address, calldata,
//             { from: sender }
//           ).should.not.be.fulfilled
//         })
//       })
//
//       context('app is paused', async () => {
//
//         beforeEach(async () => {
//           await storage.pauseAppInstance(executionID, { from: updater }).should.be.fulfilled
//           let appInfo = await storage.app_info.call(executionID)
//           appInfo[0].should.be.eq(true)
//         })
//
//         it('should throw', async () => {
//           await scriptExec.exec(
//             target, calldata,
//             { from: sender }
//           ).should.not.be.fulfilled
//         })
//       })
//     })
//
//     describe('RevertApp (app reverts)', async () => {
//
//       let revertEvents
//       let revertReturn
//
//       beforeEach(async () => {
//         target = revertApp.address
//         expectedStatus = false
//       })
//
//       describe('function did not exist', async () => {
//
//         let invalidCalldata
//
//         beforeEach(async () => {
//           invalidCalldata = await appMockUtil.rev0.call(senderContext)
//           invalidCalldata.should.not.eq('0x0')
//
//           revertReturn = await scriptExec.exec.call(
//             target, invalidCalldata,
//             { from: sender }
//           ).should.be.fulfilled
//
//           revertEvents = await scriptExec.exec(
//             target, invalidCalldata,
//             { from: sender }
//           ).should.be.fulfilled.then((tx) => {
//             return tx.receipt.logs
//           })
//         })
//
//         describe('returned data', async () => {
//
//           it('should return the expected status', async () => {
//             revertReturn.should.be.eq(expectedStatus)
//           })
//         })
//
//         describe('events', async () => {
//
//           it('should have emitted 2 events total', async () => {
//             revertEvents.length.should.be.eq(2)
//           })
//
//           describe('the StorageException event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = revertEvents[1].topics
//               eventData = revertEvents[1].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(3)
//             })
//
//             it('should list the correct event signature in the first topic', async () => {
//               let sig = eventTopics[0]
//               web3.toDecimal(sig).should.be.eq(web3.toDecimal(storageExceptHash))
//             })
//
//             it('should have the storage address and execution id as the other 2 topics', async () => {
//               let emittedAddr = eventTopics[1]
//               let emittedExecId = eventTopics[2]
//               web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(storage.address))
//               web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(executionID))
//             })
//
//             it('should have the sender and wei sent as data', async () => {
//               let parsedData = await testUtils.parseStorageExceptionData.call(eventData).should.be.fulfilled
//               parsedData.length.should.be.eq(2)
//               parsedData[0].should.be.eq(sender)
//               parsedData[1].toNumber().should.be.eq(0)
//             })
//           })
//
//           describe('the ApplicationException event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = revertEvents[0].topics
//               eventData = revertEvents[0].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(3)
//             })
//
//             it('should list the correct event signature in the first topic', async () => {
//               let sig = eventTopics[0]
//               web3.toDecimal(sig).should.be.eq(web3.toDecimal(appExceptHash))
//             })
//
//             it('should have the target address and execution id as the other 2 topics', async () => {
//               let emittedAddr = eventTopics[1]
//               let emittedExecId = eventTopics[2]
//               web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(target))
//               web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(executionID))
//             })
//
//             it('should have data containing the message \'DefaultException\'', async () => {
//               eventData.length.should.be.eq(194)
//               let message = eventData.substring(130, 194)
//               hexStrEquals(message, 'DefaultException').should.be.eq(true, web3.toAscii(message))
//             })
//           })
//         })
//       })
//
//       describe('reverts with no message', async () => {
//
//         beforeEach(async () => {
//           let revertCalldata = await appMockUtil.rev1.call(senderContext)
//           revertCalldata.should.not.eq('0x0')
//
//           revertReturn = await scriptExec.exec.call(
//             target, revertCalldata,
//             { from: sender }
//           ).should.be.fulfilled
//
//           revertEvents = await scriptExec.exec(
//             target, revertCalldata,
//             { from: sender }
//           ).should.be.fulfilled.then((tx) => {
//             return tx.receipt.logs
//           })
//         })
//
//         describe('returned data', async () => {
//
//           it('should return the expected status', async () => {
//             revertReturn.should.be.eq(expectedStatus)
//           })
//         })
//
//         describe('events', async () => {
//
//           it('should have emitted 2 events total', async () => {
//             revertEvents.length.should.be.eq(2)
//           })
//
//           describe('the StorageException event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = revertEvents[1].topics
//               eventData = revertEvents[1].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(3)
//             })
//
//             it('should list the correct event signature in the first topic', async () => {
//               let sig = eventTopics[0]
//               web3.toDecimal(sig).should.be.eq(web3.toDecimal(storageExceptHash))
//             })
//
//             it('should have the storage address and execution id as the other 2 topics', async () => {
//               let emittedAddr = eventTopics[1]
//               let emittedExecId = eventTopics[2]
//               web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(storage.address))
//               web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(executionID))
//             })
//
//             it('should have the sender and wei sent as data', async () => {
//               let parsedData = await testUtils.parseStorageExceptionData.call(eventData).should.be.fulfilled
//               parsedData.length.should.be.eq(2)
//               parsedData[0].should.be.eq(sender)
//               parsedData[1].toNumber().should.be.eq(0)
//             })
//           })
//
//           describe('the ApplicationException event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = revertEvents[0].topics
//               eventData = revertEvents[0].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(3)
//             })
//
//             it('should list the correct event signature in the first topic', async () => {
//               let sig = eventTopics[0]
//               web3.toDecimal(sig).should.be.eq(web3.toDecimal(appExceptHash))
//             })
//
//             it('should have the target address and execution id as the other 2 topics', async () => {
//               let emittedAddr = eventTopics[1]
//               let emittedExecId = eventTopics[2]
//               web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(target))
//               web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(executionID))
//             })
//
//             it('should have data containing the message \'DefaultException\'', async () => {
//               eventData.length.should.be.eq(194)
//               let message = eventData.substring(130, 194)
//               hexStrEquals(message, 'DefaultException').should.be.eq(true, web3.toAscii(message))
//             })
//           })
//         })
//       })
//
//       describe('reverts with message', async () => {
//
//         beforeEach(async () => {
//           let revertCalldata = await appMockUtil.rev2.call(revertMessage, senderContext)
//           revertCalldata.should.not.eq('0x0')
//
//           revertReturn = await scriptExec.exec.call(
//             target, revertCalldata,
//             { from: sender }
//           ).should.be.fulfilled
//
//           revertEvents = await scriptExec.exec(
//             target, revertCalldata,
//             { from: sender }
//           ).should.be.fulfilled.then((tx) => {
//             return tx.receipt.logs
//           })
//         })
//
//         describe('returned data', async () => {
//
//           it('should return the expected status', async () => {
//             revertReturn.should.be.eq(expectedStatus)
//           })
//         })
//
//         describe('events', async () => {
//
//           it('should have emitted 2 events total', async () => {
//             revertEvents.length.should.be.eq(2)
//           })
//
//           describe('the StorageException event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = revertEvents[1].topics
//               eventData = revertEvents[1].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(3)
//             })
//
//             it('should list the correct event signature in the first topic', async () => {
//               let sig = eventTopics[0]
//               web3.toDecimal(sig).should.be.eq(web3.toDecimal(storageExceptHash))
//             })
//
//             it('should have the storage address and execution id as the other 2 topics', async () => {
//               let emittedAddr = eventTopics[1]
//               let emittedExecId = eventTopics[2]
//               web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(storage.address))
//               web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(executionID))
//             })
//
//             it('should have the sender and wei sent as data', async () => {
//               let parsedData = await testUtils.parseStorageExceptionData.call(eventData).should.be.fulfilled
//               parsedData.length.should.be.eq(2)
//               parsedData[0].should.be.eq(sender)
//               parsedData[1].toNumber().should.be.eq(0)
//             })
//           })
//
//           describe('the ApplicationException event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = revertEvents[0].topics
//               eventData = revertEvents[0].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(3)
//             })
//
//             it('should list the correct event signature in the first topic', async () => {
//               let sig = eventTopics[0]
//               web3.toDecimal(sig).should.be.eq(web3.toDecimal(appExceptHash))
//             })
//
//             it('should have the target address and execution id as the other 2 topics', async () => {
//               let emittedAddr = eventTopics[1]
//               let emittedExecId = eventTopics[2]
//               web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(target))
//               web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(executionID))
//             })
//
//             it('should have data containing the correct message', async () => {
//               eventData.length.should.be.eq(194)
//               let message = eventData.substring(130, 194)
//               hexStrEquals(message, revertMessage).should.be.eq(true, web3.toAscii(message))
//             })
//           })
//         })
//       })
//
//       describe('signals to throw with a message', async () => {
//
//         let revertCalldata
//
//         beforeEach(async () => {
//           revertCalldata = await appMockUtil.throws1.call(throwMessage, senderContext)
//           revertCalldata.should.not.eq('0x0')
//         })
//
//         it('should throw', async () => {
//           await scriptExec.exec(
//             target, revertCalldata,
//             { from: sender }
//           ).should.not.be.fulfilled
//         })
//       })
//
//       describe('signals to throw incorrectly', async () => {
//
//         let revertCalldata
//
//         beforeEach(async () => {
//           revertCalldata = await appMockUtil.throws2.call(throwMessage, senderContext)
//           revertCalldata.should.not.eq('0x0')
//         })
//
//         it('should throw', async () => {
//           await scriptExec.exec(
//             target, revertCalldata,
//             { from: sender }
//           ).should.not.be.fulfilled
//         })
//       })
//     })
//
//     describe('InvalidApp (app returns malformed data)', async () => {
//
//       let invalidCalldata
//
//       beforeEach(async () => {
//         target = invalidApp.address
//       })
//
//       describe('app attempts to pay storage contract', async () => {
//
//         let execContext
//
//         beforeEach(async () => {
//           execContext = await testUtils.getContextFromAddr.call(
//             executionID, sender, payouts[0]
//           ).should.be.fulfilled
//           execContext.should.not.eq('0x0')
//           invalidCalldata = await appMockUtil.inv1.call(execContext)
//           invalidCalldata.should.not.eq('0x0')
//         })
//
//         it('should throw', async () => {
//           await scriptExec.exec(
//             target, invalidCalldata,
//             { from: sender, value: payouts[0] }
//           ).should.not.be.fulfilled
//         })
//       })
//
//       describe('app does not change state', async () => {
//
//         beforeEach(async () => {
//           invalidCalldata = await appMockUtil.inv2.call(senderContext)
//           invalidCalldata.should.not.eq('0x0')
//         })
//
//         it('should throw', async () => {
//           await scriptExec.exec(
//             target, invalidCalldata,
//             { from: sender }
//           ).should.not.be.fulfilled
//         })
//       })
//     })
//
//     describe('StdApp (app stores data)', async () => {
//
//       let returnData
//       let execEvents
//
//       beforeEach(async () => {
//         target = stdApp.address
//       })
//
//       describe('storing to 0 slots', async () => {
//
//         let invalidCalldata
//
//         beforeEach(async () => {
//           expectedStatus = false
//
//           invalidCalldata = await appMockUtil.std0.call(senderContext)
//           invalidCalldata.should.not.eq('0x0')
//         })
//
//         it('should throw', async () => {
//           await scriptExec.exec(
//             target, invalidCalldata,
//             { from: sender }
//           ).should.not.be.fulfilled
//         })
//       })
//
//       describe('storing to one slot', async () => {
//
//         let calldata
//
//         beforeEach(async () => {
//           expectedStatus = true
//           calldata = await appMockUtil.std1.call(
//             storageLocations[0], storageValues[0], senderContext
//           )
//           calldata.should.not.eq('0x0')
//
//           returnData = await scriptExec.exec.call(
//             target, calldata,
//             { from: sender }
//           ).should.be.fulfilled
//
//           execEvents = await scriptExec.exec(
//             target, calldata,
//             { from: sender }
//           ).should.be.fulfilled.then((tx) => {
//             return tx.receipt.logs
//           })
//         })
//
//         describe('returned data', async () => {
//
//           it('should return the expected status', async () => {
//             returnData.should.be.eq(expectedStatus)
//           })
//         })
//
//         describe('events', async () => {
//
//           it('should have emitted 1 event total', async () => {
//             execEvents.length.should.be.eq(1)
//           })
//
//           describe('the ApplicationExecution event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = execEvents[0].topics
//               eventData = execEvents[0].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(3)
//             })
//
//             it('should list the correct event signature in the first topic', async () => {
//               let sig = eventTopics[0]
//               web3.toDecimal(sig).should.be.eq(web3.toDecimal(execHash))
//             })
//
//             it('should have the target app address and execution id as the other 2 topics', async () => {
//               let emittedAddr = eventTopics[2]
//               let emittedExecId = eventTopics[1]
//               web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(target))
//               web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(executionID))
//             })
//
//             it('should have an empty data field', async () => {
//               eventData.should.be.eq('0x0')
//             })
//           })
//         })
//
//         describe('storage', async () => {
//
//           it('should have correctly stored the value at the location', async () => {
//             let readValue = await storage.read.call(executionID, storageLocations[0])
//             hexStrEquals(readValue, storageValues[0]).should.be.eq(true, readValue)
//           })
//         })
//       })
//
//       describe('storing to 2 slots', async () => {
//
//         let calldata
//
//         beforeEach(async () => {
//           expectedStatus = true
//           calldata = await appMockUtil.std2.call(
//             storageLocations[0], storageValues[0],
//             storageLocations[1], storageValues[1],
//             senderContext
//           )
//           calldata.should.not.eq('0x0')
//
//           returnData = await scriptExec.exec.call(
//             target, calldata,
//             { from: sender }
//           ).should.be.fulfilled
//
//           execEvents = await scriptExec.exec(
//             target, calldata,
//             { from: sender }
//           ).should.be.fulfilled.then((tx) => {
//             return tx.receipt.logs
//           })
//         })
//
//         describe('returned data', async () => {
//
//           it('should return the expected status', async () => {
//             returnData.should.be.eq(expectedStatus)
//           })
//         })
//
//         describe('events', async () => {
//
//           it('should have emitted 1 event total', async () => {
//             execEvents.length.should.be.eq(1)
//           })
//
//           describe('the ApplicationExecution event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = execEvents[0].topics
//               eventData = execEvents[0].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(3)
//             })
//
//             it('should list the correct event signature in the first topic', async () => {
//               let sig = eventTopics[0]
//               web3.toDecimal(sig).should.be.eq(web3.toDecimal(execHash))
//             })
//
//             it('should have the target app address and execution id as the other 2 topics', async () => {
//               let emittedAddr = eventTopics[2]
//               let emittedExecId = eventTopics[1]
//               web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(target))
//               web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(executionID))
//             })
//
//             it('should have an empty data field', async () => {
//               eventData.should.be.eq('0x0')
//             })
//           })
//         })
//
//         describe('storage', async () => {
//
//           it('should have correctly stored the value at the first location', async () => {
//             let readValue = await storage.read.call(executionID, storageLocations[0])
//             hexStrEquals(readValue, storageValues[0]).should.be.eq(true)
//           })
//
//           it('should have correctly stored the value at the second location', async () => {
//             let readValue = await storage.read.call(executionID, storageLocations[1])
//             hexStrEquals(readValue, storageValues[1]).should.be.eq(true)
//           })
//         })
//       })
//     })
//
//     describe('PayableApp (forwards ETH)', async () => {
//
//       let calldata
//       let returnData
//       let execEvents
//
//       beforeEach(async () => {
//         target = payableApp.address
//       })
//
//       describe('pays out to 0 addresses', async () => {
//
//         let invalidCalldata
//         let invalidContext
//
//         beforeEach(async () => {
//           invalidContext = await testUtils.getContextFromAddr.call(
//             executionID, sender, payouts[0]
//           ).should.be.fulfilled
//           invalidContext.should.not.eq('0x0')
//
//           invalidCalldata = await appMockUtil.pay0.call(invalidContext)
//           invalidCalldata.should.not.eq('0x0')
//         })
//
//         it('should throw', async () => {
//           await scriptExec.exec(
//             target, invalidCalldata,
//             { from: sender, value: payouts[0] }
//           ).should.not.be.fulfilled
//         })
//       })
//
//       describe('pays out to 1 address', async () => {
//
//         let initPayeeBalance = 0
//         let senderPayContext
//
//         beforeEach(async () => {
//           expectedStatus = true
//           senderPayContext = await testUtils.getContextFromAddr.call(
//             executionID, sender, payouts[0]
//           ).should.be.fulfilled
//           senderPayContext.should.not.eq('0x0')
//
//           calldata = await appMockUtil.pay1.call(
//             payees[0], payouts[0], senderPayContext
//           )
//           calldata.should.not.eq('0x0')
//
//           returnData = await scriptExec.exec.call(
//             target, calldata,
//             { from: sender, value: payouts[0] }
//           ).should.be.fulfilled
//
//           initPayeeBalance = web3.eth.getBalance(payees[0])
//
//           execEvents = await scriptExec.exec(
//             target, calldata,
//             { from: sender, value: payouts[0] }
//           ).should.be.fulfilled.then((tx) => {
//             return tx.receipt.logs
//           })
//         })
//
//         describe('returned data', async () => {
//
//           it('should return the expected status', async () => {
//             returnData.should.be.eq(expectedStatus)
//           })
//         })
//
//         describe('events', async () => {
//
//           it('should have emitted 2 events total', async () => {
//             execEvents.length.should.be.eq(2)
//           })
//
//           describe('the ApplicationExecution event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = execEvents[1].topics
//               eventData = execEvents[1].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(3)
//             })
//
//             it('should list the correct event signature in the first topic', async () => {
//               let sig = eventTopics[0]
//               web3.toDecimal(sig).should.be.eq(web3.toDecimal(execHash))
//             })
//
//             it('should have the target app address and execution id as the other 2 topics', async () => {
//               let emittedAddr = eventTopics[2]
//               let emittedExecId = eventTopics[1]
//               web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(target))
//               web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(executionID))
//             })
//
//             it('should have an empty data field', async () => {
//               eventData.should.be.eq('0x0')
//             })
//           })
//
//           describe('the DeliveredPayment event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = execEvents[0].topics
//               eventData = execEvents[0].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(3)
//             })
//
//             it('should list the correct event signature in the first topic', async () => {
//               let sig = eventTopics[0]
//               web3.toDecimal(sig).should.be.eq(web3.toDecimal(payHash))
//             })
//
//             it('should have the payment destination and execution id as the other 2 topics', async () => {
//               let emittedAddr = eventTopics[2]
//               let emittedExecId = eventTopics[1]
//               web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(payees[0]))
//               web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(executionID))
//             })
//
//             it('should have a data field containing the amount sent', async () => {
//               web3.toDecimal(eventData).should.be.eq(payouts[0])
//             })
//           })
//         })
//
//         describe('payment', async () => {
//
//           it('should have delivered the amount to the destination', async () => {
//             let curPayeeBalance = web3.eth.getBalance(payees[0])
//             curPayeeBalance.should.be.bignumber.eq(web3.toBigNumber(initPayeeBalance).plus(payouts[0]))
//           })
//         })
//       })
//
//       describe('pays out to 2 addresses', async () => {
//
//         let initPayeeBalances = [0, 0]
//         let totalPayout
//
//         let senderPayContext
//
//         beforeEach(async () => {
//           expectedStatus = true
//           totalPayout = payouts[0] + payouts[1]
//
//           senderPayContext = await testUtils.getContextFromAddr.call(
//             executionID, sender, totalPayout
//           ).should.be.fulfilled
//           senderPayContext.should.not.eq('0x0')
//
//           calldata = await appMockUtil.pay2.call(
//             payees[0], payouts[0], payees[1], payouts[1],
//             senderPayContext
//           )
//           calldata.should.not.eq('0x0')
//
//           returnData = await scriptExec.exec.call(
//             target, calldata,
//             { from: sender, value: totalPayout }
//           ).should.be.fulfilled
//
//           initPayeeBalances = []
//           let payeeBal = web3.eth.getBalance(payees[0])
//           initPayeeBalances.push(payeeBal)
//           payeeBal = web3.eth.getBalance(payees[1])
//           initPayeeBalances.push(payeeBal)
//
//           execEvents = await scriptExec.exec(
//             target, calldata,
//             { from: sender, value: totalPayout  }
//           ).should.be.fulfilled.then((tx) => {
//             return tx.receipt.logs
//           })
//         })
//
//         describe('returned data', async () => {
//
//           it('should return the expected status', async () => {
//             returnData.should.be.eq(expectedStatus)
//           })
//         })
//
//         describe('events', async () => {
//
//           it('should have emitted 3 events total', async () => {
//             execEvents.length.should.be.eq(3)
//           })
//
//           describe('the ApplicationExecution event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = execEvents[2].topics
//               eventData = execEvents[2].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(3)
//             })
//
//             it('should list the correct event signature in the first topic', async () => {
//               let sig = eventTopics[0]
//               web3.toDecimal(sig).should.be.eq(web3.toDecimal(execHash))
//             })
//
//             it('should have the target app address and execution id as the other 2 topics', async () => {
//               let emittedAddr = eventTopics[2]
//               let emittedExecId = eventTopics[1]
//               web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(target))
//               web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(executionID))
//             })
//
//             it('should have an empty data field', async () => {
//               eventData.should.be.eq('0x0')
//             })
//           })
//
//           describe('the DeliveredPayment events', async () => {
//
//             let eventTopicsA
//             let eventDataA
//             let eventTopicsB
//             let eventDataB
//
//             beforeEach(async () => {
//               eventTopicsA = execEvents[0].topics
//               eventDataA = execEvents[0].data
//               eventTopicsB = execEvents[1].topics
//               eventDataB = execEvents[1].data
//             })
//
//             it('should both have the correct number of topics', async () => {
//               eventTopicsA.length.should.be.eq(3)
//               eventTopicsB.length.should.be.eq(3)
//             })
//
//             it('should both list the correct event signature in the first topic', async () => {
//               let sig = eventTopicsA[0]
//               web3.toDecimal(sig).should.be.eq(web3.toDecimal(payHash))
//               sig = eventTopicsB[0]
//               web3.toDecimal(sig).should.be.eq(web3.toDecimal(payHash))
//             })
//
//             it('should both have the payment destination and execution id as the other 2 topics', async () => {
//               let emittedAddr = eventTopicsA[2]
//               let emittedExecId = eventTopicsA[1]
//               web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(payees[0]))
//               web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(executionID))
//               emittedAddr = eventTopicsB[2]
//               emittedExecId = eventTopicsB[1]
//               web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(payees[1]))
//               web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(executionID))
//             })
//
//             it('should both have a data field containing the amount sent', async () => {
//               web3.toDecimal(eventDataA).should.be.eq(payouts[0])
//               web3.toDecimal(eventDataB).should.be.eq(payouts[1])
//             })
//           })
//         })
//
//         describe('payment', async () => {
//
//           it('should have delivered the amount to the first destination', async () => {
//             let curPayeeBalance = web3.eth.getBalance(payees[0])
//             curPayeeBalance.should.be.bignumber.eq(web3.toBigNumber(initPayeeBalances[0]).plus(payouts[0]))
//           })
//
//           it('should have delivered the amount to the second destination', async () => {
//             let curPayeeBalance = web3.eth.getBalance(payees[1])
//             curPayeeBalance.should.be.bignumber.eq(web3.toBigNumber(initPayeeBalances[1]).plus(payouts[1]))
//           })
//         })
//       })
//     })
//
//     describe('EmitsApp (app emits events)', async () => {
//
//       let calldata
//       let returnData
//       let execEvents
//
//       beforeEach(async () => {
//         target = emitApp.address
//       })
//
//       describe('emitting 0 events', async () => {
//
//         let invalidCalldata
//
//         beforeEach(async () => {
//           invalidCalldata = await appMockUtil.emit0.call(senderContext)
//           invalidCalldata.should.not.eq('0x0')
//         })
//
//         it('should throw', async () => {
//           await scriptExec.exec(
//             target, invalidCalldata,
//             { from: sender }
//           ).should.not.be.fulfilled
//         })
//       })
//
//       describe('emitting 1 event with no topics or data', async () => {
//
//         beforeEach(async () => {
//           expectedStatus = true
//           calldata = await appMockUtil.emit1top0.call(senderContext)
//           calldata.should.not.eq('0x0')
//
//           returnData = await scriptExec.exec.call(
//             target, calldata,
//             { from: sender }
//           ).should.be.fulfilled
//
//           execEvents = await scriptExec.exec(
//             target, calldata,
//             { from: sender }
//           ).should.be.fulfilled.then((tx) => {
//             return tx.receipt.logs
//           })
//         })
//
//         describe('returned data', async () => {
//
//           it('should return the expected status', async () => {
//             returnData.should.be.eq(expectedStatus)
//           })
//         })
//
//         describe('events', async () => {
//
//           it('should have emitted 2 events total', async () => {
//             execEvents.length.should.be.eq(2)
//           })
//
//           describe('the ApplicationExecution event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = execEvents[1].topics
//               eventData = execEvents[1].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(3)
//             })
//
//             it('should list the correct event signature in the first topic', async () => {
//               let sig = eventTopics[0]
//               web3.toDecimal(sig).should.be.eq(web3.toDecimal(execHash))
//             })
//
//             it('should have the target app address and execution id as the other 2 topics', async () => {
//               let emittedAddr = eventTopics[2]
//               let emittedExecId = eventTopics[1]
//               web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(target))
//               web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(executionID))
//             })
//
//             it('should have an empty data field', async () => {
//               eventData.should.be.eq('0x0')
//             })
//           })
//
//           describe('the other event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = execEvents[0].topics
//               eventData = execEvents[0].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(0)
//             })
//
//             it('should have an empty data field', async () => {
//               eventData.should.be.eq('0x0')
//             })
//           })
//         })
//       })
//
//       describe('emitting 1 event with no topics with data', async () => {
//
//         beforeEach(async () => {
//           expectedStatus = true
//           calldata = await appMockUtil.emit1top0data.call(senderContext)
//           calldata.should.not.eq('0x0')
//
//           returnData = await scriptExec.exec.call(
//             target, calldata,
//             { from: sender }
//           ).should.be.fulfilled
//
//           execEvents = await scriptExec.exec(
//             target, calldata,
//             { from: sender }
//           ).should.be.fulfilled.then((tx) => {
//             return tx.receipt.logs
//           })
//         })
//
//         describe('returned data', async () => {
//
//           it('should return the expected status', async () => {
//             returnData.should.be.eq(expectedStatus)
//           })
//         })
//
//         describe('events', async () => {
//
//           it('should have emitted 2 events total', async () => {
//             execEvents.length.should.be.eq(2)
//           })
//
//           describe('the ApplicationExecution event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = execEvents[1].topics
//               eventData = execEvents[1].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(3)
//             })
//
//             it('should list the correct event signature in the first topic', async () => {
//               let sig = eventTopics[0]
//               web3.toDecimal(sig).should.be.eq(web3.toDecimal(execHash))
//             })
//
//             it('should have the target app address and execution id as the other 2 topics', async () => {
//               let emittedAddr = eventTopics[2]
//               let emittedExecId = eventTopics[1]
//               web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(target))
//               web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(executionID))
//             })
//
//             it('should have an empty data field', async () => {
//               eventData.should.be.eq('0x0')
//             })
//           })
//
//           describe('the other event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = execEvents[0].topics
//               eventData = execEvents[0].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(0)
//             })
//
//             it('should have a data field matching the sender context', async () => {
//               web3.toDecimal(eventData).should.be.eq(web3.toDecimal(senderContext))
//             })
//           })
//         })
//       })
//
//       describe('emitting 1 event with 4 topics with data', async () => {
//
//         beforeEach(async () => {
//           expectedStatus = true
//           calldata = await appMockUtil.emit1top4data.call(
//             emitTopics[0], emitTopics[1], emitTopics[2], emitTopics[3],
//             senderContext
//           )
//           calldata.should.not.eq('0x0')
//
//           returnData = await scriptExec.exec.call(
//             target, calldata,
//             { from: sender }
//           ).should.be.fulfilled
//
//           execEvents = await scriptExec.exec(
//             target, calldata,
//             { from: sender }
//           ).should.be.fulfilled.then((tx) => {
//             return tx.receipt.logs
//           })
//         })
//
//         describe('returned data', async () => {
//
//           it('should return the expected status', async () => {
//             returnData.should.be.eq(expectedStatus)
//           })
//         })
//
//         describe('events', async () => {
//
//           it('should have emitted 2 events total', async () => {
//             execEvents.length.should.be.eq(2)
//           })
//
//           describe('the ApplicationExecution event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = execEvents[1].topics
//               eventData = execEvents[1].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(3)
//             })
//
//             it('should list the correct event signature in the first topic', async () => {
//               let sig = eventTopics[0]
//               web3.toDecimal(sig).should.be.eq(web3.toDecimal(execHash))
//             })
//
//             it('should have the target app address and execution id as the other 2 topics', async () => {
//               let emittedAddr = eventTopics[2]
//               let emittedExecId = eventTopics[1]
//               web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(target))
//               web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(executionID))
//             })
//
//             it('should have an empty data field', async () => {
//               eventData.should.be.eq('0x0')
//             })
//           })
//
//           describe('the other event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = execEvents[0].topics
//               eventData = execEvents[0].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(4)
//             })
//
//             it('should match the topics sent', async () => {
//               hexStrEquals(eventTopics[0], emitTopics[0]).should.be.eq(true)
//               hexStrEquals(eventTopics[1], emitTopics[1]).should.be.eq(true)
//               hexStrEquals(eventTopics[2], emitTopics[2]).should.be.eq(true)
//               hexStrEquals(eventTopics[3], emitTopics[3]).should.be.eq(true)
//             })
//
//             it('should have a data field matching the sender context', async () => {
//               web3.toDecimal(eventData).should.be.eq(web3.toDecimal(senderContext))
//             })
//           })
//         })
//       })
//
//       describe('emitting 2 events, each with 1 topic and data', async () => {
//
//         beforeEach(async () => {
//           expectedStatus = true
//           calldata = await appMockUtil.emit2top1data.call(
//             emitTopics[0], senderContext
//           )
//           calldata.should.not.eq('0x0')
//
//           returnData = await scriptExec.exec.call(
//             target, calldata,
//             { from: sender }
//           ).should.be.fulfilled
//
//           execEvents = await scriptExec.exec(
//             target, calldata,
//             { from: sender }
//           ).should.be.fulfilled.then((tx) => {
//             return tx.receipt.logs
//           })
//         })
//
//         describe('returned data', async () => {
//
//           it('should return the expected status', async () => {
//             returnData.should.be.eq(expectedStatus)
//           })
//         })
//
//         describe('events', async () => {
//
//           it('should have emitted 3 events total', async () => {
//             execEvents.length.should.be.eq(3)
//           })
//
//           describe('the ApplicationExecution event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = execEvents[2].topics
//               eventData = execEvents[2].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(3)
//             })
//
//             it('should list the correct event signature in the first topic', async () => {
//               let sig = eventTopics[0]
//               web3.toDecimal(sig).should.be.eq(web3.toDecimal(execHash))
//             })
//
//             it('should have the target app address and execution id as the other 2 topics', async () => {
//               let emittedAddr = eventTopics[2]
//               let emittedExecId = eventTopics[1]
//               web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(target))
//               web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(executionID))
//             })
//
//             it('should have an empty data field', async () => {
//               eventData.should.be.eq('0x0')
//             })
//           })
//
//           describe('the other events', async () => {
//
//             let eventTopicsA
//             let eventDataA
//             let eventTopicsB
//             let eventDataB
//
//             beforeEach(async () => {
//               eventTopicsA = execEvents[0].topics
//               eventDataA = execEvents[0].data
//               eventTopicsB = execEvents[1].topics
//               eventDataB = execEvents[1].data
//             })
//
//             it('should both have the correct number of topics', async () => {
//               eventTopicsA.length.should.be.eq(1)
//               eventTopicsB.length.should.be.eq(1)
//             })
//
//             it('should both match the topics sent', async () => {
//               hexStrEquals(eventTopicsA[0], emitTopics[0]).should.be.eq(true)
//               let appTopics2Hex = web3.toHex(
//                 web3.toBigNumber(eventTopicsB[0]).minus(1)
//               )
//               hexStrEquals(appTopics2Hex, emitTopics[0]).should.be.eq(true)
//             })
//
//             it('should both have a data field matching the sender context', async () => {
//               web3.toDecimal(eventDataA).should.be.eq(web3.toDecimal(senderContext))
//               web3.toDecimal(eventDataB).should.be.eq(web3.toDecimal(senderContext))
//             })
//           })
//         })
//       })
//
//       describe('emitting 2 events, each with 4 topics and no data', async () => {
//
//         beforeEach(async () => {
//           expectedStatus = true
//           calldata = await appMockUtil.emit2top4.call(
//             emitTopics[0], emitTopics[1], emitTopics[2], emitTopics[3],
//             senderContext
//           )
//           calldata.should.not.eq('0x0')
//
//           returnData = await scriptExec.exec.call(
//             target, calldata,
//             { from: sender }
//           ).should.be.fulfilled
//
//           execEvents = await scriptExec.exec(
//             target, calldata,
//             { from: sender }
//           ).should.be.fulfilled.then((tx) => {
//             return tx.receipt.logs
//           })
//         })
//
//         describe('returned data', async () => {
//
//           it('should return the expected status', async () => {
//             returnData.should.be.eq(expectedStatus)
//           })
//         })
//
//         describe('events', async () => {
//
//           it('should have emitted 3 events total', async () => {
//             execEvents.length.should.be.eq(3)
//           })
//
//           describe('the ApplicationExecution event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = execEvents[2].topics
//               eventData = execEvents[2].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(3)
//             })
//
//             it('should list the correct event signature in the first topic', async () => {
//               let sig = eventTopics[0]
//               web3.toDecimal(sig).should.be.eq(web3.toDecimal(execHash))
//             })
//
//             it('should have the target app address and execution id as the other 2 topics', async () => {
//               let emittedAddr = eventTopics[2]
//               let emittedExecId = eventTopics[1]
//               web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(target))
//               web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(executionID))
//             })
//
//             it('should have an empty data field', async () => {
//               eventData.should.be.eq('0x0')
//             })
//           })
//
//           describe('the other events', async () => {
//
//             let eventTopicsA
//             let eventDataA
//             let eventTopicsB
//             let eventDataB
//
//             beforeEach(async () => {
//               eventTopicsA = execEvents[0].topics
//               eventDataA = execEvents[0].data
//               eventTopicsB = execEvents[1].topics
//               eventDataB = execEvents[1].data
//             })
//
//             it('should both have the correct number of topics', async () => {
//               eventTopicsA.length.should.be.eq(4)
//               eventTopicsB.length.should.be.eq(4)
//             })
//
//             it('should both match the topics sent', async () => {
//               // First topic, both events
//               hexStrEquals(eventTopicsA[0], emitTopics[0]).should.be.eq(true)
//               let topicHex = web3.toHex(web3.toBigNumber(eventTopicsB[0]).minus(1))
//               hexStrEquals(topicHex, emitTopics[0]).should.be.eq(true)
//               // Second topic, both events
//               hexStrEquals(eventTopicsA[1], emitTopics[1]).should.be.eq(true)
//               topicHex = web3.toHex(web3.toBigNumber(eventTopicsB[1]).minus(1))
//               hexStrEquals(topicHex, emitTopics[1]).should.be.eq(true)
//               // Third topic, both events
//               hexStrEquals(eventTopicsA[2], emitTopics[2]).should.be.eq(true)
//               topicHex = web3.toHex(web3.toBigNumber(eventTopicsB[2]).minus(1))
//               hexStrEquals(topicHex, emitTopics[2]).should.be.eq(true)
//               // Fourth topic, both events
//               hexStrEquals(eventTopicsA[3], emitTopics[3]).should.be.eq(true)
//               topicHex = web3.toHex(web3.toBigNumber(eventTopicsB[3]).minus(1))
//               hexStrEquals(topicHex, emitTopics[3]).should.be.eq(true)
//             })
//
//             it('should both have an empty data field', async () => {
//               eventDataA.should.be.eq('0x0')
//               eventDataB.should.be.eq('0x0')
//             })
//           })
//         })
//       })
//     })
//
//     describe('MixedApp (app requests various actions from storage. order/amt not vary)', async () => {
//
//       let calldata
//       let returnData
//       let execEvents
//
//       beforeEach(async () => {
//         expectedStatus = true
//         target = mixApp.address
//       })
//
//       describe('2 actions (EMITS 1, THROWS)', async () => {
//
//         let invalidCalldata
//
//         beforeEach(async () => {
//           invalidCalldata = await appMockUtil.req0.call(emitTopics[0], senderContext)
//           invalidCalldata.should.not.eq('0x0')
//         })
//
//         it('should throw', async () => {
//           await scriptExec.exec(
//             target, invalidCalldata,
//             { from: sender }
//           ).should.not.be.fulfilled
//         })
//       })
//
//       describe('2 actions (PAYS 1, STORES 1)', async () => {
//
//         let initPayeeBalance = 0
//         let senderPayContext
//
//         beforeEach(async () => {
//           senderPayContext = await testUtils.getContextFromAddr.call(
//             executionID, sender, payouts[0]
//           ).should.be.fulfilled
//           senderPayContext.should.not.eq('0x0')
//
//           calldata = await appMockUtil.req1.call(
//             payees[0], payouts[0], storageLocations[0], storageValues[0],
//             senderPayContext
//           )
//           calldata.should.not.eq('0x0')
//
//           returnData = await scriptExec.exec.call(
//             target, calldata,
//             { from: sender, value: payouts[0] }
//           ).should.be.fulfilled
//
//           initPayeeBalance = web3.eth.getBalance(payees[0])
//
//           execEvents = await scriptExec.exec(
//             target, calldata,
//             { from: sender, value: payouts[0] }
//           ).should.be.fulfilled.then((tx) => {
//             return tx.receipt.logs
//           })
//         })
//
//         describe('returned data', async () => {
//
//           it('should return the expected status', async () => {
//             returnData.should.be.eq(expectedStatus)
//           })
//         })
//
//         describe('events', async () => {
//
//           it('should have emitted 2 events total', async () => {
//             execEvents.length.should.be.eq(2)
//           })
//
//           describe('the ApplicationExecution event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = execEvents[1].topics
//               eventData = execEvents[1].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(3)
//             })
//
//             it('should list the correct event signature in the first topic', async () => {
//               let sig = eventTopics[0]
//               web3.toDecimal(sig).should.be.eq(web3.toDecimal(execHash))
//             })
//
//             it('should have the target app address and execution id as the other 2 topics', async () => {
//               let emittedAddr = eventTopics[2]
//               let emittedExecId = eventTopics[1]
//               web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(target))
//               web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(executionID))
//             })
//
//             it('should have an empty data field', async () => {
//               eventData.should.be.eq('0x0')
//             })
//           })
//
//           describe('the DeliveredPayment event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = execEvents[0].topics
//               eventData = execEvents[0].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(3)
//             })
//
//             it('should list the correct event signature in the first topic', async () => {
//               let sig = eventTopics[0]
//               web3.toDecimal(sig).should.be.eq(web3.toDecimal(payHash))
//             })
//
//             it('should have the payment destination and execution id as the other 2 topics', async () => {
//               let emittedAddr = eventTopics[2]
//               let emittedExecId = eventTopics[1]
//               web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(payees[0]))
//               web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(executionID))
//             })
//
//             it('should have a data field containing the amount sent', async () => {
//               web3.toDecimal(eventData).should.be.eq(payouts[0])
//             })
//           })
//         })
//
//         describe('storage', async () => {
//
//           it('should have correctly stored the value at the location', async () => {
//             let readValue = await storage.read.call(executionID, storageLocations[0])
//             hexStrEquals(readValue, storageValues[0]).should.be.eq(true, readValue)
//           })
//         })
//
//         describe('payment', async () => {
//
//           it('should have delivered the amount to the destination', async () => {
//             let curPayeeBalance = web3.eth.getBalance(payees[0])
//             curPayeeBalance.should.be.bignumber.eq(web3.toBigNumber(initPayeeBalance).plus(payouts[0]))
//           })
//         })
//       })
//
//       describe('2 actions (EMITS 1, STORES 1)', async () => {
//
//         beforeEach(async () => {
//           calldata = await appMockUtil.req2.call(
//             emitTopics[0], storageLocations[0], storageValues[0],
//             senderContext
//           )
//           calldata.should.not.eq('0x0')
//
//           returnData = await scriptExec.exec.call(
//             target, calldata,
//             { from: sender }
//           ).should.be.fulfilled
//
//           execEvents = await scriptExec.exec(
//             target, calldata,
//             { from: sender }
//           ).should.be.fulfilled.then((tx) => {
//             return tx.receipt.logs
//           })
//         })
//
//         describe('returned data', async () => {
//
//           it('should return the expected status', async () => {
//             returnData.should.be.eq(expectedStatus)
//           })
//         })
//
//         describe('events', async () => {
//
//           it('should have emitted 2 events total', async () => {
//             execEvents.length.should.be.eq(2)
//           })
//
//           describe('the ApplicationExecution event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = execEvents[1].topics
//               eventData = execEvents[1].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(3)
//             })
//
//             it('should list the correct event signature in the first topic', async () => {
//               let sig = eventTopics[0]
//               web3.toDecimal(sig).should.be.eq(web3.toDecimal(execHash))
//             })
//
//             it('should have the target app address and execution id as the other 2 topics', async () => {
//               let emittedAddr = eventTopics[2]
//               let emittedExecId = eventTopics[1]
//               web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(target))
//               web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(executionID))
//             })
//
//             it('should have an empty data field', async () => {
//               eventData.should.be.eq('0x0')
//             })
//           })
//
//           describe('the other event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = execEvents[0].topics
//               eventData = execEvents[0].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(1)
//             })
//
//             it('should match the expected topics', async () => {
//               hexStrEquals(eventTopics[0], emitTopics[0]).should.be.eq(true)
//             })
//
//             it('should have an empty data field', async () => {
//               eventData.should.be.eq('0x0')
//             })
//           })
//         })
//
//         describe('storage', async () => {
//
//           it('should have correctly stored the value at the location', async () => {
//             let readValue = await storage.read.call(executionID, storageLocations[0])
//             hexStrEquals(readValue, storageValues[0]).should.be.eq(true)
//           })
//         })
//       })
//
//       describe('2 actions (PAYS 1, EMITS 1)', async () => {
//
//         let initPayeeBalance
//         let senderPayContext
//
//         beforeEach(async () => {
//           senderPayContext = await testUtils.getContextFromAddr.call(
//             executionID, sender, payouts[0]
//           ).should.be.fulfilled
//           senderPayContext.should.not.eq('0x0')
//
//           calldata = await appMockUtil.req3.call(
//             payees[0], payouts[0], emitTopics[0],
//             senderPayContext
//           )
//           calldata.should.not.eq('0x0')
//
//           returnData = await scriptExec.exec.call(
//             target, calldata,
//             { from: sender, value: payouts[0] }
//           ).should.be.fulfilled
//
//           initPayeeBalance = web3.eth.getBalance(payees[0])
//
//           execEvents = await scriptExec.exec(
//             target, calldata,
//             { from: sender, value: payouts[0] }
//           ).should.be.fulfilled.then((tx) => {
//             return tx.receipt.logs
//           })
//         })
//
//         describe('returned data', async () => {
//
//           it('should return the expected status', async () => {
//             returnData.should.be.eq(expectedStatus)
//           })
//         })
//
//         describe('events', async () => {
//
//           it('should have emitted 3 events total', async () => {
//             execEvents.length.should.be.eq(3)
//           })
//
//           describe('the ApplicationExecution event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = execEvents[2].topics
//               eventData = execEvents[2].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(3)
//             })
//
//             it('should list the correct event signature in the first topic', async () => {
//               let sig = eventTopics[0]
//               web3.toDecimal(sig).should.be.eq(web3.toDecimal(execHash))
//             })
//
//             it('should have the target app address and execution id as the other 2 topics', async () => {
//               let emittedAddr = eventTopics[2]
//               let emittedExecId = eventTopics[1]
//               web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(target))
//               web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(executionID))
//             })
//
//             it('should have an empty data field', async () => {
//               eventData.should.be.eq('0x0')
//             })
//           })
//
//           describe('the DeliveredPayment event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = execEvents[0].topics
//               eventData = execEvents[0].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(3)
//             })
//
//             it('should list the correct event signature in the first topic', async () => {
//               let sig = eventTopics[0]
//               web3.toDecimal(sig).should.be.eq(web3.toDecimal(payHash))
//             })
//
//             it('should have the payment destination and execution id as the other 2 topics', async () => {
//               let emittedAddr = eventTopics[2]
//               let emittedExecId = eventTopics[1]
//               web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(payees[0]))
//               web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(executionID))
//             })
//
//             it('should have a data field containing the amount sent', async () => {
//               web3.toDecimal(eventData).should.be.eq(payouts[0])
//             })
//           })
//
//           describe('the other event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = execEvents[1].topics
//               eventData = execEvents[1].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(1)
//             })
//
//             it('should match the expected topics', async () => {
//               hexStrEquals(eventTopics[0], emitTopics[0]).should.be.eq(true)
//             })
//
//             it('should have an empty data field', async () => {
//               eventData.should.be.eq('0x0')
//             })
//           })
//         })
//
//         describe('payment', async () => {
//
//           it('should have delivered the amount to the destination', async () => {
//             let curPayeeBalance = web3.eth.getBalance(payees[0])
//             curPayeeBalance.should.be.bignumber.eq(web3.toBigNumber(initPayeeBalance).plus(payouts[0]))
//           })
//         })
//       })
//
//       describe('3 actions (PAYS 2, EMITS 1, THROWS)', async () => {
//
//         let invalidCalldata
//         let senderPayContext
//
//         beforeEach(async () => {
//           senderPayContext = await testUtils.getContextFromAddr.call(
//             executionID, sender, payouts[0]
//           ).should.be.fulfilled
//           senderPayContext.should.not.eq('0x0')
//
//           invalidCalldata = await appMockUtil.reqs0.call(
//             payees[0], payouts[0], payees[1], payouts[1],
//             emitTopics[0], senderPayContext
//           )
//           invalidCalldata.should.not.eq('0x0')
//         })
//
//         it('should throw', async () => {
//           await scriptExec.exec(
//             target, invalidCalldata,
//             { from: sender, value: payouts[0] }
//           ).should.not.be.fulfilled
//         })
//       })
//
//       describe('3 actions (EMITS 2, PAYS 1, STORES 2)', async () => {
//
//         let initPayeeBalance
//         let senderPayContext
//
//         beforeEach(async () => {
//           senderPayContext = await testUtils.getContextFromAddr.call(
//             executionID, sender, payouts[0]
//           ).should.be.fulfilled
//           senderPayContext.should.not.eq('0x0')
//
//           calldata = await appMockUtil.reqs1.call(
//             payees[0], payouts[0],
//             storageLocations[0], storageValues[0],
//             storageLocations[1], storageValues[1],
//             senderPayContext
//           )
//           calldata.should.not.eq('0x0')
//
//           returnData = await scriptExec.exec.call(
//             target, calldata,
//             { from: sender, value: payouts[0] }
//           ).should.be.fulfilled
//
//           initPayeeBalance = web3.eth.getBalance(payees[0])
//
//           execEvents = await scriptExec.exec(
//             target, calldata,
//             { from: sender, value: payouts[0] }
//           ).should.be.fulfilled.then((tx) => {
//             return tx.receipt.logs
//           })
//         })
//
//         describe('returned data', async () => {
//
//           it('should return the expected status', async () => {
//             returnData.should.be.eq(expectedStatus)
//           })
//         })
//
//         describe('events', async () => {
//
//           it('should have emitted 4 events total', async () => {
//             execEvents.length.should.be.eq(4)
//           })
//
//           describe('the ApplicationExecution event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = execEvents[3].topics
//               eventData = execEvents[3].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(3)
//             })
//
//             it('should list the correct event signature in the first topic', async () => {
//               let sig = eventTopics[0]
//               web3.toDecimal(sig).should.be.eq(web3.toDecimal(execHash))
//             })
//
//             it('should have the target app address and execution id as the other 2 topics', async () => {
//               let emittedAddr = eventTopics[2]
//               let emittedExecId = eventTopics[1]
//               web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(target))
//               web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(executionID))
//             })
//
//             it('should have an empty data field', async () => {
//               eventData.should.be.eq('0x0')
//             })
//           })
//
//           describe('the DeliveredPayment event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = execEvents[2].topics
//               eventData = execEvents[2].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(3)
//             })
//
//             it('should list the correct event signature in the first topic', async () => {
//               let sig = eventTopics[0]
//               web3.toDecimal(sig).should.be.eq(web3.toDecimal(payHash))
//             })
//
//             it('should have the payment destination and execution id as the other 2 topics', async () => {
//               let emittedAddr = eventTopics[2]
//               let emittedExecId = eventTopics[1]
//               web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(payees[0]))
//               web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(executionID))
//             })
//
//             it('should have a data field containing the amount sent', async () => {
//               web3.toDecimal(eventData).should.be.eq(payouts[0])
//             })
//           })
//
//           describe('the other events', async () => {
//
//             let eventTopicsA
//             let eventDataA
//             let eventTopicsB
//             let eventDataB
//
//             beforeEach(async () => {
//               eventTopicsA = execEvents[0].topics
//               eventDataA = execEvents[0].data
//               eventTopicsB = execEvents[1].topics
//               eventDataB = execEvents[1].data
//             })
//
//             it('should both have the correct number of topics', async () => {
//               eventTopicsA.length.should.be.eq(0)
//               eventTopicsB.length.should.be.eq(0)
//             })
//
//             it('should both have a data field matching the sender context', async () => {
//               web3.toDecimal(eventDataA).should.be.eq(web3.toDecimal(senderPayContext))
//               web3.toDecimal(eventDataB).should.be.eq(web3.toDecimal(senderPayContext))
//             })
//           })
//         })
//
//         describe('storage', async () => {
//
//           it('should have correctly stored the value at the first location', async () => {
//             let readValue = await storage.read.call(executionID, storageLocations[0])
//             hexStrEquals(readValue, storageValues[0]).should.be.eq(true)
//           })
//
//           it('should have correctly stored the value at the second location', async () => {
//             let readValue = await storage.read.call(executionID, storageLocations[1])
//             hexStrEquals(readValue, storageValues[1]).should.be.eq(true)
//           })
//         })
//
//         describe('payment', async () => {
//
//           it('should have delivered the amount to the destination', async () => {
//             let curPayeeBalance = web3.eth.getBalance(payees[0])
//             curPayeeBalance.should.be.bignumber.eq(web3.toBigNumber(initPayeeBalance).plus(payouts[0]))
//           })
//         })
//       })
//
//       describe('3 actions (PAYS 1, EMITS 3, STORES 1)', async () => {
//
//         let initPayeeBalance
//         let senderPayContext
//
//         beforeEach(async () => {
//           senderPayContext = await testUtils.getContextFromAddr.call(
//             executionID, sender, payouts[0]
//           ).should.be.fulfilled
//           senderPayContext.should.not.eq('0x0')
//
//           calldata = await appMockUtil.reqs2.call(
//             payees[0], payouts[0], emitTopics,
//             storageLocations[0], storageValues[0],
//             senderPayContext
//           )
//           calldata.should.not.eq('0x0')
//
//           returnData = await scriptExec.exec.call(
//             target, calldata,
//             { from: sender, value: payouts[0] }
//           ).should.be.fulfilled
//
//           initPayeeBalance = web3.eth.getBalance(payees[0])
//
//           execEvents = await scriptExec.exec(
//             target, calldata,
//             { from: sender, value: payouts[0] }
//           ).should.be.fulfilled.then((tx) => {
//             return tx.receipt.logs
//           })
//         })
//
//         describe('returned data', async () => {
//
//           it('should return the expected status', async () => {
//             returnData.should.be.eq(expectedStatus)
//           })
//         })
//
//         describe('events', async () => {
//
//           it('should have emitted 4 events total', async () => {
//             execEvents.length.should.be.eq(5)
//           })
//
//           describe('the ApplicationExecution event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = execEvents[4].topics
//               eventData = execEvents[4].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(3)
//             })
//
//             it('should list the correct event signature in the first topic', async () => {
//               let sig = eventTopics[0]
//               web3.toDecimal(sig).should.be.eq(web3.toDecimal(execHash))
//             })
//
//             it('should have the target app address and execution id as the other 2 topics', async () => {
//               let emittedAddr = eventTopics[2]
//               let emittedExecId = eventTopics[1]
//               web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(target))
//               web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(executionID))
//             })
//
//             it('should have an empty data field', async () => {
//               eventData.should.be.eq('0x0')
//             })
//           })
//
//           describe('the DeliveredPayment event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = execEvents[0].topics
//               eventData = execEvents[0].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(3)
//             })
//
//             it('should list the correct event signature in the first topic', async () => {
//               let sig = eventTopics[0]
//               web3.toDecimal(sig).should.be.eq(web3.toDecimal(payHash))
//             })
//
//             it('should have the payment destination and execution id as the other 2 topics', async () => {
//               let emittedAddr = eventTopics[2]
//               let emittedExecId = eventTopics[1]
//               web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(payees[0]))
//               web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(executionID))
//             })
//
//             it('should have a data field containing the amount sent', async () => {
//               web3.toDecimal(eventData).should.be.eq(payouts[0])
//             })
//           })
//
//           describe('the other events', async () => {
//
//             let eventTopicsA
//             let eventDataA
//             let eventTopicsB
//             let eventDataB
//             let eventTopicsC
//             let eventDataC
//
//
//             beforeEach(async () => {
//               eventTopicsA = execEvents[1].topics
//               eventDataA = execEvents[1].data
//               eventTopicsB = execEvents[2].topics
//               eventDataB = execEvents[2].data
//               eventTopicsC = execEvents[3].topics
//               eventDataC = execEvents[3].data
//             })
//
//             context('event A', async () => {
//
//               it('should have the correct number of topics', async () => {
//                 eventTopicsA.length.should.be.eq(4)
//               })
//
//               it('should match the passed in topics', async () => {
//                 hexStrEquals(eventTopicsA[0], emitTopics[0]).should.be.eq(true)
//                 hexStrEquals(eventTopicsA[1], emitTopics[1]).should.be.eq(true)
//                 hexStrEquals(eventTopicsA[2], emitTopics[2]).should.be.eq(true)
//                 hexStrEquals(eventTopicsA[3], emitTopics[3]).should.be.eq(true)
//               })
//
//               it('should have a data field matching the sender context', async () => {
//                 web3.toDecimal(eventDataA).should.be.eq(web3.toDecimal(senderPayContext))
//               })
//             })
//
//             context('event B', async () => {
//
//               it('should have the correct number of topics', async () => {
//                 eventTopicsB.length.should.be.eq(4)
//               })
//
//               it('should match the passed in topics', async () => {
//                 let topicHex = web3.toHex(web3.toBigNumber(eventTopicsB[0]).minus(1))
//                 hexStrEquals(topicHex, emitTopics[0]).should.be.eq(true)
//                 topicHex = web3.toHex(web3.toBigNumber(eventTopicsB[1]).minus(1))
//                 hexStrEquals(topicHex, emitTopics[1]).should.be.eq(true)
//                 topicHex = web3.toHex(web3.toBigNumber(eventTopicsB[2]).minus(1))
//                 hexStrEquals(topicHex, emitTopics[2]).should.be.eq(true)
//                 topicHex = web3.toHex(web3.toBigNumber(eventTopicsB[3]).minus(1))
//                 hexStrEquals(topicHex, emitTopics[3]).should.be.eq(true)
//               })
//
//               it('should have a data field matching the sender context', async () => {
//                 web3.toDecimal(eventDataB).should.be.eq(web3.toDecimal(senderPayContext))
//               })
//             })
//
//             context('event C', async () => {
//
//               it('should have the correct number of topics', async () => {
//                 eventTopicsC.length.should.be.eq(4)
//               })
//
//               it('should match the passed in topics', async () => {
//                 let topicHex = web3.toHex(web3.toBigNumber(eventTopicsC[0]).minus(2))
//                 hexStrEquals(topicHex, emitTopics[0]).should.be.eq(true)
//                 topicHex = web3.toHex(web3.toBigNumber(eventTopicsC[1]).minus(2))
//                 hexStrEquals(topicHex, emitTopics[1]).should.be.eq(true)
//                 topicHex = web3.toHex(web3.toBigNumber(eventTopicsC[2]).minus(2))
//                 hexStrEquals(topicHex, emitTopics[2]).should.be.eq(true)
//                 topicHex = web3.toHex(web3.toBigNumber(eventTopicsC[3]).minus(2))
//                 hexStrEquals(topicHex, emitTopics[3]).should.be.eq(true)
//               })
//
//               it('should have a data field matching the sender context', async () => {
//                 web3.toDecimal(eventDataC).should.be.eq(web3.toDecimal(senderPayContext))
//               })
//             })
//           })
//         })
//
//         describe('storage', async () => {
//
//           it('should have correctly stored the value at the location', async () => {
//             let readValue = await storage.read.call(executionID, storageLocations[0])
//             hexStrEquals(readValue, storageValues[0]).should.be.eq(true)
//           })
//         })
//
//         describe('payment', async () => {
//
//           it('should have delivered the amount to the destination', async () => {
//             let curPayeeBalance = web3.eth.getBalance(payees[0])
//             curPayeeBalance.should.be.bignumber.eq(web3.toBigNumber(initPayeeBalance).plus(payouts[0]))
//           })
//         })
//       })
//
//       describe('3 actions (STORES 2, PAYS 1, EMITS 1)', async () => {
//
//         let initPayeeBalance
//         let senderPayContext
//
//         beforeEach(async () => {
//           senderPayContext = await testUtils.getContextFromAddr.call(
//             executionID, sender, payouts[0]
//           ).should.be.fulfilled
//           senderPayContext.should.not.eq('0x0')
//
//           calldata = await appMockUtil.reqs3.call(
//             payees[0], payouts[0], emitTopics[0],
//             storageLocations[0], storageValues[0],
//             storageLocations[1], storageValues[1],
//             senderPayContext
//           )
//           calldata.should.not.eq('0x0')
//
//           returnData = await scriptExec.exec.call(
//             target, calldata,
//             { from: sender, value: payouts[0] }
//           ).should.be.fulfilled
//
//           initPayeeBalance = web3.eth.getBalance(payees[0])
//
//           execEvents = await scriptExec.exec(
//             target, calldata,
//             { from: sender, value: payouts[0] }
//           ).should.be.fulfilled.then((tx) => {
//             return tx.receipt.logs
//           })
//         })
//
//         describe('returned data', async () => {
//
//           it('should return the expected status', async () => {
//             returnData.should.be.eq(expectedStatus)
//           })
//         })
//
//         describe('events', async () => {
//
//           it('should have emitted 3 events total', async () => {
//             execEvents.length.should.be.eq(3)
//           })
//
//           describe('the ApplicationExecution event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = execEvents[2].topics
//               eventData = execEvents[2].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(3)
//             })
//
//             it('should list the correct event signature in the first topic', async () => {
//               let sig = eventTopics[0]
//               web3.toDecimal(sig).should.be.eq(web3.toDecimal(execHash))
//             })
//
//             it('should have the target app address and execution id as the other 2 topics', async () => {
//               let emittedAddr = eventTopics[2]
//               let emittedExecId = eventTopics[1]
//               web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(target))
//               web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(executionID))
//             })
//
//             it('should have an empty data field', async () => {
//               eventData.should.be.eq('0x0')
//             })
//           })
//
//           describe('the DeliveredPayment event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = execEvents[0].topics
//               eventData = execEvents[0].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(3)
//             })
//
//             it('should list the correct event signature in the first topic', async () => {
//               let sig = eventTopics[0]
//               web3.toDecimal(sig).should.be.eq(web3.toDecimal(payHash))
//             })
//
//             it('should have the payment destination and execution id as the other 2 topics', async () => {
//               let emittedAddr = eventTopics[2]
//               let emittedExecId = eventTopics[1]
//               web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(payees[0]))
//               web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(executionID))
//             })
//
//             it('should have a data field containing the amount sent', async () => {
//               web3.toDecimal(eventData).should.be.eq(payouts[0])
//             })
//           })
//
//           describe('the other event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = execEvents[1].topics
//               eventData = execEvents[1].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(1)
//             })
//
//             it('should match the expected topics', async () => {
//               hexStrEquals(eventTopics[0], emitTopics[0]).should.be.eq(true)
//             })
//
//             it('should a data field matching the sender context', async () => {
//               web3.toDecimal(eventData).should.be.eq(web3.toDecimal(senderPayContext))
//             })
//           })
//         })
//
//         describe('storage', async () => {
//
//           it('should have correctly stored the value at the first location', async () => {
//             let readValue = await storage.read.call(executionID, storageLocations[0])
//             hexStrEquals(readValue, storageValues[0]).should.be.eq(true)
//           })
//
//           it('should have correctly stored the value at the second location', async () => {
//             let readValue = await storage.read.call(executionID, storageLocations[1])
//             hexStrEquals(readValue, storageValues[1]).should.be.eq(true)
//           })
//         })
//
//         describe('payment', async () => {
//
//           it('should have delivered the amount to the destination', async () => {
//             let curPayeeBalance = web3.eth.getBalance(payees[0])
//             curPayeeBalance.should.be.bignumber.eq(web3.toBigNumber(initPayeeBalance).plus(payouts[0]))
//           })
//         })
//       })
//     })
//   })
//
//   describe('#exec - nonpayable', async () => {
//
//     let executionID
//     let target
//     let expectedStatus
//
//     beforeEach(async () => {
//       let events = await storage.initAndFinalize(
//         updater, false, appInit.address, initCalldata, allowedAddrs,
//         { from: execAdmin }
//       ).should.be.fulfilled.then((tx) => {
//         return tx.logs
//       })
//       events.should.not.eq(null)
//       events.length.should.be.eq(2)
//       events[0].event.should.be.eq('ApplicationInitialized')
//       events[1].event.should.be.eq('ApplicationFinalization')
//       executionID = events[0].args['execution_id']
//       web3.toDecimal(executionID).should.not.eq(0)
//
//       await storage.changeScriptExec(
//         executionID, scriptExec.address, { from: execAdmin }
//       ).should.be.fulfilled
//
//       senderContext = await testUtils.getContextFromAddr.call(
//         executionID, sender, 0
//       ).should.be.fulfilled
//       senderContext.should.not.eq('0x0')
//     })
//
//     describe('basic app info', async () => {
//
//       it('should correctly set the script exec to the deployed contract', async () => {
//         let appInfo = await storage.app_info.call(executionID)
//         appInfo[0].should.be.eq(false)
//         appInfo[1].should.be.eq(true)
//         appInfo[2].should.be.eq(false)
//         appInfo[3].should.be.eq(updater)
//         appInfo[4].should.be.eq(scriptExec.address)
//         appInfo[5].should.be.eq(appInit.address)
//       })
//     })
//
//     describe('invalid inputs or invalid state', async () => {
//
//       let calldata
//
//       beforeEach(async () => {
//         target = stdApp.address
//
//         calldata = await testUtils.getContextFromAddr(
//           executionID, sender, 0
//         ).should.be.fulfilled
//         calldata.should.not.eq('0x0')
//       })
//
//       context('sender passes in incorrect address with context', async () => {
//
//         let invalidContext
//         let invalidCalldata
//
//         beforeEach(async () => {
//           invalidContext = await testUtils.getContextFromAddr.call(
//             executionID, otherAddr, 0
//           ).should.be.fulfilled
//           invalidContext.should.not.eq('0x0')
//
//           invalidCalldata = await appMockUtil.std1.call(
//             storageLocations[0], storageValues[0], invalidContext
//           ).should.be.fulfilled
//           invalidCalldata.should.not.eq('0x0')
//         })
//
//         it('should throw', async () => {
//           await scriptExec.exec(
//             target, invalidCalldata,
//             { from: sender }
//           ).should.not.be.fulfilled
//         })
//       })
//
//       context('sender passes in incorrect wei amount with context', async () => {
//
//         let invalidContext
//         let invalidCalldata
//
//         beforeEach(async () => {
//           invalidContext = await testUtils.getContextFromAddr.call(
//             executionID, sender, 1
//           ).should.be.fulfilled
//           invalidContext.should.not.eq('0x0')
//
//           invalidCalldata = await appMockUtil.std1.call(
//             storageLocations[0], storageValues[0], invalidContext
//           ).should.be.fulfilled
//           invalidCalldata.should.not.eq('0x0')
//         })
//
//         it('should throw', async () => {
//           await scriptExec.exec(
//             target, invalidCalldata,
//             { from: sender }
//           ).should.not.be.fulfilled
//         })
//       })
//
//       context('sender sends wei to a non-payable app', async () => {
//
//         let invalidContext
//         let invalidCalldata
//
//         beforeEach(async () => {
//           invalidContext = await testUtils.getContextFromAddr.call(
//             executionID, sender, payouts[0]
//           ).should.be.fulfilled
//           invalidContext.should.not.eq('0x0')
//
//           invalidCalldata = await appMockUtil.pay1.call(
//             payees[0], payouts[0], invalidContext
//           ).should.be.fulfilled
//           invalidCalldata.should.not.eq('0x0')
//         })
//
//         it('should throw', async () => {
//           await scriptExec.exec(
//             payableApp.address, invalidCalldata,
//             { from: sender, value: payouts[0] }
//           ).should.not.be.fulfilled
//         })
//       })
//
//       context('target address is 0', async () => {
//
//         it('should throw', async () => {
//           await scriptExec.exec(
//             zeroAddress(), calldata,
//             { from: sender }
//           ).should.not.be.fulfilled
//         })
//       })
//
//       context('exec id is 0', async () => {
//
//         let invalidExecID = web3.toHex(0)
//         let invalidContext
//         let invalidCalldata
//
//         beforeEach(async () => {
//           invalidContext = await testUtils.getContextFromAddr.call(
//             invalidExecID, sender, 0
//           ).should.be.fulfilled
//           invalidContext.should.not.eq('0x0')
//
//           invalidCalldata = await appMockUtil.std1.call(
//             storageLocations[0], storageValues[0], invalidContext
//           ).should.be.fulfilled
//           calldata.should.not.be.eq('0x0')
//         })
//
//         it('should throw', async () => {
//           await scriptExec.exec(
//             target, invalidCalldata,
//             { from: sender }
//           ).should.not.be.fulfilled
//         })
//       })
//
//       context('script target not in exec id allowed list', async () => {
//
//         let invalidTarget
//
//         beforeEach(async () => {
//           invalidTarget = await StdApp.new().should.be.fulfilled
//         })
//
//         it('should throw', async () => {
//           await scriptExec.exec(
//             invalidTarget.address, calldata,
//             { from: sender }
//           ).should.not.be.fulfilled
//         })
//       })
//
//       context('app is paused', async () => {
//
//         beforeEach(async () => {
//           await storage.pauseAppInstance(executionID, { from: updater }).should.be.fulfilled
//           let appInfo = await storage.app_info.call(executionID)
//           appInfo[0].should.be.eq(true)
//         })
//
//         it('should throw', async () => {
//           await scriptExec.exec(
//             target, calldata,
//             { from: sender }
//           ).should.not.be.fulfilled
//         })
//       })
//     })
//
//     describe('RevertApp (app reverts)', async () => {
//
//       let revertEvents
//       let revertReturn
//
//       beforeEach(async () => {
//         target = revertApp.address
//         expectedStatus = false
//       })
//
//       describe('function did not exist', async () => {
//
//         let invalidCalldata
//
//         beforeEach(async () => {
//           invalidCalldata = await appMockUtil.rev0.call(senderContext)
//           invalidCalldata.should.not.eq('0x0')
//
//           revertReturn = await scriptExec.exec.call(
//             target, invalidCalldata,
//             { from: sender }
//           ).should.be.fulfilled
//
//           revertEvents = await scriptExec.exec(
//             target, invalidCalldata,
//             { from: sender }
//           ).should.be.fulfilled.then((tx) => {
//             return tx.receipt.logs
//           })
//         })
//
//         describe('returned data', async () => {
//
//           it('should return the expected status', async () => {
//             revertReturn.should.be.eq(expectedStatus)
//           })
//         })
//
//         describe('events', async () => {
//
//           it('should have emitted 2 events total', async () => {
//             revertEvents.length.should.be.eq(2)
//           })
//
//           describe('the StorageException event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = revertEvents[1].topics
//               eventData = revertEvents[1].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(3)
//             })
//
//             it('should list the correct event signature in the first topic', async () => {
//               let sig = eventTopics[0]
//               web3.toDecimal(sig).should.be.eq(web3.toDecimal(storageExceptHash))
//             })
//
//             it('should have the storage address and execution id as the other 2 topics', async () => {
//               let emittedAddr = eventTopics[1]
//               let emittedExecId = eventTopics[2]
//               web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(storage.address))
//               web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(executionID))
//             })
//
//             it('should have the sender and wei sent as data', async () => {
//               let parsedData = await testUtils.parseStorageExceptionData.call(eventData).should.be.fulfilled
//               parsedData.length.should.be.eq(2)
//               parsedData[0].should.be.eq(sender)
//               parsedData[1].toNumber().should.be.eq(0)
//             })
//           })
//
//           describe('the ApplicationException event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = revertEvents[0].topics
//               eventData = revertEvents[0].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(3)
//             })
//
//             it('should list the correct event signature in the first topic', async () => {
//               let sig = eventTopics[0]
//               web3.toDecimal(sig).should.be.eq(web3.toDecimal(appExceptHash))
//             })
//
//             it('should have the target address and execution id as the other 2 topics', async () => {
//               let emittedAddr = eventTopics[1]
//               let emittedExecId = eventTopics[2]
//               web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(target))
//               web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(executionID))
//             })
//
//             it('should have data containing the message \'DefaultException\'', async () => {
//               eventData.length.should.be.eq(194)
//               let message = eventData.substring(130, 194)
//               hexStrEquals(message, 'DefaultException').should.be.eq(true, web3.toAscii(message))
//             })
//           })
//         })
//       })
//
//       describe('reverts with no message', async () => {
//
//         beforeEach(async () => {
//           let revertCalldata = await appMockUtil.rev1.call(senderContext)
//           revertCalldata.should.not.eq('0x0')
//
//           revertReturn = await scriptExec.exec.call(
//             target, revertCalldata,
//             { from: sender }
//           ).should.be.fulfilled
//
//           revertEvents = await scriptExec.exec(
//             target, revertCalldata,
//             { from: sender }
//           ).should.be.fulfilled.then((tx) => {
//             return tx.receipt.logs
//           })
//         })
//
//         describe('returned data', async () => {
//
//           it('should return the expected status', async () => {
//             revertReturn.should.be.eq(expectedStatus)
//           })
//         })
//
//         describe('events', async () => {
//
//           it('should have emitted 2 events total', async () => {
//             revertEvents.length.should.be.eq(2)
//           })
//
//           describe('the StorageException event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = revertEvents[1].topics
//               eventData = revertEvents[1].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(3)
//             })
//
//             it('should list the correct event signature in the first topic', async () => {
//               let sig = eventTopics[0]
//               web3.toDecimal(sig).should.be.eq(web3.toDecimal(storageExceptHash))
//             })
//
//             it('should have the storage address and execution id as the other 2 topics', async () => {
//               let emittedAddr = eventTopics[1]
//               let emittedExecId = eventTopics[2]
//               web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(storage.address))
//               web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(executionID))
//             })
//
//             it('should have the sender and wei sent as data', async () => {
//               let parsedData = await testUtils.parseStorageExceptionData.call(eventData).should.be.fulfilled
//               parsedData.length.should.be.eq(2)
//               parsedData[0].should.be.eq(sender)
//               parsedData[1].toNumber().should.be.eq(0)
//             })
//           })
//
//           describe('the ApplicationException event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = revertEvents[0].topics
//               eventData = revertEvents[0].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(3)
//             })
//
//             it('should list the correct event signature in the first topic', async () => {
//               let sig = eventTopics[0]
//               web3.toDecimal(sig).should.be.eq(web3.toDecimal(appExceptHash))
//             })
//
//             it('should have the target address and execution id as the other 2 topics', async () => {
//               let emittedAddr = eventTopics[1]
//               let emittedExecId = eventTopics[2]
//               web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(target))
//               web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(executionID))
//             })
//
//             it('should have data containing the message \'DefaultException\'', async () => {
//               eventData.length.should.be.eq(194)
//               let message = eventData.substring(130, 194)
//               hexStrEquals(message, 'DefaultException').should.be.eq(true, web3.toAscii(message))
//             })
//           })
//         })
//       })
//
//       describe('reverts with message', async () => {
//
//         beforeEach(async () => {
//           let revertCalldata = await appMockUtil.rev2.call(revertMessage, senderContext)
//           revertCalldata.should.not.eq('0x0')
//
//           revertReturn = await scriptExec.exec.call(
//             target, revertCalldata,
//             { from: sender }
//           ).should.be.fulfilled
//
//           revertEvents = await scriptExec.exec(
//             target, revertCalldata,
//             { from: sender }
//           ).should.be.fulfilled.then((tx) => {
//             return tx.receipt.logs
//           })
//         })
//
//         describe('returned data', async () => {
//
//           it('should return the expected status', async () => {
//             revertReturn.should.be.eq(expectedStatus)
//           })
//         })
//
//         describe('events', async () => {
//
//           it('should have emitted 2 events total', async () => {
//             revertEvents.length.should.be.eq(2)
//           })
//
//           describe('the StorageException event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = revertEvents[1].topics
//               eventData = revertEvents[1].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(3)
//             })
//
//             it('should list the correct event signature in the first topic', async () => {
//               let sig = eventTopics[0]
//               web3.toDecimal(sig).should.be.eq(web3.toDecimal(storageExceptHash))
//             })
//
//             it('should have the storage address and execution id as the other 2 topics', async () => {
//               let emittedAddr = eventTopics[1]
//               let emittedExecId = eventTopics[2]
//               web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(storage.address))
//               web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(executionID))
//             })
//
//             it('should have the sender and wei sent as data', async () => {
//               let parsedData = await testUtils.parseStorageExceptionData.call(eventData).should.be.fulfilled
//               parsedData.length.should.be.eq(2)
//               parsedData[0].should.be.eq(sender)
//               parsedData[1].toNumber().should.be.eq(0)
//             })
//           })
//
//           describe('the ApplicationException event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = revertEvents[0].topics
//               eventData = revertEvents[0].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(3)
//             })
//
//             it('should list the correct event signature in the first topic', async () => {
//               let sig = eventTopics[0]
//               web3.toDecimal(sig).should.be.eq(web3.toDecimal(appExceptHash))
//             })
//
//             it('should have the target address and execution id as the other 2 topics', async () => {
//               let emittedAddr = eventTopics[1]
//               let emittedExecId = eventTopics[2]
//               web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(target))
//               web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(executionID))
//             })
//
//             it('should have data containing the correct message', async () => {
//               eventData.length.should.be.eq(194)
//               let message = eventData.substring(130, 194)
//               hexStrEquals(message, revertMessage).should.be.eq(true, web3.toAscii(message))
//             })
//           })
//         })
//       })
//
//       describe('signals to throw with a message', async () => {
//
//         let revertCalldata
//
//         beforeEach(async () => {
//           revertCalldata = await appMockUtil.throws1.call(throwMessage, senderContext)
//           revertCalldata.should.not.eq('0x0')
//         })
//
//         it('should throw', async () => {
//           await scriptExec.exec(
//             target, revertCalldata,
//             { from: sender }
//           ).should.not.be.fulfilled
//         })
//       })
//
//       describe('signals to throw incorrectly', async () => {
//
//         let revertCalldata
//
//         beforeEach(async () => {
//           revertCalldata = await appMockUtil.throws2.call(throwMessage, senderContext)
//           revertCalldata.should.not.eq('0x0')
//         })
//
//         it('should throw', async () => {
//           await scriptExec.exec(
//             target, revertCalldata,
//             { from: sender }
//           ).should.not.be.fulfilled
//         })
//       })
//     })
//
//     describe('InvalidApp (app returns malformed data)', async () => {
//
//       let invalidCalldata
//
//       beforeEach(async () => {
//         target = invalidApp.address
//       })
//
//       describe('app attempts to pay storage contract', async () => {
//
//         let execContext
//
//         beforeEach(async () => {
//           execContext = await testUtils.getContextFromAddr.call(
//             executionID, sender, payouts[0]
//           ).should.be.fulfilled
//           execContext.should.not.eq('0x0')
//           invalidCalldata = await appMockUtil.inv1.call(execContext)
//           invalidCalldata.should.not.eq('0x0')
//         })
//
//         it('should throw', async () => {
//           await scriptExec.exec(
//             target, invalidCalldata,
//             { from: sender, value: payouts[0] }
//           ).should.not.be.fulfilled
//         })
//       })
//
//       describe('app does not change state', async () => {
//
//         beforeEach(async () => {
//           invalidCalldata = await appMockUtil.inv2.call(senderContext)
//           invalidCalldata.should.not.eq('0x0')
//         })
//
//         it('should throw', async () => {
//           await scriptExec.exec(
//             target, invalidCalldata,
//             { from: sender }
//           ).should.not.be.fulfilled
//         })
//       })
//     })
//
//     describe('StdApp (app stores data)', async () => {
//
//       let returnData
//       let execEvents
//
//       beforeEach(async () => {
//         target = stdApp.address
//       })
//
//       describe('storing to 0 slots', async () => {
//
//         let invalidCalldata
//
//         beforeEach(async () => {
//           expectedStatus = false
//
//           invalidCalldata = await appMockUtil.std0.call(senderContext)
//           invalidCalldata.should.not.eq('0x0')
//         })
//
//         it('should throw', async () => {
//           await scriptExec.exec(
//             target, invalidCalldata,
//             { from: sender }
//           ).should.not.be.fulfilled
//         })
//       })
//
//       describe('storing to one slot', async () => {
//
//         let calldata
//
//         beforeEach(async () => {
//           expectedStatus = true
//           calldata = await appMockUtil.std1.call(
//             storageLocations[0], storageValues[0], senderContext
//           )
//           calldata.should.not.eq('0x0')
//
//           returnData = await scriptExec.exec.call(
//             target, calldata,
//             { from: sender }
//           ).should.be.fulfilled
//
//           execEvents = await scriptExec.exec(
//             target, calldata,
//             { from: sender }
//           ).should.be.fulfilled.then((tx) => {
//             return tx.receipt.logs
//           })
//         })
//
//         describe('returned data', async () => {
//
//           it('should return the expected status', async () => {
//             returnData.should.be.eq(expectedStatus)
//           })
//         })
//
//         describe('events', async () => {
//
//           it('should have emitted 1 event total', async () => {
//             execEvents.length.should.be.eq(1)
//           })
//
//           describe('the ApplicationExecution event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = execEvents[0].topics
//               eventData = execEvents[0].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(3)
//             })
//
//             it('should list the correct event signature in the first topic', async () => {
//               let sig = eventTopics[0]
//               web3.toDecimal(sig).should.be.eq(web3.toDecimal(execHash))
//             })
//
//             it('should have the target app address and execution id as the other 2 topics', async () => {
//               let emittedAddr = eventTopics[2]
//               let emittedExecId = eventTopics[1]
//               web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(target))
//               web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(executionID))
//             })
//
//             it('should have an empty data field', async () => {
//               eventData.should.be.eq('0x0')
//             })
//           })
//         })
//
//         describe('storage', async () => {
//
//           it('should have correctly stored the value at the location', async () => {
//             let readValue = await storage.read.call(executionID, storageLocations[0])
//             hexStrEquals(readValue, storageValues[0]).should.be.eq(true, readValue)
//           })
//         })
//       })
//
//       describe('storing to 2 slots', async () => {
//
//         let calldata
//
//         beforeEach(async () => {
//           expectedStatus = true
//           calldata = await appMockUtil.std2.call(
//             storageLocations[0], storageValues[0],
//             storageLocations[1], storageValues[1],
//             senderContext
//           )
//           calldata.should.not.eq('0x0')
//
//           returnData = await scriptExec.exec.call(
//             target, calldata,
//             { from: sender }
//           ).should.be.fulfilled
//
//           execEvents = await scriptExec.exec(
//             target, calldata,
//             { from: sender }
//           ).should.be.fulfilled.then((tx) => {
//             return tx.receipt.logs
//           })
//         })
//
//         describe('returned data', async () => {
//
//           it('should return the expected status', async () => {
//             returnData.should.be.eq(expectedStatus)
//           })
//         })
//
//         describe('events', async () => {
//
//           it('should have emitted 1 event total', async () => {
//             execEvents.length.should.be.eq(1)
//           })
//
//           describe('the ApplicationExecution event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = execEvents[0].topics
//               eventData = execEvents[0].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(3)
//             })
//
//             it('should list the correct event signature in the first topic', async () => {
//               let sig = eventTopics[0]
//               web3.toDecimal(sig).should.be.eq(web3.toDecimal(execHash))
//             })
//
//             it('should have the target app address and execution id as the other 2 topics', async () => {
//               let emittedAddr = eventTopics[2]
//               let emittedExecId = eventTopics[1]
//               web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(target))
//               web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(executionID))
//             })
//
//             it('should have an empty data field', async () => {
//               eventData.should.be.eq('0x0')
//             })
//           })
//         })
//
//         describe('storage', async () => {
//
//           it('should have correctly stored the value at the first location', async () => {
//             let readValue = await storage.read.call(executionID, storageLocations[0])
//             hexStrEquals(readValue, storageValues[0]).should.be.eq(true)
//           })
//
//           it('should have correctly stored the value at the second location', async () => {
//             let readValue = await storage.read.call(executionID, storageLocations[1])
//             hexStrEquals(readValue, storageValues[1]).should.be.eq(true)
//           })
//         })
//       })
//     })
//
//     // Note: All PAYS action cause non-payable applications to fail
//     describe('PayableApp (forwards ETH)', async () => {
//
//       let calldata
//       let returnData
//       let execEvents
//
//       beforeEach(async () => {
//         target = payableApp.address
//       })
//
//       describe('pays out to 0 addresses', async () => {
//
//         let invalidCalldata
//         let invalidContext
//
//         beforeEach(async () => {
//           invalidContext = await testUtils.getContextFromAddr.call(
//             executionID, sender, payouts[0]
//           ).should.be.fulfilled
//           invalidContext.should.not.eq('0x0')
//
//           invalidCalldata = await appMockUtil.pay0.call(invalidContext)
//           invalidCalldata.should.not.eq('0x0')
//         })
//
//         it('should throw', async () => {
//           await scriptExec.exec(
//             target, invalidCalldata,
//             { from: sender, value: payouts[0] }
//           ).should.not.be.fulfilled
//         })
//       })
//
//       describe('pays out to 1 address', async () => {
//
//         let initPayeeBalance = 0
//         let senderPayContext
//
//         beforeEach(async () => {
//           senderPayContext = await testUtils.getContextFromAddr.call(
//             executionID, sender, payouts[0]
//           ).should.be.fulfilled
//           senderPayContext.should.not.eq('0x0')
//
//           calldata = await appMockUtil.pay1.call(
//             payees[0], payouts[0], senderPayContext
//           )
//           calldata.should.not.eq('0x0')
//         })
//
//         it('should throw', async () => {
//           await scriptExec.exec(
//             target, calldata,
//             { from: sender, value: payouts[0] }
//           ).should.not.be.fulfilled
//         })
//       })
//
//       describe('pays out to 2 addresses', async () => {
//
//         let initPayeeBalances = [0, 0]
//         let totalPayout
//
//         let senderPayContext
//
//         beforeEach(async () => {
//           totalPayout = payouts[0] + payouts[1]
//
//           senderPayContext = await testUtils.getContextFromAddr.call(
//             executionID, sender, totalPayout
//           ).should.be.fulfilled
//           senderPayContext.should.not.eq('0x0')
//
//           calldata = await appMockUtil.pay2.call(
//             payees[0], payouts[0], payees[1], payouts[1],
//             senderPayContext
//           )
//           calldata.should.not.eq('0x0')
//         })
//
//         it('should throw', async () => {
//           await scriptExec.exec(
//             target, calldata,
//             { from: sender, value: totalPayout }
//           ).should.not.be.fulfilled
//         })
//       })
//     })
//
//     describe('EmitsApp (app emits events)', async () => {
//
//       let calldata
//       let returnData
//       let execEvents
//
//       beforeEach(async () => {
//         target = emitApp.address
//       })
//
//       describe('emitting 0 events', async () => {
//
//         let invalidCalldata
//
//         beforeEach(async () => {
//           invalidCalldata = await appMockUtil.emit0.call(senderContext)
//           invalidCalldata.should.not.eq('0x0')
//         })
//
//         it('should throw', async () => {
//           await scriptExec.exec(
//             target, invalidCalldata,
//             { from: sender }
//           ).should.not.be.fulfilled
//         })
//       })
//
//       describe('emitting 1 event with no topics or data', async () => {
//
//         beforeEach(async () => {
//           expectedStatus = true
//           calldata = await appMockUtil.emit1top0.call(senderContext)
//           calldata.should.not.eq('0x0')
//
//           returnData = await scriptExec.exec.call(
//             target, calldata,
//             { from: sender }
//           ).should.be.fulfilled
//
//           execEvents = await scriptExec.exec(
//             target, calldata,
//             { from: sender }
//           ).should.be.fulfilled.then((tx) => {
//             return tx.receipt.logs
//           })
//         })
//
//         describe('returned data', async () => {
//
//           it('should return the expected status', async () => {
//             returnData.should.be.eq(expectedStatus)
//           })
//         })
//
//         describe('events', async () => {
//
//           it('should have emitted 2 events total', async () => {
//             execEvents.length.should.be.eq(2)
//           })
//
//           describe('the ApplicationExecution event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = execEvents[1].topics
//               eventData = execEvents[1].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(3)
//             })
//
//             it('should list the correct event signature in the first topic', async () => {
//               let sig = eventTopics[0]
//               web3.toDecimal(sig).should.be.eq(web3.toDecimal(execHash))
//             })
//
//             it('should have the target app address and execution id as the other 2 topics', async () => {
//               let emittedAddr = eventTopics[2]
//               let emittedExecId = eventTopics[1]
//               web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(target))
//               web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(executionID))
//             })
//
//             it('should have an empty data field', async () => {
//               eventData.should.be.eq('0x0')
//             })
//           })
//
//           describe('the other event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = execEvents[0].topics
//               eventData = execEvents[0].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(0)
//             })
//
//             it('should have an empty data field', async () => {
//               eventData.should.be.eq('0x0')
//             })
//           })
//         })
//       })
//
//       describe('emitting 1 event with no topics with data', async () => {
//
//         beforeEach(async () => {
//           expectedStatus = true
//           calldata = await appMockUtil.emit1top0data.call(senderContext)
//           calldata.should.not.eq('0x0')
//
//           returnData = await scriptExec.exec.call(
//             target, calldata,
//             { from: sender }
//           ).should.be.fulfilled
//
//           execEvents = await scriptExec.exec(
//             target, calldata,
//             { from: sender }
//           ).should.be.fulfilled.then((tx) => {
//             return tx.receipt.logs
//           })
//         })
//
//         describe('returned data', async () => {
//
//           it('should return the expected status', async () => {
//             returnData.should.be.eq(expectedStatus)
//           })
//         })
//
//         describe('events', async () => {
//
//           it('should have emitted 2 events total', async () => {
//             execEvents.length.should.be.eq(2)
//           })
//
//           describe('the ApplicationExecution event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = execEvents[1].topics
//               eventData = execEvents[1].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(3)
//             })
//
//             it('should list the correct event signature in the first topic', async () => {
//               let sig = eventTopics[0]
//               web3.toDecimal(sig).should.be.eq(web3.toDecimal(execHash))
//             })
//
//             it('should have the target app address and execution id as the other 2 topics', async () => {
//               let emittedAddr = eventTopics[2]
//               let emittedExecId = eventTopics[1]
//               web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(target))
//               web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(executionID))
//             })
//
//             it('should have an empty data field', async () => {
//               eventData.should.be.eq('0x0')
//             })
//           })
//
//           describe('the other event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = execEvents[0].topics
//               eventData = execEvents[0].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(0)
//             })
//
//             it('should have a data field matching the sender context', async () => {
//               web3.toDecimal(eventData).should.be.eq(web3.toDecimal(senderContext))
//             })
//           })
//         })
//       })
//
//       describe('emitting 1 event with 4 topics with data', async () => {
//
//         beforeEach(async () => {
//           expectedStatus = true
//           calldata = await appMockUtil.emit1top4data.call(
//             emitTopics[0], emitTopics[1], emitTopics[2], emitTopics[3],
//             senderContext
//           )
//           calldata.should.not.eq('0x0')
//
//           returnData = await scriptExec.exec.call(
//             target, calldata,
//             { from: sender }
//           ).should.be.fulfilled
//
//           execEvents = await scriptExec.exec(
//             target, calldata,
//             { from: sender }
//           ).should.be.fulfilled.then((tx) => {
//             return tx.receipt.logs
//           })
//         })
//
//         describe('returned data', async () => {
//
//           it('should return the expected status', async () => {
//             returnData.should.be.eq(expectedStatus)
//           })
//         })
//
//         describe('events', async () => {
//
//           it('should have emitted 2 events total', async () => {
//             execEvents.length.should.be.eq(2)
//           })
//
//           describe('the ApplicationExecution event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = execEvents[1].topics
//               eventData = execEvents[1].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(3)
//             })
//
//             it('should list the correct event signature in the first topic', async () => {
//               let sig = eventTopics[0]
//               web3.toDecimal(sig).should.be.eq(web3.toDecimal(execHash))
//             })
//
//             it('should have the target app address and execution id as the other 2 topics', async () => {
//               let emittedAddr = eventTopics[2]
//               let emittedExecId = eventTopics[1]
//               web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(target))
//               web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(executionID))
//             })
//
//             it('should have an empty data field', async () => {
//               eventData.should.be.eq('0x0')
//             })
//           })
//
//           describe('the other event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = execEvents[0].topics
//               eventData = execEvents[0].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(4)
//             })
//
//             it('should match the topics sent', async () => {
//               hexStrEquals(eventTopics[0], emitTopics[0]).should.be.eq(true)
//               hexStrEquals(eventTopics[1], emitTopics[1]).should.be.eq(true)
//               hexStrEquals(eventTopics[2], emitTopics[2]).should.be.eq(true)
//               hexStrEquals(eventTopics[3], emitTopics[3]).should.be.eq(true)
//             })
//
//             it('should have a data field matching the sender context', async () => {
//               web3.toDecimal(eventData).should.be.eq(web3.toDecimal(senderContext))
//             })
//           })
//         })
//       })
//
//       describe('emitting 2 events, each with 1 topic and data', async () => {
//
//         beforeEach(async () => {
//           expectedStatus = true
//           calldata = await appMockUtil.emit2top1data.call(
//             emitTopics[0], senderContext
//           )
//           calldata.should.not.eq('0x0')
//
//           returnData = await scriptExec.exec.call(
//             target, calldata,
//             { from: sender }
//           ).should.be.fulfilled
//
//           execEvents = await scriptExec.exec(
//             target, calldata,
//             { from: sender }
//           ).should.be.fulfilled.then((tx) => {
//             return tx.receipt.logs
//           })
//         })
//
//         describe('returned data', async () => {
//
//           it('should return the expected status', async () => {
//             returnData.should.be.eq(expectedStatus)
//           })
//         })
//
//         describe('events', async () => {
//
//           it('should have emitted 3 events total', async () => {
//             execEvents.length.should.be.eq(3)
//           })
//
//           describe('the ApplicationExecution event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = execEvents[2].topics
//               eventData = execEvents[2].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(3)
//             })
//
//             it('should list the correct event signature in the first topic', async () => {
//               let sig = eventTopics[0]
//               web3.toDecimal(sig).should.be.eq(web3.toDecimal(execHash))
//             })
//
//             it('should have the target app address and execution id as the other 2 topics', async () => {
//               let emittedAddr = eventTopics[2]
//               let emittedExecId = eventTopics[1]
//               web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(target))
//               web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(executionID))
//             })
//
//             it('should have an empty data field', async () => {
//               eventData.should.be.eq('0x0')
//             })
//           })
//
//           describe('the other events', async () => {
//
//             let eventTopicsA
//             let eventDataA
//             let eventTopicsB
//             let eventDataB
//
//             beforeEach(async () => {
//               eventTopicsA = execEvents[0].topics
//               eventDataA = execEvents[0].data
//               eventTopicsB = execEvents[1].topics
//               eventDataB = execEvents[1].data
//             })
//
//             it('should both have the correct number of topics', async () => {
//               eventTopicsA.length.should.be.eq(1)
//               eventTopicsB.length.should.be.eq(1)
//             })
//
//             it('should both match the topics sent', async () => {
//               hexStrEquals(eventTopicsA[0], emitTopics[0]).should.be.eq(true)
//               let appTopics2Hex = web3.toHex(
//                 web3.toBigNumber(eventTopicsB[0]).minus(1)
//               )
//               hexStrEquals(appTopics2Hex, emitTopics[0]).should.be.eq(true)
//             })
//
//             it('should both have a data field matching the sender context', async () => {
//               web3.toDecimal(eventDataA).should.be.eq(web3.toDecimal(senderContext))
//               web3.toDecimal(eventDataB).should.be.eq(web3.toDecimal(senderContext))
//             })
//           })
//         })
//       })
//
//       describe('emitting 2 events, each with 4 topics and no data', async () => {
//
//         beforeEach(async () => {
//           expectedStatus = true
//           calldata = await appMockUtil.emit2top4.call(
//             emitTopics[0], emitTopics[1], emitTopics[2], emitTopics[3],
//             senderContext
//           )
//           calldata.should.not.eq('0x0')
//
//           returnData = await scriptExec.exec.call(
//             target, calldata,
//             { from: sender }
//           ).should.be.fulfilled
//
//           execEvents = await scriptExec.exec(
//             target, calldata,
//             { from: sender }
//           ).should.be.fulfilled.then((tx) => {
//             return tx.receipt.logs
//           })
//         })
//
//         describe('returned data', async () => {
//
//           it('should return the expected status', async () => {
//             returnData.should.be.eq(expectedStatus)
//           })
//         })
//
//         describe('events', async () => {
//
//           it('should have emitted 3 events total', async () => {
//             execEvents.length.should.be.eq(3)
//           })
//
//           describe('the ApplicationExecution event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = execEvents[2].topics
//               eventData = execEvents[2].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(3)
//             })
//
//             it('should list the correct event signature in the first topic', async () => {
//               let sig = eventTopics[0]
//               web3.toDecimal(sig).should.be.eq(web3.toDecimal(execHash))
//             })
//
//             it('should have the target app address and execution id as the other 2 topics', async () => {
//               let emittedAddr = eventTopics[2]
//               let emittedExecId = eventTopics[1]
//               web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(target))
//               web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(executionID))
//             })
//
//             it('should have an empty data field', async () => {
//               eventData.should.be.eq('0x0')
//             })
//           })
//
//           describe('the other events', async () => {
//
//             let eventTopicsA
//             let eventDataA
//             let eventTopicsB
//             let eventDataB
//
//             beforeEach(async () => {
//               eventTopicsA = execEvents[0].topics
//               eventDataA = execEvents[0].data
//               eventTopicsB = execEvents[1].topics
//               eventDataB = execEvents[1].data
//             })
//
//             it('should both have the correct number of topics', async () => {
//               eventTopicsA.length.should.be.eq(4)
//               eventTopicsB.length.should.be.eq(4)
//             })
//
//             it('should both match the topics sent', async () => {
//               // First topic, both events
//               hexStrEquals(eventTopicsA[0], emitTopics[0]).should.be.eq(true)
//               let topicHex = web3.toHex(web3.toBigNumber(eventTopicsB[0]).minus(1))
//               hexStrEquals(topicHex, emitTopics[0]).should.be.eq(true)
//               // Second topic, both events
//               hexStrEquals(eventTopicsA[1], emitTopics[1]).should.be.eq(true)
//               topicHex = web3.toHex(web3.toBigNumber(eventTopicsB[1]).minus(1))
//               hexStrEquals(topicHex, emitTopics[1]).should.be.eq(true)
//               // Third topic, both events
//               hexStrEquals(eventTopicsA[2], emitTopics[2]).should.be.eq(true)
//               topicHex = web3.toHex(web3.toBigNumber(eventTopicsB[2]).minus(1))
//               hexStrEquals(topicHex, emitTopics[2]).should.be.eq(true)
//               // Fourth topic, both events
//               hexStrEquals(eventTopicsA[3], emitTopics[3]).should.be.eq(true)
//               topicHex = web3.toHex(web3.toBigNumber(eventTopicsB[3]).minus(1))
//               hexStrEquals(topicHex, emitTopics[3]).should.be.eq(true)
//             })
//
//             it('should both have an empty data field', async () => {
//               eventDataA.should.be.eq('0x0')
//               eventDataB.should.be.eq('0x0')
//             })
//           })
//         })
//       })
//     })
//
//     // Note: All PAYS action cause non-payable applications to fail
//     describe('MixedApp (app requests various actions from storage. order/amt not vary)', async () => {
//
//       let calldata
//       let returnData
//       let execEvents
//
//       beforeEach(async () => {
//         expectedStatus = true
//         target = mixApp.address
//       })
//
//       describe('2 actions (EMITS 1, THROWS)', async () => {
//
//         let invalidCalldata
//
//         beforeEach(async () => {
//           invalidCalldata = await appMockUtil.req0.call(emitTopics[0], senderContext)
//           invalidCalldata.should.not.eq('0x0')
//         })
//
//         it('should throw', async () => {
//           await scriptExec.exec(
//             target, invalidCalldata,
//             { from: sender }
//           ).should.not.be.fulfilled
//         })
//       })
//
//       describe('2 actions (PAYS 1, STORES 1)', async () => {
//
//         let senderPayContext
//
//         beforeEach(async () => {
//           senderPayContext = await testUtils.getContextFromAddr.call(
//             executionID, sender, payouts[0]
//           ).should.be.fulfilled
//           senderPayContext.should.not.eq('0x0')
//
//           calldata = await appMockUtil.req1.call(
//             payees[0], payouts[0], storageLocations[0], storageValues[0],
//             senderPayContext
//           )
//           calldata.should.not.eq('0x0')
//         })
//
//         it('should throw', async () => {
//           await scriptExec.exec(
//             target, calldata,
//             { from: sender, value: payouts[0] }
//           ).should.not.be.fulfilled
//         })
//       })
//
//       describe('2 actions (EMITS 1, STORES 1)', async () => {
//
//         beforeEach(async () => {
//           calldata = await appMockUtil.req2.call(
//             emitTopics[0], storageLocations[0], storageValues[0],
//             senderContext
//           )
//           calldata.should.not.eq('0x0')
//
//           returnData = await scriptExec.exec.call(
//             target, calldata,
//             { from: sender }
//           ).should.be.fulfilled
//
//           execEvents = await scriptExec.exec(
//             target, calldata,
//             { from: sender }
//           ).should.be.fulfilled.then((tx) => {
//             return tx.receipt.logs
//           })
//         })
//
//         describe('returned data', async () => {
//
//           it('should return the expected status', async () => {
//             returnData.should.be.eq(expectedStatus)
//           })
//         })
//
//         describe('events', async () => {
//
//           it('should have emitted 2 events total', async () => {
//             execEvents.length.should.be.eq(2)
//           })
//
//           describe('the ApplicationExecution event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = execEvents[1].topics
//               eventData = execEvents[1].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(3)
//             })
//
//             it('should list the correct event signature in the first topic', async () => {
//               let sig = eventTopics[0]
//               web3.toDecimal(sig).should.be.eq(web3.toDecimal(execHash))
//             })
//
//             it('should have the target app address and execution id as the other 2 topics', async () => {
//               let emittedAddr = eventTopics[2]
//               let emittedExecId = eventTopics[1]
//               web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(target))
//               web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(executionID))
//             })
//
//             it('should have an empty data field', async () => {
//               eventData.should.be.eq('0x0')
//             })
//           })
//
//           describe('the other event', async () => {
//
//             let eventTopics
//             let eventData
//
//             beforeEach(async () => {
//               eventTopics = execEvents[0].topics
//               eventData = execEvents[0].data
//             })
//
//             it('should have the correct number of topics', async () => {
//               eventTopics.length.should.be.eq(1)
//             })
//
//             it('should match the expected topics', async () => {
//               hexStrEquals(eventTopics[0], emitTopics[0]).should.be.eq(true)
//             })
//
//             it('should have an empty data field', async () => {
//               eventData.should.be.eq('0x0')
//             })
//           })
//         })
//
//         describe('storage', async () => {
//
//           it('should have correctly stored the value at the location', async () => {
//             let readValue = await storage.read.call(executionID, storageLocations[0])
//             hexStrEquals(readValue, storageValues[0]).should.be.eq(true)
//           })
//         })
//       })
//
//       describe('2 actions (PAYS 1, EMITS 1)', async () => {
//
//         let senderPayContext
//
//         beforeEach(async () => {
//           senderPayContext = await testUtils.getContextFromAddr.call(
//             executionID, sender, payouts[0]
//           ).should.be.fulfilled
//           senderPayContext.should.not.eq('0x0')
//
//           calldata = await appMockUtil.req3.call(
//             payees[0], payouts[0], emitTopics[0],
//             senderPayContext
//           )
//           calldata.should.not.eq('0x0')
//         })
//
//         it('should throw', async () => {
//           await scriptExec.exec(
//             target, calldata,
//             { from: sender, value: payouts[0] }
//           ).should.not.be.fulfilled
//         })
//       })
//
//       describe('3 actions (PAYS 2, EMITS 1, THROWS)', async () => {
//
//         let invalidCalldata
//         let senderPayContext
//
//         beforeEach(async () => {
//           senderPayContext = await testUtils.getContextFromAddr.call(
//             executionID, sender, payouts[0]
//           ).should.be.fulfilled
//           senderPayContext.should.not.eq('0x0')
//
//           invalidCalldata = await appMockUtil.reqs0.call(
//             payees[0], payouts[0], payees[1], payouts[1],
//             emitTopics[0], senderPayContext
//           )
//           invalidCalldata.should.not.eq('0x0')
//         })
//
//         it('should throw', async () => {
//           await scriptExec.exec(
//             target, invalidCalldata,
//             { from: sender, value: payouts[0] }
//           ).should.not.be.fulfilled
//         })
//       })
//
//       describe('3 actions (EMITS 2, PAYS 1, STORES 2)', async () => {
//
//         let senderPayContext
//
//         beforeEach(async () => {
//           senderPayContext = await testUtils.getContextFromAddr.call(
//             executionID, sender, payouts[0]
//           ).should.be.fulfilled
//           senderPayContext.should.not.eq('0x0')
//
//           calldata = await appMockUtil.reqs1.call(
//             payees[0], payouts[0],
//             storageLocations[0], storageValues[0],
//             storageLocations[1], storageValues[1],
//             senderPayContext
//           )
//           calldata.should.not.eq('0x0')
//         })
//
//         it('should throw', async () => {
//           await scriptExec.exec(
//             target, calldata,
//             { from: sender, value: payouts[0] }
//           ).should.not.be.fulfilled
//         })
//       })
//
//       describe('3 actions (PAYS 1, EMITS 3, STORES 1)', async () => {
//
//         let senderPayContext
//
//         beforeEach(async () => {
//           senderPayContext = await testUtils.getContextFromAddr.call(
//             executionID, sender, payouts[0]
//           ).should.be.fulfilled
//           senderPayContext.should.not.eq('0x0')
//
//           calldata = await appMockUtil.reqs2.call(
//             payees[0], payouts[0], emitTopics,
//             storageLocations[0], storageValues[0],
//             senderPayContext
//           )
//           calldata.should.not.eq('0x0')
//         })
//
//         it('should throw', async () => {
//           await scriptExec.exec(
//             target, calldata,
//             { from: sender, value: payouts[0] }
//           ).should.not.be.fulfilled
//         })
//       })
//
//       describe('3 actions (STORES 2, PAYS 1, EMITS 1)', async () => {
//
//         let senderPayContext
//
//         beforeEach(async () => {
//           senderPayContext = await testUtils.getContextFromAddr.call(
//             executionID, sender, payouts[0]
//           ).should.be.fulfilled
//           senderPayContext.should.not.eq('0x0')
//
//           calldata = await appMockUtil.reqs3.call(
//             payees[0], payouts[0], emitTopics[0],
//             storageLocations[0], storageValues[0],
//             storageLocations[1], storageValues[1],
//             senderPayContext
//           )
//           calldata.should.not.eq('0x0')
//         })
//
//         it('should throw', async () => {
//           await scriptExec.exec(
//             target, calldata,
//             { from: sender, value: payouts[0] }
//           ).should.not.be.fulfilled
//         })
//       })
//     })
//   })
//
//   describe('#initAppInstance', async () => {
//
//     let registryExecID
//     let providerContext
//
//     let appName = 'AppName1'
//     let appDesc = 'Application description'
//     let verDescOne = 'version description 1'
//     let versionNameOne = 'v0.0.1'
//     let initDescOne = 'init description'
//     let versionNameTwo = 'v0.0.2'
//
//     let registerAppCalldata
//     let registerVersionOneCalldata
//     let registerVersionTwoCalldata
//     let addFunctionsCalldata
//     let finalizeOneCalldata
//
//     beforeEach(async () => {
//       let events = await storage.initAndFinalize(
//         updater, false, initRegistry.address, initCalldata, registryAllowed,
//         { from: provider }
//       ).should.be.fulfilled.then((tx) => {
//         return tx.logs
//       })
//       events.should.not.eq(null)
//       events.length.should.be.eq(2)
//       events[0].event.should.be.eq('ApplicationInitialized')
//       events[1].event.should.be.eq('ApplicationFinalization')
//       registryExecID = events[1].args['execution_id']
//       web3.toDecimal(registryExecID).should.not.eq(0)
//
//       await scriptExec.changeRegistryExecId(registryExecID, { from: execAdmin }).should.be.fulfilled
//
//       providerContext = await testUtils.getContextFromAddr.call(
//         registryExecID, provider, 0
//       ).should.be.fulfilled
//       providerContext.should.not.eq('0x0')
//
//       registerAppCalldata = await registryUtil.registerApp.call(
//         appName, storage.address, appDesc, providerContext
//       ).should.be.fulfilled
//       registerAppCalldata.should.not.eq('0x0')
//
//       registerVersionOneCalldata = await registryUtil.registerVersion.call(
//         appName, versionNameOne, storage.address, verDescOne, providerContext
//       ).should.be.fulfilled
//       registerVersionOneCalldata.should.not.eq('0x0')
//
//       addFunctionsCalldata = await registryUtil.addFunctions.call(
//         appName, versionNameOne, ['0xdeadbeef', '0xdeadbeef', '0xdeadbeef'],
//         [payableApp.address, stdApp.address, emitApp.address],
//         providerContext
//       ).should.be.fulfilled
//       addFunctionsCalldata.should.not.eq('0x0')
//
//       finalizeOneCalldata = await registryUtil.finalizeVersion.call(
//         appName, versionNameOne, appInit.address, ['0xdeadbeef'], initDescOne,
//         providerContext
//       ).should.be.fulfilled
//       finalizeOneCalldata.should.not.eq('0x0')
//
//       events = await storage.exec(
//         appConsole.address, registryExecID, registerAppCalldata,
//         { from: provider }
//       ).then((tx) => {
//         return tx.logs
//       })
//       events.should.not.eq(null)
//       events.length.should.be.eq(1)
//       events[0].event.should.be.eq('ApplicationExecution')
//
//       events = await storage.exec(
//         versionConsole.address, registryExecID, registerVersionOneCalldata,
//         { from: provider }
//       ).then((tx) => {
//         return tx.logs
//       })
//       events.should.not.eq(null)
//       events.length.should.be.eq(1)
//       events[0].event.should.be.eq('ApplicationExecution')
//
//       events = await storage.exec(
//         implConsole.address, registryExecID, addFunctionsCalldata,
//         { from: provider }
//       ).then((tx) => {
//         return tx.logs
//       })
//       events.should.not.eq(null)
//       events.length.should.be.eq(1)
//       events[0].event.should.be.eq('ApplicationExecution')
//     })
//
//     describe('pre-test storage', async () => {
//
//       it('should have registered the app', async () => {
//         let appInfo = await initRegistry.getAppInfo.call(
//           storage.address, registryExecID, providerID, appName
//         ).should.be.fulfilled
//         appInfo.length.should.be.eq(3)
//         appInfo[0].toNumber().should.be.eq(1)
//         appInfo[1].should.be.eq(storage.address)
//         hexStrEquals(appInfo[2], appDesc).should.be.eq(true)
//       })
//
//       it('should have registered the version', async () => {
//         let verInfo = await initRegistry.getVersionInfo.call(
//           storage.address, registryExecID, providerID, appName, versionNameOne
//         ).should.be.fulfilled
//         verInfo.length.should.be.eq(4)
//         verInfo[0].should.be.eq(false)
//         verInfo[1].toNumber().should.be.eq(3)
//         verInfo[2].should.be.eq(storage.address)
//         hexStrEquals(verInfo[3], verDescOne).should.be.eq(true)
//       })
//     })
//
//     context('app does not exist in script registry', async () => {
//
//       let invalidAppName = 'invalid'
//
//       it('should throw', async () => {
//         await scriptExec.initAppInstance(
//           invalidAppName, false, initCalldata,
//           { from: execAdmin }
//         ).should.not.be.fulfilled
//       })
//     })
//
//     context('app does not have a stable version in script registry', async () => {
//
//       it('should throw', async () => {
//         await scriptExec.initAppInstance(
//           appName, false, initCalldata,
//           { from: execAdmin }
//         ).should.not.be.fulfilled
//       })
//     })
//
//     context('app name is invalid', async () => {
//
//       let invalidAppName = ''
//
//       it('should throw', async () => {
//         let events = await storage.exec(
//           versionConsole.address, registryExecID, finalizeOneCalldata,
//           { from: provider }
//         ).then((tx) => {
//           return tx.logs
//         })
//         events.should.not.eq(null)
//         events.length.should.be.eq(1)
//         events[0].event.should.be.eq('ApplicationExecution')
//
//         await scriptExec.initAppInstance(
//           invalidAppName, false, initCalldata,
//           { from: execAdmin }
//         ).should.not.be.fulfilled
//       })
//     })
//
//     context('app init calldata is too short', async () => {
//
//       let invalidCalldata = '0xaabb'
//
//       it('should throw', async () => {
//         let events = await storage.exec(
//           versionConsole.address, registryExecID, finalizeOneCalldata,
//           { from: provider }
//         ).then((tx) => {
//           return tx.logs
//         })
//         events.should.not.eq(null)
//         events.length.should.be.eq(1)
//         events[0].event.should.be.eq('ApplicationExecution')
//
//         await scriptExec.initAppInstance(
//           appName, false, invalidCalldata,
//           { from: execAdmin }
//         ).should.not.be.fulfilled
//       })
//     })
//
//     context('init function returns an EMITS action', async () => {
//
//       let initEmitCalldata
//
//       let returnedExecID
//       let execEvents
//
//       let senderNewContext
//
//       beforeEach(async () => {
//         let events = await storage.exec(
//           versionConsole.address, registryExecID, finalizeOneCalldata,
//           { from: provider }
//         ).then((tx) => {
//           return tx.logs
//         })
//         events.should.not.eq(null)
//         events.length.should.be.eq(1)
//         events[0].event.should.be.eq('ApplicationExecution')
//
//         initEmitCalldata = await appInitUtil.initEmits.call(emitTopics[0])
//         initEmitCalldata.should.not.eq('0x0')
//
//         let returnedData = await scriptExec.initAppInstance.call(
//          appName, true, initEmitCalldata,
//          { from: sender }
//         ).should.be.fulfilled
//         returnedData.length.should.be.eq(2)
//         hexStrEquals(returnedData[0], versionNameOne).should.be.eq(true)
//         returnedExecID = returnedData[1]
//
//         execEvents = await scriptExec.initAppInstance(
//           appName, true, initEmitCalldata,
//           { from: sender }
//         ).then((tx) => {
//           return tx.receipt.logs
//         })
//
//         senderNewContext = await testUtils.getContextFromAddr.call(
//           returnedExecID, sender, 0
//         ).should.be.fulfilled
//         senderNewContext.should.not.eq('0x0')
//       })
//
//       describe('returned data', async () => {
//
//         it('should return a nonzero exec id', async () => {
//           web3.toDecimal(returnedExecID).should.not.eq(0)
//         })
//       })
//
//       describe('events', async () => {
//
//         it('should have emitted 4 events total', async () => {
//           execEvents.length.should.be.eq(4)
//         })
//
//         describe('the ApplicationInitialized event', async () => {
//
//           let eventTopics
//           let eventData
//
//           beforeEach(async () => {
//             eventTopics = execEvents[1].topics
//             eventData = execEvents[1].data
//           })
//
//           it('should have the correct number of topics', async () => {
//             eventTopics.length.should.be.eq(3)
//           })
//
//           it('should list the correct event signature in the first topic', async () => {
//             let sig = eventTopics[0]
//             web3.toDecimal(sig).should.be.eq(web3.toDecimal(initHash))
//           })
//
//           it('should have the app init address and execution id as the other 2 topics', async () => {
//             let emittedAddr = eventTopics[2]
//             let emittedExecId = eventTopics[1]
//             web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(appInit.address))
//             web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(returnedExecID))
//           })
//
//           it('should a data field containing the script exec and updater addresses', async () => {
//             let parsedData = await appInitUtil.parseInit.call(eventData).should.be.fulfilled
//             parsedData.length.should.be.eq(2)
//             parsedData[0].should.be.eq(scriptExec.address)
//             parsedData[1].should.be.eq(updater)
//           })
//         })
//
//         describe('the ApplicationFinalization event', async () => {
//
//           let eventTopics
//           let eventData
//
//           beforeEach(async () => {
//             eventTopics = execEvents[2].topics
//             eventData = execEvents[2].data
//           })
//
//           it('should have the correct number of topics', async () => {
//             eventTopics.length.should.be.eq(3)
//           })
//
//           it('should list the correct event signature in the first topic', async () => {
//             let sig = eventTopics[0]
//             web3.toDecimal(sig).should.be.eq(web3.toDecimal(finalHash))
//           })
//
//           it('should have the app init address and execution id as the other 2 topics', async () => {
//             let emittedAddr = eventTopics[2]
//             let emittedExecId = eventTopics[1]
//             web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(appInit.address))
//             web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(returnedExecID))
//           })
//
//           it('should have an empty data field', async () => {
//             eventData.should.be.eq('0x0')
//           })
//         })
//
//         describe('the AppInstanceCreated event', async () => {
//
//           let eventTopics
//           let eventData
//
//           beforeEach(async () => {
//             eventTopics = execEvents[3].topics
//             eventData = execEvents[3].data
//           })
//
//           it('should have the correct number of topics', async () => {
//             eventTopics.length.should.be.eq(3)
//           })
//
//           it('should list the correct event signature in the first topic', async () => {
//             let sig = eventTopics[0]
//             web3.toDecimal(sig).should.be.eq(web3.toDecimal(appInstanceCreatedHash))
//           })
//
//           it('should have the creator address and execution id as the other 2 topics', async () => {
//             let emittedAddr = eventTopics[1]
//             let emittedExecId = eventTopics[2]
//             web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(sender))
//             web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(returnedExecID))
//           })
//
//           it('should have a data field with the app storage address, app name, and version name', async () => {
//             let parsedData = await appInitUtil.parseInstanceCreated.call(eventData).should.be.fulfilled
//             parsedData.length.should.be.eq(3)
//             parsedData[0].should.be.eq(storage.address)
//             hexStrEquals(parsedData[1], appName).should.be.eq(true)
//             hexStrEquals(parsedData[2], versionNameOne).should.be.eq(true)
//           })
//         })
//
//         describe('the other event', async () => {
//
//           let eventTopics
//           let eventData
//
//           beforeEach(async () => {
//             eventTopics = execEvents[0].topics
//             eventData = execEvents[0].data
//           })
//
//           it('should have the correct number of topics', async () => {
//             eventTopics.length.should.be.eq(1)
//           })
//
//           it('should match the topic sent', async () => {
//             hexStrEquals(eventTopics[0], emitTopics[0]).should.be.eq(true)
//           })
//
//           it('should have an empty data field', async () => {
//             eventData.should.be.eq('0x0')
//           })
//         })
//       })
//
//       describe('storage', async () => {
//
//         it('should return valid app info', async () => {
//           let appInfo = await storage.app_info.call(returnedExecID)
//           appInfo.length.should.be.eq(6)
//           appInfo[0].should.be.eq(false)
//           appInfo[1].should.be.eq(true)
//           appInfo[2].should.be.eq(true)
//           appInfo[3].should.be.eq(updater)
//           appInfo[4].should.be.eq(scriptExec.address)
//           appInfo[5].should.be.eq(appInit.address)
//         })
//
//         it('should return a correctly populated allowed address array', async () => {
//           let allowedInfo = await storage.getExecAllowed.call(returnedExecID)
//           allowedInfo.length.should.be.eq(3)
//           allowedInfo[0].should.be.eq(payableApp.address)
//           allowedInfo[1].should.be.eq(stdApp.address)
//           allowedInfo[2].should.be.eq(emitApp.address)
//         })
//       })
//
//       it('should allow execution', async () => {
//         let calldata = await appMockUtil.std1.call(
//           storageLocations[0], storageValues[0], senderNewContext
//         ).should.be.fulfilled
//         calldata.should.not.eq('0x0')
//
//         let events = await scriptExec.exec(
//           stdApp.address, calldata,
//           { from: sender }
//         ).then((tx) => {
//           return tx.receipt.logs
//         })
//         events.should.not.eq(null)
//         events.length.should.be.eq(1)
//       })
//     })
//
//     context('init function returns a PAYS action', async () => {
//
//       let initPaysCalldata
//
//       beforeEach(async () => {
//         let events = await storage.exec(
//           versionConsole.address, registryExecID, finalizeOneCalldata,
//           { from: provider }
//         ).then((tx) => {
//           return tx.logs
//         })
//         events.should.not.eq(null)
//         events.length.should.be.eq(1)
//         events[0].event.should.be.eq('ApplicationExecution')
//
//         initPaysCalldata = await appInit.initPays.call(
//           payees[0], payouts[0]
//         )
//         initPaysCalldata.should.not.eq('0x0')
//       })
//
//       it('should throw', async () => {
//         await scriptExec.initAppInstance(
//           appName, true, initPaysCalldata,
//           { from: sender, value: payouts[0] }
//         ).should.not.be.fulfilled
//       })
//     })
//
//     context('init function returns a STORES action', async () => {
//
//       let initStoresCalldata
//
//       let returnedExecID
//       let execEvents
//
//       let senderNewContext
//
//       beforeEach(async () => {
//         let events = await storage.exec(
//           versionConsole.address, registryExecID, finalizeOneCalldata,
//           { from: provider }
//         ).then((tx) => {
//           return tx.logs
//         })
//         events.should.not.eq(null)
//         events.length.should.be.eq(1)
//         events[0].event.should.be.eq('ApplicationExecution')
//
//         initStoresCalldata = await appInitUtil.initStores.call(
//           storageLocations[0], storageValues[0]
//         )
//         initStoresCalldata.should.not.eq('0x0')
//
//         let returnedData = await scriptExec.initAppInstance.call(
//          appName, true, initStoresCalldata,
//          { from: sender }
//         ).should.be.fulfilled
//         returnedData.length.should.be.eq(2)
//         hexStrEquals(returnedData[0], versionNameOne).should.be.eq(true)
//         returnedExecID = returnedData[1]
//
//         execEvents = await scriptExec.initAppInstance(
//           appName, true, initStoresCalldata,
//           { from: sender }
//         ).then((tx) => {
//           return tx.receipt.logs
//         })
//
//         senderNewContext = await testUtils.getContextFromAddr.call(
//           returnedExecID, sender, 0
//         ).should.be.fulfilled
//         senderNewContext.should.not.eq('0x0')
//       })
//
//       describe('returned data', async () => {
//
//         it('should return a nonzero exec id', async () => {
//           web3.toDecimal(returnedExecID).should.not.eq(0)
//         })
//       })
//
//       describe('events', async () => {
//
//         it('should have emitted 3 events total', async () => {
//           execEvents.length.should.be.eq(3)
//         })
//
//         describe('the ApplicationInitialized event', async () => {
//
//           let eventTopics
//           let eventData
//
//           beforeEach(async () => {
//             eventTopics = execEvents[0].topics
//             eventData = execEvents[0].data
//           })
//
//           it('should have the correct number of topics', async () => {
//             eventTopics.length.should.be.eq(3)
//           })
//
//           it('should list the correct event signature in the first topic', async () => {
//             let sig = eventTopics[0]
//             web3.toDecimal(sig).should.be.eq(web3.toDecimal(initHash))
//           })
//
//           it('should have the app init address and execution id as the other 2 topics', async () => {
//             let emittedAddr = eventTopics[2]
//             let emittedExecId = eventTopics[1]
//             web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(appInit.address))
//             web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(returnedExecID))
//           })
//
//           it('should a data field containing the script exec and updater addresses', async () => {
//             let parsedData = await appInitUtil.parseInit.call(eventData).should.be.fulfilled
//             parsedData.length.should.be.eq(2)
//             parsedData[0].should.be.eq(scriptExec.address)
//             parsedData[1].should.be.eq(updater)
//           })
//         })
//
//         describe('the ApplicationFinalization event', async () => {
//
//           let eventTopics
//           let eventData
//
//           beforeEach(async () => {
//             eventTopics = execEvents[1].topics
//             eventData = execEvents[1].data
//           })
//
//           it('should have the correct number of topics', async () => {
//             eventTopics.length.should.be.eq(3)
//           })
//
//           it('should list the correct event signature in the first topic', async () => {
//             let sig = eventTopics[0]
//             web3.toDecimal(sig).should.be.eq(web3.toDecimal(finalHash))
//           })
//
//           it('should have the app init address and execution id as the other 2 topics', async () => {
//             let emittedAddr = eventTopics[2]
//             let emittedExecId = eventTopics[1]
//             web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(appInit.address))
//             web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(returnedExecID))
//           })
//
//           it('should have an empty data field', async () => {
//             eventData.should.be.eq('0x0')
//           })
//         })
//
//         describe('the AppInstanceCreated event', async () => {
//
//           let eventTopics
//           let eventData
//
//           beforeEach(async () => {
//             eventTopics = execEvents[2].topics
//             eventData = execEvents[2].data
//           })
//
//           it('should have the correct number of topics', async () => {
//             eventTopics.length.should.be.eq(3)
//           })
//
//           it('should list the correct event signature in the first topic', async () => {
//             let sig = eventTopics[0]
//             web3.toDecimal(sig).should.be.eq(web3.toDecimal(appInstanceCreatedHash))
//           })
//
//           it('should have the creator address and execution id as the other 2 topics', async () => {
//             let emittedAddr = eventTopics[1]
//             let emittedExecId = eventTopics[2]
//             web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(sender))
//             web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(returnedExecID))
//           })
//
//           it('should have a data field with the app storage address, app name, and version name', async () => {
//             let parsedData = await appInitUtil.parseInstanceCreated.call(eventData).should.be.fulfilled
//             parsedData.length.should.be.eq(3)
//             parsedData[0].should.be.eq(storage.address)
//             hexStrEquals(parsedData[1], appName).should.be.eq(true)
//             hexStrEquals(parsedData[2], versionNameOne).should.be.eq(true)
//           })
//         })
//       })
//
//       describe('storage', async () => {
//
//         it('should return valid app info', async () => {
//           let appInfo = await storage.app_info.call(returnedExecID)
//           appInfo.length.should.be.eq(6)
//           appInfo[0].should.be.eq(false)
//           appInfo[1].should.be.eq(true)
//           appInfo[2].should.be.eq(true)
//           appInfo[3].should.be.eq(updater)
//           appInfo[4].should.be.eq(scriptExec.address)
//           appInfo[5].should.be.eq(appInit.address)
//         })
//
//         it('should return a correctly populated allowed address array', async () => {
//           let allowedInfo = await storage.getExecAllowed.call(returnedExecID)
//           allowedInfo.length.should.be.eq(3)
//           allowedInfo[0].should.be.eq(payableApp.address)
//           allowedInfo[1].should.be.eq(stdApp.address)
//           allowedInfo[2].should.be.eq(emitApp.address)
//         })
//
//         it('should have stored the requested value', async () => {
//           let readValue = await storage.read.call(returnedExecID, storageLocations[0]).should.be.fulfilled
//           hexStrEquals(readValue, storageValues[0]).should.be.eq(true, readValue)
//         })
//       })
//
//       it('should allow execution', async () => {
//         let calldata = await appMockUtil.std1.call(
//           storageLocations[0], storageValues[0], senderNewContext
//         ).should.be.fulfilled
//         calldata.should.not.eq('0x0')
//
//         let events = await scriptExec.exec(
//           stdApp.address, calldata,
//           { from: sender }
//         ).then((tx) => {
//           return tx.receipt.logs
//         })
//         events.should.not.eq(null)
//         events.length.should.be.eq(1)
//       })
//     })
//   })
//
//   describe('#migrateApplication', async () => {
//
//     let registryExecID
//     let providerContext
//
//     let appName = 'AppName1'
//     let appDesc = 'Application description'
//     let verDescOne = 'version description 1'
//     let versionNameOne = 'v0.0.1'
//     let initDescOne = 'init description'
//     let versionNameTwo = 'v0.0.2'
//
//     let registerAppCalldata
//     let registerVersionOneCalldata
//     let registerVersionTwoCalldata
//     let addFunctionsCalldata
//     let finalizeOneCalldata
//
//     let newScriptExec
//
//     beforeEach(async () => {
//       let events = await storage.initAndFinalize(
//         updater, false, initRegistry.address, initCalldata, registryAllowed,
//         { from: provider }
//       ).should.be.fulfilled.then((tx) => {
//         return tx.logs
//       })
//       events.should.not.eq(null)
//       events.length.should.be.eq(2)
//       events[0].event.should.be.eq('ApplicationInitialized')
//       events[1].event.should.be.eq('ApplicationFinalization')
//       registryExecID = events[1].args['execution_id']
//       web3.toDecimal(registryExecID).should.not.eq(0)
//
//       await scriptExec.changeRegistryExecId(registryExecID, { from: execAdmin }).should.be.fulfilled
//
//       providerContext = await testUtils.getContextFromAddr.call(
//         registryExecID, provider, 0
//       ).should.be.fulfilled
//       providerContext.should.not.eq('0x0')
//       registerAppCalldata = await registryUtil.registerApp.call(
//         appName, storage.address, appDesc, providerContext
//       ).should.be.fulfilled
//       registerAppCalldata.should.not.eq('0x0')
//
//       registerVersionOneCalldata = await registryUtil.registerVersion.call(
//         appName, versionNameOne, storage.address, verDescOne, providerContext
//       ).should.be.fulfilled
//       registerVersionOneCalldata.should.not.eq('0x0')
//
//       addFunctionsCalldata = await registryUtil.addFunctions.call(
//         appName, versionNameOne, ['0xdeadbeef', '0xdeadbeef', '0xdeadbeef'],
//         [payableApp.address, stdApp.address, emitApp.address],
//         providerContext
//       ).should.be.fulfilled
//       addFunctionsCalldata.should.not.eq('0x0')
//
//       finalizeOneCalldata = await registryUtil.finalizeVersion.call(
//         appName, versionNameOne, appInit.address, ['0xdeadbeef'], initDescOne,
//         providerContext
//       ).should.be.fulfilled
//       finalizeOneCalldata.should.not.eq('0x0')
//
//       events = await storage.exec(
//         appConsole.address, registryExecID, registerAppCalldata,
//         { from: provider }
//       ).then((tx) => {
//         return tx.logs
//       })
//       events.should.not.eq(null)
//       events.length.should.be.eq(1)
//       events[0].event.should.be.eq('ApplicationExecution')
//
//       events = await storage.exec(
//         versionConsole.address, registryExecID, registerVersionOneCalldata,
//         { from: provider }
//       ).then((tx) => {
//         return tx.logs
//       })
//       events.should.not.eq(null)
//       events.length.should.be.eq(1)
//       events[0].event.should.be.eq('ApplicationExecution')
//
//       events = await storage.exec(
//         implConsole.address, registryExecID, addFunctionsCalldata,
//         { from: provider }
//       ).then((tx) => {
//         return tx.logs
//       })
//       events.should.not.eq(null)
//       events.length.should.be.eq(1)
//       events[0].event.should.be.eq('ApplicationExecution')
//
//       events = await storage.exec(
//         versionConsole.address, registryExecID, finalizeOneCalldata,
//         { from: provider }
//       ).then((tx) => {
//         return tx.logs
//       })
//       events.should.not.eq(null)
//       events.length.should.be.eq(1)
//       events[0].event.should.be.eq('ApplicationExecution')
//
//       let initStorageCalldata = await appInitUtil.initStores.call(
//         storageLocations[0], storageValues[0]
//       )
//       initStorageCalldata.should.not.eq('0x0')
//
//       let returnedData = await scriptExec.initAppInstance.call(
//        appName, true, initStorageCalldata,
//        { from: sender }
//       ).should.be.fulfilled
//       returnedData.length.should.be.eq(2)
//       hexStrEquals(returnedData[0], versionNameOne).should.be.eq(true)
//       returnedExecID = returnedData[1]
//
//       execEvents = await scriptExec.initAppInstance(
//         appName, true, initStorageCalldata,
//         { from: sender }
//       ).then((tx) => {
//         return tx.receipt.logs
//       })
//       execEvents.should.not.eq(null)
//       execEvents.length.should.be.eq(3)
//
//       senderNewContext = await testUtils.getContextFromAddr.call(
//         returnedExecID, sender, 0
//       ).should.be.fulfilled
//       senderNewContext.should.not.eq('0x0')
//
//       newScriptExec = await ScriptExec.new(
//         execAdmin, updater, storage.address, providerID,
//         { from: execAdmin }
//       ).should.be.fulfilled
//     })
//
//     context('new script exec address unavailable', async () => {
//
//       it('should throw', async () => {
//         await scriptExec.migrateApplication(
//           returnedExecID, { from: sender }
//         ).should.not.be.fulfilled
//       })
//     })
//
//     context('sender is not the deployer of the application', async () => {
//
//       beforeEach(async () => {
//         await scriptExec.changeExec(
//           newScriptExec.address, { from: execAdmin }
//         ).should.be.fulfilled
//       })
//
//       it('should throw', async () => {
//         await scriptExec.migrateApplication(
//           returnedExecID, { from: updater }
//         ).should.not.be.fulfilled
//       })
//     })
//
//     context('execution id does not exist', async () => {
//
//       let invalidExecID = web3.toHex(0)
//
//       beforeEach(async () => {
//         await scriptExec.changeExec(
//           newScriptExec.address, { from: execAdmin }
//         ).should.be.fulfilled
//       })
//
//       it('should throw', async () => {
//         await scriptExec.migrateApplication(
//           invalidExecID, { from: sender }
//         ).should.not.be.fulfilled
//       })
//     })
//
//     context('sender successfully migrates the script exec address', async () => {
//
//       let migrationEvent
//
//       beforeEach(async () => {
//         await scriptExec.changeExec(
//           newScriptExec.address, { from: execAdmin }
//         ).should.be.fulfilled
//
//         let events = await scriptExec.migrateApplication(
//           returnedExecID, { from: sender }
//         ).should.be.fulfilled.then((tx) => {
//           return tx.logs
//         })
//         events.should.not.eq(null)
//         events.length.should.be.eq(1)
//         migrationEvent = events[0]
//       })
//
//       it('should emit an ApplicationMigration event', async () => {
//         migrationEvent.event.should.be.eq('ApplicationMigration')
//       })
//
//       describe('the ApplicationMigration event', async () => {
//
//         it('should have the storage address as a topic', async () => {
//           let emittedAddr = migrationEvent.args['storage_addr']
//           emittedAddr.should.be.eq(storage.address)
//         })
//
//         it('should match the exec id being migrated', async () => {
//           let emittedExecId = migrationEvent.args['exec_id']
//           emittedExecId.should.be.eq(returnedExecID)
//         })
//
//         it('should match the address of the new script exec', async () => {
//           let emittedExecAddr = migrationEvent.args['new_exec_addr']
//           emittedExecAddr.should.be.eq(newScriptExec.address)
//         })
//
//         it('should contain the deployer address', async () => {
//           let emittedDeployer = migrationEvent.args['original_deployer']
//           emittedDeployer.should.be.eq(sender)
//         })
//       })
//
//       describe('the new script exec address', async () => {
//
//         let calldata
//         let senderNewContext
//
//         beforeEach(async () => {
//           senderNewContext = await testUtils.getContextFromAddr.call(
//             returnedExecID, sender, 0
//           ).should.be.fulfilled
//           senderNewContext.should.not.eq('0x0')
//
//           calldata = await appMockUtil.std1.call(
//             storageLocations[0], storageValues[0], senderNewContext
//           ).should.be.fulfilled
//           calldata.should.not.eq('0x0')
//         })
//
//         it('should be able to execute the application', async () => {
//           await newScriptExec.exec(
//             stdApp.address, calldata,
//             { from: sender }
//           ).should.be.fulfilled
//         })
//       })
//     })
//   })
//
//   describe('#changeExec', async () => {
//
//     let newScriptExec
//
//     beforeEach(async () => {
//       newScriptExec = await ScriptExec.new(
//         execAdmin, updater, storage.address, providerID,
//         { from: execAdmin }
//       ).should.be.fulfilled
//     })
//
//     context('sender is not the admin', async () => {
//
//       it('should throw', async () => {
//         await scriptExec.changeExec(
//           newScriptExec.address, { from: updater }
//         ).should.not.be.fulfilled
//       })
//     })
//
//     context('sender is the admin', async () => {
//
//       beforeEach(async () => {
//         await scriptExec.changeExec(
//           newScriptExec.address, { from: execAdmin }
//         ).should.be.fulfilled
//       })
//
//       it('should have a new script exec address', async () => {
//         let execInfo = await scriptExec.new_script_exec.call()
//         execInfo.should.be.eq(newScriptExec.address)
//       })
//     })
//   })
//
//   describe('#changeStorage', async () => {
//
//     let newStorage
//
//     beforeEach(async () => {
//       newStorage = await AbstractStorage.new().should.be.fulfilled
//     })
//
//     context('sender is not the admin', async () => {
//
//       it('should throw', async () => {
//         await scriptExec.changeStorage(
//           newStorage.address, { from: updater }
//         ).should.not.be.fulfilled
//       })
//     })
//
//     context('sender is the admin', async () => {
//
//       beforeEach(async () => {
//         await scriptExec.changeStorage(
//           newStorage.address, { from: execAdmin }
//         ).should.be.fulfilled
//       })
//
//       it('should have a new default storage address', async () => {
//         let execInfo = await scriptExec.default_storage.call()
//         execInfo.should.be.eq(newStorage.address)
//       })
//     })
//   })
//
//   describe('#changeUpdater', async () => {
//
//     let newUpdater = accounts[5]
//
//     context('sender is not the admin', async () => {
//
//       it('should throw', async () => {
//         await scriptExec.changeUpdater(
//           newUpdater, { from: updater }
//         ).should.not.be.fulfilled
//       })
//     })
//
//     context('sender is the admin', async () => {
//
//       beforeEach(async () => {
//         await scriptExec.changeUpdater(
//           newUpdater, { from: execAdmin }
//         ).should.be.fulfilled
//       })
//
//       it('should have a new default updater address', async () => {
//         let execInfo = await scriptExec.default_updater.call()
//         execInfo.should.be.eq(newUpdater)
//       })
//     })
//   })
//
//   describe('#changeAdmin', async () => {
//
//     let newAdmin = accounts[5]
//
//     context('sender is not the admin', async () => {
//
//       it('should throw', async () => {
//         await scriptExec.changeAdmin(
//           newAdmin, { from: updater }
//         ).should.not.be.fulfilled
//       })
//     })
//
//     context('sender is the admin', async () => {
//
//       beforeEach(async () => {
//         await scriptExec.changeAdmin(
//           newAdmin, { from: execAdmin }
//         ).should.be.fulfilled
//       })
//
//       it('should have a new exec admin address', async () => {
//         let execInfo = await scriptExec.exec_admin.call()
//         execInfo.should.be.eq(newAdmin)
//       })
//     })
//   })
//
//   describe('#changeProvider', async () => {
//
//     let newProvider = accounts[5]
//     let newProviderID
//
//     beforeEach(async () => {
//       newProviderID = await testUtils.getAppProviderHash.call(newProvider)
//     })
//
//     context('sender is not the admin', async () => {
//
//       it('should throw', async () => {
//         await scriptExec.changeProvider(
//           newProviderID, { from: updater }
//         ).should.not.be.fulfilled
//       })
//     })
//
//     context('sender is the admin', async () => {
//
//       beforeEach(async () => {
//         await scriptExec.changeProvider(
//           newProviderID, { from: execAdmin }
//         ).should.be.fulfilled
//       })
//
//       it('should have a new default provider id', async () => {
//         let execInfo = await scriptExec.default_provider.call()
//         execInfo.should.be.eq(newProviderID)
//       })
//     })
//   })
//
//   describe('#changeRegistryExecId', async () => {
//
//     let newExecID = web3.toHex(0)
//
//     context('sender is not the admin', async () => {
//
//       it('should throw', async () => {
//         await scriptExec.changeRegistryExecId(
//           newExecID, { from: updater }
//         ).should.not.be.fulfilled
//       })
//     })
//
//     context('sender is the admin', async () => {
//
//       beforeEach(async () => {
//         await scriptExec.changeRegistryExecId(
//           newExecID, { from: execAdmin }
//         ).should.be.fulfilled
//       })
//
//       it('should have a new default registry exec id', async () => {
//         let execInfo = await scriptExec.default_registry_exec_id.call()
//         web3.toDecimal(execInfo).should.be.eq(web3.toDecimal(newExecID))
//       })
//     })
//   })
// })
