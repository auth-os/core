pragma solidity ^0.4.23;

library PayableAppContext {

  bytes4 internal constant PAYS = bytes4(keccak256('pays:'));

  // forwards payment to 0 addresses
  function pay0(bytes memory) public pure returns (bytes memory) {
    return abi.encodeWithSelector(PAYS, uint(0));
  }

  // forwards payment to one address
  function pay1(address _dest, uint _amt, bytes memory) public pure returns (bytes memory) {
    return abi.encodeWithSelector(PAYS, uint(1), _amt, _dest);
  }

  // forwards payment to 2 addresses
  function pay2(
    address _dest1, uint _amt1, address _dest2, uint _amt2, bytes memory
  ) public pure returns (bytes memory) {
    return abi.encodeWithSelector(
      PAYS, uint(2), _amt1, _dest1, _amt2, _dest2
    );
  }
}
