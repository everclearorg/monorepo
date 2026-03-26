export const NATIVE_TOKEN = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE';
export const GELATO_SERVER = 'https://api.gelato.digital';

// Gelato executor EOA address — this is the address that actually sends transactions
// on-chain via Gelato's sendTransaction() relay mode. Must match msg.sender at the
// target contract for relayer checks (_relayer == msg.sender).
//
// Previously this was set to the Gelato relay forwarder contract (0xceA8...),
// which is NOT the msg.sender — the executor EOA calls the target directly.
// Override via GELATO_RELAYER_ADDRESS env var if Gelato rotates their executor.
const GELATO_EXECUTOR_DEFAULT = '0xE2D4A7ff2b7bB9f92AD5d1eDd438224C1646733C';
const GELATO_EXECUTOR_ZKSYNC = '0x30532F63B02c5bBb6D6f684Cbc7bebfC5deF407B';

export const getGelatoRelayerAddress = (domain: string): string => {
  // Allow env var override for all chains (in case Gelato rotates executor)
  const envOverride = process.env.GELATO_RELAYER_ADDRESS;
  if (envOverride) {
    return envOverride;
  }

  switch (domain) {
    case '280': // zkSync testnet
    case '324': // zkSync mainnet
      return GELATO_EXECUTOR_ZKSYNC;
    default:
      return GELATO_EXECUTOR_DEFAULT;
  }
};
