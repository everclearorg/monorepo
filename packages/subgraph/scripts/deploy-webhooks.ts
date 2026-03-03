import { readFileSync, writeFileSync, mkdtempSync, rmSync } from 'fs';
import { join } from 'path';
import { execSync } from 'child_process';
import { program } from 'commander';
import * as Mustache from 'mustache';
import { config as dotenvConfig } from 'dotenv';

dotenvConfig();

interface PipelineEntity {
  sourceId: string;
  entity: string;
  webhookName: string;
}

interface HubPipelineConfig {
  webhookName: string;
  subgraph: { name: string };
  webhookBaseUrl: string;
  secretName: string;
  entities: PipelineEntity[];
}

interface SpokePipelineConfig extends HubPipelineConfig {
  network: string;
  domain: string;
}

function loadTemplate(): string {
  return readFileSync(join(__dirname, '../src/cartographer-webhooks/webhook.template.yaml'), 'utf-8');
}

function renderPipeline(
  template: string,
  config: HubPipelineConfig,
  subgraphVersion: string,
  subgraphLabel: string,
): string {
  const view = {
    webhookName: config.webhookName,
    subgraphLabel: subgraphLabel.replace(/\./g, '-'),
    entities: config.entities.map((e) => ({
      ...e,
      subgraphName: config.subgraph.name,
      subgraphVersion,
      subgraphLabel,
      webhookBaseUrl: config.webhookBaseUrl,
      secretName: config.secretName,
      domain: (config as SpokePipelineConfig).domain,
    })),
  };

  return Mustache.render(template, view);
}

function executeCommand(cmd: string, dryRun: boolean): void {
  if (dryRun) {
    console.log(`[DRY RUN] Would execute: ${cmd}`);
    return;
  }

  console.log(`Executing: ${cmd}`);
  try {
    const output = execSync(cmd, { encoding: 'utf-8', stdio: 'pipe' });
    if (output.trim()) {
      console.log(output);
    }
  } catch (error) {
    console.error(`Command failed: ${error}`);
    throw error;
  }
}

function deployPipeline(yaml: string, pipelineName: string, dryRun: boolean): void {
  if (dryRun) {
    console.log(`\n--- Pipeline: ${pipelineName} ---`);
    console.log(yaml);
    console.log('--- End ---\n');
    return;
  }

  // Write YAML to a temp file
  const tmpDir = mkdtempSync('/tmp/goldsky-pipeline-');
  const tmpFile = join(tmpDir, `${pipelineName}.yaml`);

  try {
    writeFileSync(tmpFile, yaml);
    executeCommand(`goldsky pipeline apply ${tmpFile}`, false);
    console.log(`Successfully deployed pipeline: ${pipelineName}`);
  } finally {
    rmSync(tmpDir, { recursive: true, force: true });
  }
}

program
  .argument('<config-name>', 'Pipeline config name (e.g., everclear-hub-webhooks)')
  .option('-v, --version <value>', 'Config version (staging or production)', 'production')
  .option('-n, --networks <value...>', 'Network names to filter (spoke configs only)')
  .option('-s, --subgraph-label <value>', 'Subgraph label (e.g., v0.0.3)')
  .option('-d, --dry-run', 'Only output the resolved YAML without deploying', false)
  .action(async (configName: string) => {
    const options = program.opts();
    const version = options.version;
    const subgraphLabel = options.subgraphLabel;
    const dryRun = options.dryRun;
    const filterNetworks = options.networks;

    if (!subgraphLabel) {
      console.error('Error: --subgraph-label is required');
      process.exit(1);
    }

    const subgraphVersion = `${version}-${subgraphLabel}`;

    const configFile = `${configName}-${version}.json`;
    const configPath = join(__dirname, `../config/${configFile}`);

    console.log(`Loading config from: ${configPath}`);
    const configRaw = readFileSync(configPath, 'utf-8');
    const template = loadTemplate();

    // Determine if this is a hub config (object) or spoke config (array)
    const parsed = JSON.parse(configRaw);

    if (Array.isArray(parsed)) {
      // Spoke configs - array of pipeline configs, one per chain
      let configs: SpokePipelineConfig[] = parsed;

      // Filter by network if specified
      if (filterNetworks && filterNetworks[0] !== 'all') {
        configs = configs.filter((c) => filterNetworks.includes(c.network));
      }

      console.log(`Deploying ${configs.length} spoke webhook pipelines...`);

      for (const config of configs) {
        const yaml = renderPipeline(template, config, subgraphVersion, subgraphLabel);
        deployPipeline(yaml, config.webhookName, dryRun);
      }
    } else {
      // Hub config - single pipeline config
      const config: HubPipelineConfig = parsed;
      console.log(`Deploying hub webhook pipeline: ${config.webhookName}`);

      const yaml = renderPipeline(template, config, subgraphVersion, subgraphLabel);
      deployPipeline(yaml, config.webhookName, dryRun);
    }

    console.log('Done!');
  });

program.parse();
