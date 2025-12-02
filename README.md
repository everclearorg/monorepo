# Everclear - Chimera Upgrade

This monorepo contains the components of the upcoming Chimera Upgrade for the Everclear Protocol.

## Packages

### Contracts

Solidity smart contracts for the on-chain logic of the protocol. These are categorized by `Common` (utils), `Intent` (supported chains) and `Hub` (Everclear Rollup).

### Adapters

### Utils

### Chainservice

Service for on-chain transaction submissions, reading on-chain state, and managing domains/providers.

This package is automatically deployed by the CI pipeline when its `package.json` version is updated. Because it depends on the following workspace packages, make sure their `package.json` versions are synchronized to the updated version.
- /contracts
- /utils

Dependency order: /contracts -> /utils -> /chainservice