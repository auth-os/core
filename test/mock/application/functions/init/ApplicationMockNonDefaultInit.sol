pragma solidity ^0.4.21;


library ApplicationMockNonDefaultInit {

    function init(bytes _argv) public pure {}

    function initSel() public pure returns (bytes4) {
        return bytes4(keccak256("init(bytes)"));
    }
}
