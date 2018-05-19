let AbstractStorage = artifacts.require('./AbstractStorage')
// Mock
let AppInitMock = artifacts.require('./mock/AppInitMock')
let PayableApp = artifacts.require('./mock/PayableApp')
let StdApp = artifacts.require('./mock/StdApp')
let InvalidApp = artifacts.require('./mock/InvalidApp')
let RevertApp = artifacts.require('./mock/RevertApp')
// Util
let AppInitUtil = artifacts.require('./util/AppInitUtil')
let AppMockUtil = artifacts.require('./util/AppMockUtil')
let ViewBalance = artifacts.require('./util/ViewBalance')

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

async function getBalance(contract, owner) {
  let bal = await contract.viewOwnerBalance.call(owner).should.be.fulfilled
  return bal.toNumber()
}

contract('AbstractStorage', function (accounts) {

  let storage
  let exec = accounts[0]
  let updater = accounts[1]

  let payAmt = 555
  let payDest = accounts[2]

  let storageLocations = [
    web3.toHex('location A'),
    web3.toHex('location B')
  ]

  let storageValues = ['value A', 'value B']

  let revertMessage = 'appreverted'

  let otherAddr = accounts[accounts.length - 1]

  let appInit
  let appInitUtil
  let viewBalance

  let initCalldata

  let appMockUtil
  let payableApp
  let stdApp
  let invalidApp
  let revertApp

  let allowedAddrs

  let stdAppCalldata

  before(async () => {
    viewBalance = await ViewBalance.new().should.be.fulfilled

    storage = await AbstractStorage.new().should.be.fulfilled

    appInit = await AppInitMock.new().should.be.fulfilled
    appInitUtil = await AppInitUtil.new().should.be.fulfilled

    appMockUtil = await AppMockUtil.new().should.be.fulfilled
    payableApp = await PayableApp.new().should.be.fulfilled
    stdApp = await StdApp.new().should.be.fulfilled
    invalidApp = await InvalidApp.new().should.be.fulfilled
    revertApp = await RevertApp.new().should.be.fulfilled

    initCalldata = await appInitUtil.init.call().should.be.fulfilled
    initCalldata.should.not.eq('0x')

    allowedAddrs = [
      stdApp.address,
      payableApp.address,
      invalidApp.address,
      revertApp.address
    ]

    stdAppCalldata = []
    let cd = await appMockUtil.std1.call(storageLocations[0], storageValues[0])
    cd.should.not.eq('0x')
    stdAppCalldata.push(cd)
  })

  beforeEach(async () => {
    // Transfer funds from payDest to exec
    sendBalanceTo(payDest, exec)
    let bal = await getBalance(viewBalance, payDest)
    bal.should.be.eq(0)
  })

  describe('#exec - payable', async () => {

    let executionID

    beforeEach(async () => {
      // Transfer funds from payDest to exec
      sendBalanceTo(payDest, exec)
      let bal = await getBalance(viewBalance, payDest)
      bal.should.be.eq(0)

      let events = await storage.initAndFinalize(
        updater, true, appInit.address, initCalldata, allowedAddrs,
        { from: exec }
      ).should.be.fulfilled.then((tx) => {
        return tx.logs
      })
      events.should.not.eq(null)
      events.length.should.be.eq(2)
      events[0].event.should.be.eq('ApplicationInitialized')
      events[1].event.should.be.eq('ApplicationFinalization')
      executionID = events[0].args['execution_id']
      web3.toDecimal(executionID).should.not.eq(0)
    })

    describe('invalid inputs or invalid state', async () => {

      context('calldata is too short', async () => {

        let invalidCalldata = '0xabcd'

        it('should throw', async () => {
          await storage.exec(
            allowedAddrs[0], executionID, invalidCalldata,
            { from: exec }
          ).should.not.be.fulfilled
        })
      })

      context('target address is 0', async () => {

        let invalidAddr = zeroAddress()

        it('should throw', async () => {
          await storage.exec(
            invalidAddr, executionID, stdAppCalldata[0],
            { from: exec }
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

        let invalidTarget = otherAddr

        it('should throw', async () => {
          await storage.exec(
            invalidTarget, executionID, stdAppCalldata[0],
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

    describe('target application reverts (RevertApp tests)', async () => {

      let revertEvents
      let revertReturn

      context('function did not exist', async () => {

        let invalidCalldata

        beforeEach(async () => {
          invalidCalldata = await appMockUtil.rev0.call()
          invalidCalldata.should.not.eq('0x')

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
            revertReturn[0].should.be.eq(false)
            revertReturn[1].toNumber().should.be.eq(0)
            revertReturn[2].should.be.eq('0x')
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

      context('reverts with no message', async () => {

        beforeEach(async () => {
          let revertCalldata = await appMockUtil.rev1.call()
          revertCalldata.should.not.eq('0x')

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
            revertReturn[0].should.be.eq(false)
            revertReturn[1].toNumber().should.be.eq(0)
            revertReturn[2].should.be.eq('0x')
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

      context('reverts with message', async () => {

        beforeEach(async () => {
          let revertCalldata = await appMockUtil.rev2.call(revertMessage)
          revertCalldata.should.not.eq('0x')

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
            revertReturn[0].should.be.eq(false)
            revertReturn[1].toNumber().should.be.eq(0)
            revertReturn[2].should.be.eq('0x')
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
    })

    describe('target application returns malformed data', async () => {

      let target
      let calldata

      context('target is InvalidApp', async () => {

        beforeEach(async () => {
          target = invalidApp.address
        })

        describe('app attempts to pay storage contract', async () => {

          beforeEach(async () => {
            calldata = await appMockUtil.inv1.call(payAmt)
            calldata.should.not.eq('0x')
          })

          it('should throw', async () => {
            await storage.exec.call(
              target, executionID, calldata,
              { from: exec, value: payAmt }
            ).should.not.be.fulfilled
          })
        })

        describe('app pays no one and stores no data', async () => {

          beforeEach(async () => {
            calldata = await appMockUtil.inv2.call()
            calldata.should.not.eq('0x')
          })

          it('should throw', async () => {
            await storage.exec.call(
              target, executionID, calldata,
              { from: exec }
            ).should.not.be.fulfilled
          })
        })

        describe('app storage request has odd length', async () => {

          beforeEach(async () => {
            calldata = await appMockUtil.inv3.call()
            calldata.should.not.eq('0x')
          })

          it('should throw', async () => {
            await storage.exec.call(
              target, executionID, calldata,
              { from: exec }
            ).should.not.be.fulfilled
          })
        })

        describe('app storage request not divisible by 64 bytes', async () => {

          beforeEach(async () => {
            calldata = await appMockUtil.inv4.call()
            calldata.should.not.eq('0x')
          })

          it('should throw', async () => {
            await storage.exec.call(
              target, executionID, calldata,
              { from: exec }
            ).should.not.be.fulfilled
          })
        })

        describe('app storage request length under 128 bytes', async () => {

          beforeEach(async () => {
            calldata = await appMockUtil.inv5.call()
            calldata.should.not.eq('0x')
          })

          it('should throw', async () => {
            await storage.exec.call(
              target, executionID, calldata,
              { from: exec }
            ).should.not.be.fulfilled
          })
        })
      })
    })

    describe('target application returns well-formed data', async () => {

      let target
      let calldata
      let returnData
      let execEvents

      context('target is StdApp', async () => {

        beforeEach(async () => {
          // Transfer funds from payDest to exec
          sendBalanceTo(payDest, exec)
          let bal = await getBalance(viewBalance, payDest)
          bal.should.be.eq(0)

          target = stdApp.address
        })

        describe('store to one slot', async () => {

          beforeEach(async () => {
            calldata = await appMockUtil.std1.call(storageLocations[0], storageValues[0])
            calldata.should.not.eq('0x')

            returnData = await storage.exec.call(
              target, executionID, calldata,
              { from: exec, value: payAmt }
            ).should.be.fulfilled

            execEvents = await storage.exec(
              target, executionID, calldata,
              { from: exec, value: payAmt }
            ).should.be.fulfilled.then((tx) => {
              return tx.logs
            })
          })

          describe('returned data', async () => {

            it('should return a tuple with 3 fields', async () => {
              returnData.length.should.be.eq(3)
            })

            it('should return success', async () => {
              returnData[0].should.be.eq(true)
            })

            it('should return the correct amount written', async () => {
              returnData[1].toNumber().should.be.eq(1)
            })

            it('should return an empty bytes array', async () => {
              let parsedReturn = await appMockUtil.parsePayable.call(returnData[2]).should.be.fulfilled
              parsedReturn.length.should.be.eq(3)
              parsedReturn[0].toNumber().should.be.eq(64)
              parsedReturn[1].toNumber().should.be.eq(0)
              web3.toDecimal(parsedReturn[2]).should.be.eq(0)
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
              hexStrEquals(readValue, storageValues[0])
                .should.be.eq(true, "val read:" + readValue)
            })
          })
        })

        describe('store to 2 slots', async () => {

          beforeEach(async () => {
            calldata = await appMockUtil.std2.call(
              storageLocations[0], storageValues[0], storageLocations[1], storageValues[1]
            )
            calldata.should.not.eq('0x')

            returnData = await storage.exec.call(
              target, executionID, calldata,
              { from: exec, value: payAmt }
            ).should.be.fulfilled

            execEvents = await storage.exec(
              target, executionID, calldata,
              { from: exec, value: payAmt }
            ).should.be.fulfilled.then((tx) => {
              return tx.logs
            })
          })

          describe('returned data', async () => {

            it('should return a tuple with 3 fields', async () => {
              returnData.length.should.be.eq(3)
            })

            it('should return success', async () => {
              returnData[0].should.be.eq(true)
            })

            it('should return the correct amount written', async () => {
              returnData[1].toNumber().should.be.eq(2)
            })

            it('should return an empty bytes array', async () => {
              let parsedReturn = await appMockUtil.parsePayable.call(returnData[2]).should.be.fulfilled
              parsedReturn.length.should.be.eq(3)
              parsedReturn[0].toNumber().should.be.eq(64)
              parsedReturn[1].toNumber().should.be.eq(0)
              web3.toDecimal(parsedReturn[2]).should.be.eq(0)
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
              hexStrEquals(readValue, storageValues[0])
                .should.be.eq(true, "val read:" + readValue)
            })

            it('should have correctly stored the value at the second location', async () => {
              let readValue = await storage.read.call(executionID, storageLocations[1])
              hexStrEquals(readValue, storageValues[1])
                .should.be.eq(true, "val read:" + readValue)
            })
          })
        })

      })

      context('target is PayableApp', async () => {

        beforeEach(async () => {
          // Transfer funds from payDest to exec
          sendBalanceTo(payDest, exec)
          let bal = await getBalance(viewBalance, payDest)
          bal.should.be.eq(0)

          target = payableApp.address
        })

        describe('payment without storage', async () => {

          beforeEach(async () => {
            calldata = await appMockUtil.pay1.call(payDest, payAmt)
            calldata.should.not.eq('0x')

            returnData = await storage.exec.call(
              target, executionID, calldata,
              { from: exec, value: payAmt }
            ).should.be.fulfilled

            execEvents = await storage.exec(
              target, executionID, calldata,
              { from: exec, value: payAmt }
            ).should.be.fulfilled.then((tx) => {
              return tx.logs
            })
          })

          describe('returned data', async () => {

            it('should return a tuple with 3 fields', async () => {
              returnData.length.should.be.eq(3)
            })

            it('should return success', async () => {
              returnData[0].should.be.eq(true)
            })

            it('should return the correct amount written', async () => {
              returnData[1].toNumber().should.be.eq(0)
            })

            it('should return a bytes array populated with payment destination and send amount', async () => {
              let parsedReturn = await appMockUtil.parsePayable.call(returnData[2]).should.be.fulfilled
              parsedReturn.length.should.be.eq(3)
              parsedReturn[0].toNumber().should.be.eq(64)
              parsedReturn[1].toNumber().should.be.eq(payAmt)
              parsedReturn[2].should.be.eq(payDest)
            })
          })

          describe('exec events', async () => {

            it('should emit an ApplicationExecution event and a DeliveredPayment event', async () => {
              execEvents.length.should.be.eq(2)
              execEvents[0].event.should.be.eq('DeliveredPayment')
              execEvents[1].event.should.be.eq('ApplicationExecution')
            })

            it('both events should match the used execution id', async () => {
              let emittedExecId = execEvents[0].args['execution_id']
              emittedExecId.should.be.eq(executionID)
              emittedExecId = execEvents[1].args['execution_id']
              emittedExecId.should.be.eq(executionID)
            })

            it('the ApplicationExecution event should match the targeted app address', async () => {
              let emittedAddr = execEvents[1].args['script_target']
              emittedAddr.should.be.eq(target)
            })

            it('the DeliveredPayment event should match the destination and amoutn sent', async () => {
              let dest = execEvents[0].args['destination']
              dest.should.be.eq(payDest)
              let amtSend = execEvents[0].args['amount']
              amtSend.toNumber().should.be.eq(payAmt)
            })
          })

          describe('payment', async () => {

            it('should have paid the amount to the requested destination', async () => {
              let bal = await getBalance(viewBalance, payDest)
              bal.should.be.eq(payAmt)
            })
          })
        })

        describe('store to one slot', async () => {

          beforeEach(async () => {
            calldata = await appMockUtil.pay2.call(
              payDest, payAmt, storageLocations[0], storageValues[0]
            )
            calldata.should.not.eq('0x')

            returnData = await storage.exec.call(
              target, executionID, calldata,
              { from: exec, value: payAmt }
            ).should.be.fulfilled

            execEvents = await storage.exec(
              target, executionID, calldata,
              { from: exec, value: payAmt }
            ).should.be.fulfilled.then((tx) => {
              return tx.logs
            })
          })

          describe('returned data', async () => {

            it('should return a tuple with 3 fields', async () => {
              returnData.length.should.be.eq(3)
            })

            it('should return success', async () => {
              returnData[0].should.be.eq(true)
            })

            it('should return the correct amount written', async () => {
              returnData[1].toNumber().should.be.eq(1)
            })

            it('should return a bytes array populated with payment destination and send amount', async () => {
              let parsedReturn = await appMockUtil.parsePayable.call(returnData[2]).should.be.fulfilled
              parsedReturn.length.should.be.eq(3)
              parsedReturn[0].toNumber().should.be.eq(64)
              parsedReturn[1].toNumber().should.be.eq(payAmt)
              parsedReturn[2].should.be.eq(payDest)
            })
          })

          describe('exec events', async () => {

            it('should emit an ApplicationExecution event and a DeliveredPayment event', async () => {
              execEvents.length.should.be.eq(2)
              execEvents[0].event.should.be.eq('DeliveredPayment')
              execEvents[1].event.should.be.eq('ApplicationExecution')
            })

            it('both events should match the used execution id', async () => {
              let emittedExecId = execEvents[0].args['execution_id']
              emittedExecId.should.be.eq(executionID)
              emittedExecId = execEvents[1].args['execution_id']
              emittedExecId.should.be.eq(executionID)
            })

            it('the ApplicationExecution event should match the targeted app address', async () => {
              let emittedAddr = execEvents[1].args['script_target']
              emittedAddr.should.be.eq(target)
            })

            it('the DeliveredPayment event should match the destination and amoutn sent', async () => {
              let dest = execEvents[0].args['destination']
              dest.should.be.eq(payDest)
              let amtSend = execEvents[0].args['amount']
              amtSend.toNumber().should.be.eq(payAmt)
            })
          })

          describe('storage', async () => {

            it('should not have stored to the payment destination', async () => {
              let readValue = await storage.read.call(executionID, payDest)
              web3.toDecimal(readValue).should.be.eq(0)
            })

            it('should have correctly stored the value at the location', async () => {
              let readValue = await storage.read.call(executionID, storageLocations[0])
              hexStrEquals(readValue, storageValues[0])
                .should.be.eq(true, "val read:" + readValue)
            })
          })

          describe('payment', async () => {

            it('should have paid the amount to the requested destination', async () => {
              let bal = await getBalance(viewBalance, payDest)
              bal.should.be.eq(payAmt)
            })
          })
        })

        describe('store to 2 slots', async () => {

          beforeEach(async () => {
            calldata = await appMockUtil.pay3.call(
              payDest, payAmt,
              storageLocations[0], storageValues[0],
              storageLocations[1], storageValues[1]
            )
            calldata.should.not.eq('0x')

            returnData = await storage.exec.call(
              target, executionID, calldata,
              { from: exec, value: payAmt }
            ).should.be.fulfilled

            execEvents = await storage.exec(
              target, executionID, calldata,
              { from: exec, value: payAmt }
            ).should.be.fulfilled.then((tx) => {
              return tx.logs
            })
          })

          describe('returned data', async () => {

            it('should return a tuple with 3 fields', async () => {
              returnData.length.should.be.eq(3)
            })

            it('should return success', async () => {
              returnData[0].should.be.eq(true)
            })

            it('should return the correct amount written', async () => {
              returnData[1].toNumber().should.be.eq(2)
            })

            it('should return a bytes array populated with payment destination and send amount', async () => {
              let parsedReturn = await appMockUtil.parsePayable.call(returnData[2]).should.be.fulfilled
              parsedReturn.length.should.be.eq(3)
              parsedReturn[0].toNumber().should.be.eq(64)
              parsedReturn[1].toNumber().should.be.eq(payAmt)
              parsedReturn[2].should.be.eq(payDest)
            })
          })

          describe('exec events', async () => {

            it('should emit an ApplicationExecution event and a DeliveredPayment event', async () => {
              execEvents.length.should.be.eq(2)
              execEvents[0].event.should.be.eq('DeliveredPayment')
              execEvents[1].event.should.be.eq('ApplicationExecution')
            })

            it('both events should match the used execution id', async () => {
              let emittedExecId = execEvents[0].args['execution_id']
              emittedExecId.should.be.eq(executionID)
              emittedExecId = execEvents[1].args['execution_id']
              emittedExecId.should.be.eq(executionID)
            })

            it('the ApplicationExecution event should match the targeted app address', async () => {
              let emittedAddr = execEvents[1].args['script_target']
              emittedAddr.should.be.eq(target)
            })

            it('the DeliveredPayment event should match the destination and amoutn sent', async () => {
              let dest = execEvents[0].args['destination']
              dest.should.be.eq(payDest)
              let amtSend = execEvents[0].args['amount']
              amtSend.toNumber().should.be.eq(payAmt)
            })
          })

          describe('storage', async () => {

            it('should not have stored to the payment destination', async () => {
              let readValue = await storage.read.call(executionID, payDest)
              web3.toDecimal(readValue).should.be.eq(0)
            })

            it('should have correctly stored the value at the first location', async () => {
              let readValue = await storage.read.call(executionID, storageLocations[0])
              hexStrEquals(readValue, storageValues[0])
                .should.be.eq(true, "val read:" + readValue)
            })

            it('should have correctly stored the value at the second location', async () => {
              let readValue = await storage.read.call(executionID, storageLocations[1])
              hexStrEquals(readValue, storageValues[1])
                .should.be.eq(true, "val read:" + readValue)
            })
          })

          describe('payment', async () => {

            it('should have paid the amount to the requested destination', async () => {
              let bal = await getBalance(viewBalance, payDest)
              bal.should.be.eq(payAmt)
            })
          })
        })
      })
    })
  })

  describe('#exec - nonpayable', async () => {

    let executionID

    beforeEach(async () => {
      let events = await storage.initAndFinalize(
        updater, false, appInit.address, initCalldata, allowedAddrs,
        { from: exec }
      ).should.be.fulfilled.then((tx) => {
        return tx.logs
      })
      events.should.not.eq(null)
      events.length.should.be.eq(2)
      events[0].event.should.be.eq('ApplicationInitialized')
      events[1].event.should.be.eq('ApplicationFinalization')
      executionID = events[0].args['execution_id']
      web3.toDecimal(executionID).should.not.eq(0)
    })

    describe('invalid inputs or invalid state', async () => {

      context('calldata is too short', async () => {

        let invalidCalldata = '0xabcd'

        it('should throw', async () => {
          await storage.exec(
            allowedAddrs[0], executionID, invalidCalldata,
            { from: exec }
          ).should.not.be.fulfilled
        })
      })

      context('target address is 0', async () => {

        let invalidAddr = zeroAddress()

        it('should throw', async () => {
          await storage.exec(
            invalidAddr, executionID, stdAppCalldata[0],
            { from: exec }
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

      context('ether sent to non-payable app', async () => {

        it('should throw', async () => {
          await storage.exec(
            stdApp.address, executionID, stdAppCalldata[0],
            { from: exec, value: 1 }
          ).should.not.be.fulfilled
        })
      })

      context('script target not in exec id allowed list', async () => {

        let invalidTarget = otherAddr

        it('should throw', async () => {
          await storage.exec(
            invalidTarget, executionID, stdAppCalldata[0],
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

    describe('target application reverts (RevertApp tests)', async () => {

      let revertEvents
      let revertReturn

      context('function did not exist', async () => {

        let invalidCalldata

        beforeEach(async () => {
          invalidCalldata = await appMockUtil.rev0.call()
          invalidCalldata.should.not.eq('0x')

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
            revertReturn[0].should.be.eq(false)
            revertReturn[1].toNumber().should.be.eq(0)
            revertReturn[2].should.be.eq('0x')
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

      context('reverts with no message', async () => {

        beforeEach(async () => {
          let revertCalldata = await appMockUtil.rev1.call()
          revertCalldata.should.not.eq('0x')

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
            revertReturn[0].should.be.eq(false)
            revertReturn[1].toNumber().should.be.eq(0)
            revertReturn[2].should.be.eq('0x')
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

      context('reverts with message', async () => {

        beforeEach(async () => {
          let revertCalldata = await appMockUtil.rev2.call(revertMessage)
          revertCalldata.should.not.eq('0x')

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
            revertReturn[0].should.be.eq(false)
            revertReturn[1].toNumber().should.be.eq(0)
            revertReturn[2].should.be.eq('0x')
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
    })

    describe('target application returns malformed data', async () => {

      let target
      let calldata

      context('target is InvalidApp', async () => {

        beforeEach(async () => {
          target = invalidApp.address
        })

        describe('app attempts to pay storage contract', async () => {

          beforeEach(async () => {
            calldata = await appMockUtil.inv1.call(payAmt)
            calldata.should.not.eq('0x')
          })

          it('should throw', async () => {
            await storage.exec.call(
              target, executionID, calldata,
              { from: exec }
            ).should.not.be.fulfilled
          })
        })

        describe('app pays no one and stores no data', async () => {

          beforeEach(async () => {
            calldata = await appMockUtil.inv2.call()
            calldata.should.not.eq('0x')
          })

          it('should throw', async () => {
            await storage.exec.call(
              target, executionID, calldata,
              { from: exec }
            ).should.not.be.fulfilled
          })
        })

        describe('app storage request has odd length', async () => {

          beforeEach(async () => {
            calldata = await appMockUtil.inv3.call()
            calldata.should.not.eq('0x')
          })

          it('should throw', async () => {
            await storage.exec.call(
              target, executionID, calldata,
              { from: exec }
            ).should.not.be.fulfilled
          })
        })

        describe('app storage request not divisible by 64 bytes', async () => {

          beforeEach(async () => {
            calldata = await appMockUtil.inv4.call()
            calldata.should.not.eq('0x')
          })

          it('should throw', async () => {
            await storage.exec.call(
              target, executionID, calldata,
              { from: exec }
            ).should.not.be.fulfilled
          })
        })

        describe('app storage request length under 128 bytes', async () => {

          beforeEach(async () => {
            calldata = await appMockUtil.inv5.call()
            calldata.should.not.eq('0x')
          })

          it('should throw', async () => {
            await storage.exec.call(
              target, executionID, calldata,
              { from: exec }
            ).should.not.be.fulfilled
          })
        })
      })
    })

    describe('target application returns well-formed data', async () => {

      let target
      let calldata
      let returnData
      let execEvents

      context('target is StdApp', async () => {

        beforeEach(async () => {
          target = stdApp.address
        })

        describe('store to one slot', async () => {

          beforeEach(async () => {
            calldata = await appMockUtil.std1.call(storageLocations[0], storageValues[0])
            calldata.should.not.eq('0x')

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

            it('should return success', async () => {
              returnData[0].should.be.eq(true)
            })

            it('should return the correct amount written', async () => {
              returnData[1].toNumber().should.be.eq(1)
            })

            it('should return an empty bytes array', async () => {
              returnData[2].should.be.eq('0x')
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
              hexStrEquals(readValue, storageValues[0])
                .should.be.eq(true, "val read:" + readValue)
            })
          })
        })

        describe('store to 2 slots', async () => {

          beforeEach(async () => {
            calldata = await appMockUtil.std2.call(
              storageLocations[0], storageValues[0], storageLocations[1], storageValues[1]
            )
            calldata.should.not.eq('0x')

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

            it('should return success', async () => {
              returnData[0].should.be.eq(true)
            })

            it('should return the correct amount written', async () => {
              returnData[1].toNumber().should.be.eq(2)
            })

            it('should return an empty bytes array', async () => {
              returnData[2].should.be.eq('0x')
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
              hexStrEquals(readValue, storageValues[0])
                .should.be.eq(true, "val read:" + readValue)
            })

            it('should have correctly stored the value at the second location', async () => {
              let readValue = await storage.read.call(executionID, storageLocations[1])
              hexStrEquals(readValue, storageValues[1])
                .should.be.eq(true, "val read:" + readValue)
            })
          })
        })

      })

      context('target is PayableApp', async () => {

        beforeEach(async () => {
          target = payableApp.address
        })

        describe('payment without storage', async () => {

          let invalidCalldata

          beforeEach(async () => {
            invalidCalldata = await appMockUtil.pay1.call(payDest, payAmt)
            invalidCalldata.should.not.eq('0x')
          })

          it('should throw', async () => {
            await storage.exec(
              target, executionID, invalidCalldata,
              { from: exec }
            ).should.not.be.fulfilled
          })
        })

        describe('store to one slot', async () => {

          beforeEach(async () => {
            calldata = await appMockUtil.pay2.call(
              payDest, payAmt, storageLocations[0], storageValues[0]
            )
            calldata.should.not.eq('0x')

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

            it('should return success', async () => {
              returnData[0].should.be.eq(true)
            })

            it('should return the correct amount written', async () => {
              returnData[1].toNumber().should.be.eq(1)
            })

            it('should return an empty bytes array', async () => {
              returnData[2].should.be.eq('0x')
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

            it('should not have stored to the payment destination', async () => {
              let readValue = await storage.read.call(executionID, payDest)
              web3.toDecimal(readValue).should.be.eq(0)
            })

            it('should have correctly stored the value at the location', async () => {
              let readValue = await storage.read.call(executionID, storageLocations[0])
              hexStrEquals(readValue, storageValues[0])
                .should.be.eq(true, "val read:" + readValue)
            })
          })

          describe('payment', async () => {

            it('should not have paid the requested destination', async () => {
              let bal = await getBalance(viewBalance, payDest)
              bal.should.be.eq(0)
            })
          })
        })

        describe('store to 2 slots', async () => {

          beforeEach(async () => {
            calldata = await appMockUtil.pay3.call(
              payDest, payAmt,
              storageLocations[0], storageValues[0],
              storageLocations[1], storageValues[1]
            )
            calldata.should.not.eq('0x')

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

            it('should return success', async () => {
              returnData[0].should.be.eq(true)
            })

            it('should return the correct amount written', async () => {
              returnData[1].toNumber().should.be.eq(2)
            })

            it('should return an empty bytes array', async () => {
              returnData[2].should.be.eq('0x')
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

            it('should not have stored to the payment destination', async () => {
              let readValue = await storage.read.call(executionID, payDest)
              web3.toDecimal(readValue).should.be.eq(0)
            })

            it('should have correctly stored the value at the first location', async () => {
              let readValue = await storage.read.call(executionID, storageLocations[0])
              hexStrEquals(readValue, storageValues[0])
                .should.be.eq(true, "val read:" + readValue)
            })

            it('should have correctly stored the value at the second location', async () => {
              let readValue = await storage.read.call(executionID, storageLocations[1])
              hexStrEquals(readValue, storageValues[1])
                .should.be.eq(true, "val read:" + readValue)
            })
          })

          describe('payment', async () => {

            it('should not have paid the requested destination', async () => {
              let bal = await getBalance(viewBalance, payDest)
              bal.should.be.eq(0)
            })
          })
        })
      })
    })
  })

  describe('#initAppInstance', async () => {

    context('init function returns invalid storage request', async () => {

      let invalidCalldata

      beforeEach(async () => {
        invalidCalldata = await appInitUtil.initInvalid.call()
        invalidCalldata.should.not.eq('0x')
      })

      it('should throw', async () => {
        await storage.initAppInstance(
          updater, false, appInit.address, invalidCalldata, allowedAddrs,
          { from: exec }
        ).should.not.be.fulfilled
      })
    })

    context('init function returns no storage request', async () => {

      let initCalldata

      let returnedExecID
      let initEvent

      beforeEach(async () => {
        initCalldata = await appInitUtil.init.call()
        initCalldata.should.not.eq('0x')

        returnedExecID = await storage.initAppInstance.call(
          updater, false, appInit.address, initCalldata, allowedAddrs,
          { from: exec }
        ).should.be.fulfilled

        let events = await storage.initAppInstance(
          updater, false, appInit.address, initCalldata, allowedAddrs,
          { from: exec }
        ).then((tx) => {
          return tx.logs
        })
        events.should.not.eq(null)
        events.length.should.be.eq(1)
        initEvent = events[0]
      })

      it('should return a nonzero exec id', async () => {
        web3.toDecimal(returnedExecID).should.not.eq(0)
      })

      it('should emit an ApplicationInitialized event', async () => {
        initEvent.event.should.be.eq('ApplicationInitialized')
      })

      describe('the ApplicationInitialized event', async () => {

        it('should match the returned exec id', async () => {
          initEvent.args['execution_id'].should.be.eq(returnedExecID)
        })

        it('should match the correct init address', async () => {
          let emittedInitAddr = initEvent.args['init_address']
          emittedInitAddr.should.be.eq(appInit.address)
        })

        it('should match the script exec address', async () => {
          let emittedExec = initEvent.args['script_exec']
          emittedExec.should.be.eq(exec)
        })

        it('should match the updater address', async () => {
          let emittedUpdater = initEvent.args['updater']
          emittedUpdater.should.be.eq(updater)
        })
      })

      describe('registered app info', async () => {

        it('should return valid app info', async () => {
          let appInfo = await storage.app_info.call(returnedExecID)
          appInfo.length.should.be.eq(6)
          appInfo[0].should.be.eq(true)
          appInfo[1].should.be.eq(false)
          appInfo[2].should.be.eq(false)
          appInfo[3].should.be.eq(updater)
          appInfo[4].should.be.eq(exec)
          appInfo[5].should.be.eq(appInit.address)
        })

        it('should return a correctly populated allowed address array', async () => {
          let allowedInfo = await storage.getExecAllowed.call(returnedExecID)
          allowedInfo.length.should.be.eq(4)
          allowedInfo.should.be.eql(allowedAddrs)
        })
      })

      it('should not allow execution', async () => {
        await storage.exec(allowedAddrs[0], returnedExecID, stdAppCalldata).should.not.be.fulfilled
      })

      it('should not allow the updater address to unpause the application', async () => {
        await storage.pauseAppInstance(returnedExecID).should.not.be.fulfilled
      })
    })

    context('init function returns only payment information', async () => {

      let initCalldata

      beforeEach(async () => {
        initCalldata = await appInitUtil.initPayment.call()
        initCalldata.should.not.eq('0x')
      })

      it('should throw', async () => {
        await storage.initAppInstance(
          updater, false, appInit.address, initCalldata, allowedAddrs,
          { from: exec }
        ).should.not.be.fulfilled
      })
    })

    context('init function returns storage request', async () => {

      context('storing data to 1 slot', async () => {

        let initCalldata

        let returnedExecID
        let initEvent

        beforeEach(async () => {
          initCalldata = await appInitUtil.initValidSingle.call(
            storageLocations[0], storageValues[0]
          )
          initCalldata.should.not.eq('0x')

          returnedExecID = await storage.initAppInstance.call(
            updater, false, appInit.address, initCalldata, allowedAddrs,
            { from: exec }
          ).should.be.fulfilled

          let events = await storage.initAppInstance(
            updater, false, appInit.address, initCalldata, allowedAddrs,
            { from: exec }
          ).then((tx) => {
            return tx.logs
          })
          events.should.not.eq(null)
          events.length.should.be.eq(1)
          initEvent = events[0]
        })

        it('should return a nonzero exec id', async () => {
          web3.toDecimal(returnedExecID).should.not.eq(0)
        })

        it('should emit an ApplicationInitialized event', async () => {
          initEvent.event.should.be.eq('ApplicationInitialized')
        })

        describe('the ApplicationInitialized event', async () => {

          it('should match the returned exec id', async () => {
            initEvent.args['execution_id'].should.be.eq(returnedExecID)
          })

          it('should match the correct init address', async () => {
            let emittedInitAddr = initEvent.args['init_address']
            emittedInitAddr.should.be.eq(appInit.address)
          })

          it('should match the script exec address', async () => {
            let emittedExec = initEvent.args['script_exec']
            emittedExec.should.be.eq(exec)
          })

          it('should match the updater address', async () => {
            let emittedUpdater = initEvent.args['updater']
            emittedUpdater.should.be.eq(updater)
          })
        })

        describe('registered app info', async () => {

          it('should return valid app info', async () => {
            let appInfo = await storage.app_info.call(returnedExecID)
            appInfo.length.should.be.eq(6)
            appInfo[0].should.be.eq(true)
            appInfo[1].should.be.eq(false)
            appInfo[2].should.be.eq(false)
            appInfo[3].should.be.eq(updater)
            appInfo[4].should.be.eq(exec)
            appInfo[5].should.be.eq(appInit.address)
          })

          it('should return a correctly populated allowed address array', async () => {
            let allowedInfo = await storage.getExecAllowed.call(returnedExecID)
            allowedInfo.length.should.be.eq(4)
            allowedInfo.should.be.eql(allowedAddrs)
          })
        })

        it('should not allow execution', async () => {
          await storage.exec(allowedAddrs[0], returnedExecID, stdAppCalldata).should.not.be.fulfilled
        })

        it('should not allow the updater address to unpause the application', async () => {
          await storage.pauseAppInstance(returnedExecID).should.not.be.fulfilled
        })

        describe('storage', async () => {

          it('should have correctly stored the value at the location', async () => {
            let readValue = await storage.read.call(returnedExecID, storageLocations[0])
            hexStrEquals(readValue, storageValues[0])
              .should.be.eq(true, "val read:" + readValue)
          })
        })
      })

      context('storing data to 2 slots', async () => {

        let initCalldata

        let returnedExecID
        let initEvent

        beforeEach(async () => {
          initCalldata = await appInitUtil.initValidMulti.call(
            storageLocations[0], storageValues[0], storageLocations[1], storageValues[1]
          )
          initCalldata.should.not.eq('0x')

          returnedExecID = await storage.initAppInstance.call(
            updater, false, appInit.address, initCalldata, allowedAddrs,
            { from: exec }
          ).should.be.fulfilled

          let events = await storage.initAppInstance(
            updater, false, appInit.address, initCalldata, allowedAddrs,
            { from: exec }
          ).then((tx) => {
            return tx.logs
          })
          events.should.not.eq(null)
          events.length.should.be.eq(1)
          initEvent = events[0]
        })

        it('should return a nonzero exec id', async () => {
          web3.toDecimal(returnedExecID).should.not.eq(0)
        })

        it('should emit an ApplicationInitialized event', async () => {
          initEvent.event.should.be.eq('ApplicationInitialized')
        })

        describe('the ApplicationInitialized event', async () => {

          it('should match the returned exec id', async () => {
            initEvent.args['execution_id'].should.be.eq(returnedExecID)
          })

          it('should match the correct init address', async () => {
            let emittedInitAddr = initEvent.args['init_address']
            emittedInitAddr.should.be.eq(appInit.address)
          })

          it('should match the script exec address', async () => {
            let emittedExec = initEvent.args['script_exec']
            emittedExec.should.be.eq(exec)
          })

          it('should match the updater address', async () => {
            let emittedUpdater = initEvent.args['updater']
            emittedUpdater.should.be.eq(updater)
          })
        })

        describe('registered app info', async () => {

          it('should return valid app info', async () => {
            let appInfo = await storage.app_info.call(returnedExecID)
            appInfo.length.should.be.eq(6)
            appInfo[0].should.be.eq(true)
            appInfo[1].should.be.eq(false)
            appInfo[2].should.be.eq(false)
            appInfo[3].should.be.eq(updater)
            appInfo[4].should.be.eq(exec)
            appInfo[5].should.be.eq(appInit.address)
          })

          it('should return a correctly populated allowed address array', async () => {
            let allowedInfo = await storage.getExecAllowed.call(returnedExecID)
            allowedInfo.length.should.be.eq(4)
            allowedInfo.should.be.eql(allowedAddrs)
          })
        })

        it('should not allow execution', async () => {
          await storage.exec(allowedAddrs[0], returnedExecID, stdAppCalldata).should.not.be.fulfilled
        })

        it('should not allow the updater address to unpause the application', async () => {
          await storage.pauseAppInstance(returnedExecID).should.not.be.fulfilled
        })

        describe('storage', async () => {

          it('should have correctly stored the value at the first location', async () => {
            let readValue = await storage.read.call(returnedExecID, storageLocations[0])
            hexStrEquals(readValue, storageValues[0])
              .should.be.eq(true, "val read:" + readValue)
          })

          it('should have correctly stored the value at the second location', async () => {
            let readValue = await storage.read.call(returnedExecID, storageLocations[1])
            hexStrEquals(readValue, storageValues[1])
              .should.be.eq(true, "val read:" + readValue)
          })
        })
      })
    })
  })

  describe('#finalizeAppInstance', async () => {

    let initCalldata

    let returnedExecID
    let initEvent

    beforeEach(async () => {
      initCalldata = await appInitUtil.init.call()
      initCalldata.should.not.eq('0x')

      returnedExecID = await storage.initAppInstance.call(
        updater, false, appInit.address, initCalldata, allowedAddrs,
        { from: exec }
      ).should.be.fulfilled

      let events = await storage.initAppInstance(
        updater, false, appInit.address, initCalldata, allowedAddrs,
        { from: exec }
      ).then((tx) => {
        return tx.logs
      })
      events.should.not.eq(null)
      events.length.should.be.eq(1)
      initEvent = events[0]
    })

    context('when the sender is not the script exec', async () => {

      it('should throw', async () => {
        await storage.finalizeAppInstance(
          returnedExecID, { from: updater }
        ).should.not.be.fulfilled
      })
    })

    context('when the exec id does not exist', async () => {

      it('should throw', async () => {
        await storage.finalizeAppInstance(
          '0xa', { from: exec }
        ).should.not.be.fulfilled
      })
    })

    context('when the app is already finalized', async () => {

      beforeEach(async () => {
        await storage.finalizeAppInstance(
          returnedExecID, { from: exec }
        ).should.be.fulfilled
      })

      it('should throw', async () => {
        await storage.finalizeAppInstance(
          returnedExecID, { from: exec }
        ).should.not.be.fulfilled
      })
    })

    context('when the app is in a valid state to be finalized and the sender is exec', async () => {

      let finalEvent

      beforeEach(async () => {
        let events = await storage.finalizeAppInstance(
          returnedExecID, { from: exec }
        ).then((tx) => {
          return tx.logs
        })
        events.should.not.eq(null)
        events.length.should.be.eq(1)
        finalEvent = events[0]
      })

      it('should emit an ApplicationFinalization event', async () => {
        finalEvent.event.should.be.eq('ApplicationFinalization')
      })

      describe('the ApplicationFinalization event', async () => {

        it('should match the returned exec id', async () => {
          finalEvent.args['execution_id'].should.be.eq(returnedExecID)
        })

        it('should match the correct init address', async () => {
          let emittedInitAddr = finalEvent.args['init_address']
          emittedInitAddr.should.be.eq(appInit.address)
        })
      })

      describe('registered app info', async () => {

        it('should return valid app info', async () => {
          let appInfo = await storage.app_info.call(returnedExecID)
          appInfo.length.should.be.eq(6)
          appInfo[0].should.be.eq(false)
          appInfo[1].should.be.eq(true)
          appInfo[2].should.be.eq(false)
          appInfo[3].should.be.eq(updater)
          appInfo[4].should.be.eq(exec)
          appInfo[5].should.be.eq(appInit.address)
        })

        it('should return a correctly populated allowed address array', async () => {
          let allowedInfo = await storage.getExecAllowed.call(returnedExecID)
          allowedInfo.length.should.be.eq(4)
          allowedInfo.should.be.eql(allowedAddrs)
        })
      })

      it('should allow execution', async () => {
        let stdAppCalldata = await appMockUtil.std1.call(
          storageLocations[0], storageValues[0]
        )
        stdAppCalldata.should.not.eq('0x')
        await storage.exec(
          stdApp.address, returnedExecID, stdAppCalldata,
          { from: exec }
        ).should.be.fulfilled
      })

      it('should allow the updater address to pause and unpause the application', async () => {
        await storage.pauseAppInstance(returnedExecID, { from: updater }).should.be.fulfilled
        await storage.unpauseAppInstance(returnedExecID, { from: updater }).should.be.fulfilled
      })
    })
  })

  describe('#initAndFinalize', async () => {

    context('init function returns invalid storage request', async () => {

      let invalidCalldata

      beforeEach(async () => {
        invalidCalldata = await appInitUtil.initInvalid.call()
        invalidCalldata.should.not.eq('0x')
      })

      it('should throw', async () => {
        await storage.initAndFinalize(
          updater, false, appInit.address, invalidCalldata, allowedAddrs,
          { from: exec }
        ).should.not.be.fulfilled
      })
    })

    context('init function returns no storage request', async () => {

      let initCalldata

      let returnedExecID
      let initEvent
      let finalEvent

      beforeEach(async () => {
        initCalldata = await appInitUtil.init.call()
        initCalldata.should.not.eq('0x')

        returnedExecID = await storage.initAndFinalize.call(
          updater, false, appInit.address, initCalldata, allowedAddrs,
          { from: exec }
        ).should.be.fulfilled

        let events = await storage.initAndFinalize(
          updater, false, appInit.address, initCalldata, allowedAddrs,
          { from: exec }
        ).then((tx) => {
          return tx.logs
        })
        events.should.not.eq(null)
        events.length.should.be.eq(2)
        initEvent = events[0]
        finalEvent = events[1]
      })

      it('should return a nonzero exec id', async () => {
        web3.toDecimal(returnedExecID).should.not.eq(0)
      })

      it('should emit an ApplicationInitialized event', async () => {
        initEvent.event.should.be.eq('ApplicationInitialized')
      })

      describe('the ApplicationInitialized event', async () => {

        it('should match the returned exec id', async () => {
          initEvent.args['execution_id'].should.be.eq(returnedExecID)
        })

        it('should match the correct init address', async () => {
          let emittedInitAddr = initEvent.args['init_address']
          emittedInitAddr.should.be.eq(appInit.address)
        })

        it('should match the script exec address', async () => {
          let emittedExec = initEvent.args['script_exec']
          emittedExec.should.be.eq(exec)
        })

        it('should match the updater address', async () => {
          let emittedUpdater = initEvent.args['updater']
          emittedUpdater.should.be.eq(updater)
        })
      })

      it('should emit an ApplicationFinalization event', async () => {
        finalEvent.event.should.be.eq('ApplicationFinalization')
      })

      describe('the ApplicationFinalization event', async () => {

        it('should match the returned exec id', async () => {
          finalEvent.args['execution_id'].should.be.eq(returnedExecID)
        })

        it('should match the correct init address', async () => {
          let emittedInitAddr = finalEvent.args['init_address']
          emittedInitAddr.should.be.eq(appInit.address)
        })
      })

      describe('registered app info', async () => {

        it('should return valid app info', async () => {
          let appInfo = await storage.app_info.call(returnedExecID)
          appInfo.length.should.be.eq(6)
          appInfo[0].should.be.eq(false)
          appInfo[1].should.be.eq(true)
          appInfo[2].should.be.eq(false)
          appInfo[3].should.be.eq(updater)
          appInfo[4].should.be.eq(exec)
          appInfo[5].should.be.eq(appInit.address)
        })

        it('should return a correctly populated allowed address array', async () => {
          let allowedInfo = await storage.getExecAllowed.call(returnedExecID)
          allowedInfo.length.should.be.eq(4)
          allowedInfo.should.be.eql(allowedAddrs)
        })
      })

      it('should allow execution', async () => {
        let stdAppCalldata = await appMockUtil.std1.call(
          storageLocations[0], storageValues[0]
        )
        stdAppCalldata.should.not.eq('0x')
        await storage.exec(
          stdApp.address, returnedExecID, stdAppCalldata,
          { from: exec }
        ).should.be.fulfilled
      })

      it('should allow the updater address to pause and unpause the application', async () => {
        await storage.pauseAppInstance(returnedExecID, { from: updater }).should.be.fulfilled
        await storage.unpauseAppInstance(returnedExecID, { from: updater }).should.be.fulfilled
      })
    })

    context('init function returns only payment information', async () => {

      let initCalldata

      beforeEach(async () => {
        initCalldata = await appInitUtil.initPayment.call()
        initCalldata.should.not.eq('0x')
      })

      it('should throw', async () => {
        await storage.initAndFinalize(
          updater, false, appInit.address, initCalldata, allowedAddrs,
          { from: exec }
        ).should.not.be.fulfilled
      })
    })

    context('init function returns storage request', async () => {

      context('storing data to 1 slot', async () => {

        let initCalldata

        let returnedExecID
        let initEvent
        let finalEvent

        beforeEach(async () => {
          initCalldata = await appInitUtil.initValidSingle.call(
            storageLocations[0], storageValues[0]
          )
          initCalldata.should.not.eq('0x')

          returnedExecID = await storage.initAndFinalize.call(
            updater, false, appInit.address, initCalldata, allowedAddrs,
            { from: exec }
          ).should.be.fulfilled

          let events = await storage.initAndFinalize(
            updater, false, appInit.address, initCalldata, allowedAddrs,
            { from: exec }
          ).then((tx) => {
            return tx.logs
          })
          events.should.not.eq(null)
          events.length.should.be.eq(2)
          initEvent = events[0]
          finalEvent = events[1]
        })

        it('should return a nonzero exec id', async () => {
          web3.toDecimal(returnedExecID).should.not.eq(0)
        })

        it('should emit an ApplicationInitialized event', async () => {
          initEvent.event.should.be.eq('ApplicationInitialized')
        })

        describe('the ApplicationInitialized event', async () => {

          it('should match the returned exec id', async () => {
            initEvent.args['execution_id'].should.be.eq(returnedExecID)
          })

          it('should match the correct init address', async () => {
            let emittedInitAddr = initEvent.args['init_address']
            emittedInitAddr.should.be.eq(appInit.address)
          })

          it('should match the script exec address', async () => {
            let emittedExec = initEvent.args['script_exec']
            emittedExec.should.be.eq(exec)
          })

          it('should match the updater address', async () => {
            let emittedUpdater = initEvent.args['updater']
            emittedUpdater.should.be.eq(updater)
          })
        })

        it('should emit an ApplicationFinalization event', async () => {
          finalEvent.event.should.be.eq('ApplicationFinalization')
        })

        describe('the ApplicationFinalization event', async () => {

          it('should match the returned exec id', async () => {
            finalEvent.args['execution_id'].should.be.eq(returnedExecID)
          })

          it('should match the correct init address', async () => {
            let emittedInitAddr = finalEvent.args['init_address']
            emittedInitAddr.should.be.eq(appInit.address)
          })
        })

        describe('registered app info', async () => {

          it('should return valid app info', async () => {
            let appInfo = await storage.app_info.call(returnedExecID)
            appInfo.length.should.be.eq(6)
            appInfo[0].should.be.eq(false)
            appInfo[1].should.be.eq(true)
            appInfo[2].should.be.eq(false)
            appInfo[3].should.be.eq(updater)
            appInfo[4].should.be.eq(exec)
            appInfo[5].should.be.eq(appInit.address)
          })

          it('should return a correctly populated allowed address array', async () => {
            let allowedInfo = await storage.getExecAllowed.call(returnedExecID)
            allowedInfo.length.should.be.eq(4)
            allowedInfo.should.be.eql(allowedAddrs)
          })
        })

        it('should allow execution', async () => {
          let stdAppCalldata = await appMockUtil.std1.call(
            storageLocations[0], storageValues[0]
          )
          stdAppCalldata.should.not.eq('0x')
          await storage.exec(
            stdApp.address, returnedExecID, stdAppCalldata,
            { from: exec }
          ).should.be.fulfilled
        })

        it('should allow the updater address to pause and unpause the application', async () => {
          await storage.pauseAppInstance(returnedExecID, { from: updater }).should.be.fulfilled
          await storage.unpauseAppInstance(returnedExecID, { from: updater }).should.be.fulfilled
        })

        describe('storage', async () => {

          it('should have correctly stored the value at the location', async () => {
            let readValue = await storage.read.call(returnedExecID, storageLocations[0])
            hexStrEquals(readValue, storageValues[0])
              .should.be.eq(true, "val read:" + readValue)
          })
        })
      })

      context('storing data to 2 slots', async () => {

        let initCalldata

        let returnedExecID
        let initEvent
        let finalEvent

        beforeEach(async () => {
          initCalldata = await appInitUtil.initValidMulti.call(
            storageLocations[0], storageValues[0], storageLocations[1], storageValues[1]
          )
          initCalldata.should.not.eq('0x')

          returnedExecID = await storage.initAndFinalize.call(
            updater, false, appInit.address, initCalldata, allowedAddrs,
            { from: exec }
          ).should.be.fulfilled

          let events = await storage.initAndFinalize(
            updater, false, appInit.address, initCalldata, allowedAddrs,
            { from: exec }
          ).then((tx) => {
            return tx.logs
          })
          events.should.not.eq(null)
          events.length.should.be.eq(2)
          initEvent = events[0]
          finalEvent = events[1]
        })

        it('should return a nonzero exec id', async () => {
          web3.toDecimal(returnedExecID).should.not.eq(0)
        })

        it('should emit an ApplicationInitialized event', async () => {
          initEvent.event.should.be.eq('ApplicationInitialized')
        })

        describe('the ApplicationInitialized event', async () => {

          it('should match the returned exec id', async () => {
            initEvent.args['execution_id'].should.be.eq(returnedExecID)
          })

          it('should match the correct init address', async () => {
            let emittedInitAddr = initEvent.args['init_address']
            emittedInitAddr.should.be.eq(appInit.address)
          })

          it('should match the script exec address', async () => {
            let emittedExec = initEvent.args['script_exec']
            emittedExec.should.be.eq(exec)
          })

          it('should match the updater address', async () => {
            let emittedUpdater = initEvent.args['updater']
            emittedUpdater.should.be.eq(updater)
          })
        })

        it('should emit an ApplicationFinalization event', async () => {
          finalEvent.event.should.be.eq('ApplicationFinalization')
        })

        describe('the ApplicationFinalization event', async () => {

          it('should match the returned exec id', async () => {
            finalEvent.args['execution_id'].should.be.eq(returnedExecID)
          })

          it('should match the correct init address', async () => {
            let emittedInitAddr = finalEvent.args['init_address']
            emittedInitAddr.should.be.eq(appInit.address)
          })
        })

        describe('registered app info', async () => {

          it('should return valid app info', async () => {
            let appInfo = await storage.app_info.call(returnedExecID)
            appInfo.length.should.be.eq(6)
            appInfo[0].should.be.eq(false)
            appInfo[1].should.be.eq(true)
            appInfo[2].should.be.eq(false)
            appInfo[3].should.be.eq(updater)
            appInfo[4].should.be.eq(exec)
            appInfo[5].should.be.eq(appInit.address)
          })

          it('should return a correctly populated allowed address array', async () => {
            let allowedInfo = await storage.getExecAllowed.call(returnedExecID)
            allowedInfo.length.should.be.eq(4)
            allowedInfo.should.be.eql(allowedAddrs)
          })
        })

        it('should allow execution', async () => {
          let stdAppCalldata = await appMockUtil.std1.call(
            storageLocations[0], storageValues[0]
          )
          stdAppCalldata.should.not.eq('0x')
          await storage.exec(
            stdApp.address, returnedExecID, stdAppCalldata,
            { from: exec }
          ).should.be.fulfilled
        })

        it('should allow the updater address to pause and unpause the application', async () => {
          await storage.pauseAppInstance(returnedExecID, { from: updater }).should.be.fulfilled
          await storage.unpauseAppInstance(returnedExecID, { from: updater }).should.be.fulfilled
        })

        describe('storage', async () => {

          it('should have correctly stored the value at the first location', async () => {
            let readValue = await storage.read.call(returnedExecID, storageLocations[0])
            hexStrEquals(readValue, storageValues[0])
              .should.be.eq(true, "val read:" + readValue)
          })

          it('should have correctly stored the value at the second location', async () => {
            let readValue = await storage.read.call(returnedExecID, storageLocations[1])
            hexStrEquals(readValue, storageValues[1])
              .should.be.eq(true, "val read:" + readValue)
          })
        })
      })
    })
  })

  describe('#add/removeAllowed', async () => {

    let additionalAddr
    let execID

    beforeEach(async () => {
      additionalAddr = await StdApp.new().should.be.fulfilled

      initCalldata = await appInitUtil.init.call()
      initCalldata.should.not.eq('0x')

      let events = await storage.initAndFinalize(
        updater, false, appInit.address, initCalldata, allowedAddrs,
        { from: exec }
      ).then((tx) => {
        return tx.logs
      })
      events.should.not.eq(null)
      events.length.should.be.eq(2)
      execID = events[1].args['execution_id']
      web3.toDecimal(execID).should.not.eq(0)
    })

    context('when the app does not exist', async () => {

      it('should throw on addAllowed', async () => {
        await storage.addAllowed(
          '0x1', [additionalAddr.address], { from: updater }
        ).should.not.be.fulfilled
      })

      it('should throw on removeAllowed', async () => {
        await storage.removeAllowed(
          '0x1', [stdApp.address], { from: updater }
        ).should.not.be.fulfilled
      })
    })

    context('when the app is unpaused', async () => {

      it('should throw on addAllowed', async () => {
        await storage.addAllowed(
          execID, [additionalAddr.address], { from: updater }
        ).should.not.be.fulfilled
      })

      it('should throw on removeAllowed', async () => {
        await storage.removeAllowed(
          execID, [stdApp.address], { from: updater }
        ).should.not.be.fulfilled
      })
    })

    context('when the app is paused', async () => {

      beforeEach(async () => {
        await storage.pauseAppInstance(
          execID, { from: updater }
        ).should.be.fulfilled
        let appInfo = await storage.app_info.call(execID)
        appInfo[0].should.be.eq(true)
      })

      context('when the sender is not the updater address', async () => {

        it('should throw on addAllowed', async () => {
          await storage.addAllowed(
            execID, [additionalAddr.address], { from: exec }
          ).should.not.be.fulfilled
        })

        it('should throw on removeAllowed', async () => {
          await storage.removeAllowed(
            execID, [stdApp.address], { from: exec }
          ).should.not.be.fulfilled
        })
      })

      context('when the sender is the updater address', async () => {

        context('addAllowed', async () => {

          beforeEach(async () => {
            await storage.addAllowed(
              execID, [additionalAddr.address], { from: updater }
            ).should.be.fulfilled
          })

          it('should add the new address', async () => {
            let allowedInfo = await storage.allowed_addresses.call(execID, additionalAddr.address)
            allowedInfo.toNumber().should.not.eq(0)
          })

          it('should allow execution through the new address once unpaused', async () => {
            await storage.unpauseAppInstance(execID, { from: updater }).should.be.fulfilled
            let sendCalldata = await appMockUtil.std1.call(
              storageLocations[0], storageValues[0]
            )
            sendCalldata.should.not.eq('0x')
            await storage.exec(
              additionalAddr.address, execID, sendCalldata,
              { from: exec }
            ).should.be.fulfilled
          })
        })

        context('removeAllowed', async () => {

          beforeEach(async () => {
            await storage.removeAllowed(
              execID, [stdApp.address], { from: updater }
            ).should.be.fulfilled
          })

          it('should remove the address', async () => {
            let allowedInfo = await storage.allowed_addresses.call(execID, stdApp.address)
            allowedInfo.toNumber().should.be.eq(0)
          })

          it('should not allow execution through the address once unpaused', async () => {
            await storage.unpauseAppInstance(execID, { from: updater }).should.be.fulfilled
            let sendCalldata = await appMockUtil.std1.call(
              storageLocations[0], storageValues[0]
            )
            sendCalldata.should.not.eq('0x')
            await storage.exec(
              stdApp.address, execID, sendCalldata,
              { from: exec }
            ).should.not.be.fulfilled
          })
        })
      })
    })
  })

  describe('#pause/unpauseAppInstance', async () => {

    let execID

    beforeEach(async () => {
      initCalldata = await appInitUtil.init.call()
      initCalldata.should.not.eq('0x')

      let events = await storage.initAndFinalize(
        updater, false, appInit.address, initCalldata, allowedAddrs,
        { from: exec }
      ).then((tx) => {
        return tx.logs
      })
      events.should.not.eq(null)
      events.length.should.be.eq(2)
      execID = events[1].args['execution_id']
      web3.toDecimal(execID).should.not.eq(0)
    })

    context('when the app does not exist', async () => {

      it('should throw on pauseAppInstance', async () => {
        await storage.pauseAppInstance(
          '0x1', { from: updater }
        ).should.not.be.fulfilled
      })

      it('should throw on unpauseAppInstance', async () => {
        await storage.unpauseAppInstance(
          '0x1', { from: updater }
        ).should.not.be.fulfilled
      })
    })

    context('when the sender is not the updater address', async () => {

      it('should throw on pauseAppInstance', async () => {
        await storage.pauseAppInstance(
          execID, { from: exec }
        ).should.not.be.fulfilled
      })

      it('should throw on pauseAppInstance', async () => {
        await storage.pauseAppInstance(
          execID, { from: exec }
        ).should.not.be.fulfilled
      })
    })

    context('when the sender is the updater address', async () => {

      it('should allow the updater to pause the app', async () => {
        await storage.pauseAppInstance(
          execID, { from: updater }
        ).should.be.fulfilled
        await storage.exec(
          stdApp.address, execID, stdAppCalldata,
          { from: exec }
        ).should.not.be.fulfilled
      })

      it('should allow the updater to unpause the app', async () => {
        await storage.unpauseAppInstance(
          execID, { from: updater }
        ).should.be.fulfilled
        await storage.exec(
          stdApp.address, execID, stdAppCalldata,
          { from: exec }
        ).should.be.fulfilled
      })
    })
  })

  describe('#changeScriptExec', async () => {

    let execID
    let newExec = accounts[accounts.length - 1]

    beforeEach(async () => {
      initCalldata = await appInitUtil.init.call()
      initCalldata.should.not.eq('0x')

      let events = await storage.initAndFinalize(
        updater, false, appInit.address, initCalldata, allowedAddrs,
        { from: exec }
      ).then((tx) => {
        return tx.logs
      })
      events.should.not.eq(null)
      events.length.should.be.eq(2)
      execID = events[1].args['execution_id']
      web3.toDecimal(execID).should.not.eq(0)
    })

    context('when the sender is not the script exec address', async () => {

      it('should throw', async () => {
        await storage.changeScriptExec(
          execID, newExec, { from: updater }
        ).should.not.be.fulfilled
      })
    })

    context('when the sender is the script exec address', async () => {

      beforeEach(async () => {
        await storage.changeScriptExec(
          execID, newExec, { from: exec }
        ).should.be.fulfilled
      })

      it('should correctly store the new exec address', async () => {
        let appInfo = await storage.app_info.call(execID)
        appInfo[4].should.be.eq(newExec)
      })

      it('should allow execution throught the new exec address', async () => {
        await storage.exec(
          stdApp.address, execID, stdAppCalldata,
          { from: newExec }
        ).should.be.fulfilled
      })

      it('should disallow execution throught old exec address', async () => {
        await storage.exec(
          stdApp.address, execID, stdAppCalldata,
          { from: exec }
        ).should.not.be.fulfilled
      })
    })
  })
})
