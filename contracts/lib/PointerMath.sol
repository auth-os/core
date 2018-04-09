pragma solidity ^0.4.21;


library PointerMath {

    // Adds the value stored in the pointer to a, to b - and checks for overflow
    function safeAdd(uint _a_ptr, uint _b) internal pure {
        assembly {
            // Get a -
            let a := mload(_a_ptr)
            // Check for overflow
            if lt(add(a, _b), a) { revert (0, 0) }
            // Add and store -
            mstore(_a_ptr, add(a, _b))
        }
    }

    // Subtracts b from the value stored at _a_ptr - and checks for underflow
    function safeSub(uint _a_ptr, uint _b) internal pure {
        assembly {
            // Get a -
            let a := mload(_a_ptr)
            // Check for underflow
            if gt(_b, a) { revert (0, 0) }
            // Subtract and store
            mstore(_a_ptr, sub(a, _b))
        }
    }

    /* TODO mul, div, pow */
}
