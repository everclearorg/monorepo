// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IEverclear} from 'interfaces/common/IEverclear.sol';

import {IAssetManager} from 'interfaces/hub/IAssetManager.sol';
import {IProtocolManager} from 'interfaces/hub/IProtocolManager.sol';
import {IUsersManager} from 'interfaces/hub/IUsersManager.sol';

interface IManager is IAssetManager, IUsersManager, IProtocolManager, IEverclear {}
