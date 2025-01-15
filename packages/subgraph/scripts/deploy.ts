#!/usr/bin/env node
/* eslint-disable @typescript-eslint/no-explicit-any */
import { Command } from 'commander';
const program = new Command();

import { config as dotenvConfig } from 'dotenv';
dotenvConfig();

import { readFileSync, writeFileSync } from 'fs';
import YAML from 'yaml';
import yamlToJson from 'js-yaml';
import { build, deploySubgraph } from './thegraph';

const ARTIFACTS_PREFIX = `../contracts/deployments`;

export type Network = {
  subgraphName: string;
  network: string;
  domain: string;
  environment: 'local' | 'staging' | 'production';
  indexers: string[];
  source: [
    {
      name: string; // should align with name stored in artifacts
    },
  ];
};

const supportedIndexers = ['hosted', 'studio', 'goldsky', 'bware', 'local'];

program
  .argument('<name>', 'Subgraph Name')
  .option('-v, --version <value>', 'Subgraph Version v0, v1,... staging, local-v0...', 'v0')
  .option('-n, --networks <value...>', 'Network name. all | mainnet optimism ...', 'all')
  .option('-l, --label <value>', 'Subgrpah version label. v0.0.1, v0.0.2...', '')
  .option('-d, --deploy <value>', 'deploy to network?', 'true')
  .option('-i, --indexers <value...>', 'Indexers. all | studio', 'all')
  .action(async function (name) {
    const options = program.opts();
    console.log(options);
    console.info('Run deploy %s subgaph: version %s, networks: %s', name, options.version, options.networks);

    // first argument is subgraph name: chimera-hub, chimera-spoke...
    const subgraphName = name;
    // first option argument is version: v0, v1, v2... staging...
    // version argument should include `local` for local subgraph. local-v0, local-v1...
    const version = options.version;
    // second argument is networks: all | "<network1 network2 ...>"
    const networks = options.networks;
    // check if deploy
    const deploy = options.deploy === 'true';
    // Subgrpah version label. required in studio and goldsky.
    const label = options.label || '';
    // Indexers
    const indexers = options.indexers === 'all' ? supportedIndexers : options.indexers;

    // validate command args

    // Get networks from config
    const configFile = `${subgraphName}-${version}.json`;

    const configNetworks: Network[] = JSON.parse(readFileSync(`./config/${configFile}`, 'utf8'));

    // Get network names
    const networkNames: string[] =
      networks.length === 1 && networks[0].toUpperCase() === 'ALL'
        ? configNetworks.map((n) => n.network)
        : networks.filter((n: string) => n.toUpperCase() !== 'ALL');

    const networksToDeploy = networkNames.map((n) => {
      const res = configNetworks.find((e) => e.network.toUpperCase() === n.toUpperCase());
      if (!res) {
        throw new Error(`Network (${n}) not found`);
      }
      return res;
    });

    const templateJsonFile: any = yamlToJson.load(readFileSync(`./src/${subgraphName}/subgraph.template.yaml`, 'utf8'));

    for (const n of networksToDeploy) {
      const { environment, domain, network } = n;
      // Generate the artifact prefix
      const prefix = `${ARTIFACTS_PREFIX}/${environment}/${domain}`;

      /// prepare
      templateJsonFile.dataSources = await Promise.all(
        (templateJsonFile.dataSources ?? []).map(async (ds: any) => {
          // Generate the mappings
          const abis = ds.mapping.abis.map((a: { file: string; name: string }) => {
            return { name: a.name, file: `${prefix}/${a.name}.json` };
          });
          // Parse the artifacts
          const artifact: { address: string; abi: object[]; startBlock: number } = JSON.parse(
            readFileSync(`${prefix}/${ds.name}.json`, 'utf8') ?? '{}',
          );
          if (!artifact.address || !artifact.startBlock) {
            throw new Error(`Artifact for ${ds.name} not found`);
          }
          return {
            ...ds,
            network: network,
            mapping: {
              ...ds.mapping,
              abis,
            },
            source: {
              ...ds.source,
              address: artifact.address,
              startBlock: artifact.startBlock,
            },
          };
        }),
      );

      templateJsonFile.dataSources = templateJsonFile.dataSources.filter((s: any) => !!s);
      if (templateJsonFile.templates) {
        templateJsonFile.templates = (templateJsonFile.templates ?? []).map((ds: any) => {
          return {
            ...ds,
            network: n.network,
          };
        });
      }

      const yamlDoc = new YAML.Document();
      yamlDoc.contents = JSON.parse(JSON.stringify(templateJsonFile));
      writeFileSync('./subgraph.yaml', yamlDoc.toString());

      console.log('Running Build command for ' + n.network);
      await build();

      /// deploy
      if (!deploy || version.includes('devnet')) {
        console.log('Skipping deployments...');
      } else {
        console.log('Running Deployment command for ' + n.network + ' with indexers: ' + n.indexers);
        for (const indexer of n.indexers) {
          if (indexers.includes(indexer) && supportedIndexers.includes(indexer)) {
            await deploySubgraph(n.subgraphName, version, label, indexer);
          }
        }
      }
    }
  });

program.parse();
