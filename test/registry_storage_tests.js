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
    it('should deterministically return the true location of the data in storage', async () => {
      let location0 = await storage.write.call('storageloc', '...')
      let location1 = await storage.write.call('storageloc', '...')
      location0.should.not.be.eq(null)
      location1.should.not.be.eq(null)
      location0.should.be.deep.eq(location1)
    })

    context('when the given storage location and bytes32 data are valid', async () => {
      [
        ['address', 0x0000000000000000000000000000000000000000],
        ['tx hash', 0xc9f7b1968534162e7507ac7e3471c5fbf64d1eea9a2cd062b216e98a9a3d733e],
        ['string', 'valid bytes 32 string'],
        ['unsigned int', 123],
      ].forEach(async (tuple) => {
        it('should write ' + tuple[0] + ' at the given storage location', async () => {
          await storage.write('storageloc', tuple[1])

          let data = await storage.read('storageloc')
          data.should.not.be.eq(null)
        })
      });

      context('when the given data exceeds 32 bytes', async () => {
        context('when the given data is a string exceeding 32 bytes', async () => {
          it('should write the first 32 bytes of the string at the given storage location', async () => {
            await storage.write('storageloc', '12345678901234 67890123456789012this is truncated')

            let data = await storage.read('storageloc')
            web3.toUtf8(data).should.be.deep.eq('12345678901234 67890123456789012')
          })
        })
      })
    })

    context('when the given data is invalid bytes32', async () => {
      [
        ['signed int', -123],
      ].forEach(async (tuple) => {
        it('should reject the attempted ' + tuple[0] + ' write tx', async () => {
          await storage.write('storageloc', tuple[1]).should.be.rejectedWith(exports.EVM_ERR_REVERT);
        })
      });
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
