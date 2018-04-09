pragma solidity ^0.4.21;


library StorageUtils {

    // Returns a bytes32[] from a storage buffer
    function getBuffer(uint _ptr) internal pure returns (bytes32[] memory storage_buffer) {
        assembly {
            storage_buffer := _ptr
        }
    }

    /*
    Creates a storage buffer and adds payment information

    @param _destination: The destination to forward wei
    @param _value: The amount of wei to forward
    @return ptr: A pointer to the storage buffer
    */
    function storePaymentInfo(uint _ptr, address _destination, uint _value) internal pure returns (uint ptr) {
        // Ensure valid destination -
        require(_destination != address(0));
        // If the pointer is 0, get a new pointer -
        ptr = _ptr;
        if (ptr == 0)
        ptr = getFreePointer();

        // Push destination and value to storage pointer
        stPush(ptr, bytes32(_destination), bytes32(_value));
    }

    // Returns the storage location to read from given a key, key size, and storage seed
    function location(bytes32 _key, uint _key_size, bytes32 _seed) internal pure returns (bytes32 storage_location) {
        assert(_key_size <= 32);
        assembly {
            // Place the key at 0x00 for hashing
            mstore(0x00, _key)
            // Place the seed at 0x20 for hashing
            mstore(0x20, _seed)
            // Hash the seed with the bytes of the key that are applicable
            storage_location := keccak256(sub(0x20, _key_size), add(0x20, _key_size))
        }
    }

    // Creates a storage buffer in free memory, and adds default payment information (0, 0)
    function stBuff() internal pure returns (uint ptr) {
        assembly {
            // Get free memory pointer for the buffer
            ptr := mload(0x40)
            // First slot in the buffer is length - set initial length to 2
            mstore(ptr, 2)
            // First two slots are payment information - set both to 0
            mstore(add(0x20, ptr), 0)
            mstore(add(0x40, ptr), 0)

            // If the free memory pointer does not point beyond the buffer, update it
            if lt(mload(0x40), add(0x60, ptr)) {
                mstore(0x40, add(0x60, ptr))
            }
        }
    }

    /*
    Pushes location and data to a storage buffer at _ptr

    @param _ptr: A pointer to a storage buffer
    @param _location: The location to which data will be stored
    @param _data: The data to store in the location
    */
    function stPush(uint _ptr, bytes32 _location, bytes32 _data) internal pure {
        assembly {
            // Get number of items in the buffer
            let size := mload(_ptr)
            // Store new buffer size -
            mstore(_ptr, add(2, size))
            // Multiply size by 0x20, and add pointer and 0x20 to get push location
            // [size][loc_0][data_0][loc_1][data_1]...[loc_2n-1][data_2n-1]
            size := add(add(0x20, _ptr), mul(0x20, size))
            // Push location and data to buffer
            mstore(size, _location)
            mstore(add(0x20, size), _data)

            // If the free memory pointer is not pointing beyond the buffer, increase the pointer
            if lt(mload(0x40), add(0x40, size)) {
                mstore(0x40, add(0x40, size))
            }
        }
    }

    /*
    Gets the value stored at the pointer, plus an offset
    */
    function get(uint _ptr, uint _ind) internal pure returns (bytes32 value) {
        assembly {
            value := mload(add(_ind, _ptr))
        }
    }

    // Returns a pointer to free memory
    function getFreePointer() internal pure returns (uint ptr) {
        assembly {
            ptr := mload(0x40)
        }
    }
}
