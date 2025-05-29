// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Strings} from '@openzeppelin/contracts/utils/Strings.sol';
import {Script} from 'forge-std/Script.sol';
import {stdJson} from 'forge-std/StdJson.sol';

abstract contract Artifacts is Script {
  function _saveHubArtifacts(
    uint32 _domain,
    address _hub,
    address _gateway,
    address _ism,
    uint256 _timestamp,
    uint256 _block
  ) internal {
    string memory _root = vm.projectRoot();
    string memory _artifacts = string.concat(_root, '/deployments/staging/', Strings.toString(_domain));

    string memory _baseObject = 'base_key';
    vm.serializeUint(_baseObject, 'domain', _domain);
    vm.serializeUint(_baseObject, 'timestamp', _timestamp);
    vm.serializeUint(_baseObject, 'block', _block);
    vm.serializeString(_baseObject, 'type', 'hub');

    string memory _contractsObject = 'contracts_key';

    vm.serializeString(_contractsObject, 'EverclearHub', Strings.toHexString(_hub));
    vm.serializeString(_contractsObject, 'HubGateway', Strings.toHexString(_gateway));
    string memory _final = vm.serializeString(_contractsObject, 'InterchainSecurityModule', Strings.toHexString(_ism));

    string memory _finalJson = vm.serializeString(_baseObject, 'contracts', _final);

    // if 'latest' exists, replace its name with its timestamp
    try vm.readFile(string.concat(_artifacts, '/latest.json')) returns (string memory _content) {
      vm.removeFile(string.concat(_artifacts, '/latest.json'));
      uint256 _latestTimestamp = stdJson.readUint(_content, '.timestamp');
      vm.writeFile(string.concat(_artifacts, '/', Strings.toString(_latestTimestamp), '.json'), _content);
    } catch (bytes memory) {}

    // save latest
    vm.writeJson(_finalJson, string.concat(_artifacts, '/latest.json'));
  }

  function _saveSpokeArtifacts(
    uint32 _domain,
    address _spoke,
    address _gateway,
    address _executor,
    address _ism,
    uint256 _timestamp,
    uint256 _block
  ) internal {
    string memory _root = vm.projectRoot();
    string memory _artifacts = string.concat(_root, '/deployments/staging/', Strings.toString(_domain));

    string memory _baseObject = 'base_key';
    vm.serializeUint(_baseObject, 'domain', _domain);
    vm.serializeUint(_baseObject, 'timestamp', _timestamp);
    vm.serializeUint(_baseObject, 'block', _block);
    vm.serializeString(_baseObject, 'type', 'spoke');

    string memory _contractsObject = 'contracts_key';

    vm.serializeString(_contractsObject, 'EverclearSpoke', Strings.toHexString(_spoke));
    vm.serializeString(_contractsObject, 'SpokeGateway', Strings.toHexString(_gateway));
    vm.serializeString(_contractsObject, 'CallExecutor', Strings.toHexString(_executor));
    string memory _final = vm.serializeString(_contractsObject, 'InterchainSecurityModule', Strings.toHexString(_ism));

    string memory _finalJson = vm.serializeString(_baseObject, 'contracts', _final);

    // if 'latest' exists, replace its name with its timestamp
    try vm.readFile(string.concat(_artifacts, '/latest.json')) returns (string memory _content) {
      vm.removeFile(string.concat(_artifacts, '/latest.json'));
      uint256 _latestTimestamp = stdJson.readUint(_content, '.timestamp');
      vm.writeFile(string.concat(_artifacts, '/', Strings.toString(_latestTimestamp), '.json'), _content);
    } catch (bytes memory) {}

    // save latest
    vm.writeJson(_finalJson, string.concat(_artifacts, '/latest.json'));
  }
}
