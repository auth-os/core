let RegistryStorage = artifacts.require('./mock/RegistryStorageMock')

let storage // test subject

contract('RegistryStorage', function(accounts) {

  beforeEach(async () => {
    storage = await RegistryStorage.new()
  })

  describe('#getTrueLocation', async () => {
    it('should be deterministic', async () => {
      let location0 = await storage.getTrueLocation('storageloc')
      let location1 = await storage.getTrueLocation('storageloc')
      location0.should.be.eq(location1)
    })
  })

  describe('#getLocationWithSeed', async () => {
    it('should be deterministic', async () => {
      let location0 = await storage.getLocationWithSeed('storageloc', accounts[0])
      let location1 = await storage.getLocationWithSeed('storageloc', accounts[0])
      location0.should.be.eq(location1)
    })
  })

  describe('#write', async () => {
    context('when the data is valid bytes32', async () => {
      it('should write data at the given storage location', async () => {
        let location = await storage.write('storageloc', 'valid bytes 32')
        let read = await storage.read('storageloc')
        read.should.not.be.eq(null)
      })
    })
  })

  describe('#writeMulti', async () => {
    context('when the provided array consist of only valid bytes32 location => data items', async () => {
      it('should write each data at the corresponding given storage location', async () => {
        await storage.writeMulti(['storageloc0', 'valid bytes 32 0', 'storageloc1', 'valid bytes 32 1'])

        let data0 = await storage.read('storageloc0')
        data0.should.not.be.eq(null)
        web3.toUtf8(data0).should.be.deep.eq('valid bytes 32 0')

        let data1 = await storage.read('storageloc1')
        data1.should.not.be.eq(null)
        web3.toUtf8(data1).should.be.deep.eq('valid bytes 32 1')
      })
    })
  })

  describe('#read', async () => {
    beforeEach(async () => {
      await storage.write('storageloc', 'valid bytes 32')
    })

    it('should expose the stored value at the given storage location', async () => {
      let data = await storage.read('storageloc')
      web3.toUtf8(data).should.be.deep.eq('valid bytes 32')
    })
  })

  describe('#readMulti', async () => {
    beforeEach(async () => {
      await storage.writeMulti(['storageloc0', 'valid bytes 32 0', 'storageloc1', 'valid bytes 32 1'])
    })

    context('when the provided array consist of only valid bytes32 locations', async () => {
      it('should write each data at the corresponding given storage location', async () => {
        let values = await storage.readMulti(['storageloc0', 'storageloc1'])
        values.length.should.be.eq(2)
        values[0].should.not.be.eq(null)
        web3.toUtf8(values[0]).should.be.deep.eq('valid bytes 32 0')
        values[1].should.not.be.eq(null)
        web3.toUtf8(values[1]).should.be.deep.eq('valid bytes 32 1')
      })
    })
  })

  describe('#readTrueLocation', async () => {
    let location

    beforeEach(async () => {
      await storage.write('storageloc', 'valid bytes 32')
      location = await storage.getTrueLocation('storageloc')
    })

    it('should be deterministic', async () => {
      let read0 = await storage.readTrueLocation(location)
      let read1 = await storage.readTrueLocation(location)
      read0.should.be.eq(read1)
    })

    it('should expose the stored value at the given true storage location', async () => {
      let data = await storage.readTrueLocation(location)
      web3.toUtf8(data).should.be.deep.eq('valid bytes 32')
    })
  })
})
