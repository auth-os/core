pragma solidity ^0.4.23;

contract AppMockUtil {

  /// PAYABLE APP ///

  function pay0() public pure returns (bytes memory) { return msg.data; }
  function pay1(address, uint) public pure returns (bytes memory) { return msg.data; }
  function pay2(address, uint, address, uint) public pure returns (bytes memory) { return msg.data; }

  /// STD APP ///

  function std0() public pure returns (bytes memory) { return msg.data; }
  function std1(bytes32, bytes32) public pure returns (bytes memory) { return msg.data; }
  function std2(bytes32, bytes32, bytes32, bytes32) public pure returns (bytes memory) { return msg.data; }

  /// EMITS APP ///

  function emit0() public pure returns (bytes memory) { return msg.data; }
  function emit1top0() public pure returns (bytes memory) { return msg.data; }
  function emit1top0data(bytes memory) public pure returns (bytes memory) { return msg.data; }
  function emit1top4data(bytes32, bytes32, bytes32, bytes32, bytes) public pure returns (bytes memory) { return msg.data; }
  function emit2top1data(bytes32, bytes memory, bytes memory) public pure returns (bytes memory) { return msg.data; }
  function emit2top4(bytes32, bytes32, bytes32, bytes32) public pure returns (bytes memory) { return msg.data; }

  /// MIXED APP ///

  function req0(bytes32) public pure returns (bytes memory) { return msg.data; }
  function req1(address, uint, bytes32, bytes32) public pure returns (bytes memory) { return msg.data; }
  function req2(bytes32, bytes32, bytes32) public pure returns (bytes memory) { return msg.data; }
  function req3(address, uint, bytes32) public pure returns (bytes memory) { return msg.data; }
  function reqs0(
    address, address, address, address,
    bytes32, bytes memory
  ) public pure returns (bytes memory) { return msg.data; }
  function reqs1(
    address, uint, bytes memory, bytes memory,
    bytes32, bytes32, bytes32, bytes32
  ) public pure returns (bytes memory) { return msg.data; }
  function reqs2(
    address, uint, bytes32[4] memory, bytes memory,
    bytes32, bytes32
  ) public pure returns (bytes memory) { return msg.data; }
  function reqs3(
    address, uint, bytes32, bytes memory,
    bytes32, bytes32, bytes32, bytes32
  ) public pure returns (bytes memory) { return msg.data; }

  /// INVALID APP ///

  function inv1() public pure returns (bytes memory) { return msg.data; }
  function inv2() public pure returns (bytes memory) { return msg.data; }

  /// REVERT APP ///

  function rev0() public pure returns (bytes memory) { return msg.data; }
  function rev1() public pure returns (bytes memory) { return msg.data; }
  function rev2(bytes32) public pure returns (bytes memory) { return msg.data; }
  function throws1(bytes memory) public pure returns (bytes memory) { return msg.data; }
  function throws2(bytes memory) public pure returns (bytes memory) { return msg.data; }
}
