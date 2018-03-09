pragma solidity ^0.4.20;

/*
Abstract storage contract -

Allows storage requests from anyone, but hashes requests with the sender's address to prevent overlap or malicious overwrites.
Facilitates a much more fluid storage structure. In the future, storage requests will be hashed with a seed instead, which will allow several
permissioned addresses to access the same storage locations.
*/
contract AbstractStorage {

  /*
  Writes data to a given location

  @param _location: The internal storage address to store data in
  @param _data: The data to store
  @return location: The actual storage location, after hashing
  */
  function write(bytes32 _location, bytes32 _data) public returns (bytes32 location) {
    bytes32 sender = keccak256(msg.sender);
    location = keccak256(_location, sender);
    assembly {
      sstore(location, _data)
    }
  }

  /*
  Writes data to multiple locations in memory. Locations do not need to be consecutive. For the time being,
  only supports single slot (32 bytes) writes to each location, but can be expanded to allow dynamic writes.

  @param _input: Contains information on data to be stored. Uses the following format:
  [location][data][location][data][location][data]... where each 'index' is one 32-byte slot
  @return location_hash: The hash of all storage locations written to, in order. Hash does not use sender-seeded locations (for easy interface-side verification)
  */
  function writeMulti(bytes32[] _input) public returns (uint num_writes) {
    // Ensure input length is even
    require(_input.length % 2 == 0);
    bytes32 sender = keccak256(msg.sender);
    assembly {
      // Get a pointer to free-memory to compute storage location hashes in
      let storage_hash_ptr := mload(0x40)
      // Store sender hash in second slot of pointer
      mstore(add(0x20, storage_hash_ptr), sender)
      // Update free-memory pointer
      mstore(0x40, add(0x40, storage_hash_ptr))

      // Ensure input length is nonzero
      if iszero(mload(_input)) { revert (0, 0) }

      // Loop over input
      for { let offset := 0x20 } lt(offset, mul(0x20, mload(_input))) { offset := add(0x40, offset) } {
        // Get location from input
        let location := mload(add(offset, _input))
        // Get data from input
        let data := mload(add(add(0x20, offset), _input))
        // Store location in storage_hash_ptr, to calculate storage location
        mstore(storage_hash_ptr, location)
        // Get hash of sender and storage location
        let true_storage_location := keccak256(storage_hash_ptr, 0x40)
        // Store data
        sstore(true_storage_location, data)
      }
      // Get number of writes performed (uint)
      num_writes := div(mload(_input), 2)
    }
  }

  /*
  Returns data stored at a given location

  @param _location: The address to get data from
  @return data: The data stored at the location after hashing
  */
  function read(bytes32 _location) public constant returns (bytes32 data_read) {
    bytes32 sender = keccak256(msg.sender);
    bytes32 location = keccak256(_location, sender);
    assembly {
      data_read := sload(location)
    }
  }

  /*
  Reads data directly from storage

  @param _location: The storage address to read from
  @return data: The data stored at the given location
  */
  function readTrueLocation(bytes32 _location) public constant returns (bytes32 data_read) {
    assembly {
      data_read := sload(_location)
    }
  }

  /*
  Returns data stored in several nonconsecutive locations

  @param _locations: A dynamic array of storage locations to read from
  @return data_read: The corresponding data stored in the requested locations
  */
  function readMulti(bytes32[] _locations) public constant returns (bytes32[] data_read) {
    bytes32 sender = keccak256(msg.sender);
    assembly {
      // Get free-memory pointer for a hash location
      let hash_loc := mload(0x40)
      // Store the hash of the sender in the second slot of the hash pointer
      mstore(add(0x20, hash_loc), sender)

      // Get a free-memory pointer to store return data in
      data_read := add(0x20, msize)
      // Store return data length (uint)
      mstore(data_read, mload(_locations))

      // Loop over input and store in return data
      for { let offset := 0x20 } lt(offset, add(0x20, mul(0x20, mload(_locations)))) { offset := add(0x20, offset) } {
        // Get storage location from hash location ptr
        mstore(hash_loc, mload(add(offset, _locations)))
        // Hash sender and location to get storage location
        let storage_location := keccak256(hash_loc, 0x40)
        // Store data in storage, in data_read
        mstore(add(offset, data_read), sload(storage_location))
      }
    }
  }

  /*
  Returns the true location in Abstract Storage for a passed-in location seed

  @param _location: The seed of the true location to get
  @return true_location: The location corresponding to the given seed
  */
  function getTrueLocation(bytes32 _location) public constant returns (bytes32 true_location) {
    return keccak256(_location, keccak256(msg.sender));
  }

  /*
  Returns the true location in Abstract Storage for a passed-in location, seeded by an address

  @param _location: The location from which to calculate storage location
  @param _seed: The address to hash with the given location
  @return true_location: The location in Abstract Storage
  */
  function getLocationWithSeed(bytes32 _location, address _seed) public pure returns (bytes32 true_location) {
    return keccak256(_location, keccak256(_seed));
  }
}
