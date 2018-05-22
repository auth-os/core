let AbstractStorage = artifacts.require('./AbstractStorage')
let ScriptExec = artifacts.require('./ScriptExec')
// Script Registry
let InitRegistry = artifacts.require('./InitRegistry')
let AppConsole = artifacts.require('./AppConsole')
let VersionConsole = artifacts.require('./VersionConsole')
let ImplConsole = artifacts.require('./ImplementationConsole')
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

function sendBalanceTo(_from, _to) {
  let bal = web3.eth.getBalance(_from).toNumber()
  web3.eth.sendTransaction({ from: _from, to: _to, value: bal, gasPrice: 0 })
}

contract('ScriptExec', function (accounts) {

  let storage
  let scriptExec

  let execAdmin = accounts[0]
  let updater = accounts[1]
  let provider = accounts[2]
  let registryExecID
  let providerID
  let testUtils

  // PayableApp
  let payees = [accounts[3], accounts[4]]
  let payouts = [111, 222]
  // StdApp
  let storageLocations = [web3.toHex('AA'), web3.toHex('BB')]
  let storageValues = ['CC', 'DD']
  // EmitsApp
  let initHash = web3.sha3('ApplicationInitialized(bytes32,address,address,address)')
  let finalHash = web3.sha3('ApplicationFinalization(bytes32,address)')
  let execHash = web3.sha3('ApplicationExecution(bytes32,address)')
  let payHash = web3.sha3('DeliveredPayment(bytes32,address,uint256)')
  let emitTopics = ['aaaaa', 'bbbbbb', 'ccccc', 'ddddd']
  let emitData1 = 'tiny'
  let emitData2 = 'much much much much much much much much larger'
  // RevertApp
  let revertMessage = 'appreverted'
  let throwMessage = 'this application threw'

  let otherAddr = accounts[accounts.length - 1]

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

  let allowedAddrs

  let stdAppCalldata

  before(async () => {
    storage = await AbstractStorage.new().should.be.fulfilled

    appInit = await AppInitMock.new().should.be.fulfilled
    appInitUtil = await AppInitUtil.new().should.be.fulfilled
    testUtils = await TestUtils.new().should.be.fulfilled

    providerID = testUtils.getAppProviderHash.call(provider)
    providerID.should.not.eq('0x')

    appMockUtil = await AppMockUtil.new().should.be.fulfilled
    payableApp = await PayableApp.new().should.be.fulfilled
    stdApp = await StdApp.new().should.be.fulfilled
    emitApp = await EmitsApp.new().should.be.fulfilled
    mixApp = await MixedApp.new().should.be.fulfilled
    invalidApp = await InvalidApp.new().should.be.fulfilled
    revertApp = await RevertApp.new().should.be.fulfilled

    initCalldata = await appInitUtil.init.call().should.be.fulfilled
    initCalldata.should.not.eq('0x0')

    allowedAddrs = [
      stdApp.address,
      payableApp.address,
      emitApp.address,
      mixApp.address,
      invalidApp.address,
      revertApp.address
    ]

    stdAppCalldata = []
    let cd = await appMockUtil.std1.call(storageLocations[0], storageValues[0])
    cd.should.not.eq('0x0')
    stdAppCalldata.push(cd)
  })

  beforeEach(async () => {
    scriptExec = await ScriptExec.new(
      execAdmin, updater, storage.address, providerID,
      { from: execAdmin }
    ).should.be.fulfilled
  })

  describe('#constructor', async () => {

    let testExec

    context('when no exec admin is passed-in', async () => {

      beforeEach(async () => {
        testExec = await ScriptExec.new(
          zeroAddress(), updater, storage.address, providerID,
          { from: execAdmin }
        ).should.be.fulfilled
      })

      it('should set the exec admin address as the sender', async () => {
        let adminInfo = await testExec.exec_admin.call()
        adminInfo.should.be.eq(execAdmin)
      })

      it('should correctly set other initial data', async () => {
        let updaterInfo = await testExec.default_updater.call()
        updaterInfo.should.be.eq(updater)
        let storageInfo = await testExec.default_storage.call()
        storageInfo.should.be.eq(storage.address)
        let providerInfo = await testExec.default_provider.call()
        providerInfo.should.be.eq(providerID)
      })
    })

    context('when an exec admin is passed-in', async () => {

      beforeEach(async () => {
        testExec = await ScriptExec.new(
          execAdmin, updater, storage.address, providerID,
          { from: execAdmin }
        ).should.be.fulfilled
      })

      it('should set the exec admin address as the passed-in address', async () => {
        let adminInfo = await testExec.exec_admin.call()
        adminInfo.should.be.eq(execAdmin)
      })

      it('should correctly set other initial data', async () => {
        let updaterInfo = await testExec.default_updater.call()
        updaterInfo.should.be.eq(updater)
        let storageInfo = await testExec.default_storage.call()
        storageInfo.should.be.eq(storage.address)
        let providerInfo = await testExec.default_provider.call()
        providerInfo.should.be.eq(providerID)
      })
    })
  })

  describe('#exec - payable', async () => {

    let executionID
    let target

    beforeEach(async () => {
      let events = await storage.initAndFinalize(
        updater, true, appInit.address, initCalldata, allowedAddrs,
        { from: execAdmin }
      ).should.be.fulfilled.then((tx) => {
        return tx.logs
      })
      events.should.not.eq(null)
      events.length.should.be.eq(2)
      events[0].event.should.be.eq('ApplicationInitialized')
      events[1].event.should.be.eq('ApplicationFinalization')
      executionID = events[0].args['execution_id']
      web3.toDecimal(executionID).should.not.eq(0)

      await storage.changeScriptExec(
        executionID, scriptExec.address, { from: execAdmin }
      ).should.be.fulfilled
    })

    describe('basic app info', async () => {

      it('should correctly set the script exec to the deployed contract', async () => {
        let appInfo = await storage.app_info.call(executionID)
        appInfo[0].should.be.eq(false)
        appInfo[1].should.be.eq(true)
        appInfo[2].should.be.eq(true)
        appInfo[3].should.be.eq(updater)
        appInfo[4].should.be.eq(scriptExec.address)
        appInfo[5].should.be.eq(appInit.address)
      })
    })

    describe('invalid inputs or invalid state', async () => {

      beforeEach(async () => {
        target = stdApp.address
      })

      context('calldata is too short', async () => {

        let invalidCalldata = '0xabcd'

        it('should throw', async () => {
          await scriptExec.exec(
            target,
          )
          await storage.exec(
            target, executionID, invalidCalldata,
            { from: execAdmin }
          ).should.not.be.fulfilled
        })
      })

      context('target address is 0', async () => {

        let invalidAddr = zeroAddress()

        it('should throw', async () => {
          await storage.exec(
            invalidAddr, executionID, stdAppCalldata[0],
            { from: execAdmin }
          ).should.not.be.fulfilled
        })
      })

      context('exec id is 0', async () => {

        let invalidExecID = web3.toHex(0)

        it('should throw', async () => {
          await storage.exec(
            allowedAddrs[0], invalidExecID, stdAppCalldata[0],
            { from: exec }
          ).should.not.be.fulfilled
        })
      })

      context('sender is not script exec for the passed in execution id', async () => {

        let invalidExec = otherAddr

        it('should throw', async () => {
          await storage.exec(
            stdApp.address, executionID, stdAppCalldata[0],
            { from: invalidExec }
          ).should.not.be.fulfilled
        })
      })

      context('script target not in exec id allowed list', async () => {

        let invalidTarget

        beforeEach(async () => {
          invalidTarget = await StdApp.new().should.be.fulfilled
        })

        it('should throw', async () => {
          await storage.exec(
            invalidTarget.address, executionID, stdAppCalldata[0],
            { from: exec }
          ).should.not.be.fulfilled
        })
      })

      context('app is paused', async () => {

        beforeEach(async () => {
          await storage.pauseAppInstance(executionID, { from: updater }).should.be.fulfilled
          let appInfo = await storage.app_info.call(executionID)
          appInfo[0].should.be.eq(true)
        })

        it('should throw', async () => {
          await storage.exec(
            stdApp.address, executionID, stdAppCalldata[0],
            { from: exec }
          ).should.not.be.fulfilled
        })
      })
    })

    describe('RevertApp (app reverts)', async () => {

      let revertEvents
      let revertReturn

      describe('function did not exist', async () => {

        let invalidCalldata

        beforeEach(async () => {
          invalidCalldata = await appMockUtil.rev0.call()
          invalidCalldata.should.not.eq('0x0')

          revertReturn = await storage.exec.call(
            revertApp.address, executionID, invalidCalldata,
            { from: exec }
          ).should.be.fulfilled

          revertEvents = await storage.exec(
            revertApp.address, executionID, invalidCalldata,
            { from: exec }
          ).should.be.fulfilled.then((tx) => {
            return tx.logs
          })
        })

        describe('returned data', async () => {

          it('should return a tuple with 3 fields', async () => {
            revertReturn.length.should.be.eq(3)
          })

          it('should return blank data', async () => {
            revertReturn[0].toNumber().should.be.eq(0)
            revertReturn[1].toNumber().should.be.eq(0)
            revertReturn[2].toNumber().should.be.eq(0)
          })
        })

        describe('revert events', async () => {

          it('should emit a single ApplicationException event', async () => {
            revertEvents.length.should.be.eq(1)
            revertEvents[0].event.should.be.eq('ApplicationException')
          })

          it('should match the used execution id', async () => {
            let emittedExecId = revertEvents[0].args['execution_id']
            emittedExecId.should.be.eq(executionID)
          })

          it('should match the targeted app address', async () => {
            let emittedAddr = revertEvents[0].args['application_address']
            emittedAddr.should.be.eq(revertApp.address)
          })

          it('should emit a message matching \'DefaultException\'', async () => {
            let emittedMessage = revertEvents[0].args['message']
            hexStrEquals(emittedMessage, 'DefaultException').should.be.eq(true,
              "emitted:" + web3.toAscii(emittedMessage)
            )
          })
        })
      })

      describe('reverts with no message', async () => {

        beforeEach(async () => {
          let revertCalldata = await appMockUtil.rev1.call()
          revertCalldata.should.not.eq('0x0')

          revertReturn = await storage.exec.call(
            revertApp.address, executionID, revertCalldata,
            { from: exec }
          ).should.be.fulfilled

          revertEvents = await storage.exec(
            revertApp.address, executionID, revertCalldata,
            { from: exec }
          ).should.be.fulfilled.then((tx) => {
            return tx.logs
          })
        })

        describe('returned data', async () => {

          it('should return a tuple with 3 fields', async () => {
            revertReturn.length.should.be.eq(3)
          })

          it('should return blank data', async () => {
            revertReturn[0].toNumber().should.be.eq(0)
            revertReturn[1].toNumber().should.be.eq(0)
            revertReturn[2].toNumber().should.be.eq(0)
          })
        })

        describe('revert events', async () => {

          it('should emit a single ApplicationException event', async () => {
            revertEvents.length.should.be.eq(1)
            revertEvents[0].event.should.be.eq('ApplicationException')
          })

          it('should match the used execution id', async () => {
            let emittedExecId = revertEvents[0].args['execution_id']
            emittedExecId.should.be.eq(executionID)
          })

          it('should match the targeted app address', async () => {
            let emittedAddr = revertEvents[0].args['application_address']
            emittedAddr.should.be.eq(revertApp.address)
          })

          it('should emit a message matching \'DefaultException\'', async () => {
            let emittedMessage = revertEvents[0].args['message']
            hexStrEquals(emittedMessage, 'DefaultException').should.be.eq(true,
              "emitted:" + web3.toAscii(emittedMessage)
            )
          })
        })
      })

      describe('reverts with message', async () => {

        beforeEach(async () => {
          let revertCalldata = await appMockUtil.rev2.call(revertMessage)
          revertCalldata.should.not.eq('0x0')

          revertReturn = await storage.exec.call(
            revertApp.address, executionID, revertCalldata,
            { from: exec }
          ).should.be.fulfilled

          revertEvents = await storage.exec(
            revertApp.address, executionID, revertCalldata,
            { from: exec }
          ).should.be.fulfilled.then((tx) => {
            return tx.logs
          })
        })

        describe('returned data', async () => {

          it('should return a tuple with 3 fields', async () => {
            revertReturn.length.should.be.eq(3)
          })

          it('should return blank data', async () => {
            revertReturn[0].toNumber().should.be.eq(0)
            revertReturn[1].toNumber().should.be.eq(0)
            revertReturn[2].toNumber().should.be.eq(0)
          })
        })

        describe('revert events', async () => {

          it('should emit a single ApplicationException event', async () => {
            revertEvents.length.should.be.eq(1)
            revertEvents[0].event.should.be.eq('ApplicationException')
          })

          it('should match the used execution id', async () => {
            let emittedExecId = revertEvents[0].args['execution_id']
            emittedExecId.should.be.eq(executionID)
          })

          it('should match the targeted app address', async () => {
            let emittedAddr = revertEvents[0].args['application_address']
            emittedAddr.should.be.eq(revertApp.address)
          })

          it('should emit the correct message', async () => {
            let emittedMessage = revertEvents[0].args['message']
            hexStrEquals(emittedMessage, revertMessage).should.be.eq(true,
              "emitted:" + web3.toAscii(emittedMessage)
            )
          })
        })
      })

      describe('signals to throw with a message', async () => {

        let revertCalldata

        beforeEach(async () => {
          revertCalldata = await appMockUtil.throws1.call(throwMessage)
          revertCalldata.should.not.eq('0x0')
        })

        it('should throw', async () => {
          await storage.exec(
            revertApp.address, executionID, revertCalldata,
            { from: exec }
          ).should.not.be.fulfilled
        })
      })

      describe('signals to throw incorrectly', async () => {

        let revertCalldata

        beforeEach(async () => {
          revertCalldata = await appMockUtil.throws2.call(throwMessage)
          revertCalldata.should.not.eq('0x0')
        })

        it('should throw', async () => {
          await storage.exec(
            revertApp.address, executionID, revertCalldata,
            { from: exec }
          ).should.not.be.fulfilled
        })
      })
    })

    describe('InvalidApp (app returns malformed data)', async () => {

      let target
      let calldata

      beforeEach(async () => {
        target = invalidApp.address
      })

      describe('app attempts to pay storage contract', async () => {

        beforeEach(async () => {
          calldata = await appMockUtil.inv1.call()
          calldata.should.not.eq('0x0')
        })

        it('should throw', async () => {
          await storage.exec.call(
            target, executionID, calldata,
            { from: exec, value: payouts[0] }
          ).should.not.be.fulfilled
        })
      })

      describe('app does not change state', async () => {

        beforeEach(async () => {
          calldata = await appMockUtil.inv2.call()
          calldata.should.not.eq('0x0')
        })

        it('should throw', async () => {
          await storage.exec.call(
            target, executionID, calldata,
            { from: exec }
          ).should.not.be.fulfilled
        })
      })
    })

    describe('StdApp (app stores data)', async () => {

      let target
      let calldata
      let returnData
      let execEvents

      beforeEach(async () => {
        target = stdApp.address
      })

      describe('storing to 0 slots', async () => {

        let invalidCalldata

        beforeEach(async () => {
          invalidCalldata = await appMockUtil.std0.call()
          invalidCalldata.should.not.eq('0x0')
        })

        it('should throw', async () => {
          await storage.exec(
            target, executionID, invalidCalldata,
            { from: exec }
          ).should.not.be.fulfilled
        })
      })

      describe('storing to one slot', async () => {

        beforeEach(async () => {
          calldata = await appMockUtil.std1.call(
            storageLocations[0], storageValues[0]
          )
          calldata.should.not.eq('0x0')

          returnData = await storage.exec.call(
            target, executionID, calldata,
            { from: exec }
          ).should.be.fulfilled

          execEvents = await storage.exec(
            target, executionID, calldata,
            { from: exec }
          ).should.be.fulfilled.then((tx) => {
            return tx.logs
          })
        })

        describe('returned data', async () => {

          it('should return a tuple with 3 fields', async () => {
            returnData.length.should.be.eq(3)
          })

          it('should return 0 events emitted', async () => {
            returnData[0].toNumber().should.be.eq(0)
          })

          it('should return 0 addresses paid', async () => {
            returnData[1].toNumber().should.be.eq(0)
          })

          it('should return the correct number of slots written to', async () => {
            returnData[2].toNumber().should.be.eq(1)
          })
        })

        describe('exec events', async () => {

          it('should emit a single ApplicationExecution event', async () => {
            execEvents.length.should.be.eq(1)
            execEvents[0].event.should.be.eq('ApplicationExecution')
          })

          it('should match the used execution id', async () => {
            let emittedExecId = execEvents[0].args['execution_id']
            emittedExecId.should.be.eq(executionID)
          })

          it('should match the targeted app address', async () => {
            let emittedAddr = execEvents[0].args['script_target']
            emittedAddr.should.be.eq(target)
          })
        })

        describe('storage', async () => {

          it('should have correctly stored the value at the location', async () => {
            let readValue = await storage.read.call(executionID, storageLocations[0])
            hexStrEquals(readValue, storageValues[0]).should.be.eq(true, readValue)
          })
        })
      })

      describe('storing to 2 slots', async () => {

        beforeEach(async () => {
          calldata = await appMockUtil.std2.call(
            storageLocations[0], storageValues[0], storageLocations[1], storageValues[1]
          )
          calldata.should.not.eq('0x0')

          returnData = await storage.exec.call(
            target, executionID, calldata,
            { from: exec }
          ).should.be.fulfilled

          execEvents = await storage.exec(
            target, executionID, calldata,
            { from: exec }
          ).should.be.fulfilled.then((tx) => {
            return tx.logs
          })
        })

        describe('returned data', async () => {

          it('should return a tuple with 3 fields', async () => {
            returnData.length.should.be.eq(3)
          })

          it('should return 0 events emitted', async () => {
            returnData[0].toNumber().should.be.eq(0)
          })

          it('should return 0 addresses paid', async () => {
            returnData[1].toNumber().should.be.eq(0)
          })

          it('should return the correct number of slots written to', async () => {
            returnData[2].toNumber().should.be.eq(2)
          })
        })

        describe('exec events', async () => {

          it('should emit a single ApplicationExecution event', async () => {
            execEvents.length.should.be.eq(1)
            execEvents[0].event.should.be.eq('ApplicationExecution')
          })

          it('should match the used execution id', async () => {
            let emittedExecId = execEvents[0].args['execution_id']
            emittedExecId.should.be.eq(executionID)
          })

          it('should match the targeted app address', async () => {
            let emittedAddr = execEvents[0].args['script_target']
            emittedAddr.should.be.eq(target)
          })
        })

        describe('storage', async () => {

          it('should have correctly stored the value at the first location', async () => {
            let readValue = await storage.read.call(executionID, storageLocations[0])
            hexStrEquals(readValue, storageValues[0]).should.be.eq(true)
          })

          it('should have correctly stored the value at the second location', async () => {
            let readValue = await storage.read.call(executionID, storageLocations[1])
            hexStrEquals(readValue, storageValues[1]).should.be.eq(true)
          })
        })
      })
    })

    describe('PayableApp (forwards ETH)', async () => {

      let target
      let calldata
      let returnData
      let execEvents

      beforeEach(async () => {
        target = payableApp.address
      })

      describe('pays out to 0 addresses', async () => {

        let invalidCalldata

        beforeEach(async () => {
          invalidCalldata = await appMockUtil.pay0.call()
          invalidCalldata.should.not.eq('0x0')
        })

        it('should throw', async () => {
          await storage.exec(
            target, executionID, invalidCalldata,
            { from: exec, value: payouts[0] }
          ).should.not.be.fulfilled
        })
      })

      describe('pays out to 1 address', async () => {

        let initPayeeBalance = 0

        beforeEach(async () => {
          calldata = await appMockUtil.pay1.call(payees[0], payouts[0])
          calldata.should.not.eq('0x0')

          returnData = await storage.exec.call(
            target, executionID, calldata,
            { from: exec, value: payouts[0] }
          ).should.be.fulfilled

          initPayeeBalance = web3.eth.getBalance(payees[0])

          execEvents = await storage.exec(
            target, executionID, calldata,
            { from: exec, value: payouts[0] }
          ).should.be.fulfilled.then((tx) => {
            return tx.logs
          })
        })

        describe('returned data', async () => {

          it('should return a tuple with 3 fields', async () => {
            returnData.length.should.be.eq(3)
          })

          it('should return the correct number of events emitted', async () => {
            returnData[0].toNumber().should.be.eq(0)
          })

          it('should return the correct number of addresses paid', async () => {
            returnData[1].toNumber().should.be.eq(1)
          })

          it('should return the correct number of storage slots written to', async () => {
            returnData[2].toNumber().should.be.eq(0)
          })
        })

        describe('exec events', async () => {

          let execEvent
          let payoutEvents

          beforeEach(async () => {
            payoutEvents = [execEvents[0]]
            execEvent = execEvents[1]
          })

          it('should emit 2 events total', async () => {
            execEvents.length.should.be.eq(2)
          })

          describe('the DeliveredPayment event', async () => {

            it('should match DeliveredPayment', async () => {
              payoutEvents[0].event.should.be.eq('DeliveredPayment')
            })

            it('should match the used execution id', async () => {
              let emittedExecId = payoutEvents[0].args['execution_id']
              emittedExecId.should.be.eq(executionID)
            })

            it('should match the payout destination', async () => {
              let emittedAddr = payoutEvents[0].args['destination']
              emittedAddr.should.be.eq(payees[0])
            })

            it('should match the amount sent', async () => {
              let emittedAmt = payoutEvents[0].args['amount']
              emittedAmt.toNumber().should.be.eq(payouts[0])
            })
          })

          describe('the ApplicationExecution event', async () => {

            it('should match ApplicationExecution', async () => {
              execEvent.event.should.be.eq('ApplicationExecution')
            })

            it('should match the used execution id', async () => {
              let emittedExecId = execEvent.args['execution_id']
              emittedExecId.should.be.eq(executionID)
            })

            it('should match the targeted app address', async () => {
              let emittedAddr = execEvent.args['script_target']
              emittedAddr.should.be.eq(target)
            })
          })
        })

        describe('payment', async () => {

          it('should have delivered the amount to the destination', async () => {
            let curPayeeBalance = web3.eth.getBalance(payees[0])
            curPayeeBalance.should.be.bignumber.eq(web3.toBigNumber(initPayeeBalance).plus(payouts[0]))
          })
        })
      })

      describe('pays out to 2 addresses', async () => {

        let initPayeeBalances = [0, 0]
        let totalPayout

        beforeEach(async () => {
          totalPayout = payouts[0] + payouts[1]

          calldata = await appMockUtil.pay2.call(
            payees[0], payouts[0], payees[1], payouts[1]
          )
          calldata.should.not.eq('0x0')

          returnData = await storage.exec.call(
            target, executionID, calldata,
            { from: exec, value: totalPayout }
          ).should.be.fulfilled

          initPayeeBalances = []
          let payeeBal = web3.eth.getBalance(payees[0])
          initPayeeBalances.push(payeeBal)
          payeeBal = web3.eth.getBalance(payees[1])
          initPayeeBalances.push(payeeBal)

          execEvents = await storage.exec(
            target, executionID, calldata,
            { from: exec, value: totalPayout  }
          ).should.be.fulfilled.then((tx) => {
            return tx.logs
          })
        })

        describe('returned data', async () => {

          it('should return a tuple with 3 fields', async () => {
            returnData.length.should.be.eq(3)
          })

          it('should return the correct number of events emitted', async () => {
            returnData[0].toNumber().should.be.eq(0)
          })

          it('should return the correct number of addresses paid', async () => {
            returnData[1].toNumber().should.be.eq(2)
          })

          it('should return the correct number of storage slots written to', async () => {
            returnData[2].toNumber().should.be.eq(0)
          })
        })

        describe('exec events', async () => {

          let execEvent
          let payoutEvents

          beforeEach(async () => {
            payoutEvents = [execEvents[0], execEvents[1]]
            execEvent = execEvents[2]
          })

          it('should emit 3 events total', async () => {
            execEvents.length.should.be.eq(3)
          })

          describe('the DeliveredPayment events', async () => {

            it('should match DeliveredPayment', async () => {
              payoutEvents[0].event.should.be.eq('DeliveredPayment')
              payoutEvents[1].event.should.be.eq('DeliveredPayment')
            })

            it('should match the used execution id', async () => {
              let emittedExecId = payoutEvents[0].args['execution_id']
              emittedExecId.should.be.eq(executionID)
              emittedExecId = payoutEvents[1].args['execution_id']
              emittedExecId.should.be.eq(executionID)
            })

            it('should match the payout destination', async () => {
              let emittedAddr = payoutEvents[0].args['destination']
              emittedAddr.should.be.eq(payees[0])
              emittedAddr = payoutEvents[1].args['destination']
              emittedAddr.should.be.eq(payees[1])
            })

            it('should match the amount sent', async () => {
              let emittedAmt = payoutEvents[0].args['amount']
              emittedAmt.toNumber().should.be.eq(payouts[0])
              emittedAmt = payoutEvents[1].args['amount']
              emittedAmt.toNumber().should.be.eq(payouts[1])
            })
          })

          describe('the ApplicationExecution event', async () => {

            it('should match ApplicationExecution', async () => {
              execEvent.event.should.be.eq('ApplicationExecution')
            })

            it('should match the used execution id', async () => {
              let emittedExecId = execEvent.args['execution_id']
              emittedExecId.should.be.eq(executionID)
            })

            it('should match the targeted app address', async () => {
              let emittedAddr = execEvent.args['script_target']
              emittedAddr.should.be.eq(target)
            })
          })
        })

        describe('payment', async () => {

          it('should have delivered the amount to the first destination', async () => {
            let curPayeeBalance = web3.eth.getBalance(payees[0])
            curPayeeBalance.should.be.bignumber.eq(web3.toBigNumber(initPayeeBalances[0]).plus(payouts[0]))
          })

          it('should have delivered the amount to the second destination', async () => {
            let curPayeeBalance = web3.eth.getBalance(payees[1])
            curPayeeBalance.should.be.bignumber.eq(web3.toBigNumber(initPayeeBalances[1]).plus(payouts[1]))
          })
        })
      })
    })

    describe('EmitsApp (app emits events)', async () => {

      let target
      let calldata
      let returnData
      let execEvents

      beforeEach(async () => {
        target = emitApp.address
      })

      describe('emitting 0 events', async () => {

        let invalidCalldata

        beforeEach(async () => {
          invalidCalldata = await appMockUtil.emit0.call()
          invalidCalldata.should.not.eq('0x0')
        })

        it('should throw', async () => {
          await storage.exec(
            target, executionID, invalidCalldata,
            { from: exec }
          ).should.not.be.fulfilled
        })
      })

      describe('emitting 1 event with no topics or data', async () => {

        beforeEach(async () => {
          calldata = await appMockUtil.emit1top0.call()
          calldata.should.not.eq('0x0')

          returnData = await storage.exec.call(
            target, executionID, calldata,
            { from: exec }
          ).should.be.fulfilled

          execEvents = await storage.exec(
            target, executionID, calldata,
            { from: exec }
          ).should.be.fulfilled.then((tx) => {
            return tx.logs
          })
        })

        describe('returned data', async () => {

          it('should return a tuple with 3 fields', async () => {
            returnData.length.should.be.eq(3)
          })

          it('should return the correct number of events emitted', async () => {
            returnData[0].toNumber().should.be.eq(1)
          })

          it('should return 0 addresses paid', async () => {
            returnData[1].toNumber().should.be.eq(0)
          })

          it('should return 0 storage slots written to', async () => {
            returnData[2].toNumber().should.be.eq(0)
          })
        })

        describe('exec events', async () => {

          it('should emit 2 events total', async () => {
            execEvents.length.should.be.eq(1)
            execEvents[0].event.should.be.eq('ApplicationExecution')
            execEvents[0].logIndex.should.be.eq(1)
          })

          describe('the ApplicationExecution event', async () => {

            it('should match the used execution id', async () => {
              let emittedExecId = execEvents[0].args['execution_id']
              emittedExecId.should.be.eq(executionID)
            })

            it('should match the targeted app address', async () => {
              let emittedAddr = execEvents[0].args['script_target']
              emittedAddr.should.be.eq(target)
            })
          })
        })
      })

      describe('emitting 1 event with no topics with data', async () => {

        beforeEach(async () => {
          calldata = await appMockUtil.emit1top0data.call(emitData1)
          calldata.should.not.eq('0x0')

          returnData = await storage.exec.call(
            target, executionID, calldata,
            { from: exec }
          ).should.be.fulfilled

          execEvents = await storage.exec(
            target, executionID, calldata,
            { from: exec }
          ).should.be.fulfilled.then((tx) => {
            return tx.receipt.logs
          })
        })

        describe('returned data', async () => {

          it('should return a tuple with 3 fields', async () => {
            returnData.length.should.be.eq(3)
          })

          it('should return the correct number of events emitted', async () => {
            returnData[0].toNumber().should.be.eq(1)
          })

          it('should return 0 addresses paid', async () => {
            returnData[1].toNumber().should.be.eq(0)
          })

          it('should return 0 storage slots written to', async () => {
            returnData[2].toNumber().should.be.eq(0)
          })
        })

        describe('exec events', async () => {

          let appTopics
          let appData
          let execTopics
          let execData

          beforeEach(async () => {
            appTopics = execEvents[0].topics
            appData = execEvents[0].data
            execTopics = execEvents[1].topics
            execData = execEvents[1].data
          })

          it('should emit 2 events total', async () => {
            execEvents.length.should.be.eq(2)
          })

          describe('the ApplicationExecution event', async () => {

            it('should have 3 topics', async () => {
              execTopics.length.should.be.eq(3)
            })

            it('should have the event signature as the first topic', async () => {
              let sig = execTopics[0]
              web3.toDecimal(sig).should.be.eq(web3.toDecimal(execHash))
            })

            it('should match the used execution id', async () => {
              let emittedExecId = execTopics[1]
              emittedExecId.should.be.eq(executionID)
            })

            it('should match the targeted app address', async () => {
              let emittedAddr = execTopics[2]
              web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(target))
            })

            it('should have an empty data field', async () => {
              execData.should.be.eq('0x0')
            })
          })

          describe('the other event', async () => {

            it('should have no topics', async () => {
              appTopics.length.should.be.eq(0)
            })

            it('should match the data sent', async () => {
              hexStrEquals(appData, emitData1).should.be.eq(true)
            })
          })
        })
      })

      describe('emitting 1 event with 4 topics with data', async () => {

        beforeEach(async () => {
          calldata = await appMockUtil.emit1top4data.call(
            emitTopics[0], emitTopics[1], emitTopics[2], emitTopics[3],
            emitData1
          )
          calldata.should.not.eq('0x0')

          returnData = await storage.exec.call(
            target, executionID, calldata,
            { from: exec }
          ).should.be.fulfilled

          execEvents = await storage.exec(
            target, executionID, calldata,
            { from: exec }
          ).should.be.fulfilled.then((tx) => {
            return tx.receipt.logs
          })
        })

        describe('returned data', async () => {

          it('should return a tuple with 3 fields', async () => {
            returnData.length.should.be.eq(3)
          })

          it('should return the correct number of events emitted', async () => {
            returnData[0].toNumber().should.be.eq(1)
          })

          it('should return 0 addresses paid', async () => {
            returnData[1].toNumber().should.be.eq(0)
          })

          it('should return 0 storage slots written to', async () => {
            returnData[2].toNumber().should.be.eq(0)
          })
        })

        describe('exec events', async () => {

          let appTopics
          let appData
          let execTopics
          let execData

          beforeEach(async () => {
            appTopics = execEvents[0].topics
            appData = execEvents[0].data
            execTopics = execEvents[1].topics
            execData = execEvents[1].data
          })

          it('should emit 2 events total', async () => {
            execEvents.length.should.be.eq(2)
          })

          describe('the ApplicationExecution event', async () => {

            it('should have 3 topics', async () => {
              execTopics.length.should.be.eq(3)
            })

            it('should have the event signature as the first topic', async () => {
              let sig = execTopics[0]
              web3.toDecimal(sig).should.be.eq(web3.toDecimal(execHash))
            })

            it('should match the used execution id', async () => {
              let emittedExecId = execTopics[1]
              emittedExecId.should.be.eq(executionID)
            })

            it('should match the targeted app address', async () => {
              let emittedAddr = execTopics[2]
              web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(target))
            })

            it('should have an empty data field', async () => {
              execData.should.be.eq('0x0')
            })
          })

          describe('the other event', async () => {

            it('should have 4 topics', async () => {
              appTopics.length.should.be.eq(4)
            })

            it('should match the data sent', async () => {
              hexStrEquals(appData, emitData1).should.be.eq(true)
            })

            it('should match the topics sent', async () => {
              hexStrEquals(appTopics[0], emitTopics[0]).should.be.eq(true)
              hexStrEquals(appTopics[1], emitTopics[1]).should.be.eq(true)
              hexStrEquals(appTopics[2], emitTopics[2]).should.be.eq(true)
              hexStrEquals(appTopics[3], emitTopics[3]).should.be.eq(true)
            })
          })
        })
      })

      describe('emitting 2 events, each with 1 topic and data', async () => {

        beforeEach(async () => {
          calldata = await appMockUtil.emit2top1data.call(
            emitTopics[0], emitData1, emitData2
          )
          calldata.should.not.eq('0x0')

          returnData = await storage.exec.call(
            target, executionID, calldata,
            { from: exec }
          ).should.be.fulfilled

          execEvents = await storage.exec(
            target, executionID, calldata,
            { from: exec }
          ).should.be.fulfilled.then((tx) => {
            return tx.receipt.logs
          })
        })

        describe('returned data', async () => {

          it('should return a tuple with 3 fields', async () => {
            returnData.length.should.be.eq(3)
          })

          it('should return the correct number of events emitted', async () => {
            returnData[0].toNumber().should.be.eq(2)
          })

          it('should return 0 addresses paid', async () => {
            returnData[1].toNumber().should.be.eq(0)
          })

          it('should return 0 storage slots written to', async () => {
            returnData[2].toNumber().should.be.eq(0)
          })
        })

        describe('exec events', async () => {

          let appTopics1
          let appData1
          let appTopics2
          let appData2
          let execTopics
          let execData

          beforeEach(async () => {
            appTopics1 = execEvents[0].topics
            appData1 = execEvents[0].data
            appTopics2 = execEvents[1].topics
            appData2 = execEvents[1].data
            execTopics = execEvents[2].topics
            execData = execEvents[2].data
          })

          it('should emit 3 events total', async () => {
            execEvents.length.should.be.eq(3)
          })

          describe('the ApplicationExecution event', async () => {

            it('should have 3 topics', async () => {
              execTopics.length.should.be.eq(3)
            })

            it('should have the event signature as the first topic', async () => {
              let sig = execTopics[0]
              web3.toDecimal(sig).should.be.eq(web3.toDecimal(execHash))
            })

            it('should match the used execution id', async () => {
              let emittedExecId = execTopics[1]
              emittedExecId.should.be.eq(executionID)
            })

            it('should match the targeted app address', async () => {
              let emittedAddr = execTopics[2]
              web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(target))
            })

            it('should have an empty data field', async () => {
              execData.should.be.eq('0x0')
            })
          })

          describe('the other events', async () => {

            it('should each have 1 topic', async () => {
              appTopics1.length.should.be.eq(1)
              appTopics2.length.should.be.eq(1)
            })

            it('should each match the data sent', async () => {
              hexStrEquals(appData1, emitData1).should.be.eq(true)
              hexStrEquals(appData2, emitData2).should.be.eq(true)
            })

            it('should each match the topics sent', async () => {
              hexStrEquals(appTopics1[0], emitTopics[0]).should.be.eq(true)
              let appTopics2Hex = web3.toHex(
                web3.toBigNumber(appTopics2[0]).minus(1)
              )
              hexStrEquals(appTopics2Hex, emitTopics[0]).should.be.eq(true)
            })
          })
        })
      })

      describe('emitting 2 events, each with 4 topics and no data', async () => {

        beforeEach(async () => {
          calldata = await appMockUtil.emit2top4.call(
            emitTopics[0], emitTopics[1], emitTopics[2], emitTopics[3]
          )
          calldata.should.not.eq('0x0')

          returnData = await storage.exec.call(
            target, executionID, calldata,
            { from: exec }
          ).should.be.fulfilled

          execEvents = await storage.exec(
            target, executionID, calldata,
            { from: exec }
          ).should.be.fulfilled.then((tx) => {
            return tx.receipt.logs
          })
        })

        describe('returned data', async () => {

          it('should return a tuple with 3 fields', async () => {
            returnData.length.should.be.eq(3)
          })

          it('should return the correct number of events emitted', async () => {
            returnData[0].toNumber().should.be.eq(2)
          })

          it('should return 0 addresses paid', async () => {
            returnData[1].toNumber().should.be.eq(0)
          })

          it('should return 0 storage slots written to', async () => {
            returnData[2].toNumber().should.be.eq(0)
          })
        })

        describe('exec events', async () => {

          let appTopics1
          let appData1
          let appTopics2
          let appData2
          let execTopics
          let execData

          beforeEach(async () => {
            appTopics1 = execEvents[0].topics
            appData1 = execEvents[0].data
            appTopics2 = execEvents[1].topics
            appData2 = execEvents[1].data
            execTopics = execEvents[2].topics
            execData = execEvents[2].data
          })

          it('should emit 3 events total', async () => {
            execEvents.length.should.be.eq(3)
          })

          describe('the ApplicationExecution event', async () => {

            it('should have 3 topics', async () => {
              execTopics.length.should.be.eq(3)
            })

            it('should have the event signature as the first topic', async () => {
              let sig = execTopics[0]
              web3.toDecimal(sig).should.be.eq(web3.toDecimal(execHash))
            })

            it('should match the used execution id', async () => {
              let emittedExecId = execTopics[1]
              emittedExecId.should.be.eq(executionID)
            })

            it('should match the targeted app address', async () => {
              let emittedAddr = execTopics[2]
              web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(target))
            })

            it('should have an empty data field', async () => {
              execData.should.be.eq('0x0')
            })
          })

          describe('the other events', async () => {

            it('should each have 4 topics', async () => {
              appTopics1.length.should.be.eq(4)
              appTopics2.length.should.be.eq(4)
            })

            it('should each have an empty data field', async () => {
              appData1.should.be.eq('0x0')
              appData2.should.be.eq('0x0')
            })

            it('should each match the topics sent', async () => {
              // First topic, both events
              hexStrEquals(appTopics1[0], emitTopics[0]).should.be.eq(true)
              let topicHex = web3.toHex(web3.toBigNumber(appTopics2[0]).minus(1))
              hexStrEquals(topicHex, emitTopics[0]).should.be.eq(true)
              // Second topic, both events
              hexStrEquals(appTopics1[1], emitTopics[1]).should.be.eq(true)
              topicHex = web3.toHex(web3.toBigNumber(appTopics2[1]).minus(1))
              hexStrEquals(topicHex, emitTopics[1]).should.be.eq(true)
              // Third topic, both events
              hexStrEquals(appTopics1[2], emitTopics[2]).should.be.eq(true)
              topicHex = web3.toHex(web3.toBigNumber(appTopics2[2]).minus(1))
              hexStrEquals(topicHex, emitTopics[2]).should.be.eq(true)
              // Fourth topic, both events
              hexStrEquals(appTopics1[3], emitTopics[3]).should.be.eq(true)
              topicHex = web3.toHex(web3.toBigNumber(appTopics2[3]).minus(1))
              hexStrEquals(topicHex, emitTopics[3]).should.be.eq(true)
            })
          })
        })
      })
    })

    describe('MixedApp (app requests various actions from storage. order/amt not vary)', async () => {

      let target
      let calldata
      let returnData
      let execEvents

      beforeEach(async () => {
        target = mixApp.address
      })

      describe('2 actions (EMITS 1, THROWS)', async () => {

        let invalidCalldata

        beforeEach(async () => {
          invalidCalldata = await appMockUtil.req0.call(emitTopics[0])
          invalidCalldata.should.not.eq('0x0')
        })

        it('should throw', async () => {
          await storage.exec(
            target, executionID, invalidCalldata,
            { from: exec }
          ).should.not.be.fulfilled
        })
      })

      describe('2 actions (PAYS 1, STORES 1)', async () => {

        let initPayeeBalance = 0

        beforeEach(async () => {
          calldata = await appMockUtil.req1.call(
            payees[0], payouts[0], storageLocations[0], storageValues[0]
          )
          calldata.should.not.eq('0x0')

          returnData = await storage.exec.call(
            target, executionID, calldata,
            { from: exec, value: payouts[0] }
          ).should.be.fulfilled

          initPayeeBalance = web3.eth.getBalance(payees[0])

          execEvents = await storage.exec(
            target, executionID, calldata,
            { from: exec, value: payouts[0] }
          ).should.be.fulfilled.then((tx) => {
            return tx.logs
          })
        })

        describe('returned data', async () => {

          it('should return a tuple with 3 fields', async () => {
            returnData.length.should.be.eq(3)
          })

          it('should return the correct number of events emitted', async () => {
            returnData[0].toNumber().should.be.eq(0)
          })

          it('should return the correct number of addresses paid', async () => {
            returnData[1].toNumber().should.be.eq(1)
          })

          it('should return the correct number of storage slots written to', async () => {
            returnData[2].toNumber().should.be.eq(1)
          })
        })

        describe('exec events', async () => {

          let execEvent
          let payoutEvents

          beforeEach(async () => {
            payoutEvents = [execEvents[0]]
            execEvent = execEvents[1]
          })

          it('should emit 2 events total', async () => {
            execEvents.length.should.be.eq(2)
          })

          describe('the DeliveredPayment event', async () => {

            it('should match DeliveredPayment', async () => {
              payoutEvents[0].event.should.be.eq('DeliveredPayment')
            })

            it('should match the used execution id', async () => {
              let emittedExecId = payoutEvents[0].args['execution_id']
              emittedExecId.should.be.eq(executionID)
            })

            it('should match the payout destination', async () => {
              let emittedAddr = payoutEvents[0].args['destination']
              emittedAddr.should.be.eq(payees[0])
            })

            it('should match the amount sent', async () => {
              let emittedAmt = payoutEvents[0].args['amount']
              emittedAmt.toNumber().should.be.eq(payouts[0])
            })
          })

          describe('the ApplicationExecution event', async () => {

            it('should match ApplicationExecution', async () => {
              execEvent.event.should.be.eq('ApplicationExecution')
            })

            it('should match the used execution id', async () => {
              let emittedExecId = execEvent.args['execution_id']
              emittedExecId.should.be.eq(executionID)
            })

            it('should match the targeted app address', async () => {
              let emittedAddr = execEvent.args['script_target']
              emittedAddr.should.be.eq(target)
            })
          })
        })

        describe('payment', async () => {

          it('should have delivered the amount to the destination', async () => {
            let curPayeeBalance = web3.eth.getBalance(payees[0])
            curPayeeBalance.should.be.bignumber.eq(web3.toBigNumber(initPayeeBalance).plus(payouts[0]))
          })
        })
      })

      describe('2 actions (EMITS 1, STORES 1)', async () => {

        beforeEach(async () => {
          calldata = await appMockUtil.req2.call(
            emitTopics[0], storageLocations[0], storageValues[0]
          )
          calldata.should.not.eq('0x0')

          returnData = await storage.exec.call(
            target, executionID, calldata,
            { from: exec }
          ).should.be.fulfilled

          execEvents = await storage.exec(
            target, executionID, calldata,
            { from: exec }
          ).should.be.fulfilled.then((tx) => {
            return tx.receipt.logs
          })
        })

        describe('returned data', async () => {

          it('should return a tuple with 3 fields', async () => {
            returnData.length.should.be.eq(3)
          })

          it('should return the correct number of events emitted', async () => {
            returnData[0].toNumber().should.be.eq(1)
          })

          it('should return the correct number of addresses paid', async () => {
            returnData[1].toNumber().should.be.eq(0)
          })

          it('should return the correct number of storage slots written to', async () => {
            returnData[2].toNumber().should.be.eq(1)
          })
        })

        describe('exec events', async () => {

          let appTopics
          let appData
          let execTopics
          let execData

          beforeEach(async () => {
            appTopics = execEvents[0].topics
            appData = execEvents[0].data
            execTopics = execEvents[1].topics
            execData = execEvents[1].data
          })

          it('should emit 2 events total', async () => {
            execEvents.length.should.be.eq(2)
          })

          describe('the ApplicationExecution event', async () => {

            it('should have 3 topics', async () => {
              execTopics.length.should.be.eq(3)
            })

            it('should have the event signature as the first topic', async () => {
              let sig = execTopics[0]
              web3.toDecimal(sig).should.be.eq(web3.toDecimal(execHash))
            })

            it('should match the used execution id', async () => {
              let emittedExecId = execTopics[1]
              emittedExecId.should.be.eq(executionID)
            })

            it('should match the targeted app address', async () => {
              let emittedAddr = execTopics[2]
              web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(target))
            })

            it('should have an empty data field', async () => {
              execData.should.be.eq('0x0')
            })
          })

          describe('the other event', async () => {

            it('should have 1 topic', async () => {
              appTopics.length.should.be.eq(1)
            })

            it('should have an empty data field', async () => {
              appData.should.be.eq('0x0')
            })

            it('should match the topic sent', async () => {
              hexStrEquals(appTopics[0], emitTopics[0]).should.be.eq(true)
            })
          })
        })

        describe('storage', async () => {

          it('should have correctly stored the value at the location', async () => {
            let readValue = await storage.read.call(executionID, storageLocations[0])
            hexStrEquals(readValue, storageValues[0]).should.be.eq(true)
          })
        })
      })

      describe('2 actions (PAYS 1, EMITS 1)', async () => {

        let initPayeeBalance

        beforeEach(async () => {
          calldata = await appMockUtil.req3.call(
            payees[0], payouts[0], emitTopics[0]
          )
          calldata.should.not.eq('0x0')

          returnData = await storage.exec.call(
            target, executionID, calldata,
            { from: exec, value: payouts[0] }
          ).should.be.fulfilled

          initPayeeBalance = web3.eth.getBalance(payees[0])

          execEvents = await storage.exec(
            target, executionID, calldata,
            { from: exec, value: payouts[0] }
          ).should.be.fulfilled.then((tx) => {
            return tx.receipt.logs
          })
        })

        describe('returned data', async () => {

          it('should return a tuple with 3 fields', async () => {
            returnData.length.should.be.eq(3)
          })

          it('should return the correct number of events emitted', async () => {
            returnData[0].toNumber().should.be.eq(1)
          })

          it('should return the correct number of addresses paid', async () => {
            returnData[1].toNumber().should.be.eq(1)
          })

          it('should return the correct number of storage slots written to', async () => {
            returnData[2].toNumber().should.be.eq(0)
          })
        })

        describe('exec events', async () => {

          let execTopics
          let execData
          let payoutTopics
          let payoutData
          let appTopics
          let appData

          beforeEach(async () => {
            payoutTopics = execEvents[0].topics
            payoutData = execEvents[0].data
            appTopics = execEvents[1].topics
            appData = execEvents[1].data
            execTopics = execEvents[2].topics
            execData = execEvents[2].data
          })

          it('should emit 3 events total', async () => {
            execEvents.length.should.be.eq(3)
          })

          describe('the DeliveredPayment event', async () => {

            it('should have 3 topics', async () => {
              payoutTopics.length.should.be.eq(3)
            })

            it('should have the event signature as the first topic', async () => {
              let sig = payoutTopics[0]
              web3.toDecimal(sig).should.be.eq(web3.toDecimal(payHash))
            })

            it('should match the used execution id', async () => {
              let emittedExecId = payoutTopics[1]
              emittedExecId.should.be.eq(executionID)
            })

            it('should match the payout destination', async () => {
              let emittedAddr = payoutTopics[2]
              web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(payees[0]))
            })

            it('should have an empty data field', async () => {
              web3.toDecimal(payoutData).should.be.eq(payouts[0])
            })
          })

          describe('the ApplicationExecution event', async () => {

            it('should have 3 topics', async () => {
              execTopics.length.should.be.eq(3)
            })

            it('should have the event signature as the first topic', async () => {
              let sig = execTopics[0]
              web3.toDecimal(sig).should.be.eq(web3.toDecimal(execHash))
            })

            it('should match the used execution id', async () => {
              let emittedExecId = execTopics[1]
              emittedExecId.should.be.eq(executionID)
            })

            it('should match the targeted app address', async () => {
              let emittedAddr = execTopics[2]
              web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(target))
            })

            it('should have an empty data field', async () => {
              execData.should.be.eq('0x0')
            })
          })

          describe('the other event', async () => {

            it('should have 1 topic', async () => {
              appTopics.length.should.be.eq(1)
            })

            it('should have an empty data field', async () => {
              appData.should.be.eq('0x0')
            })

            it('should match the topic sent', async () => {
              hexStrEquals(appTopics[0], emitTopics[0]).should.be.eq(true)
            })
          })
        })

        describe('payment', async () => {

          it('should have delivered the amount to the destination', async () => {
            let curPayeeBalance = web3.eth.getBalance(payees[0])
            curPayeeBalance.should.be.bignumber.eq(web3.toBigNumber(initPayeeBalance).plus(payouts[0]))
          })
        })
      })

      describe('3 actions (PAYS 2, EMITS 1, THROWS)', async () => {

        let invalidCalldata

        beforeEach(async () => {
          invalidCalldata = await appMockUtil.reqs0.call(
            payees[0], payouts[0], payees[1], payouts[1],
            emitTopics[0], emitData1
          )
          invalidCalldata.should.not.eq('0x0')
        })

        it('should throw', async () => {
          await storage.exec(
            target, executionID, invalidCalldata,
            { from: exec }
          ).should.not.be.fulfilled
        })
      })

      describe('3 actions (EMITS 2, PAYS 1, STORES 2)', async () => {

        let initPayeeBalance

        beforeEach(async () => {
          calldata = await appMockUtil.reqs1.call(
            payees[0], payouts[0], emitData1, emitData2,
            storageLocations[0], storageValues[0],
            storageLocations[1], storageValues[1]
          )
          calldata.should.not.eq('0x0')

          returnData = await storage.exec.call(
            target, executionID, calldata,
            { from: exec, value: payouts[0] }
          ).should.be.fulfilled

          initPayeeBalance = web3.eth.getBalance(payees[0])

          execEvents = await storage.exec(
            target, executionID, calldata,
            { from: exec, value: payouts[0] }
          ).should.be.fulfilled.then((tx) => {
            return tx.receipt.logs
          })
        })

        describe('returned data', async () => {

          it('should return a tuple with 3 fields', async () => {
            returnData.length.should.be.eq(3)
          })

          it('should return the correct number of events emitted', async () => {
            returnData[0].toNumber().should.be.eq(2)
          })

          it('should return the correct number of addresses paid', async () => {
            returnData[1].toNumber().should.be.eq(1)
          })

          it('should return the correct number of storage slots written to', async () => {
            returnData[2].toNumber().should.be.eq(2)
          })
        })

        describe('exec events', async () => {

          let execTopics
          let execData
          let payoutTopics
          let payoutData
          let appTopics1
          let appData1
          let appTopics2
          let appData2

          beforeEach(async () => {
            appTopics1 = execEvents[0].topics
            appData1 = execEvents[0].data
            appTopics2 = execEvents[1].topics
            appData2 = execEvents[1].data
            payoutTopics = execEvents[2].topics
            payoutData = execEvents[2].data
            execTopics = execEvents[3].topics
            execData = execEvents[3].data
          })

          it('should emit 4 events total', async () => {
            execEvents.length.should.be.eq(4)
          })

          describe('the DeliveredPayment event', async () => {

            it('should have 3 topics', async () => {
              payoutTopics.length.should.be.eq(3)
            })

            it('should have the event signature as the first topic', async () => {
              let sig = payoutTopics[0]
              web3.toDecimal(sig).should.be.eq(web3.toDecimal(payHash))
            })

            it('should match the used execution id', async () => {
              let emittedExecId = payoutTopics[1]
              emittedExecId.should.be.eq(executionID)
            })

            it('should match the payout destination', async () => {
              let emittedAddr = payoutTopics[2]
              web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(payees[0]))
            })

            it('should match the amount sent in the data field', async () => {
              web3.toDecimal(payoutData).should.be.eq(payouts[0])
            })
          })

          describe('the ApplicationExecution event', async () => {

            it('should have 3 topics', async () => {
              execTopics.length.should.be.eq(3)
            })

            it('should have the event signature as the first topic', async () => {
              let sig = execTopics[0]
              web3.toDecimal(sig).should.be.eq(web3.toDecimal(execHash))
            })

            it('should match the used execution id', async () => {
              let emittedExecId = execTopics[1]
              emittedExecId.should.be.eq(executionID)
            })

            it('should match the targeted app address', async () => {
              let emittedAddr = execTopics[2]
              web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(target))
            })

            it('should have an empty data field', async () => {
              execData.should.be.eq('0x0')
            })
          })

          describe('the other events', async () => {

            it('should both have no topics', async () => {
              appTopics1.length.should.be.eq(0)
              appTopics2.length.should.be.eq(0)
            })

            it('should each match the data sent', async () => {
              hexStrEquals(appData1, emitData1).should.be.eq(true)
              hexStrEquals(appData2, emitData2).should.be.eq(true)
            })
          })
        })

        describe('storage', async () => {

          it('should have correctly stored the value at the first location', async () => {
            let readValue = await storage.read.call(executionID, storageLocations[0])
            hexStrEquals(readValue, storageValues[0]).should.be.eq(true)
          })

          it('should have correctly stored the value at the second location', async () => {
            let readValue = await storage.read.call(executionID, storageLocations[1])
            hexStrEquals(readValue, storageValues[1]).should.be.eq(true)
          })
        })

        describe('payment', async () => {

          it('should have delivered the amount to the destination', async () => {
            let curPayeeBalance = web3.eth.getBalance(payees[0])
            curPayeeBalance.should.be.bignumber.eq(web3.toBigNumber(initPayeeBalance).plus(payouts[0]))
          })
        })
      })

      describe('3 actions (PAYS 1, EMITS 3, STORES 1)', async () => {

        let initPayeeBalance

        beforeEach(async () => {
          calldata = await appMockUtil.reqs2.call(
            payees[0], payouts[0], emitTopics, emitData1,
            storageLocations[0], storageValues[0]
          )
          calldata.should.not.eq('0x0')

          returnData = await storage.exec.call(
            target, executionID, calldata,
            { from: exec, value: payouts[0] }
          ).should.be.fulfilled

          initPayeeBalance = web3.eth.getBalance(payees[0])
          execEvents = await storage.exec(
            target, executionID, calldata,
            { from: exec, value: payouts[0] }
          ).should.be.fulfilled.then((tx) => {
            return tx.receipt.logs
          })
        })

        describe('returned data', async () => {

          it('should return a tuple with 3 fields', async () => {
            returnData.length.should.be.eq(3)
          })

          it('should return the correct number of events emitted', async () => {
            returnData[0].toNumber().should.be.eq(3)
          })

          it('should return the correct number of addresses paid', async () => {
            returnData[1].toNumber().should.be.eq(1)
          })

          it('should return the correct number of storage slots written to', async () => {
            returnData[2].toNumber().should.be.eq(1)
          })
        })

        describe('exec events', async () => {

          let execTopics
          let execData
          let payoutTopics
          let payoutData
          let appTopics1
          let appData1
          let appTopics2
          let appData2
          let appTopics3
          let appData3

          beforeEach(async () => {
            payoutTopics = execEvents[0].topics
            payoutData = execEvents[0].data
            appTopics1 = execEvents[1].topics
            appData1 = execEvents[1].data
            appTopics2 = execEvents[2].topics
            appData2 = execEvents[2].data
            appTopics3 = execEvents[3].topics
            appData3 = execEvents[3].data
            execTopics = execEvents[4].topics
            execData = execEvents[4].data
          })

          it('should emit 5 events total', async () => {
            execEvents.length.should.be.eq(5)
          })

          describe('the DeliveredPayment event', async () => {

            it('should have 3 topics', async () => {
              payoutTopics.length.should.be.eq(3)
            })

            it('should have the event signature as the first topic', async () => {
              let sig = payoutTopics[0]
              web3.toDecimal(sig).should.be.eq(web3.toDecimal(payHash))
            })

            it('should match the used execution id', async () => {
              let emittedExecId = payoutTopics[1]
              emittedExecId.should.be.eq(executionID)
            })

            it('should match the payout destination', async () => {
              let emittedAddr = payoutTopics[2]
              web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(payees[0]))
            })

            it('should match the amount sent in the data field', async () => {
              web3.toDecimal(payoutData).should.be.eq(payouts[0])
            })
          })

          describe('the ApplicationExecution event', async () => {

            it('should have 3 topics', async () => {
              execTopics.length.should.be.eq(3)
            })

            it('should have the event signature as the first topic', async () => {
              let sig = execTopics[0]
              web3.toDecimal(sig).should.be.eq(web3.toDecimal(execHash))
            })

            it('should match the used execution id', async () => {
              let emittedExecId = execTopics[1]
              emittedExecId.should.be.eq(executionID)
            })

            it('should match the targeted app address', async () => {
              let emittedAddr = execTopics[2]
              web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(target))
            })

            it('should have an empty data field', async () => {
              execData.should.be.eq('0x0')
            })
          })

          describe('the other events', async () => {

            it('should each have 4 topics', async () => {
              appTopics1.length.should.be.eq(4)
              appTopics2.length.should.be.eq(4)
              appTopics3.length.should.be.eq(4)
            })

            it('should match the topics sent in the first event', async () => {
              // First topic
              hexStrEquals(appTopics1[0], emitTopics[0]).should.be.eq(true)
              // Second topic
              hexStrEquals(appTopics1[1], emitTopics[1]).should.be.eq(true)
              // Third topic
              hexStrEquals(appTopics1[2], emitTopics[2]).should.be.eq(true)
              // Fourth topic
              hexStrEquals(appTopics1[3], emitTopics[3]).should.be.eq(true)
            })

            it('should match the topics sent in the second event', async () => {
              // First topic
              let topicHex = web3.toHex(web3.toBigNumber(appTopics2[0]).minus(1))
              hexStrEquals(topicHex, emitTopics[0]).should.be.eq(true)
              // Second topic
              topicHex = web3.toHex(web3.toBigNumber(appTopics2[1]).minus(1))
              hexStrEquals(topicHex, emitTopics[1]).should.be.eq(true)
              // Third topic
              topicHex = web3.toHex(web3.toBigNumber(appTopics2[2]).minus(1))
              hexStrEquals(topicHex, emitTopics[2]).should.be.eq(true)
              // Fourth topic
              topicHex = web3.toHex(web3.toBigNumber(appTopics2[3]).minus(1))
              hexStrEquals(topicHex, emitTopics[3]).should.be.eq(true)
            })

            it('should match the topics sent in the third event', async () => {
              // First topic
              let topicHex = web3.toHex(web3.toBigNumber(appTopics3[0]).minus(2))
              hexStrEquals(topicHex, emitTopics[0]).should.be.eq(true)
              // Second topic
              topicHex = web3.toHex(web3.toBigNumber(appTopics3[1]).minus(2))
              hexStrEquals(topicHex, emitTopics[1]).should.be.eq(true)
              // Third topic
              topicHex = web3.toHex(web3.toBigNumber(appTopics3[2]).minus(2))
              hexStrEquals(topicHex, emitTopics[2]).should.be.eq(true)
              // Fourth topic
              topicHex = web3.toHex(web3.toBigNumber(appTopics3[3]).minus(2))
              hexStrEquals(topicHex, emitTopics[3]).should.be.eq(true)
            })

            it('should each match the data sent', async () => {
              hexStrEquals(appData1, emitData1).should.be.eq(true)
              hexStrEquals(appData2, emitData1).should.be.eq(true)
              hexStrEquals(appData3, emitData1).should.be.eq(true)
            })
          })
        })

        describe('storage', async () => {

          it('should have correctly stored the value at the location', async () => {
            let readValue = await storage.read.call(executionID, storageLocations[0])
            hexStrEquals(readValue, storageValues[0]).should.be.eq(true)
          })
        })

        describe('payment', async () => {

          it('should have delivered the amount to the destination', async () => {
            let curPayeeBalance = web3.eth.getBalance(payees[0])
            curPayeeBalance.should.be.bignumber.eq(web3.toBigNumber(initPayeeBalance).plus(payouts[0]))
          })
        })
      })

      describe('3 actions (STORES 2, PAYS 1, EMITS 1)', async () => {

        let initPayeeBalance

        beforeEach(async () => {
          calldata = await appMockUtil.reqs3.call(
            payees[0], payouts[0], emitTopics[0], emitData1,
            storageLocations[0], storageValues[0],
            storageLocations[1], storageValues[1]
          )
          calldata.should.not.eq('0x0')

          returnData = await storage.exec.call(
            target, executionID, calldata,
            { from: exec, value: payouts[0] }
          ).should.be.fulfilled

          initPayeeBalance = web3.eth.getBalance(payees[0])

          execEvents = await storage.exec(
            target, executionID, calldata,
            { from: exec, value: payouts[0] }
          ).should.be.fulfilled.then((tx) => {
            return tx.receipt.logs
          })
        })

        describe('returned data', async () => {

          it('should return a tuple with 3 fields', async () => {
            returnData.length.should.be.eq(3)
          })

          it('should return the correct number of events emitted', async () => {
            returnData[0].toNumber().should.be.eq(1)
          })

          it('should return the correct number of addresses paid', async () => {
            returnData[1].toNumber().should.be.eq(1)
          })

          it('should return the correct number of storage slots written to', async () => {
            returnData[2].toNumber().should.be.eq(2)
          })
        })

        describe('exec events', async () => {

          let execTopics
          let execData
          let payoutTopics
          let payoutData
          let appTopics
          let appData

          beforeEach(async () => {
            payoutTopics = execEvents[0].topics
            payoutData = execEvents[0].data
            appTopics = execEvents[1].topics
            appData = execEvents[1].data
            execTopics = execEvents[2].topics
            execData = execEvents[2].data
          })

          it('should emit 3 events total', async () => {
            execEvents.length.should.be.eq(3)
          })

          describe('the DeliveredPayment event', async () => {

            it('should have 3 topics', async () => {
              payoutTopics.length.should.be.eq(3)
            })

            it('should have the event signature as the first topic', async () => {
              let sig = payoutTopics[0]
              web3.toDecimal(sig).should.be.eq(web3.toDecimal(payHash))
            })

            it('should match the used execution id', async () => {
              let emittedExecId = payoutTopics[1]
              emittedExecId.should.be.eq(executionID)
            })

            it('should match the payout destination', async () => {
              let emittedAddr = payoutTopics[2]
              web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(payees[0]))
            })

            it('should match the amount sent in the data field', async () => {
              web3.toDecimal(payoutData).should.be.eq(payouts[0])
            })
          })

          describe('the ApplicationExecution event', async () => {

            it('should have 3 topics', async () => {
              execTopics.length.should.be.eq(3)
            })

            it('should have the event signature as the first topic', async () => {
              let sig = execTopics[0]
              web3.toDecimal(sig).should.be.eq(web3.toDecimal(execHash))
            })

            it('should match the used execution id', async () => {
              let emittedExecId = execTopics[1]
              emittedExecId.should.be.eq(executionID)
            })

            it('should match the targeted app address', async () => {
              let emittedAddr = execTopics[2]
              web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(target))
            })

            it('should have an empty data field', async () => {
              execData.should.be.eq('0x0')
            })
          })

          describe('the other event', async () => {

            it('should have 1 topic', async () => {
              appTopics.length.should.be.eq(1)
            })

            it('should match the topic sent', async () => {
              hexStrEquals(appTopics[0], emitTopics[0]).should.be.eq(true)
            })

            it('should match the data sent', async () => {
              hexStrEquals(appData, emitData1).should.be.eq(true)
            })
          })
        })

        describe('storage', async () => {

          it('should have correctly stored the value at the first location', async () => {
            let readValue = await storage.read.call(executionID, storageLocations[0])
            hexStrEquals(readValue, storageValues[0]).should.be.eq(true)
          })

          it('should have correctly stored the value at the second location', async () => {
            let readValue = await storage.read.call(executionID, storageLocations[1])
            hexStrEquals(readValue, storageValues[1]).should.be.eq(true)
          })
        })

        describe('payment', async () => {

          it('should have delivered the amount to the destination', async () => {
            let curPayeeBalance = web3.eth.getBalance(payees[0])
            curPayeeBalance.should.be.bignumber.eq(web3.toBigNumber(initPayeeBalance).plus(payouts[0]))
          })
        })
      })
    })
  })

  // describe('#exec - nonpayable', async () => {
  //
  //   let executionID
  //
  //   beforeEach(async () => {
  //     let events = await storage.initAndFinalize(
  //       updater, false, appInit.address, initCalldata, allowedAddrs,
  //       { from: exec }
  //     ).should.be.fulfilled.then((tx) => {
  //       return tx.logs
  //     })
  //     events.should.not.eq(null)
  //     events.length.should.be.eq(2)
  //     events[0].event.should.be.eq('ApplicationInitialized')
  //     events[1].event.should.be.eq('ApplicationFinalization')
  //     executionID = events[0].args['execution_id']
  //     web3.toDecimal(executionID).should.not.eq(0)
  //   })
  //
  //   describe('invalid inputs or invalid state', async () => {
  //
  //     context('calldata is too short', async () => {
  //
  //       let invalidCalldata = '0xabcd'
  //
  //       it('should throw', async () => {
  //         await storage.exec(
  //           allowedAddrs[0], executionID, invalidCalldata,
  //           { from: exec }
  //         ).should.not.be.fulfilled
  //       })
  //     })
  //
  //     context('target address is 0', async () => {
  //
  //       let invalidAddr = zeroAddress()
  //
  //       it('should throw', async () => {
  //         await storage.exec(
  //           invalidAddr, executionID, stdAppCalldata[0],
  //           { from: exec }
  //         ).should.not.be.fulfilled
  //       })
  //     })
  //
  //     context('exec id is 0', async () => {
  //
  //       let invalidExecID = web3.toHex(0)
  //
  //       it('should throw', async () => {
  //         await storage.exec(
  //           allowedAddrs[0], invalidExecID, stdAppCalldata[0],
  //           { from: exec }
  //         ).should.not.be.fulfilled
  //       })
  //     })
  //
  //     context('sender is not script exec for the passed in execution id', async () => {
  //
  //       let invalidExec = otherAddr
  //
  //       it('should throw', async () => {
  //         await storage.exec(
  //           stdApp.address, executionID, stdAppCalldata[0],
  //           { from: invalidExec }
  //         ).should.not.be.fulfilled
  //       })
  //     })
  //
  //     context('ether sent to non-payable app', async () => {
  //
  //       it('should throw', async () => {
  //         await storage.exec(
  //           stdApp.address, executionID, stdAppCalldata[0],
  //           { from: exec, value: 1 }
  //         ).should.not.be.fulfilled
  //       })
  //     })
  //
  //     context('script target not in exec id allowed list', async () => {
  //
  //       let invalidTarget
  //
  //       beforeEach(async () => {
  //         invalidTarget = await StdApp.new().should.be.fulfilled
  //       })
  //
  //       it('should throw', async () => {
  //         await storage.exec(
  //           invalidTarget.address, executionID, stdAppCalldata[0],
  //           { from: exec }
  //         ).should.not.be.fulfilled
  //       })
  //     })
  //
  //     context('app is paused', async () => {
  //
  //       beforeEach(async () => {
  //         await storage.pauseAppInstance(executionID, { from: updater }).should.be.fulfilled
  //         let appInfo = await storage.app_info.call(executionID)
  //         appInfo[0].should.be.eq(true)
  //       })
  //
  //       it('should throw', async () => {
  //         await storage.exec(
  //           stdApp.address, executionID, stdAppCalldata[0],
  //           { from: exec }
  //         ).should.not.be.fulfilled
  //       })
  //     })
  //   })
  //
  //   describe('RevertApp (app reverts)', async () => {
  //
  //     let revertEvents
  //     let revertReturn
  //
  //     describe('function did not exist', async () => {
  //
  //       let invalidCalldata
  //
  //       beforeEach(async () => {
  //         invalidCalldata = await appMockUtil.rev0.call()
  //         invalidCalldata.should.not.eq('0x0')
  //
  //         revertReturn = await storage.exec.call(
  //           revertApp.address, executionID, invalidCalldata,
  //           { from: exec }
  //         ).should.be.fulfilled
  //
  //         revertEvents = await storage.exec(
  //           revertApp.address, executionID, invalidCalldata,
  //           { from: exec }
  //         ).should.be.fulfilled.then((tx) => {
  //           return tx.logs
  //         })
  //       })
  //
  //       describe('returned data', async () => {
  //
  //         it('should return a tuple with 3 fields', async () => {
  //           revertReturn.length.should.be.eq(3)
  //         })
  //
  //         it('should return blank data', async () => {
  //           revertReturn[0].toNumber().should.be.eq(0)
  //           revertReturn[1].toNumber().should.be.eq(0)
  //           revertReturn[2].toNumber().should.be.eq(0)
  //         })
  //       })
  //
  //       describe('revert events', async () => {
  //
  //         it('should emit a single ApplicationException event', async () => {
  //           revertEvents.length.should.be.eq(1)
  //           revertEvents[0].event.should.be.eq('ApplicationException')
  //         })
  //
  //         it('should match the used execution id', async () => {
  //           let emittedExecId = revertEvents[0].args['execution_id']
  //           emittedExecId.should.be.eq(executionID)
  //         })
  //
  //         it('should match the targeted app address', async () => {
  //           let emittedAddr = revertEvents[0].args['application_address']
  //           emittedAddr.should.be.eq(revertApp.address)
  //         })
  //
  //         it('should emit a message matching \'DefaultException\'', async () => {
  //           let emittedMessage = revertEvents[0].args['message']
  //           hexStrEquals(emittedMessage, 'DefaultException').should.be.eq(true,
  //             "emitted:" + web3.toAscii(emittedMessage)
  //           )
  //         })
  //       })
  //     })
  //
  //     describe('reverts with no message', async () => {
  //
  //       beforeEach(async () => {
  //         let revertCalldata = await appMockUtil.rev1.call()
  //         revertCalldata.should.not.eq('0x0')
  //
  //         revertReturn = await storage.exec.call(
  //           revertApp.address, executionID, revertCalldata,
  //           { from: exec }
  //         ).should.be.fulfilled
  //
  //         revertEvents = await storage.exec(
  //           revertApp.address, executionID, revertCalldata,
  //           { from: exec }
  //         ).should.be.fulfilled.then((tx) => {
  //           return tx.logs
  //         })
  //       })
  //
  //       describe('returned data', async () => {
  //
  //         it('should return a tuple with 3 fields', async () => {
  //           revertReturn.length.should.be.eq(3)
  //         })
  //
  //         it('should return blank data', async () => {
  //           revertReturn[0].toNumber().should.be.eq(0)
  //           revertReturn[1].toNumber().should.be.eq(0)
  //           revertReturn[2].toNumber().should.be.eq(0)
  //         })
  //       })
  //
  //       describe('revert events', async () => {
  //
  //         it('should emit a single ApplicationException event', async () => {
  //           revertEvents.length.should.be.eq(1)
  //           revertEvents[0].event.should.be.eq('ApplicationException')
  //         })
  //
  //         it('should match the used execution id', async () => {
  //           let emittedExecId = revertEvents[0].args['execution_id']
  //           emittedExecId.should.be.eq(executionID)
  //         })
  //
  //         it('should match the targeted app address', async () => {
  //           let emittedAddr = revertEvents[0].args['application_address']
  //           emittedAddr.should.be.eq(revertApp.address)
  //         })
  //
  //         it('should emit a message matching \'DefaultException\'', async () => {
  //           let emittedMessage = revertEvents[0].args['message']
  //           hexStrEquals(emittedMessage, 'DefaultException').should.be.eq(true,
  //             "emitted:" + web3.toAscii(emittedMessage)
  //           )
  //         })
  //       })
  //     })
  //
  //     describe('reverts with message', async () => {
  //
  //       beforeEach(async () => {
  //         let revertCalldata = await appMockUtil.rev2.call(revertMessage)
  //         revertCalldata.should.not.eq('0x0')
  //
  //         revertReturn = await storage.exec.call(
  //           revertApp.address, executionID, revertCalldata,
  //           { from: exec }
  //         ).should.be.fulfilled
  //
  //         revertEvents = await storage.exec(
  //           revertApp.address, executionID, revertCalldata,
  //           { from: exec }
  //         ).should.be.fulfilled.then((tx) => {
  //           return tx.logs
  //         })
  //       })
  //
  //       describe('returned data', async () => {
  //
  //         it('should return a tuple with 3 fields', async () => {
  //           revertReturn.length.should.be.eq(3)
  //         })
  //
  //         it('should return blank data', async () => {
  //           revertReturn[0].toNumber().should.be.eq(0)
  //           revertReturn[1].toNumber().should.be.eq(0)
  //           revertReturn[2].toNumber().should.be.eq(0)
  //         })
  //       })
  //
  //       describe('revert events', async () => {
  //
  //         it('should emit a single ApplicationException event', async () => {
  //           revertEvents.length.should.be.eq(1)
  //           revertEvents[0].event.should.be.eq('ApplicationException')
  //         })
  //
  //         it('should match the used execution id', async () => {
  //           let emittedExecId = revertEvents[0].args['execution_id']
  //           emittedExecId.should.be.eq(executionID)
  //         })
  //
  //         it('should match the targeted app address', async () => {
  //           let emittedAddr = revertEvents[0].args['application_address']
  //           emittedAddr.should.be.eq(revertApp.address)
  //         })
  //
  //         it('should emit the correct message', async () => {
  //           let emittedMessage = revertEvents[0].args['message']
  //           hexStrEquals(emittedMessage, revertMessage).should.be.eq(true,
  //             "emitted:" + web3.toAscii(emittedMessage)
  //           )
  //         })
  //       })
  //     })
  //
  //     describe('signals to throw with a message', async () => {
  //
  //       let revertCalldata
  //
  //       beforeEach(async () => {
  //         revertCalldata = await appMockUtil.throws1.call(throwMessage)
  //         revertCalldata.should.not.eq('0x0')
  //       })
  //
  //       it('should throw', async () => {
  //         await storage.exec(
  //           revertApp.address, executionID, revertCalldata,
  //           { from: exec }
  //         ).should.not.be.fulfilled
  //       })
  //     })
  //
  //     describe('signals to throw incorrectly', async () => {
  //
  //       let revertCalldata
  //
  //       beforeEach(async () => {
  //         revertCalldata = await appMockUtil.throws2.call(throwMessage)
  //         revertCalldata.should.not.eq('0x0')
  //       })
  //
  //       it('should throw', async () => {
  //         await storage.exec(
  //           revertApp.address, executionID, revertCalldata,
  //           { from: exec }
  //         ).should.not.be.fulfilled
  //       })
  //     })
  //   })
  //
  //   describe('InvalidApp (app returns malformed data)', async () => {
  //
  //     let target
  //     let calldata
  //
  //     beforeEach(async () => {
  //       target = invalidApp.address
  //     })
  //
  //     describe('app attempts to pay storage contract', async () => {
  //
  //       beforeEach(async () => {
  //         calldata = await appMockUtil.inv1.call()
  //         calldata.should.not.eq('0x0')
  //       })
  //
  //       it('should throw', async () => {
  //         await storage.exec.call(
  //           target, executionID, calldata,
  //           { from: exec }
  //         ).should.not.be.fulfilled
  //       })
  //     })
  //
  //     describe('app does not change state', async () => {
  //
  //       beforeEach(async () => {
  //         calldata = await appMockUtil.inv2.call()
  //         calldata.should.not.eq('0x0')
  //       })
  //
  //       it('should throw', async () => {
  //         await storage.exec.call(
  //           target, executionID, calldata,
  //           { from: exec }
  //         ).should.not.be.fulfilled
  //       })
  //     })
  //   })
  //
  //   describe('StdApp (app stores data)', async () => {
  //
  //     let target
  //     let calldata
  //     let returnData
  //     let execEvents
  //
  //     beforeEach(async () => {
  //       target = stdApp.address
  //     })
  //
  //     describe('storing to 0 slots', async () => {
  //
  //       let invalidCalldata
  //
  //       beforeEach(async () => {
  //         invalidCalldata = await appMockUtil.std0.call()
  //         invalidCalldata.should.not.eq('0x0')
  //       })
  //
  //       it('should throw', async () => {
  //         await storage.exec(
  //           target, executionID, invalidCalldata,
  //           { from: exec }
  //         ).should.not.be.fulfilled
  //       })
  //     })
  //
  //     describe('storing to one slot', async () => {
  //
  //       beforeEach(async () => {
  //         calldata = await appMockUtil.std1.call(
  //           storageLocations[0], storageValues[0]
  //         )
  //         calldata.should.not.eq('0x0')
  //
  //         returnData = await storage.exec.call(
  //           target, executionID, calldata,
  //           { from: exec }
  //         ).should.be.fulfilled
  //
  //         execEvents = await storage.exec(
  //           target, executionID, calldata,
  //           { from: exec }
  //         ).should.be.fulfilled.then((tx) => {
  //           return tx.logs
  //         })
  //       })
  //
  //       describe('returned data', async () => {
  //
  //         it('should return a tuple with 3 fields', async () => {
  //           returnData.length.should.be.eq(3)
  //         })
  //
  //         it('should return 0 events emitted', async () => {
  //           returnData[0].toNumber().should.be.eq(0)
  //         })
  //
  //         it('should return 0 addresses paid', async () => {
  //           returnData[1].toNumber().should.be.eq(0)
  //         })
  //
  //         it('should return the correct number of slots written to', async () => {
  //           returnData[2].toNumber().should.be.eq(1)
  //         })
  //       })
  //
  //       describe('exec events', async () => {
  //
  //         it('should emit a single ApplicationExecution event', async () => {
  //           execEvents.length.should.be.eq(1)
  //           execEvents[0].event.should.be.eq('ApplicationExecution')
  //         })
  //
  //         it('should match the used execution id', async () => {
  //           let emittedExecId = execEvents[0].args['execution_id']
  //           emittedExecId.should.be.eq(executionID)
  //         })
  //
  //         it('should match the targeted app address', async () => {
  //           let emittedAddr = execEvents[0].args['script_target']
  //           emittedAddr.should.be.eq(target)
  //         })
  //       })
  //
  //       describe('storage', async () => {
  //
  //         it('should have correctly stored the value at the location', async () => {
  //           let readValue = await storage.read.call(executionID, storageLocations[0])
  //           hexStrEquals(readValue, storageValues[0]).should.be.eq(true, readValue)
  //         })
  //       })
  //     })
  //
  //     describe('storing to 2 slots', async () => {
  //
  //       beforeEach(async () => {
  //         calldata = await appMockUtil.std2.call(
  //           storageLocations[0], storageValues[0], storageLocations[1], storageValues[1]
  //         )
  //         calldata.should.not.eq('0x0')
  //
  //         returnData = await storage.exec.call(
  //           target, executionID, calldata,
  //           { from: exec }
  //         ).should.be.fulfilled
  //
  //         execEvents = await storage.exec(
  //           target, executionID, calldata,
  //           { from: exec }
  //         ).should.be.fulfilled.then((tx) => {
  //           return tx.logs
  //         })
  //       })
  //
  //       describe('returned data', async () => {
  //
  //         it('should return a tuple with 3 fields', async () => {
  //           returnData.length.should.be.eq(3)
  //         })
  //
  //         it('should return 0 events emitted', async () => {
  //           returnData[0].toNumber().should.be.eq(0)
  //         })
  //
  //         it('should return 0 addresses paid', async () => {
  //           returnData[1].toNumber().should.be.eq(0)
  //         })
  //
  //         it('should return the correct number of slots written to', async () => {
  //           returnData[2].toNumber().should.be.eq(2)
  //         })
  //       })
  //
  //       describe('exec events', async () => {
  //
  //         it('should emit a single ApplicationExecution event', async () => {
  //           execEvents.length.should.be.eq(1)
  //           execEvents[0].event.should.be.eq('ApplicationExecution')
  //         })
  //
  //         it('should match the used execution id', async () => {
  //           let emittedExecId = execEvents[0].args['execution_id']
  //           emittedExecId.should.be.eq(executionID)
  //         })
  //
  //         it('should match the targeted app address', async () => {
  //           let emittedAddr = execEvents[0].args['script_target']
  //           emittedAddr.should.be.eq(target)
  //         })
  //       })
  //
  //       describe('storage', async () => {
  //
  //         it('should have correctly stored the value at the first location', async () => {
  //           let readValue = await storage.read.call(executionID, storageLocations[0])
  //           hexStrEquals(readValue, storageValues[0]).should.be.eq(true)
  //         })
  //
  //         it('should have correctly stored the value at the second location', async () => {
  //           let readValue = await storage.read.call(executionID, storageLocations[1])
  //           hexStrEquals(readValue, storageValues[1]).should.be.eq(true)
  //         })
  //       })
  //     })
  //   })
  //
  //   // Note: All PAYS action cause non-payable applications to fail
  //   describe('PayableApp (forwards ETH)', async () => {
  //
  //     let target
  //     let calldata
  //     let returnData
  //     let execEvents
  //
  //     beforeEach(async () => {
  //       target = payableApp.address
  //     })
  //
  //     describe('pays out to 0 addresses', async () => {
  //
  //       let invalidCalldata
  //
  //       beforeEach(async () => {
  //         invalidCalldata = await appMockUtil.pay0.call()
  //         invalidCalldata.should.not.eq('0x0')
  //       })
  //
  //       it('should throw', async () => {
  //         await storage.exec(
  //           target, executionID, invalidCalldata,
  //           { from: exec }
  //         ).should.not.be.fulfilled
  //       })
  //     })
  //
  //     describe('pays out to 1 address', async () => {
  //
  //       beforeEach(async () => {
  //         calldata = await appMockUtil.pay1.call(payees[0], payouts[0])
  //         calldata.should.not.eq('0x0')
  //       })
  //
  //       it('should throw', async () => {
  //         await storage.exec(
  //           target, executionID, calldata,
  //           { from: exec }
  //         ).should.not.be.fulfilled
  //       })
  //     })
  //
  //     describe('pays out to 2 addresses', async () => {
  //
  //       beforeEach(async () => {
  //         calldata = await appMockUtil.pay2.call(
  //           payees[0], payouts[0], payees[1], payouts[1]
  //         )
  //         calldata.should.not.eq('0x0')
  //       })
  //
  //       it('should throw', async () => {
  //         await storage.exec(
  //           target, executionID, calldata,
  //           { from: exec }
  //         ).should.not.be.fulfilled
  //       })
  //     })
  //   })
  //
  //   describe('EmitsApp (app emits events)', async () => {
  //
  //     let target
  //     let calldata
  //     let returnData
  //     let execEvents
  //
  //     beforeEach(async () => {
  //       target = emitApp.address
  //     })
  //
  //     describe('emitting 0 events', async () => {
  //
  //       let invalidCalldata
  //
  //       beforeEach(async () => {
  //         invalidCalldata = await appMockUtil.emit0.call()
  //         invalidCalldata.should.not.eq('0x0')
  //       })
  //
  //       it('should throw', async () => {
  //         await storage.exec(
  //           target, executionID, invalidCalldata,
  //           { from: exec }
  //         ).should.not.be.fulfilled
  //       })
  //     })
  //
  //     describe('emitting 1 event with no topics or data', async () => {
  //
  //       beforeEach(async () => {
  //         calldata = await appMockUtil.emit1top0.call()
  //         calldata.should.not.eq('0x0')
  //
  //         returnData = await storage.exec.call(
  //           target, executionID, calldata,
  //           { from: exec }
  //         ).should.be.fulfilled
  //
  //         execEvents = await storage.exec(
  //           target, executionID, calldata,
  //           { from: exec }
  //         ).should.be.fulfilled.then((tx) => {
  //           return tx.receipt.logs
  //         })
  //       })
  //
  //       describe('returned data', async () => {
  //
  //         it('should return a tuple with 3 fields', async () => {
  //           returnData.length.should.be.eq(3)
  //         })
  //
  //         it('should return the correct number of events emitted', async () => {
  //           returnData[0].toNumber().should.be.eq(1)
  //         })
  //
  //         it('should return 0 addresses paid', async () => {
  //           returnData[1].toNumber().should.be.eq(0)
  //         })
  //
  //         it('should return 0 storage slots written to', async () => {
  //           returnData[2].toNumber().should.be.eq(0)
  //         })
  //       })
  //
  //       describe('exec events', async () => {
  //
  //         let appTopics
  //         let appData
  //         let execTopics
  //         let execData
  //
  //         beforeEach(async () => {
  //           appTopics = execEvents[0].topics
  //           appData = execEvents[0].data
  //           execTopics = execEvents[1].topics
  //           execData = execEvents[1].data
  //         })
  //
  //         it('should emit 2 events total', async () => {
  //           execEvents.length.should.be.eq(2)
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
  //             emittedExecId.should.be.eq(executionID)
  //           })
  //
  //           it('should match the targeted app address', async () => {
  //             let emittedAddr = execTopics[2]
  //             web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(target))
  //           })
  //
  //           it('should have an empty data field', async () => {
  //             execData.should.be.eq('0x0')
  //           })
  //         })
  //
  //         describe('the other event', async () => {
  //
  //           it('should have no topics', async () => {
  //             appTopics.length.should.be.eq(0)
  //           })
  //
  //           it('should have no data', async () => {
  //             appData.should.be.eq('0x0')
  //           })
  //         })
  //       })
  //     })
  //
  //     describe('emitting 1 event with no topics with data', async () => {
  //
  //       beforeEach(async () => {
  //         calldata = await appMockUtil.emit1top0data.call(emitData1)
  //         calldata.should.not.eq('0x0')
  //
  //         returnData = await storage.exec.call(
  //           target, executionID, calldata,
  //           { from: exec }
  //         ).should.be.fulfilled
  //
  //         execEvents = await storage.exec(
  //           target, executionID, calldata,
  //           { from: exec }
  //         ).should.be.fulfilled.then((tx) => {
  //           return tx.receipt.logs
  //         })
  //       })
  //
  //       describe('returned data', async () => {
  //
  //         it('should return a tuple with 3 fields', async () => {
  //           returnData.length.should.be.eq(3)
  //         })
  //
  //         it('should return the correct number of events emitted', async () => {
  //           returnData[0].toNumber().should.be.eq(1)
  //         })
  //
  //         it('should return 0 addresses paid', async () => {
  //           returnData[1].toNumber().should.be.eq(0)
  //         })
  //
  //         it('should return 0 storage slots written to', async () => {
  //           returnData[2].toNumber().should.be.eq(0)
  //         })
  //       })
  //
  //       describe('exec events', async () => {
  //
  //         let appTopics
  //         let appData
  //         let execTopics
  //         let execData
  //
  //         beforeEach(async () => {
  //           appTopics = execEvents[0].topics
  //           appData = execEvents[0].data
  //           execTopics = execEvents[1].topics
  //           execData = execEvents[1].data
  //         })
  //
  //         it('should emit 2 events total', async () => {
  //           execEvents.length.should.be.eq(2)
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
  //             emittedExecId.should.be.eq(executionID)
  //           })
  //
  //           it('should match the targeted app address', async () => {
  //             let emittedAddr = execTopics[2]
  //             web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(target))
  //           })
  //
  //           it('should have an empty data field', async () => {
  //             execData.should.be.eq('0x0')
  //           })
  //         })
  //
  //         describe('the other event', async () => {
  //
  //           it('should have no topics', async () => {
  //             appTopics.length.should.be.eq(0)
  //           })
  //
  //           it('should match the data sent', async () => {
  //             hexStrEquals(appData, emitData1).should.be.eq(true)
  //           })
  //         })
  //       })
  //     })
  //
  //     describe('emitting 1 event with 4 topics with data', async () => {
  //
  //       beforeEach(async () => {
  //         calldata = await appMockUtil.emit1top4data.call(
  //           emitTopics[0], emitTopics[1], emitTopics[2], emitTopics[3],
  //           emitData1
  //         )
  //         calldata.should.not.eq('0x0')
  //
  //         returnData = await storage.exec.call(
  //           target, executionID, calldata,
  //           { from: exec }
  //         ).should.be.fulfilled
  //
  //         execEvents = await storage.exec(
  //           target, executionID, calldata,
  //           { from: exec }
  //         ).should.be.fulfilled.then((tx) => {
  //           return tx.receipt.logs
  //         })
  //       })
  //
  //       describe('returned data', async () => {
  //
  //         it('should return a tuple with 3 fields', async () => {
  //           returnData.length.should.be.eq(3)
  //         })
  //
  //         it('should return the correct number of events emitted', async () => {
  //           returnData[0].toNumber().should.be.eq(1)
  //         })
  //
  //         it('should return 0 addresses paid', async () => {
  //           returnData[1].toNumber().should.be.eq(0)
  //         })
  //
  //         it('should return 0 storage slots written to', async () => {
  //           returnData[2].toNumber().should.be.eq(0)
  //         })
  //       })
  //
  //       describe('exec events', async () => {
  //
  //         let appTopics
  //         let appData
  //         let execTopics
  //         let execData
  //
  //         beforeEach(async () => {
  //           appTopics = execEvents[0].topics
  //           appData = execEvents[0].data
  //           execTopics = execEvents[1].topics
  //           execData = execEvents[1].data
  //         })
  //
  //         it('should emit 2 events total', async () => {
  //           execEvents.length.should.be.eq(2)
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
  //             emittedExecId.should.be.eq(executionID)
  //           })
  //
  //           it('should match the targeted app address', async () => {
  //             let emittedAddr = execTopics[2]
  //             web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(target))
  //           })
  //
  //           it('should have an empty data field', async () => {
  //             execData.should.be.eq('0x0')
  //           })
  //         })
  //
  //         describe('the other event', async () => {
  //
  //           it('should have 4 topics', async () => {
  //             appTopics.length.should.be.eq(4)
  //           })
  //
  //           it('should match the data sent', async () => {
  //             hexStrEquals(appData, emitData1).should.be.eq(true)
  //           })
  //
  //           it('should match the topics sent', async () => {
  //             hexStrEquals(appTopics[0], emitTopics[0]).should.be.eq(true)
  //             hexStrEquals(appTopics[1], emitTopics[1]).should.be.eq(true)
  //             hexStrEquals(appTopics[2], emitTopics[2]).should.be.eq(true)
  //             hexStrEquals(appTopics[3], emitTopics[3]).should.be.eq(true)
  //           })
  //         })
  //       })
  //     })
  //
  //     describe('emitting 2 events, each with 1 topic and data', async () => {
  //
  //       beforeEach(async () => {
  //         calldata = await appMockUtil.emit2top1data.call(
  //           emitTopics[0], emitData1, emitData2
  //         )
  //         calldata.should.not.eq('0x0')
  //
  //         returnData = await storage.exec.call(
  //           target, executionID, calldata,
  //           { from: exec }
  //         ).should.be.fulfilled
  //
  //         execEvents = await storage.exec(
  //           target, executionID, calldata,
  //           { from: exec }
  //         ).should.be.fulfilled.then((tx) => {
  //           return tx.receipt.logs
  //         })
  //       })
  //
  //       describe('returned data', async () => {
  //
  //         it('should return a tuple with 3 fields', async () => {
  //           returnData.length.should.be.eq(3)
  //         })
  //
  //         it('should return the correct number of events emitted', async () => {
  //           returnData[0].toNumber().should.be.eq(2)
  //         })
  //
  //         it('should return 0 addresses paid', async () => {
  //           returnData[1].toNumber().should.be.eq(0)
  //         })
  //
  //         it('should return 0 storage slots written to', async () => {
  //           returnData[2].toNumber().should.be.eq(0)
  //         })
  //       })
  //
  //       describe('exec events', async () => {
  //
  //         let appTopics1
  //         let appData1
  //         let appTopics2
  //         let appData2
  //         let execTopics
  //         let execData
  //
  //         beforeEach(async () => {
  //           appTopics1 = execEvents[0].topics
  //           appData1 = execEvents[0].data
  //           appTopics2 = execEvents[1].topics
  //           appData2 = execEvents[1].data
  //           execTopics = execEvents[2].topics
  //           execData = execEvents[2].data
  //         })
  //
  //         it('should emit 3 events total', async () => {
  //           execEvents.length.should.be.eq(3)
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
  //             emittedExecId.should.be.eq(executionID)
  //           })
  //
  //           it('should match the targeted app address', async () => {
  //             let emittedAddr = execTopics[2]
  //             web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(target))
  //           })
  //
  //           it('should have an empty data field', async () => {
  //             execData.should.be.eq('0x0')
  //           })
  //         })
  //
  //         describe('the other events', async () => {
  //
  //           it('should each have 1 topic', async () => {
  //             appTopics1.length.should.be.eq(1)
  //             appTopics2.length.should.be.eq(1)
  //           })
  //
  //           it('should each match the data sent', async () => {
  //             hexStrEquals(appData1, emitData1).should.be.eq(true)
  //             hexStrEquals(appData2, emitData2).should.be.eq(true)
  //           })
  //
  //           it('should each match the topics sent', async () => {
  //             hexStrEquals(appTopics1[0], emitTopics[0]).should.be.eq(true)
  //             let appTopics2Hex = web3.toHex(
  //               web3.toBigNumber(appTopics2[0]).minus(1)
  //             )
  //             hexStrEquals(appTopics2Hex, emitTopics[0]).should.be.eq(true)
  //           })
  //         })
  //       })
  //     })
  //
  //     describe('emitting 2 events, each with 4 topics and no data', async () => {
  //
  //       beforeEach(async () => {
  //         calldata = await appMockUtil.emit2top4.call(
  //           emitTopics[0], emitTopics[1], emitTopics[2], emitTopics[3]
  //         )
  //         calldata.should.not.eq('0x0')
  //
  //         returnData = await storage.exec.call(
  //           target, executionID, calldata,
  //           { from: exec }
  //         ).should.be.fulfilled
  //
  //         execEvents = await storage.exec(
  //           target, executionID, calldata,
  //           { from: exec }
  //         ).should.be.fulfilled.then((tx) => {
  //           return tx.receipt.logs
  //         })
  //       })
  //
  //       describe('returned data', async () => {
  //
  //         it('should return a tuple with 3 fields', async () => {
  //           returnData.length.should.be.eq(3)
  //         })
  //
  //         it('should return the correct number of events emitted', async () => {
  //           returnData[0].toNumber().should.be.eq(2)
  //         })
  //
  //         it('should return 0 addresses paid', async () => {
  //           returnData[1].toNumber().should.be.eq(0)
  //         })
  //
  //         it('should return 0 storage slots written to', async () => {
  //           returnData[2].toNumber().should.be.eq(0)
  //         })
  //       })
  //
  //       describe('exec events', async () => {
  //
  //         let appTopics1
  //         let appData1
  //         let appTopics2
  //         let appData2
  //         let execTopics
  //         let execData
  //
  //         beforeEach(async () => {
  //           appTopics1 = execEvents[0].topics
  //           appData1 = execEvents[0].data
  //           appTopics2 = execEvents[1].topics
  //           appData2 = execEvents[1].data
  //           execTopics = execEvents[2].topics
  //           execData = execEvents[2].data
  //         })
  //
  //         it('should emit 3 events total', async () => {
  //           execEvents.length.should.be.eq(3)
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
  //             emittedExecId.should.be.eq(executionID)
  //           })
  //
  //           it('should match the targeted app address', async () => {
  //             let emittedAddr = execTopics[2]
  //             web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(target))
  //           })
  //
  //           it('should have an empty data field', async () => {
  //             execData.should.be.eq('0x0')
  //           })
  //         })
  //
  //         describe('the other events', async () => {
  //
  //           it('should each have 4 topics', async () => {
  //             appTopics1.length.should.be.eq(4)
  //             appTopics2.length.should.be.eq(4)
  //           })
  //
  //           it('should each have an empty data field', async () => {
  //             appData1.should.be.eq('0x0')
  //             appData2.should.be.eq('0x0')
  //           })
  //
  //           it('should each match the topics sent', async () => {
  //             // First topic, both events
  //             hexStrEquals(appTopics1[0], emitTopics[0]).should.be.eq(true)
  //             let topicHex = web3.toHex(web3.toBigNumber(appTopics2[0]).minus(1))
  //             hexStrEquals(topicHex, emitTopics[0]).should.be.eq(true)
  //             // Second topic, both events
  //             hexStrEquals(appTopics1[1], emitTopics[1]).should.be.eq(true)
  //             topicHex = web3.toHex(web3.toBigNumber(appTopics2[1]).minus(1))
  //             hexStrEquals(topicHex, emitTopics[1]).should.be.eq(true)
  //             // Third topic, both events
  //             hexStrEquals(appTopics1[2], emitTopics[2]).should.be.eq(true)
  //             topicHex = web3.toHex(web3.toBigNumber(appTopics2[2]).minus(1))
  //             hexStrEquals(topicHex, emitTopics[2]).should.be.eq(true)
  //             // Fourth topic, both events
  //             hexStrEquals(appTopics1[3], emitTopics[3]).should.be.eq(true)
  //             topicHex = web3.toHex(web3.toBigNumber(appTopics2[3]).minus(1))
  //             hexStrEquals(topicHex, emitTopics[3]).should.be.eq(true)
  //           })
  //         })
  //       })
  //     })
  //   })
  //
  //   // Note: All PAYS action cause non-payable applications to fail
  //   describe('MixedApp (app requests various actions from storage. order/amt not vary)', async () => {
  //
  //     let target
  //     let calldata
  //     let returnData
  //     let execEvents
  //
  //     beforeEach(async () => {
  //       target = mixApp.address
  //     })
  //
  //     describe('2 actions (EMITS 1, THROWS)', async () => {
  //
  //       let invalidCalldata
  //
  //       beforeEach(async () => {
  //         invalidCalldata = await appMockUtil.req0.call(emitTopics[0])
  //         invalidCalldata.should.not.eq('0x0')
  //       })
  //
  //       it('should throw', async () => {
  //         await storage.exec(
  //           target, executionID, invalidCalldata,
  //           { from: exec }
  //         ).should.not.be.fulfilled
  //       })
  //     })
  //
  //     describe('2 actions (PAYS 1, STORES 1)', async () => {
  //
  //       let invalidCalldata
  //
  //       beforeEach(async () => {
  //         invalidCalldata = await appMockUtil.req1.call(
  //           payees[0], payouts[0], storageLocations[0], storageValues[0]
  //         )
  //         invalidCalldata.should.not.eq('0x0')
  //       })
  //
  //       it('should throw', async () => {
  //         await storage.exec(
  //           target, executionID, invalidCalldata,
  //           { from: exec }
  //         ).should.not.be.fulfilled
  //       })
  //     })
  //
  //     describe('2 actions (EMITS 1, STORES 1)', async () => {
  //
  //       beforeEach(async () => {
  //         calldata = await appMockUtil.req2.call(
  //           emitTopics[0], storageLocations[0], storageValues[0]
  //         )
  //         calldata.should.not.eq('0x0')
  //
  //         returnData = await storage.exec.call(
  //           target, executionID, calldata,
  //           { from: exec }
  //         ).should.be.fulfilled
  //
  //         execEvents = await storage.exec(
  //           target, executionID, calldata,
  //           { from: exec }
  //         ).should.be.fulfilled.then((tx) => {
  //           return tx.receipt.logs
  //         })
  //       })
  //
  //       describe('returned data', async () => {
  //
  //         it('should return a tuple with 3 fields', async () => {
  //           returnData.length.should.be.eq(3)
  //         })
  //
  //         it('should return the correct number of events emitted', async () => {
  //           returnData[0].toNumber().should.be.eq(1)
  //         })
  //
  //         it('should return the correct number of addresses paid', async () => {
  //           returnData[1].toNumber().should.be.eq(0)
  //         })
  //
  //         it('should return the correct number of storage slots written to', async () => {
  //           returnData[2].toNumber().should.be.eq(1)
  //         })
  //       })
  //
  //       describe('exec events', async () => {
  //
  //         let appTopics
  //         let appData
  //         let execTopics
  //         let execData
  //
  //         beforeEach(async () => {
  //           appTopics = execEvents[0].topics
  //           appData = execEvents[0].data
  //           execTopics = execEvents[1].topics
  //           execData = execEvents[1].data
  //         })
  //
  //         it('should emit 2 events total', async () => {
  //           execEvents.length.should.be.eq(2)
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
  //             emittedExecId.should.be.eq(executionID)
  //           })
  //
  //           it('should match the targeted app address', async () => {
  //             let emittedAddr = execTopics[2]
  //             web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(target))
  //           })
  //
  //           it('should have an empty data field', async () => {
  //             execData.should.be.eq('0x0')
  //           })
  //         })
  //
  //         describe('the other event', async () => {
  //
  //           it('should have 1 topic', async () => {
  //             appTopics.length.should.be.eq(1)
  //           })
  //
  //           it('should have an empty data field', async () => {
  //             appData.should.be.eq('0x0')
  //           })
  //
  //           it('should match the topic sent', async () => {
  //             hexStrEquals(appTopics[0], emitTopics[0]).should.be.eq(true)
  //           })
  //         })
  //       })
  //
  //       describe('storage', async () => {
  //
  //         it('should have correctly stored the value at the location', async () => {
  //           let readValue = await storage.read.call(executionID, storageLocations[0])
  //           hexStrEquals(readValue, storageValues[0]).should.be.eq(true)
  //         })
  //       })
  //     })
  //
  //     describe('2 actions (PAYS 1, EMITS 1)', async () => {
  //
  //       let invalidCalldata
  //
  //       beforeEach(async () => {
  //         invalidCalldata = await appMockUtil.req3.call(
  //           payees[0], payouts[0], emitTopics[0]
  //         )
  //         invalidCalldata.should.not.eq('0x0')
  //       })
  //
  //       it('should throw', async () => {
  //         await storage.exec(
  //           target, executionID, invalidCalldata,
  //           { from: exec }
  //         ).should.not.be.fulfilled
  //       })
  //     })
  //
  //     describe('3 actions (PAYS 2, EMITS 1, THROWS)', async () => {
  //
  //       let invalidCalldata
  //
  //       beforeEach(async () => {
  //         invalidCalldata = await appMockUtil.reqs0.call(
  //           payees[0], payouts[0], payees[1], payouts[1],
  //           emitTopics[0], emitData1
  //         )
  //         invalidCalldata.should.not.eq('0x0')
  //       })
  //
  //       it('should throw', async () => {
  //         await storage.exec(
  //           target, executionID, invalidCalldata,
  //           { from: exec }
  //         ).should.not.be.fulfilled
  //       })
  //     })
  //
  //     describe('3 actions (EMITS 2, PAYS 1, STORES 2)', async () => {
  //
  //       let invalidCalldata
  //
  //       beforeEach(async () => {
  //         invalidCalldata = await appMockUtil.reqs1.call(
  //           payees[0], payouts[0], emitData1, emitData2,
  //           storageLocations[0], storageValues[0], storageLocations[1], storageValues[1]
  //         )
  //         invalidCalldata.should.not.eq('0x0')
  //       })
  //
  //       it('should throw', async () => {
  //         await storage.exec(
  //           target, executionID, invalidCalldata,
  //           { from: exec }
  //         ).should.not.be.fulfilled
  //       })
  //     })
  //
  //     describe('3 actions (PAYS 1, EMITS 3, STORES 1)', async () => {
  //
  //       let invalidCalldata
  //
  //       beforeEach(async () => {
  //         invalidCalldata = await appMockUtil.reqs2.call(
  //           payees[0], payouts[0], emitTopics, emitData1,
  //           storageLocations[0], storageValues[0]
  //         )
  //         invalidCalldata.should.not.eq('0x0')
  //       })
  //
  //       it('should throw', async () => {
  //         await storage.exec(
  //           target, executionID, invalidCalldata,
  //           { from: exec }
  //         ).should.not.be.fulfilled
  //       })
  //     })
  //
  //     describe('3 actions (STORES 2, PAYS 1, EMITS 1)', async () => {
  //
  //       let invalidCalldata
  //
  //       beforeEach(async () => {
  //         invalidCalldata = await appMockUtil.reqs3.call(
  //           payees[0], payouts[0], emitTopics[0], emitData1,
  //           storageLocations[0], storageValues[0], storageLocations[1], storageValues[1]
  //         )
  //         invalidCalldata.should.not.eq('0x0')
  //       })
  //
  //       it('should throw', async () => {
  //         await storage.exec(
  //           target, executionID, invalidCalldata,
  //           { from: exec }
  //         ).should.not.be.fulfilled
  //       })
  //     })
  //   })
  // })
  //
  // describe('#initAppInstance', async () => {
  //
  //   let executionID
  //
  //   beforeEach(async () => {
  //     let events = await storage.initAndFinalize(
  //       updater, false, appInit.address, initCalldata, allowedAddrs,
  //       { from: exec }
  //     ).should.be.fulfilled.then((tx) => {
  //       return tx.logs
  //     })
  //     events.should.not.eq(null)
  //     events.length.should.be.eq(2)
  //     events[0].event.should.be.eq('ApplicationInitialized')
  //     events[1].event.should.be.eq('ApplicationFinalization')
  //     executionID = events[1].args['execution_id']
  //     web3.toDecimal(executionID).should.not.eq(0)
  //   })
  //
  //   context('init function returns a value of inadequate size', async () => {
  //
  //     let invalidCalldata
  //
  //     beforeEach(async () => {
  //       invalidCalldata = await appInitUtil.initInvalid.call()
  //       invalidCalldata.should.not.eq('0x0')
  //     })
  //
  //     it('should throw', async () => {
  //       await storage.initAppInstance(
  //         updater, false, appInit.address, invalidCalldata, allowedAddrs,
  //         { from: exec }
  //       ).should.not.be.fulfilled
  //     })
  //   })
  //
  //   context('init function does not return an action', async () => {
  //
  //     let invalidCalldata
  //
  //     beforeEach(async () => {
  //       invalidCalldata = await appInitUtil.initNullAction.call()
  //       invalidCalldata.should.not.eq('0x0')
  //     })
  //
  //     it('should throw', async () => {
  //       await storage.initAppInstance(
  //         updater, false, appInit.address, invalidCalldata, allowedAddrs,
  //         { from: exec }
  //       ).should.not.be.fulfilled
  //     })
  //   })
  //
  //   context('init function returns a THROWS action', async () => {
  //
  //     let invalidCalldata
  //
  //     beforeEach(async () => {
  //       invalidCalldata = await appInitUtil.initThrowsAction.call()
  //       invalidCalldata.should.not.eq('0x0')
  //     })
  //
  //     it('should throw', async () => {
  //       await storage.initAppInstance(
  //         updater, false, appInit.address, invalidCalldata, allowedAddrs,
  //         { from: exec }
  //       ).should.not.be.fulfilled
  //     })
  //   })
  //
  //   context('init function returns an EMITS action', async () => {
  //
  //     let initCalldata
  //
  //     let returnedExecID
  //     let execEvents
  //
  //     beforeEach(async () => {
  //       initCalldata = await appInitUtil.initEmits.call(emitTopics[0])
  //       initCalldata.should.not.eq('0x0')
  //
  //       returnedExecID = await storage.initAppInstance.call(
  //         updater, false, appInit.address, initCalldata, allowedAddrs,
  //         { from: exec }
  //       ).should.be.fulfilled
  //
  //       execEvents = await storage.initAppInstance(
  //         updater, false, appInit.address, initCalldata, allowedAddrs,
  //         { from: exec }
  //       ).then((tx) => {
  //         return tx.receipt.logs
  //       })
  //     })
  //
  //     describe('exec events', async () => {
  //
  //       let appTopics
  //       let appData
  //       let execTopics
  //       let execData
  //
  //       beforeEach(async () => {
  //         appTopics = execEvents[0].topics
  //         appData = execEvents[0].data
  //         execTopics = execEvents[1].topics
  //         execData = execEvents[1].data
  //       })
  //
  //       it('should emit 2 events total', async () => {
  //         execEvents.length.should.be.eq(2)
  //       })
  //
  //       describe('the ApplicationInitialized event', async () => {
  //
  //         it('should have 3 topics', async () => {
  //           execTopics.length.should.be.eq(3)
  //         })
  //
  //         it('should have the event signature as the first topic', async () => {
  //           let sig = execTopics[0]
  //           web3.toBigNumber(sig).should.be.bignumber.eq(web3.toBigNumber(initHash))
  //         })
  //
  //         it('should match the used execution id', async () => {
  //           let emittedExecId = execTopics[1]
  //           emittedExecId.should.be.eq(returnedExecID)
  //         })
  //
  //         it('should match the app init address', async () => {
  //           let emittedAddr = execTopics[2]
  //           web3.toDecimal(emittedAddr).should.be.eq(web3.toDecimal(appInit.address))
  //         })
  //
  //         it('should have the script exec and updater addresses in the data field', async () => {
  //           let parsedInit = await appInitUtil.parseInit.call(execData)
  //           parsedInit[0].should.be.eq(exec)
  //           parsedInit[1].should.be.eq(updater)
  //         })
  //       })
  //
  //       describe('the other event', async () => {
  //
  //         it('should have 1 topic', async () => {
  //           appTopics.length.should.be.eq(1)
  //           hexStrEquals(appTopics[0], emitTopics[0]).should.be.eq(true)
  //         })
  //
  //         it('should have no data', async () => {
  //           appData.should.be.eq('0x0')
  //         })
  //       })
  //     })
  //
  //     it('should return a nonzero exec id', async () => {
  //       web3.toDecimal(returnedExecID).should.not.eq(0)
  //     })
  //
  //     describe('registered app info', async () => {
  //
  //       it('should return valid app info', async () => {
  //         let appInfo = await storage.app_info.call(returnedExecID)
  //         appInfo.length.should.be.eq(6)
  //         appInfo[0].should.be.eq(true)
  //         appInfo[1].should.be.eq(false)
  //         appInfo[2].should.be.eq(false)
  //         appInfo[3].should.be.eq(updater)
  //         appInfo[4].should.be.eq(exec)
  //         appInfo[5].should.be.eq(appInit.address)
  //       })
  //
  //       it('should return a correctly populated allowed address array', async () => {
  //         let allowedInfo = await storage.getExecAllowed.call(returnedExecID)
  //         allowedInfo.length.should.be.eq(allowedAddrs.length)
  //         allowedInfo.should.be.eql(allowedAddrs)
  //       })
  //     })
  //
  //     it('should not allow execution', async () => {
  //       await storage.exec(allowedAddrs[0], returnedExecID, stdAppCalldata, { from: exec }).should.not.be.fulfilled
  //     })
  //
  //     it('should not allow the updater address to unpause the application', async () => {
  //       await storage.pauseAppInstance(returnedExecID, { from: updater }).should.not.be.fulfilled
  //     })
  //   })
  //
  //   context('init function returns a PAYS action', async () => {
  //
  //     let initCalldata
  //
  //     beforeEach(async () => {
  //       initCalldata = await appInit.initPays.call(
  //         payees[0], payouts[0]
  //       )
  //       initCalldata.should.not.eq('0x0')
  //     })
  //
  //     it('should throw', async () => {
  //       await storage.initAppInstance(
  //         updater, false, appInit.address, initCalldata, allowedAddrs,
  //         { from: exec, value: payouts[0] }
  //       ).should.not.be.fulfilled
  //     })
  //   })
  //
  //   context('init function returns a STORES action', async () => {
  //
  //     let initCalldata
  //
  //     let returnedExecID
  //     let execEvents
  //
  //     beforeEach(async () => {
  //       initCalldata = await appInitUtil.initStores.call(
  //         storageLocations[0], storageValues[0]
  //       )
  //       initCalldata.should.not.eq('0x0')
  //
  //       returnedExecID = await storage.initAppInstance.call(
  //         updater, false, appInit.address, initCalldata, allowedAddrs,
  //         { from: exec }
  //       ).should.be.fulfilled
  //
  //       execEvents = await storage.initAppInstance(
  //         updater, false, appInit.address, initCalldata, allowedAddrs,
  //         { from: exec }
  //       ).then((tx) => {
  //         return tx.logs
  //       })
  //     })
  //
  //     describe('exec events', async () => {
  //
  //       let initEvent
  //
  //       beforeEach(async () => {
  //         initEvent = execEvents[0]
  //       })
  //
  //       it('should emit 1 event total', async () => {
  //         execEvents.length.should.be.eq(1)
  //       })
  //
  //       describe('the ApplicationInitialized event', async () => {
  //
  //         it('should be the correct event', async () => {
  //           initEvent.event.should.be.eq('ApplicationInitialized')
  //         })
  //
  //         it('should match the used execution id', async () => {
  //           let emittedExecId = initEvent.args['execution_id']
  //           emittedExecId.should.be.eq(returnedExecID)
  //         })
  //
  //         it('should match the app init address', async () => {
  //           let emittedAddr = initEvent.args['init_address']
  //           emittedAddr.should.be.eq(appInit.address)
  //         })
  //
  //         it('should have the script exec and updater addresses in the data field', async () => {
  //           let emittedExec = initEvent.args['script_exec']
  //           emittedExec.should.be.eq(exec)
  //           let emittedUpdater = initEvent.args['updater']
  //           emittedUpdater.should.be.eq(updater)
  //         })
  //       })
  //     })
  //
  //     it('should return a nonzero exec id', async () => {
  //       web3.toDecimal(returnedExecID).should.not.eq(0)
  //     })
  //
  //     describe('registered app info', async () => {
  //
  //       it('should return valid app info', async () => {
  //         let appInfo = await storage.app_info.call(returnedExecID)
  //         appInfo.length.should.be.eq(6)
  //         appInfo[0].should.be.eq(true)
  //         appInfo[1].should.be.eq(false)
  //         appInfo[2].should.be.eq(false)
  //         appInfo[3].should.be.eq(updater)
  //         appInfo[4].should.be.eq(exec)
  //         appInfo[5].should.be.eq(appInit.address)
  //       })
  //
  //       it('should return a correctly populated allowed address array', async () => {
  //         let allowedInfo = await storage.getExecAllowed.call(returnedExecID)
  //         allowedInfo.length.should.be.eq(allowedAddrs.length)
  //         allowedInfo.should.be.eql(allowedAddrs)
  //       })
  //     })
  //
  //     it('should not allow execution', async () => {
  //       await storage.exec(allowedAddrs[0], returnedExecID, stdAppCalldata, { from: exec }).should.not.be.fulfilled
  //     })
  //
  //     it('should not allow the updater address to unpause the application', async () => {
  //       await storage.pauseAppInstance(returnedExecID, { from: updater }).should.not.be.fulfilled
  //     })
  //
  //     it('should have stored the requested values', async () => {
  //       let readValue = await storage.read.call(returnedExecID, storageLocations[0])
  //       hexStrEquals(readValue, storageValues[0]).should.be.eq(true)
  //     })
  //   })
  // })

  // describe('#migrateApplication', async () => {
  //
  // })
  //
  // describe('#changeExec', async () => {
  //
  // })
  //
  // describe('#changeStorage', async () => {
  //
  // })
  //
  // describe('#changeUpdater', async () => {
  //
  // })
  //
  // describe('#changeAdmin', async () => {
  //
  // })
  //
  // describe('#changeProvider', async () => {
  //
  // })
  //
  // describe('#changeRegistryExecId', async () => {
  //
  // })
})
