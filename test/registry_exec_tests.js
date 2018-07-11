let AbstractStorage = artifacts.require('./AbstractStorage')
let ScriptExec = artifacts.require('./RegistryExec')
// Registry
let RegistryUtil = artifacts.require('./RegistryUtil')
let RegistryIdx = artifacts.require('./RegistryIdx')
let Provider = artifacts.require('./Provider')
// Mock
let AppInitMock = artifacts.require('./mock/AppInitMock')
let PayableApp = artifacts.require('./mock/PayableApp')
let StdApp = artifacts.require('./mock/StdApp')
let EmitsApp = artifacts.require('./mock/EmitsApp')
let MixedApp = artifacts.require('./mock/MixedApp')
let InvalidApp = artifacts.require('./mock/InvalidApp')
let RevertApp = artifacts.require('./mock/RevertApp')
// Util
let TestUtils = artifacts.require('./util/TestUtils')
let AppInitUtil = artifacts.require('./util/AppInitUtil')
let AppMockUtil = artifacts.require('./util/AppMockUtil')

function getTime() {
  let block = web3.eth.getBlock('latest')
  return block.timestamp;
}

function zeroAddress() {
  return web3.toHex(0)
}

function hexStrEquals(hex, expected) {
  return web3.toAscii(hex).substring(0, expected.length) == expected;
}

contract('RegistryExec', function (accounts) {

  let storage
  let scriptExec

  let execAdmin = accounts[0]
  let updater = accounts[1]
  let provider = accounts[2]
  let registryExecID
  let testUtils

  let sender = accounts[3]

  // PayableApp
  let payees = [accounts[5], accounts[6]]
  let payouts = [444, 222]
  // StdApp
  let storageLocations = [web3.toHex('AA'), web3.toHex('BB')]
  let storageValues = ['CC', 'DD']
  // EmitsApp
  let registryHash = web3.sha3('RegistryInstanceCreated(address,bytes32,address,address)')
  let emitTopics = ['aaaaa', 'bbbbbb', 'ccccc', 'ddddd']

  let appInit
  let appInitUtil

  let initCalldata

  let appMockUtil
  let payableApp
  let stdApp
  let emitApp
  let mixApp
  let invalidApp
  let revertApp

  let stdAppName = 'stdapp'
  let stdAppName2 = 'stdapp2'
  let version1 = '0.0.1'
  let appSelectors
  let allowedAddrs

  let stdAppCalldata

  let regExecID
  let regUtil
  let regProvider
  let regIdx

  before(async () => {
    storage = await AbstractStorage.new().should.be.fulfilled

    regUtil = await RegistryUtil.new().should.be.fulfilled
    regProvider = await Provider.new().should.be.fulfilled
    regIdx = await RegistryIdx.new().should.be.fulfilled

    appInit = await AppInitMock.new().should.be.fulfilled
    appInitUtil = await AppInitUtil.new().should.be.fulfilled
    testUtils = await TestUtils.new().should.be.fulfilled

    appMockUtil = await AppMockUtil.new().should.be.fulfilled
    payableApp = await PayableApp.new().should.be.fulfilled
    stdApp = await StdApp.new().should.be.fulfilled
    emitApp = await EmitsApp.new().should.be.fulfilled
    mixApp = await MixedApp.new().should.be.fulfilled
    invalidApp = await InvalidApp.new().should.be.fulfilled
    revertApp = await RevertApp.new().should.be.fulfilled

    initCalldata = await appInitUtil.init.call().should.be.fulfilled
    initCalldata.should.not.eq('0x0')

    appSelectors = await appMockUtil.getSelectors.call().should.be.fulfilled
    appSelectors.length.should.be.eq(25)

    allowedAddrs = [
      // pay
      payableApp.address, payableApp.address, payableApp.address,
      // std
      stdApp.address, stdApp.address, stdApp.address,
      // emit
      emitApp.address, emitApp.address, emitApp.address,
      emitApp.address, emitApp.address, emitApp.address,
      // mix
      mixApp.address, mixApp.address, mixApp.address, mixApp.address,
      mixApp.address, mixApp.address, mixApp.address, mixApp.address,
      // inv
      invalidApp.address, invalidApp.address,
      // rev
      revertApp.address, revertApp.address, revertApp.address
    ]
    allowedAddrs.length.should.be.eq(appSelectors.length)

    stdAppCalldata = []
    let cd = await appMockUtil.std1.call(storageLocations[0], storageValues[0])
    cd.should.not.eq('0x0')
    stdAppCalldata.push(cd)
  })

  beforeEach(async () => {
    scriptExec = await ScriptExec.new(
      { from: execAdmin }
    ).should.be.fulfilled

    scriptExec.configure(
      execAdmin, storage.address, provider,
      { from: execAdmin }
    ).should.be.fulfilled
  })

  describe('#constructor', async () => {

    let testExec

    context('when no exec admin is passed-in', async () => {

      beforeEach(async () => {
        testExec = await ScriptExec.new(
          { from: execAdmin }
        ).should.be.fulfilled

        testExec.configure(
          execAdmin, storage.address, provider,
          { from: execAdmin }
        ).should.be.fulfilled
      })

      it('should set the exec admin address as the sender', async () => {
        let adminInfo = await testExec.exec_admin.call()
        adminInfo.should.be.eq(execAdmin)
      })

      it('should correctly set other initial data', async () => {
        let storageInfo = await testExec.app_storage.call()
        storageInfo.should.be.eq(storage.address)
        let providerInfo = await testExec.provider.call()
        providerInfo.should.be.eq(provider)
      })
    })

    context('when an exec admin is passed-in', async () => {

      beforeEach(async () => {
        testExec = await ScriptExec.new(
          { from: execAdmin }
        ).should.be.fulfilled

        testExec.configure(
          execAdmin, storage.address, provider,
          { from: execAdmin }
        ).should.be.fulfilled
      })

      it('should set the exec admin address as the passed-in address', async () => {
        let adminInfo = await testExec.exec_admin.call()
        adminInfo.should.be.eq(execAdmin)
      })

      it('should correctly set other initial data', async () => {
        let storageInfo = await testExec.app_storage.call()
        storageInfo.should.be.eq(storage.address)
        let providerInfo = await testExec.provider.call()
        providerInfo.should.be.eq(provider)
      })
    })
  })

  describe('#createRegistryInstance', async () => {

    context('invalid input', async () => {

      let invalidAddr = web3.toHex(0)

      context('invalid index address', async () => {

        it('should throw', async () => {
          await scriptExec.createRegistryInstance(
            invalidAddr, regProvider.address
          ).should.not.be.fulfilled
        })
      })

      context('invalid impl address', async () => {

        it('should throw', async () => {
          await scriptExec.createRegistryInstance(
            regIdx.address, invalidAddr
          ).should.not.be.fulfilled
        })
      })
    })

    context('when there is not already a set registry exec id', async () => {

      let createEvent
      let newRegExecId

      beforeEach(async () => {
        let events = await scriptExec.createRegistryInstance(
          regIdx.address, regProvider.address, { from: execAdmin }
        ).should.be.fulfilled.then((tx) => {
          return tx.logs
        })
        events.should.not.eq(null)
        events.length.should.be.eq(1)
        createEvent = events[0]
        newRegExecId = createEvent.args['execution_id']
        web3.toDecimal(newRegExecId).should.not.eq(0)
      })

      it('should set the contract registry exec id to the emitted exec id', async () => {
        let execInfo = await scriptExec.registry_exec_id.call()
        execInfo.should.be.eq(newRegExecId)
      })

      it('should emit a RegistryInstanceCreated event', async () => {
        createEvent.event.should.be.eq('RegistryInstanceCreated')
      })

      it('store the correct addresses as registry instance info', async () => {
        let addrInfo = await scriptExec.registry_instance_info.call(newRegExecId)
        addrInfo.length.should.be.eq(2)
        addrInfo[0].should.be.eq(regIdx.address)
        addrInfo[1].should.be.eq(regProvider.address)
      })
    })

    context('when there is already a set registry exec id', async () => {

      let createEvent
      let newRegExecId

      beforeEach(async () => {
        await scriptExec.setRegistryExecID(web3.sha3('A'), { from: execAdmin }).should.be.fulfilled

        let events = await scriptExec.createRegistryInstance(
          regIdx.address, regProvider.address, { from: execAdmin }
        ).should.be.fulfilled.then((tx) => {
          return tx.logs
        })
        events.should.not.eq(null)
        events.length.should.be.eq(1)
        createEvent = events[0]
        newRegExecId = createEvent.args['execution_id']
        web3.toDecimal(newRegExecId).should.not.eq(0)
      })

      it('should match the original exec id set', async () => {
        let execInfo = await scriptExec.registry_exec_id.call()
        execInfo.should.be.eq(web3.sha3('A'))
      })

      it('should emit a RegistryInstanceCreated event', async () => {
        createEvent.event.should.be.eq('RegistryInstanceCreated')
      })

      it('store the correct addresses as registry instance info', async () => {
        let addrInfo = await scriptExec.registry_instance_info.call(newRegExecId)
        addrInfo.length.should.be.eq(2)
        addrInfo[0].should.be.eq(regIdx.address)
        addrInfo[1].should.be.eq(regProvider.address)
      })
    })
  })

  describe('#registerApp', async () => {

    let registryExecID

    beforeEach(async () => {
      let events = await scriptExec.createRegistryInstance(
        regIdx.address, regProvider.address, { from: execAdmin }
      ).should.be.fulfilled.then((tx) => {
        return tx.logs
      })
      events.should.not.eq(null)
      events.length.should.be.eq(1)
      events[0].event.should.be.eq('RegistryInstanceCreated')
      registryExecID = events[0].args['execution_id']
    })

    context('invalid input', async () => {

      describe('invalid index address', async () => {

        it('should throw', async () => {
          await scriptExec.registerApp(
            stdAppName, zeroAddress(), appSelectors, allowedAddrs
          ).should.not.be.fulfilled
        })
      })

      describe('invalid app name', async () => {

        let invalidName = ''

        it('should throw', async () => {
          await scriptExec.registerApp(
            invalidName, regIdx.address, appSelectors, allowedAddrs
          ).should.not.be.fulfilled
        })
      })

      describe('invalid input length', async () => {

        let invalidSelectors = ['0xdeadbeef']

        it('should throw', async () => {
          await scriptExec.registerApp(
            stdAppName, regIdx.address, invalidSelectors, allowedAddrs
          ).should.not.be.fulfilled
        })
      })

      describe('unset registry exec id', async () => {

        beforeEach(async () => {
          await scriptExec.setRegistryExecID(web3.toHex(0))
        })

        it('should throw', async () => {
          await scriptExec.registerApp(
            stdAppName, regIdx.address, appSelectors, allowedAddrs
          ).should.not.be.fulfilled
        })
      })
    })

    context('app already exists', async () => {

      beforeEach(async () => {
        await scriptExec.registerApp(
          stdAppName, regIdx.address, appSelectors, allowedAddrs
        ).should.be.fulfilled
      })

      it('should throw', async () => {
        await scriptExec.registerApp(
          stdAppName, regIdx.address, appSelectors, allowedAddrs
        ).should.not.be.fulfilled
      })
    })

    context('app does not already exist', async () => {

      beforeEach(async () => {
        await scriptExec.registerApp(
          stdAppName, regIdx.address, appSelectors, allowedAddrs
        ).should.be.fulfilled
      })

      it('should return the app\'s own name as its only version', async () => {
        let versionInfo = await regIdx.getVersions.call(
          storage.address, registryExecID, execAdmin, stdAppName
        ).should.be.fulfilled
        versionInfo.length.should.be.eq(1)
        hexStrEquals(versionInfo[0], stdAppName).should.be.eq(true)
      })
    })
  })

  describe('#registerAppVersion', async () => {

    let registryExecID

    beforeEach(async () => {
      let events = await scriptExec.createRegistryInstance(
        regIdx.address, regProvider.address, { from: execAdmin }
      ).should.be.fulfilled.then((tx) => {
        return tx.logs
      })
      events.should.not.eq(null)
      events.length.should.be.eq(1)
      events[0].event.should.be.eq('RegistryInstanceCreated')
      registryExecID = events[0].args['execution_id']
    })

    context('invalid input', async () => {

      beforeEach(async () => {
        await scriptExec.registerApp(
          stdAppName, regIdx.address, appSelectors, allowedAddrs
        ).should.be.fulfilled
      })

      describe('invalid index address', async () => {

        it('should throw', async () => {
          await scriptExec.registerAppVersion(
            stdAppName, version1, zeroAddress(), appSelectors, allowedAddrs
          ).should.not.be.fulfilled
        })
      })

      describe('invalid version name', async () => {

        let invalidName = ''

        it('should throw', async () => {
          await scriptExec.registerAppVersion(
            stdAppName, invalidName, regIdx.address, appSelectors, allowedAddrs
          ).should.not.be.fulfilled
        })
      })

      describe('invalid input length', async () => {

        let invalidSelectors = ['0xdeadbeef']

        it('should throw', async () => {
          await scriptExec.registerAppVersion(
            stdAppName, version1, regIdx.address, invalidSelectors, allowedAddrs
          ).should.not.be.fulfilled
        })
      })

      describe('unset registry exec id', async () => {

        beforeEach(async () => {
          await scriptExec.setRegistryExecID(web3.toHex(0))
        })

        it('should throw', async () => {
          await scriptExec.registerAppVersion(
            stdAppName, version1, regIdx.address, appSelectors, allowedAddrs
          ).should.not.be.fulfilled
        })
      })
    })

    context('app does not already exist', async () => {

      it('should throw', async () => {
        await scriptExec.registerAppVersion(
          stdAppName, version1, regIdx.address, appSelectors, allowedAddrs
        ).should.not.be.fulfilled
      })
    })

    context('app exists, version already exists', async () => {

      beforeEach(async () => {
        await scriptExec.registerApp(
          stdAppName, regIdx.address, appSelectors, allowedAddrs
        ).should.be.fulfilled
        await scriptExec.registerAppVersion(
          stdAppName, version1, regIdx.address, appSelectors, allowedAddrs
        ).should.be.fulfilled
      })

      it('should throw', async () => {
        await scriptExec.registerAppVersion(
          stdAppName, version1, regIdx.address, appSelectors, allowedAddrs
        ).should.not.be.fulfilled
      })
    })

    context('app exists, version does not exist', async () => {

      beforeEach(async () => {
        await scriptExec.registerApp(
          stdAppName, regIdx.address, appSelectors, allowedAddrs
        ).should.be.fulfilled
        await scriptExec.registerAppVersion(
          stdAppName, version1, regIdx.address, appSelectors, allowedAddrs
        ).should.be.fulfilled
      })

      it('should return an app version list length of 2', async () => {
        let versionInfo = await regIdx.getVersions.call(
          storage.address, registryExecID, execAdmin, stdAppName
        ).should.be.fulfilled
        versionInfo.length.should.be.eq(2)
        hexStrEquals(versionInfo[0], stdAppName).should.be.eq(true)
        hexStrEquals(versionInfo[1], version1).should.be.eq(true)
      })
    })
  })

  describe('#updateExec', async () => {

    let registryExecID

    beforeEach(async () => {
      let events = await scriptExec.createRegistryInstance(
        regIdx.address, regProvider.address, { from: execAdmin }
      ).should.be.fulfilled.then((tx) => {
        return tx.logs
      })
      events.should.not.eq(null)
      events.length.should.be.eq(1)
      events[0].event.should.be.eq('RegistryInstanceCreated')
      registryExecID = events[0].args['execution_id']
    })

    describe('invalid input', async () => {

      context('sender is not deployer', async () => {

        it('should throw', async () => {
          await scriptExec.updateAppExec(
            registryExecID, execAdmin, 
            { from: update }
          ).should.not.be.fulfilled
        })

      })

      context('execID is zero', async () => {
        it('should throw', async () => {
          await scriptExec.updateAppExec(
            '0x0000000000000000000000000000000000000000000000000000000000000000', execAdmin, 
            { from: execAdmin }
          ).should.not.be.fulfilled
        })

      })

      context('replacement is address zero', async () => {

        it('should throw', async () => {
          await scriptExec.updateAppExec(
            registryExecID,  '0x0000000000000000000000000000000000000000000000000000', 
            { from: execAdmin }
          ).should.not.be.fulfilled
        })

      })

      context('replacement is this ScriptExec', async () => {
        it('should throw', async () => {
          await scriptExec.updateAppExec(
            registryExecID, scriptExec.address, 
            { from: execAdmin }
          ).should.not.be.fulfilled
        })

      })

    })

  })

  describe('valid update', async () => {

  })

})
