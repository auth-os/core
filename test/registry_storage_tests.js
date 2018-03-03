let RegistryStorage = artifacts.require('./mock/RegistryStorageMock')

let storage // test subject

contract('RegistryStorage', function(accounts) {

  beforeEach(async () => {
    storage = await RegistryStorage.new()
  })
})
