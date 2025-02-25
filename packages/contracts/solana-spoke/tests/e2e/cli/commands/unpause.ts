import { Command } from 'commander';
import chalk from 'chalk';
import { getConnection, getProgram, loadKeypair, confirmTransaction, getProgramId, getSpokeStatePda } from '../utils';
import { getEnvironment } from '../../config/environment';

const command = new Command('unpause')
  .description('Unpause the Everclear Spoke contract')
  .option('-k, --keypair <path>', 'Path to keypair file (must be lighthouse or watchtower)')
  .action(async (options) => {
    try {
      const env = getEnvironment();

      // Load keypair
      const keypairPath = options.keypair || env.keypairPath;
      const keypair = loadKeypair(keypairPath);

      console.log(chalk.blue('Unpausing Everclear Spoke contract...'));

      // Connect to the program
      const programId = getProgramId();
      const program = getProgram(programId.toString(), keypair);

      // Get the state PDA
      const [stateAddress] = getSpokeStatePda();

      console.log(chalk.blue(`State address: ${stateAddress.toString()}`));

      // Execute the unpause transaction
      const tx = await program.methods
        .unpause()
        .accounts({
          spokeState: stateAddress,
          admin: keypair.publicKey,
        })
        .signers([keypair])
        .rpc();

      await confirmTransaction(getConnection(), tx);

      console.log(chalk.green('Everclear Spoke contract unpaused successfully!'));
      console.log(chalk.green(`Transaction: ${tx}`));

      // Verify the state
      const spokeState = await (program.account as any).spokeState.fetch(stateAddress);
      console.log(chalk.blue(`Current pause state: ${spokeState.paused ? 'PAUSED' : 'ACTIVE'}`));
    } catch (error) {
      console.error(chalk.red(`Error unpausing Everclear Spoke contract: ${error}`));
    }
  });

export default command;
