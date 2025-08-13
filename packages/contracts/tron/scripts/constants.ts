// Global //
export const POLYMER_ISM: string = '41cbcbc532cf88bacf1c8a6359604c784d042bb692';
export const POLYMER_MAILBOX: string = '415b34081e9d453fc2ba925d893583d89d1b7175dd';
export const MESSAGE_RECEIVER: string = '4147120c330314b3929b3efa22234a069f84e2c80d';
export const CALL_EXECUTOR: string = '41902fdfc8e489100aadfc982d7c5144253b5dfb81';
export const GATEWAY_IMPL: string = '417039676630aba9606afa13bfb4b822d67c05282a';
export const SPOKE_IMPL: string = 'TRooMrhE5VP2JFRyBf74fqMijMGx8usXuX';
export const FEE_SIGNER: string = 'TPRnuwo64F7ndhEKhWByyPs7BgNMpzQwuP';
export const FEE_SIGNER_PROD: string = 'THFQDwfJJw4GSMdt4X7z2wRWDH7gGVNSB6';
export const tronLighthouse: string = 'TFAJBqyUQmudXW1fanNN4a5V76qEDTouT7';
export const tronWatchtower: string = 'TJx4rVn6Nf2P1ZL9m5G737EYLD3BQdF7rj';
export const tronOwner: string = 'TATCzhQqxq9DRppGHiEFvFuoDW6tHaESqg'; // NOTE: Using EOA to enable the update of the gateway
export const tronMaxSolversFee: number = 5000;
export const hubDomain: number = 25327;
export const tronIsm: string = POLYMER_ISM;
export const tronMailbox: string = POLYMER_MAILBOX;

// Implementations //
export const EVERCLEAR_SPOKE_IMPL = 'TRooMrhE5VP2JFRyBf74fqMijMGx8usXuX';
export const EVERCLEAR_SPOKE_GATEWAY_IMPL = '417039676630aba9606afa13bfb4b822d67c05282a'; // TLCbT376siRg4PvzGBXYq4a1xafWJyzM5n || 417039676630aba9606afa13bfb4b822d67c05282a
 
// Production //
export const SPOKE_PROD: string = '419b266df36c882a73d45b18876104d5728424828f'; // TQ7ZmvN6K2TaSpzbz8KUw8bSK2zsSeksxJ
export const EVERCLEAR_SPOKE_GATEWAY_PROD = '418fd8a4d1980fa73f060a37af5bf23d8fb2b68a0b';
export const hubGatewayProd: string = '41EFfAB7cCEBF63FbEFB4884964b12259d4374FaAa';
export const HUB_GATEWAY_PROD = '0x000000000000000000000000effab7ccebf63fbefb4884964b12259d4374faaa';
export const XERC20_MODULE_PROD: string = '41af50e223f96be03403e6a2535a2e4508bca1d778';
export const FEE_ADAPTER_PROD: string = 'TESPzRJKmCFRGPhxgdbhf7PDjTuDx52pK8';

// Upgrades // 
export const EVERCLEAR_SPOKE_IMPL_V5: string = 'TVNcMDJBV8V9mZaPqbxaj29QSiR4u7sMms';

// Staging //
export const SPOKE_STAGING: string = 'TVgfN2ewsCKmFd4NkP833NQzeFtZRXvp1g';
export const hubGatewayStaging: string = '41e5f2f4afad6211cfbd6a882d5a6a435530ee3909'; // 0xe5F2F4afAd6211cfBD6a882D5a6a435530Ee3909
export const HUB_GATEWAY_STAGING = '0x000000000000000000000000e5f2f4afad6211cfbd6a882d5a6a435530ee3909';
export const XERC20_MODULE_STAGING: string = '419239e1c157d6dc7d6249b37512455c5a489a6cd7';
export const FEE_ADAPTER_STAGING: string = 'TWycgYzTWmDfrUaTikcmFGJpfZRjQXPXyF';
export const EVERCLEAR_SPOKE_GATEWAY_STAGING = '411f7c443b1793e2223541ee90814fe2a1f8b8778f';

// Helper //
export function fetchAddresses(logProd: boolean) {
  const spokeAddress = logProd ? SPOKE_PROD : SPOKE_STAGING;
  const gatewayAddress = logProd ? EVERCLEAR_SPOKE_GATEWAY_PROD : EVERCLEAR_SPOKE_GATEWAY_STAGING;
  const xerc20Module = logProd ? XERC20_MODULE_PROD : XERC20_MODULE_STAGING;
  const feeAdapter = logProd ? FEE_ADAPTER_PROD : FEE_ADAPTER_STAGING;

  return { spokeAddress, gatewayAddress, xerc20Module, feeAdapter };
}