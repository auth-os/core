pragma solidity ^0.4.23;

contract ReturndataGenerator {

  bytes4 public constant EMITS = bytes4(keccak256('emits:'));
  bytes4 public constant STORES = bytes4(keccak256('stores:'));
  bytes4 public constant PAYS = bytes4(keccak256('pays:'));
  bytes4 public constant THROWS = bytes4(keccak256('throws:'));

  bytes32 public constant TOPIC_1 = bytes32('LOG_1_TEST');
  bytes32 public constant TOPIC_2 = bytes32('LOG_2_TEST');
  bytes32 public constant TOPIC_3 = bytes32('LOG_3_TEST');
  bytes32 public constant TOPIC_4 = bytes32('LOG_4_TEST');

  function STORE_1(uint _loc, uint _val) public pure returns (bytes memory returned_data) {
    returned_data = abi.encodeWithSelector(
      STORES, uint(1), _loc, _val
    );
  }

  function STORE_4(uint _loc, uint _val) public pure returns (bytes memory returned_data) {
    returned_data = abi.encodeWithSelector(
      STORES, uint(4), _loc, _val, ++_loc, ++_val, ++_loc, ++_val, ++_loc, ++_val
    );
  }

  function S1_P1_E1(uint _loc, uint _dest, uint _val) public pure returns (bytes memory returned_data) {
    bytes memory temp = abi.encodeWithSelector(
      STORES, uint(1), _loc, _dest
    );
    returned_data = abi.encodeWithSelector(
      PAYS, uint(1), _dest, _val
    );
    returned_data = abi.encodePacked(returned_data, temp);
    temp = abi.encodeWithSelector(
      EMITS, uint(2),
      uint(1), [TOPIC_1], uint(96), _loc, _dest, _val,
      uint(1), [TOPIC_4]
    );
    temp = abi.encodePacked(temp, uint(12), PAYS, STORES, EMITS);
    returned_data = abi.encodePacked(returned_data, temp);
  }

  function PAY_1_DEST(uint _dest, uint _val) public pure returns (bytes memory returned_data) {
    uint n_dest = 1;
    returned_data = abi.encodeWithSelector(
      PAYS, n_dest, _dest, _val
    );
  }

  function PAY_3_DEST(uint _dest, uint _val) public pure returns (bytes memory returned_data) {
    uint n_dest = 3;
    returned_data = abi.encodeWithSelector(
      PAYS, n_dest, _dest, _val, ++_dest, ++_val, ++_dest, ++_val
    );
  }

  function PAY_1_EMIT_1_LOG_1_PLUS_DATA(uint _dest, uint _val) public pure returns (bytes memory returned_data) {
    uint n_dest = 1;
    uint n_events = 1;
    bytes memory returned_1 = abi.encodeWithSelector(
      PAYS, n_dest, _dest, _val
    );
    bytes memory returned_2 = abi.encodeWithSelector(
      EMITS, n_events, uint(1), [TOPIC_1], uint(64), _dest, _val
    );
    returned_data = abi.encodePacked(returned_1, returned_2);
  }

  function PAY_1_EMIT_3(uint _dest, uint _val) public pure returns (bytes memory returned_data) {
    bytes memory pay_ret = abi.encodeWithSelector(
      PAYS, uint(1), _dest, _val
    );
    bytes memory emit_ret = abi.encodeWithSelector(
      EMITS, uint(3),
      uint(2), [TOPIC_1, TOPIC_1], uint(64), _dest, _val,
      uint(0), uint(64), _dest, _val,
      uint(1), [TOPIC_1], uint(4), PAYS
    );
    returned_data = abi.encodePacked(pay_ret, emit_ret);
  }

  uint public constant VAL = 25;
  uint public constant VALS1 = 24;
  uint public constant VALS2 = 23;

  uint public constant DEST = 444;
  uint public constant DEST1 = 445;
  uint public constant DEST2 = 446;

  function PAY_3_EMIT_3() public pure returns (bytes memory returned_data) {
    bytes memory _pay = abi.encodeWithSelector(
      PAYS, uint(3), DEST, VAL, DEST1, VALS1, DEST2, VALS2
    );

    bytes memory _emit = abi.encodeWithSelector(
      EMITS, uint(3),
      uint(2), [TOPIC_1, TOPIC_1], uint(64), DEST2, VALS2,
      uint(0), uint(64), DEST1, VALS1,
      uint(4), [TOPIC_1, TOPIC_2, TOPIC_3, TOPIC_4], uint(64)
    );

    returned_data = abi.encodePacked(_pay, _emit, DEST, VAL);
  }

  function LOG_0_PLUS_DATA(uint _val) public view returns (bytes memory returned_data) {
    returned_data = new bytes(0xa4);

    uint num_to_emit = 1;
    returned_data = abi.encodeWithSelector(EMITS, num_to_emit, uint(0));

    assembly {
      mstore(returned_data, 0xa4)
      mstore(add(0x64, returned_data), 0x40)
      mstore(add(0x84, returned_data), caller)
      mstore(add(0xa4, returned_data), _val)
      mstore(0x40, add(0x40, mload(returned_data)))
    }
  }

  function LOG_1_PLUS_DATA(uint _val) public view returns (bytes memory returned_data) {
    returned_data = new bytes(0xe4);

    bytes32[1] memory topics = [TOPIC_1];
    uint num_to_emit = 1;
    returned_data = abi.encodeWithSelector(EMITS, num_to_emit, topics.length, topics);

    assembly {
      mstore(returned_data, 0xe4)
      mstore(add(0x84, returned_data), 0x40)
      mstore(add(0xa4, returned_data), caller)
      mstore(add(0xc4, returned_data), _val)
      mstore(0x40, add(0x40, mload(returned_data)))
    }
  }

  function LOG_4_PLUS_DATA(uint _val) public view returns (bytes memory returned_data) {
    returned_data = new bytes(0x144);

    bytes32[4] memory topics = [TOPIC_1, TOPIC_2, TOPIC_3, TOPIC_4];
    uint num_to_emit = 1;
    returned_data = abi.encodeWithSelector(EMITS, num_to_emit, topics.length, topics);

    assembly {
      mstore(returned_data, 0x144)
      mstore(add(0xe4, returned_data), 0x40)
      mstore(add(0x104, returned_data), caller)
      mstore(add(0x124, returned_data), _val)
      mstore(0x40, add(0x40, mload(returned_data)))
    }
  }

  function LOG_1_NO_DATA() public pure returns (bytes memory returned_data) {
    uint num_to_emit = 1;
    bytes32[1] memory topics = [TOPIC_1];
    returned_data = abi.encodeWithSelector(EMITS, num_to_emit, topics.length, topics, uint(0));
  }

  function LOG_4_NO_DATA() public pure returns (bytes memory returned_data) {
    uint num_to_emit = 1;
    bytes32[4] memory topics = [TOPIC_1, TOPIC_2, TOPIC_3, TOPIC_4];
    returned_data = abi.encodeWithSelector(EMITS, num_to_emit, topics.length, topics, uint(0));
  }

  function EMIT_2_LOG_1_NO_DATA() public pure returns (bytes memory returned_data) {
    uint num_to_emit = 2;
    bytes32[1] memory topics1 = [TOPIC_1];
    bytes32[1] memory topics2 = [TOPIC_2];
    returned_data = abi.encodeWithSelector(
      EMITS, num_to_emit, topics1.length, topics1, uint(0), topics2.length, topics2, uint(0)
    );
  }

  function EMIT_2_LOG_4_NO_DATA() public pure returns (bytes memory returned_data) {
    uint num_to_emit = 2;
    bytes32[4] memory topics1 = [TOPIC_1, TOPIC_2, TOPIC_3, TOPIC_4];
    bytes32[4] memory topics2 = [TOPIC_4, TOPIC_3, TOPIC_2, TOPIC_1];
    returned_data = abi.encodeWithSelector(
      EMITS, num_to_emit, topics1.length, topics1, uint(0), topics2.length, topics2, uint(0)
    );
  }

  function EMIT_2_LOG_0_PLUS_DATA(uint _val1, uint _val2) public view returns (bytes memory returned_data) {
    uint num_to_emit = 2;

    returned_data = abi.encodeWithSelector(
      EMITS, num_to_emit, uint(0), uint(64), msg.sender, _val1, uint(0), uint(64), msg.sender, _val2
    );
  }

  function EMIT_2_LOG_4_PLUS_DATA(uint _val1, uint _val2) public view returns (bytes memory returned_data) {
    uint num_to_emit = 2;
    bytes32[4] memory topics1 = [TOPIC_1, TOPIC_2, TOPIC_3, TOPIC_4];
    bytes32[4] memory topics2 = [TOPIC_4, TOPIC_3, TOPIC_2, TOPIC_1];

    returned_data = abi.encodeWithSelector(
      EMITS, num_to_emit,
      topics1.length, topics1, uint(64), msg.sender, _val1,
      topics2.length, topics2, uint(96), msg.sender, _val2, keccak256(msg.sender)
    );
  }

  function EMIT_3_MIX() public view returns (bytes memory) {
    // w/ data
    bytes32[4] memory topics1 = [TOPIC_1, TOPIC_2, TOPIC_3, TOPIC_4];
    // w/o data
    bytes32[3] memory topics2 = [TOPIC_4, TOPIC_3, TOPIC_2];
    // w/o data
    bytes32[4] memory topics3 = [TOPIC_2, TOPIC_2, TOPIC_2, TOPIC_2];

    return abi.encodeWithSelector(EMITS, uint(3),
      topics1.length, topics1, uint(64), msg.sender, uint(2),
      topics2.length, topics2, uint(0),
      topics3.length, topics3, uint(64), msg.sender, keccak256(msg.sender)
    );
  }
}
