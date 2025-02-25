# Everclear Solana Spoke E2E Testing CLI

This tool provides a command-line interface for end-to-end testing of the Everclear Solana Spoke contracts.

## Prerequisites

- Node.js v16 or later
- Yarn or NPM
- Solana CLI tools installed and configured

## Setup

1. Clone the repository and navigate to the e2e directory:
   ```bash
   cd packages/contracts/solana-spoke/tests/e2e
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Build the CLI tool:
   ```bash
   npm run build
   ```

4. Set up your environment:
   - Copy the `.env.example` file to `.env` (or one will be created automatically)
   - Edit the `.env` file with your own configuration:
     ```
     # Solana RPC URL (local validator, devnet, or custom)
     RPC_URL=http://localhost:8899
     
     # Program ID of the deployed Everclear Spoke contract
     PROGRAM_ID=uvXqfnsfugQTAbd8Wy7xUBQDhcREMGZZeCUb1Y3fXLC
     
     # Path to your Solana keypair file
     KEYPAIR_PATH=~/.config/solana/id.json
     
     # Everclear domain ID
     EVERCLEAR_DOMAIN=1
     ```

## Usage

The CLI tool provides various commands to interact with the Everclear Spoke contract:

### Initialize the Contract

```bash
npm start -- initialize [options]
```

Options:
- `-d, --domain <number>`: Domain ID for this spoke (default: 1)
- `-h, --hub-domain <number>`: Domain ID for Everclear hub (default: 2)
- `-g, --gateway <address>`: Gateway address
- `-r, --receiver <address>`: Message receiver address
- `-l, --lighthouse <address>`: Lighthouse address
- `-w, --watchtower <address>`: Watchtower address
- `-e, --executor <address>`: Call executor address
- `-m, --mailbox <address>`: Mailbox address
- `-g, --message-gas <number>`: Message gas limit (default: 900000)
- `-k, --keypair <path>`: Path to keypair file

### Pause the Contract

```bash
npm start -- pause [options]
```

Options:
- `-k, --keypair <path>`: Path to keypair file (must be lighthouse or watchtower)

### Unpause the Contract

```bash
npm start -- unpause [options]
```

Options:
- `-k, --keypair <path>`: Path to keypair file (must be lighthouse or watchtower)

### Create a New Intent

```bash
npm start -- new-intent [options]
```

Options:
- `-r, --receiver <address>`: Receiver address (required)
- `-i, --input-asset <address>`: Input asset address (required)
- `-o, --output-asset <address>`: Output asset address (required)
- `-a, --amount <number>`: Amount (required)
- `-f, --max-fee <number>`: Maximum fee (basis points: 0-10000, default: 500)
- `-t, --ttl <number>`: Time to live in seconds (default: 3600)
- `-d, --destinations <numbers...>`: Destination chain IDs (required)
- `--data <string>`: Additional call data (hex)
- `-g, --gas-limit <number>`: Message gas limit (default: 900000)
- `-k, --keypair <path>`: Path to keypair file

### Update Message Gas Limit

```bash
npm start -- update-message-gas-limit [options]
```

Options:
- `-g, --gas-limit <number>`: New message gas limit (required)
- `-k, --keypair <path>`: Path to keypair file (must be owner)

## Examples

Initialize the contract:
```bash
npm start -- initialize --domain 1 --hub-domain 2
```

Pause the contract:
```bash
npm start -- pause
```

Unpause the contract:
```bash
npm start -- unpause
```

Create a new intent:
```bash
npm start -- new-intent --receiver 5ZWj7a1f8tWkjBESHKgrLmXshuXxqeY9SYcfbshpAqPG --input-asset EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v --output-asset 4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU --amount 1000000 --destinations 2
```

Update message gas limit:
```bash
npm start -- update-message-gas-limit --gas-limit 1000000
```

## Development

To add a new command:

1. Create a new file in the `cli/commands` directory
2. Implement the command using the Commander.js API
3. Build the CLI tool:
   ```bash
   npm run build
   ```

## Troubleshooting

- If you encounter an error about missing program IDL, make sure you've built the Anchor program first:
  ```bash
  cd ../../..
  anchor build
  ```

- If transactions fail with "Transaction simulation failed", check the Solana logs for more details:
  ```bash
  solana logs -u <RPC_URL>
  ``` 