module.exports = {
    networks: {
      development: {
        privateKey: '',
        userFeePercentage: 100, // The percentage of resource consumption ratio.
        feeLimit: 100000000, // The TRX consumption limit for the deployment and trigger, unit is SUN
        fullNode: 'https://api.nileex.io',
        solidityNode: 'https://api.nileex.io',
        eventServer: 'https://event.nileex.io',
        network_id: '*'
      },
      mainnet: {
        privateKey: '',
        userFeePercentage: 100, // The percentage of resource consumption ratio.
        feeLimit: 100000000, // The TRX consumption limit for the deployment and trigger, unit is SUN
        fullNode: 'https://api.trongrid.io',
        solidityNode: 'https://api.trongrid.io',
        eventServer: 'https://api.trongrid.io',
        network_id: '*'
        }
    },
      compilers: {
        solc: {
          version: '0.8.23',
        }
    },
    solc: {
      optimizer: {
        enabled: true,
        runs: 200
      },
      evmVersion: 'london'
    }
  };