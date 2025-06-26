export const NATIVE_TOKEN = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE';
export const GELATO_SERVER = 'https://api.gelato.digital';

export const getGelatoRelayerAddress = (domain: string): string => {
  switch (domain) {
    case '280': // zkSync testnet
    case '324': // zkSync mainnet
      return '0x30532F63B02c5bBb6D6f684Cbc7bebfC5deF407B';
    default:
      return '0xceA8aAa918bc6C19e5B77841ebD77ff3188385AF'; // all other networks
  }
};
