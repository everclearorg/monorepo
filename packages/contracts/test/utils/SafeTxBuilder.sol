// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import 'forge-std/Test.sol';

contract SafeTxBuilder is Test {
  string constant CREATED_FROM_SAFE_ADDRESS = '';
  string constant CREATED_FROM_OWNER_ADDRESS = '';
  WriteTransaction[] public safeTransactions;

  struct WriteTransaction {
    uint256 value;
    address target;
    bytes data;
  }

  struct SafeMeta {
    string name;
    string description;
    string txBuilderVersion;
    string createdFromSafeAddress;
    string createdFromOwnerAddress;
  }

  struct SafeInputHeader {
    string version;
    string chainId;
    uint256 createdAt;
    SafeMeta meta;
  }

  function _createTransaction(
    uint256 _value,
    address _target,
    bytes memory _calldata
  ) internal pure returns (WriteTransaction memory _transaction) {
    _transaction = WriteTransaction({value: _value, target: _target, data: _calldata});
  }

  function _getJsonTxInfo(
    SafeInputHeader memory _header,
    WriteTransaction[] memory _transactions
  ) internal returns (string memory _batchJson) {
    // Building the tx info and meta
    string memory json1 = '';
    vm.serializeString(json1, 'version', _header.version);
    vm.serializeString(json1, 'chainId', _header.chainId);
    vm.serializeString(json1, 'createdAt', vm.toString(_header.createdAt));

    string memory json2 = 'meta';
    string memory output = vm.serializeString(json2, 'name', _header.meta.name);
    output = vm.serializeString(json2, 'description', _header.meta.description);
    output = vm.serializeString(json2, 'txBuilderVersion', _header.meta.txBuilderVersion);
    output = vm.serializeString(json2, 'createdFromSafeAddress', _header.meta.createdFromSafeAddress);
    output = vm.serializeString(json2, 'createdFromOwnerAddress', _header.meta.createdFromOwnerAddress);

    // Building the tx input
    string[] memory txInput = _getTransactionInput(_transactions);

    // Building the final json
    _batchJson = vm.serializeString(json1, 'meta', output);
    _batchJson = vm.serializeString(json1, 'transactions', txInput);
  }

  function _getSafeInputMeta(
    string memory description
  ) internal pure returns (SafeMeta memory _meta) {
    _meta = SafeMeta({
      name: 'Transactions Batch',
      description: description,
      txBuilderVersion: '1.16.5',
      createdFromSafeAddress: CREATED_FROM_SAFE_ADDRESS,
      createdFromOwnerAddress: CREATED_FROM_OWNER_ADDRESS
    });
  }

  function _getTransactionInput(
    WriteTransaction[] memory _transactions
  ) internal pure returns (string[] memory _transactionsArray) {
    // Building the transaction array
    _transactionsArray = new string[](_transactions.length);
    for (uint256 i = 0; i < _transactions.length; i++) {
      WriteTransaction memory safeTx = _transactions[i];
      // Concatenat the information
      string memory txInput = string.concat(
        '{"to": "', vm.toString(safeTx.target), '", "value": "', '0', '", "data": "', vm.toString(safeTx.data), '"}'
      );
      _transactionsArray[i] = txInput;
    }
  }

  function _getSafeInputHeader(
    string memory description,
    string memory chainId
  ) internal view returns (SafeInputHeader memory _header) {
    SafeMeta memory _meta = _getSafeInputMeta(description);
    _header = SafeInputHeader({version: '1.0', chainId: chainId, createdAt: block.timestamp * 1000, meta: _meta});
  }

  function _writeSafeTransactionInput(
    string memory filename,
    string memory description,
    WriteTransaction[] memory _transactions,
    string memory chainId
  ) internal {
    string memory batchJson = _getJsonTxInfo(_getSafeInputHeader(description, chainId), _transactions);
    vm.writeJson(batchJson, filename);
  }
}
