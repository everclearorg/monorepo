export const NATIVE_TOKEN = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE';
export const GELATO_SERVER = 'https://api.gelato.digital';

// Testnet addresses (2/5)
// - On all networks except zkSync: 0xF9D64d54D32EE2BDceAAbFA60C4C438E224427d0
// - On zkSync: 0x0c1B63765Be752F07147ACb80a7817A8b74d9831
// So, for testnets you can already update the whitelist to these new addresses.

export const getGelatoRelayerAddress = (domain: string): string =>
  domain === '2053862260' || // zksync testnet
  domain === '2053862243' // zksync mainnet
    ? '0x0c1B63765Be752F07147ACb80a7817A8b74d9831'
    : '0xF9D64d54D32EE2BDceAAbFA60C4C438E224427d0'; // all other networks
