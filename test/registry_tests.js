// let InitRegistry = artifacts.require('./InitRegistry')
// let AppConsole = artifacts.require('./AppConsole')
// let VersionConsole = artifacts.require('./VersionConsole')
// let ImplementationConsole = artifacts.require('./ImplementationConsole')
//
// let RegistryStorage = artifacts.require('./mock/RegistryStorageMock')
//
// let MockAppInit = artifacts.require('./mock/ApplicationMockInit')
// let MockAppLibOne = artifacts.require('./mock/MockAppOne')
// let MockAppLibTwo = artifacts.require('./mock/MockAppTwo')
// let MockAppLibThree = artifacts.require('./mock/MockAppThree')
//
// let utils = require('./support/utils.js')
// let TestUtils = artifacts.require('./util/TestUtils')
// let RegistryUtil = artifacts.require('./util/RegistryUtil')
//
// function hexStrEquals(hex, expected) {
//   return web3.toAscii(hex).substring(0, expected.length) == expected;
// }
//
// contract('Script Registry', function(accounts) {
//   let storage
//   let testUtils
//   let registryUtil
//
//   let exec = accounts[0]
//   let updater = accounts[1]
//
//   let registryExecId
//
//   let initRegistry
//   let initRegistryCalldata = '0xe1c7392a'
//
//   let appConsole
//   let versionConsole
//   let implConsole
//
//   let mockAppInit
//   let mockAppInitSig = '0xe1c7392a'
//   let mockAppInitDesc = 'A mock application initialization address'
//
//   let mockAppLibOne
//   let mockAppLibTwo
//   let mockAppLibThree
//
//   let providerOne = accounts[2]
//   let providerTwo = accounts[3]
//   let otherAccount = accounts[accounts.length - 1]
//
//   let providerOneID
//   let providerTwoID
//
//   let initHash = web3.sha3('ApplicationInitialized(bytes32,address,address,address)')
//   let finalHash = web3.sha3('ApplicationFinalization(bytes32,address)')
//   let execHash = web3.sha3('ApplicationExecution(bytes32,address)')
//   let exceptHash = web3.sha3('ApplicationException(address,bytes32,bytes)')
//
//   let appRegHash = web3.sha3('AppRegistered(bytes32,bytes32,bytes32)')
//   let verRegHash = web3.sha3('VersionRegistered(bytes32,bytes32,bytes32,bytes32)')
//   let verFinHash = web3.sha3('VersionReleased(bytes32,bytes32,bytes32,bytes32)')
//
//   before(async () => {
//     storage = await RegistryStorage.new().should.be.fulfilled
//     testUtils = await TestUtils.new().should.be.fulfilled
//     registryUtil = await RegistryUtil.new().should.be.fulfilled
//
//     initRegistry = await InitRegistry.new().should.be.fulfilled
//
//     appConsole = await AppConsole.new().should.be.fulfilled
//     versionConsole = await VersionConsole.new().should.be.fulfilled
//     implConsole = await ImplementationConsole.new().should.be.fulfilled
//
//     mockAppInit = await MockAppInit.new().should.be.fulfilled
//     mockAppLibOne = await MockAppLibOne.new().should.be.fulfilled
//     mockAppLibTwo = await MockAppLibTwo.new().should.be.fulfilled
//     mockAppLibThree = await MockAppLibThree.new().should.be.fulfilled
//   })
//
//   beforeEach(async ()  => {
//     let events = await storage.initAndFinalize(
//       updater, false, initRegistry.address, initRegistryCalldata, [
//         appConsole.address, versionConsole.address, implConsole.address
//       ],
//       { from: exec }
//     ).then((tx) => {
//       return tx.logs
//     })
//
//     events.should.not.eq(null)
//     events.length.should.be.eq(2)
//
//     registryExecId = events[0].args['execution_id']
//     registryExecId.should.not.eq(null)
//     registryExecId.should.not.eq('0x0')
//
//     providerOneID = await testUtils.getAppProviderHash(providerOne).should.be.fulfilled
//     providerTwoID = await testUtils.getAppProviderHash(providerTwo).should.be.fulfilled
//
//     web3.toDecimal(providerOneID).should.not.eq(0)
//     web3.toDecimal(providerTwoID).should.not.eq(0)
//   })
//
//   describe('#AppConsole', async () => {
//
//     let execContextProvOne
//     let execContextProvTwo
//     let execContextOther
//
//     let appNameOne = 'AppNameOne'
//     let appDescOne = 'A generic application'
//     let registerOneProvOneCalldata
//     let registerOneProvTwoCalldata
//
//     let appNameTwo = 'AppNameTwo'
//     let appDescTwo = 'A second, equally-as-generic application'
//     let registerTwoProvOneCalldata
//     let registerTwoProvTwoCalldata
//
//     beforeEach(async () => {
//       execContextProvOne = await testUtils.getContextFromAddr.call(
//         registryExecId, providerOne, 0
//       ).should.be.fulfilled
//       execContextProvTwo = await testUtils.getContextFromAddr.call(
//         registryExecId, providerTwo, 0
//       ).should.be.fulfilled
//       execContextOther = await testUtils.getContextFromAddr.call(
//         registryExecId, otherAccount, 0
//       ).should.be.fulfilled
//
//       execContextProvOne.should.not.eq('0x0')
//       execContextProvTwo.should.not.eq('0x0')
//       execContextOther.should.not.eq('0x0')
//
//       registerOneProvOneCalldata = await registryUtil.registerApp.call(
//         appNameOne, storage.address, appDescOne, execContextProvOne
//       ).should.be.fulfilled
//       registerOneProvOneCalldata.should.not.eq('0x0')
//
//       registerOneProvTwoCalldata = await registryUtil.registerApp.call(
//         appNameOne, storage.address, appDescOne, execContextProvTwo
//       ).should.be.fulfilled
//       registerOneProvTwoCalldata.should.not.eq('0x0')
//
//       registerTwoProvOneCalldata = await registryUtil.registerApp.call(
//         appNameTwo, storage.address, appDescTwo, execContextProvOne
//       ).should.be.fulfilled
//       registerTwoProvOneCalldata.should.not.eq('0x0')
//
//       registerTwoProvTwoCalldata = await registryUtil.registerApp.call(
//         appNameTwo, storage.address, appDescTwo, execContextProvTwo
//       ).should.be.fulfilled
//       registerTwoProvTwoCalldata.should.not.eq('0x0')
//     })
//
//     describe('when an application is registered with valid information', async () => {
//
//       let providerOneApps
//       let providerTwoApps
//
//       let returnOne
//       let returnTwo
//       let returnThree
//       let returnInvalid
//
//       let eventsOne
//       let eventsTwo
//       let eventsThree
//       let eventsInvalid
//
//       beforeEach(async () => {
//         providerOneApps = await initRegistry.getProviderInfo.call(
//           storage.address,
//           registryExecId,
//           providerOneID
//         ).should.be.fulfilled
//         providerOneApps.length.should.be.eq(0)
//
//         providerTwoApps = await initRegistry.getProviderInfo.call(
//           storage.address,
//           registryExecId,
//           providerTwoID
//         ).should.be.fulfilled
//         providerTwoApps.length.should.be.eq(0)
//
//         returnOne = await storage.exec.call(
//           appConsole.address, registryExecId, registerOneProvOneCalldata,
//           { from: exec }
//         )
//         eventsOne = await storage.exec(
//           appConsole.address, registryExecId, registerOneProvOneCalldata,
//           { from: exec }
//         ).then((tx) => {
//           return tx.receipt.logs
//         })
//
//         returnTwo = await storage.exec.call(
//           appConsole.address, registryExecId, registerOneProvTwoCalldata,
//           { from: exec }
//         )
//         eventsTwo = await storage.exec(
//           appConsole.address, registryExecId, registerOneProvTwoCalldata,
//           { from: exec }
//         ).then((tx) => {
//           return tx.receipt.logs
//         })
//
//         returnThree = await storage.exec.call(
//           appConsole.address, registryExecId, registerTwoProvTwoCalldata,
//           { from: exec }
//         )
//         eventsThree = await storage.exec(
//           appConsole.address, registryExecId, registerTwoProvTwoCalldata,
//           { from: exec }
//         ).then((tx) => {
//           return tx.receipt.logs
//         })
//
//         returnInvalid = await storage.exec.call(
//           appConsole.address, registryExecId, registerOneProvOneCalldata,
//           { from: exec }
//         )
//         eventsInvalid = await storage.exec(
//           appConsole.address, registryExecId, registerOneProvOneCalldata,
//           { from: exec }
//         ).then((tx) => {
//           return tx.logs
//         })
//       })
//
//       it('should correctly register one unique application for a provider', async () => {
//
//         let newProviderOneApps = await initRegistry.getProviderInfo.call(
//           storage.address,
//           registryExecId,
//           providerOneID
//         ).should.be.fulfilled
//         newProviderOneApps.length.should.be.above(providerOneApps.length)
//         newProviderOneApps.length.should.be.eq(1)
//
//         hexStrEquals(newProviderOneApps[0], appNameOne).should.be.eq(true)
//       })
//
//       it('should register two unique applications for a provider', async () => {
//         let newProviderTwoApps = await initRegistry.getProviderInfo.call(
//           storage.address,
//           registryExecId,
//           providerTwoID
//         ).should.be.fulfilled
//         newProviderTwoApps.length.should.be.above(providerTwoApps.length)
//         newProviderTwoApps.length.should.be.eq(2)
//
//         hexStrEquals(newProviderTwoApps[0], appNameOne).should.be.eq(true)
//         hexStrEquals(newProviderTwoApps[1], appNameTwo).should.be.eq(true)
//       })
//
//       context('events (#1)', async () => {
//
//         let appTopics
//         let appData
//         let execTopics
//         let execData
//
//         beforeEach(async () => {
//           appTopics = eventsOne[0].topics
//           appData = eventsOne[0].data
//           execTopics = eventsOne[1].topics
//           execData = eventsOne[1].data
//         })
//
//         it('should emit 2 events total', async () => {
//           eventsOne.length.should.be.eq(2)
//         })
//
//         describe('the ApplicationExecution event', async () => {
//
//           it('should have 3 topics', async () => {
//             execTopics.length.should.be.eq(3)
//           })
//
//           it('should have the event signature as the first topic', async () => {
//             let sig = execTopics[0]
//             web3.toDecimal(sig).should.be.eq(web3.toDecimal(execHash))
//           })
//
//           it('should match the used execution id', async () => {
//             let emittedExecId = execTopics[1]
//             emittedExecId.should.be.eq(registryExecId)
//           })
//
//           it('should match the targeted app address', async () => {
//             let emittedAddr = execTopics[2]
//             web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(appConsole.address))
//           })
//
//           it('should have an empty data field', async () => {
//             execData.should.be.eq('0x0')
//           })
//         })
//
//         describe('the other event', async () => {
//
//           it('should have 3 topics', async () => {
//             appTopics.length.should.be.eq(3)
//           })
//
//           it('should have the AppRegistered event signature as the first topic', async () => {
//             let sig = appTopics[0]
//             web3.toDecimal(sig).should.be.eq(web3.toDecimal(appRegHash))
//           })
//
//           it('should match the exec id for the second topic', async () => {
//             let emittedExecId = appTopics[1]
//             emittedExecId.should.be.eq(registryExecId)
//           })
//
//           it('should match the provider id for the third topic', async () => {
//             let emittedProviderId = appTopics[2]
//             emittedProviderId.should.be.eq(providerOneID)
//           })
//
//           it('should contain the app name in the data emitted', async () => {
//             let emittedName = appData
//             hexStrEquals(emittedName, appNameOne).should.be.eq(true, emittedName + "|" + appNameOne)
//           })
//         })
//       })
//
//       context('return (#1)', async () => {
//
//         it('should return a tuple with 3 fields', async () => {
//           returnOne.length.should.be.eq(3)
//         })
//
//         it('should return the correct number of events emitted', async () => {
//           returnOne[0].toNumber().should.be.eq(1)
//         })
//
//         it('should return the correct number of addresses paid', async () => {
//           returnOne[1].toNumber().should.be.eq(0)
//         })
//
//         it('should return the correct number of storage slots written to', async () => {
//           returnOne[2].toNumber().should.be.above(4)
//         })
//       })
//
//       context('events (#2)', async () => {
//
//         let appTopics
//         let appData
//         let execTopics
//         let execData
//
//         beforeEach(async () => {
//           appTopics = eventsTwo[0].topics
//           appData = eventsTwo[0].data
//           execTopics = eventsTwo[1].topics
//           execData = eventsTwo[1].data
//         })
//
//         it('should emit 2 events total', async () => {
//           eventsTwo.length.should.be.eq(2)
//         })
//
//         describe('the ApplicationExecution event', async () => {
//
//           it('should have 3 topics', async () => {
//             execTopics.length.should.be.eq(3)
//           })
//
//           it('should have the event signature as the first topic', async () => {
//             let sig = execTopics[0]
//             web3.toDecimal(sig).should.be.eq(web3.toDecimal(execHash))
//           })
//
//           it('should match the used execution id', async () => {
//             let emittedExecId = execTopics[1]
//             emittedExecId.should.be.eq(registryExecId)
//           })
//
//           it('should match the targeted app address', async () => {
//             let emittedAddr = execTopics[2]
//             web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(appConsole.address))
//           })
//
//           it('should have an empty data field', async () => {
//             execData.should.be.eq('0x0')
//           })
//         })
//
//         describe('the other event', async () => {
//
//           it('should have 3 topics', async () => {
//             appTopics.length.should.be.eq(3)
//           })
//
//           it('should have the AppRegistered event signature as the first topic', async () => {
//             let sig = appTopics[0]
//             web3.toDecimal(sig).should.be.eq(web3.toDecimal(appRegHash))
//           })
//
//           it('should match the exec id for the second topic', async () => {
//             let emittedExecId = appTopics[1]
//             emittedExecId.should.be.eq(registryExecId)
//           })
//
//           it('should match the provider id for the third topic', async () => {
//             let emittedProviderId = appTopics[2]
//             emittedProviderId.should.be.eq(providerTwoID)
//           })
//
//           it('should contain the app name in the data emitted', async () => {
//             let emittedName = appData
//             hexStrEquals(emittedName, appNameOne).should.be.eq(true, emittedName + "|" + appNameOne)
//           })
//         })
//       })
//
//       context('return (#2)', async () => {
//
//         it('should return a tuple with 3 fields', async () => {
//           returnTwo.length.should.be.eq(3)
//         })
//
//         it('should return the correct number of events emitted', async () => {
//           returnTwo[0].toNumber().should.be.eq(1)
//         })
//
//         it('should return the correct number of addresses paid', async () => {
//           returnTwo[1].toNumber().should.be.eq(0)
//         })
//
//         it('should return the correct number of storage slots written to', async () => {
//           returnTwo[2].toNumber().should.be.above(4)
//         })
//       })
//
//       context('events (#3)', async () => {
//
//         let appTopics
//         let appData
//         let execTopics
//         let execData
//
//         beforeEach(async () => {
//           appTopics = eventsThree[0].topics
//           appData = eventsThree[0].data
//           execTopics = eventsThree[1].topics
//           execData = eventsThree[1].data
//         })
//
//         it('should emit 2 events total', async () => {
//           eventsThree.length.should.be.eq(2)
//         })
//
//         describe('the ApplicationExecution event', async () => {
//
//           it('should have 3 topics', async () => {
//             execTopics.length.should.be.eq(3)
//           })
//
//           it('should have the event signature as the first topic', async () => {
//             let sig = execTopics[0]
//             web3.toDecimal(sig).should.be.eq(web3.toDecimal(execHash))
//           })
//
//           it('should match the used execution id', async () => {
//             let emittedExecId = execTopics[1]
//             emittedExecId.should.be.eq(registryExecId)
//           })
//
//           it('should match the targeted app address', async () => {
//             let emittedAddr = execTopics[2]
//             web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(appConsole.address))
//           })
//
//           it('should have an empty data field', async () => {
//             execData.should.be.eq('0x0')
//           })
//         })
//
//         describe('the other event', async () => {
//
//           it('should have 3 topics', async () => {
//             appTopics.length.should.be.eq(3)
//           })
//
//           it('should have the AppRegistered event signature as the first topic', async () => {
//             let sig = appTopics[0]
//             web3.toDecimal(sig).should.be.eq(web3.toDecimal(appRegHash))
//           })
//
//           it('should match the exec id for the second topic', async () => {
//             let emittedExecId = appTopics[1]
//             emittedExecId.should.be.eq(registryExecId)
//           })
//
//           it('should match the provider id for the third topic', async () => {
//             let emittedProviderId = appTopics[2]
//             emittedProviderId.should.be.eq(providerTwoID)
//           })
//
//           it('should contain the app name in the data emitted', async () => {
//             let emittedName = appData
//             hexStrEquals(emittedName, appNameTwo).should.be.eq(true, emittedName + "|" + appNameOne)
//           })
//         })
//       })
//
//       context('return (#3)', async () => {
//
//         it('should return a tuple with 3 fields', async () => {
//           returnTwo.length.should.be.eq(3)
//         })
//
//         it('should return the correct number of events emitted', async () => {
//           returnTwo[0].toNumber().should.be.eq(1)
//         })
//
//         it('should return the correct number of addresses paid', async () => {
//           returnTwo[1].toNumber().should.be.eq(0)
//         })
//
//         it('should return the correct number of storage slots written to', async () => {
//           returnTwo[2].toNumber().should.be.above(4)
//         })
//       })
//
//       context('events (#4)', async () => {
//
//         let invalidEvent
//
//         beforeEach(async () => {
//           invalidEvent = eventsInvalid[0]
//         })
//
//         it('should emit 1 event total', async () => {
//           eventsInvalid.length.should.be.eq(1)
//         })
//
//         describe('the ApplicationException event', async () => {
//
//           it('should have the correct name and signature', async () => {
//             invalidEvent.event.should.be.eq('ApplicationException')
//           })
//
//           it('should match the used execution id', async () => {
//             let emittedExecId = invalidEvent.args['execution_id']
//             emittedExecId.should.be.eq(registryExecId)
//           })
//
//           it('should match the targeted app address', async () => {
//             let emittedAddr = invalidEvent.args['application_address']
//             emittedAddr.should.be.eq(appConsole.address)
//           })
//
//           it('should have a non-empty data field with the message \'InsufficientPermissions\'', async () => {
//             let message = invalidEvent.args['message']
//             hexStrEquals(message, 'InsufficientPermissions').should.be.eq(true, web3.toAscii(message))
//           })
//         })
//       })
//
//       context('return (#4)', async () => {
//
//         it('should return a tuple with 3 fields', async () => {
//           returnTwo.length.should.be.eq(3)
//         })
//
//         it('should return the correct number of events emitted', async () => {
//           returnTwo[0].toNumber().should.be.eq(1)
//         })
//
//         it('should return the correct number of addresses paid', async () => {
//           returnTwo[1].toNumber().should.be.eq(0)
//         })
//
//         it('should return the correct number of storage slots written to', async () => {
//           returnTwo[2].toNumber().should.be.above(5)
//         })
//       })
//
//       context('resulting storage', async () => {
//
//         it('should not register an application under another provider', async () => {
//           let otherProviderApps = await initRegistry.getProviderInfoFromAddress.call(
//             storage.address, registryExecId, otherAccount
//           ).should.be.fulfilled
//           let otherProviderID = await testUtils.getAppProviderHash.call(otherAccount).should.be.fulfilled
//
//           otherProviderApps.length.should.be.eq(2)
//           otherProviderApps[0].should.be.eq(otherProviderID)
//           otherProviderApps[1].length.should.be.eq(0)
//         })
//
//         it('should return information about an application', async () => {
//           let appInfoReturn = await initRegistry.getAppInfo.call(
//             storage.address, registryExecId, providerOneID, appNameOne
//           ).should.be.fulfilled
//
//           appInfoReturn.length.should.be.eq(3)
//           appInfoReturn[0].toNumber().should.be.eq(0)
//           appInfoReturn[1].should.be.eq(storage.address)
//           hexStrEquals(appInfoReturn[2], appDescOne).should.be.eq(true)
//         })
//
//         it('should not have any versions registered', async () => {
//           let appVersionsReturn = await initRegistry.getAppVersions.call(
//             storage.address, registryExecId, providerOneID, appNameOne
//           ).should.be.fulfilled
//
//           appVersionsReturn.length.should.be.eq(2)
//           appVersionsReturn[0].toNumber().should.be.eq(0)
//           appVersionsReturn[1].length.should.be.eq(0)
//         })
//
//         it('should not have information on initialization', async () => {
//           let appLatestReturn = await initRegistry.getAppLatestInfo.call(
//             storage.address, registryExecId, providerOneID, appNameOne
//           ).should.be.fulfilled
//
//           appLatestReturn.length.should.be.eq(4)
//           appLatestReturn[0].should.be.eq(storage.address)
//           web3.toDecimal(appLatestReturn[1]).should.be.eq(0)
//           web3.toDecimal(appLatestReturn[2]).should.be.eq(0)
//           appLatestReturn[3].length.should.be.eq(0)
//         })
//       })
//     })
//
//     describe('when an application is registered with invalid input information', async () => {
//       let executionContext
//       let validCalldata
//       let validEvents
//
//       let validReturn
//
//       let validAppName = 'valid'
//       let validAppStorage
//       let validAppDescription = 'valid desc'
//
//       let invalidAppName = ''
//       let invalidAppStorage = web3.toHex(0)
//       let invalidAppDescription = ''
//
//       let invalidNameCalldata
//       let invalidStorageCalldata
//       let invalidDescCalldata
//
//       let invalidNameEvents
//       let invalidStorageEvents
//       let invalidDescEvents
//
//       let invalidNameReturn
//       let invalidStorageReturn
//       let invalidDescReturn
//
//       beforeEach(async () => {
//         validAppStorage = storage.address
//
//         executionContext = await testUtils.getContextFromAddr.call(registryExecId, otherAccount, 0).should.be.fulfilled
//
//         validCalldata = await registryUtil.registerApp.call(
//           validAppName, validAppStorage, validAppDescription, executionContext
//         ).should.be.fulfilled
//
//         invalidNameCalldata = await registryUtil.registerApp.call(
//           invalidAppName, validAppStorage, validAppDescription, executionContext
//         ).should.be.fulfilled
//
//         invalidStorageCalldata = await registryUtil.registerApp.call(
//           validAppName, invalidAppStorage, validAppDescription, executionContext
//         ).should.be.fulfilled
//
//         invalidDescCalldata = await registryUtil.registerApp.call(
//           validAppName, validAppStorage, invalidAppDescription, executionContext
//         ).should.be.fulfilled
//
//         invalidNameReturn = await storage.exec.call(
//           appConsole.address, registryExecId, invalidNameCalldata,
//           { from: exec }
//         )
//         invalidNameEvents = await storage.exec(
//           appConsole.address, registryExecId, invalidNameCalldata,
//           { from: exec }
//         ).then((tx) => {
//           return tx.logs
//         })
//
//         invalidStorageReturn = await storage.exec.call(
//           appConsole.address, registryExecId, invalidStorageCalldata,
//           { from: exec }
//         )
//         invalidStorageEvents = await storage.exec(
//           appConsole.address, registryExecId, invalidStorageCalldata,
//           { from: exec }
//         ).then((tx) => {
//           return tx.logs
//         })
//
//         invalidDescReturn = await storage.exec.call(
//           appConsole.address, registryExecId, invalidDescCalldata,
//           { from: exec }
//         )
//         invalidDescEvents = await storage.exec(
//           appConsole.address, registryExecId, invalidDescCalldata,
//           { from: exec }
//         ).then((tx) => {
//           return tx.logs
//         })
//
//         validReturn = await storage.exec.call(
//           appConsole.address, registryExecId, validCalldata,
//           { from: exec }
//         )
//         validEvents = await storage.exec(
//           appConsole.address, registryExecId, validCalldata,
//           { from: exec }
//         ).then((tx) => {
//           return tx.logs
//         })
//       })
//
//       context('events (#1)', async () => {
//
//         let invalidEvent
//
//         beforeEach(async () => {
//           invalidEvent = invalidNameEvents[0]
//         })
//
//         it('should emit 1 event total', async () => {
//           invalidNameEvents.length.should.be.eq(1)
//         })
//
//         describe('the ApplicationException event', async () => {
//
//           it('should have the correct name and signature', async () => {
//             invalidEvent.event.should.be.eq('ApplicationException')
//           })
//
//           it('should match the used execution id', async () => {
//             let emittedExecId = invalidEvent.args['execution_id']
//             emittedExecId.should.be.eq(registryExecId)
//           })
//
//           it('should match the targeted app address', async () => {
//             let emittedAddr = invalidEvent.args['application_address']
//             emittedAddr.should.be.eq(appConsole.address)
//           })
//
//           it('should have a non-empty data field with the message \'DefaultException\'', async () => {
//             let message = invalidEvent.args['message']
//             hexStrEquals(message, 'DefaultException').should.be.eq(true, web3.toAscii(message))
//           })
//         })
//       })
//
//       context('return (#1)', async () => {
//
//         it('should return a tuple with 3 fields', async () => {
//           invalidNameReturn.length.should.be.eq(3)
//         })
//
//         it('should return the correct number of events emitted', async () => {
//           invalidNameReturn[0].toNumber().should.be.eq(0)
//         })
//
//         it('should return the correct number of addresses paid', async () => {
//           invalidNameReturn[1].toNumber().should.be.eq(0)
//         })
//
//         it('should return the correct number of storage slots written to', async () => {
//           invalidNameReturn[2].toNumber().should.be.eq(0)
//         })
//       })
//
//       context('events (#2)', async () => {
//
//         let invalidEvent
//
//         beforeEach(async () => {
//           invalidEvent = invalidStorageEvents[0]
//         })
//
//         it('should emit 1 event total', async () => {
//           invalidStorageEvents.length.should.be.eq(1)
//         })
//
//         describe('the ApplicationException event', async () => {
//
//           it('should have the correct name and signature', async () => {
//             invalidEvent.event.should.be.eq('ApplicationException')
//           })
//
//           it('should match the used execution id', async () => {
//             let emittedExecId = invalidEvent.args['execution_id']
//             emittedExecId.should.be.eq(registryExecId)
//           })
//
//           it('should match the targeted app address', async () => {
//             let emittedAddr = invalidEvent.args['application_address']
//             emittedAddr.should.be.eq(appConsole.address)
//           })
//
//           it('should have a non-empty data field with the message \'DefaultException\'', async () => {
//             let message = invalidEvent.args['message']
//             hexStrEquals(message, 'DefaultException').should.be.eq(true, web3.toAscii(message))
//           })
//         })
//       })
//
//       context('return (#2)', async () => {
//
//         it('should return a tuple with 3 fields', async () => {
//           invalidStorageReturn.length.should.be.eq(3)
//         })
//
//         it('should return the correct number of events emitted', async () => {
//           invalidStorageReturn[0].toNumber().should.be.eq(0)
//         })
//
//         it('should return the correct number of addresses paid', async () => {
//           invalidStorageReturn[1].toNumber().should.be.eq(0)
//         })
//
//         it('should return the correct number of storage slots written to', async () => {
//           invalidStorageReturn[2].toNumber().should.be.eq(0)
//         })
//       })
//
//       context('events (#3)', async () => {
//
//         let invalidEvent
//
//         beforeEach(async () => {
//           invalidEvent = invalidDescEvents[0]
//         })
//
//         it('should emit 1 event total', async () => {
//           invalidDescEvents.length.should.be.eq(1)
//         })
//
//         describe('the ApplicationException event', async () => {
//
//           it('should have the correct name and signature', async () => {
//             invalidEvent.event.should.be.eq('ApplicationException')
//           })
//
//           it('should match the used execution id', async () => {
//             let emittedExecId = invalidEvent.args['execution_id']
//             emittedExecId.should.be.eq(registryExecId)
//           })
//
//           it('should match the targeted app address', async () => {
//             let emittedAddr = invalidEvent.args['application_address']
//             emittedAddr.should.be.eq(appConsole.address)
//           })
//
//           it('should have a non-empty data field with the message \'DefaultException\'', async () => {
//             let message = invalidEvent.args['message']
//             hexStrEquals(message, 'DefaultException').should.be.eq(true, web3.toAscii(message))
//           })
//         })
//       })
//
//       context('return (#3)', async () => {
//
//         it('should return a tuple with 3 fields', async () => {
//           invalidDescReturn.length.should.be.eq(3)
//         })
//
//         it('should return the correct number of events emitted', async () => {
//           invalidDescReturn[0].toNumber().should.be.eq(0)
//         })
//
//         it('should return the correct number of addresses paid', async () => {
//           invalidDescReturn[1].toNumber().should.be.eq(0)
//         })
//
//         it('should return the correct number of storage slots written to', async () => {
//           invalidDescReturn[2].toNumber().should.be.eq(0)
//         })
//       })
//
//       context('events (#4)', async () => {
//
//         let validEvent
//
//         beforeEach(async () => {
//           validEvent = validEvents[0]
//         })
//
//         it('should emit 1 event, ApplicationExecution', async () => {
//           validEvents.length.should.be.eq(1)
//           validEvent.event.should.be.eq('ApplicationExecution')
//         })
//       })
//
//       context('return (#4)', async () => {
//
//         it('should return a tuple with 3 fields', async () => {
//           validReturn.length.should.be.eq(3)
//         })
//
//         it('should return the correct number of events emitted', async () => {
//           validReturn[0].toNumber().should.be.eq(1)
//         })
//
//         it('should return the correct number of addresses paid', async () => {
//           validReturn[1].toNumber().should.be.eq(0)
//         })
//
//         it('should return the correct number of storage slots written to', async () => {
//           validReturn[2].toNumber().should.be.above(5);
//         })
//       })
//     })
//
//     describe('when an application is registered with an invalid context array', async () => {
//       let validContext
//       let validCalldata
//       let validEvents
//
//       let validReturn
//
//       let appName = 'valid'
//       let appStorage
//       let appDescription = 'valid desc'
//
//       let invalidHex = web3.toHex(0)
//
//       let invalidExecIDContext
//       let invalidProviderContext
//       let invalidLengthContext
//
//       let invalidExecIDCalldata
//       let invalidProviderCalldata
//       let invalidLengthCalldata
//
//       let invalidExecIDEvents
//       let invalidProviderEvents
//       let invalidLengthEvents
//
//       let invalidExecIDReturn
//       let invalidProviderReturn
//       let invalidLengthReturn
//
//       beforeEach(async () => {
//         appStorage = storage.address
//
//         invalidExecIDContext = await testUtils.getContextFromAddr.call(invalidHex, otherAccount, 0).should.be.fulfilled
//         invalidProviderContext = await testUtils.getContextFromAddr.call(registryExecId, invalidHex, 0).should.be.fulfilled
//         invalidLengthContext = await testUtils.getInvalidContext.call(registryExecId, otherAccount, 0).should.be.fulfilled
//         invalidLengthContext.length.should.be.eq(192)
//
//         validContext = await testUtils.getContextFromAddr.call(registryExecId, otherAccount, 0).should.be.fulfilled
//
//         validCalldata = await registryUtil.registerApp.call(
//           appName, appStorage, appDescription, validContext
//         ).should.be.fulfilled
//
//         invalidExecIDCalldata = await registryUtil.registerApp.call(
//           appName, appStorage, appDescription, invalidExecIDContext
//         ).should.be.fulfilled
//
//         invalidProviderCalldata = await registryUtil.registerApp.call(
//           appName, appStorage, appDescription, invalidProviderContext
//         ).should.be.fulfilled
//
//         invalidLengthCalldata = await registryUtil.registerApp.call(
//           appName, appStorage, appDescription, invalidLengthContext
//         ).should.be.fulfilled
//
//         invalidExecIDReturn = await storage.exec.call(
//           appConsole.address, registryExecId, invalidExecIDCalldata,
//           { from: exec }
//         )
//         invalidExecIDEvents = await storage.exec(
//           appConsole.address, registryExecId, invalidExecIDCalldata,
//           { from: exec }
//         ).then((tx) => {
//           return tx.logs
//         })
//
//         invalidProviderReturn = await storage.exec.call(
//           appConsole.address, registryExecId, invalidProviderCalldata,
//           { from: exec }
//         )
//         invalidProviderEvents = await storage.exec(
//           appConsole.address, registryExecId, invalidProviderCalldata,
//           { from: exec }
//         ).then((tx) => {
//           return tx.logs
//         })
//
//         invalidLengthReturn = await storage.exec.call(
//           appConsole.address, registryExecId, invalidLengthCalldata,
//           { from: exec }
//         )
//         invalidLengthEvents = await storage.exec(
//           appConsole.address, registryExecId, invalidLengthCalldata,
//           { from: exec }
//         ).then((tx) => {
//           return tx.logs
//         })
//
//         validReturn = await storage.exec.call(
//           appConsole.address, registryExecId, validCalldata,
//           { from: exec }
//         )
//         validEvents = await storage.exec(
//           appConsole.address, registryExecId, validCalldata,
//           { from: exec }
//         ).then((tx) => {
//           return tx.logs
//         })
//       })
//
//       context('events (#1)', async () => {
//
//         let invalidEvent
//
//         beforeEach(async () => {
//           invalidEvent = invalidExecIDEvents[0]
//         })
//
//         it('should emit 1 event total', async () => {
//           invalidExecIDEvents.length.should.be.eq(1)
//         })
//
//         describe('the ApplicationException event', async () => {
//
//           it('should have the correct name and signature', async () => {
//             invalidEvent.event.should.be.eq('ApplicationException')
//           })
//
//           it('should match the used execution id', async () => {
//             let emittedExecId = invalidEvent.args['execution_id']
//             emittedExecId.should.be.eq(registryExecId)
//           })
//
//           it('should match the targeted app address', async () => {
//             let emittedAddr = invalidEvent.args['application_address']
//             emittedAddr.should.be.eq(appConsole.address)
//           })
//
//           it('should have a non-empty data field with the message \'UnknownContext\'', async () => {
//             let message = invalidEvent.args['message']
//             hexStrEquals(message, 'UnknownContext').should.be.eq(true, web3.toAscii(message))
//           })
//         })
//       })
//
//       context('return (#1)', async () => {
//
//         it('should return a tuple with 3 fields', async () => {
//           invalidExecIDReturn.length.should.be.eq(3)
//         })
//
//         it('should return the correct number of events emitted', async () => {
//           invalidExecIDReturn[0].toNumber().should.be.eq(0)
//         })
//
//         it('should return the correct number of addresses paid', async () => {
//           invalidExecIDReturn[1].toNumber().should.be.eq(0)
//         })
//
//         it('should return the correct number of storage slots written to', async () => {
//           invalidExecIDReturn[2].toNumber().should.be.eq(0)
//         })
//       })
//
//       context('events (#2)', async () => {
//
//         let invalidEvent
//
//         beforeEach(async () => {
//           invalidEvent = invalidProviderEvents[0]
//         })
//
//         it('should emit 1 event total', async () => {
//           invalidProviderEvents.length.should.be.eq(1)
//         })
//
//         describe('the ApplicationException event', async () => {
//
//           it('should have the correct name and signature', async () => {
//             invalidEvent.event.should.be.eq('ApplicationException')
//           })
//
//           it('should match the used execution id', async () => {
//             let emittedExecId = invalidEvent.args['execution_id']
//             emittedExecId.should.be.eq(registryExecId)
//           })
//
//           it('should match the targeted app address', async () => {
//             let emittedAddr = invalidEvent.args['application_address']
//             emittedAddr.should.be.eq(appConsole.address)
//           })
//
//           it('should have a non-empty data field with the message \'UnknownContext\'', async () => {
//             let message = invalidEvent.args['message']
//             hexStrEquals(message, 'UnknownContext').should.be.eq(true, web3.toAscii(message))
//           })
//         })
//       })
//
//       context('return (#2)', async () => {
//
//         it('should return a tuple with 3 fields', async () => {
//           invalidProviderReturn.length.should.be.eq(3)
//         })
//
//         it('should return the correct number of events emitted', async () => {
//           invalidProviderReturn[0].toNumber().should.be.eq(0)
//         })
//
//         it('should return the correct number of addresses paid', async () => {
//           invalidProviderReturn[1].toNumber().should.be.eq(0)
//         })
//
//         it('should return the correct number of storage slots written to', async () => {
//           invalidProviderReturn[2].toNumber().should.be.eq(0)
//         })
//       })
//
//       context('events (#3)', async () => {
//
//         let invalidEvent
//
//         beforeEach(async () => {
//           invalidEvent = invalidLengthEvents[0]
//         })
//
//         it('should emit 1 event total', async () => {
//           invalidLengthEvents.length.should.be.eq(1)
//         })
//
//         describe('the ApplicationException event', async () => {
//
//           it('should have the correct name and signature', async () => {
//             invalidEvent.event.should.be.eq('ApplicationException')
//           })
//
//           it('should match the used execution id', async () => {
//             let emittedExecId = invalidEvent.args['execution_id']
//             emittedExecId.should.be.eq(registryExecId)
//           })
//
//           it('should match the targeted app address', async () => {
//             let emittedAddr = invalidEvent.args['application_address']
//             emittedAddr.should.be.eq(appConsole.address)
//           })
//
//           it('should have a non-empty data field with the message \'DefaultException\'', async () => {
//             let message = invalidEvent.args['message']
//             hexStrEquals(message, 'DefaultException').should.be.eq(true, web3.toAscii(message))
//           })
//         })
//       })
//
//       context('return (#3)', async () => {
//
//         it('should return a tuple with 3 fields', async () => {
//           invalidLengthReturn.length.should.be.eq(3)
//         })
//
//         it('should return the correct number of events emitted', async () => {
//           invalidLengthReturn[0].toNumber().should.be.eq(0)
//         })
//
//         it('should return the correct number of addresses paid', async () => {
//           invalidLengthReturn[1].toNumber().should.be.eq(0)
//         })
//
//         it('should return the correct number of storage slots written to', async () => {
//           invalidLengthReturn[2].toNumber().should.be.eq(0)
//         })
//       })
//
//       context('events (#4)', async () => {
//
//         let validEvent
//
//         beforeEach(async () => {
//           validEvent = validEvents[0]
//         })
//
//         it('should emit 1 event, ApplicationExecution', async () => {
//           validEvents.length.should.be.eq(1)
//           validEvent.event.should.be.eq('ApplicationExecution')
//         })
//       })
//
//       context('return (#4)', async () => {
//
//         it('should return a tuple with 3 fields', async () => {
//           validReturn.length.should.be.eq(3)
//         })
//
//         it('should return the correct number of events emitted', async () => {
//           validReturn[0].toNumber().should.be.eq(1)
//         })
//
//         it('should return the correct number of addresses paid', async () => {
//           validReturn[1].toNumber().should.be.eq(0)
//         })
//
//         it('should return the correct number of storage slots written to', async () => {
//           validReturn[2].toNumber().should.be.above(5);
//         })
//       })
//     })
//   })
//
//   describe('#VersionConsole', async () => {
//
//     let providerID
//     let executionContext
//
//     let otherProviderID
//     let otherAccContext
//
//     let appName = 'Application'
//     let appDesc = 'An application that will have many versions'
//     let registerAppCalldata
//     let registerByOtherProvCalldata
//
//     let unregisteredAppName = 'Unregistered'
//
//     let versionOneName = 'v0.0.1'
//     let versionOneDesc = 'Initial version'
//     let versionTwoName = 'v0.0.2'
//     let versionTwoDesc = 'Second version'
//
//     beforeEach(async () => {
//       providerID = await testUtils.getAppProviderHash.call(providerOne).should.be.fulfilled
//       otherProviderID = await testUtils.getAppProviderHash.call(otherAccount).should.be.fulfilled
//
//       web3.toDecimal(providerID).should.not.eq(0)
//       web3.toDecimal(otherProviderID).should.not.eq(0)
//
//       executionContext = await testUtils.getContextFromAddr.call(
//         registryExecId, providerOne, 0
//       ).should.be.fulfilled
//       executionContext.should.not.eq('0x0')
//
//       otherAccContext = await testUtils.getContextFromAddr.call(
//         registryExecId, otherAccount, 0
//       ).should.be.fulfilled
//       otherAccContext.should.not.eq('0x0')
//
//       registerAppCalldata = await registryUtil.registerApp.call(
//         appName, storage.address, appDesc, executionContext
//       ).should.be.fulfilled
//       registerAppCalldata.should.not.eq('0x0')
//
//       let events = await storage.exec(
//         appConsole.address, registryExecId, registerAppCalldata,
//         { from: exec }
//       ).then((tx) => {
//         return tx.logs
//       })
//
//       events.should.not.eq(null)
//       events.length.should.be.eq(1)
//       events[0].event.should.be.eq('ApplicationExecution')
//     })
//
//     context('when a provider registers a unique version with valid parameters', async () => {
//
//       context('for an application that does not exist', async () => {
//
//         let registerV1Calldata
//         let exceptionEvent
//         let exceptionReturn
//
//         beforeEach(async () => {
//           registerV1Calldata = await registryUtil.registerVersion.call(
//             unregisteredAppName, versionOneName, storage.address, versionOneDesc, executionContext
//           ).should.be.fulfilled
//           registerV1Calldata.should.not.eq('0x0')
//
//           exceptionReturn = await storage.exec.call(
//             versionConsole.address, registryExecId, registerV1Calldata,
//             { from: exec }
//           ).should.be.fulfilled
//
//           let events = await storage.exec(
//             versionConsole.address, registryExecId, registerV1Calldata,
//             { from: exec }
//           ).then((tx) => {
//             return tx.logs
//           })
//
//           events.should.not.eq(null)
//           events.length.should.be.eq(1)
//           exceptionEvent = events[0]
//         })
//
//         it('should revert and throw and exception through storage', async () => {
//           hexStrEquals(exceptionEvent.args['message'], 'InsufficientPermissions').should.be.eq(true)
//         })
//
//         describe('returned data', async () => {
//
//           it('should return a tuple with 3 fields', async () => {
//             exceptionReturn.length.should.be.eq(3)
//           })
//
//           it('should return the correct number of events emitted', async () => {
//             exceptionReturn[0].toNumber().should.be.eq(0)
//           })
//
//           it('should return the correct number of addresses paid', async () => {
//             exceptionReturn[1].toNumber().should.be.eq(0)
//           })
//
//           it('should return the correct number of storage slots written to', async () => {
//             exceptionReturn[2].toNumber().should.be.eq(0)
//           })
//         })
//       })
//
//       context('for an application that does exist', async () => {
//
//         let registerV1Calldata
//         let registerV2Calldata
//
//         let execEvents
//         let execEvents2
//
//         let registrationV1Return
//         let registrationV2Return
//
//         beforeEach(async () => {
//           registerV1Calldata = await registryUtil.registerVersion.call(
//             appName, versionOneName, storage.address, versionOneDesc, executionContext
//           ).should.be.fulfilled
//           registerV1Calldata.should.not.eq('0x0')
//
//           registerV2Calldata = await registryUtil.registerVersion.call(
//             appName, versionTwoName, storage.address, versionTwoDesc, executionContext
//           ).should.be.fulfilled
//           registerV2Calldata.should.not.eq('0x0')
//         })
//
//         context('and has no versions', async () => {
//
//           beforeEach(async () => {
//             registrationV1Return = await storage.exec.call(
//               versionConsole.address, registryExecId, registerV1Calldata,
//               { from: exec }
//             ).should.be.fulfilled
//
//             execEvents = await storage.exec(
//               versionConsole.address, registryExecId, registerV1Calldata,
//               { from: exec }
//             ).then((tx) => {
//               return tx.receipt.logs
//             })
//           })
//
//           describe('events', async () => {
//
//             let appTopics
//             let appData
//             let execTopics
//             let execData
//
//             beforeEach(async () => {
//               appTopics = execEvents[0].topics
//               appData = execEvents[0].data
//               execTopics = execEvents[1].topics
//               execData = execEvents[1].data
//             })
//
//             it('should emit 2 events total', async () => {
//               execEvents.length.should.be.eq(2)
//             })
//
//             describe('the ApplicationExecution event', async () => {
//
//               it('should have 3 topics', async () => {
//                 execTopics.length.should.be.eq(3)
//               })
//
//               it('should have the event signature as the first topic', async () => {
//                 let sig = execTopics[0]
//                 web3.toDecimal(sig).should.be.eq(web3.toDecimal(execHash))
//               })
//
//               it('should match the used execution id', async () => {
//                 let emittedExecId = execTopics[1]
//                 emittedExecId.should.be.eq(registryExecId)
//               })
//
//               it('should match the targeted app address', async () => {
//                 let emittedAddr = execTopics[2]
//                 web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(versionConsole.address))
//               })
//
//               it('should have an empty data field', async () => {
//                 execData.should.be.eq('0x0')
//               })
//             })
//
//             describe('the other event', async () => {
//
//               it('should have 4 topics', async () => {
//                 appTopics.length.should.be.eq(4)
//               })
//
//               it('should match the version name in the data field', async () => {
//                 hexStrEquals(appData, versionOneName).should.be.eq(true)
//               })
//
//               it('should match the event signature for the first topic', async () => {
//                 let sig = appTopics[0]
//                 web3.toDecimal(sig).should.be.eq(web3.toDecimal(verRegHash))
//               })
//
//               it('should contain execution ID, provider ID, and app name as the other topics', async () => {
//                 let emittedExecId = appTopics[1]
//                 let emittedProviderId = appTopics[2]
//                 let emittedAppName = appTopics[3]
//                 web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(registryExecId))
//                 web3.toDecimal(emittedProviderId).should.be.eq(web3.toDecimal(providerOneID))
//                 hexStrEquals(emittedAppName, appName).should.be.eq(true)
//               })
//             })
//           })
//
//           describe('storage', async () => {
//
//             it('should set the number of versions of the application to 1', async () => {
//               let appInfo = await initRegistry.getAppInfo.call(
//                 storage.address, registryExecId, providerID, appName
//               ).should.be.fulfilled
//
//               appInfo.length.should.be.eq(3)
//               appInfo[0].toNumber().should.be.eq(1)
//               appInfo[1].should.be.eq(storage.address)
//               hexStrEquals(appInfo[2], appDesc).should.be.eq(true)
//             })
//
//             it('should result in a version list of length 1', async () => {
//               let appVersions = await initRegistry.getAppVersions.call(
//                 storage.address, registryExecId, providerID, appName
//               ).should.be.fulfilled
//
//               appVersions.length.should.be.eq(2)
//               appVersions[0].toNumber().should.be.eq(1)
//               appVersions[1].length.should.be.eq(1)
//               hexStrEquals(appVersions[1][0], versionOneName).should.be.eq(true)
//             })
//
//             it('should return valid version info', async () => {
//               let versionInfo = await initRegistry.getVersionInfo.call(
//                 storage.address, registryExecId, providerID, appName, versionOneName
//               ).should.be.fulfilled
//
//               versionInfo.length.should.be.eq(4)
//               versionInfo[0].should.be.eq(false)
//               versionInfo[1].toNumber().should.be.eq(0)
//               versionInfo[2].should.be.eq(storage.address)
//               hexStrEquals(versionInfo[3], versionOneDesc).should.be.eq(true)
//             })
//           })
//         })
//
//         context('and has versions', async () => {
//
//           beforeEach(async () => {
//             registrationV1Return = await storage.exec.call(
//               versionConsole.address, registryExecId, registerV1Calldata,
//               { from: exec }
//             ).should.be.fulfilled
//             execEvents = await storage.exec(
//               versionConsole.address, registryExecId, registerV1Calldata,
//               { from: exec }
//             ).then((tx) => {
//               return tx.receipt.logs
//             })
//
//             registrationV2Return = await storage.exec.call(
//               versionConsole.address, registryExecId, registerV2Calldata,
//               { from: exec }
//             ).should.be.fulfilled
//             execEvents2 = await storage.exec(
//               versionConsole.address, registryExecId, registerV2Calldata,
//               { from: exec }
//             ).then((tx) => {
//               return tx.receipt.logs
//             })
//           })
//
//           describe('events', async () => {
//
//             let appTopics1
//             let appData1
//             let execTopics1
//             let execData1
//             let appTopics2
//             let appData2
//             let execTopics2
//             let execData2
//
//             beforeEach(async () => {
//               appTopics1 = execEvents[0].topics
//               appData1 = execEvents[0].data
//               execTopics1 = execEvents[1].topics
//               execData1 = execEvents[1].data
//               appTopics2 = execEvents2[0].topics
//               appData2 = execEvents2[0].data
//               execTopics2 = execEvents2[1].topics
//               execData2 = execEvents2[1].data
//             })
//
//             it('should emit 4 events total', async () => {
//               execEvents.length.should.be.eq(2)
//               execEvents2.length.should.be.eq(2)
//             })
//
//             describe('the ApplicationExecution events', async () => {
//
//               it('should both have 3 topics', async () => {
//                 execTopics1.length.should.be.eq(3)
//                 execTopics2.length.should.be.eq(3)
//               })
//
//               it('should both have the event signature as the first topic', async () => {
//                 let sig = execTopics1[0]
//                 web3.toDecimal(sig).should.be.eq(web3.toDecimal(execHash))
//                 sig = execTopics2[0]
//                 web3.toDecimal(sig).should.be.eq(web3.toDecimal(execHash))
//               })
//
//               it('should both match the used execution id', async () => {
//                 let emittedExecId = execTopics1[1]
//                 emittedExecId.should.be.eq(registryExecId)
//                 emittedExecId = execTopics2[1]
//                 emittedExecId.should.be.eq(registryExecId)
//               })
//
//               it('should both match the targeted app address', async () => {
//                 let emittedAddr = execTopics1[2]
//                 web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(versionConsole.address))
//                 emittedAddr = execTopics2[2]
//                 web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(versionConsole.address))
//               })
//
//               it('should both have an empty data field', async () => {
//                 execData1.should.be.eq('0x0')
//                 execData2.should.be.eq('0x0')
//               })
//             })
//
//             describe('the other events', async () => {
//
//               it('should both have 4 topics', async () => {
//                 appTopics1.length.should.be.eq(4)
//                 appTopics2.length.should.be.eq(4)
//               })
//
//               it('should both match the corresponding version name in the data field', async () => {
//                 hexStrEquals(appData1, versionOneName).should.be.eq(true)
//                 hexStrEquals(appData2, versionTwoName).should.be.eq(true)
//               })
//
//               it('should both match the event signature for the first topic', async () => {
//                 let sig = appTopics1[0]
//                 web3.toDecimal(sig).should.be.eq(web3.toDecimal(verRegHash))
//                 sig = appTopics2[0]
//                 web3.toDecimal(sig).should.be.eq(web3.toDecimal(verRegHash))
//               })
//
//               it('should both contain execution ID, provider ID, and app name as the other topics', async () => {
//                 let emittedExecId = appTopics1[1]
//                 let emittedProviderId = appTopics1[2]
//                 let emittedAppName = appTopics1[3]
//                 web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(registryExecId))
//                 web3.toDecimal(emittedProviderId).should.be.eq(web3.toDecimal(providerOneID))
//                 hexStrEquals(emittedAppName, appName).should.be.eq(true)
//                 emittedExecId = appTopics2[1]
//                 emittedProviderId = appTopics2[2]
//                 emittedAppName = appTopics2[3]
//                 web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(registryExecId))
//                 web3.toDecimal(emittedProviderId).should.be.eq(web3.toDecimal(providerOneID))
//                 hexStrEquals(emittedAppName, appName).should.be.eq(true)
//               })
//             })
//           })
//
//           describe('storage', async () => {
//
//             it('should set the number of versions of the application to 2', async () => {
//               let appInfo = await initRegistry.getAppInfo.call(
//                 storage.address, registryExecId, providerID, appName
//               ).should.be.fulfilled
//
//               appInfo.length.should.be.eq(3)
//               appInfo[0].toNumber().should.be.eq(2)
//               appInfo[1].should.be.eq(storage.address)
//               hexStrEquals(appInfo[2], appDesc).should.be.eq(true)
//             })
//
//             it('should result in a version list of length 2', async () => {
//               let appVersions = await initRegistry.getAppVersions.call(
//                 storage.address, registryExecId, providerID, appName
//               ).should.be.fulfilled
//
//               appVersions.length.should.be.eq(2)
//               appVersions[0].toNumber().should.be.eq(2)
//               appVersions[1].length.should.be.eq(2)
//               hexStrEquals(appVersions[1][0], versionOneName).should.be.eq(true)
//               hexStrEquals(appVersions[1][1], versionTwoName).should.be.eq(true)
//             })
//
//             it('should return valid version info for the first version', async () => {
//               let versionInfo = await initRegistry.getVersionInfo.call(
//                 storage.address, registryExecId, providerID, appName, versionOneName
//               ).should.be.fulfilled
//
//               versionInfo.length.should.be.eq(4)
//               versionInfo[0].should.be.eq(false)
//               versionInfo[1].toNumber().should.be.eq(0)
//               versionInfo[2].should.be.eq(storage.address)
//               hexStrEquals(versionInfo[3], versionOneDesc).should.be.eq(true)
//             })
//
//             it('should return valid version info for the second version', async () => {
//               let versionInfo = await initRegistry.getVersionInfo.call(
//                 storage.address, registryExecId, providerID, appName, versionTwoName
//               ).should.be.fulfilled
//
//               versionInfo.length.should.be.eq(4)
//               versionInfo[0].should.be.eq(false)
//               versionInfo[1].toNumber().should.be.eq(0)
//               versionInfo[2].should.be.eq(storage.address)
//               hexStrEquals(versionInfo[3], versionTwoDesc).should.be.eq(true)
//             })
//           })
//         })
//       })
//     })
//
//     context('when a provider registers a version that already exists', async () => {
//
//       let registerV1Calldata
//       let numVersionsInitial
//
//       let invalidEvents
//       let invalidReturn
//
//       beforeEach(async () => {
//         registerV1Calldata = await registryUtil.registerVersion.call(
//           appName, versionOneName, storage.address, versionOneDesc, executionContext
//         ).should.be.fulfilled
//         registerV1Calldata.should.not.eq('0x0')
//
//         let events = await storage.exec(
//           versionConsole.address, registryExecId, registerV1Calldata,
//           { from: exec }
//         ).then((tx) => {
//           return tx.logs
//         })
//
//         events.should.not.eq(null)
//         events.length.should.be.eq(1)
//         events[0].event.should.be.eq('ApplicationExecution')
//
//         let appInfo = await initRegistry.getAppInfo.call(
//           storage.address, registryExecId, providerID, appName
//         ).should.be.fulfilled
//         appInfo.length.should.be.eq(3)
//         numVersionsInitial = appInfo[0].toNumber()
//
//         invalidReturn = await storage.exec.call(
//           versionConsole.address, registryExecId, registerV1Calldata,
//           { from: exec }
//         ).should.be.fulfilled
//         invalidEvents = await storage.exec(
//           versionConsole.address, registryExecId, registerV1Calldata,
//           { from: exec }
//         ).then((tx) => {
//           return tx.logs
//         })
//         invalidEvents.should.not.eq(null)
//         invalidEvents.length.should.be.eq(1)
//       })
//
//       it('should revert and throw an ApplicationException', async () => {
//         invalidEvents[0].event.should.be.eq('ApplicationException')
//         hexStrEquals(invalidEvents[0].args['message'], 'InsufficientPermissions').should.be.eq(true)
//       })
//
//       it('should not change the number of versions registered', async () => {
//         let appInfo = await initRegistry.getAppInfo.call(
//           storage.address, registryExecId, providerID, appName
//         ).should.be.fulfilled
//         appInfo.length.should.be.eq(3)
//         let numVersionsFinal = appInfo[0].toNumber()
//
//         numVersionsInitial.should.be.eq(numVersionsFinal)
//       })
//
//       describe('returned data', async () => {
//
//         it('should return a tuple with 3 fields', async () => {
//           invalidReturn.length.should.be.eq(3)
//         })
//
//         it('should return the correct number of events emitted', async () => {
//           invalidReturn[0].toNumber().should.be.eq(0)
//         })
//
//         it('should return the correct number of addresses paid', async () => {
//           invalidReturn[1].toNumber().should.be.eq(0)
//         })
//
//         it('should return the correct number of storage slots written to', async () => {
//           invalidReturn[2].toNumber().should.be.eq(0)
//         })
//       })
//     })
//
//     context('when a provider does not specify a storage address', async () => {
//       let unspecifedStorage = web3.toHex(0)
//       let registerV1Calldata
//
//       beforeEach(async () => {
//         registerV1Calldata = await registryUtil.registerVersion.call(
//           appName, versionOneName, unspecifedStorage, versionOneDesc, executionContext
//         ).should.be.fulfilled
//         registerV1Calldata.should.not.eq('0x0')
//
//         let events = await storage.exec(
//           versionConsole.address, registryExecId, registerV1Calldata,
//           { from: exec }
//         ).then((tx) => {
//           return tx.logs
//         })
//
//         events.should.not.eq(null)
//         events.length.should.be.eq(1)
//         events[0].event.should.be.eq('ApplicationExecution')
//       })
//
//       it('should default to the app storage address', async () => {
//         let appInfo = await initRegistry.getAppInfo.call(
//           storage.address, registryExecId, providerID, appName
//         ).should.be.fulfilled
//         appInfo.length.should.be.eq(3)
//         let appDefaultStorage = appInfo[1]
//
//         let versionInfo = await initRegistry.getVersionInfo.call(
//           storage.address, registryExecId, providerID, appName, versionOneName
//         ).should.be.fulfilled
//         versionInfo.length.should.be.eq(4)
//         let versionStorage = versionInfo[2]
//
//         appDefaultStorage.should.be.eq(versionStorage)
//       })
//     })
//
//     context('when a provider attempts to register a version with an invalid parameter', async () => {
//
//       let validAppName = appName
//       let validVersionName = 'valid version'
//       let validDescription = 'valid description'
//
//       let invalidCalldata
//       let invalidRegisterEvent
//       let invalidRegisterReturn
//
//       let numRegisteredInitial
//
//       beforeEach(async () => {
//         let appInfo = await initRegistry.getAppInfo.call(
//           storage.address, registryExecId, providerID, validAppName
//         ).should.be.fulfilled
//         appInfo.should.not.eq(null)
//
//         numRegisteredInitial = appInfo[0].toNumber()
//       })
//
//       context('such as the application name', async () => {
//
//         let invalidAppName = ''
//
//         beforeEach(async () => {
//           invalidCalldata = await registryUtil.registerVersion.call(
//             invalidAppName, validVersionName, storage.address, validDescription, executionContext
//           ).should.be.fulfilled
//           invalidCalldata.should.not.eq('0x0')
//
//           invalidRegisterReturn = await storage.exec.call(
//             versionConsole.address, registryExecId, invalidCalldata
//           ).should.be.fulfilled
//           let events = await storage.exec(
//             versionConsole.address, registryExecId, invalidCalldata
//           ).then((tx) => {
//             return tx.logs
//           })
//           events.should.not.eq(null)
//           events.length.should.be.eq(1)
//           invalidRegisterEvent = events[0]
//         })
//
//         it('should revert and emit an ApplicationException event', async () => {
//           invalidRegisterEvent.event.should.be.eq('ApplicationException')
//           let message = invalidRegisterEvent.args['message']
//           hexStrEquals(message, 'DefaultException').should.be.eq(true)
//         })
//
//         it('should not change the number of versions registered', async () => {
//           let appInfo = await initRegistry.getAppInfo(
//             storage.address, registryExecId, providerID, validAppName
//           ).should.be.fulfilled
//           appInfo.should.not.eq(null)
//
//           let numRegisteredFinal = appInfo[0].toNumber()
//
//           numRegisteredInitial.should.be.eq(numRegisteredFinal)
//         })
//
//         describe('returned data', async () => {
//
//           it('should return a tuple with 3 fields', async () => {
//             invalidRegisterReturn.length.should.be.eq(3)
//           })
//
//           it('should return the correct number of events emitted', async () => {
//             invalidRegisterReturn[0].toNumber().should.be.eq(0)
//           })
//
//           it('should return the correct number of addresses paid', async () => {
//             invalidRegisterReturn[1].toNumber().should.be.eq(0)
//           })
//
//           it('should return the correct number of storage slots written to', async () => {
//             invalidRegisterReturn[2].toNumber().should.be.eq(0)
//           })
//         })
//       })
//
//       context('such as the version name', async () => {
//
//         let invalidVersionName = ''
//
//         beforeEach(async () => {
//           invalidCalldata = await registryUtil.registerVersion.call(
//             validAppName, invalidVersionName, storage.address, validDescription, executionContext
//           ).should.be.fulfilled
//           invalidCalldata.should.not.eq('0x0')
//
//           invalidRegisterReturn = await storage.exec.call(
//             versionConsole.address, registryExecId, invalidCalldata
//           ).should.be.fulfilled
//           let events = await storage.exec(
//             versionConsole.address, registryExecId, invalidCalldata
//           ).then((tx) => {
//             return tx.logs
//           })
//           events.should.not.eq(null)
//           events.length.should.be.eq(1)
//
//           invalidRegisterEvent = events[0]
//         })
//
//         it('should revert and emit an ApplicationException event', async () => {
//           invalidRegisterEvent.event.should.be.eq('ApplicationException')
//           let message = invalidRegisterEvent.args['message']
//           hexStrEquals(message, 'DefaultException').should.be.eq(true)
//         })
//
//         it('should not change the number of versions registered', async () => {
//           let appInfo = await initRegistry.getAppInfo.call(
//             storage.address, registryExecId, providerID, validAppName
//           ).should.be.fulfilled
//           appInfo.should.not.eq(null)
//
//           let numRegisteredFinal = appInfo[0].toNumber()
//
//           numRegisteredInitial.should.be.eq(numRegisteredFinal)
//         })
//
//         describe('returned data', async () => {
//
//           it('should return a tuple with 3 fields', async () => {
//             invalidRegisterReturn.length.should.be.eq(3)
//           })
//
//           it('should return the correct number of events emitted', async () => {
//             invalidRegisterReturn[0].toNumber().should.be.eq(0)
//           })
//
//           it('should return the correct number of addresses paid', async () => {
//             invalidRegisterReturn[1].toNumber().should.be.eq(0)
//           })
//
//           it('should return the correct number of storage slots written to', async () => {
//             invalidRegisterReturn[2].toNumber().should.be.eq(0)
//           })
//         })
//       })
//
//       context('such as the version description', async () => {
//
//         let invalidVersionDesc = ''
//
//         beforeEach(async () => {
//           invalidCalldata = await registryUtil.registerVersion.call(
//             validAppName, validVersionName, storage.address, invalidVersionDesc, executionContext
//           ).should.be.fulfilled
//           invalidCalldata.should.not.eq('0x0')
//
//           invalidRegisterReturn = await storage.exec.call(
//             versionConsole.address, registryExecId, invalidCalldata
//           ).should.be.fulfilled
//           let events = await storage.exec(
//             versionConsole.address, registryExecId, invalidCalldata
//           ).then((tx) => {
//             return tx.logs
//           })
//           events.should.not.eq(null)
//           events.length.should.be.eq(1)
//
//           invalidRegisterEvent = events[0]
//         })
//
//         it('should revert and emit an ApplicationException event', async () => {
//           invalidRegisterEvent.event.should.be.eq('ApplicationException')
//           let message = invalidRegisterEvent.args['message']
//           hexStrEquals(message, 'DefaultException').should.be.eq(true)
//         })
//
//         it('should not change the number of versions registered', async () => {
//           let appInfo = await initRegistry.getAppInfo.call(
//             storage.address, registryExecId, providerID, validAppName
//           ).should.be.fulfilled
//           appInfo.should.not.eq(null)
//
//           let numRegisteredFinal = appInfo[0].toNumber()
//
//           numRegisteredInitial.should.be.eq(numRegisteredFinal)
//         })
//
//         describe('returned data', async () => {
//
//           it('should return a tuple with 3 fields', async () => {
//             invalidRegisterReturn.length.should.be.eq(3)
//           })
//
//           it('should return the correct number of events emitted', async () => {
//             invalidRegisterReturn[0].toNumber().should.be.eq(0)
//           })
//
//           it('should return the correct number of addresses paid', async () => {
//             invalidRegisterReturn[1].toNumber().should.be.eq(0)
//           })
//
//           it('should return the correct number of storage slots written to', async () => {
//             invalidRegisterReturn[2].toNumber().should.be.eq(0)
//           })
//         })
//       })
//     })
//
//     context('(no implementation) when the provider finalizes a version with valid input', async () => {
//
//       it('should have default values for getAppLatest', async () => {
//         let appLatest = await initRegistry.getAppLatestInfo.call(
//           storage.address, registryExecId, providerID, appName
//         ).should.be.fulfilled
//         appLatest.should.not.eq(null)
//         appLatest.length.should.be.eq(4)
//
//         appLatest[0].should.be.eq(storage.address)
//         web3.toDecimal(appLatest[1]).should.be.eq(0)
//         web3.toDecimal(appLatest[2]).should.be.eq(0)
//         appLatest[3].length.should.be.eq(0)
//       })
//
//       context('and the version is already finalized', async () => {
//
//         let invalidFinalizeEvent
//         let invalidFinalizeReturn
//
//         beforeEach(async () => {
//           let registerVersionCalldata = await registryUtil.registerVersion.call(
//             appName, versionOneName, storage.address, versionOneDesc, executionContext
//           ).should.be.fulfilled
//           registerVersionCalldata.should.not.eq('0x0')
//
//           let events = await storage.exec(
//             versionConsole.address, registryExecId, registerVersionCalldata,
//             { from: exec }
//           ).then((tx) => {
//             return tx.logs
//           })
//           events.should.not.eq(null)
//           events.length.should.be.eq(1)
//           events[0].event.should.be.eq('ApplicationExecution')
//
//           let finalizeVersionCalldata = await registryUtil.finalizeVersion.call(
//             appName, versionOneName, mockAppInit.address, mockAppInitSig, mockAppInitDesc, executionContext
//           ).should.be.fulfilled
//           finalizeVersionCalldata.should.not.eq('0x0')
//
//           events = await storage.exec(
//             versionConsole.address, registryExecId, finalizeVersionCalldata,
//             { from: exec }
//           ).then((tx) => {
//             return tx.logs
//           })
//           events.should.not.eq(null)
//           events.length.should.be.eq(1)
//           events[0].event.should.be.eq('ApplicationExecution')
//
//           finalizeVersionCalldata = await registryUtil.finalizeVersion.call(
//             appName, versionOneName, mockAppLibOne.address, mockAppInitSig, mockAppInitDesc, executionContext
//           ).should.be.fulfilled
//           finalizeVersionCalldata.should.not.eq('0x0')
//
//           invalidFinalizeReturn = await storage.exec.call(
//             versionConsole.address, registryExecId, finalizeVersionCalldata,
//             { from: exec }
//           ).should.be.fulfilled
//           events = await storage.exec(
//             versionConsole.address, registryExecId, finalizeVersionCalldata,
//             { from: exec }
//           ).then((tx) => {
//             return tx.logs
//           })
//           events.should.not.eq(null)
//           events.length.should.be.eq(1)
//           invalidFinalizeEvent = events[0]
//         })
//
//         it('should emit an ApplicationException event', async () => {
//           invalidFinalizeEvent.event.should.be.eq('ApplicationException')
//           hexStrEquals(invalidFinalizeEvent.args['message'], 'InsufficientPermissions').should.be.eq(true)
//         })
//
//         describe('returned data', async () => {
//
//           it('should return a tuple with 3 fields', async () => {
//             invalidFinalizeReturn.length.should.be.eq(3)
//           })
//
//           it('should return the correct number of events emitted', async () => {
//             invalidFinalizeReturn[0].toNumber().should.be.eq(0)
//           })
//
//           it('should return the correct number of addresses paid', async () => {
//             invalidFinalizeReturn[1].toNumber().should.be.eq(0)
//           })
//
//           it('should return the correct number of storage slots written to', async () => {
//             invalidFinalizeReturn[2].toNumber().should.be.eq(0)
//           })
//         })
//       })
//
//       context('and the provider tries to finalize the app\'s only version', async () => {
//
//         let registerVersionCalldata
//         let finalizeVersionCalldata
//
//         let execEvents
//         let execReturn
//
//         let numVersionsInitial
//
//         beforeEach(async () => {
//           let appInfo = await initRegistry.getAppInfo.call(
//             storage.address, registryExecId, providerID, appName
//           ).should.be.fulfilled
//           appInfo.should.not.eq(null)
//           numVersionsInitial = appInfo[0].toNumber()
//           numVersionsInitial.should.be.eq(0)
//
//           registerVersionCalldata = await registryUtil.registerVersion.call(
//             appName, versionOneName, storage.address, versionOneDesc, executionContext
//           ).should.be.fulfilled
//           registerVersionCalldata.should.not.eq('0x0')
//
//           let events = await storage.exec(
//             versionConsole.address, registryExecId, registerVersionCalldata,
//             { from: exec }
//           ).then((tx) => {
//             return tx.logs
//           })
//           events.should.not.eq(null)
//           events.length.should.be.eq(1)
//           events[0].event.should.be.eq('ApplicationExecution')
//
//           finalizeVersionCalldata = await registryUtil.finalizeVersion.call(
//             appName, versionOneName, mockAppInit.address, mockAppInitSig, mockAppInitDesc, executionContext
//           ).should.be.fulfilled
//           finalizeVersionCalldata.should.not.eq('0x0')
//
//           execReturn = await storage.exec.call(
//             versionConsole.address, registryExecId, finalizeVersionCalldata,
//             { from: exec }
//           ).should.be.fulfilled
//           execEvents = await storage.exec(
//             versionConsole.address, registryExecId, finalizeVersionCalldata,
//             { from: exec }
//           ).then((tx) => {
//             return tx.receipt.logs
//           })
//         })
//
//         describe('events', async () => {
//
//           let appTopics
//           let appData
//           let execTopics
//           let execData
//
//           beforeEach(async () => {
//             appTopics = execEvents[0].topics
//             appData = execEvents[0].data
//             execTopics = execEvents[1].topics
//             execData = execEvents[1].data
//           })
//
//           it('should emit 2 events total', async () => {
//             execEvents.length.should.be.eq(2)
//           })
//
//           describe('the ApplicationExecution event', async () => {
//
//             it('should have 3 topics', async () => {
//               execTopics.length.should.be.eq(3)
//             })
//
//             it('should have the event signature as the first topic', async () => {
//               let sig = execTopics[0]
//               web3.toDecimal(sig).should.be.eq(web3.toDecimal(execHash))
//             })
//
//             it('should match the used execution id', async () => {
//               let emittedExecId = execTopics[1]
//               emittedExecId.should.be.eq(registryExecId)
//             })
//
//             it('should match the targeted app address', async () => {
//               let emittedAddr = execTopics[2]
//               web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(versionConsole.address))
//             })
//
//             it('should have an empty data field', async () => {
//               execData.should.be.eq('0x0')
//             })
//           })
//
//           describe('the other event', async () => {
//
//             it('should have 4 topics', async () => {
//               appTopics.length.should.be.eq(4)
//             })
//
//             it('should both match the corresponding version name in the data field', async () => {
//               hexStrEquals(appData, versionOneName).should.be.eq(true)
//             })
//
//             it('should match the event signature for the first topic', async () => {
//               let sig = appTopics[0]
//               web3.toDecimal(sig).should.be.eq(web3.toDecimal(verFinHash))
//             })
//
//             it('should contain execution ID, provider ID, and app name as the other topics', async () => {
//               let emittedExecId = appTopics[1]
//               let emittedProviderId = appTopics[2]
//               let emittedAppName = appTopics[3]
//               web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(registryExecId))
//               web3.toDecimal(emittedProviderId).should.be.eq(web3.toDecimal(providerOneID))
//               hexStrEquals(emittedAppName, appName).should.be.eq(true)
//             })
//           })
//         })
//
//         describe('returned data', async () => {
//
//           it('should return a tuple with 3 fields', async () => {
//             execReturn.length.should.be.eq(3)
//           })
//
//           it('should return the correct number of events emitted', async () => {
//             execReturn[0].toNumber().should.be.eq(1)
//           })
//
//           it('should return the correct number of addresses paid', async () => {
//             execReturn[1].toNumber().should.be.eq(0)
//           })
//
//           it('should return the correct number of storage slots written to', async () => {
//             execReturn[2].toNumber().should.be.above(5)
//           })
//         })
//
//         describe('storage', async () => {
//
//           it('should have one more version total', async () => {
//             let appInfo = await initRegistry.getAppInfo.call(
//               storage.address, registryExecId, providerID, appName
//             ).should.be.fulfilled
//             appInfo.should.not.eq(null)
//
//             let numVersionsFinal = appInfo[0].toNumber()
//             numVersionsFinal.should.be.eq(numVersionsInitial + 1)
//           })
//
//           it('should have non-default getAppLatestInfo', async () => {
//             let appLatest = await initRegistry.getAppLatestInfo.call(
//               storage.address, registryExecId, providerID, appName
//             ).should.be.fulfilled
//             appLatest.should.not.eq(null)
//             appLatest.length.should.be.eq(4)
//
//             appLatest[0].should.be.eq(storage.address)
//             hexStrEquals(appLatest[1], versionOneName).should.be.eq(true)
//             appLatest[2].should.be.eq(mockAppInit.address)
//             appLatest[3].length.should.be.eq(0)
//           })
//
//           it('should have valid version info', async () => {
//             let versionInfo = await initRegistry.getVersionInfo.call(
//               storage.address, registryExecId, providerID, appName, versionOneName
//             ).should.be.fulfilled
//             versionInfo.should.not.eq(null)
//             versionInfo.length.should.be.eq(4)
//
//             versionInfo[0].should.be.eq(true)
//             versionInfo[1].toNumber().should.be.eq(0)
//             versionInfo[2].should.be.eq(storage.address)
//             hexStrEquals(versionInfo[3], versionOneDesc).should.be.eq(true)
//           })
//
//           it('should have valid init info', async () => {
//             let initInfo = await initRegistry.getVersionInitInfo.call(
//               storage.address, registryExecId, providerID, appName, versionOneName
//             ).should.be.fulfilled
//             initInfo.should.not.eq(null)
//             initInfo.length.should.be.eq(3)
//
//             initInfo[0].should.be.eq(mockAppInit.address)
//             initInfo[1].should.be.eq(mockAppInitSig)
//             hexStrEquals(initInfo[2], mockAppInitDesc).should.be.eq(true)
//           })
//
//           it('should have empty implememntation info', async () => {
//             let implInfo = await initRegistry.getVersionImplementation.call(
//               storage.address, registryExecId, providerID, appName, versionOneName
//             ).should.be.fulfilled
//             implInfo.should.not.eq(null)
//             implInfo.length.should.be.eq(2)
//
//             implInfo[0].length.should.be.eq(0)
//             implInfo[1].length.should.be.eq(0)
//           })
//         })
//       })
//
//       context('and the provider tries to finalize a version in an app with at least 1 version', async () => {
//         let finalizeVersionCalldata
//
//         let execEvents
//         let execReturn
//
//         let numVersionsInitial
//
//         beforeEach(async () => {
//           let registerVersionCalldata = await registryUtil.registerVersion.call(
//             appName, versionOneName, storage.address, versionOneDesc, executionContext
//           ).should.be.fulfilled
//           registerVersionCalldata.should.not.eq('0x0')
//
//           let events = await storage.exec(
//             versionConsole.address, registryExecId, registerVersionCalldata,
//             { from: exec }
//           ).then((tx) => {
//             return tx.logs
//           })
//           events.should.not.eq(null)
//           events.length.should.be.eq(1)
//           events[0].event.should.be.eq('ApplicationExecution')
//
//           let appInfo = await initRegistry.getAppInfo.call(
//             storage.address, registryExecId, providerID, appName
//           ).should.be.fulfilled
//           appInfo.should.not.eq(null)
//           numVersionsInitial = appInfo[0].toNumber()
//           numVersionsInitial.should.be.eq(1)
//
//           registerVersionCalldata = await registryUtil.registerVersion.call(
//             appName, versionTwoName, storage.address, versionTwoDesc, executionContext
//           ).should.be.fulfilled
//           registerVersionCalldata.should.not.eq('0x0')
//
//           events = await storage.exec(
//             versionConsole.address, registryExecId, registerVersionCalldata,
//             { from: exec }
//           ).then((tx) => {
//             return tx.logs
//           })
//           events.should.not.eq(null)
//           events.length.should.be.eq(1)
//           events[0].event.should.be.eq('ApplicationExecution')
//
//           finalizeVersionCalldata = await registryUtil.finalizeVersion.call(
//             appName, versionTwoName, mockAppInit.address, mockAppInitSig, mockAppInitDesc, executionContext
//           ).should.be.fulfilled
//           finalizeVersionCalldata.should.not.eq('0x0')
//
//           execReturn = await storage.exec.call(
//             versionConsole.address, registryExecId, finalizeVersionCalldata,
//             { from: exec }
//           ).should.be.fulfilled
//           execEvents = await storage.exec(
//             versionConsole.address, registryExecId, finalizeVersionCalldata,
//             { from: exec }
//           ).then((tx) => {
//             return tx.receipt.logs
//           })
//         })
//
//         describe('events', async () => {
//
//           let appTopics
//           let appData
//           let execTopics
//           let execData
//
//           beforeEach(async () => {
//             appTopics = execEvents[0].topics
//             appData = execEvents[0].data
//             execTopics = execEvents[1].topics
//             execData = execEvents[1].data
//           })
//
//           it('should emit 2 events total', async () => {
//             execEvents.length.should.be.eq(2)
//           })
//
//           describe('the ApplicationExecution event', async () => {
//
//             it('should have 3 topics', async () => {
//               execTopics.length.should.be.eq(3)
//             })
//
//             it('should have the event signature as the first topic', async () => {
//               let sig = execTopics[0]
//               web3.toDecimal(sig).should.be.eq(web3.toDecimal(execHash))
//             })
//
//             it('should match the used execution id', async () => {
//               let emittedExecId = execTopics[1]
//               emittedExecId.should.be.eq(registryExecId)
//             })
//
//             it('should match the targeted app address', async () => {
//               let emittedAddr = execTopics[2]
//               web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(versionConsole.address))
//             })
//
//             it('should have an empty data field', async () => {
//               execData.should.be.eq('0x0')
//             })
//           })
//
//           describe('the other event', async () => {
//
//             it('should have 4 topics', async () => {
//               appTopics.length.should.be.eq(4)
//             })
//
//             it('should both match the corresponding version name in the data field', async () => {
//               hexStrEquals(appData, versionTwoName).should.be.eq(true)
//             })
//
//             it('should match the event signature for the first topic', async () => {
//               let sig = appTopics[0]
//               web3.toDecimal(sig).should.be.eq(web3.toDecimal(verFinHash))
//             })
//
//             it('should contain execution ID, provider ID, and app name as the other topics', async () => {
//               let emittedExecId = appTopics[1]
//               let emittedProviderId = appTopics[2]
//               let emittedAppName = appTopics[3]
//               web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(registryExecId))
//               web3.toDecimal(emittedProviderId).should.be.eq(web3.toDecimal(providerOneID))
//               hexStrEquals(emittedAppName, appName).should.be.eq(true)
//             })
//           })
//         })
//
//         describe('returned data', async () => {
//
//           it('should return a tuple with 3 fields', async () => {
//             execReturn.length.should.be.eq(3)
//           })
//
//           it('should return the correct number of events emitted', async () => {
//             execReturn[0].toNumber().should.be.eq(1)
//           })
//
//           it('should return the correct number of addresses paid', async () => {
//             execReturn[1].toNumber().should.be.eq(0)
//           })
//
//           it('should return the correct number of storage slots written to', async () => {
//             execReturn[2].toNumber().should.be.above(5)
//           })
//         })
//
//         describe('storage', async () => {
//
//           it('should have one more version total', async () => {
//             let appInfo = await initRegistry.getAppInfo.call(
//               storage.address, registryExecId, providerID, appName
//             ).should.be.fulfilled
//             appInfo.should.not.eq(null)
//
//             let numVersionsFinal = appInfo[0].toNumber()
//             numVersionsFinal.should.be.eq(numVersionsInitial + 1)
//           })
//
//           it('should have non-default getAppLatestInfo', async () => {
//             let appLatest = await initRegistry.getAppLatestInfo.call(
//               storage.address, registryExecId, providerID, appName
//             ).should.be.fulfilled
//             appLatest.should.not.eq(null)
//             appLatest.length.should.be.eq(4)
//
//             appLatest[0].should.be.eq(storage.address)
//             hexStrEquals(appLatest[1], versionTwoName).should.be.eq(true)
//             appLatest[2].should.be.eq(mockAppInit.address)
//             appLatest[3].length.should.be.eq(0)
//           })
//
//           it('should have valid version info', async () => {
//             let versionInfo = await initRegistry.getVersionInfo.call(
//               storage.address, registryExecId, providerID, appName, versionTwoName
//             ).should.be.fulfilled
//             versionInfo.should.not.eq(null)
//             versionInfo.length.should.be.eq(4)
//
//             versionInfo[0].should.be.eq(true)
//             versionInfo[1].toNumber().should.be.eq(0)
//             versionInfo[2].should.be.eq(storage.address)
//             hexStrEquals(versionInfo[3], versionTwoDesc).should.be.eq(true)
//           })
//
//           it('should have valid init info', async () => {
//             let initInfo = await initRegistry.getVersionInitInfo.call(
//               storage.address, registryExecId, providerID, appName, versionTwoName
//             ).should.be.fulfilled
//             initInfo.should.not.eq(null)
//             initInfo.length.should.be.eq(3)
//
//             initInfo[0].should.be.eq(mockAppInit.address)
//             initInfo[1].should.be.eq(mockAppInitSig)
//             hexStrEquals(initInfo[2], mockAppInitDesc).should.be.eq(true)
//           })
//
//           it('should have empty implememntation info', async () => {
//             let implInfo = await initRegistry.getVersionImplementation.call(
//               storage.address, registryExecId, providerID, appName, versionTwoName
//             ).should.be.fulfilled
//             implInfo.should.not.eq(null)
//             implInfo.length.should.be.eq(2)
//
//             implInfo[0].length.should.be.eq(0)
//             implInfo[1].length.should.be.eq(0)
//           })
//         })
//       })
//
//       context('and the provider tries to finalize a version that is not the last version', async () => {
//
//         let versionThreeName = 'v0.0.3'
//         let versionThreeDesc = 'Third version'
//
//         let execEvents
//         let execReturn
//
//         let numVersionsInitial
//
//         beforeEach(async () => {
//           let registerVersionCalldata = await registryUtil.registerVersion.call(
//             appName, versionOneName, storage.address, versionOneDesc, executionContext
//           ).should.be.fulfilled
//           registerVersionCalldata.should.not.eq('0x0')
//
//           let events = await storage.exec(
//             versionConsole.address, registryExecId, registerVersionCalldata,
//             { from: exec }
//           ).then((tx) => {
//             return tx.logs
//           })
//           events.should.not.eq(null)
//           events.length.should.be.eq(1)
//           events[0].event.should.be.eq('ApplicationExecution')
//
//           registerVersionCalldata = await registryUtil.registerVersion.call(
//             appName, versionTwoName, storage.address, versionTwoDesc, executionContext
//           ).should.be.fulfilled
//           registerVersionCalldata.should.not.eq('0x0')
//
//           events = await storage.exec(
//             versionConsole.address, registryExecId, registerVersionCalldata,
//             { from: exec }
//           ).then((tx) => {
//             return tx.logs
//           })
//           events.should.not.eq(null)
//           events.length.should.be.eq(1)
//           events[0].event.should.be.eq('ApplicationExecution')
//
//           registerVersionCalldata = await registryUtil.registerVersion.call(
//             appName, versionThreeName, storage.address, versionThreeDesc, executionContext
//           ).should.be.fulfilled
//           registerVersionCalldata.should.not.eq('0x0')
//
//           events = await storage.exec(
//             versionConsole.address, registryExecId, registerVersionCalldata,
//             { from: exec }
//           ).then((tx) => {
//             return tx.logs
//           })
//
//           let appInfo = await initRegistry.getAppInfo.call(
//             storage.address, registryExecId, providerID, appName
//           ).should.be.fulfilled
//           appInfo.should.not.eq(null)
//
//           numVersionsInitial = appInfo[0].toNumber()
//         })
//
//         context(' - version index is after all other finalized versions', async () => {
//
//           beforeEach(async () => {
//             finalizeVersionCalldata = await registryUtil.finalizeVersion.call(
//               appName, versionThreeName, mockAppInit.address, mockAppInitSig, mockAppInitDesc, executionContext
//             ).should.be.fulfilled
//             finalizeVersionCalldata.should.not.eq('0x0')
//
//             execReturn = await storage.exec.call(
//               versionConsole.address, registryExecId, finalizeVersionCalldata,
//               { from: exec }
//             ).should.be.fulfilled
//             execEvents = await storage.exec(
//               versionConsole.address, registryExecId, finalizeVersionCalldata,
//               { from: exec }
//             ).then((tx) => {
//               return tx.receipt.logs
//             })
//           })
//
//           describe('events', async () => {
//
//             let appTopics
//             let appData
//             let execTopics
//             let execData
//
//             beforeEach(async () => {
//               appTopics = execEvents[0].topics
//               appData = execEvents[0].data
//               execTopics = execEvents[1].topics
//               execData = execEvents[1].data
//             })
//
//             it('should emit 2 events total', async () => {
//               execEvents.length.should.be.eq(2)
//             })
//
//             describe('the ApplicationExecution event', async () => {
//
//               it('should have 3 topics', async () => {
//                 execTopics.length.should.be.eq(3)
//               })
//
//               it('should have the event signature as the first topic', async () => {
//                 let sig = execTopics[0]
//                 web3.toDecimal(sig).should.be.eq(web3.toDecimal(execHash))
//               })
//
//               it('should match the used execution id', async () => {
//                 let emittedExecId = execTopics[1]
//                 emittedExecId.should.be.eq(registryExecId)
//               })
//
//               it('should match the targeted app address', async () => {
//                 let emittedAddr = execTopics[2]
//                 web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(versionConsole.address))
//               })
//
//               it('should have an empty data field', async () => {
//                 execData.should.be.eq('0x0')
//               })
//             })
//
//             describe('the other event', async () => {
//
//               it('should have 4 topics', async () => {
//                 appTopics.length.should.be.eq(4)
//               })
//
//               it('should both match the corresponding version name in the data field', async () => {
//                 hexStrEquals(appData, versionThreeName).should.be.eq(true)
//               })
//
//               it('should match the event signature for the first topic', async () => {
//                 let sig = appTopics[0]
//                 web3.toDecimal(sig).should.be.eq(web3.toDecimal(verFinHash))
//               })
//
//               it('should contain execution ID, provider ID, and app name as the other topics', async () => {
//                 let emittedExecId = appTopics[1]
//                 let emittedProviderId = appTopics[2]
//                 let emittedAppName = appTopics[3]
//                 web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(registryExecId))
//                 web3.toDecimal(emittedProviderId).should.be.eq(web3.toDecimal(providerOneID))
//                 hexStrEquals(emittedAppName, appName).should.be.eq(true)
//               })
//             })
//           })
//
//           describe('returned data', async () => {
//
//             it('should return a tuple with 3 fields', async () => {
//               execReturn.length.should.be.eq(3)
//             })
//
//             it('should return the correct number of events emitted', async () => {
//               execReturn[0].toNumber().should.be.eq(1)
//             })
//
//             it('should return the correct number of addresses paid', async () => {
//               execReturn[1].toNumber().should.be.eq(0)
//             })
//
//             it('should return the correct number of storage slots written to', async () => {
//               execReturn[2].toNumber().should.be.above(5)
//             })
//           })
//
//           describe('storage', async () => {
//
//             it('should have getAppLatestInfo matching the finalized version', async () => {
//               let appLatest = await initRegistry.getAppLatestInfo.call(
//                 storage.address, registryExecId, providerID, appName
//               ).should.be.fulfilled
//               appLatest.should.not.eq(null)
//               appLatest.length.should.be.eq(4)
//
//               appLatest[0].should.be.eq(storage.address)
//               hexStrEquals(appLatest[1], versionThreeName).should.be.eq(true)
//               appLatest[2].should.be.eq(mockAppInit.address)
//               appLatest[3].length.should.be.eq(0)
//             })
//
//             it('should have valid version info for the finalized version', async () => {
//               let versionInfo = await initRegistry.getVersionInfo.call(
//                 storage.address, registryExecId, providerID, appName, versionThreeName
//               ).should.be.fulfilled
//               versionInfo.should.not.eq(null)
//               versionInfo.length.should.be.eq(4)
//
//               versionInfo[0].should.be.eq(true)
//               versionInfo[1].toNumber().should.be.eq(0)
//               versionInfo[2].should.be.eq(storage.address)
//               hexStrEquals(versionInfo[3], versionThreeDesc).should.be.eq(true)
//             })
//
//             it('should have valid init info for the finalized version', async () => {
//               let initInfo = await initRegistry.getVersionInitInfo.call(
//                 storage.address, registryExecId, providerID, appName, versionThreeName
//               ).should.be.fulfilled
//               initInfo.should.not.eq(null)
//               initInfo.length.should.be.eq(3)
//
//               initInfo[0].should.be.eq(mockAppInit.address)
//               initInfo[1].should.be.eq(mockAppInitSig)
//               hexStrEquals(initInfo[2], mockAppInitDesc).should.be.eq(true)
//             })
//           })
//         })
//
//         context(' - version index is before an already finalized version', async () => {
//
//           beforeEach(async () => {
//             finalizeVersionCalldata = await registryUtil.finalizeVersion.call(
//               appName, versionThreeName, mockAppInit.address, mockAppInitSig, mockAppInitDesc, executionContext
//             ).should.be.fulfilled
//             finalizeVersionCalldata.should.not.eq('0x0')
//
//             let events = await storage.exec(
//               versionConsole.address, registryExecId, finalizeVersionCalldata,
//               { from: exec }
//             ).then((tx) => {
//               return tx.logs
//             })
//             events.should.not.eq(null)
//             events.length.should.be.eq(1)
//             events[0].event.should.be.eq('ApplicationExecution')
//
//             finalizeVersionCalldata = await registryUtil.finalizeVersion.call(
//               appName, versionTwoName, mockAppLibOne.address, mockAppInitSig, mockAppInitDesc, executionContext
//             ).should.be.fulfilled
//             finalizeVersionCalldata.should.not.eq('0x0')
//
//             execReturn = await storage.exec.call(
//               versionConsole.address, registryExecId, finalizeVersionCalldata,
//               { from: exec }
//             ).should.be.fulfilled
//             execEvents = await storage.exec(
//               versionConsole.address, registryExecId, finalizeVersionCalldata,
//               { from: exec }
//             ).then((tx) => {
//               return tx.receipt.logs
//             })
//           })
//
//           describe('events', async () => {
//
//             let appTopics
//             let appData
//             let execTopics
//             let execData
//
//             beforeEach(async () => {
//               appTopics = execEvents[0].topics
//               appData = execEvents[0].data
//               execTopics = execEvents[1].topics
//               execData = execEvents[1].data
//             })
//
//             it('should emit 2 events total', async () => {
//               execEvents.length.should.be.eq(2)
//             })
//
//             describe('the ApplicationExecution event', async () => {
//
//               it('should have 3 topics', async () => {
//                 execTopics.length.should.be.eq(3)
//               })
//
//               it('should have the event signature as the first topic', async () => {
//                 let sig = execTopics[0]
//                 web3.toDecimal(sig).should.be.eq(web3.toDecimal(execHash))
//               })
//
//               it('should match the used execution id', async () => {
//                 let emittedExecId = execTopics[1]
//                 emittedExecId.should.be.eq(registryExecId)
//               })
//
//               it('should match the targeted app address', async () => {
//                 let emittedAddr = execTopics[2]
//                 web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(versionConsole.address))
//               })
//
//               it('should have an empty data field', async () => {
//                 execData.should.be.eq('0x0')
//               })
//             })
//
//             describe('the other event', async () => {
//
//               it('should have 4 topics', async () => {
//                 appTopics.length.should.be.eq(4)
//               })
//
//               it('should both match the corresponding version name in the data field', async () => {
//                 hexStrEquals(appData, versionTwoName).should.be.eq(true)
//               })
//
//               it('should match the event signature for the first topic', async () => {
//                 let sig = appTopics[0]
//                 web3.toDecimal(sig).should.be.eq(web3.toDecimal(verFinHash))
//               })
//
//               it('should contain execution ID, provider ID, and app name as the other topics', async () => {
//                 let emittedExecId = appTopics[1]
//                 let emittedProviderId = appTopics[2]
//                 let emittedAppName = appTopics[3]
//                 web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(registryExecId))
//                 web3.toDecimal(emittedProviderId).should.be.eq(web3.toDecimal(providerOneID))
//                 hexStrEquals(emittedAppName, appName).should.be.eq(true)
//               })
//             })
//           })
//
//           describe('returned data', async () => {
//
//             it('should return a tuple with 3 fields', async () => {
//               execReturn.length.should.be.eq(3)
//             })
//
//             it('should return the correct number of events emitted', async () => {
//               execReturn[0].toNumber().should.be.eq(1)
//             })
//
//             it('should return the correct number of addresses paid', async () => {
//               execReturn[1].toNumber().should.be.eq(0)
//             })
//
//             it('should return the correct number of storage slots written to', async () => {
//               execReturn[2].toNumber().should.be.above(5)
//             })
//           })
//
//           describe('storage', async () => {
//
//             it('should have getAppLatestInfo matching the first finalized version', async () => {
//               let appLatest = await initRegistry.getAppLatestInfo.call(
//                 storage.address, registryExecId, providerID, appName
//               ).should.be.fulfilled
//               appLatest.should.not.eq(null)
//               appLatest.length.should.be.eq(4)
//
//               appLatest[0].should.be.eq(storage.address)
//               hexStrEquals(appLatest[1], versionThreeName).should.be.eq(true)
//               appLatest[2].should.be.eq(mockAppInit.address)
//               appLatest[3].length.should.be.eq(0)
//             })
//
//             it('should have valid version info for the first finalized version', async () => {
//               let versionInfo = await initRegistry.getVersionInfo.call(
//                 storage.address, registryExecId, providerID, appName, versionThreeName
//               ).should.be.fulfilled
//               versionInfo.should.not.eq(null)
//               versionInfo.length.should.be.eq(4)
//
//               versionInfo[0].should.be.eq(true)
//               versionInfo[1].toNumber().should.be.eq(0)
//               versionInfo[2].should.be.eq(storage.address)
//               hexStrEquals(versionInfo[3], versionThreeDesc).should.be.eq(true)
//             })
//
//             it('should have valid version info for the second finalized version', async () => {
//               let versionInfo = await initRegistry.getVersionInfo.call(
//                 storage.address, registryExecId, providerID, appName, versionTwoName
//               ).should.be.fulfilled
//               versionInfo.should.not.eq(null)
//               versionInfo.length.should.be.eq(4)
//
//               versionInfo[0].should.be.eq(true)
//               versionInfo[1].toNumber().should.be.eq(0)
//               versionInfo[2].should.be.eq(storage.address)
//               hexStrEquals(versionInfo[3], versionTwoDesc).should.be.eq(true)
//             })
//
//             it('should have valid init info for the first finalized version', async () => {
//               let initInfo = await initRegistry.getVersionInitInfo.call(
//                 storage.address, registryExecId, providerID, appName, versionThreeName
//               ).should.be.fulfilled
//               initInfo.should.not.eq(null)
//               initInfo.length.should.be.eq(3)
//
//               initInfo[0].should.be.eq(mockAppInit.address)
//               initInfo[1].should.be.eq(mockAppInitSig)
//               hexStrEquals(initInfo[2], mockAppInitDesc).should.be.eq(true)
//             })
//
//             it('should have valid init info for the second finalized version', async () => {
//               let initInfo = await initRegistry.getVersionInitInfo.call(
//                 storage.address, registryExecId, providerID, appName, versionTwoName
//               ).should.be.fulfilled
//               initInfo.should.not.eq(null)
//               initInfo.length.should.be.eq(3)
//
//               initInfo[0].should.be.eq(mockAppLibOne.address)
//               initInfo[1].should.be.eq(mockAppInitSig)
//               hexStrEquals(initInfo[2], mockAppInitDesc).should.be.eq(true)
//             })
//           })
//         })
//       })
//     })
//
//     context('when the provider finalizes a version with an invalid parameter', async () => {
//
//       let validAppName = appName
//       let validVersionName = versionOneName
//       let validInitDesc = versionOneDesc
//       let validInitAddr
//       let validInitSig = mockAppInitSig
//
//       let invalidCalldata
//       let invalidEvent
//       let invalidReturn
//
//       beforeEach(async () => {
//         validInitAddr = mockAppInit.address
//
//         let registerVersionCalldata = await registryUtil.registerVersion(
//           validAppName, validVersionName, storage.address, versionOneDesc, executionContext
//         ).should.be.fulfilled
//         registerVersionCalldata.should.not.eq('0x0')
//
//         let events = await storage.exec(
//           versionConsole.address, registryExecId, registerVersionCalldata,
//           { from: exec }
//         ).then((tx) => {
//           return tx.logs
//         })
//         events.should.not.eq(null)
//         events.length.should.be.eq(1)
//         events[0].event.should.be.eq('ApplicationExecution')
//       })
//
//       context('such as the app name', async () => {
//         let invalidAppName = ''
//
//         beforeEach(async () => {
//           invalidCalldata = await registryUtil.finalizeVersion.call(
//             invalidAppName, validVersionName, validInitAddr, validInitSig, validInitDesc, executionContext
//           ).should.be.fulfilled
//           invalidCalldata.should.not.eq('0x0')
//
//           invalidReturn = await storage.exec.call(
//             versionConsole.address, registryExecId, invalidCalldata,
//             { from: exec }
//           ).should.be.fulfilled
//           let events = await storage.exec(
//             versionConsole.address, registryExecId, invalidCalldata,
//             { from: exec }
//           ).then((tx) => {
//             return tx.logs
//           })
//           events.should.not.eq(null)
//           events.length.should.be.eq(1)
//
//           invalidEvent = events[0]
//         })
//
//         describe('returned data', async () => {
//
//           it('should return a tuple with 3 fields', async () => {
//             invalidReturn.length.should.be.eq(3)
//           })
//
//           it('should return the correct number of events emitted', async () => {
//             invalidReturn[0].toNumber().should.be.eq(0)
//           })
//
//           it('should return the correct number of addresses paid', async () => {
//             invalidReturn[1].toNumber().should.be.eq(0)
//           })
//
//           it('should return the correct number of storage slots written to', async () => {
//             invalidReturn[2].toNumber().should.be.eq(0)
//           })
//         })
//
//         it('should emit an ApplicationException event', async () => {
//           invalidEvent.event.should.be.eq('ApplicationException')
//           hexStrEquals(invalidEvent.args['message'], 'DefaultException').should.be.eq(true)
//         })
//
//         it('should still have default getAppLatestInfo', async () => {
//           let appInfo = await initRegistry.getAppLatestInfo.call(
//             storage.address, registryExecId, providerID, appName
//           ).should.be.fulfilled
//           appInfo.should.not.eq(null)
//           appInfo.length.should.be.eq(4)
//
//           web3.toDecimal(appInfo[0]).should.be.eq(0)
//           web3.toDecimal(appInfo[1]).should.be.eq(0)
//           web3.toDecimal(appInfo[2]).should.be.eq(0)
//           appInfo[3].length.should.be.eq(0)
//         })
//       })
//
//       context('such as the version name', async () => {
//         let invalidVersionName = ''
//
//         beforeEach(async () => {
//           invalidCalldata = await registryUtil.finalizeVersion.call(
//             validAppName, invalidVersionName, validInitAddr, validInitSig, validInitDesc, executionContext
//           ).should.be.fulfilled
//           invalidCalldata.should.not.eq('0x0')
//
//           invalidReturn = await storage.exec.call(
//             versionConsole.address, registryExecId, invalidCalldata,
//             { from: exec }
//           ).should.be.fulfilled
//           let events = await storage.exec(
//             versionConsole.address, registryExecId, invalidCalldata,
//             { from: exec }
//           ).then((tx) => {
//             return tx.logs
//           })
//           events.should.not.eq(null)
//           events.length.should.be.eq(1)
//
//           invalidEvent = events[0]
//         })
//
//         describe('returned data', async () => {
//
//           it('should return a tuple with 3 fields', async () => {
//             invalidReturn.length.should.be.eq(3)
//           })
//
//           it('should return the correct number of events emitted', async () => {
//             invalidReturn[0].toNumber().should.be.eq(0)
//           })
//
//           it('should return the correct number of addresses paid', async () => {
//             invalidReturn[1].toNumber().should.be.eq(0)
//           })
//
//           it('should return the correct number of storage slots written to', async () => {
//             invalidReturn[2].toNumber().should.be.eq(0)
//           })
//         })
//
//         it('should emit an ApplicationException event', async () => {
//           invalidEvent.event.should.be.eq('ApplicationException')
//           hexStrEquals(invalidEvent.args['message'], 'DefaultException').should.be.eq(true)
//         })
//
//         it('should still have default getAppLatestInfo', async () => {
//           let appInfo = await initRegistry.getAppLatestInfo.call(
//             storage.address, registryExecId, providerID, appName
//           ).should.be.fulfilled
//           appInfo.should.not.eq(null)
//           appInfo.length.should.be.eq(4)
//
//           web3.toDecimal(appInfo[0]).should.be.eq(0)
//           web3.toDecimal(appInfo[1]).should.be.eq(0)
//           web3.toDecimal(appInfo[2]).should.be.eq(0)
//           appInfo[3].length.should.be.eq(0)
//         })
//       })
//
//       context('such as the init description', async () => {
//         let invalidInitDesc = ''
//
//         beforeEach(async () => {
//           invalidCalldata = await registryUtil.finalizeVersion.call(
//             validAppName, validVersionName, validInitAddr, validInitSig, invalidInitDesc, executionContext
//           ).should.be.fulfilled
//           invalidCalldata.should.not.eq('0x0')
//
//           invalidReturn = await storage.exec.call(
//             versionConsole.address, registryExecId, invalidCalldata,
//             { from: exec }
//           ).should.be.fulfilled
//           let events = await storage.exec(
//             versionConsole.address, registryExecId, invalidCalldata,
//             { from: exec }
//           ).then((tx) => {
//             return tx.logs
//           })
//           events.should.not.eq(null)
//           events.length.should.be.eq(1)
//
//           invalidEvent = events[0]
//         })
//
//         describe('returned data', async () => {
//
//           it('should return a tuple with 3 fields', async () => {
//             invalidReturn.length.should.be.eq(3)
//           })
//
//           it('should return the correct number of events emitted', async () => {
//             invalidReturn[0].toNumber().should.be.eq(0)
//           })
//
//           it('should return the correct number of addresses paid', async () => {
//             invalidReturn[1].toNumber().should.be.eq(0)
//           })
//
//           it('should return the correct number of storage slots written to', async () => {
//             invalidReturn[2].toNumber().should.be.eq(0)
//           })
//         })
//
//         it('should emit an ApplicationException event', async () => {
//           invalidEvent.event.should.be.eq('ApplicationException')
//           hexStrEquals(invalidEvent.args['message'], 'DefaultException').should.be.eq(true)
//         })
//
//         it('should still have default getAppLatestInfo', async () => {
//           let appInfo = await initRegistry.getAppLatestInfo.call(
//             storage.address, registryExecId, providerID, appName
//           ).should.be.fulfilled
//           appInfo.should.not.eq(null)
//           appInfo.length.should.be.eq(4)
//
//           web3.toDecimal(appInfo[0]).should.be.eq(0)
//           web3.toDecimal(appInfo[1]).should.be.eq(0)
//           web3.toDecimal(appInfo[2]).should.be.eq(0)
//           appInfo[3].length.should.be.eq(0)
//         })
//       })
//
//       context('such as the init address', async () => {
//         let invalidInitAddr = web3.toHex(0)
//
//         beforeEach(async () => {
//           invalidCalldata = await registryUtil.finalizeVersion(
//             validAppName, validVersionName, invalidInitAddr, validInitSig, validInitDesc, executionContext
//           ).should.be.fulfilled
//           invalidCalldata.should.not.eq('0x0')
//
//           invalidReturn = await storage.exec.call(
//             versionConsole.address, registryExecId, invalidCalldata,
//             { from: exec }
//           ).should.be.fulfilled
//           let events = await storage.exec(
//             versionConsole.address, registryExecId, invalidCalldata,
//             { from: exec }
//           ).then((tx) => {
//             return tx.logs
//           })
//           events.should.not.eq(null)
//           events.length.should.be.eq(1)
//
//           invalidEvent = events[0]
//         })
//
//         describe('returned data', async () => {
//
//           it('should return a tuple with 3 fields', async () => {
//             invalidReturn.length.should.be.eq(3)
//           })
//
//           it('should return the correct number of events emitted', async () => {
//             invalidReturn[0].toNumber().should.be.eq(0)
//           })
//
//           it('should return the correct number of addresses paid', async () => {
//             invalidReturn[1].toNumber().should.be.eq(0)
//           })
//
//           it('should return the correct number of storage slots written to', async () => {
//             invalidReturn[2].toNumber().should.be.eq(0)
//           })
//         })
//
//         it('should emit an ApplicationException event', async () => {
//           invalidEvent.event.should.be.eq('ApplicationException')
//           hexStrEquals(invalidEvent.args['message'], 'DefaultException').should.be.eq(true)
//         })
//
//         it('should still have default getAppLatestInfo', async () => {
//           let appInfo = await initRegistry.getAppLatestInfo.call(
//             storage.address, registryExecId, providerID, appName
//           ).should.be.fulfilled
//           appInfo.should.not.eq(null)
//           appInfo.length.should.be.eq(4)
//
//           web3.toDecimal(appInfo[0]).should.be.eq(0)
//           web3.toDecimal(appInfo[1]).should.be.eq(0)
//           web3.toDecimal(appInfo[2]).should.be.eq(0)
//           appInfo[3].length.should.be.eq(0)
//         })
//       })
//
//       context('such as the init selector', async () => {
//         let invalidInitSig = '0x00000000'
//
//         beforeEach(async () => {
//           invalidCalldata = await registryUtil.finalizeVersion(
//             validAppName, validVersionName, validInitAddr, invalidInitSig, validInitDesc, executionContext
//           ).should.be.fulfilled
//           invalidCalldata.should.not.eq('0x0')
//
//           invalidReturn = await storage.exec.call(
//             versionConsole.address, registryExecId, invalidCalldata,
//             { from: exec }
//           ).should.be.fulfilled
//           let events = await storage.exec(
//             versionConsole.address, registryExecId, invalidCalldata,
//             { from: exec }
//           ).then((tx) => {
//             return tx.logs
//           })
//           events.should.not.eq(null)
//           events.length.should.be.eq(1)
//
//           invalidEvent = events[0]
//         })
//
//         describe('returned data', async () => {
//
//           it('should return a tuple with 3 fields', async () => {
//             invalidReturn.length.should.be.eq(3)
//           })
//
//           it('should return the correct number of events emitted', async () => {
//             invalidReturn[0].toNumber().should.be.eq(0)
//           })
//
//           it('should return the correct number of addresses paid', async () => {
//             invalidReturn[1].toNumber().should.be.eq(0)
//           })
//
//           it('should return the correct number of storage slots written to', async () => {
//             invalidReturn[2].toNumber().should.be.eq(0)
//           })
//         })
//
//         it('should emit an ApplicationException event', async () => {
//           invalidEvent.event.should.be.eq('ApplicationException')
//           hexStrEquals(invalidEvent.args['message'], 'DefaultException').should.be.eq(true)
//         })
//
//         it('should still have default getAppLatestInfo', async () => {
//           let appInfo = await initRegistry.getAppLatestInfo.call(
//             storage.address, registryExecId, providerID, appName
//           ).should.be.fulfilled
//           appInfo.should.not.eq(null)
//           appInfo.length.should.be.eq(4)
//
//           web3.toDecimal(appInfo[0]).should.be.eq(0)
//           web3.toDecimal(appInfo[1]).should.be.eq(0)
//           web3.toDecimal(appInfo[2]).should.be.eq(0)
//           appInfo[3].length.should.be.eq(0)
//         })
//       })
//     })
//   })
//
//   describe('#ImplementationConsole', async () => {
//
//     let providerID
//     let executionContext
//
//     let appName = 'Application'
//     let appDesc = 'An application that will have many versions'
//
//     let versionName = 'v0.0.1'
//     let versionDesc = 'The initial version of an application'
//
//     let registerAppCalldata
//     let registerVersionCalldata
//     let addFunctionsCalldata
//     let finalizeVersionCalldata
//
//     let registerVersionEvents
//     let addFunctionsEvents
//     let finalizeVersionEvents
//
//     let registerVersionReturn
//     let addFunctionsReturn
//     let finalizeVersionReturn
//
//     let mockLibOneArray
//     let mockLibOneSelArray
//
//     let mockLibTwoArray
//     let twoSelectorArray
//
//     let mockLibThreeArray
//     let threeSelectorArray
//
//     beforeEach(async () => {
//       providerID = await testUtils.getAppProviderHash.call(providerOne).should.be.fulfilled
//       web3.toDecimal(providerID).should.not.eq(0)
//
//       executionContext = await testUtils.getContextFromAddr.call(
//         registryExecId, providerOne, 0
//       ).should.be.fulfilled
//       executionContext.should.not.eq('0x0')
//
//       mockLibOneArray = [mockAppLibOne.address, mockAppLibOne.address]
//       let mockLibSelOne = await mockAppLibOne.funcOneAppOne.call().should.be.fulfilled
//       web3.toDecimal(mockLibSelOne).should.not.eq(0)
//       let mockLibSelTwo = await mockAppLibOne.funcTwoAppOne.call().should.be.fulfilled
//       web3.toDecimal(mockLibSelTwo).should.not.eq(0)
//
//       mockLibOneSelArray = [mockLibSelOne, mockLibSelTwo]
//
//       mockLibTwoArray = []
//       twoSelectorArray = []
//
//       mockLibThreeArray = [mockAppLibThree.address]
//       let mockLibSelThree = await mockAppLibThree.funcOneAppThree.call().should.be.fulfilled
//       web3.toDecimal(mockLibSelThree).should.not.eq(0)
//       threeSelectorArray = [mockLibSelThree]
//
//       registerAppCalldata = await registryUtil.registerApp.call(
//         appName, storage.address, appDesc, executionContext
//       ).should.be.fulfilled
//       registerAppCalldata.should.not.eq('0x0')
//
//       let events = await storage.exec(
//         appConsole.address, registryExecId, registerAppCalldata,
//         { from: exec }
//       ).then((tx) => {
//         return tx.logs
//       })
//       events.should.not.eq(null)
//       events.length.should.be.eq(1)
//       events[0].event.should.be.eq('ApplicationExecution')
//     })
//
//     context('when the provider tries to add functions to a version (valid parameters)', async () => {
//
//       beforeEach(async () => {
//         registerVersionCalldata = await registryUtil.registerVersion.call(
//           appName, versionName, storage.address, versionDesc, executionContext
//         ).should.be.fulfilled
//         registerVersionCalldata.should.not.eq('0x0')
//
//         registerVersionReturn = await storage.exec.call(
//           versionConsole.address, registryExecId, registerVersionCalldata,
//           { from: exec }
//         ).should.be.fulfilled
//         registerVersionEvents = await storage.exec(
//           versionConsole.address, registryExecId, registerVersionCalldata,
//           { from: exec }
//         ).then((tx) => {
//           return tx.logs
//         })
//       })
//
//       context('but the application doesn\'t exist', async () => {
//
//         let unregisteredApp = 'UnregisteredApp'
//
//         beforeEach(async () => {
//           registerVersionCalldata = await registryUtil.registerVersion.call(
//             unregisteredApp, versionName, storage.address, versionDesc, executionContext
//           ).should.be.fulfilled
//           registerVersionCalldata.should.not.eq('0x0')
//
//           registerVersionReturn = await storage.exec.call(
//             versionConsole.address, registryExecId, registerVersionCalldata,
//             { from: exec }
//           ).should.be.fulfilled
//           let events = await storage.exec(
//             versionConsole.address, registryExecId, registerVersionCalldata,
//             { from: exec }
//           ).then((tx) => {
//             return tx.logs
//           })
//           events.should.not.eq(null)
//           events.length.should.be.eq(1)
//           registerVersionEvents = events[0]
//
//           addFunctionsCalldata = await registryUtil.addFunctions.call(
//             unregisteredApp, versionName, mockLibOneSelArray, mockLibOneArray, executionContext
//           ).should.be.fulfilled
//           addFunctionsCalldata.should.not.eq('0x0')
//
//           addFunctionsReturn = await storage.exec.call(
//             implConsole.address, registryExecId, addFunctionsCalldata,
//             { from: exec }
//           ).should.be.fulfilled
//           events = await storage.exec(
//             implConsole.address, registryExecId, addFunctionsCalldata,
//             { from: exec }
//           ).then((tx) => {
//             return tx.logs
//           })
//           events.should.not.eq(null)
//           events.length.should.be.eq(1)
//           addFunctionsEvents = events[0]
//         })
//
//         describe('returned data (version registration)', async () => {
//
//           it('should return a tuple with 3 fields', async () => {
//             registerVersionReturn.length.should.be.eq(3)
//           })
//
//           it('should return the correct number of events emitted', async () => {
//             registerVersionReturn[0].toNumber().should.be.eq(0)
//           })
//
//           it('should return the correct number of addresses paid', async () => {
//             registerVersionReturn[1].toNumber().should.be.eq(0)
//           })
//
//           it('should return the correct number of storage slots written to', async () => {
//             registerVersionReturn[2].toNumber().should.be.eq(0)
//           })
//         })
//
//         describe('returned data (addFunctions)', async () => {
//
//           it('should return a tuple with 3 fields', async () => {
//             addFunctionsReturn.length.should.be.eq(3)
//           })
//
//           it('should return the correct number of events emitted', async () => {
//             addFunctionsReturn[0].toNumber().should.be.eq(0)
//           })
//
//           it('should return the correct number of addresses paid', async () => {
//             addFunctionsReturn[1].toNumber().should.be.eq(0)
//           })
//
//           it('should return the correct number of storage slots written to', async () => {
//             addFunctionsReturn[2].toNumber().should.be.eq(0)
//           })
//         })
//
//         it('should revert version registration with an ApplicationException event', async () => {
//           registerVersionEvents.event.should.be.eq('ApplicationException')
//           hexStrEquals(registerVersionEvents.args['message'], 'InsufficientPermissions').should.be.eq(true)
//         })
//
//         it('should revert adding functions with an ApplicationException event', async () => {
//           addFunctionsEvents.event.should.be.eq('ApplicationException')
//           hexStrEquals(addFunctionsEvents.args['message'], 'InsufficientPermissions').should.be.eq(true)
//         })
//       })
//
//       context('and the application exists', async () => {
//
//         context('but the version doesn\'t exist', async () => {
//
//           let unregisteredVersion = 'UnregisteredVer'
//
//           beforeEach(async () => {
//             addFunctionsCalldata = await registryUtil.addFunctions.call(
//               appName, unregisteredVersion, mockLibOneSelArray, mockLibOneArray, executionContext
//             ).should.be.fulfilled
//             addFunctionsCalldata.should.not.eq('0x0')
//
//             addFunctionsReturn = await storage.exec.call(
//               implConsole.address, registryExecId, addFunctionsCalldata,
//               { from: exec }
//             ).should.be.fulfilled
//             let events = await storage.exec(
//               implConsole.address, registryExecId, addFunctionsCalldata,
//               { from: exec }
//             ).then((tx) => {
//               return tx.logs
//             })
//             events.should.not.eq(null)
//             events.length.should.be.eq(1)
//             addFunctionsEvents = events[0]
//           })
//
//           describe('returned data', async () => {
//
//             it('should return a tuple with 3 fields', async () => {
//               addFunctionsReturn.length.should.be.eq(3)
//             })
//
//             it('should return the correct number of events emitted', async () => {
//               addFunctionsReturn[0].toNumber().should.be.eq(0)
//             })
//
//             it('should return the correct number of addresses paid', async () => {
//               addFunctionsReturn[1].toNumber().should.be.eq(0)
//             })
//
//             it('should return the correct number of storage slots written to', async () => {
//               addFunctionsReturn[2].toNumber().should.be.eq(0)
//             })
//           })
//
//           it('should revert adding functions with an ApplicationException event', async () => {
//             addFunctionsEvents.event.should.be.eq('ApplicationException')
//             hexStrEquals(addFunctionsEvents.args['message'], 'InsufficientPermissions').should.be.eq(true)
//           })
//         })
//
//         context('and the version exists', async () => {
//
//           context('but the version is already finalized', async () => {
//
//             beforeEach(async () => {
//               finalizeVersionCalldata = await registryUtil.finalizeVersion.call(
//                 appName, versionName, mockAppInit.address, mockAppInitSig, mockAppInitDesc, executionContext
//               ).should.be.fulfilled
//               finalizeVersionCalldata.should.not.eq('0x0')
//
//               let events = await storage.exec(
//                 versionConsole.address, registryExecId, finalizeVersionCalldata,
//                 { from: exec }
//               ).then((tx) => {
//                 return tx.logs
//               })
//               events.should.not.eq(null)
//               events.length.should.be.eq(1)
//               events[0].event.should.be.eq('ApplicationExecution')
//
//               addFunctionsCalldata = await registryUtil.addFunctions.call(
//                 appName, versionName, mockLibOneSelArray, mockLibOneArray, executionContext
//               ).should.be.fulfilled
//               addFunctionsCalldata.should.not.eq('0x0')
//
//               addFunctionsReturn = await storage.exec.call(
//                 implConsole.address, registryExecId, addFunctionsCalldata,
//                 { from: exec }
//               ).should.be.fulfilled
//               events = await storage.exec(
//                 implConsole.address, registryExecId, addFunctionsCalldata,
//                 { from: exec }
//               ).then((tx) => {
//                 return tx.logs
//               })
//               events.should.not.eq(null)
//               events.length.should.be.eq(1)
//               addFunctionsEvents = events[0]
//             })
//
//             describe('returned data', async () => {
//
//               it('should return a tuple with 3 fields', async () => {
//                 addFunctionsReturn.length.should.be.eq(3)
//               })
//
//               it('should return the correct number of events emitted', async () => {
//                 addFunctionsReturn[0].toNumber().should.be.eq(0)
//               })
//
//               it('should return the correct number of addresses paid', async () => {
//                 addFunctionsReturn[1].toNumber().should.be.eq(0)
//               })
//
//               it('should return the correct number of storage slots written to', async () => {
//                 addFunctionsReturn[2].toNumber().should.be.eq(0)
//               })
//             })
//
//             it('should revert adding functions with an ApplicationException event', async () => {
//               addFunctionsEvents.event.should.be.eq('ApplicationException')
//               hexStrEquals(addFunctionsEvents.args['message'], 'InsufficientPermissions').should.be.eq(true)
//             })
//           })
//
//           context('and the version is not finalized', async () => {
//
//             beforeEach(async () => {
//               addFunctionsCalldata = await registryUtil.addFunctions.call(
//                 appName, versionName, mockLibOneSelArray, mockLibOneArray, executionContext
//               ).should.be.fulfilled
//               addFunctionsCalldata.should.not.eq('0x0')
//
//               addFunctionsReturn = await storage.exec.call(
//                 implConsole.address, registryExecId, addFunctionsCalldata,
//                 { from: exec }
//               ).should.be.fulfilled
//               let events = await storage.exec(
//                 implConsole.address, registryExecId, addFunctionsCalldata,
//                 { from: exec }
//               ).then((tx) => {
//                 return tx.logs
//               })
//               events.should.not.eq(null)
//               events.length.should.be.eq(1)
//               addFunctionsEvents = events[0]
//             })
//
//             describe('returned data', async () => {
//
//               it('should return a tuple with 3 fields', async () => {
//                 addFunctionsReturn.length.should.be.eq(3)
//               })
//
//               it('should return the correct number of events emitted', async () => {
//                 addFunctionsReturn[0].toNumber().should.be.eq(0)
//               })
//
//               it('should return the correct number of addresses paid', async () => {
//                 addFunctionsReturn[1].toNumber().should.be.eq(0)
//               })
//
//               it('should return the correct number of storage slots written to', async () => {
//                 addFunctionsReturn[2].toNumber().should.be.eq(6)
//               })
//             })
//
//             describe('storage', async () => {
//
//               it('should have default getAppLatestInfo', async () => {
//                 let appLatest = await initRegistry.getAppLatestInfo.call(
//                   storage.address, registryExecId, providerID, appName
//                 ).should.be.fulfilled
//                 appLatest.should.not.eq(null)
//                 appLatest.length.should.be.eq(4)
//
//                 web3.toDecimal(appLatest[0]).should.be.eq(0)
//                 web3.toDecimal(appLatest[1]).should.be.eq(0)
//                 web3.toDecimal(appLatest[2]).should.be.eq(0)
//                 appLatest[3].length.should.be.eq(0)
//               })
//
//               it('should have default getVersionInitInfo', async () => {
//                 let appInit = await initRegistry.getVersionInitInfo.call(
//                   storage.address, registryExecId, providerID, appName, versionName
//                 ).should.be.fulfilled
//                 appInit.should.not.eq(null)
//                 appInit.length.should.be.eq(3)
//
//                 web3.toDecimal(appInit[0]).should.be.eq(0)
//                 web3.toDecimal(appInit[1]).should.be.eq(0)
//                 appInit[2].should.be.eq('0x')
//               })
//
//               it('should have valid version info', async () => {
//                 let versionInfo = await initRegistry.getVersionInfo.call(
//                   storage.address, registryExecId, providerID, appName, versionName
//                 ).should.be.fulfilled
//                 versionInfo.should.not.eq(null)
//                 versionInfo.length.should.be.eq(4)
//
//                 versionInfo[0].should.be.eq(false)
//                 versionInfo[1].toNumber().should.be.eq(2)
//                 versionInfo[2].should.be.eq(storage.address)
//                 hexStrEquals(versionInfo[3], versionDesc).should.be.eq(true)
//               })
//
//               it('should have valid version implementation info', async () => {
//                 let implInfo = await initRegistry.getVersionImplementation.call(
//                   storage.address, registryExecId, providerID, appName, versionName
//                 ).should.be.fulfilled
//                 implInfo.should.not.eq(null)
//                 implInfo.length.should.be.eq(2)
//
//                 implInfo[0].length.should.be.eq(2)
//                 implInfo[1].length.should.be.eq(2)
//
//                 implInfo[0][0].should.be.eq(mockLibOneSelArray[0])
//                 implInfo[0][1].should.be.eq(mockLibOneSelArray[1])
//                 implInfo[1][0].should.be.eq(mockLibOneArray[0])
//                 implInfo[1][1].should.be.eq(mockLibOneArray[1])
//               })
//             })
//
//             it('should emit an ApplicationExecution event', async () => {
//               addFunctionsEvents.event.should.be.eq('ApplicationExecution')
//             })
//           })
//         })
//       })
//     })
//
//     context('when the provider tries to add functions with an invalid parameter', async () => {
//
//       let invalidCalldata
//       let invalidEvent
//       let invalidReturn
//
//       beforeEach(async () => {
//         registerVersionCalldata = await registryUtil.registerVersion.call(
//           appName, versionName, storage.address, versionDesc, executionContext
//         ).should.be.fulfilled
//         registerVersionCalldata.should.not.eq('0x0')
//
//         let events = await storage.exec(
//           versionConsole.address, registryExecId, registerVersionCalldata,
//           { from: exec }
//         ).then((tx) => {
//           return tx.logs
//         })
//         events.should.not.eq(null)
//         events.length.should.be.eq(1)
//         events[0].event.should.be.eq('ApplicationExecution')
//       })
//
//       context('such as the app name', async () => {
//         let invalidAppName = ''
//
//         beforeEach(async () => {
//           invalidCalldata = await registryUtil.addFunctions.call(
//             invalidAppName, versionName, mockLibOneSelArray, mockLibOneArray, executionContext
//           ).should.be.fulfilled
//           addFunctionsCalldata.should.not.eq('0x0')
//
//           invalidReturn = await storage.exec.call(
//             implConsole.address, registryExecId, invalidCalldata,
//             { from: exec }
//           ).should.be.fulfilled
//           let events = await storage.exec(
//             implConsole.address, registryExecId, invalidCalldata,
//             { from: exec }
//           ).then((tx) => {
//             return tx.logs
//           })
//           events.should.not.eq(null)
//           events.length.should.be.eq(1)
//           invalidEvent = events[0]
//         })
//
//         describe('returned data', async () => {
//
//           it('should return a tuple with 3 fields', async () => {
//             invalidReturn.length.should.be.eq(3)
//           })
//
//           it('should return the correct number of events emitted', async () => {
//             invalidReturn[0].toNumber().should.be.eq(0)
//           })
//
//           it('should return the correct number of addresses paid', async () => {
//             invalidReturn[1].toNumber().should.be.eq(0)
//           })
//
//           it('should return the correct number of storage slots written to', async () => {
//             invalidReturn[2].toNumber().should.be.eq(0)
//           })
//         })
//
//         it('should revert and emit an ApplicationException event', async () => {
//           invalidEvent.event.should.be.eq('ApplicationException')
//           hexStrEquals(invalidEvent.args['message'], 'DefaultException').should.be.eq(true)
//         })
//       })
//
//       context('such as the version name', async () => {
//         let invalidVersionName = ''
//
//         beforeEach(async () => {
//           invalidCalldata = await registryUtil.addFunctions.call(
//             appName, invalidVersionName, mockLibOneSelArray, mockLibOneArray, executionContext
//           ).should.be.fulfilled
//           addFunctionsCalldata.should.not.eq('0x0')
//
//           invalidReturn = await storage.exec.call(
//             implConsole.address, registryExecId, invalidCalldata,
//             { from: exec }
//           ).should.be.fulfilled
//           let events = await storage.exec(
//             implConsole.address, registryExecId, invalidCalldata,
//             { from: exec }
//           ).then((tx) => {
//             return tx.logs
//           })
//           events.should.not.eq(null)
//           events.length.should.be.eq(1)
//           invalidEvent = events[0]
//         })
//
//         describe('returned data', async () => {
//
//           it('should return a tuple with 3 fields', async () => {
//             invalidReturn.length.should.be.eq(3)
//           })
//
//           it('should return the correct number of events emitted', async () => {
//             invalidReturn[0].toNumber().should.be.eq(0)
//           })
//
//           it('should return the correct number of addresses paid', async () => {
//             invalidReturn[1].toNumber().should.be.eq(0)
//           })
//
//           it('should return the correct number of storage slots written to', async () => {
//             invalidReturn[2].toNumber().should.be.eq(0)
//           })
//         })
//
//         it('should revert and emit an ApplicationException event', async () => {
//           invalidEvent.event.should.be.eq('ApplicationException')
//           hexStrEquals(invalidEvent.args['message'], 'DefaultException').should.be.eq(true)
//         })
//       })
//
//       context('such as the function signature array length', async () => {
//         let invalidSignatureArray = ['0xaabbccdd']
//
//         beforeEach(async () => {
//           invalidCalldata = await registryUtil.addFunctions.call(
//             appName, versionName, invalidSignatureArray, mockLibOneArray, executionContext
//           ).should.be.fulfilled
//           addFunctionsCalldata.should.not.eq('0x0')
//
//           invalidReturn = await storage.exec.call(
//             implConsole.address, registryExecId, invalidCalldata,
//             { from: exec }
//           ).should.be.fulfilled
//           let events = await storage.exec(
//             implConsole.address, registryExecId, invalidCalldata,
//             { from: exec }
//           ).then((tx) => {
//             return tx.logs
//           })
//           events.should.not.eq(null)
//           events.length.should.be.eq(1)
//           invalidEvent = events[0]
//         })
//
//         describe('returned data', async () => {
//
//           it('should return a tuple with 3 fields', async () => {
//             invalidReturn.length.should.be.eq(3)
//           })
//
//           it('should return the correct number of events emitted', async () => {
//             invalidReturn[0].toNumber().should.be.eq(0)
//           })
//
//           it('should return the correct number of addresses paid', async () => {
//             invalidReturn[1].toNumber().should.be.eq(0)
//           })
//
//           it('should return the correct number of storage slots written to', async () => {
//             invalidReturn[2].toNumber().should.be.eq(0)
//           })
//         })
//
//         it('should revert and emit an ApplicationException event', async () => {
//           invalidEvent.event.should.be.eq('ApplicationException')
//           hexStrEquals(invalidEvent.args['message'], 'DefaultException').should.be.eq(true)
//         })
//       })
//
//       context('such as the function address array length', async () => {
//         let invalidAddressArray = []
//
//         beforeEach(async () => {
//           invalidCalldata = await registryUtil.addFunctions(
//             appName, versionName, mockLibOneSelArray, invalidAddressArray, executionContext
//           ).should.be.fulfilled
//           addFunctionsCalldata.should.not.eq('0x0')
//
//           invalidReturn = await storage.exec.call(
//             implConsole.address, registryExecId, invalidCalldata,
//             { from: exec }
//           ).should.be.fulfilled
//           let events = await storage.exec(
//             implConsole.address, registryExecId, invalidCalldata,
//             { from: exec }
//           ).then((tx) => {
//             return tx.logs
//           })
//           events.should.not.eq(null)
//           events.length.should.be.eq(1)
//           invalidEvent = events[0]
//         })
//
//         describe('returned data', async () => {
//
//           it('should return a tuple with 3 fields', async () => {
//             invalidReturn.length.should.be.eq(3)
//           })
//
//           it('should return the correct number of events emitted', async () => {
//             invalidReturn[0].toNumber().should.be.eq(0)
//           })
//
//           it('should return the correct number of addresses paid', async () => {
//             invalidReturn[1].toNumber().should.be.eq(0)
//           })
//
//           it('should return the correct number of storage slots written to', async () => {
//             invalidReturn[2].toNumber().should.be.eq(0)
//           })
//         })
//
//         it('should revert and emit an ApplicationException event', async () => {
//           invalidEvent.event.should.be.eq('ApplicationException')
//           hexStrEquals(invalidEvent.args['message'], 'DefaultException').should.be.eq(true)
//         })
//       })
//     })
//
//     context('when the provider finalizes a version with functions', async () => {
//
//       let finalizeCalldata
//       let finalizeEvents
//       let finalizeReturn
//
//       let addFunctionsOneCalldata
//       let addFunctionsOneEvents
//       let addFunctionsOneReturn
//
//       let addFunctionsThreeCalldata
//       let addFunctionsThreeEvents
//       let addFunctionsThreeReturn
//
//       beforeEach(async () => {
//         let registerVersionCalldata = await registryUtil.registerVersion.call(
//           appName, versionName, storage.address, versionDesc, executionContext
//         ).should.be.fulfilled
//         registerVersionCalldata.should.not.eq('0x0')
//
//         let events = await storage.exec(
//           versionConsole.address, registryExecId, registerVersionCalldata,
//           { from: exec }
//         ).then((tx) => {
//           return tx.logs
//         })
//         events.should.not.eq(null)
//         events.length.should.be.eq(1)
//         events[0].event.should.be.eq('ApplicationExecution')
//
//         let addFunctionsOneCalldata = await registryUtil.addFunctions.call(
//           appName, versionName, mockLibOneSelArray, mockLibOneArray, executionContext
//         ).should.be.fulfilled
//         addFunctionsOneCalldata.should.not.eq('0x0')
//
//         let addFunctionsThreeCalldata = await registryUtil.addFunctions.call(
//           appName, versionName, threeSelectorArray, mockLibThreeArray, executionContext
//         ).should.be.fulfilled
//         addFunctionsThreeCalldata.should.not.eq('0x0')
//
//         addFunctionsOneReturn = await storage.exec.call(
//           implConsole.address, registryExecId, addFunctionsOneCalldata,
//           { from: exec }
//         ).should.be.fulfilled
//         addFunctionsOneEvents = await storage.exec(
//           implConsole.address, registryExecId, addFunctionsOneCalldata,
//           { from: exec }
//         ).then((tx) => {
//           return tx.logs
//         })
//
//         addFunctionsThreeReturn = await storage.exec.call(
//           implConsole.address, registryExecId, addFunctionsThreeCalldata,
//           { from: exec }
//         ).should.be.fulfilled
//         addFunctionsThreeEvents = await storage.exec(
//           implConsole.address, registryExecId, addFunctionsThreeCalldata,
//           { from: exec }
//         ).then((tx) => {
//           return tx.logs
//         })
//
//         finalizeCalldata = await registryUtil.finalizeVersion.call(
//           appName, versionName, mockAppInit.address, mockAppInitSig, mockAppInitDesc, executionContext
//         ).should.be.fulfilled
//         finalizeCalldata.should.not.eq('0x0')
//
//         finalizeReturn = await storage.exec.call(
//           versionConsole.address, registryExecId, finalizeCalldata,
//           { from: exec }
//         ).should.be.fulfilled
//         finalizeEvents = await storage.exec(
//           versionConsole.address, registryExecId, finalizeCalldata,
//           { from: exec }
//         ).then((tx) => {
//           return tx.receipt.logs
//         })
//       })
//
//       describe('events', async () => {
//
//         describe('addFunctions (#1)', async () => {
//
//           it('should emit one event, total - ApplicationExecution', async () => {
//             addFunctionsOneEvents.length.should.be.eq(1)
//             addFunctionsOneEvents[0].event.should.be.eq('ApplicationExecution')
//           })
//
//           describe('the ApplicationExecution event', async () => {
//
//             it('should match the execution ID used', async () => {
//               let emittedExecId = addFunctionsOneEvents[0].args['execution_id']
//               emittedExecId.should.be.eq(registryExecId)
//             })
//
//             it('should match the target address', async () => {
//               let emittedAddr = addFunctionsOneEvents[0].args['script_target']
//               emittedAddr.should.be.eq(implConsole.address)
//             })
//           })
//         })
//
//         describe('addFunctions (#3)', async () => {
//
//           it('should emit one event, total - ApplicationExecution', async () => {
//             addFunctionsThreeEvents.length.should.be.eq(1)
//             addFunctionsThreeEvents[0].event.should.be.eq('ApplicationExecution')
//           })
//
//           describe('the ApplicationExecution event', async () => {
//
//             it('should match the execution ID used', async () => {
//               let emittedExecId = addFunctionsThreeEvents[0].args['execution_id']
//               emittedExecId.should.be.eq(registryExecId)
//             })
//
//             it('should match the target address', async () => {
//               let emittedAddr = addFunctionsThreeEvents[0].args['script_target']
//               emittedAddr.should.be.eq(implConsole.address)
//             })
//           })
//         })
//
//         describe('finalize', async () => {
//
//           let appTopics
//           let appData
//           let execTopics
//           let execData
//
//           beforeEach(async () => {
//             appTopics = finalizeEvents[0].topics
//             appData = finalizeEvents[0].data
//             execTopics = finalizeEvents[1].topics
//             execData = finalizeEvents[1].data
//           })
//
//           it('should emit 2 events total', async () => {
//             finalizeEvents.length.should.be.eq(2)
//           })
//
//           describe('the ApplicationExecution event', async () => {
//
//             it('should have 3 topics', async () => {
//               execTopics.length.should.be.eq(3)
//             })
//
//             it('should have the event signature as the first topic', async () => {
//               let sig = execTopics[0]
//               web3.toDecimal(sig).should.be.eq(web3.toDecimal(execHash))
//             })
//
//             it('should match the used execution id', async () => {
//               let emittedExecId = execTopics[1]
//               emittedExecId.should.be.eq(registryExecId)
//             })
//
//             it('should match the targeted app address', async () => {
//               let emittedAddr = execTopics[2]
//               web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(versionConsole.address))
//             })
//
//             it('should have an empty data field', async () => {
//               execData.should.be.eq('0x0')
//             })
//           })
//
//           describe('the other event', async () => {
//
//             it('should have 4 topics', async () => {
//               appTopics.length.should.be.eq(4)
//             })
//
//             it('should contain the version name in the data emitted', async () => {
//               hexStrEquals(appData, versionName).should.be.eq(true, appData)
//             })
//
//             it('should contain the event signature as the first topic', async () => {
//               let sig = appTopics[0]
//               web3.toDecimal(sig).should.be.eq(web3.toDecimal(verFinHash))
//             })
//
//             it('should contain the exec id, provider id, and app name as the other events', async () => {
//               let emittedExecId = appTopics[1]
//               let emittedProviderId = appTopics[2]
//               web3.toDecimal(emittedExecId).should.be.eq(web3.toDecimal(registryExecId))
//               web3.toDecimal(emittedProviderId).should.be.eq(web3.toDecimal(providerOneID))
//               hexStrEquals(appTopics[3], appName).should.be.eq(true)
//             })
//           })
//         })
//       })
//
//       describe('returned data', async () => {
//
//         it('should each return a tuple with 3 fields', async () => {
//           finalizeReturn.length.should.be.eq(3)
//           addFunctionsOneReturn.length.should.be.eq(3)
//           addFunctionsThreeReturn.length.should.be.eq(3)
//         })
//
//         describe('addFunctions (#1)', async () => {
//
//           it('should return the correct number of events emitted', async () => {
//             addFunctionsOneReturn[0].toNumber().should.be.eq(0)
//           })
//
//           it('should return the correct number of addresses paid', async () => {
//             addFunctionsOneReturn[1].toNumber().should.be.eq(0)
//           })
//
//           it('should return the correct number of storage slots written to', async () => {
//             addFunctionsOneReturn[2].toNumber().should.be.eq(6)
//           })
//         })
//
//         describe('addFunctions (#3)', async () => {
//
//           it('should return the correct number of events emitted', async () => {
//             addFunctionsThreeReturn[0].toNumber().should.be.eq(0)
//           })
//
//           it('should return the correct number of addresses paid', async () => {
//             addFunctionsThreeReturn[1].toNumber().should.be.eq(0)
//           })
//
//           it('should return the correct number of storage slots written to', async () => {
//             addFunctionsThreeReturn[2].toNumber().should.be.eq(4)
//           })
//         })
//
//         describe('finalize', async () => {
//
//           it('should return the correct number of events emitted', async () => {
//             finalizeReturn[0].toNumber().should.be.eq(1)
//           })
//
//           it('should return the correct number of addresses paid', async () => {
//             finalizeReturn[1].toNumber().should.be.eq(0)
//           })
//
//           it('should return the correct number of storage slots written to', async () => {
//             finalizeReturn[2].toNumber().should.be.above(5)
//           })
//         })
//       })
//
//       describe('storage', async () => {
//
//         it('should store the correct values for getAppLatestInfo', async () => {
//           let appLatest = await initRegistry.getAppLatestInfo.call(
//             storage.address, registryExecId, providerID, appName
//           ).should.be.fulfilled
//           appLatest.should.not.eq(null)
//           appLatest.length.should.be.eq(4)
//
//           appLatest[0].should.be.eq(storage.address)
//           hexStrEquals(appLatest[1], versionName).should.be.eq(true)
//           appLatest[2].should.be.eq(mockAppInit.address)
//           appLatest[3].length.should.be.eq(3)
//
//           appLatest[3][0].should.be.eq(mockLibOneArray[0])
//           appLatest[3][1].should.be.eq(mockLibOneArray[1])
//           appLatest[3][2].should.be.eq(mockLibThreeArray[0])
//         })
//
//         it('should store the correct version info', async () => {
//           let versionInfo = await initRegistry.getVersionInfo.call(
//             storage.address, registryExecId, providerID, appName, versionName
//           ).should.be.fulfilled
//           versionInfo.should.not.eq(null)
//           versionInfo.length.should.be.eq(4)
//
//           versionInfo[0].should.be.eq(true)
//           versionInfo[1].toNumber().should.be.eq(3)
//           versionInfo[2].should.be.eq(storage.address)
//           hexStrEquals(versionInfo[3], versionDesc)
//         })
//
//         it('should store the correct initialization info', async () => {
//           let initInfo = await initRegistry.getVersionInitInfo.call(
//             storage.address, registryExecId, providerID, appName, versionName
//           ).should.be.fulfilled
//           initInfo.should.not.eq(null)
//           initInfo.length.should.be.eq(3)
//
//           initInfo[0].should.be.eq(mockAppInit.address)
//           initInfo[1].should.be.eq(mockAppInitSig)
//           hexStrEquals(initInfo[2], mockAppInitDesc)
//         })
//
//         it('should store the correct version implementation details', async () => {
//           let  implInfo = await initRegistry.getVersionImplementation.call(
//             storage.address, registryExecId, providerID, appName, versionName
//           ).should.be.fulfilled
//           implInfo.should.not.eq(null)
//           implInfo.length.should.be.eq(2)
//
//           implInfo[0].length.should.be.eq(3)
//           implInfo[1].length.should.be.eq(3)
//
//           implInfo[0][0].should.be.eq(mockLibOneSelArray[0])
//           implInfo[0][1].should.be.eq(mockLibOneSelArray[1])
//           implInfo[0][2].should.be.eq(threeSelectorArray[0])
//           implInfo[1][0].should.be.eq(mockLibOneArray[0])
//           implInfo[1][1].should.be.eq(mockLibOneArray[1])
//           implInfo[1][2].should.be.eq(mockLibThreeArray[0])
//         })
//       })
//     })
//   })
// })
