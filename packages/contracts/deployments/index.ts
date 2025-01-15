//////// Testnet Staging Deployments ////////
import StagingEverclearHubEverclearSepolia from './staging/6398/EverclearHub.json';
import StagingHubGatewayEverclearSepolia from './staging/6398/HubGateway.json';

import StagingEverclearSpokeSepolia from './staging/11155111/EverclearSpoke.json';
import StagingSpokeGatewaySepolia from './staging/11155111/SpokeGateway.json';

import StagingEverclearSpokeBscTestnet from './staging/97/EverclearSpoke.json';
import StagingSpokeGatewayBscTestnet from './staging/97/SpokeGateway.json';

import StagingEverclearSpokeOptimismSepolia from './staging/11155420/EverclearSpoke.json';
import StagingSpokeGatewayOptimismSepolia from './staging/11155420/SpokeGateway.json';

import StagingEverclearSpokeArbitrumSepolia from './staging/421614/EverclearSpoke.json';
import StagingSpokeGatewayArbitrumSepolia from './staging/421614/SpokeGateway.json';

//////// Testnet Production Deployments ////////
import ProductionEverclearHubEverclearSepolia from './production/6398/EverclearHub.json';
import ProductionHubGatewayEverclearSepolia from './production/6398/HubGateway.json';

import ProductionTokenomicsHubGaugeEverclearSepolia from './production/6398/HubGauge.json';
import ProductionTokenomicsRewardDistributorEverclearSepolia from './production/6398/RewardDistributor.json';
import ProductionTokenomicsHubGatewayEverclearSepolia from './production/6398/TokenomicsHubGateway.json';

import ProductionEverclearSpokeBscTestnet from './production/97/EverclearSpoke.json';
import ProductionSpokeGatewayBscTestnet from './production/97/SpokeGateway.json';

import ProductionEverclearSpokeSepolia from './production/11155111/EverclearSpoke.json';
import ProductionSpokeGatewaySepolia from './production/11155111/SpokeGateway.json';

import ProductionEverclearSpokeOptimismSepolia from './production/11155420/EverclearSpoke.json';
import ProductionSpokeGatewayOptimismSepolia from './production/11155420/SpokeGateway.json';

import ProductionEverclearSpokeArbitrumSepolia from './production/421614/EverclearSpoke.json';
import ProductionSpokeGatewayArbitrumSepolia from './production/421614/SpokeGateway.json';

//////// Mainnet Staging Deployments ////////

import StagingEverclearHubEverclearMainnet from './staging/25327/EverclearHub.json';
import StagingHubGatewayEverclearMainnet from './staging/25327/HubGateway.json';

import StagingEverclearSpokeOptimism from './staging/10/EverclearSpoke.json';
import StagingSpokeGatewayOptimism from './staging/10/SpokeGateway.json';

import StagingEverclearSpokeArbitrumOne from './staging/42161/EverclearSpoke.json';
import StagingSpokeGatewayArbitrumOne from './staging/42161/SpokeGateway.json';

import StagingEverclearSpokeZircuit from './staging/48900/EverclearSpoke.json';
import StagingSpokeGatewayZircuit from './staging/48900/SpokeGateway.json';

import StagingEverclearSpokeBlast from './staging/81457/EverclearSpoke.json';
import StagingSpokeGatewayBlast from './staging/81457/SpokeGateway.json';

//////// Mainnet Production Deployments ////////

import ProductionEverclearHubEverclearMainnet from './production/25327/EverclearHub.json';
import ProductionHubGatewayEverclearMainnet from './production/25327/HubGateway.json';

import ProductionTokenomicsHubGaugeEverclearMainnet from './production/25327/HubGauge.json';
import ProductionTokenomicsRewardDistributorEverclearMainnet from './production/25327/RewardDistributor.json';
import ProductionTokenomicsHubGatewayEverclearMainnet from './production/25327/TokenomicsHubGateway.json';

import ProductionEverclearSpokeBscMainnet from './production/56/EverclearSpoke.json';
import ProductionSpokeGatewayBscMainnet from './production/56/SpokeGateway.json';

import ProductionEverclearSpokeEthereum from './production/1/EverclearSpoke.json';
import ProductionSpokeGatewayEthereum from './production/1/SpokeGateway.json';

import ProductionEverclearSpokeOptimism from './production/10/EverclearSpoke.json';
import ProductionSpokeGatewayOptimism from './production/10/SpokeGateway.json';

import ProductionEverclearSpokeArbitrumOne from './production/42161/EverclearSpoke.json';
import ProductionSpokeGatewayArbitrumOne from './production/42161/SpokeGateway.json';

import ProductionEverclearSpokeBase from './production/8453/EverclearSpoke.json';
import ProductionSpokeGatewayBase from './production/8453/SpokeGateway.json';

import ProductionEverclearSpokeZircuit from './production/48900/EverclearSpoke.json';
import ProductionSpokeGatewayZircuit from './production/48900/SpokeGateway.json';

import ProductionEverclearSpokeBlast from './production/81457/EverclearSpoke.json';
import ProductionSpokeGatewayBlast from './production/81457/SpokeGateway.json';

export const Deployments = {
  local: {},
  production: {
    //////// Testnet Production Deployments ////////
    6398: {
      everclear: ProductionEverclearHubEverclearSepolia,
      gateway: ProductionHubGatewayEverclearSepolia,
      gauge: ProductionTokenomicsHubGaugeEverclearSepolia,
      rewardDistributor: ProductionTokenomicsRewardDistributorEverclearSepolia,
      tokenomicsHubGateway: ProductionTokenomicsHubGatewayEverclearSepolia,
    },
    11155111: {
      everclear: ProductionEverclearSpokeSepolia,
      gateway: ProductionSpokeGatewaySepolia,
    },
    97: {
      everclear: ProductionEverclearSpokeBscTestnet,
      gateway: ProductionSpokeGatewayBscTestnet,
    },
    421614: {
      everclear: ProductionEverclearSpokeArbitrumSepolia,
      gateway: ProductionSpokeGatewayArbitrumSepolia,
    },
    11155420: {
      everclear: ProductionEverclearSpokeOptimismSepolia,
      gateway: ProductionSpokeGatewayOptimismSepolia,
    },
    //////// Mainnet Production Deployments ////////
    25327: {
      everclear: ProductionEverclearHubEverclearMainnet,
      gateway: ProductionHubGatewayEverclearMainnet,
      gauge: ProductionTokenomicsHubGaugeEverclearMainnet,
      rewardDistributor: ProductionTokenomicsRewardDistributorEverclearMainnet,
      tokenomicsHubGateway: ProductionTokenomicsHubGatewayEverclearMainnet,
    },
    1: {
      everclear: ProductionEverclearSpokeEthereum,
      gateway: ProductionSpokeGatewayEthereum,
    },
    56: {
      everclear: ProductionEverclearSpokeBscMainnet,
      gateway: ProductionSpokeGatewayBscMainnet,
    },
    42161: {
      everclear: ProductionEverclearSpokeArbitrumOne,
      gateway: ProductionSpokeGatewayArbitrumOne,
    },
    10: {
      everclear: ProductionEverclearSpokeOptimism,
      gateway: ProductionSpokeGatewayOptimism,
    },
    8453: {
      everclear: ProductionEverclearSpokeBase,
      gateway: ProductionSpokeGatewayBase,
    },
    48900: {
      everclear: ProductionEverclearSpokeZircuit,
      gateway: ProductionSpokeGatewayZircuit,
    },
    81457: {
      everclear: ProductionEverclearSpokeBlast,
      gateway: ProductionSpokeGatewayBlast,
    },
  },
  staging: {
    //////// Testnet Staging Deployments ////////
    6398: {
      everclear: StagingEverclearHubEverclearSepolia,
      gateway: StagingHubGatewayEverclearSepolia,
      // use the production values here instead for now
      gauge: ProductionTokenomicsHubGaugeEverclearSepolia,
      rewardDistributor: ProductionTokenomicsRewardDistributorEverclearSepolia,
      tokenomicsHubGateway: ProductionTokenomicsHubGatewayEverclearSepolia,
    },
    11155111: {
      everclear: StagingEverclearSpokeSepolia,
      gateway: StagingSpokeGatewaySepolia,
    },
    97: {
      everclear: StagingEverclearSpokeBscTestnet,
      gateway: StagingSpokeGatewayBscTestnet,
    },
    421614: {
      everclear: StagingEverclearSpokeArbitrumSepolia,
      gateway: StagingSpokeGatewayArbitrumSepolia,
    },
    11155420: {
      everclear: StagingEverclearSpokeOptimismSepolia,
      gateway: StagingSpokeGatewayOptimismSepolia,
    },

    //////// Mainnet Staging Deployments ////////
    25327: {
      everclear: StagingEverclearHubEverclearMainnet,
      gateway: StagingHubGatewayEverclearMainnet,
    },
    42161: {
      everclear: StagingEverclearSpokeArbitrumOne,
      gateway: StagingSpokeGatewayArbitrumOne,
    },
    10: {
      everclear: StagingEverclearSpokeOptimism,
      gateway: StagingSpokeGatewayOptimism,
    },
    48900: {
      everclear: StagingEverclearSpokeZircuit,
      gateway: StagingSpokeGatewayZircuit,
    },
    81457: {
      everclear: StagingEverclearSpokeBlast,
      gateway: StagingSpokeGatewayBlast,
    },
  },
};
