pragma solidity ^0.4.24;

library ListLib {

  struct LinkedList {
    uint size;
    uint head;
    uint tail;
  }

  struct Node {
    bytes[] data;
    uint next;
  }

  /**
   * @dev Converts a pointer into a Node struct 
   * @param ptr The memory location of the node struct
   * @returns _node The node struct to be converted
   */
  function toNode(uint _ptr) internal pure returns (Node memory node) {
    assembly { node := _ptr }
  }

  /**
   * @dev Converts a Node struct into a pointer
   * @param _node The node struct to be converted
   * @returns ptr The memory location of the node struct
   */
  function toPtr(Node memory _node) internal pure returns (uint ptr) {
    assembly { ptr := _node }
  }

  /**
   * @dev Adds the elements of a bytes[] to the LinkedList
   * @param _list The LinkedList struct
   * @param _array The array which will be added to the LinkedList
   */
  function join(LinkedList memory _list, bytes[] memory _array) internal pure {
    // If the size of the list is zero, operate on the head. Otherwise, operate on the tail of the list.
    if (_list.size == 0) {
      // Set the list struct's size to be equal to the length of _array.
      _list.size = _array.length;
      // Construct a Node struct in memory with _array and a next pointer of zero.
      Node memory head = Node({ data: _array, next: 0 });
      // Set the head pointer equal to the location in memory of the head struct.
      _list.head = toPtr(head);
      // Set the tail pointer equal to the head pointer -- used so that the head's next pointer is set correctly.
      _list.tail = toPtr(head);
    } else {
      // Add the length of _array to the list struct's size.
      _list.size += _array.length;
      // Convert the list struct's tail pointer into a Node struct.
      Node memory tail = toNode(_list.tail);
      // Construct a Node struct in memory with _array and a next pointer of zero.
      Node memory new_tail = Node({ data: _array, next: 0 }); 
      // Set the next pointer of the tail struct to be the location in memory of the new tail struct.
      tail.next = toPtr(new_tail); 
      // Set the list struct's tail pointer to be the location in memory of the new tail struct.
      _list.tail = toPtr(new_tail);
    }
  }

  /**
   * @dev Adds the bytes array to the LinkedList
   * @param _list The LinkedList struct
   * @param _array The array which will be appended to the LinkedList
   */
  function append(LinkedList memory _list, bytes memory _array) internal pure {
    // Initialize a bytes[] called arr with length one in memory.
    bytes[] memory arr = new bytes[](1);
    // Set the first entry of arr to be equal to _array.
    arr[0] = _array;
    // If the size of the list is zero, operate on the head. Otherwise, operate on the tail of the list.
    if (_list.size == 0) {
      // Set the list struct's size to 1.
      _list.size = 1;
      // Construct a Node struct in memory with arr and a next pointer of zero.
      Node memory head = Node({ data: arr, next: 0 });
      // Set the head pointer equal to the location in memory of the head struct.
      _list.head = toPtr(head);
      // Set the tail pointer equal to the head pointer -- used so that the head's next pointer is set correctly.
      _list.tail = toPtr(head);
    } else {
      // Increment the list struct's size.
      _list.size ++;
      // Convert the list struct's tail pointer into a Node struct.
      Node memory tail = toNode(_list.tail);
      // Construct a Node struct in memory with arr and a next pointer of zero.
      Node memory new_tail = Node({ data: arr, next: 0 }); 
      // Set the next pointer of the tail struct to be the location in memory of the new tail struct.
      tail.next = toPtr(new_tail); 
      // Set the list struct's tail pointer to be the location in memory of the new tail struct.
      _list.tail = toPtr(new_tail);
    }
  }

  /**
   * @dev Converts the LinkedList to a bytes[] and returns it
   * @param _list The LinkedList struct
   * @return array A bytes[] comprising of all of the nodes of the LinkedList
   */
  function toArray(LinkedList memory _list) internal pure returns (bytes[] memory array) {
    // Allocate memory for the return array.
    array = new bytes[](_list.size); 
    // Loop through the data structure and add pointers to the return array.
    Node memory cur = toNode(_list.head);
    // Add all of the bytes stored in the list data structure to the return array.
    for (uint i = 0; i < _list.size; cur = toNode(cur.next)) {
      for (uint j = 0; j < cur.data.length; j++) {
        array[i++] = cur.data[j];
      }
    }
  }

}

