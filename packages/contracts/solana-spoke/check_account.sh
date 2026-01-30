#!/bin/bash
# Quick check script for fee adapter state migration status

FEE_ADAPTER_STATE="D34rarD1GafLfoUuozpbshP1QJxtkogHS4ixQYmsB82a"
NETWORK="${SOLANA_NETWORK:-mainnet-beta}"

echo "Checking Fee Adapter State: $FEE_ADAPTER_STATE"
echo "Network: $NETWORK"
echo ""

# Check account info using Solana CLI
solana account "$FEE_ADAPTER_STATE" --url "$NETWORK" 2>&1 | head -20

echo ""
echo "To check migration status programmatically, run:"
echo "FEE_ADAPTER_STATE_ADDRESS=$FEE_ADAPTER_STATE ts-node scripts/checkMigrationStatus.ts"
