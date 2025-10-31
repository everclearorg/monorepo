// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IEverclearV2} from 'interfaces/common/IEverclearV2.sol';

import {IAssetManagerV2} from 'interfaces/hub/IAssetManagerV2.sol';
import {IProtocolManagerV2} from 'interfaces/hub/IProtocolManagerV2.sol';
import {IUsersManager} from 'interfaces/hub/IUsersManager.sol';

interface IManagerV2 is IAssetManagerV2, IUsersManager, IProtocolManagerV2, IEverclearV2 {}
