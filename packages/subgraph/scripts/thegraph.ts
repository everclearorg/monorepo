import { exec as _exec } from 'child_process';
import util from 'util';

const exec = util.promisify(_exec);

const EVERCLEAR_SUBGRAPH_ACCOUNT = 'connext';

export const executeCommand = async (command: string) => {
  try {
    const { stdout, stderr } = await exec(command);
    console.log('stdout:', stdout);
    if (stderr) {
      console.log(`stderr: ${stderr}`);
    }
    return { stdout, stderr };
  } catch (e) {
    console.log(e);
    // should contain code (exit code) and signal (that caused the termination).
    throw new Error(`exec error: ${e}`);
  }
};

const checkStudioAccessToken = () => {
  if (!process.env.SUBGRAPH_STUDIO_DEPLOY_KEY) {
    throw new Error(
      `
      Missing access token in SUBGRAPH_STUDIO_DEPLOY_KEY env.
      You can get a token from https://thegraph.com/studio/
      `,
    );
  }
};

const checkHostedServiceAccessToken = () => {
  if (!process.env.SUBGRAPH_ACCESS_TOKEN) {
    throw new Error(
      `
      Missing access token in SUBGRAPH_ACCESS_TOKEN env.
      You can get a token from https://thegraph.com/hosted-service/dashboard
      `,
    );
  }
};

// Generate subgraph manifest
export const build = async () => {
  console.log(`Building subgraph...`);
  await executeCommand(`yarn codegen && yarn graph:build`);
};

const executeStudioDeploy = async (subgraphName: string, version: string) => {
  const cmd = `graph deploy --studio ${subgraphName} ` + (version ? ` --version-label ${version}` : '');
  const { stderr } = await executeCommand(cmd);

  if (stderr) {
    if (stderr.includes(`Version label already exists`)) {
      throw new Error(`Studio version '${version}' for ${subgraphName} exists - skipping`);
    }
  }
};

export const deployStudio = async (subgraphName: string, version: string) => {
  checkStudioAccessToken();
  await executeCommand(`graph auth --studio ${process.env.SUBGRAPH_STUDIO_DEPLOY_KEY}`);
  await executeStudioDeploy(subgraphName, version);
};

const executeHostedDeploy = async (subgraphName: string, version: string) => {
  const cmd = `graph deploy --product hosted-service ${EVERCLEAR_SUBGRAPH_ACCOUNT}/${subgraphName}-${version}`;
  await executeCommand(cmd);
};

export const deployHostedService = async (subgraphName: string, version: string) => {
  checkHostedServiceAccessToken();
  await executeCommand(`graph auth --product hosted-service ${process.env.SUBGRAPH_ACCESS_TOKEN}`);
  await executeHostedDeploy(subgraphName, version);
};

const executeLocalDeploy = async (subgraphName: string, version: string) => {
  const createCmd = `graph create --node ${process.env.GRAPH_LOCALHOST_URL} ${subgraphName}-${version}`;
  await executeCommand(createCmd);
  const cmd = `graph deploy --node ${process.env.GRAPH_LOCALHOST_URL} ${subgraphName}-${version}`;
  await executeCommand(cmd);
};

export const deployLocal = async (subgraphName: string, version: string) => {
  await executeLocalDeploy(subgraphName, version);
};

const executeGoldSkyDeploy = async (subgraphName: string, version: string) => {
  const cmd = `goldsky subgraph deploy ${subgraphName}/${version}`;
  await executeCommand(cmd);
};

export const deployGoldSky = async (subgraphName: string, version: string, label: string) => {
  const _goldSkyVersion = version.concat(`-${label}`);
  await executeGoldSkyDeploy(subgraphName, _goldSkyVersion);
};

/**
 * deploy subgraph command
 */
export const deploySubgraph = async (subgraphName: string, version: string, label: string, indexer: string) => {
  // deploy to hosted-service or studio
  switch (indexer) {
    case 'studio':
      await deployStudio(subgraphName, label);
      break;
    case 'goldsky':
      await deployGoldSky(subgraphName, version, label);
      break;
    case 'hosted':
      await deployHostedService(subgraphName, version);
      break;
    case 'local':
      await deployLocal(subgraphName, version);
      break;
    default:
      break;
  }
};
