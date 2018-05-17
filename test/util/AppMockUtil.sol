pragma solidity ^0.4.23;

contract AppMockUtil {

  /// PAYABLE APP ///

  function pay1(address, uint) public pure returns (bytes memory) { return msg.data; }
  function pay2(address, uint, bytes32, bytes32) public pure returns (bytes memory) { return msg.data; }
  function pay3(address, uint, bytes32, bytes32, bytes32, bytes32) public pure returns (bytes memory) { return msg.data; }

  function parsePayable(bytes memory _in) public pure returns (uint length, uint amount, address destination) {
    length = _in.length;
    require(length >= 64);
    assembly {
      amount := mload(add(0x20, _in))
      destination := mload(add(0x40, _in))
    }
  }

  /// STD APP ///

  function std1(bytes32, bytes32) public pure returns (bytes memory) { return msg.data; }
  function std2(bytes32, bytes32, bytes32, bytes32) public pure returns (bytes memory) { return msg.data; }

  /// INVALID APP ///

  function inv1(uint) public pure returns (bytes memory) { return msg.data; }
  function inv2() public pure returns (bytes memory) { return msg.data; }
  function inv3() public pure returns (bytes memory) { return msg.data; }
  function inv4() public pure returns (bytes memory) { return msg.data; }
  function inv5() public pure returns (bytes memory) { return msg.data; }

  /// REVERT APP ///

  function rev0() public pure returns (bytes memory) { return msg.data; }
  function rev1() public pure returns (bytes memory) { return msg.data; }
  function rev2(bytes32) public pure returns (bytes memory) { return msg.data; }
}
