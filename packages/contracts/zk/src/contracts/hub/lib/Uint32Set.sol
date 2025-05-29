// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/structs/EnumerableSet.sol)
// This file was procedurally generated from scripts/generate/templates/EnumerableSet.js.
pragma solidity 0.8.25;

/**
 * @dev Library for managing uint32 sets. Copied and adapted from OpenZeppelin's EnumerableSet library.
 *
 * Sets have the following properties:
 *
 * - Elements are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Elements are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```solidity
 * contract Example {
 *     // Add the library methods
 *     using EnumerableSet for EnumerableSet.AddressSet;
 *
 *     // Declare a set state variable
 *     EnumerableSet.AddressSet private mySet;
 * }
 * ```
 *
 * [WARNING]
 * ====
 * Trying to delete such a structure from storage will likely result in data corruption, rendering the structure
 * unusable.
 * See https://github.com/ethereum/solidity/pull/11843[ethereum/solidity#11843] for more info.
 *
 * In order to clean an EnumerableSet, you can either remove all elements one by one or create a fresh instance using an
 * array of EnumerableSet.
 * ====
 */
library Uint32Set {
  struct Set {
    // Storage of set values
    uint32[] values;
    // Position of the value in the `values` array, plus 1 because index 0
    // means a value is not in the set.
    mapping(uint32 => uint256) indexes;
  }

  /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @dev Add a value to a set. O(1).
   *
   * Returns true if the value was added to the set, that is if it was not
   * already present.
   */
  function add(Set storage _set, uint32 _value) internal returns (bool) {
    return _add(_set, _value);
  }

  /**
   * @dev Removes a value from a set. O(1).
   *
   * Returns true if the value was removed from the set, that is if it was
   * present.
   */
  function remove(Set storage _set, uint32 _value) internal returns (bool) {
    return _remove(_set, _value);
  }

  /**
   * @dev Removes all the elements of the set. O(n).
   */
  function flush(
    Set storage set
  ) internal {
    for (uint256 _i; _i < set.values.length; _i++) {
      delete set.indexes[set.values[_i]];
    }

    delete set.values;
  }

  /**
   * @dev Returns true if the value is in the set. O(1).
   */
  function contains(Set storage _set, uint32 _value) internal view returns (bool) {
    return _contains(_set, _value);
  }

  /**
   * @dev Returns the number of values in the set. O(1).
   */
  function length(
    Set storage _set
  ) internal view returns (uint256) {
    return _length(_set);
  }

  /**
   * @dev Returns the value stored at position `index` in the set. O(1).
   *
   * Note that there are no guarantees on the ordering of values inside the
   * array, and it may change when more values are added or removed.
   *
   * Requirements:
   *
   * - `index` must be strictly less than {length}.
   */
  function at(Set storage _set, uint256 _index) internal view returns (uint32) {
    return _at(_set, _index);
  }

  /**
   * @dev Return the entire set in an array
   *
   * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
   * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
   * this function has an unbounded cost, and using it as part of a state-changing function may render the function
   * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
   */
  function memValues(
    Set storage _set
  ) internal view returns (uint32[] memory) {
    uint32[] memory store = _values(_set);
    uint32[] memory result;

    /// @solidity memory-safe-assembly
    assembly {
      result := store
    }

    return result;
  }

  /*//////////////////////////////////////////////////////////////
                           PRIVATE FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @dev Add a value to a set. O(1).
   *
   * Returns true if the value was added to the set, that is if it was not
   * already present.
   */
  function _add(Set storage _set, uint32 _value) private returns (bool) {
    if (!_contains(_set, _value)) {
      _set.values.push(_value);
      // The value is stored at length-1, but we add 1 to all indexes
      // and use 0 as a sentinel value
      _set.indexes[_value] = _set.values.length;
      return true;
    } else {
      return false;
    }
  }

  /**
   * @dev Removes a value from a set. O(1).
   *
   * Returns true if the value was removed from the set, that is if it was
   * present.
   */
  function _remove(Set storage _set, uint32 _value) private returns (bool) {
    // We read and store the value's index to prevent multiple reads from the same storage slot
    uint256 valueIndex = _set.indexes[_value];

    if (valueIndex != 0) {
      // Equivalent to contains(set, value)
      // To delete an element from the values array in O(1), we swap the element to delete with the last one in
      // the array, and then remove the last element (sometimes called as 'swap and pop').
      // This modifies the order of the array, as noted in {at}.

      uint256 toDeleteIndex = valueIndex - 1;
      uint256 lastIndex = _set.values.length - 1;

      if (lastIndex != toDeleteIndex) {
        uint32 lastValue = _set.values[lastIndex];

        // Move the last value to the index where the value to delete is
        _set.values[toDeleteIndex] = lastValue;
        // Update the index for the moved value
        _set.indexes[lastValue] = valueIndex; // Replace lastValue's index to valueIndex
      }

      // Delete the slot where the moved value was stored
      _set.values.pop();

      // Delete the index for the deleted slot
      delete _set.indexes[_value];

      return true;
    } else {
      return false;
    }
  }

  /**
   * @dev Returns true if the value is in the set. O(1).
   */
  function _contains(Set storage _set, uint32 _value) private view returns (bool) {
    return _set.indexes[_value] != 0;
  }

  /**
   * @dev Returns the number of values on the set. O(1).
   */
  function _length(
    Set storage _set
  ) private view returns (uint256) {
    return _set.values.length;
  }

  /**
   * @dev Returns the value stored at position `index` in the set. O(1).
   *
   * Note that there are no guarantees on the ordering of values inside the
   * array, and it may change when more values are added or removed.
   *
   * Requirements:
   *
   * - `index` must be strictly less than {length}.
   */
  function _at(Set storage _set, uint256 _index) private view returns (uint32) {
    return _set.values[_index];
  }

  /**
   * @dev Return the entire set in an array
   *
   * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
   * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
   * this function has an unbounded cost, and using it as part of a state-changing function may render the function
   * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
   */
  function _values(
    Set storage _set
  ) private view returns (uint32[] memory) {
    return _set.values;
  }
}
