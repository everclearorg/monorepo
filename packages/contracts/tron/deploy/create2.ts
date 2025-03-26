// // Run command: yarn ts-node --files --project tsconfig.json tron/deploy/create2.ts
// import TronWeb from 'tronweb';

// import Create2Deployer from '../build/contracts/Create2Deployer.json';

// // Public RPCs for Tron
// const MAINNET_RPC = 'https://tron-rpc.publicnode.com';
// const NILE_RPC = 'https://nile.trongrid.io';

// const tronWeb = new TronWeb({
//   fullHost: NILE_RPC,
//   privateKey: 'd7c1222cb9b938dffb88f406623278e5d53b8b2c93b5dd2e876ea69f8703df7b',
// });

// (async () => {
//   try {
//     console.log('Deploying create2 deployer');
//     const deployer = await tronWeb.contract().new(Create2Deployer);
//     console.log('Deployed create2 deployer at address', deployer.address);
//   } catch (error) {
//     console.log('Error deploying create2 deployer', error);
//   }
// })();