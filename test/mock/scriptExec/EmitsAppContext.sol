pragma solidity ^0.4.23;

library EmitsApp {

  bytes4 internal constant EMITS = bytes4(keccak256('emits:'));

  // emits 0 events
  function emit0(bytes memory) public pure returns (bytes memory) {
    return abi.encodeWithSelector(EMITS, uint(0));
  }

  // emits 1 event with 0 topics and no data
  function emit1top0(bytes memory) public pure returns (bytes memory) {
    return abi.encodeWithSelector(EMITS, uint(1), uint(0), uint(0));
  }

  // emits 1 event with 0 topics and with data
  function emit1top0data(bytes memory _context) public pure returns (bytes memory) {
    bytes memory temp = abi.encodeWithSelector(EMITS, uint(1), uint(0));
    return abi.encodePacked(temp, _context.length, _context);
  }

  // emits 1 event with 4 topics and with data
  function emit1top4data(
    bytes32 _t1, bytes32 _t2, bytes32 _t3, bytes32 _t4,
    bytes memory _context
  ) public pure returns (bytes memory) {
    bytes memory temp = abi.encodeWithSelector(
      EMITS, uint(1),
      uint(4), _t1, _t2, _t3, _t4
    );
    return abi.encodePacked(temp, _context.length, _context);
  }

  // emits 2 events, each with 1 topic and data
  function emit2top1data(
    bytes32 _t1, bytes memory _context
  ) public pure returns (bytes memory) {
    bytes memory temp = abi.encodeWithSelector(EMITS, uint(2), uint(1), _t1);
    return abi.encodePacked(
      temp, _context.length, _context,
      uint(1), (1 + uint(_t1)), _context.length, _context
    );
  }

  // emits 2 events, each with 4 topics and with no data
  function emit2top4(
    bytes32 _t1, bytes32 _t2, bytes32 _t3, bytes32 _t4, bytes memory
  ) public pure returns (bytes memory) {
    bytes memory temp = abi.encodeWithSelector(
      EMITS, uint(2), uint(4), _t1, _t2, _t3, _t4, uint(0)
    );
    return abi.encodePacked(
      temp, uint(4),
      uint(_t1) + 1, uint(_t2) + 1,
      uint(_t3) + 1, uint(_t4) + 1,
      uint(0)
    );
  }
}
