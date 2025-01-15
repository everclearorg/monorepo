// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {TypeCasts} from 'contracts/common/TypeCasts.sol';

import {TestExtended} from '../../utils/TestExtended.sol';
import {InvoiceListLib} from 'contracts/hub/lib/InvoiceListLib.sol';
import {IHubStorage} from 'interfaces/hub/IHubStorage.sol';

contract BaseTest is TestExtended {
  using InvoiceListLib for InvoiceListLib.InvoiceList;
  using TypeCasts for address;

  InvoiceListLib.InvoiceList list;

  modifier setPreviousNodes(
    uint8 _previousNodes
  ) {
    _setPreviousNodes(_previousNodes);
    _;
  }

  function _setPreviousNodes(
    uint8 _previousNodes
  ) internal {
    vm.assume(_previousNodes > 0 && _previousNodes < type(uint8).max);
    for (uint8 _i = 1; _i <= _previousNodes; _i++) {
      IHubStorage.Invoice memory _invoice = IHubStorage.Invoice({
        intentId: keccak256(abi.encode(_i)),
        owner: vm.addr(_i).toBytes32(),
        entryEpoch: _i,
        amount: 10
      });
      list.append(_invoice);
    }
  }
}

contract Unit_Append is BaseTest {
  using InvoiceListLib for InvoiceListLib.InvoiceList;

  /**
   * @notice Test appending to an empty list
   * @param _invoice the invoice to add
   */
  function test_EmptyList(
    IHubStorage.Invoice calldata _invoice
  ) public {
    vm.assume(_invoice.intentId != 0);
    list.append(_invoice);

    InvoiceListLib.Node memory _node = list.at(list.head);
    assertEq(_node.invoice.intentId, _invoice.intentId, 'incorrect intentId');
    assertEq(_node.invoice.entryEpoch, _invoice.entryEpoch, 'incorrect entryEpoch');
    assertEq(_node.invoice.amount, _invoice.amount, 'incorrect amount');
    assertEq(_node.next, 0, 'incorrect next');
    assertEq(list.head, list.tail, 'head and tail are not the same');
    assertEq(list.length, 1, 'incorrect length');
  }

  /**
   * @notice Test appending to a non-empty list
   * @param _previousNodes the number of previous nodes
   * @param _invoice the invoice to add
   */
  function test_NonEmptyList(
    uint8 _previousNodes,
    IHubStorage.Invoice calldata _invoice
  ) public setPreviousNodes(_previousNodes) {
    vm.assume(_invoice.intentId != 0);

    bytes32 _expectedHead = list.head;
    bytes32 _previousTail = list.tail;
    bytes32 _expectedNextForPreviousTail = keccak256(abi.encode(_invoice, _previousNodes + 1));
    bytes32 _expectedTail = keccak256(abi.encode(_invoice, _previousNodes + 1));

    list.append(_invoice);

    InvoiceListLib.Node memory _node = list.at(list.tail);
    assertEq(_node.invoice.intentId, _invoice.intentId, 'incorrect intentId');
    assertEq(_node.invoice.entryEpoch, _invoice.entryEpoch, 'incorrect entryEpoch');
    assertEq(_node.invoice.amount, _invoice.amount, 'incorrect amount');
    assertEq(_node.next, 0, 'incorrect next');
    assertEq(list.head, _expectedHead, 'incorrect head');
    assertEq(list.tail, _expectedTail, 'incorrect tail');
    assertEq(list.length, _previousNodes + 1, 'incorrect length');
    assertEq(list.nodes[_previousTail].next, _expectedNextForPreviousTail, 'incorrect next for previous tail');
  }
}

contract Unit_Remove is BaseTest {
  using InvoiceListLib for InvoiceListLib.InvoiceList;
  using TypeCasts for address;

  /**
   * @notice Test removing head from the list
   * @param _previousNodes the number of previous nodes
   */
  function test_Head(
    uint8 _previousNodes
  ) public setPreviousNodes(_previousNodes) {
    bytes32 _removedNode = list.head;
    bytes32 _expectedHead = list.nodes[_removedNode].next;

    // Since we are removing the head, previous node is 0
    list.remove({_id: _removedNode, _previousId: 0});

    assertEq(list.head, _expectedHead, 'incorrect head');
    assertEq(list.length, _previousNodes - 1, 'incorrect length');
    assertEq(list.nodes[_removedNode].invoice.intentId, 0, 'node not deleted');
    assertEq(list.nodes[_removedNode].next, 0, 'node not deleted');
  }

  /**
   * @notice Test removing tail from the list
   * @param _previousNodes the number of previous nodes
   */
  function test_Tail(
    uint8 _previousNodes
  ) public setPreviousNodes(_previousNodes) {
    // tail is not head, we have a separate test for that
    vm.assume(_previousNodes > 1);

    bytes32 _removedNode = list.tail;
    uint256 _previousNodeUint = _previousNodes - 1;
    IHubStorage.Invoice memory _previousInvoice = IHubStorage.Invoice({
      intentId: keccak256(abi.encode(_previousNodeUint)),
      owner: vm.addr(_previousNodeUint).toBytes32(),
      entryEpoch: uint48(_previousNodeUint),
      amount: 10
    });
    bytes32 _previousNode = keccak256(abi.encode(_previousInvoice, _previousNodeUint));
    bytes32 _expectedHead = list.head;

    list.remove({_id: _removedNode, _previousId: _previousNode});

    assertEq(list.head, _expectedHead, 'incorrect head');
    assertEq(list.tail, _previousNode, 'incorrect tail');
    assertEq(list.length, _previousNodes - 1, 'incorrect length');
    assertEq(list.nodes[_removedNode].invoice.intentId, 0, 'node not deleted');
    assertEq(list.nodes[_removedNode].next, 0, 'node not deleted');
    assertEq(list.nodes[_previousNode].next, 0, 'next for new tail is not 0');
  }

  /**
   * @notice Test removing the only node from the list of size 1
   * @param _invoice the invoice to be removed
   */
  function test_TailAndHead(
    IHubStorage.Invoice calldata _invoice
  ) public {
    vm.assume(_invoice.intentId != 0);
    // Node to be removed is tail and head
    list.append(_invoice);

    bytes32 _removedNode = list.head;
    bytes32 _previousNode = 0;

    list.remove({_id: _removedNode, _previousId: _previousNode});

    assertEq(list.head, 0, 'incorrect head');
    assertEq(list.tail, 0, 'incorrect tail');
    assertEq(list.length, 0, 'incorrect length');
    assertEq(list.nodes[_removedNode].invoice.intentId, 0, 'node not deleted');
    assertEq(list.nodes[_removedNode].next, 0, 'node not deleted');
  }

  /**
   * @notice Test removing a node from the middle of the list
   * @param _previousNodes the number of previous nodes
   * @param _removedNodeUint the node to be removed
   */
  function test_Middle(uint8 _previousNodes, uint8 _removedNodeUint) public setPreviousNodes(_previousNodes) {
    vm.assume(_previousNodes > 2);
    vm.assume(_removedNodeUint > 1 && _removedNodeUint < _previousNodes);

    uint256 _previousNodeUint = _removedNodeUint - 1;
    IHubStorage.Invoice memory _previousInvoice = IHubStorage.Invoice({
      intentId: keccak256(abi.encode(_previousNodeUint)),
      owner: vm.addr(_previousNodeUint).toBytes32(),
      entryEpoch: uint48(_previousNodeUint),
      amount: 10
    });
    bytes32 _previousNode = keccak256(abi.encode(_previousInvoice, _previousNodeUint));

    IHubStorage.Invoice memory _removedInvoice = IHubStorage.Invoice({
      intentId: keccak256(abi.encode(_removedNodeUint)),
      owner: vm.addr(_removedNodeUint).toBytes32(),
      entryEpoch: uint48(_removedNodeUint),
      amount: 10
    });
    bytes32 _removedNode = keccak256(abi.encode(_removedInvoice, _removedNodeUint));

    bytes32 _expectedNextForPreviousNode = list.nodes[_removedNode].next;
    bytes32 _expectedHead = list.head;
    bytes32 _expectedTail = list.tail;

    list.remove({_id: _removedNode, _previousId: _previousNode});

    assertEq(list.length, _previousNodes - 1, 'incorrect length');
    assertEq(list.nodes[_removedNode].invoice.intentId, 0, 'node not deleted');
    assertEq(list.nodes[_removedNode].next, 0, 'node not deleted');
    assertEq(list.nodes[_previousNode].next, _expectedNextForPreviousNode, 'incorrect next for previous node');
    assertEq(list.head, _expectedHead, 'incorrect head');
    assertEq(list.tail, _expectedTail, 'incorrect tail');
  }

  /**
   * @notice Test removing a node that does not exist
   * @param _previousNodes the number of previous nodes
   * @param _nodeUint the node to be removed
   */
  function test_Revert_NodeNotFound(uint8 _previousNodes, uint8 _nodeUint) public setPreviousNodes(_previousNodes) {
    vm.assume(_nodeUint > _previousNodes);
    IHubStorage.Invoice memory _invoice = IHubStorage.Invoice({
      intentId: keccak256(abi.encode(_nodeUint)),
      owner: vm.addr(_nodeUint).toBytes32(),
      entryEpoch: uint48(_nodeUint),
      amount: 10
    });
    bytes32 _nodeId = keccak256(abi.encode(_invoice, _nodeUint));

    vm.expectRevert(abi.encodeWithSelector(InvoiceListLib.InvoiceList_NotFound.selector, _nodeId));
    list.remove(_nodeId, 0);
  }

  /**
   * @notice Test removing a node with an invalid previous id
   * @param _previousNodes the number of previous nodes
   * @param _nodeUint the node to be removed
   * @param _invalidPreviousNodeUint the invalid previous node
   */
  function test_Revert_InvalidPreviousId(
    uint8 _previousNodes,
    uint8 _nodeUint,
    uint8 _invalidPreviousNodeUint
  ) public setPreviousNodes(_previousNodes) {
    vm.assume(_nodeUint > 1 && _nodeUint <= _previousNodes);
    vm.assume(_invalidPreviousNodeUint != _nodeUint - 1);
    vm.assume(_invalidPreviousNodeUint > 0);

    IHubStorage.Invoice memory _invoice = IHubStorage.Invoice({
      intentId: keccak256(abi.encode(_nodeUint)),
      owner: vm.addr(_nodeUint).toBytes32(),
      entryEpoch: uint48(_nodeUint),
      amount: 10
    });
    bytes32 _nodeId = keccak256(abi.encode(_invoice, _nodeUint));

    IHubStorage.Invoice memory _invalidPreviousInvoice = IHubStorage.Invoice({
      intentId: keccak256(abi.encode(_invalidPreviousNodeUint)),
      owner: vm.addr(_invalidPreviousNodeUint).toBytes32(),
      entryEpoch: uint48(_invalidPreviousNodeUint),
      amount: 10
    });
    bytes32 _previousId = keccak256(abi.encode(_invalidPreviousInvoice, _invalidPreviousNodeUint));

    vm.expectRevert(abi.encodeWithSelector(InvoiceListLib.InvoiceList_Remove_InvalidPreviousId.selector, _previousId));
    list.remove(_nodeId, _previousId);
  }

  /**
   * @notice Test removing a node with an invalid previous id
   * @param _invoice the invoice to be removed
   * @param _previousId the previous node id
   */
  function test_Revert_HeadTail_InvalidPreviousId_NotZero(
    IHubStorage.Invoice calldata _invoice,
    bytes32 _previousId
  ) public {
    vm.assume(_invoice.intentId != 0 && _previousId != 0);
    list.append(_invoice);
    bytes32 _nodeId = list.head;

    vm.expectRevert(abi.encodeWithSelector(InvoiceListLib.InvoiceList_Remove_InvalidPreviousId.selector, _previousId));
    list.remove(_nodeId, _previousId);
  }
}

contract Unit_At is BaseTest {
  using InvoiceListLib for InvoiceListLib.InvoiceList;
  using TypeCasts for address;

  /**
   * @notice Test getting a node from the list
   * @param _previousNodes the number of previous nodes
   * @param _nodeAtUint the node to get
   */
  function test_At(uint8 _previousNodes, uint8 _nodeAtUint) public setPreviousNodes(_previousNodes) {
    vm.assume(_nodeAtUint > 0 && _nodeAtUint <= _previousNodes);

    bytes32 _intentId = keccak256(abi.encode(_nodeAtUint));
    IHubStorage.Invoice memory _invoice = IHubStorage.Invoice({
      intentId: _intentId,
      owner: vm.addr(_nodeAtUint).toBytes32(),
      entryEpoch: uint48(_nodeAtUint),
      amount: 10
    });
    bytes32 _nodeId = keccak256(abi.encode(_invoice, _nodeAtUint));

    IHubStorage.Invoice memory _nextInvoice = IHubStorage.Invoice({
      intentId: keccak256(abi.encode(_nodeAtUint + 1)),
      owner: vm.addr(_nodeAtUint + 1).toBytes32(),
      entryEpoch: uint48(_nodeAtUint + 1),
      amount: 10
    });
    bytes32 _expectedNext =
      _nodeAtUint == _previousNodes ? bytes32(0) : keccak256(abi.encode(_nextInvoice, _nodeAtUint + 1));
    InvoiceListLib.Node memory _node = list.at(_nodeId);

    assertEq(_node.invoice.intentId, _intentId, 'incorrect intentId');
    assertEq(_node.next, _expectedNext, 'incorrect next');
  }

  /**
   * @notice Test getting a node that does not exist
   * @param _previousNodes the number of previous nodes
   * @param _nodeUint the node to get
   */
  function test_Revert_NodeNotFound(uint8 _previousNodes, uint8 _nodeUint) public setPreviousNodes(_previousNodes) {
    vm.assume(_nodeUint > _previousNodes);
    IHubStorage.Invoice memory _notFoundInvoice = IHubStorage.Invoice({
      intentId: keccak256(abi.encode(_nodeUint)),
      owner: vm.addr(_nodeUint).toBytes32(),
      entryEpoch: uint48(_nodeUint),
      amount: 10
    });
    bytes32 _nodeId = keccak256(abi.encode(_notFoundInvoice, _nodeUint));

    vm.expectRevert(abi.encodeWithSelector(InvoiceListLib.InvoiceList_NotFound.selector, _nodeId));
    list.at(_nodeId);
  }
}

contract Unit_Iteration is BaseTest {
  using InvoiceListLib for InvoiceListLib.InvoiceList;

  /**
   * @notice Test iterating over the list
   * @param _previousNodes the number of previous nodes
   */
  function test_Iterate(
    uint8 _previousNodes
  ) public setPreviousNodes(_previousNodes) {
    InvoiceListLib.Node memory _current = list.at(list.head);
    uint256 _count = 1;
    while (_current.next != 0) {
      _count += 1;
      _current = list.at(_current.next);
    }
    assertEq(_count, _previousNodes, 'incorrect count');
    assertEq(_current.next, 0, 'incorrect next for last node');
    assertEq(list.length, _count, 'incorrect length');
  }
}
