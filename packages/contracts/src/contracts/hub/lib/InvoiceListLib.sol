// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IHubStorage} from 'interfaces/hub/IHubStorage.sol';

/**
 * @title InvoiceListLib
 * @notice InvoiceListLib library for managing a linked list of invoices
 */
library InvoiceListLib {
  /**
   * @notice Node struct
   * @param invoice the invoice object
   * @param next the next node id
   */
  struct Node {
    IHubStorage.Invoice invoice;
    bytes32 next;
  }

  /**
   * @notice InvoiceList struct
   * @param head the head node id
   * @param tail the tail node id
   * @param nonce the nonce
   * @param length the length of the list
   * @param nodes the nodes mapping
   */
  struct InvoiceList {
    bytes32 head;
    bytes32 tail;
    uint256 nonce;
    uint256 length;
    mapping(bytes32 _id => Node _node) nodes;
  }

  /**
   * @notice Thrown if the id is not found in the list
   * @param _id the id not found
   */
  error InvoiceList_NotFound(bytes32 _id);

  /**
   * @notice Throws if the previous id is invalid for a removal
   * @param _previousId the previous id
   */
  error InvoiceList_Remove_InvalidPreviousId(bytes32 _previousId);

  /**
   * @notice Append a new node to the list
   * @param _list the list
   * @param _invoice the invoice to add
   */
  function append(InvoiceList storage _list, IHubStorage.Invoice memory _invoice) internal returns (bytes32 _id) {
    _list.length += 1;
    _id = keccak256(abi.encode(_invoice, ++_list.nonce));
    if (_list.head == 0) {
      // empty list
      _list.head = _id;
    } else {
      _list.nodes[_list.tail].next = _id;
    }
    _list.tail = _id;
    _list.nodes[_id] = Node({invoice: _invoice, next: 0});
  }

  /**
   * @notice Remove a node from the list
   * @param _list the list
   * @param _id the id of the node to remove
   * @param _previousId the id of the previous node
   * @dev the previous node is needed to update the next pointer, we are trusting the caller to provide the correct previous node for O(1) removal, if the previousId is incorrect it will revert
   */
  function remove(InvoiceList storage _list, bytes32 _id, bytes32 _previousId) internal {
    if (_list.nodes[_id].invoice.intentId == 0) {
      revert InvoiceList_NotFound(_id);
    }
    if (_list.head != _id) {
      if (_list.nodes[_previousId].next != _id) {
        revert InvoiceList_Remove_InvalidPreviousId(_previousId);
      }
      _list.nodes[_previousId].next = _list.nodes[_id].next;
    } else {
      if (_previousId != 0) {
        revert InvoiceList_Remove_InvalidPreviousId(_previousId);
      }
      _list.head = _list.nodes[_id].next;
    }
    _list.length -= 1;
    if (_list.tail == _id) {
      _list.tail = _previousId;
    }
    delete _list.nodes[_id];
  }

  /**
   * @notice Returns the node at the given id
   * @param _list the list
   * @param _id the id of the node
   * @return _node the node
   */
  function at(InvoiceList storage _list, bytes32 _id) internal view returns (Node memory _node) {
    if (_list.nodes[_id].invoice.intentId == 0) {
      revert InvoiceList_NotFound(_id);
    }
    return _list.nodes[_id];
  }
}
