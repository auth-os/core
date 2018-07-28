pragma solidity ^0.4.24;

/**
 * @title ListLib
 * @dev Implements a simple, efficient LinkedList in memory to which bytes and
 * bytes[] can be appended
 */
library ListLib {

  struct LinkedList {
    uint size;
    Node head;
    Node tail;
  }

  struct Node {
    bytes[] data;
    uint next;
  }

  /**
   * @dev Adds the elements of a bytes[] to the tail of the LinkedList
   * @param _list The LinkedList struct
   * @param _array The array which will be added to the LinkedList
   */
  function join(LinkedList memory _list, bytes[] memory _array) internal pure {
    // Allocate memory for a new node and set its data field to the array
    Node memory new_node;
    new_node.data = _array;
    // If the size of the list is zero, operate on the head. Otherwise, operate on the tail of the list
    if (_list.size == 0) {
      // Set the list's size to be equal to the length of the array
      _list.size = _array.length;
      // Set the new node as the head and tail of the list
      _list.head = new_node;
      _list.tail = new_node;
    } else {
      // Add the length of _array to the list's size
      _list.size += _array.length;
      // Set the list's tail to point to the new node
      _list.tail.next = toPtr(new_node);
      // Make the new node the tail of the list
      _list.tail = new_node;
    }
  }

  /**
   * @dev Adds the bytes array to the LinkedList
   * @param _list The LinkedList struct
   * @param _array The array which will be appended to the LinkedList
   */
  function append(LinkedList memory _list, bytes memory _array) internal pure {
    // Create a bytes[] of length 1 to hold _array
    bytes[] memory arr = new bytes[](1);
    arr[0] = _array;
    // Allocate memory for a new node and set its data field to the array
    Node memory new_node;
    new_node.data = arr;
    // If the size of the list is zero, operate on the head. Otherwise, operate on the tail of the list
    if (_list.size == 0) {
      // Set the list's size to 1
      _list.size = 1;
      // Set the new node as the head and tail of the list
      _list.head = new_node;
      _list.tail = new_node;
    } else {
      // Increment the list's size
      _list.size++;
      // Set the list's tail to point to the new node
      _list.tail.next = toPtr(new_node);
      // Make the new node the tail of the list
      _list.tail = new_node;
    }
  }

  /**
   * @dev Joins the data field of each Node in the LinkedList and returns it as a bytes[]
   * @param _list The LinkedList struct
   * @return array A bytes[] comprising of the data of each Node in the LinkedList
   */
  function toArray(LinkedList memory _list) internal pure returns (bytes[] memory array) {
    // Allocate memory for the return array
    array = new bytes[](_list.size);
    // Get a pointer representing the current Node
    uint cur = toPtr(_list.head);
    uint node_len;
    // Iterate over each Node and add its data to the return array
    for (uint i = 0; i < _list.size; cur = next(cur)) {
      node_len = getLength(cur);
      for (uint j = 0; j < node_len; j++) {
        array[i++] = getData(cur, j);
      }
    }
  }

  /**
   * @dev Converts a Node struct into a pointer
   * @param _node The node struct to be converted
   * @return ptr The memory location of the node struct
   */
  function toPtr(Node memory _node) internal pure returns (uint ptr) {
    assembly { ptr := _node }
  }

  /**
   * @dev Sets the current node to its next node
   * @param _curr The current Node
   * @return next_node The next node
   */
  function next(uint _curr) internal pure returns (uint next_node) {
    assembly { next_node := mload(add(_curr, 0x20)) }
  }

  /**
   * @dev Gets the length of the data bytes[] of the _curr node
   * @param _curr The pointer to the current node
   * @return length The length of the data bytes[] of the _curr node
   */
  function getLength(uint _curr) internal pure returns (uint length) {
    assembly { length := mload(mload(_curr)) }
  }

  /**
   * @dev Gets the bytes at a specific index of a bytes[]
   * @param _curr The pointer to the current node
   * @param _index The index within the bytes[] to obtain
   * @return data The bytes held at _index of the data field of curr
   */
  function getData(uint _curr, uint _index) internal pure returns (bytes memory data) {
    // Calculate the offset of the desired bytes and load its pointer
    _index = (_index * 32) + 32;
    assembly { data := mload(add(_index, mload(_curr))) }
  }
}
