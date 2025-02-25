import { Command } from 'commander';
import { PublicKey } from '@solana/web3.js';
import * as anchor from '@coral-xyz/anchor';
import chalk from 'chalk';
import { getConnection, getProgram, loadKeypair, confirmTransaction, getProgramId, getSpokeStatePda } from '../utils';
import { getEnvironment } from '../../config/environment';

const command = new Command('new-intent')
  .description('Create a new intent on Everclear Spoke contract')
  .requiredOption('-r, --receiver <address>', 'Receiver address')
  .requiredOption('-i, --input-asset <address>', 'Input asset address')
  .requiredOption('-o, --output-asset <address>', 'Output asset address')
  .requiredOption('-a, --amount <number>', 'Amount')
  .option('-f, --max-fee <number>', 'Maximum fee (basis points: 0-10000)', '500')
  .option('-t, --ttl <number>', 'Time to live (seconds)', '3600')
  .requiredOption('-d, --destinations <numbers...>', 'Destination chain IDs')
  .option('--data <string>', 'Additional call data (hex)')
  .option('-g, --gas-limit <number>', 'Message gas limit', '900000')
  .option('-k, --keypair <path>', 'Path to keypair file')
  .action(async (options) => {
    try {
      const env = getEnvironment();
      
      // Load keypair
      const keypairPath = options.keypair || env.keypairPath;
      const keypair = loadKeypair(keypairPath);
      
      console.log(chalk.blue('Creating new intent on Everclear Spoke contract...'));
      
      // Connect to the program
      const programId = getProgramId();
      const program = getProgram(programId.toString(), keypair);
      
      // Get the state PDA
      const [stateAddress] = getSpokeStatePda();
      
      console.log(chalk.blue(`State address: ${stateAddress.toString()}`));
      
      // Convert destinations to array of numbers
      let destinationsArray: number[] = [];
      if (typeof options.destinations === 'string') {
        destinationsArray = [parseInt(options.destinations, 10)];
      } else if (Array.isArray(options.destinations)) {
        destinationsArray = options.destinations.map((d: string) => parseInt(d, 10));
      } else {
        throw new Error('Invalid destinations format. Must be a number or array of numbers.');
      }
      
      // Convert hex data to Buffer if provided
      let data = Buffer.from([]);
      if (options.data) {
        if (options.data.startsWith('0x')) {
          data = Buffer.from(options.data.slice(2), 'hex');
        } else {
          data = Buffer.from(options.data, 'hex');
        }
      }
      
      // These accounts would typically be loaded from a config or derived
      // For the e2e CLI demo, we'll create them on the fly
      // In a real app, you'd need to set up all the Hyperlane accounts correctly
      const mockHyperlaneAccounts = {
        hyperlaneMailbox: keypair.publicKey,
        mailboxOutbox: keypair.publicKey,
        dispatchAuthority: keypair.publicKey,
        uniqueMessageAccount: keypair.publicKey,
        dispatchedMessagePda: keypair.publicKey,
        igpProgram: keypair.publicKey,
        igpProgramData: keypair.publicKey,
        igpPaymentPda: keypair.publicKey,
        configuredIgpAccount: keypair.publicKey,
        innerIgpAccount: keypair.publicKey,
      };
      
      console.log(chalk.yellow('Note: This is a simplified demo. In production, you would need to:'));
      console.log(chalk.yellow('1. Set up all the correct Hyperlane accounts'));
      console.log(chalk.yellow('2. Fund the appropriate SPL token accounts'));
      console.log(chalk.yellow('3. Ensure the Hyperlane infrastructure is properly configured'));
      
      // In a real implementation, you would create an SPL token, mint it,
      // create token accounts for the user and program vault, etc.
      // For this demo, we'll just log what would happen
      
      console.log(chalk.blue('\nIntent Parameters:'));
      console.log(chalk.blue(`Receiver: ${options.receiver}`));
      console.log(chalk.blue(`Input Asset: ${options.inputAsset}`));
      console.log(chalk.blue(`Output Asset: ${options.outputAsset}`));
      console.log(chalk.blue(`Amount: ${options.amount}`));
      console.log(chalk.blue(`Max Fee: ${options.maxFee} (${parseInt(options.maxFee, 10) / 100}%)`));
      console.log(chalk.blue(`TTL: ${options.ttl} seconds`));
      console.log(chalk.blue(`Destinations: ${destinationsArray.join(', ')}`));
      console.log(chalk.blue(`Data: ${options.data || 'None'}`));
      console.log(chalk.blue(`Gas Limit: ${options.gasLimit}`));
      
      console.log(chalk.yellow('\nThis is a demo implementation. In a real application,'));
      console.log(chalk.yellow('you would need to set up and fund the appropriate SPL token accounts.'));
      
      /*
      // This is what a real implementation would look like:
      const tx = await program.methods
        .newIntent(
          new PublicKey(options.receiver),
          new PublicKey(options.inputAsset),
          new PublicKey(options.outputAsset),
          new anchor.BN(options.amount),
          parseInt(options.maxFee, 10),
          new anchor.BN(options.ttl),
          destinationsArray,
          Array.from(data),
          new anchor.BN(options.gasLimit)
        )
        .accounts({
          spokeState: stateAddress,
          payer: keypair.publicKey,
          authority: keypair.publicKey,
          mint: new PublicKey(options.inputAsset),
          userTokenAccount: userTokenAccount.publicKey,
          programVaultAccount: programVaultAccount.publicKey,
          tokenProgram: TOKEN_PROGRAM_ID,
          hyperlaneMailbox: mockHyperlaneAccounts.hyperlaneMailbox,
          systemProgram: SystemProgram.programId,
          splNoopProgram: new PublicKey("noopb9bkMVfRPU8AsbpTUg8AQkHtKwMYZiFUjNRtMmV"),
          mailboxOutbox: mockHyperlaneAccounts.mailboxOutbox,
          dispatchAuthority: mockHyperlaneAccounts.dispatchAuthority,
          uniqueMessageAccount: mockHyperlaneAccounts.uniqueMessageAccount,
          dispatchedMessagePda: mockHyperlaneAccounts.dispatchedMessagePda,
          igpProgram: mockHyperlaneAccounts.igpProgram,
          igpProgramData: mockHyperlaneAccounts.igpProgramData,
          igpPaymentPda: mockHyperlaneAccounts.igpPaymentPda,
          configuredIgpAccount: mockHyperlaneAccounts.configuredIgpAccount,
          innerIgpAccount: mockHyperlaneAccounts.innerIgpAccount,
        })
        .signers([keypair])
        .rpc();
      
      await confirmTransaction(getConnection(), tx);
      */
    } catch (error) {
      console.error(chalk.red(`Error creating new intent: ${error}`));
    }
  });

export default command; 