# Everclear Indexer

High-performance blockchain indexer for the Everclear protocol using [Envio](https://envio.dev/). Indexes Everclear hub and spoke contracts and related events (intents, fills, queues, balances, settlements, invoices, fees, and stats) across all supported networks.

## Overview

This indexer monitors Everclear hub and spoke contracts (including EverclearSpoke and FeeAdapter) across multiple chains and provides a unified GraphQL API to query:
- **Intents & Queues**: Cross-chain intent creation, queueing, and fulfillment
- **Fills**: Solver activity and fill details
- **Fees & Balances**: Token/native fees paid by initiators and protocol balance tracking
- **Hub Settlements & Invoices**: Settlement flows and invoice state on the hub
- **Statistics & Asset Tracking**: Global metrics for intents/fills and volume/usage statistics

## Quick Start

### Prerequisites

- **Docker Desktop** - Required for PostgreSQL and Hasura
- **Node.js** - v18 or higher
- **Yarn** - v3+ (managed by monorepo root)

### Installation

```bash
# Install dependencies
yarn install

# Generate TypeScript types from schema
yarn codegen
```

### Running Locally

```bash
# Start Docker containers (PostgreSQL + Hasura)
cd generated
docker-compose up -d
cd ..

# Start the indexer
yarn start

# Or use dev mode (auto-restart on changes)
yarn dev
```

The indexer will:
1. Connect to PostgreSQL on port 5433
2. Start Hasura GraphQL engine on port 8080
3. Begin syncing events from all configured chains

### Accessing the API

- **GraphQL Endpoint**: http://localhost:8080/v1/graphql
- **Hasura Console**: http://localhost:8080/console
  - Admin Secret: `testing` (default)

## Indexed Chains

| Chain | Chain ID | Contract Address | Start Block |
|-------|----------|-----------------|-------------|
| Ethereum | 1 | 0xa05A3380889115bf313f1Db9d5f335157Be4D816 | 20,760,959 |
| Arbitrum | 42161 | 0xa05A3380889115bf313f1Db9d5f335157Be4D816 | 0 |
| Optimism | 10 | 0xa05A3380889115bf313f1Db9d5f335157Be4D816 | 0 |
| Base | 8453 | 0xa05A3380889115bf313f1Db9d5f335157Be4D816 | 0 |
| BNB Chain | 56 | 0xa05A3380889115bf313f1Db9d5f335157Be4D816 | 0 |
| Linea | 59144 | 0xc24dC29774fD2c1c0c5FA31325Bb9cbC11D8b751 | 0 |
| Polygon | 137 | 0x7189C59e245135696bFd2906b56607755F84F3fD | 0 |
| Avalanche | 43114 | 0x9aA2Ecad5C77dfcB4f34893993f313ec4a370460 | 0 |
| Unichain | 130 | 0xa05A3380889115bf313f1Db9d5f335157Be4D816 | 0 |

All chains use [HyperSync](https://docs.envio.dev/docs/HyperIndex/hypersync) for fast indexing.

## GraphQL Schema

### Core Entities

#### Intent
Represents a cross-chain intent created on the origin chain.

```graphql
type Intent {
  id: ID!                    # Intent ID
  intentId: Bytes!
  status: IntentStatus!      # ADDED, FILLED
  
  # Intent details
  initiator: Bytes!
  receiver: Bytes!
  inputAsset: Bytes!
  outputAsset: Bytes!
  originAmount: BigInt!      # Original intent amount
  maxFee: Int!
  ttl: BigInt!
  
  # Chain info
  chainId: Int!              # Origin chain
  origin: Int!
  destinations: [Int!]!      # Target chains
  
  # Metadata
  blockNumber: BigInt!       # Block when intent was created
  blockTimestamp: BigInt!
  transactionHash: Bytes!
  
  # Fill metadata
  receiveBlockNumber: BigInt # Block when intent was filled (null if unfilled)
  isFastPath: Boolean!       # true if ttl != 0 (fillable), false if ttl == 0 (nettable)
  
  # Fee information (from FeeAdapter)
  tokenFee: BigInt           # Token fee paid by initiator
  nativeFee: BigInt          # Native token fee paid by initiator
  
  # Relations
  fills: [Fill!]!
}
```

#### Fill
Represents an intent fulfillment on a destination chain.

```graphql
type Fill {
  id: ID!
  intentId: Bytes!
  solver: Bytes!
  totalFeeDBPS: BigInt!      # Fee in decibasis points (basis points / 100)
  
  # Intent data snapshot
  originAmount: BigInt!      # Original intent amount
  fillAmount: BigInt!        # Amount after deducting fee (originAmount - fee)
  initiator: Bytes!
  receiver: Bytes!
  inputAsset: Bytes!
  outputAsset: Bytes!
  
  # Chain info
  chainId: Int!              # Destination chain where fill occurred
  
  # Metadata
  blockNumber: BigInt!
  blockTimestamp: BigInt!
  transactionHash: Bytes!
  
  # Relations
  intent: Intent!
}
```

#### Statistics & Assets
- `IntentStatistics` - Global totals (unique intents, nettable vs fillable, total fills)
- `Asset` - Asset volume tracking per chain

### Indexed Contracts

The indexer tracks events from two contracts on each chain:

1. **EverclearSpoke** - Core intent creation and fulfillment
   - `IntentAdded` - When a user creates an intent
   - `IntentFilled` - When a solver fills an intent

2. **FeeAdapter** - Fee collection for intents
   - `IntentWithFeesAdded` - Tracks token and native fees paid by initiators

## Example Queries

### Get Recent Intents

```graphql
query RecentIntents {
  Intent(limit: 10, order_by: { blockNumber: desc }) {
    id
    intentId
    status
    chainId
    originAmount
    isFastPath
    ttl
    tokenFee
    nativeFee
    initiator
    receiver
    blockNumber
    blockTimestamp
    receiveBlockNumber
  }
}
```

### Get Intent with Fills

```graphql
query IntentWithFills($intentId: String!) {
  Intent(where: { intentId: { _eq: $intentId } }) {
    id
    intentId
    status
    chainId
    originAmount
    tokenFee
    nativeFee
    isFastPath
    receiveBlockNumber
    
    fills {
      id
      chainId
      solver
      originAmount
      fillAmount
      totalFeeDBPS
      blockTimestamp
    }
  }
}
```

### Get Global Statistics

```graphql
query GlobalStats {
  IntentStatistics {
    totalUniqueIntents
    totalNettableIntents
    totalFillableIntents
    totalFills
  }
}
```

### Get Fills by Solver

```graphql
query FillsBySolver($solver: String!) {
  Fill(
    where: { solver: { _eq: $solver } }
    order_by: { blockTimestamp: desc }
  ) {
    id
    intentId
    solver
    totalFeeDBPS
    originAmount
    fillAmount
    chainId
    blockTimestamp
    intent {
      initiator
      receiver
      isFastPath
    }
  }
}
```

### Get Active Unfilled Intents

```graphql
query ActiveUnfilledIntents {
  Intent(
    where: {
      _and: [
        { status: { _eq: ADDED } }
        { isFastPath: { _eq: true } }
      ]
    }
    order_by: { blockTimestamp: desc }
  ) {
    id
    intentId
    status
    ttl
    timestamp
    blockTimestamp
    chainId
    originAmount
    isFastPath
    initiator
    receiver
    inputAsset
    outputAsset
    destinations
  }
}
```

### Get Intents with Fees

```graphql
query IntentsWithFees {
  Intent(
    where: {
      _or: [
        { tokenFee: { _gt: "0" } }
        { nativeFee: { _gt: "0" } }
      ]
    }
    limit: 10
    order_by: { blockNumber: desc }
  ) {
    id
    intentId
    originAmount
    tokenFee
    nativeFee
    initiator
    chainId
    blockNumber
    transactionHash
  }
}
```

### Cross-Chain Intent Flow

```graphql
query CrossChainIntents {
  Intent(
    where: {
      chainId: { _eq: 1 }                    # Created on Ethereum
      fills: { chainId: { _in: [8453, 10] } }  # Filled on Base or Optimism
    }
  ) {
    intentId
    chainId
    originAmount
    tokenFee
    nativeFee
    isFastPath
    receiveBlockNumber
    fills {
      chainId
      solver
      fillAmount
      totalFeeDBPS
      blockTimestamp
    }
  }
}
```

## Project Structure

```
packages/indexer/
├── config.yaml              # Indexer configuration
├── schema.graphql           # GraphQL schema definition
├── src/
│   └── EventHandlers.ts     # Event processing logic
├── abis/
│   └── EverclearSpoke.json  # Contract ABI
├── generated/               # Auto-generated code (don't edit)
│   ├── src/                 # TypeScript types
│   └── docker-compose.yaml  # Database setup
├── package.json
└── tsconfig.json
```

## Configuration

### Environment Variables

Create a `.env` file (see `env.example`):

### Modifying Chains

Edit `config.yaml` to add/remove chains:

```yaml
networks:
  - id: 1                    # Chain ID
    start_block: 20760959    # Start indexing from this block
    contracts:
      - name: EverclearSpoke
        address: 0xa05A3380889115bf313f1Db9d5f335157Be4D816
```

After modifying, regenerate types:

```bash
yarn codegen
```

## Event Handlers

The indexer processes events from two contracts:

### IntentAdded
Triggered when a user creates an intent on the origin chain.

**Handler logic:**
1. Create Intent entity with:
   - `status: ADDED`
   - `originAmount`: The original intent amount
   - `isFastPath`: Set to `true` if `ttl != 0`, `false` if `ttl == 0`
   - `receiveBlockNumber`: Initially `null` (set when filled)
2. Update global statistics:
   - Increment `totalUniqueIntents`
   - Increment `totalNettableIntents` if `ttl == 0`
   - Increment `totalFillableIntents` if `ttl != 0`
3. Track input asset usage

**Intent Types:**
- **Nettable Intents** (`ttl == 0`, `isFastPath: false`): Will be netted, not filled
- **Fillable Intents** (`ttl != 0`, `isFastPath: true`): Can be filled by solvers

### IntentFilled
Triggered when a solver fills an intent on a destination chain.

**Handler logic:**
1. **Verify intent exists** - If not found, skip processing (prevents counting invalid fills)
2. Calculate `fillAmount`:
   - Fee calculation: `feeAmount = (originAmount * totalFeeDBPS) / 10000`
   - Fill amount: `fillAmount = originAmount - feeAmount`
   - Note: `totalFeeDBPS` is in decibasis points (basis points / 100)
3. Create Fill entity with `originAmount` and calculated `fillAmount` (only for valid fills)
4. Update Intent:
   - Set `status: FILLED`
   - Set `receiveBlockNumber` to the fill block number
5. Update global statistics: increment `totalFills`
6. Track output asset usage

**Edge Case Handling:**
If a fill is sent with wrong information, the intent won't exist. These invalid fills are:
- Not added to the database
- Not counted in statistics
- Logged as warnings for monitoring

**Fee Calculation Example:**
- `originAmount`: 100 tokens
- `totalFeeDBPS`: 50 (= 0.5% fee)
- `feeAmount`: (100 * 50) / 10000 = 0.5 tokens
- `fillAmount`: 100 - 0.5 = 99.5 tokens

### IntentWithFeesAdded (FeeAdapter)
Triggered when a user creates an intent through the FeeAdapter contract (with fees).

**Handler logic:**
1. **Check if Intent exists:**
   - If exists: Update with fee information (`tokenFee`, `nativeFee`)
   - If not: Create placeholder Intent with fees (will be populated by `IntentAdded`)
2. This event can occur **before** or **after** `IntentAdded` event
3. The handler ensures fees are always captured regardless of event order

**Placeholder Handling:**
When `IntentWithFeesAdded` arrives before `IntentAdded`:
- Creates a minimal Intent with fee information
- `IntentAdded` handler detects the placeholder (by `originAmount == 0`)
- Statistics are only counted once (when real intent data arrives)
- Fees are preserved when Intent is updated with full data

**Fee Fields:**
- `tokenFee`: ERC-20 token fees paid to the protocol
- `nativeFee`: Native token (ETH/MATIC/etc) fees paid to the protocol

## Development

### Adding New Event Handlers

1. Add event to `config.yaml`:
```yaml
events:
  - event: IntentAdded
  - event: IntentFilled
  - event: YourNewEvent    # Add here
```

2. Update `schema.graphql` with new entities

3. Run codegen:
```bash
yarn codegen
```

4. Implement handler in `src/EventHandlers.ts`:
```typescript
EverclearSpoke_YourNewEvent_handler(async ({ event, context }) => {
  // Your logic here
});
```

### Testing Queries

Use the Hasura console for interactive testing:

1. Open http://localhost:8080/console
2. Enter admin secret: `testing`
3. Navigate to "API" tab
4. Write and test queries

Or use curl:

```bash
curl -X POST http://localhost:8080/v1/graphql \
  -H "Content-Type: application/json" \
  -H "x-hasura-admin-secret: testing" \
  -d '{"query": "{ Intent(limit: 5) { id intentId status } }"}'
```

## Troubleshooting

### Indexer won't start

```bash
# Ensure Docker is running
docker ps

# Restart containers
cd generated
docker-compose down -v
docker-compose up -d
cd ..

# Restart indexer
yarn start
```

### TypeScript errors

```bash
# Regenerate types
yarn codegen
```

### Database connection errors

```bash
# Check PostgreSQL is running on port 5433
docker ps | grep postgres

# Check logs
cd generated
docker-compose logs envio-postgres
```

### Reset everything

```bash
# Stop indexer (Ctrl+C)

# Remove all data and restart fresh
cd generated
docker-compose down -v
docker-compose up -d
cd ..

# Restart indexer
yarn start
```

## Performance

- **HyperSync**: Fast historical data sync via Envio's HyperSync
- **PostgreSQL**: Optimized for high-throughput writes
- **Multi-chain**: All chains indexed in parallel
- **Real-time**: New events processed within seconds

## Deployment

### Production Checklist

1. Set secure admin secret:
   ```bash
   HASURA_GRAPHQL_ADMIN_SECRET=your-secure-secret
   ```

2. Disable Hasura console:
   ```bash
   HASURA_GRAPHQL_ENABLE_CONSOLE=false
   ```

3. Use managed PostgreSQL (recommended)

4. Set up monitoring and alerts

5. Configure backup strategy

### HyperSync API Token

Starting November 3, 2025, HyperSync requires an API token. Get yours at:
https://docs.envio.dev/docs/HyperIndex/overview#hypersync-api-token-requirements

## Resources

- [Envio Documentation](https://docs.envio.dev/)
- [HyperSync](https://docs.envio.dev/docs/HyperIndex/hypersync)
- [Hasura Documentation](https://hasura.io/docs/)
- [GraphQL](https://graphql.org/learn/)

## Commands

```bash
yarn install      # Install dependencies
yarn codegen      # Generate TypeScript types
yarn start        # Start indexer
yarn dev          # Start in dev mode (auto-restart)
```

## Support

For issues or questions:
- Check [Envio Discord](https://discord.gg/envio)
- Review logs: `docker-compose logs -f`
- Verify configuration: `config.yaml`

---

**Built with Envio v2.32.3** - High-performance blockchain indexing

