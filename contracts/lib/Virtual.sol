pragma solidity ^0.4.23;

import "./Errors.sol";

library Virtual {

  // Memory pointer to a user-defined wrapper struct with several fields
  struct Wrapper { uint ptr; }

  // Initializes wrapper pointer, which stores a base storage location and execution id
  function initWrapper(Wrapper memory _ptr, bytes32 _base_storage, bytes32 _exec_id) internal pure {
    assembly {
      mstore(_ptr, mload(0x40))
      mstore(mload(_ptr), _base_storage)
      mstore(add(0x20, mload(_ptr)), _exec_id)
      mstore(0x40, add(0x60, _ptr))
    }
  }

  // Returns whether or not a pointer has been resolved to a value -
  function isResolved(uint _ptr) internal pure returns (bool) { return _ptr == 0; }

  // Returns the base storage location stored in the Wrapper
  function base(Wrapper memory _ref) internal pure returns (bytes32 base_storage) {
    assembly { base_storage := mload(mload(_ref)) }
  }

  // Returns the exec id stored in the Wrapper
  function execID(Wrapper memory _ref) internal pure returns (bytes32 exec_id) {
    assembly { exec_id := mload(add(0x20, mload(_ref))) }
  }

  // Reads and returns a value stored in the location referenced by the passed in location
  // and execution id
  function read(bytes32 _location, bytes32 _exec_id) internal view returns (bytes32 value) {
    if (_exec_id == bytes32(0))
      Errors.except('Error at Virtual.read(bytes32,bytes32): invalid exec_id');

    assembly {
      mstore(0, _location)
      mstore(0x20, _exec_id)
      value := sload(keccak256(0, 0x40))
    }
    return value;
  }

  // Reads and returns a value stored in the location referenced by the passed in location
  // and execution id, and offset by _off bytes
  function read(bytes32 _location, bytes32 _exec_id, uint _off) internal view returns (bytes32 value) {
    if (_exec_id == bytes32(0))
      Errors.except('Error at Virtual.read(Primitive): invalid exec_id');

    assembly {
      mstore(0, add(_off, _location))
      mstore(0x20, _exec_id)
      value := sload(keccak256(0, 0x40))
    }
    return value;
  }

  // Represents a basic array in storage
  // _len and _list can be resolved separately, so that the entire array does not need to
  // be read from storage, just to determine the length.
  struct List {
    Wrapper parent;  // Reference to a parent wrapper struct
    uint _len;  // Pointer to this field's length (when resolved from storage)
    uint _list;  // Pointer to this field's value (when resolved from storage)
    // User-defined function, which returns the base storage location of this list
    // when passed a reference to the parent struct
    function (Wrapper memory) pure returns (bytes32) loc;
  }

  // Called when declaring a reference to a list in storage (usually upon
  // creation of a user-defined wrapper type)
  // @param _parent: A reference pointer to the parent, which holds the parent's
  //                 base storage location and execution id.
  // @param _list: The field being declared
  // @param _loc: A function which, when passed the parent Wrapper pointer, should
  //              return the base location of the list in storage
  function hasField(
    Wrapper memory _parent,
    List memory _list,
    function (Wrapper memory) pure returns (bytes32) _loc
  ) internal pure {
    assembly {
      mstore(_list, _parent)
      mstore(add(0x60, _list), _loc)
    }
  }

  // Calls the type's 'loc' function, passing in the parent wrapper pointer.
  // Returns the type's base location in storage
  function ref(List memory _field) internal pure returns (bytes32) {
    return _field.loc(_field.parent);
  }

  // Returns the length of the list
  // If the length pointer has not been resolved, it will be read from storage. Otherwise,
  // this function will return the resolved value from _len
  function length(List memory _field) internal view returns (uint len) {
    uint _temp = _field._len;
    // Checks whether the length pointer has been resolved, returning its value if so
    if (isResolved(_temp)) {
      assembly { len := mload(_temp) }
      return len;
    }
    // If the length pointer has not been resolved, gets the location of the list from
    // the 'loc' function, and reads from storage
    len = uint(read(_field.loc(_field.parent), execID(_field.parent)));
    // Now, resolve the length pointer and return the length -
    assembly { mstore(_temp, len) }
  }

  // Returns the entire list
  // If the list pointer has not been resolved, the list will be read from storage. Otherwise,
  // this function will return the resolved values from _list
  function read(List memory _field) internal view returns (bytes32[] memory list) {
    uint _temp = _field._list;
    // Checks whether the _list pointer has been resolved, returning its value if so
    if (isResolved(_temp)) {
      assembly { list := _temp }
      return list;
    }
    // If the list pointer has not been resolved, gets the length of the list to read
    // and allocates space for the return list in memory
    list = new bytes32[](length(_field));
    if (list.length == 0) return list;
    // Get the base storage location of the list from 'loc'
    bytes32 location = _field.loc(_field.parent);
    // Reads each index in the list from storage, placing them in the return list
    for (uint i = 1; i <= list.length; i++)
      list[i - 1] = read(location, execID(_field.parent), 32 * i);

    // Finally, set the ListPtr as resolved and return the list -
    assembly { mstore(_temp, list) }
  }

  // Represents a bytes array in storage
  // _len and _words can be resolved separately, so that the entire array does not need to
  // be read from storage, just to determine the length.
  struct Words {
    Wrapper parent;  // Reference to a parent wrapper struct
    uint _len;  // Pointer to this field's length (when resolved from storage)
    uint _words;  // Pointer to this field's value (when resolved from storage)
    // User-defined function, which returns the base storage location of this array
    // when passed the parent reference pointer
    function (Wrapper memory) pure returns (bytes32) loc;
  }

  // Called when declaring a reference to a bytes array in storage (usually upon
  // creation of a user-defined wrapper type)
  // @param _parent: A reference pointer to the parent, which holds the parent's
  //                 base storage location and execution id.
  // @param _words: The field being declared
  // @param _loc: A function which, when passed the parent Wrapper pointer, should
  //              return the base location of the bytes array in storage
  function hasField(
    Wrapper memory _parent,
    Words memory _words,
    function (Wrapper memory) pure returns (bytes32) _loc
  ) internal pure {
    assembly {
      mstore(_words, _parent)
      mstore(add(0x60, _words), _loc)
    }
  }

  // Calls the type's 'loc' function, passing in the parent reference pointer.
  // Returns the type's base location in storage
  function ref(Words memory _field) internal pure returns (bytes32) {
    return _field.loc(_field.parent);
  }

  // Returns the length of the words (in bytes)
  // If the length pointer has not been resolved, it will be read from storage. Otherwise,
  // this function will return the resolved value from _len
  function length(Words memory _field) internal view returns (uint len) {
    uint _temp = _field._len;
    // Checks whether the length pointer has been resolved, returning its value if so
    if (isResolved(_temp)) {
      assembly { len := mload(_temp) }
      return len;
    }
    // If the length pointer has not been resolved, gets the location of the words from
    // the 'loc' function, and reads from storage
    len = uint(read(_field.loc(_field.parent), execID(_field.parent)));
    // Now, resolve the length pointer return the length -
    assembly { mstore(_temp, len) }
  }

  // Returns the entire bytes array
  // If the words pointer has not been resolved, the words will be read from storage. Otherwise,
  // this function will return the resolved values from _words
  function read(Words memory _field) internal view returns (bytes memory words) {
    uint _temp = _field._words;
    // Checks whether the _words pointer has been resolved, returning its value if so
    if (isResolved(_temp)) {
      assembly { words := _temp }
      return words;
    }
    // If the list pointer has not been resolved, gets the length of the array to read
    // and allocates space for the return array in memory
    words = new bytes(length(_field));
    if (words.length == 0) return words;
    // Get the base storage location of the array from 'loc'
    bytes32 location = _field.loc(_field.parent);
    // Reads the entire array from storage, placing it in the return array
    for (uint i = 32; i < words.length + 32; i += 32) {
      bytes32 val = read(location, execID(_field.parent), i);
      assembly { mstore(add(words, i), val) }
    }
    // Finally, set the ListPtr as resolved and return the array -
    assembly { mstore(_temp, words) }
  }

  // Represents a bytes32 value in storage
  struct Word {
    Wrapper parent; // Reference to a parent wrapper struct
    uint _value; // Pointer to this field's value (when resolved from storage)
    // User-defined function, which returns the base storage location of this field
    // when passed the parent reference pointer
    function (Wrapper memory) pure returns (bytes32) loc;
  }

  // Called when declaring a reference to a bytes32 in storage (usually upon
  // creation of a user-defined wrapper type)
  // @param _parent: A reference pointer to the parent, which holds the parent's
  //                 base storage location and execution id.
  // @param _word: The field being declared
  // @param _loc: A function which, when passed the parent Wrapper pointer, should
  //              return the base location of the bytes32 in storage
  function hasField(
    Wrapper memory _parent,
    Word memory _word,
    function (Wrapper memory) pure returns (bytes32) _loc
  ) internal pure {
    assembly {
      mstore(_word, _parent)
      mstore(add(0x40, _word), _loc)
    }
  }

  // Calls the type's 'loc' function, passing in the parent reference pointer.
  // Returns the type's base location in storage
  function ref(Word memory _field) internal pure returns (bytes32) {
    return _field.loc(_field.parent);
  }

  // Returns the word referenced by the passed-in field
  // If the word pointer has not been resolved, it will be read from storage. Otherwise,
  // this function will return the resolved value from _word
  function read(Word memory _field) internal view returns (bytes32 word) {
    uint _temp = _field._value;
    // Checks whether the _word pointer has already been resolved, returning its value if so
    if (isResolved(_temp)) {
      assembly { word := mload(_temp) }
      return word;
    }
    // If the _value pointer has not been resolved, gets the location of the word from
    // the 'loc' function, and reads from storage
    word = read(_field.loc(_field.parent), execID(_field.parent));
    // Now, mark the ValuePtr as resolved and return the value -
    assembly { mstore(_temp, word) }
  }

  // Represents an address in storage
  struct Address {
    Wrapper parent; // Reference to a parent wrapper struct
    uint _value; // Pointer to this field's value (when resolved from storage)
    // User-defined function, which returns the base storage location of this field
    // when passed the parent reference pointer
    function (Wrapper memory) pure returns (bytes32) loc;
  }

  // Called when declaring a reference to an address in storage (usually upon
  // creation of a user-defined wrapper type)
  // @param _parent: A reference pointer to the parent, which holds the parent's
  //                 base storage location and execution id.
  // @param _addr: The field being declared
  // @param _loc: A function which, when passed the parent Wrapper, should
  //              return the base location of the address in storage
  function hasField(
    Wrapper memory _parent,
    Address memory _addr,
    function (Wrapper memory) pure returns (bytes32) _loc
  ) internal pure {
    assembly {
      mstore(_addr, _parent)
      mstore(add(0x40, _addr), _loc)
    }
  }

  // Calls the type's 'loc' function, passing in the parent reference pointer.
  // Returns the type's base location in storage
  function ref(Address memory _field) internal pure returns (bytes32) {
    return _field.loc(_field.parent);
  }

  // Reads the value from storage
  // If the value pointer has not been resolved, it will be read from storage. Otherwise,
  // this function will return the resolved value from _value
  function read(Address memory _field) internal view returns (address addr) {
    uint _temp = _field._value;
    // Checks whether the value pointer has already been resolved, returning its value if so
    if (isResolved(_temp)) {
      assembly { addr := mload(_temp) }
      return addr;
    }
    // If the value pointer has not been resolved, gets the location of the value from
    // the 'loc' function, and reads from storage
    addr = address(read(_field.loc(_field.parent), execID(_field.parent)));
    // Now, mark the value pointer as resolved and return the value -
    assembly { mstore(_temp, addr) }
  }

  // Represents a uint256 in storage
  struct Uint {
    Wrapper parent; // Reference to a parent wrapper struct
    uint _value; // Pointer to this field's value (when resolved from storage)
    // User-defined function, which returns the base storage location of this field
    // when passed the parent reference pointer
    function (Wrapper memory) pure returns (bytes32) loc;
  }

  // Called when declaring a reference to a uint256 in storage (usually upon
  // creation of a user-defined wrapper type)
  // @param _parent: A reference pointer to the parent, which holds the parent's
  //                 base storage location and execution id.
  // @param _num: The field being declared
  // @param _loc: A function which, when passed the parent Wrapper, should
  //              return the base location of the uint in storage
  function hasField(
    Wrapper memory _parent,
    Uint memory _num,
    function (Wrapper memory) pure returns (bytes32) _loc
  ) internal pure {
    assembly {
      mstore(_num, _parent)
      mstore(add(0x40, _num), _loc)
    }
  }

  // Calls the type's 'loc' function, passing in the parent reference pointer.
  // Returns the type's base location in storage
  function ref(Uint memory _field) internal pure returns (bytes32) {
    return _field.loc(_field.parent);
  }

  // Reads the value from storage
  // If the value pointer has not been resolved, it will be read from storage. Otherwise,
  // this function will return the resolved value from _value
  function read(Uint memory _field) internal view returns (uint num) {
    uint _temp = _field._value;
    // Checks whether the value pointer has already been resolved, returning its value if so
    if (isResolved(_temp)) {
      assembly { num := mload(_temp) }
      return num;
    }
    // If the value pointer has not been resolved, gets the location of the value from
    // the 'loc' function, and reads from storage
    num = uint(read(_field.loc(_field.parent), execID(_field.parent)));
    // Now, mark the value pointer as resolved and return the value -
    assembly { mstore(_temp, num) }
  }

  // Represents a boolean value in storage
  struct Bool {
    Wrapper parent; // Reference to a parent wrapper struct
    uint _value; // Pointer to this field's value (when resolved from storage)
    // User-defined function, which returns the base storage location of this array
    // when passed the parent reference pointer
    function (Wrapper memory) pure returns (bytes32) loc;
  }

  // Called when declaring a reference to a bool in storage (usually upon
  // creation of a user-defined wrapper type)
  // @param _parent: A reference pointer to the parent, which holds the parent's
  //                 base storage location and execution id.
  // @param _bool: The field being declared
  // @param _loc: A function which, when passed the parent Wrapper, should
  //              return the base location of the bool in storage
  function hasField(
    Wrapper memory _parent,
    Bool memory _bool,
    function (Wrapper memory) pure returns (bytes32) _loc
  ) internal pure {
    assembly {
      mstore(_bool, _parent)
      mstore(add(0x40, _bool), _loc)
    }
  }

  // Calls the type's 'loc' function, passing in the parent reference pointer.
  // Returns the type's base location in storage
  function ref(Bool memory _field) internal pure returns (bytes32) {
    return _field.loc(_field.parent);
  }

  // Reads the value from storage
  // If the value pointer has not been resolved, it will be read from storage. Otherwise,
  // this function will return the resolved value from _value
  function read(Bool memory _field) internal view returns (bool val) {
    uint _temp = _field._value;
    // Checks whether the value pointer has already been resolved, returning its value if so
    if (isResolved(_temp)) {
      assembly { val := mload(_temp) }
      return val;
    }
    // If the value pointer has not been resolved, gets the location of the value from
    // the 'loc' function, and reads from storage
    val = read(_field.loc(_field.parent), execID(_field.parent)) != bytes32(0);
    // Now, mark the ValuePtr as resolved and return the value -
    assembly { mstore(_temp, val) }
  }
}
