pragma solidity ^0.4.23;

library MixedAppContext {

  // ACTION REQUESTORS //

  bytes4 internal constant EMITS = bytes4(keccak256('emits:'));
  bytes4 internal constant STORES = bytes4(keccak256('stores:'));
  bytes4 internal constant PAYS = bytes4(keccak256('pays:'));
  bytes4 internal constant THROWS = bytes4(keccak256('throws:'));

  // EMITS 1, THROWS
  function req0(bytes32 _t1, bytes memory) public pure returns (bytes memory) {
    bytes memory temp = abi.encodeWithSelector(
      EMITS, uint(1), uint(1), _t1, uint(0)
    );
    return abi.encodePacked(temp, THROWS, uint(0));
  }

  // PAYS 1, STORES 1
  function req1(
    address _dest, uint _val,
    bytes32 _loc, bytes32 _val1, bytes memory
  ) public pure returns (bytes memory) {
    bytes memory temp = abi.encodeWithSelector(
      PAYS, uint(1), _val, _dest
    );
    return abi.encodePacked(temp, STORES, uint(1), _val1, _loc);
  }

  // EMITS 1, STORES 1
  function req2(bytes32 _t1, bytes32 _loc, bytes32 _val, bytes memory) public pure returns (bytes memory) {
    bytes memory temp = abi.encodeWithSelector(
      EMITS, uint(1), uint(1), uint(_t1), uint(0)
    );
    return abi.encodePacked(temp, STORES, uint(1), _val, _loc);
  }

  // PAYS 1, EMITS 1
  function req3(address _dest, uint _val, bytes32 _t1, bytes memory) public pure returns (bytes memory) {
    bytes memory temp = abi.encodeWithSelector(
      PAYS, uint(1), _val, _dest
    );
    return abi.encodePacked(temp, EMITS, uint(1), uint(1), _t1, uint(0));
  }

  // PAYS 2, EMITS 1, THROWS
  function reqs0(
    address _dest1, address _val1,
    address _dest2, address _val2,
    bytes32 _t1, bytes memory _context
  ) public pure returns (bytes memory) {
    bytes memory temp = abi.encodeWithSelector(PAYS, uint(2), _val1, _dest1, _val2, _dest2);
    temp = abi.encodePacked(
      temp, EMITS, uint(1), uint(1), _t1, _context.length, _context
    );
    return abi.encodePacked(temp, THROWS, uint(0));
  }

  // EMITS 2, PAYS 1, STORES 2
  function reqs1(
    address _dest, uint _val,
    bytes32 _loc1, bytes32 _val1, bytes32 _loc2, bytes32 _val2,
    bytes memory _context
  ) public pure returns (bytes memory) {
    bytes memory temp = abi.encodeWithSelector(
      EMITS, uint(2), uint(0)
    );
    temp = abi.encodePacked(temp, _context.length, _context);
    temp = abi.encodePacked(temp, uint(0), _context.length, _context);
    temp = abi.encodePacked(temp, PAYS, uint(1), _val, bytes32(_dest));
    return abi.encodePacked(temp, STORES, uint(2), _val1, _loc1, _val2, _loc2);
  }

  // PAYS 1, EMITS 3, STORES 1
  function reqs2(
    address _dest, uint _val,
    bytes32[4] memory _topics,
    bytes32 _loc, bytes32 _val1, bytes memory _context
  ) public pure returns (bytes memory) {
    bytes memory temp = abi.encodeWithSelector(PAYS, uint(1), _val, _dest);
    temp = abi.encodePacked(
      temp, EMITS, uint(3), _topics.length, _topics, _context.length, _context
    );
    temp = abi.encodePacked(
      temp, _topics.length, 1 + uint( _topics[0]), 1 + uint( _topics[1]),
      1 + uint( _topics[2]), 1 + uint( _topics[3])
    );
    temp = abi.encodePacked(temp, _context.length, _context);
    temp = abi.encodePacked(
      temp, _topics.length, 2 + uint(_topics[0]), 2 + uint(_topics[1]),
      2 + uint(_topics[2]), 2 + uint(_topics[3])
    );
    temp = abi.encodePacked(temp, _context.length, _context);
    return abi.encodePacked(temp, STORES, uint(1), _val1, _loc);
  }

  // STORES 2, PAYS 1, EMITS 1
  function reqs3(
    address _dest, uint _val,
    bytes32 _t1,
    bytes32 _loc1, bytes32 _val1, bytes32 _loc2, bytes32 _val2,
    bytes memory _context
  ) public pure returns (bytes memory) {
    bytes memory temp = abi.encodeWithSelector(
      STORES, uint(2), _val1, _loc1, _val2, _loc2
    );
    temp = abi.encodePacked(temp, PAYS, uint(1), _val, bytes32(_dest));
    temp = abi.encodePacked(temp, EMITS, uint(1), uint(1), _t1);
    return abi.encodePacked(temp, _context.length, _context);
  }
}
