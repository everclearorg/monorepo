import { Command } from 'commander';
import { PublicKey, SystemProgram } from '@solana/web3.js';
import * as anchor from '@coral-xyz/anchor';
import chalk from 'chalk';
import { getConnection, getProgram, loadKeypair, confirmTransaction, getProgramId } from '../utils';
import { getEnvironment } from '../../config/environment';

const command = new Command('initialize')
  .description('Initialize the Everclear Spoke contract')
  .option('-d, --domain <number>', 'Domain ID for this spoke', '1')
  .option('-h, --hub-domain <number>', 'Domain ID for Everclear hub', '2')
  .option('-g, --gateway <address>', 'Gateway address')
  .option('-r, --receiver <address>', 'Message receiver address')
  .option('-l, --lighthouse <address>', 'Lighthouse address')
  .option('-w, --watchtower <address>', 'Watchtower address')
  .option('-e, --executor <address>', 'Call executor address')
  .option('-m, --mailbox <address>', 'Mailbox address')
  .option('-g, --message-gas <number>', 'Message gas limit', '900000')
  .option('-k, --keypair <path>', 'Path to keypair file')
  .action(async (options) => {
    try {
      const env = getEnvironment();
      
      // Load keypair
      const keypairPath = options.keypair || env.keypairPath;
      const keypair = loadKeypair(keypairPath);
      
      console.log(chalk.blue('Initializing Everclear Spoke contract...'));
      
      // Connect to the program
      const programId = getProgramId();
      const program = getProgram(programId.toString(), keypair);
      
      // Derive the state PDA
      const [stateAddress, bump] = PublicKey.findProgramAddressSync(
        [Buffer.from('spoke-state')],
        programId
      );
      
      console.log(chalk.blue(`State address: ${stateAddress.toString()}`));
      
      // Generate any unspecified addresses
      const lighthouseKeyPair = options.lighthouse 
        ? new PublicKey(options.lighthouse)
        : keypair.publicKey;
        
      const watchtowerKeyPair = options.watchtower
        ? new PublicKey(options.watchtower)
        : keypair.publicKey;
        
      const callExecutorKeyPair = options.executor
        ? new PublicKey(options.executor)
        : keypair.publicKey;
        
      const messageReceiverKeyPair = options.receiver
        ? new PublicKey(options.receiver)
        : keypair.publicKey;
        
      const mailboxKeyPair = options.mailbox
        ? new PublicKey(options.mailbox)
        : keypair.publicKey;
      
      // Prepare initialization parameters
      const params = {
        domain: parseInt(options.domain, 10),
        hubDomain: parseInt(options.hubDomain, 10),
        lighthouse: lighthouseKeyPair,
        watchtower: watchtowerKeyPair,
        callExecutor: callExecutorKeyPair,
        messageReceiver: messageReceiverKeyPair,
        messageGasLimit: new anchor.BN(options.messageGas),
        owner: keypair.publicKey,
        mailbox: mailboxKeyPair,
      };
      
      const tx = await program.methods
        .initialize(params)
        .accounts({
          spokeState: stateAddress,
          payer: keypair.publicKey,
          systemProgram: SystemProgram.programId,
        })
        .signers([keypair])
        .rpc();
      
      await confirmTransaction(getConnection(), tx);
      
      console.log(chalk.green('Everclear Spoke contract initialized successfully!'));
      console.log(chalk.green(`Transaction: ${tx}`));
      console.log(chalk.green(`State address: ${stateAddress.toString()}`));
      
      // Display the configuration
      console.log(chalk.blue('\nContract Configuration:'));
      console.log(chalk.blue(`Domain: ${params.domain}`));
      console.log(chalk.blue(`Hub Domain: ${params.hubDomain}`));
      console.log(chalk.blue(`Lighthouse: ${lighthouseKeyPair.toString()}`));
      console.log(chalk.blue(`Watchtower: ${watchtowerKeyPair.toString()}`));
      console.log(chalk.blue(`Call Executor: ${callExecutorKeyPair.toString()}`));
      console.log(chalk.blue(`Message Receiver: ${messageReceiverKeyPair.toString()}`));
      console.log(chalk.blue(`Message Gas Limit: ${params.messageGasLimit.toString()}`));
      console.log(chalk.blue(`Owner: ${keypair.publicKey.toString()}`));
      console.log(chalk.blue(`Mailbox: ${mailboxKeyPair.toString()}`));
    } catch (error) {
      console.error(chalk.red(`Error initializing Everclear Spoke contract: ${error}`));
    }
  });

export default command; 