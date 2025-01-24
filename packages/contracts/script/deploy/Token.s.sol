// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';
import {ERC20} from 'solmate/src/tokens/ERC20.sol';

interface IXERC20Factory {
  function deployXERC20(
    string memory _name,
    string memory _symbol,
    uint256[] memory _minterLimits,
    uint256[] memory _burnerLimits,
    address[] memory _bridges
  ) external returns (address _xerc20);
}

contract TestToken is ERC20 {
  constructor(string memory _name, string memory _symbol, uint8 _decimals) ERC20(_name, _symbol, _decimals) {
    _mint(msg.sender, 1_000_000 * 10 ** _decimals);
  }
}

contract Deploy is Script {
  uint8 public _decimals = 18;
  bool public _useXERC20 = false;
  string public _name = 'Test Token';
  string public _symbol = 'TT';

  address public DEFAULT_FACTORY_ADDRESS = address(0xb913bE186110B1119d5B9582F316f142c908fc25);

  mapping(uint256 => address) public _xerc20Factories;

  error XERC20FactoryNotFound();

  function setUp() public {
    _loadXERC20FactoryMapping();
  }

  function _loadXERC20FactoryMapping() private {
    // Deployed XERC20 factories can be found:
    // https://github.com/connext/xERC20/tree/main/broadcast/XERC20FactoryDeploy.sol
    // BSC testnet had to be deployed specifically
    _xerc20Factories[97] = address(0x2C1Abe81f0f1A4176F39A216d074ed77aC9CD447);
  }

  function _collectUserInput() private {
    try vm.parseUint(vm.prompt('Decimals (18)')) returns (uint256 _res) {
      _decimals = uint8(_res);
    } catch (bytes memory) {}

    try vm.parseBool(vm.prompt('Use XERC20 (false)')) returns (bool _res) {
      _useXERC20 = _res;
    } catch (bytes memory) {}

    try vm.prompt('Name (TestToken)') returns (string memory _res) {
      _name = _res;
    } catch (bytes memory) {}

    try vm.prompt('Symbol (TT)') returns (string memory _res) {
      _symbol = _res;
    } catch (bytes memory) {}
  }

  function run() public {
    _collectUserInput();

    uint256 _deployerPk = vm.envUint('DEPLOYER_PK');

    vm.startBroadcast(_deployerPk);
    address _tokenAddress;
    if (_useXERC20) {
      address _factory = _xerc20Factories[block.chainid];
      if (_factory == address(0)) {
        _factory = DEFAULT_FACTORY_ADDRESS;
        if (_factory.code.length == 0) {
          revert XERC20FactoryNotFound();
        }
      }
      // Deploy the XERC20
      // NOTE: no bridges registered
      address[] memory _bridges = new address[](0);
      uint256[] memory _burnLimits = new uint256[](0);
      uint256[] memory _mintLimits = new uint256[](0);
      _tokenAddress = IXERC20Factory(_factory).deployXERC20(_name, _symbol, _mintLimits, _burnLimits, _bridges);
    } else {
      ERC20 _token = new TestToken(_name, _symbol, _decimals);
      _tokenAddress = address(_token);
    }

    vm.stopBroadcast();

    console.log('Token address:', _tokenAddress);
  }
}
