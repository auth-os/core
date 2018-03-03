let Registry = artifacts.require('./mock/RegistryMock')
let RegistryStorage = artifacts.require('./mock/RegistryStorageMock')

let registry // test subject
let storage // test subject's initialized abstract storage impl

contract('Registry', function(accounts) {

  it('should test with sanity', async () => {
    accounts.length.should.be.gt(1)
  })

  beforeEach(async () => {
    storage = await RegistryStorage.new()
    registry = await Registry.new(storage.address, { gas: 4845075 })
  })

  describe('initialization', async () => {
    it('sets the registry moderator to the contract creator', async () => {
      let moderatorAddr = await registry.moderator()
      moderatorAddr.should.be.equal(accounts[0])
    })

    it('references an abstract storage contract impl', async () => {
      let storageAddr = await registry.abstract_storage()
      storageAddr.should.be.equal(storage.address)
    })
  })

  describe('#changeMod', async () => {  
    context('when the caller is not the acting registry moderator', async () => {
      beforeEach(async () => {
        await registry.changeMod(accounts[0], { from: accounts[accounts.length - 1] }).should.be.rejectedWith(exports.EVM_ERR_REVERT);
      })

      it('should not have allowed unauthorized modification to the moderator', async () => {
        let moderatorAddr = await registry.moderator()
        moderatorAddr.should.be.equal(accounts[0])
      })
    })

    context('when the caller is the acting registry moderator', async () => {
      let initialModeratorAddr
      beforeEach(async () => {
        initialModeratorAddr = await registry.moderator()
      })

      beforeEach(async () => {
        await registry.changeMod(accounts[accounts.length - 1])
      })

      it('should have changed the acting registry moderator', async () => {
        let moderatorAddr = await registry.moderator()
        moderatorAddr.should.be.equal(accounts[accounts.length - 1])
        moderatorAddr.should.not.be.equal(initialModeratorAddr)
      })
    })
  })

  describe('#changeStorage', async () => {
    context('when the caller is not the acting registry moderator', async () => {
      beforeEach(async () => {
        await registry.changeStorage(accounts[0], { from: accounts[accounts.length - 1] }).should.be.rejectedWith(exports.EVM_ERR_REVERT);
      })

      it('should not have allowed unauthorized modification to the abstract storage impl', async () => {
        let storageAddr = await registry.abstract_storage()
        storageAddr.should.be.equal(storage.address)
      })
    })

    context('when the caller is the acting registry moderator', async () => {
      beforeEach(async () => {
        await registry.changeStorage(accounts[accounts.length - 1])
      })

      it('should have changed the abstract storage impl address', async () => {
        let storageAddr = await registry.abstract_storage()
        storageAddr.should.be.equal(accounts[accounts.length - 1])
        storageAddr.should.not.be.equal(storage.address)
      })
    })
  })

  describe('#registerApp', async () => {
    // ...
  })

  describe('#getAppInfo', async () => {
    // ...
  })

  describe('#initVersion', async () => {
    // ...
  })

  describe('#registerVersion', async () => {
    // ...
  })

  describe('#addVersionFunctions', async () => {
    // ...
  })

  describe('#getVerInfo', async () => {
    // ...
  })

  describe('#getFuncInfo', async () => {
    // ...
  })
})
