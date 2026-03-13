import { execSync } from 'child_process';

/**
 * Query goldsky for the latest deployed subgraph version label.
 * If increment is true (default), returns the next patch version (e.g. v0.0.12 -> v0.0.13).
 * If increment is false, returns the current latest (e.g. v0.0.12).
 * If no versions found, returns v0.0.1.
 */
export async function getLatestLabel(subgraphName: string, version: string, increment = true): Promise<string> {
  console.log(`Querying goldsky for latest label of ${subgraphName}/${version}...`);

  let stdout: string;
  try {
    stdout = execSync(`goldsky subgraph list ${subgraphName} --summary`, {
      encoding: 'utf-8',
      stdio: ['pipe', 'pipe', 'pipe'],
    });
  } catch {
    console.log(`No existing subgraph found for ${subgraphName}, starting at v0.0.1`);
    return 'v0.0.1';
  }

  // Parse lines like: * everclear-spoke-mainnet/staging-v0.0.12
  const regex = new RegExp(`${subgraphName}/${version}-v(\\d+)\\.(\\d+)\\.(\\d+)`);
  let maxMajor = 0;
  let maxMinor = 0;
  let maxPatch = 0;
  let found = false;

  for (const line of stdout.split('\n')) {
    const match = line.match(regex);
    if (match) {
      const [, major, minor, patch] = match.map(Number);
      if (
        major > maxMajor ||
        (major === maxMajor && minor > maxMinor) ||
        (major === maxMajor && minor === maxMinor && patch > maxPatch)
      ) {
        maxMajor = major;
        maxMinor = minor;
        maxPatch = patch;
      }
      found = true;
    }
  }

  if (!found) {
    console.log(`No versions found for ${subgraphName}/${version}-*, starting at v0.0.1`);
    return 'v0.0.1';
  }

  const currentLabel = `v${maxMajor}.${maxMinor}.${maxPatch}`;
  if (!increment) {
    console.log(`Latest label: ${currentLabel}`);
    return currentLabel;
  }

  const nextLabel = `v${maxMajor}.${maxMinor}.${maxPatch + 1}`;
  console.log(`Latest label: ${currentLabel} -> next: ${nextLabel}`);
  return nextLabel;
}
