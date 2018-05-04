let InitRegistry = artifacts.require('./InitRegistry')
let AppConsole = artifacts.require('./AppConsole')
let VersionConsole = artifacts.require('./VersionConsole')
let ImplementationConsole = artifacts.require('./ImplementationConsole')

let RegistryStorage = artifacts.require('./mock/RegistryStorageMock')

let MockAppInit = artifacts.require('./mock/ApplicationMockInit')
let MockAppLibOne = artifacts.require('./mock/MockAppOne')
let MockAppLibTwo = artifacts.require('./mock/MockAppTwo')
let MockAppLibThree = artifacts.require('./mock/MockAppThree')

let utils = require('./support/utils.js')
let TestUtils = artifacts.require('./util/TestUtils')
let RegistryUtil = artifacts.require('./util/RegistryUtil')


contract('Script Registry', function(accounts) {
  let storage
  let testUtils
  let registryUtil

  let exec = accounts[0]
  let updater = accounts[1]

  let registryExecId

  let initRegistry
  let initRegistryCalldata = '0xe1c7392a'

  let appConsole
  let versionConsole
  let implConsole

  let mockAppInit
  let mockAppLibOne
  let mockAppLibTwo
  let mockAppLibThree

  let providerOne = accounts[2]
  let providerTwo = accounts[3]
  let otherAccount = accounts[accounts.length - 1]

  beforeEach(async ()  => {
    storage = await RegistryStorage.new().should.be.fulfilled
    testUtils = await TestUtils.new().should.be.fulfilled
    registryUtil = await RegistryUtil.new().should.be.fulfilled

    initRegistry = await InitRegistry.new().should.be.fulfilled

    appConsole = await AppConsole.new().should.be.fulfilled
    versionConsole = await VersionConsole.new().should.be.fulfilled
    implConsole = await ImplementationConsole.new().should.be.fulfilled

    let events = await storage.initAndFinalize(
      updater, false, initRegistry.address, initRegistryCalldata, [
        appConsole.address, versionConsole.address, implConsole.address
      ],
      { from: exec }
    ).then((tx) => {
      return tx.logs
    })

    events.should.not.eq(null)
    events.length.should.be.eq(2)

    registryExecId = events[0].args['execution_id']
    registryExecId.should.not.eq(null)

    mockAppInit = await MockAppInit.new().should.be.fulfilled
    mockAppLibOne = await MockAppLibOne.new().should.be.fulfilled
    mockAppLibTwo = await MockAppLibTwo.new().should.be.fulfilled
    mockAppLibThree = await MockAppLibThree.new().should.be.fulfilled
  })

  describe('#AppConsole', async () => {
    let providerOneID
    let providerTwoID

    let execContextProvOne
    let execContextProvTwo
    let execContextOther

    let appNameOne = 'AppNameOne'
    let appDescOne = 'A generic application'
    let registerOneProvOneCalldata
    let registerOneProvTwoCalldata

    let appNameTwo = 'AppNameTwo'
    let appDescTwo = 'A second, equally-as-generic application'
    let registerTwoProvOneCalldata
    let registerTwoProvTwoCalldata

    beforeEach(async () => {
      execContextProvOne = await testUtils.getContextFromAddr(
        registryExecId, providerOne, 0
      ).should.be.fulfilled
      execContextProvTwo = await testUtils.getContextFromAddr(
        registryExecId, providerTwo, 0
      ).should.be.fulfilled
      execContextOther = await testUtils.getContextFromAddr(
        registryExecId, otherAccount, 0
      ).should.be.fulfilled

      execContextProvOne.should.not.eq('0x')
      execContextProvTwo.should.not.eq('0x')
      execContextOther.should.not.eq('0x')

      providerOneID = await testUtils.getAppProviderHash(providerOne).should.be.fulfilled
      providerTwoID = await testUtils.getAppProviderHash(providerTwo).should.be.fulfilled

      providerOneID.should.not.eq(0)
      providerTwoID.should.not.eq(0)

      registerOneProvOneCalldata = await registryUtil.registerApp(
        appNameOne, storage.address, appDescOne, execContextProvOne
      )
      registerOneProvOneCalldata.should.not.eq('0x')
      registerOneProvTwoCalldata = await registryUtil.registerApp(
        appNameOne, storage.address, appDescOne, execContextProvTwo
      )
      registerOneProvTwoCalldata.should.not.eq('0x')

      registerTwoProvOneCalldata = await registryUtil.registerApp(
        appNameTwo, storage.address, appDescTwo, execContextProvOne
      )
      registerTwoProvOneCalldata.should.not.eq('0x')
      registerTwoProvTwoCalldata = await registryUtil.registerApp(
        appNameTwo, storage.address, appDescTwo, execContextProvTwo
      )
      registerTwoProvTwoCalldata.should.not.eq('0x')
    })

    context('when an application is registered with valid information', async () => {

      let providerOneApps
      let providerTwoApps

      let registryEventOne
      let registryEventTwo
      let registryEventThree
      let registryEventInvalid

      beforeEach(async () => {
        providerOneApps = await initRegistry.getProviderInfo(
          storage.address,
          registryExecId,
          providerOneID
        ).should.be.fulfilled
        providerOneApps.length.should.be.eq(0)

        providerTwoApps = await initRegistry.getProviderInfo(
          storage.address,
          registryExecId,
          providerTwoID
        ).should.be.fulfilled
        providerTwoApps.length.should.be.eq(0)

        registryEventOne = await storage.exec(
          appConsole.address, registryExecId, registerOneProvOneCalldata,
          { from: exec }
        ).then((tx) => {
          return tx.logs
        })

        registryEventTwo = await storage.exec(
          appConsole.address, registryExecId, registerOneProvTwoCalldata,
          { from: exec }
        ).then((tx) => {
          return tx.logs
        })

        registryEventThree = await storage.exec(
          appConsole.address, registryExecId, registerTwoProvTwoCalldata,
          { from: exec }
        ).then((tx) => {
          return tx.logs
        })

        registryEventInvalid = await storage.exec(
          appConsole.address, registryExecId, registerOneProvOneCalldata,
          { from: exec }
        ).then((tx) => {
          return tx.logs
        })
      })

      it('should correctly register one unique application for a provider', async () => {

        let newProviderOneApps = await initRegistry.getProviderInfo(
          storage.address,
          registryExecId,
          providerOneID
        ).should.be.fulfilled
        newProviderOneApps.length.should.be.above(providerOneApps.length)
        newProviderOneApps.length.should.be.eq(1)

        web3.toAscii(newProviderOneApps[0]).substring(0, appNameOne.length).should.be.eq(appNameOne)
      })

      it('should register two unique applications for a provider', async () => {
        let newProviderTwoApps = await initRegistry.getProviderInfo(
          storage.address,
          registryExecId,
          providerTwoID
        ).should.be.fulfilled
        newProviderTwoApps.length.should.be.above(providerTwoApps.length)
        newProviderTwoApps.length.should.be.eq(2)

        web3.toAscii(newProviderTwoApps[0]).substring(0, appNameOne.length).should.be.eq(appNameOne)
        web3.toAscii(newProviderTwoApps[1]).substring(0, appNameTwo.length).should.be.eq(appNameTwo)
      })

      it('should not register an application for a provider if the name is not unique', async () => {
        registryEventInvalid.length.should.be.eq(1)
        let exceptionEvent = registryEventInvalid[0]
        exceptionEvent.event.should.be.eq('ApplicationException')
        exceptionEvent.args['application_address'].should.be.eq(appConsole.address)
        exceptionEvent.args['execution_id'].should.be.eq(registryExecId)
        web3.toAscii(exceptionEvent.args['message']).substring(
          0, 'InsufficientPermissions'.length
        ).should.be.eq('InsufficientPermissions')
      })

      it('should not register an application under another provider', async () => {
        let otherProviderApps = await initRegistry.getProviderInfoFromAddress(
          storage.address, registryExecId, otherAccount
        ).should.be.fulfilled
        let otherProviderID = await testUtils.getAppProviderHash(otherAccount).should.be.fulfilled

        otherProviderApps.length.should.be.eq(2)
        otherProviderApps[0].should.be.eq(otherProviderID)
        otherProviderApps[1].length.should.be.eq(0)
      })

      it('should return information about an application', async () => {
        let appInfoReturn = await initRegistry.getAppInfo(
          storage.address, registryExecId, providerOneID, appNameOne
        ).should.be.fulfilled

        appInfoReturn.length.should.be.eq(3)
        appInfoReturn[0].toNumber().should.be.eq(0)
        appInfoReturn[1].should.be.eq(storage.address)
        web3.toAscii(appInfoReturn[2]).substring(
          0, appDescOne.length
        ).should.be.eq(appDescOne)
      })

      it('should not have any versions registered', async () => {
        let appVersionsReturn = await initRegistry.getAppVersions(
          storage.address, registryExecId, providerOneID, appNameOne
        ).should.be.fulfilled

        appVersionsReturn.length.should.be.eq(2)
        appVersionsReturn[0].toNumber().should.be.eq(0)
        appVersionsReturn[1].length.should.be.eq(0)
      })

      it('should not have information on initialization', async () => {
        let appLatestReturn = await initRegistry.getAppLatestInfo(
          storage.address, registryExecId, providerOneID, appNameOne
        ).should.be.fulfilled

        appLatestReturn.length.should.be.eq(4)
        appLatestReturn[0].should.be.eq(storage.address)
        web3.toDecimal(appLatestReturn[1]).should.be.eq(0)
        web3.toDecimal(appLatestReturn[2]).should.be.eq(0)
        appLatestReturn[3].length.should.be.eq(0)
      })
    })

    context('when an application is registered with invalid input information', async () => {
      let executionContext
      let validCalldata
      let validEvents

      let validAppName = 'valid'
      let validAppStorage
      let validAppDescription = 'valid desc'

      let invalidAppName = ''
      let invalidAppStorage = web3.toHex(0)
      let invalidAppDescription = ''

      let invalidNameCalldata
      let invalidStorageCalldata
      let invalidDescCalldata

      let invalidNameEvents
      let invalidStorageEvents
      let invalidDescEvents

      beforeEach(async () => {
        validAppStorage = storage.address

        executionContext = await testUtils.getContextFromAddr(registryExecId, otherAccount, 0).should.be.fulfilled

        validCalldata = await registryUtil.registerApp(
          validAppName, validAppStorage, validAppDescription, executionContext
        ).should.be.fulfilled

        invalidNameCalldata = await registryUtil.registerApp(
          invalidAppName, validAppStorage, validAppDescription, executionContext
        ).should.be.fulfilled

        invalidStorageCalldata = await registryUtil.registerApp(
          validAppName, invalidAppStorage, validAppDescription, executionContext
        ).should.be.fulfilled

        invalidDescCalldata = await registryUtil.registerApp(
          validAppName, validAppStorage, invalidAppDescription, executionContext
        ).should.be.fulfilled

        invalidNameEvents = await storage.exec(
          appConsole.address, registryExecId, invalidNameCalldata,
          { from: exec }
        ).then((tx) => {
          return tx.logs
        })

        invalidStorageEvents = await storage.exec(
          appConsole.address, registryExecId, invalidStorageCalldata,
          { from: exec }
        ).then((tx) => {
          return tx.logs
        })

        invalidDescEvents = await storage.exec(
          appConsole.address, registryExecId, invalidDescCalldata,
          { from: exec }
        ).then((tx) => {
          return tx.logs
        })

        validEvents = await storage.exec(
          appConsole.address, registryExecId, validCalldata,
          { from: exec }
        ).then((tx) => {
          return tx.logs
        })
      })

      it('should throw an exception if the application name is empty', async () => {
        invalidNameEvents.length.should.be.eq(1)
        invalidNameEvents[0].event.should.be.eq('ApplicationException')
        let message = invalidNameEvents[0].args['message']
        web3.toAscii(message).substring(
          0, 'DefaultException'.length
        ).should.be.eq('DefaultException')
      })

      it('should throw an exception if the application storage address is 0x0', async () => {
        invalidStorageEvents.length.should.be.eq(1)
        invalidStorageEvents[0].event.should.be.eq('ApplicationException')
        let message = invalidStorageEvents[0].args['message']
        web3.toAscii(message).substring(
          0, 'DefaultException'.length
        ).should.be.eq('DefaultException')
      })

      it('should throw an exception if the application description is empty', async () => {
        invalidDescEvents.length.should.be.eq(1)
        invalidDescEvents[0].event.should.be.eq('ApplicationException')
        let message = invalidDescEvents[0].args['message']
        web3.toAscii(message).substring(
          0, 'DefaultException'.length
        ).should.be.eq('DefaultException')
      })

      it('should not throw exception if the input was valid', async () => {
        validEvents.length.should.be.eq(1)
        validEvents[0].event.should.be.eq('ApplicationExecution')
      })
    })

    context('when an application is registered with an invalid context array', async () => {
      let validContext
      let validCalldata
      let validEvents

      let appName = 'valid'
      let appStorage
      let appDescription = 'valid desc'

      let invalidHex = web3.toHex(0)

      let invalidExecIDContext
      let invalidProviderContext
      let invalidLengthContext

      let invalidExecIDCalldata
      let invalidProviderCalldata
      let invalidLengthCalldata

      let invalidExecIDEvents
      let invalidProviderEvents
      let invalidLengthEvents

      beforeEach(async () => {
        appStorage = storage.address

        invalidExecIDContext = await testUtils.getContextFromAddr(invalidHex, otherAccount, 0).should.be.fulfilled
        invalidProviderContext = await testUtils.getContextFromAddr(registryExecId, invalidHex, 0).should.be.fulfilled
        invalidLengthContext = await testUtils.getInvalidContext(registryExecId, otherAccount, 0).should.be.fulfilled
        invalidLengthContext.length.should.be.eq(192)

        validContext = await testUtils.getContextFromAddr(registryExecId, otherAccount, 0).should.be.fulfilled

        validCalldata = await registryUtil.registerApp(
          appName, appStorage, appDescription, validContext
        ).should.be.fulfilled

        invalidExecIDCalldata = await registryUtil.registerApp(
          appName, appStorage, appDescription, invalidExecIDContext
        ).should.be.fulfilled

        invalidProviderCalldata = await registryUtil.registerApp(
          appName, appStorage, appDescription, invalidProviderContext
        ).should.be.fulfilled

        invalidLengthCalldata = await registryUtil.registerApp(
          appName, appStorage, appDescription, invalidLengthContext
        ).should.be.fulfilled

        invalidExecIDEvents = await storage.exec(
          appConsole.address, registryExecId, invalidExecIDCalldata,
          { from: exec }
        ).then((tx) => {
          return tx.logs
        })

        invalidProviderEvents = await storage.exec(
          appConsole.address, registryExecId, invalidProviderCalldata,
          { from: exec }
        ).then((tx) => {
          return tx.logs
        })

        invalidLengthEvents = await storage.exec(
          appConsole.address, registryExecId, invalidLengthCalldata,
          { from: exec }
        ).then((tx) => {
          return tx.logs
        })

        validEvents = await storage.exec(
          appConsole.address, registryExecId, validCalldata,
          { from: exec }
        ).then((tx) => {
          return tx.logs
        })
      })

      it('should throw an exception if the context exec id is 0', async () => {
        invalidExecIDEvents.length.should.be.eq(1)
        invalidExecIDEvents[0].event.should.be.eq('ApplicationException')
        let message = invalidExecIDEvents[0].args['message']
        web3.toAscii(message).substring(
          0, 'UnknownContext'.length
        ).should.be.eq('UnknownContext')
      })

      it('should throw an exception if the context provider value is 0', async () => {
        invalidProviderEvents.length.should.be.eq(1)
        invalidProviderEvents[0].event.should.be.eq('ApplicationException')
        let message = invalidProviderEvents[0].args['message']
        web3.toAscii(message).substring(
          0, 'UnknownContext'.length
        ).should.be.eq('UnknownContext')
      })

      it('should throw an exception if the context array length is incorrect', async () => {
        invalidLengthEvents.length.should.be.eq(1)
        invalidLengthEvents[0].event.should.be.eq('ApplicationException')
        let message = invalidLengthEvents[0].args['message']
        web3.toAscii(message).substring(
          0, 'DefaultException'.length
        ).should.be.eq('DefaultException')
      })

      it('should not throw exception if the input was valid', async () => {
        validEvents.length.should.be.eq(1)
        validEvents[0].event.should.be.eq('ApplicationExecution')
      })
    })
  })

  // contract('VersionConsole', async () => {
  //
  // })
  //
  // contract('ImplementationConsole', async () => {
  //
  // })
})
