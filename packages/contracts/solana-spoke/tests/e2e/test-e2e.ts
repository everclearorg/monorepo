import { execSync } from 'child_process';
import chalk from 'chalk';
import { createEnvFileIfNotExists } from './config/environment';

// Ensure the .env file exists
createEnvFileIfNotExists();

console.log(chalk.blue('Starting Everclear Spoke E2E Tests'));

try {
  // Clean and build before testing
  console.log(chalk.yellow('\nBuilding CLI tool...'));
  execSync('npm run build', { stdio: 'inherit' });

  // Initialize the contract
  console.log(chalk.yellow('\n1. Initializing contract...'));
  execSync('node dist/cli/index.js initialize --domain 1 --hub-domain 2', { stdio: 'inherit' });
  
  // Pause the contract
  console.log(chalk.yellow('\n2. Pausing the contract...'));
  execSync('node dist/cli/index.js pause', { stdio: 'inherit' });
  
  // Unpause the contract
  console.log(chalk.yellow('\n3. Unpausing the contract...'));
  execSync('node dist/cli/index.js unpause', { stdio: 'inherit' });
  
  // Create an intent (demo mode - not actually sending transaction)
  console.log(chalk.yellow('\n4. Creating a new intent...'));
  execSync(
    'node dist/cli/index.js new-intent ' +
    '--receiver 5ZWj7a1f8tWkjBESHKgrLmXshuXxqeY9SYcfbshpAqPG ' +
    '--input-asset EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v ' +
    '--output-asset 4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU ' +
    '--amount 1000000 ' + 
    '--destinations 2',
    { stdio: 'inherit' }
  );
  
  // Update message gas limit
  console.log(chalk.yellow('\n5. Updating message gas limit...'));
  execSync('node dist/cli/index.js update-message-gas-limit --gas-limit 1000000', { stdio: 'inherit' });
  
  console.log(chalk.green('\nE2E Tests Completed Successfully!'));
} catch (error) {
  console.error(chalk.red(`\nE2E Tests Failed: ${error}`));
  process.exit(1);
} 