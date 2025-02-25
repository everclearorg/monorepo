import * as anchor from '@coral-xyz/anchor';
import { Connection, Keypair, PublicKey } from '@solana/web3.js';
import * as fs from 'fs-extra';
import * as path from 'path';
import chalk from 'chalk';

export function getConnection(): Connection {
  const url = process.env.RPC_URL || 'http://localhost:8899';
  return new Connection(url, 'confirmed');
}

export function getProgram(programId: string, keypair: Keypair): anchor.Program {
  const connection = getConnection();
  const wallet = new anchor.Wallet(keypair);
  
  const provider = new anchor.AnchorProvider(
    connection,
    wallet,
    { commitment: 'confirmed' }
  );
  
  // Load the IDL file - the path assumes we're running from the root of the solana-spoke directory
  const idlPath = path.join(__dirname, '../../../target/idl/everclear_spoke.json');
  const idl = JSON.parse(fs.readFileSync(idlPath, 'utf8'));
  
  return new anchor.Program(idl, programId, provider);
}

export function loadKeypair(keypairPath: string): Keypair {
  try {
    const secretKey = new Uint8Array(JSON.parse(fs.readFileSync(keypairPath, 'utf8')));
    return Keypair.fromSecretKey(secretKey);
  } catch (error) {
    console.error(chalk.red(`Error loading keypair from ${keypairPath}: ${error}`));
    throw error;
  }
}

export async function confirmTransaction(
  connection: Connection,
  signature: string
): Promise<void> {
  console.log(chalk.yellow(`Transaction sent: ${signature}`));
  console.log(chalk.yellow('Waiting for confirmation...'));
  
  const confirmation = await connection.confirmTransaction(signature, 'confirmed');
  
  if (confirmation.value.err) {
    console.error(chalk.red(`Transaction failed: ${confirmation.value.err}`));
    throw new Error(`Transaction failed: ${confirmation.value.err}`);
  }
  
  console.log(chalk.green('Transaction confirmed!'));
}

export function getProgramId(): PublicKey {
  const programIdString = process.env.PROGRAM_ID || 'uvXqfnsfugQTAbd8Wy7xUBQDhcREMGZZeCUb1Y3fXLC';
  return new PublicKey(programIdString);
}

export function getSpokeStatePda(): [PublicKey, number] {
  return PublicKey.findProgramAddressSync(
    [Buffer.from('spoke-state')],
    getProgramId()
  );
} 