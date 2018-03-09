pragma solidity ^0.4.20;

import "../../storage/AbstractStorage.sol";

/*
Registry abstract storage contract -

Allows storage requests from anyone, but hashes requests with the sender's address to prevent overlap or malicious overwrites.
Facilitates a much more fluid storage structure. In the future, storage requests will be hashed with a seed instead, which will allow several
permissioned addresses to access the same storage locations.
*/
contract RegistryStorage is AbstractStorage { }
