import { Command } from 'commander';
import * as anchor from '@coral-xyz/anchor';
import chalk from 'chalk';
import { getConnection, getProgram, loadKeypair, confirmTransaction, getProgramId, getSpokeStatePda } from '../utils';
import { getEnvironment } from '../../config/environment';

const command = new Command('update-message-gas-limit')
  .description('Update the message gas limit of the Everclear Spoke contract')
  .requiredOption('-g, --gas-limit <number>', 'New message gas limit')
  .option('-k, --keypair <path>', 'Path to keypair file (must be owner)')
  .action(async (options) => {
    try {
      const env = getEnvironment();
      
      // Load keypair
      const keypairPath = options.keypair || env.keypairPath;
      const keypair = loadKeypair(keypairPath);
      
      console.log(chalk.blue('Updating message gas limit of Everclear Spoke contract...'));
      
      // Connect to the program
      const programId = getProgramId();
      const program = getProgram(programId.toString(), keypair);
      
      // Get the state PDA
      const [stateAddress] = getSpokeStatePda();
      
      console.log(chalk.blue(`State address: ${stateAddress.toString()}`));
      
      // Read the current state to verify owner access
      const spokeState = await program.account.spokeState.fetch(stateAddress);
      if (!spokeState.owner.equals(keypair.publicKey)) {
        console.log(chalk.yellow('Warning: The provided keypair is not the owner of the contract.'));
        console.log(chalk.yellow(`Owner: ${spokeState.owner.toString()}`));
        console.log(chalk.yellow(`Your public key: ${keypair.publicKey.toString()}`));
      }
      
      // Check current message gas limit
      console.log(chalk.blue(`Current message gas limit: ${spokeState.messageGasLimit.toString()}`));
      console.log(chalk.blue(`New message gas limit: ${options.gasLimit}`));
      
      // Execute the update transaction
      const gasLimit = new anchor.BN(options.gasLimit);
      const tx = await program.methods
        .updateMessageGasLimit(gasLimit)
        .accounts({
          spokeState: stateAddress,
          admin: keypair.publicKey,
        })
        .signers([keypair])
        .rpc();
      
      await confirmTransaction(getConnection(), tx);
      
      console.log(chalk.green('Message gas limit updated successfully!'));
      console.log(chalk.green(`Transaction: ${tx}`));
      
      // Verify the update
      const updatedState = await program.account.spokeState.fetch(stateAddress);
      console.log(chalk.blue(`Updated message gas limit: ${updatedState.messageGasLimit.toString()}`));
    } catch (error) {
      console.error(chalk.red(`Error updating message gas limit: ${error}`));
    }
  });

export default command; 