export const NATIVE_TOKEN = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE';
export const GELATO_SERVER = 'https://api.gelato.digital';

export const getGelatoRelayerAddress = (domain: string): string => {
  switch (domain) {
    case '280': // zkSync testnet
    case '324': // zkSync mainnet
      return '0x0c1B63765Be752F07147ACb80a7817A8b74d9831';
    case '130': // Unichain
      return '0xC6e576260853e8eDb7a683Ff1233747Ad9904f16';
    default:
      return '0xF9D64d54D32EE2BDceAAbFA60C4C438E224427d0'; // all other networks
  }
};
