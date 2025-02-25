import * as path from 'path';
import { config } from 'dotenv';
import * as fs from 'fs-extra';
import * as os from 'os';

// Load environment variables from .env file
config();

export type Environment = {
  rpcUrl: string;
  programId: string;
  keypairPath: string;
  everclearDomain: number;
};

export function getEnvironment(): Environment {
  return {
    rpcUrl: process.env.RPC_URL || 'http://localhost:8899',
    programId: process.env.PROGRAM_ID || 'uvXqfnsfugQTAbd8Wy7xUBQDhcREMGZZeCUb1Y3fXLC',
    keypairPath: process.env.KEYPAIR_PATH || path.join(os.homedir(), '.config/solana/id.json'),
    everclearDomain: parseInt(process.env.EVERCLEAR_DOMAIN || '1'),
  };
}

export function createEnvFileIfNotExists(): void {
  const envPath = path.join(__dirname, '../.env');
  
  if (!fs.existsSync(envPath)) {
    const envContent = `# Solana RPC URL (local validator, devnet, or custom)
RPC_URL=http://localhost:8899

# Program ID of the deployed Everclear Spoke contract
PROGRAM_ID=uvXqfnsfugQTAbd8Wy7xUBQDhcREMGZZeCUb1Y3fXLC

# Path to your Solana keypair file
KEYPAIR_PATH=${path.join(os.homedir(), '.config/solana/id.json')}

# Everclear domain ID
EVERCLEAR_DOMAIN=1
`;
    
    fs.writeFileSync(envPath, envContent);
    console.log(`Created .env file at ${envPath}`);
  }
} 