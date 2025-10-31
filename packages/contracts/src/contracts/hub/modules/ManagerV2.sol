// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IManagerV2} from 'interfaces/hub/IManagerV2.sol';

import {AssetManagerV2} from 'contracts/hub/modules/managers/AssetManagerV2.sol';
import {ProtocolManagerV2} from 'contracts/hub/modules/managers/ProtocolManagerV2.sol';
import {UsersManagerV2} from 'contracts/hub/modules/managers/UsersManagerV2.sol';

contract ManagerV2 is ProtocolManagerV2, UsersManagerV2, AssetManagerV2, IManagerV2 {}
