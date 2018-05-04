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

function hexStrEquals(hex, expected) {
  return web3.toAscii(hex).substring(0, expected.length) == expected;
}

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
  let mockAppInitSig = '0xe1c7392a'
  let mockAppInitDesc = 'A mock application initialization address'

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

      web3.toDecimal(providerOneID).should.not.eq(0)
      web3.toDecimal(providerTwoID).should.not.eq(0)

      registerOneProvOneCalldata = await registryUtil.registerApp(
        appNameOne, storage.address, appDescOne, execContextProvOne
      ).should.be.fulfilled
      registerOneProvOneCalldata.should.not.eq('0x')

      registerOneProvTwoCalldata = await registryUtil.registerApp(
        appNameOne, storage.address, appDescOne, execContextProvTwo
      ).should.be.fulfilled
      registerOneProvTwoCalldata.should.not.eq('0x')

      registerTwoProvOneCalldata = await registryUtil.registerApp(
        appNameTwo, storage.address, appDescTwo, execContextProvOne
      ).should.be.fulfilled
      registerTwoProvOneCalldata.should.not.eq('0x')

      registerTwoProvTwoCalldata = await registryUtil.registerApp(
        appNameTwo, storage.address, appDescTwo, execContextProvTwo
      ).should.be.fulfilled
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

        hexStrEquals(newProviderOneApps[0], appNameOne).should.be.eq(true)
      })

      it('should register two unique applications for a provider', async () => {
        let newProviderTwoApps = await initRegistry.getProviderInfo(
          storage.address,
          registryExecId,
          providerTwoID
        ).should.be.fulfilled
        newProviderTwoApps.length.should.be.above(providerTwoApps.length)
        newProviderTwoApps.length.should.be.eq(2)

        hexStrEquals(newProviderTwoApps[0], appNameOne).should.be.eq(true)
        hexStrEquals(newProviderTwoApps[1], appNameTwo).should.be.eq(true)
      })

      it('should not register an application for a provider if the name is not unique', async () => {
        registryEventInvalid.length.should.be.eq(1)
        let exceptionEvent = registryEventInvalid[0]
        exceptionEvent.event.should.be.eq('ApplicationException')
        exceptionEvent.args['application_address'].should.be.eq(appConsole.address)
        exceptionEvent.args['execution_id'].should.be.eq(registryExecId)
        hexStrEquals(exceptionEvent.args['message'], 'InsufficientPermissions').should.be.eq(true)
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
        hexStrEquals(appInfoReturn[2], appDescOne).should.be.eq(true)
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
        hexStrEquals(message, 'DefaultException').should.be.eq(true)
      })

      it('should throw an exception if the application storage address is 0x0', async () => {
        invalidStorageEvents.length.should.be.eq(1)
        invalidStorageEvents[0].event.should.be.eq('ApplicationException')
        let message = invalidStorageEvents[0].args['message']
        hexStrEquals(message, 'DefaultException').should.be.eq(true)
      })

      it('should throw an exception if the application description is empty', async () => {
        invalidDescEvents.length.should.be.eq(1)
        invalidDescEvents[0].event.should.be.eq('ApplicationException')
        let message = invalidDescEvents[0].args['message']
        hexStrEquals(message, 'DefaultException').should.be.eq(true)
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
        hexStrEquals(message, 'UnknownContext').should.be.eq(true)
      })

      it('should throw an exception if the context provider value is 0', async () => {
        invalidProviderEvents.length.should.be.eq(1)
        invalidProviderEvents[0].event.should.be.eq('ApplicationException')
        let message = invalidProviderEvents[0].args['message']
        hexStrEquals(message, 'UnknownContext').should.be.eq(true)
      })

      it('should throw an exception if the context array length is incorrect', async () => {
        invalidLengthEvents.length.should.be.eq(1)
        invalidLengthEvents[0].event.should.be.eq('ApplicationException')
        let message = invalidLengthEvents[0].args['message']
        hexStrEquals(message, 'DefaultException').should.be.eq(true)
      })

      it('should not throw exception if the input was valid', async () => {
        validEvents.length.should.be.eq(1)
        validEvents[0].event.should.be.eq('ApplicationExecution')
      })
    })
  })

  describe('#VersionConsole', async () => {

    let providerID
    let executionContext

    let otherProviderID
    let otherAccContext

    let appName = 'Application'
    let appDesc = 'An application that will have many versions'
    let registerAppCalldata
    let registerByOtherProvCalldata

    let unregisteredAppName = 'Unregistered'

    let versionOneName = 'v0.0.1'
    let versionOneDesc = 'Initial version'
    let versionTwoName = 'v0.0.2'
    let versionTwoDesc = 'Second version'

    beforeEach(async () => {
      providerID = await testUtils.getAppProviderHash(providerOne).should.be.fulfilled
      otherProviderID = await testUtils.getAppProviderHash(otherAccount).should.be.fulfilled

      web3.toDecimal(providerID).should.not.eq(0)
      web3.toDecimal(otherProviderID).should.not.eq(0)

      executionContext = await testUtils.getContextFromAddr(
        registryExecId, providerOne, 0
      ).should.be.fulfilled
      executionContext.should.not.eq('0x')

      otherAccContext = await testUtils.getContextFromAddr(
        registryExecId, otherAccount, 0
      ).should.be.fulfilled
      otherAccContext.should.not.eq('0x')

      registerAppCalldata = await registryUtil.registerApp(
        appName, storage.address, appDesc, executionContext
      ).should.be.fulfilled
      registerAppCalldata.should.not.eq('0x')

      let events = await storage.exec(
        appConsole.address, registryExecId, registerAppCalldata,
        { from: exec }
      ).then((tx) => {
        return tx.logs
      })

      events.should.not.eq(null)
      events.length.should.be.eq(1)
      events[0].event.should.be.eq('ApplicationExecution')
    })

    context('when a provider registers a unique version with valid parameters', async () => {

      context('for an application that does not exist', async () => {

        let registerV1Calldata
        let exceptionEvent

        beforeEach(async () => {
          registerV1Calldata = await registryUtil.registerVersion(
            unregisteredAppName, versionOneName, storage.address, versionOneDesc, executionContext
          ).should.be.fulfilled
          registerV1Calldata.should.not.eq('0x')

          let events = await storage.exec(
            versionConsole.address, registryExecId, registerV1Calldata,
            { from: exec }
          ).then((tx) => {
            return tx.logs
          })

          events.should.not.eq(null)
          events.length.should.be.eq(1)
          exceptionEvent = events[0]
        })

        it('should revert and throw and exception through storage', async () => {
          hexStrEquals(exceptionEvent.args['message'], 'InsufficientPermissions').should.be.eq(true)
        })
      })

      context('for an application that does exist', async () => {

        let registerV1Calldata
        let registerV2Calldata

        let registrationV1Event
        let registrationV2Event

        beforeEach(async () => {
          registerV1Calldata = await registryUtil.registerVersion(
            appName, versionOneName, storage.address, versionOneDesc, executionContext
          ).should.be.fulfilled
          registerV1Calldata.should.not.eq('0x')

          registerV2Calldata = await registryUtil.registerVersion(
            appName, versionTwoName, storage.address, versionTwoDesc, executionContext
          ).should.be.fulfilled
          registerV2Calldata.should.not.eq('0x')
        })

        context('and has no versions', async () => {

          beforeEach(async () => {
            let events = await storage.exec(
              versionConsole.address, registryExecId, registerV1Calldata,
              { from: exec }
            ).then((tx) => {
              return tx.logs
            })

            events.should.not.eq(null)
            events.length.should.be.eq(1)
            registrationV1Event = events[0]
          })

          it('should emit an ApplicationExecution event', async () => {
            registrationV1Event.event.should.be.eq('ApplicationExecution')
          })

          it('should set the number of versions of the application to 1', async () => {
            let appInfo = await initRegistry.getAppInfo(
              storage.address, registryExecId, providerID, appName
            ).should.be.fulfilled

            appInfo.length.should.be.eq(3)
            appInfo[0].toNumber().should.be.eq(1)
            appInfo[1].should.be.eq(storage.address)
            hexStrEquals(appInfo[2], appDesc).should.be.eq(true)
          })

          it('should result in a version list of length 1', async () => {
            let appVersions = await initRegistry.getAppVersions(
              storage.address, registryExecId, providerID, appName
            ).should.be.fulfilled

            appVersions.length.should.be.eq(2)
            appVersions[0].toNumber().should.be.eq(1)
            appVersions[1].length.should.be.eq(1)
            hexStrEquals(appVersions[1][0], versionOneName).should.be.eq(true)
          })

          it('should return valid version info', async () => {
            let versionInfo = await initRegistry.getVersionInfo(
              storage.address, registryExecId, providerID, appName, versionOneName
            ).should.be.fulfilled

            versionInfo.length.should.be.eq(4)
            versionInfo[0].should.be.eq(false)
            versionInfo[1].toNumber().should.be.eq(0)
            versionInfo[2].should.be.eq(storage.address)
            hexStrEquals(versionInfo[3], versionOneDesc).should.be.eq(true)
          })
        })

        context('and has versions', async () => {

          beforeEach(async () => {
            let events = await storage.exec(
              versionConsole.address, registryExecId, registerV1Calldata,
              { from: exec }
            ).then((tx) => {
              return tx.logs
            })

            events.should.not.eq(null)
            events.length.should.be.eq(1)
            registrationV1Event = events[0]

            events = await storage.exec(
              versionConsole.address, registryExecId, registerV2Calldata,
              { from: exec }
            ).then((tx) => {
              return tx.logs
            })

            events.should.not.eq(null)
            events.length.should.be.eq(1)
            registrationV2Event = events[0]
          })

          it('should emit 2 ApplicationExecution events', async () => {
            registrationV1Event.event.should.be.eq('ApplicationExecution')
            registrationV2Event.event.should.be.eq('ApplicationExecution')
          })

          it('should set the number of versions of the application to 2', async () => {
            let appInfo = await initRegistry.getAppInfo(
              storage.address, registryExecId, providerID, appName
            ).should.be.fulfilled

            appInfo.length.should.be.eq(3)
            appInfo[0].toNumber().should.be.eq(2)
            appInfo[1].should.be.eq(storage.address)
            hexStrEquals(appInfo[2], appDesc).should.be.eq(true)
          })

          it('should result in a version list of length 2', async () => {
            let appVersions = await initRegistry.getAppVersions(
              storage.address, registryExecId, providerID, appName
            ).should.be.fulfilled

            appVersions.length.should.be.eq(2)
            appVersions[0].toNumber().should.be.eq(2)
            appVersions[1].length.should.be.eq(2)
            hexStrEquals(appVersions[1][0], versionOneName).should.be.eq(true)
            hexStrEquals(appVersions[1][1], versionTwoName).should.be.eq(true)
          })

          it('should return valid version info for the first version', async () => {
            let versionInfo = await initRegistry.getVersionInfo(
              storage.address, registryExecId, providerID, appName, versionOneName
            ).should.be.fulfilled

            versionInfo.length.should.be.eq(4)
            versionInfo[0].should.be.eq(false)
            versionInfo[1].toNumber().should.be.eq(0)
            versionInfo[2].should.be.eq(storage.address)
            hexStrEquals(versionInfo[3], versionOneDesc).should.be.eq(true)
          })

          it('should return valid version info for the second version', async () => {
            let versionInfo = await initRegistry.getVersionInfo(
              storage.address, registryExecId, providerID, appName, versionTwoName
            ).should.be.fulfilled

            versionInfo.length.should.be.eq(4)
            versionInfo[0].should.be.eq(false)
            versionInfo[1].toNumber().should.be.eq(0)
            versionInfo[2].should.be.eq(storage.address)
            hexStrEquals(versionInfo[3], versionTwoDesc).should.be.eq(true)
          })
        })
      })
    })

    context('when a provider registers a version that already exists', async () => {

      let registerV1Calldata
      let secondRegistrationEvent
      let numVersionsInitial

      beforeEach(async () => {
        registerV1Calldata = await registryUtil.registerVersion(
          appName, versionOneName, storage.address, versionOneDesc, executionContext
        ).should.be.fulfilled
        registerV1Calldata.should.not.eq('0x')

        let events = await storage.exec(
          versionConsole.address, registryExecId, registerV1Calldata,
          { from: exec }
        ).then((tx) => {
          return tx.logs
        })

        events.should.not.eq(null)
        events.length.should.be.eq(1)
        events[0].event.should.be.eq('ApplicationExecution')

        let appInfo = await initRegistry.getAppInfo(
          storage.address, registryExecId, providerID, appName
        ).should.be.fulfilled
        appInfo.length.should.be.eq(3)
        numVersionsInitial = appInfo[0].toNumber()

        events = await storage.exec(
          versionConsole.address, registryExecId, registerV1Calldata,
          { from: exec }
        ).then((tx) => {
          return tx.logs
        })

        events.should.not.eq(null)
        events.length.should.be.eq(1)
        secondRegistrationEvent = events[0]
      })

      it('should revert and throw an ApplicationException', async () => {
        secondRegistrationEvent.event.should.be.eq('ApplicationException')
        hexStrEquals(secondRegistrationEvent.args['message'], 'InsufficientPermissions').should.be.eq(true)
      })

      it('should not change the number of versions registered', async () => {
        let appInfo = await initRegistry.getAppInfo(
          storage.address, registryExecId, providerID, appName
        ).should.be.fulfilled
        appInfo.length.should.be.eq(3)
        let numVersionsFinal = appInfo[0].toNumber()

        numVersionsInitial.should.be.eq(numVersionsFinal)
      })
    })

    context('when a provider does not specify a storage address', async () => {
      let unspecifedStorage = web3.toHex(0)
      let registerV1Calldata

      beforeEach(async () => {
        registerV1Calldata = await registryUtil.registerVersion(
          appName, versionOneName, unspecifedStorage, versionOneDesc, executionContext
        ).should.be.fulfilled
        registerV1Calldata.should.not.eq('0x')

        let events = await storage.exec(
          versionConsole.address, registryExecId, registerV1Calldata,
          { from: exec }
        ).then((tx) => {
          return tx.logs
        })

        events.should.not.eq(null)
        events.length.should.be.eq(1)
        events[0].event.should.be.eq('ApplicationExecution')
      })

      it('should default to the app storage address', async () => {
        let appInfo = await initRegistry.getAppInfo(
          storage.address, registryExecId, providerID, appName
        ).should.be.fulfilled
        appInfo.length.should.be.eq(3)
        let appDefaultStorage = appInfo[1]

        let versionInfo = await initRegistry.getVersionInfo(
          storage.address, registryExecId, providerID, appName, versionOneName
        ).should.be.fulfilled
        versionInfo.length.should.be.eq(4)
        let versionStorage = versionInfo[2]

        appDefaultStorage.should.be.eq(versionStorage)
      })
    })

    context('when a provider attempts to register a version with an invalid parameter', async () => {

      let validAppName = appName
      let validVersionName = 'valid version'
      let validDescription = 'valid description'

      let invalidCalldata
      let invalidRegisterEvent

      let numRegisteredInitial

      beforeEach(async () => {
        let appInfo = await initRegistry.getAppInfo(
          storage.address, registryExecId, providerID, validAppName
        ).should.be.fulfilled
        appInfo.should.not.eq(null)

        numRegisteredInitial = appInfo[0].toNumber()
      })

      context('such as the application name', async () => {

        let invalidAppName = ''

        beforeEach(async () => {
          invalidCalldata = await registryUtil.registerVersion(
            invalidAppName, validVersionName, storage.address, validDescription, executionContext
          ).should.be.fulfilled
          invalidCalldata.should.not.eq('0x')

          let events = await storage.exec(
            versionConsole.address, registryExecId, invalidCalldata
          ).then((tx) => {
            return tx.logs
          })
          events.should.not.eq(null)
          events.length.should.be.eq(1)

          invalidRegisterEvent = events[0]
        })

        it('should revert and emit an ApplicationException event', async () => {
          invalidRegisterEvent.event.should.be.eq('ApplicationException')
          let message = invalidRegisterEvent.args['message']
          hexStrEquals(message, 'DefaultException').should.be.eq(true)
        })

        it('should not change the number of versions registered', async () => {
          let appInfo = await initRegistry.getAppInfo(
            storage.address, registryExecId, providerID, validAppName
          ).should.be.fulfilled
          appInfo.should.not.eq(null)

          let numRegisteredFinal = appInfo[0].toNumber()

          numRegisteredInitial.should.be.eq(numRegisteredFinal)
        })
      })

      context('such as the version name', async () => {

        let invalidVersionName = ''

        beforeEach(async () => {
          invalidCalldata = await registryUtil.registerVersion(
            validAppName, invalidVersionName, storage.address, validDescription, executionContext
          ).should.be.fulfilled
          invalidCalldata.should.not.eq('0x')

          let events = await storage.exec(
            versionConsole.address, registryExecId, invalidCalldata
          ).then((tx) => {
            return tx.logs
          })
          events.should.not.eq(null)
          events.length.should.be.eq(1)

          invalidRegisterEvent = events[0]
        })

        it('should revert and emit an ApplicationException event', async () => {
          invalidRegisterEvent.event.should.be.eq('ApplicationException')
          let message = invalidRegisterEvent.args['message']
          hexStrEquals(message, 'DefaultException').should.be.eq(true)
        })

        it('should not change the number of versions registered', async () => {
          let appInfo = await initRegistry.getAppInfo(
            storage.address, registryExecId, providerID, validAppName
          ).should.be.fulfilled
          appInfo.should.not.eq(null)

          let numRegisteredFinal = appInfo[0].toNumber()

          numRegisteredInitial.should.be.eq(numRegisteredFinal)
        })
      })

      context('such as the version description', async () => {

        let invalidVersionDesc = ''

        beforeEach(async () => {
          invalidCalldata = await registryUtil.registerVersion(
            validAppName, validVersionName, storage.address, invalidVersionDesc, executionContext
          ).should.be.fulfilled
          invalidCalldata.should.not.eq('0x')

          let events = await storage.exec(
            versionConsole.address, registryExecId, invalidCalldata
          ).then((tx) => {
            return tx.logs
          })
          events.should.not.eq(null)
          events.length.should.be.eq(1)

          invalidRegisterEvent = events[0]
        })

        it('should revert and emit an ApplicationException event', async () => {
          invalidRegisterEvent.event.should.be.eq('ApplicationException')
          let message = invalidRegisterEvent.args['message']
          hexStrEquals(message, 'DefaultException').should.be.eq(true)
        })

        it('should not change the number of versions registered', async () => {
          let appInfo = await initRegistry.getAppInfo(
            storage.address, registryExecId, providerID, validAppName
          ).should.be.fulfilled
          appInfo.should.not.eq(null)

          let numRegisteredFinal = appInfo[0].toNumber()

          numRegisteredInitial.should.be.eq(numRegisteredFinal)
        })
      })

    })

    context('(no implementation) when the provider finalizes a version with valid input', async () => {

      it('should have default values for getAppLatest', async () => {
        let appLatest = await initRegistry.getAppLatestInfo(
          storage.address, registryExecId, providerID, appName
        ).should.be.fulfilled
        appLatest.should.not.eq(null)
        appLatest.length.should.be.eq(4)

        appLatest[0].should.be.eq(storage.address)
        web3.toDecimal(appLatest[1]).should.be.eq(0)
        web3.toDecimal(appLatest[2]).should.be.eq(0)
        appLatest[3].length.should.be.eq(0)
      })

      context('and the version is already finalized', async () => {

        let secondFinalizeEvent

        beforeEach(async () => {
          let registerVersionCalldata = await registryUtil.registerVersion(
            appName, versionOneName, storage.address, versionOneDesc, executionContext
          ).should.be.fulfilled
          registerVersionCalldata.should.not.eq('0x')

          let events = await storage.exec(
            versionConsole.address, registryExecId, registerVersionCalldata,
            { from: exec }
          ).then((tx) => {
            return tx.logs
          })
          events.should.not.eq(null)
          events.length.should.be.eq(1)
          events[0].event.should.be.eq('ApplicationExecution')

          let finalizeVersionCalldata = await registryUtil.finalizeVersion(
            appName, versionOneName, mockAppInit.address, mockAppInitSig, mockAppInitDesc, executionContext
          ).should.be.fulfilled
          finalizeVersionCalldata.should.not.eq('0x')

          events = await storage.exec(
            versionConsole.address, registryExecId, finalizeVersionCalldata,
            { from: exec }
          ).then((tx) => {
            return tx.logs
          })
          events.should.not.eq(null)
          events.length.should.be.eq(1)
          events[0].event.should.be.eq('ApplicationExecution')

          finalizeVersionCalldata = await registryUtil.finalizeVersion(
            appName, versionOneName, mockAppLibOne.address, mockAppInitSig, mockAppInitDesc, executionContext
          ).should.be.fulfilled
          finalizeVersionCalldata.should.not.eq('0x')

          events = await storage.exec(
            versionConsole.address, registryExecId, finalizeVersionCalldata,
            { from: exec }
          ).then((tx) => {
            return tx.logs
          })
          events.should.not.eq(null)
          events.length.should.be.eq(1)
          secondFinalizeEvent = events[0]
        })

        it('should emit an ApplicationException event', async () => {
          secondFinalizeEvent.event.should.be.eq('ApplicationException')
          hexStrEquals(secondFinalizeEvent.args['message'], 'InsufficientPermissions').should.be.eq(true)
        })
      })

      context('and the provider tries to finalize the app\'s only version', async () => {

        let registerVersionCalldata
        let finalizeVersionCalldata

        let finalizeExecEvent

        let numVersionsInitial

        beforeEach(async () => {
          let appInfo = await initRegistry.getAppInfo(
            storage.address, registryExecId, providerID, appName
          ).should.be.fulfilled
          appInfo.should.not.eq(null)
          numVersionsInitial = appInfo[0].toNumber()
          numVersionsInitial.should.be.eq(0)

          registerVersionCalldata = await registryUtil.registerVersion(
            appName, versionOneName, storage.address, versionOneDesc, executionContext
          ).should.be.fulfilled
          registerVersionCalldata.should.not.eq('0x')

          let events = await storage.exec(
            versionConsole.address, registryExecId, registerVersionCalldata,
            { from: exec }
          ).then((tx) => {
            return tx.logs
          })
          events.should.not.eq(null)
          events.length.should.be.eq(1)
          events[0].event.should.be.eq('ApplicationExecution')

          finalizeVersionCalldata = await registryUtil.finalizeVersion(
            appName, versionOneName, mockAppInit.address, mockAppInitSig, mockAppInitDesc, executionContext
          ).should.be.fulfilled
          finalizeVersionCalldata.should.not.eq('0x')

          events = await storage.exec(
            versionConsole.address, registryExecId, finalizeVersionCalldata,
            { from: exec }
          ).then((tx) => {
            return tx.logs
          })
          events.should.not.eq(null)
          events.length.should.be.eq(1)

          finalizeExecEvent = events[0]
        })

        it('should emit an ApplicationExecution event', async () => {
          finalizeExecEvent.event.should.be.eq('ApplicationExecution')
        })

        it('should have one more version total', async () => {
          let appInfo = await initRegistry.getAppInfo(
            storage.address, registryExecId, providerID, appName
          ).should.be.fulfilled
          appInfo.should.not.eq(null)

          let numVersionsFinal = appInfo[0].toNumber()
          numVersionsFinal.should.be.eq(numVersionsInitial + 1)
        })

        it('should have non-default getAppLatestInfo', async () => {
          let appLatest = await initRegistry.getAppLatestInfo(
            storage.address, registryExecId, providerID, appName
          ).should.be.fulfilled
          appLatest.should.not.eq(null)
          appLatest.length.should.be.eq(4)

          appLatest[0].should.be.eq(storage.address)
          hexStrEquals(appLatest[1], versionOneName).should.be.eq(true)
          appLatest[2].should.be.eq(mockAppInit.address)
          appLatest[3].length.should.be.eq(0)
        })

        it('should have valid version info', async () => {
          let versionInfo = await initRegistry.getVersionInfo(
            storage.address, registryExecId, providerID, appName, versionOneName
          ).should.be.fulfilled
          versionInfo.should.not.eq(null)
          versionInfo.length.should.be.eq(4)

          versionInfo[0].should.be.eq(true)
          versionInfo[1].toNumber().should.be.eq(0)
          versionInfo[2].should.be.eq(storage.address)
          hexStrEquals(versionInfo[3], versionOneDesc).should.be.eq(true)
        })

        it('should have valid init info', async () => {
          let initInfo = await initRegistry.getVersionInitInfo(
            storage.address, registryExecId, providerID, appName, versionOneName
          ).should.be.fulfilled
          initInfo.should.not.eq(null)
          initInfo.length.should.be.eq(3)

          initInfo[0].should.be.eq(mockAppInit.address)
          initInfo[1].should.be.eq(mockAppInitSig)
          hexStrEquals(initInfo[2], mockAppInitDesc).should.be.eq(true)
        })

        it('should have empty implememntation info', async () => {
          let implInfo = await initRegistry.getVersionImplementation(
            storage.address, registryExecId, providerID, appName, versionOneName
          ).should.be.fulfilled
          implInfo.should.not.eq(null)
          implInfo.length.should.be.eq(2)

          implInfo[0].length.should.be.eq(0)
          implInfo[1].length.should.be.eq(0)
        })
      })

      context('and the provider tries to finalize a version in an app with at least 1 version', async () => {
        let finalizeVersionCalldata

        let finalizeExecEvent

        let numVersionsInitial

        beforeEach(async () => {
          let registerVersionCalldata = await registryUtil.registerVersion(
            appName, versionOneName, storage.address, versionOneDesc, executionContext
          ).should.be.fulfilled
          registerVersionCalldata.should.not.eq('0x')

          let events = await storage.exec(
            versionConsole.address, registryExecId, registerVersionCalldata,
            { from: exec }
          ).then((tx) => {
            return tx.logs
          })
          events.should.not.eq(null)
          events.length.should.be.eq(1)
          events[0].event.should.be.eq('ApplicationExecution')

          let appInfo = await initRegistry.getAppInfo(
            storage.address, registryExecId, providerID, appName
          ).should.be.fulfilled
          appInfo.should.not.eq(null)
          numVersionsInitial = appInfo[0].toNumber()
          numVersionsInitial.should.be.eq(1)

          registerVersionCalldata = await registryUtil.registerVersion(
            appName, versionTwoName, storage.address, versionTwoDesc, executionContext
          ).should.be.fulfilled
          registerVersionCalldata.should.not.eq('0x')

          events = await storage.exec(
            versionConsole.address, registryExecId, registerVersionCalldata,
            { from: exec }
          ).then((tx) => {
            return tx.logs
          })
          events.should.not.eq(null)
          events.length.should.be.eq(1)
          events[0].event.should.be.eq('ApplicationExecution')

          finalizeVersionCalldata = await registryUtil.finalizeVersion(
            appName, versionTwoName, mockAppInit.address, mockAppInitSig, mockAppInitDesc, executionContext
          ).should.be.fulfilled
          finalizeVersionCalldata.should.not.eq('0x')

          events = await storage.exec(
            versionConsole.address, registryExecId, finalizeVersionCalldata,
            { from: exec }
          ).then((tx) => {
            return tx.logs
          })
          events.should.not.eq(null)
          events.length.should.be.eq(1)

          finalizeExecEvent = events[0]
        })

        it('should emit an ApplicationExecution event', async () => {
          finalizeExecEvent.event.should.be.eq('ApplicationExecution')
        })

        it('should have one more version total', async () => {
          let appInfo = await initRegistry.getAppInfo(
            storage.address, registryExecId, providerID, appName
          ).should.be.fulfilled
          appInfo.should.not.eq(null)

          let numVersionsFinal = appInfo[0].toNumber()
          numVersionsFinal.should.be.eq(numVersionsInitial + 1)
        })

        it('should have non-default getAppLatestInfo', async () => {
          let appLatest = await initRegistry.getAppLatestInfo(
            storage.address, registryExecId, providerID, appName
          ).should.be.fulfilled
          appLatest.should.not.eq(null)
          appLatest.length.should.be.eq(4)

          appLatest[0].should.be.eq(storage.address)
          hexStrEquals(appLatest[1], versionTwoName).should.be.eq(true)
          appLatest[2].should.be.eq(mockAppInit.address)
          appLatest[3].length.should.be.eq(0)
        })

        it('should have valid version info', async () => {
          let versionInfo = await initRegistry.getVersionInfo(
            storage.address, registryExecId, providerID, appName, versionTwoName
          ).should.be.fulfilled
          versionInfo.should.not.eq(null)
          versionInfo.length.should.be.eq(4)

          versionInfo[0].should.be.eq(true)
          versionInfo[1].toNumber().should.be.eq(0)
          versionInfo[2].should.be.eq(storage.address)
          hexStrEquals(versionInfo[3], versionTwoDesc).should.be.eq(true)
        })

        it('should have valid init info', async () => {
          let initInfo = await initRegistry.getVersionInitInfo(
            storage.address, registryExecId, providerID, appName, versionTwoName
          ).should.be.fulfilled
          initInfo.should.not.eq(null)
          initInfo.length.should.be.eq(3)

          initInfo[0].should.be.eq(mockAppInit.address)
          initInfo[1].should.be.eq(mockAppInitSig)
          hexStrEquals(initInfo[2], mockAppInitDesc).should.be.eq(true)
        })

        it('should have empty implememntation info', async () => {
          let implInfo = await initRegistry.getVersionImplementation(
            storage.address, registryExecId, providerID, appName, versionTwoName
          ).should.be.fulfilled
          implInfo.should.not.eq(null)
          implInfo.length.should.be.eq(2)

          implInfo[0].length.should.be.eq(0)
          implInfo[1].length.should.be.eq(0)
        })
      })

      context('and the provider tries to finalize a version that is not the last version', async () => {

        let versionThreeName = 'v0.0.3'
        let versionThreeDesc = 'Third version'

        let finalizeVersionCalldata
        let finalizeVersionEvent

        let numVersionsInitial

        beforeEach(async () => {
          let registerVersionCalldata = await registryUtil.registerVersion(
            appName, versionOneName, storage.address, versionOneDesc, executionContext
          ).should.be.fulfilled
          registerVersionCalldata.should.not.eq('0x')

          let events = await storage.exec(
            versionConsole.address, registryExecId, registerVersionCalldata,
            { from: exec }
          ).then((tx) => {
            return tx.logs
          })
          events.should.not.eq(null)
          events.length.should.be.eq(1)
          events[0].event.should.be.eq('ApplicationExecution')

          registerVersionCalldata = await registryUtil.registerVersion(
            appName, versionTwoName, storage.address, versionTwoDesc, executionContext
          ).should.be.fulfilled
          registerVersionCalldata.should.not.eq('0x')

          events = await storage.exec(
            versionConsole.address, registryExecId, registerVersionCalldata,
            { from: exec }
          ).then((tx) => {
            return tx.logs
          })
          events.should.not.eq(null)
          events.length.should.be.eq(1)
          events[0].event.should.be.eq('ApplicationExecution')

          registerVersionCalldata = await registryUtil.registerVersion(
            appName, versionThreeName, storage.address, versionThreeDesc, executionContext
          ).should.be.fulfilled
          registerVersionCalldata.should.not.eq('0x')

          events = await storage.exec(
            versionConsole.address, registryExecId, registerVersionCalldata,
            { from: exec }
          ).then((tx) => {
            return tx.logs
          })
          events.should.not.eq(null)
          events.length.should.be.eq(1)
          events[0].event.should.be.eq('ApplicationExecution')

          let appInfo = await initRegistry.getAppInfo(
            storage.address, registryExecId, providerID, appName
          ).should.be.fulfilled
          appInfo.should.not.eq(null)

          numVersionsInitial = appInfo[0].toNumber()
        })

        context(' - version index is after all other finalized versions', async () => {

          beforeEach(async () => {
            finalizeVersionCalldata = await registryUtil.finalizeVersion(
              appName, versionThreeName, mockAppInit.address, mockAppInitSig, mockAppInitDesc, executionContext
            ).should.be.fulfilled
            finalizeVersionCalldata.should.not.eq('0x')

            let events = await storage.exec(
              versionConsole.address, registryExecId, finalizeVersionCalldata,
              { from: exec }
            ).then((tx) => {
              return tx.logs
            })
            events.should.not.eq(null)
            events.length.should.be.eq(1)
            finalizeVersionEvent = events[0]
          })

          it('should emit an ApplicationExecution event', async () => {
            finalizeVersionEvent.event.should.be.eq('ApplicationExecution')
          })

          it('should have getAppLatestInfo matching the finalized version', async () => {
            let appLatest = await initRegistry.getAppLatestInfo(
              storage.address, registryExecId, providerID, appName
            ).should.be.fulfilled
            appLatest.should.not.eq(null)
            appLatest.length.should.be.eq(4)

            appLatest[0].should.be.eq(storage.address)
            hexStrEquals(appLatest[1], versionThreeName).should.be.eq(true)
            appLatest[2].should.be.eq(mockAppInit.address)
            appLatest[3].length.should.be.eq(0)
          })

          it('should have valid version info for the finalized version', async () => {
            let versionInfo = await initRegistry.getVersionInfo(
              storage.address, registryExecId, providerID, appName, versionThreeName
            ).should.be.fulfilled
            versionInfo.should.not.eq(null)
            versionInfo.length.should.be.eq(4)

            versionInfo[0].should.be.eq(true)
            versionInfo[1].toNumber().should.be.eq(0)
            versionInfo[2].should.be.eq(storage.address)
            hexStrEquals(versionInfo[3], versionThreeDesc).should.be.eq(true)
          })

          it('should have valid init info for the finalized version', async () => {
            let initInfo = await initRegistry.getVersionInitInfo(
              storage.address, registryExecId, providerID, appName, versionThreeName
            ).should.be.fulfilled
            initInfo.should.not.eq(null)
            initInfo.length.should.be.eq(3)

            initInfo[0].should.be.eq(mockAppInit.address)
            initInfo[1].should.be.eq(mockAppInitSig)
            hexStrEquals(initInfo[2], mockAppInitDesc).should.be.eq(true)
          })
        })

        context(' - version index is before an already finalized version', async () => {

          beforeEach(async () => {
            finalizeVersionCalldata = await registryUtil.finalizeVersion(
              appName, versionThreeName, mockAppInit.address, mockAppInitSig, mockAppInitDesc, executionContext
            ).should.be.fulfilled
            finalizeVersionCalldata.should.not.eq('0x')

            let events = await storage.exec(
              versionConsole.address, registryExecId, finalizeVersionCalldata,
              { from: exec }
            ).then((tx) => {
              return tx.logs
            })
            events.should.not.eq(null)
            events.length.should.be.eq(1)
            events[0].event.should.be.eq('ApplicationExecution')

            finalizeVersionCalldata = await registryUtil.finalizeVersion(
              appName, versionTwoName, mockAppLibOne.address, mockAppInitSig, mockAppInitDesc, executionContext
            ).should.be.fulfilled
            finalizeVersionCalldata.should.not.eq('0x')

            events = await storage.exec(
              versionConsole.address, registryExecId, finalizeVersionCalldata,
              { from: exec }
            ).then((tx) => {
              return tx.logs
            })
            events.should.not.eq(null)
            events.length.should.be.eq(1)
            events[0].event.should.be.eq('ApplicationExecution')
          })

          it('should emit an ApplicationExecution event', async () => {
            finalizeVersionEvent.event.should.be.eq('ApplicationExecution')
          })

          it('should have getAppLatestInfo matching the first finalized version', async () => {
            let appLatest = await initRegistry.getAppLatestInfo(
              storage.address, registryExecId, providerID, appName
            ).should.be.fulfilled
            appLatest.should.not.eq(null)
            appLatest.length.should.be.eq(4)

            appLatest[0].should.be.eq(storage.address)
            hexStrEquals(appLatest[1], versionThreeName).should.be.eq(true)
            appLatest[2].should.be.eq(mockAppInit.address)
            appLatest[3].length.should.be.eq(0)
          })

          it('should have valid version info for the first finalized version', async () => {
            let versionInfo = await initRegistry.getVersionInfo(
              storage.address, registryExecId, providerID, appName, versionThreeName
            ).should.be.fulfilled
            versionInfo.should.not.eq(null)
            versionInfo.length.should.be.eq(4)

            versionInfo[0].should.be.eq(true)
            versionInfo[1].toNumber().should.be.eq(0)
            versionInfo[2].should.be.eq(storage.address)
            hexStrEquals(versionInfo[3], versionThreeDesc).should.be.eq(true)
          })

          it('should have valid version info for the second finalized version', async () => {
            let versionInfo = await initRegistry.getVersionInfo(
              storage.address, registryExecId, providerID, appName, versionTwoName
            ).should.be.fulfilled
            versionInfo.should.not.eq(null)
            versionInfo.length.should.be.eq(4)

            versionInfo[0].should.be.eq(true)
            versionInfo[1].toNumber().should.be.eq(0)
            versionInfo[2].should.be.eq(storage.address)
            hexStrEquals(versionInfo[3], versionTwoDesc).should.be.eq(true)
          })

          it('should have valid init info for the first finalized version', async () => {
            let initInfo = await initRegistry.getVersionInitInfo(
              storage.address, registryExecId, providerID, appName, versionThreeName
            ).should.be.fulfilled
            initInfo.should.not.eq(null)
            initInfo.length.should.be.eq(3)

            initInfo[0].should.be.eq(mockAppInit.address)
            initInfo[1].should.be.eq(mockAppInitSig)
            hexStrEquals(initInfo[2], mockAppInitDesc).should.be.eq(true)
          })

          it('should have valid init info for the second finalized version', async () => {
            let initInfo = await initRegistry.getVersionInitInfo(
              storage.address, registryExecId, providerID, appName, versionTwoName
            ).should.be.fulfilled
            initInfo.should.not.eq(null)
            initInfo.length.should.be.eq(3)

            initInfo[0].should.be.eq(mockAppLibOne.address)
            initInfo[1].should.be.eq(mockAppInitSig)
            hexStrEquals(initInfo[2], mockAppInitDesc).should.be.eq(true)
          })
        })
      })
    })

    context('when the provider finalizes a version with an invalid parameter', async () => {

      let validAppName = appName
      let validVersionName = versionOneName
      let validInitDesc = versionOneDesc
      let validInitAddr
      let validInitSig = mockAppInitSig

      let invalidCalldata
      let invalidFinalizeEvent

      beforeEach(async () => {
        validInitAddr = mockAppInit.address

        let registerVersionCalldata = await registryUtil.registerVersion(
          validAppName, validVersionName, storage.address, versionOneDesc, executionContext
        ).should.be.fulfilled
        registerVersionCalldata.should.not.eq('0x')

        let events = await storage.exec(
          versionConsole.address, registryExecId, registerVersionCalldata,
          { from: exec }
        ).then((tx) => {
          return tx.logs
        })
        events.should.not.eq(null)
        events.length.should.be.eq(1)
        events[0].event.should.be.eq('ApplicationExecution')
      })

      context('such as the app name', async () => {
        let invalidAppName = ''

        beforeEach(async () => {
          invalidCalldata = await registryUtil.finalizeVersion(
            invalidAppName, validVersionName, validInitAddr, validInitSig, validInitDesc, executionContext
          ).should.be.fulfilled
          invalidCalldata.should.not.eq('0x')

          let events = await storage.exec(
            versionConsole.address, registryExecId, invalidCalldata,
            { from: exec }
          ).then((tx) => {
            return tx.logs
          })
          events.should.not.eq(null)
          events.length.should.be.eq(1)

          invalidFinalizeEvent = events[0]
        })

        it('should emit an ApplicationException event', async () => {
          invalidFinalizeEvent.event.should.be.eq('ApplicationException')
          hexStrEquals(invalidFinalizeEvent.args['message'], 'DefaultException').should.be.eq(true)
        })

        it('should still have default getAppLatestInfo', async () => {
          let appInfo = await initRegistry.getAppLatestInfo(
            storage.address, registryExecId, providerID, appName
          ).should.be.fulfilled
          appInfo.should.not.eq(null)
          appInfo.length.should.be.eq(4)

          web3.toDecimal(appInfo[0]).should.be.eq(0)
          web3.toDecimal(appInfo[1]).should.be.eq(0)
          web3.toDecimal(appInfo[2]).should.be.eq(0)
          appInfo[3].length.should.be.eq(0)
        })
      })

      context('such as the version name', async () => {
        let invalidVersionName = ''

        beforeEach(async () => {
          invalidCalldata = await registryUtil.finalizeVersion(
            validAppName, invalidVersionName, validInitAddr, validInitSig, validInitDesc, executionContext
          ).should.be.fulfilled
          invalidCalldata.should.not.eq('0x')

          let events = await storage.exec(
            versionConsole.address, registryExecId, invalidCalldata,
            { from: exec }
          ).then((tx) => {
            return tx.logs
          })
          events.should.not.eq(null)
          events.length.should.be.eq(1)

          invalidFinalizeEvent = events[0]
        })

        it('should emit an ApplicationException event', async () => {
          invalidFinalizeEvent.event.should.be.eq('ApplicationException')
          hexStrEquals(invalidFinalizeEvent.args['message'], 'DefaultException').should.be.eq(true)
        })

        it('should still have default getAppLatestInfo', async () => {
          let appInfo = await initRegistry.getAppLatestInfo(
            storage.address, registryExecId, providerID, appName
          ).should.be.fulfilled
          appInfo.should.not.eq(null)
          appInfo.length.should.be.eq(4)

          web3.toDecimal(appInfo[0]).should.be.eq(0)
          web3.toDecimal(appInfo[1]).should.be.eq(0)
          web3.toDecimal(appInfo[2]).should.be.eq(0)
          appInfo[3].length.should.be.eq(0)
        })
      })

      context('such as the init description', async () => {
        let invalidInitDesc = ''

        beforeEach(async () => {
          invalidCalldata = await registryUtil.finalizeVersion(
            validAppName, validVersionName, validInitAddr, validInitSig, invalidInitDesc, executionContext
          ).should.be.fulfilled
          invalidCalldata.should.not.eq('0x')

          let events = await storage.exec(
            versionConsole.address, registryExecId, invalidCalldata,
            { from: exec }
          ).then((tx) => {
            return tx.logs
          })
          events.should.not.eq(null)
          events.length.should.be.eq(1)

          invalidFinalizeEvent = events[0]
        })

        it('should emit an ApplicationException event', async () => {
          invalidFinalizeEvent.event.should.be.eq('ApplicationException')
          hexStrEquals(invalidFinalizeEvent.args['message'], 'DefaultException').should.be.eq(true)
        })

        it('should still have default getAppLatestInfo', async () => {
          let appInfo = await initRegistry.getAppLatestInfo(
            storage.address, registryExecId, providerID, appName
          ).should.be.fulfilled
          appInfo.should.not.eq(null)
          appInfo.length.should.be.eq(4)

          web3.toDecimal(appInfo[0]).should.be.eq(0)
          web3.toDecimal(appInfo[1]).should.be.eq(0)
          web3.toDecimal(appInfo[2]).should.be.eq(0)
          appInfo[3].length.should.be.eq(0)
        })
      })

      context('such as the init address', async () => {
        let invalidInitAddr = web3.toHex(0)

        beforeEach(async () => {
          invalidCalldata = await registryUtil.finalizeVersion(
            validAppName, validVersionName, invalidInitAddr, validInitSig, validInitDesc, executionContext
          ).should.be.fulfilled
          invalidCalldata.should.not.eq('0x')

          let events = await storage.exec(
            versionConsole.address, registryExecId, invalidCalldata,
            { from: exec }
          ).then((tx) => {
            return tx.logs
          })
          events.should.not.eq(null)
          events.length.should.be.eq(1)

          invalidFinalizeEvent = events[0]
        })

        it('should emit an ApplicationException event', async () => {
          invalidFinalizeEvent.event.should.be.eq('ApplicationException')
          hexStrEquals(invalidFinalizeEvent.args['message'], 'DefaultException').should.be.eq(true)
        })

        it('should still have default getAppLatestInfo', async () => {
          let appInfo = await initRegistry.getAppLatestInfo(
            storage.address, registryExecId, providerID, appName
          ).should.be.fulfilled
          appInfo.should.not.eq(null)
          appInfo.length.should.be.eq(4)

          web3.toDecimal(appInfo[0]).should.be.eq(0)
          web3.toDecimal(appInfo[1]).should.be.eq(0)
          web3.toDecimal(appInfo[2]).should.be.eq(0)
          appInfo[3].length.should.be.eq(0)
        })
      })

      context('such as the init selector', async () => {
        let invalidInitSig = '0x00000000'

        beforeEach(async () => {
          invalidCalldata = await registryUtil.finalizeVersion(
            validAppName, validVersionName, validInitAddr, invalidInitSig, validInitDesc, executionContext
          ).should.be.fulfilled
          invalidCalldata.should.not.eq('0x')

          let events = await storage.exec(
            versionConsole.address, registryExecId, invalidCalldata,
            { from: exec }
          ).then((tx) => {
            return tx.logs
          })
          events.should.not.eq(null)
          events.length.should.be.eq(1)

          invalidFinalizeEvent = events[0]
        })

        it('should emit an ApplicationException event', async () => {
          invalidFinalizeEvent.event.should.be.eq('ApplicationException')
          hexStrEquals(invalidFinalizeEvent.args['message'], 'DefaultException').should.be.eq(true)
        })

        it('should still have default getAppLatestInfo', async () => {
          let appInfo = await initRegistry.getAppLatestInfo(
            storage.address, registryExecId, providerID, appName
          ).should.be.fulfilled
          appInfo.should.not.eq(null)
          appInfo.length.should.be.eq(4)

          web3.toDecimal(appInfo[0]).should.be.eq(0)
          web3.toDecimal(appInfo[1]).should.be.eq(0)
          web3.toDecimal(appInfo[2]).should.be.eq(0)
          appInfo[3].length.should.be.eq(0)
        })
      })
    })

  })

  // contract('ImplementationConsole', async () => {
  //
  // })
})
