pragma solidity ^0.4.24;

library ListLib {

  struct LinkedList { }

  /**
   * @dev Adds the elements of a bytes[] to the LinkedList
   * @param _list The LinkedList struct
   * @param _array The array which will be added to the LinkedList
   */
  function join(LinkedList memory _list, bytes[] memory _array) internal pure;

  /**
   * @dev Adds the bytes array to the LinkedList
   * @param _list The LinkedList struct
   * @param _array The array which will be appended to the LinkedList
   */
  function append(LinkedList memory _list, bytes memory _array) internal pure;

  /**
   * @dev Converts the LinkedList to a bytes[] and returns it
   * @param _list The LinkedList struct
   * @return array A bytes[] comprising of all of the nodes of the LinkedList
   */
  function toArray(LinkedList memory _list) internal pure returns (bytes[] memory array);
}
