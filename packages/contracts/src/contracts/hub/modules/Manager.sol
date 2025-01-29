// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IManager} from 'interfaces/hub/IManager.sol';

import {AssetManager} from 'contracts/hub/modules/managers/AssetManager.sol';
import {ProtocolManager} from 'contracts/hub/modules/managers/ProtocolManager.sol';
import {UsersManager} from 'contracts/hub/modules/managers/UsersManager.sol';

contract Manager is ProtocolManager, UsersManager, AssetManager, IManager {}
