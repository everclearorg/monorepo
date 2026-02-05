import * as c from '../common';
import { Deployments } from '../../deployments';
import { createPublicClient, http } from 'viem';

// define the relevant abi
const OwnableAbi = [
  {
    type: 'function',
    name: 'owner',
    inputs: [],
    outputs: [
      {
        name: '',
        type: 'address',
        internalType: 'address',
      },
    ],
    stateMutability: 'view',
  },
];

const EVERCLEAR_CONFIG_URL = 'https://raw.githubusercontent.com/connext/chaindata/main/everclear.json';

type EverclearConfig = {
  hub: {
    domain: string;
    providers: string[];
  };
  chains: Record<string, { providers: string[] }>;
};
type HubDeployments = {
  everclear: { address: string };
  gateway: { address: string };
  gauge: { address: string };
  rewardDistributor: { address: string };
  tokenomicsHubGateway: { address: string };
};
const getConfig = async (): Promise<EverclearConfig> => {
  const res = await fetch(EVERCLEAR_CONFIG_URL);
  return res.json();
};

export async function logOwners() {
  // choose environment (production or staging)
  const environment = await c.chooseEnvironment();

  // get deployments key
  const key = environment.toLowerCase().includes('production') ? 'production' : 'staging';

  // get the chaindata
  const chaindata = await getConfig();
  const hubDomain = chaindata.hub.domain;

  // get the supported domains from config
  const supported = Object.keys(chaindata.chains).concat([hubDomain]);

  for (const [domain, deployments] of Object.entries(Deployments[key])) {
    if (!supported.includes(domain)) {
      continue;
    }
    const isHub = domain === hubDomain;
    const providerUri = isHub ? chaindata.hub.providers[0] : chaindata.chains[domain].providers[0];
    const client = createPublicClient({
      transport: http(providerUri),
    });
    try {
      const owner = await client.readContract({
        address: deployments.everclear.address as `0x${string}`,
        abi: OwnableAbi,
        functionName: 'owner',
      });
      console.log(`\nLogging owner for :`, domain);
      console.log(`\t Everclear owner  :`, owner);
    } catch (e) {
      console.warn('\t Unable to get everclear owner for domain ' + domain);
    }

    try {
      const owner = await client.readContract({
        address: deployments.gateway.address as `0x${string}`,
        abi: OwnableAbi,
        functionName: 'owner',
      });
      console.log(`\t Gateway owner    :`, owner);
    } catch (e) {
      console.warn('\t Unable to get gateway owner for domain ' + domain);
    }

    if (!isHub) {
      continue;
    }

    // otherwise, log more owners
    try {
      const owner = await client.readContract({
        address: (deployments as HubDeployments).gauge.address as `0x${string}`,
        abi: OwnableAbi,
        functionName: 'owner',
      });
      console.log(`\t Gauge owner      :`, owner);
    } catch (e) {
      console.warn('\t Unable to get gauge owner for domain ' + domain);
    }

    try {
      const owner = await client.readContract({
        address: (deployments as HubDeployments).rewardDistributor.address as `0x${string}`,
        abi: OwnableAbi,
        functionName: 'owner',
      });
      console.log(`\t Distributor owner:`, owner);
    } catch (e) {
      console.warn('\t Unable to get distributor owner for domain ' + domain);
    }

    try {
      const owner = await client.readContract({
        address: (deployments as HubDeployments).tokenomicsHubGateway.address as `0x${string}`,
        abi: OwnableAbi,
        functionName: 'owner',
      });
      console.log(`\t Tokenomics owner :`, owner);
    } catch (e) {
      console.warn('\t Unable to get tokenomics gateway owner for domain ' + domain);
    }
  }
}
