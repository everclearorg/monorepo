import { readFileSync, writeFileSync, mkdtempSync, rmSync } from 'fs';
import { join } from 'path';
import { execFileSync } from 'child_process';
import { program } from 'commander';
import * as Mustache from 'mustache';
import { config as dotenvConfig } from 'dotenv';
import { getLatestLabel } from './utils';

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

interface SolanaPipelineConfig {
  pipelineName: string;
  programId: string;
  accountFilter: string;
  domain: string;
  webhookBaseUrl: string;
  secretName: string;
}

interface TronPipelineConfig {
  pipelineName: string;
  filter: string;
  domain: string;
  webhookBaseUrl: string;
  secretName: string;
}

function isSolanaConfig(parsed: unknown): parsed is SolanaPipelineConfig {
  return typeof parsed === 'object' && parsed !== null && 'pipelineName' in parsed && 'programId' in parsed;
}

function isTronConfig(parsed: unknown): parsed is TronPipelineConfig {
  return (
    typeof parsed === 'object' &&
    parsed !== null &&
    'pipelineName' in parsed &&
    'filter' in parsed &&
    !('programId' in parsed)
  );
}

function loadTemplate(): string {
  return readFileSync(join(__dirname, '../src/cartographer-webhooks/webhook.template.yaml'), 'utf-8');
}

function loadSolanaTemplate(): string {
  return readFileSync(join(__dirname, '../src/cartographer-webhooks/solana-webhook.template.yaml'), 'utf-8');
}

function loadTronTemplate(): string {
  return readFileSync(join(__dirname, '../src/cartographer-webhooks/tron-webhook.template.yaml'), 'utf-8');
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

function executeCommand(args: string[], dryRun: boolean): void {
  const cmd = `goldsky ${args.join(' ')}`;
  if (dryRun) {
    console.log(`[DRY RUN] Would execute: ${cmd}`);
    return;
  }

  console.log(`Executing: ${cmd}`);
  try {
    execFileSync('goldsky', args, { encoding: 'utf-8', stdio: 'inherit' });
  } catch (error) {
    console.error('Command failed:', cmd, error);
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
    executeCommand(['pipeline', 'apply', tmpFile, '--status', 'ACTIVE', '--force'], dryRun);
    console.log(`Successfully deployed pipeline: ${pipelineName}`);
  } finally {
    rmSync(tmpDir, { recursive: true, force: true });
  }
}

/**
 * Deploy webhook pipelines. Exported so deploy.ts can call it after subgraph deployment.
 */
export async function deployWebhookPipelines(
  configName: string,
  version: string,
  subgraphLabel: string,
  filterNetworks?: string[],
  dryRun = false,
): Promise<void> {
  const configFile = `${configName}-${version}.json`;
  const configPath = join(__dirname, `../config/${configFile}`);

  console.log(`Loading webhook config from: ${configPath}`);
  const configRaw = readFileSync(configPath, 'utf-8');
  const parsed = JSON.parse(configRaw);

  if (isSolanaConfig(parsed)) {
    // Solana dataset pipeline — no subgraph label needed
    const solanaTemplate = loadSolanaTemplate();
    const yaml = Mustache.render(solanaTemplate, parsed);
    console.log(`Deploying Solana webhook pipeline: ${parsed.pipelineName}`);
    deployPipeline(yaml, parsed.pipelineName, dryRun);
  } else if (isTronConfig(parsed)) {
    // Tron dataset pipeline — no subgraph label needed
    const tronTemplate = loadTronTemplate();
    const yaml = Mustache.render(tronTemplate, parsed);
    console.log(`Deploying Tron webhook pipeline: ${parsed.pipelineName}`);
    deployPipeline(yaml, parsed.pipelineName, dryRun);
  } else {
    // EVM subgraph pipelines — require subgraph label
    if (!subgraphLabel) {
      throw new Error('subgraph-label is required for subgraph pipelines');
    }

    const subgraphVersion = `${version}-${subgraphLabel}`;
    const template = loadTemplate();

    if (Array.isArray(parsed)) {
      let configs: SpokePipelineConfig[] = parsed;

      if (filterNetworks && filterNetworks[0] !== 'all') {
        configs = configs.filter((c) => filterNetworks.includes(c.network));
      }

      console.log(`Deploying ${configs.length} spoke webhook pipelines...`);

      for (const config of configs) {
        const yaml = renderPipeline(template, config, subgraphVersion, subgraphLabel);
        deployPipeline(yaml, config.webhookName, dryRun);
      }
    } else {
      const config: HubPipelineConfig = parsed;
      console.log(`Deploying hub webhook pipeline: ${config.webhookName}`);

      const yaml = renderPipeline(template, config, subgraphVersion, subgraphLabel);
      deployPipeline(yaml, config.webhookName, dryRun);
    }
  }
}

// CLI entry point
if (require.main === module) {
  program
    .argument('<config-name>', 'Pipeline config name (e.g., everclear-hub-webhooks)')
    .option('-v, --version <value>', 'Config version (staging or production)', 'production')
    .option('-n, --networks <value...>', 'Network names to filter (spoke configs only)')
    .option('-s, --subgraph-label <value>', 'Subgraph label (e.g., v0.0.3). If omitted, auto-detects latest.')
    .option('-d, --dry-run', 'Only output the resolved YAML without deploying', false)
    .action(async (configName: string) => {
      const options = program.opts();
      const version = options.version;
      let subgraphLabel = options.subgraphLabel;
      const dryRun = options.dryRun;
      const filterNetworks = options.networks;

      // Auto-detect label if not provided
      if (!subgraphLabel) {
        const configFile = `${configName}-${version}.json`;
        const configPath = join(__dirname, `../config/${configFile}`);
        const configRaw = readFileSync(configPath, 'utf-8');
        const parsed = JSON.parse(configRaw);

        // Get the subgraph name from config to query goldsky
        let subgraphName: string;
        if (Array.isArray(parsed)) {
          const configs: SpokePipelineConfig[] = parsed;
          const filtered =
            filterNetworks && filterNetworks[0] !== 'all'
              ? configs.filter((c) => filterNetworks.includes(c.network))
              : configs;
          subgraphName = filtered[0]?.subgraph.name;
        } else {
          subgraphName = parsed.subgraph.name;
        }

        if (!subgraphName) {
          console.error('Error: could not determine subgraph name for auto-label detection');
          process.exit(1);
        }

        subgraphLabel = await getLatestLabel(subgraphName, version, false);
        console.log(`Auto-detected current label: ${subgraphLabel}`);
      }

      await deployWebhookPipelines(configName, version, subgraphLabel, filterNetworks, dryRun);
      console.log('Done!');
    });

  program.parse();
}
