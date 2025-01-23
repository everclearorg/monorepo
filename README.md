# Everclear - Chimera Upgrade

This monorepo contains the components of the upcoming Chimera Upgrade for the Everclear Protocol.

## Packages

### Contracts

Solidity smart contracts for the on-chain logic of the protocol. These are categorized by `Common` (utils), `Intent` (supported chains) and `Hub` (Everclear Rollup).

### Adapters

### Utils

### Chainservice

To publish the npm package:
- Update version in `package.json`
- Run:

    ```
   git tag -a chainservice-v<VERSION>
   ```
- Push tag

   ```
  git push origin chainservice-v<VERSION>
   ```