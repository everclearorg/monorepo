#!/usr/bin/env node

// Import TronWeb with proper fallback handling
let TronWeb;
try {
  const TronWebModule = require('tronweb');
  // The actual constructor is nested in the module
  TronWeb = TronWebModule.TronWeb || TronWebModule.default || TronWebModule;
} catch (error) {
  console.error(`❌ Missing TronWeb dependency: ${error.message}`);
  console.log('\n📦 Install with: npm install tronweb');
  process.exit(1);
}

const readline = require('readline');

// Tron mainnet staging configuration from the config file
const TRON_CONFIG = {
  domain: "728126428",
  network: "tvm",
  rpc: "https://tron-rpc.publicnode.com",
  spokeContract: "419b266df36c882a73d45b18876104d5728424828f", // Hex format (provided by user)
  spokeContractBase58: "TQ7ZmvN6K2TaSpzbz8KUw8bSK2zsSeksxJ", // Correct Base58 format (provided by user)
  assets: {
    USDT: {
      symbol: "USDT",
      address: "0x000000000000000000000000a614f803b6fd780986a42c78ec9c7f77e6ded13c", // Hex format
      addressBase58: "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t", // Base58 format - standard USDT address
      decimals: 6
    },
    WETH: {
      symbol: "WETH",
      address: "0x00000000000000000000000053908308f4aa220fb10d778b5d1b34489cd6edfc", // Hex format  
      addressBase58: "TXWkP3jLBqRGojUih1ShzNyDaN5Csnebok", // Base58 format - manually converted
      decimals: 8
    }
  }
};

// Constants
const MAX_FEE = 10000; // 100% fee (10000 basis points)

// Create readline interface for user input
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

// Utility function to prompt user for input
function promptUser(question) {
  return new Promise((resolve) => {
    rl.question(question, (answer) => {
      resolve(answer.trim());
    });
  });
}

// Utility function to convert hex address to base58 (Tron format)
function hexToBase58(hexAddress) {
  try {
    // Remove 0x prefix if present
    const cleanHex = hexAddress.replace(/^0x/, '');
    // Ensure it starts with 41 for Tron addresses  
    const tronHex = cleanHex.startsWith('41') ? cleanHex : '41' + cleanHex.substring(2);
    
    // Use TronWeb static method with proper error handling  
    if (TronWeb && TronWeb.address && TronWeb.address.fromHex) {
      return TronWeb.address.fromHex(tronHex);
    } else {
      // Fallback to utils method if main method not available
      const TronWebModule = require('tronweb');
      if (TronWebModule.utils && TronWebModule.utils.address && TronWebModule.utils.address.fromHex) {
        return TronWebModule.utils.address.fromHex(tronHex);
      }
      throw new Error('TronWeb address conversion methods not available');
    }
  } catch (error) {
    console.error(`Error converting hex to base58: ${error.message}`);
    throw error;
  }
}

// Spoke contract ABI for newIntent function
const SPOKE_ABI = [
  {
    "inputs": [
      {"name": "_destinations", "type": "uint32[]"},
      {"name": "_to", "type": "address"},
      {"name": "_inputAsset", "type": "address"}, 
      {"name": "_outputAsset", "type": "address"},
      {"name": "_amount", "type": "uint256"},
      {"name": "_maxFee", "type": "uint24"},
      {"name": "_ttl", "type": "uint48"},
      {"name": "_data", "type": "bytes"}
    ],
    "name": "newIntent",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  }
];

// TRC20 token ABI for approve function
const TRC20_ABI = [
  {
    "inputs": [
      {"name": "_spender", "type": "address"},
      {"name": "_value", "type": "uint256"}
    ],
    "name": "approve",
    "outputs": [{"type": "bool"}],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {"name": "_owner", "type": "address"},
      {"name": "_spender", "type": "address"}
    ],
    "name": "allowance",
    "outputs": [{"type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{"name": "_owner", "type": "address"}],
    "name": "balanceOf", 
    "outputs": [{"type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "decimals",
    "outputs": [{"type": "uint8"}], 
    "stateMutability": "view",
    "type": "function"
  }
];

class TronIntentScript {
  constructor() {
    this.tronWeb = null;
    this.userAddress = null;
    this.privateKey = null;
    
    // Default values
    this.destinations = [10]; // Optimism by default
    this.to = null; // Will be set to sender address
    this.inputAsset = TRON_CONFIG.assets.USDT.addressBase58;
    this.outputAsset = null; // Will be set based on destination  
    this.amount = "1000000"; // 1 USDT (6 decimals)
    this.ttl = 0; // Default TTL is 0
    this.data = "0x"; // Empty data
    this.runs = 1;
  }

  async initialize() {
    console.log('🚀 Tron Intent Creation Script');
    console.log('=====================================');
    
    // Get private key
    this.privateKey = await promptUser('Enter your Tron private key: ');
    
    if (!this.privateKey) {
      throw new Error('Private key is required');
    }

    // Initialize TronWeb with proper constructor handling
    try {
      if (typeof TronWeb !== 'function') {
        throw new Error('TronWeb is not a constructor function');
      }
      
      this.tronWeb = new TronWeb({
        fullHost: TRON_CONFIG.rpc,
        privateKey: this.privateKey
      });
    } catch (error) {
      console.error('❌ Failed to initialize TronWeb:', error.message);
      console.log('TronWeb type:', typeof TronWeb);
      console.log('TronWeb value:', TronWeb);
      throw new Error(`TronWeb initialization failed: ${error.message}`);
    }

    // Get user address using instance method
    try {
      this.userAddress = this.tronWeb.address.fromPrivateKey(this.privateKey);
    } catch (error) {
      // Fallback to utils method
      const TronWebModule = require('tronweb');
      this.userAddress = TronWebModule.utils.address.fromPrivateKey(this.privateKey);
    }
    this.to = this.userAddress; // Default to sending to self
    
    console.log(`\n💼 Your address: ${this.userAddress}`);
    
    // Get user inputs
    await this.getUserInputs();
  }

  async getUserInputs() {
    console.log('\n⚙️  Configuration (using hardcoded values):');
    
    // Hardcoded values based on user's previous inputs
    this.destinations = [8453]; // Base
    console.log(`Selected destinations: [${this.destinations.join(', ')}]`);

    // Keep recipient as user's own address (Tron format)
    this.to = this.userAddress;
    console.log(`To address: ${this.to}`);

    // Use USDT
    this.inputAsset = TRON_CONFIG.assets.USDT.addressBase58;
    console.log(`Input asset: ${this.inputAsset}`);

    // Set output asset based on destination (simplified - would need real cross-chain asset mapping)
    this.outputAsset = this.inputAsset; // For now, same asset
    console.log(`Output asset: ${this.outputAsset}`);

    // 1 USDT
    const decimals = this.inputAsset === TRON_CONFIG.assets.USDT.addressBase58 ? 6 : 8;
    this.amount = (1 * Math.pow(10, decimals)).toString();
    console.log(`Amount: ${this.amount}`);

    // Default TTL
    this.ttl = 0;
    console.log(`TTL: ${this.ttl}`);

    // Single run
    this.runs = 1;
    console.log(`Runs: ${this.runs}`);
  }

  async checkBalance() {
    console.log('\n🔍 Checking balance...');
    
    try {
      // Use Base58 addresses that were working before
      const tokenContract = await this.tronWeb.contract(TRC20_ABI, this.inputAsset);
      const balance = await tokenContract.balanceOf(this.userAddress).call();
      const requiredAmount = BigInt(this.amount) * BigInt(this.runs);
      
      console.log(`Token: ${this.inputAsset}`);
      console.log(`User: ${this.userAddress}`);
      console.log(`Balance: ${balance.toString()}`);
      console.log(`Required: ${requiredAmount.toString()}`);
      
      if (BigInt(balance.toString()) < requiredAmount) {
        throw new Error(`Insufficient balance. Required: ${requiredAmount}, Available: ${balance}`);
      }
      
      console.log('✅ Balance check passed');
    } catch (error) {
      console.error('❌ Balance check failed:', error.message);
      throw error;
    }
  }

  async approveToken() {
    console.log('\n📝 Checking token approval...');
    
    try {
      const tokenContract = await this.tronWeb.contract(TRC20_ABI, this.inputAsset);
      const approveAmount = (BigInt(this.amount) * BigInt(this.runs)).toString();
      
      // Check current allowance first
      console.log('Checking current allowance...');
      const currentAllowance = await tokenContract.allowance(
        this.userAddress,
        TRON_CONFIG.spokeContractBase58
      ).call();
      
      console.log(`Current allowance: ${currentAllowance.toString()}`);
      console.log(`Required amount: ${approveAmount}`);
      
      if (BigInt(currentAllowance.toString()) >= BigInt(approveAmount)) {
        console.log('✅ Sufficient allowance already exists, skipping approval');
        return;
      }
      
      console.log(`Approving ${approveAmount} tokens for spoke contract...`);
      console.log(`Token: ${this.inputAsset}`);
      console.log(`Spender: ${TRON_CONFIG.spokeContractBase58}`);
      
      const txId = await tokenContract.approve(
        TRON_CONFIG.spokeContractBase58,
        approveAmount
      ).send({
        feeLimit: 500_000_000, // 500 TRX fee limit (higher for Energy)
        shouldPollResponse: true
      });
      
      console.log(`✅ Approval transaction: ${txId}`);
      console.log(`🔗 View on TronScan: https://tronscan.org/#/transaction/${txId}`);
      
      // Wait for confirmation
      await this.waitForTransaction(txId);
      
    } catch (error) {
      console.error('❌ Token approval failed:', error.message);
      throw error;
    }
  }

  async checkResourcesForIntent() {
    console.log('\n🔍 Checking account resources...');
    
    try {
      // Get account info
      const account = await this.tronWeb.trx.getAccount(this.userAddress);
      const accountResources = await this.tronWeb.trx.getAccountResources(this.userAddress);
      
      // Current resources
      const trxBalance = account.balance || 0;
      const energy = accountResources.EnergyUsed || 0;
      const energyLimit = accountResources.EnergyLimit || 0;
      const bandwidth = accountResources.NetUsed || 0;
      const bandwidthLimit = accountResources.NetLimit || 0;
      
      const availableEnergy = energyLimit - energy;
      const availableBandwidth = bandwidthLimit - bandwidth;
      
      // Calculate free bandwidth from TRX balance (1 TRX = ~1000 bandwidth)
      const freeBandwidthFromTrx = Math.floor(trxBalance / 1000); // Approximate
      const totalAvailableBandwidth = availableBandwidth + freeBandwidthFromTrx;
      
      console.log('\n📊 Current Account Resources:');
      console.log(`💰 TRX Balance: ${(trxBalance / 1_000_000).toFixed(2)} TRX`);
      console.log(`⚡ Energy: ${availableEnergy.toLocaleString()} / ${energyLimit.toLocaleString()} available`);
      console.log(`📡 Bandwidth: ${totalAvailableBandwidth.toLocaleString()} available (${availableBandwidth} staked + ${freeBandwidthFromTrx} from TRX)`);
      
      // Estimated requirements for newIntent call
      const estimatedEnergyNeeded = 150000; // Conservative estimate based on previous error
      const estimatedBandwidthNeeded = 500; // For transaction overhead
      const feeLimit = 200_000_000; // 200 TRX in SUN (more reasonable)
      const energyPrice = 420; // SUN per Energy unit (approximate)
      const maxEnergyFromFees = Math.floor(feeLimit / energyPrice);
      
      console.log('\n📋 Transaction Requirements:');
      console.log(`⚡ Estimated Energy Needed: ${estimatedEnergyNeeded.toLocaleString()}`);
      console.log(`📡 Estimated Bandwidth Needed: ${estimatedBandwidthNeeded.toLocaleString()}`);
      console.log(`💸 Fee Limit: ${(feeLimit / 1_000_000).toFixed(0)} TRX`);
      console.log(`⚡ Max Energy from Fees: ${maxEnergyFromFees.toLocaleString()}`);
      
      // Check if we have enough resources
      const totalAvailableEnergy = availableEnergy + maxEnergyFromFees;
      const hasEnoughEnergy = totalAvailableEnergy >= estimatedEnergyNeeded;
      const hasEnoughBandwidth = totalAvailableBandwidth >= estimatedBandwidthNeeded;
      const hasEnoughTrx = trxBalance >= feeLimit;
      
      console.log('\n✅ Resource Check Results:');
      console.log(`⚡ Energy: ${hasEnoughEnergy ? '✅' : '❌'} (${totalAvailableEnergy.toLocaleString()} available vs ${estimatedEnergyNeeded.toLocaleString()} needed)`);
      console.log(`📡 Bandwidth: ${hasEnoughBandwidth ? '✅' : '❌'} (${totalAvailableBandwidth.toLocaleString()} available vs ${estimatedBandwidthNeeded.toLocaleString()} needed)`);
      console.log(`💰 TRX for Fees: ${hasEnoughTrx ? '✅' : '❌'} (${(trxBalance / 1_000_000).toFixed(2)} TRX available vs ${(feeLimit / 1_000_000).toFixed(0)} TRX needed)`);
      
      if (!hasEnoughEnergy) {
        const energyShortfall = estimatedEnergyNeeded - totalAvailableEnergy;
        const additionalTrxNeeded = Math.ceil(energyShortfall * energyPrice / 1_000_000);
        console.log(`\n⚠️  Energy Shortfall: ${energyShortfall.toLocaleString()} Energy`);
        console.log(`💡 Suggestion: Add ${additionalTrxNeeded} TRX or stake TRX for Energy`);
      }
      
      if (!hasEnoughTrx) {
        const trxShortfall = (feeLimit - trxBalance) / 1_000_000;
        console.log(`\n⚠️  TRX Shortfall: ${trxShortfall.toFixed(2)} TRX`);
        console.log(`💡 Suggestion: Add ${Math.ceil(trxShortfall)} TRX to your account`);
      }
      
      return hasEnoughEnergy && hasEnoughBandwidth && hasEnoughTrx;
      
    } catch (error) {
      console.error('❌ Resource check failed:', error.message);
      return false;
    }
  }

  async createIntents() {
    console.log('\n🎯 Creating intents...');
    
    try {
      // Check resources first
      const hasEnoughResources = await this.checkResourcesForIntent();
      
      if (!hasEnoughResources) {
        throw new Error('Insufficient resources for transaction. Please check the suggestions above.');
      }
      
      // Use Base58 addresses that were working before
      const spokeContract = await this.tronWeb.contract(SPOKE_ABI, TRON_CONFIG.spokeContractBase58);
      
      console.log('\n📋 Intent details:');
      console.log(`- Destinations: [${this.destinations.join(', ')}]`);
      console.log(`- To: ${this.to}`);
      console.log(`- Input Asset: ${this.inputAsset}`);
      console.log(`- Output Asset: ${this.outputAsset}`);
      console.log(`- Amount: ${this.amount}`);
      console.log(`- Max Fee: ${MAX_FEE}`);
      console.log(`- TTL: ${this.ttl}`);
      console.log(`- Data: ${this.data}`);
      console.log(`- Runs: ${this.runs}`);
      
      for (let i = 0; i < this.runs; i++) {
        console.log(`\n📤 Creating intent ${i + 1}/${this.runs}...`);
        
        const txId = await spokeContract.newIntent(
          this.destinations,
          this.to,
          this.inputAsset,
          this.outputAsset,
          this.amount,
          MAX_FEE,
          this.ttl,
          this.data
        ).send({
          feeLimit: 200_000_000, // 200 TRX fee limit (more reasonable, unused is returned)
          shouldPollResponse: true,
          callValue: 0
        });
        
        console.log(`✅ Intent ${i + 1} created: ${txId}`);
        console.log(`🔗 View on TronScan: https://tronscan.org/#/transaction/${txId}`);
        
        // Wait for confirmation before next transaction
        await this.waitForTransaction(txId);
      }
      
      console.log('\n🎉 All intents created successfully!');
      
    } catch (error) {
      console.error('❌ Intent creation failed:', error.message);
      throw error;
    }
  }

  validateTronAddress(address) {
    try {
      // If it's a hex address, convert it first
      if (address.startsWith('0x')) {
        return hexToBase58(address);
      }
      
      // For Base58 addresses, do basic format validation
      if (address && address.length >= 30 && (address.startsWith('T') || address.startsWith('4'))) {
        // Basic format looks correct, return as is
        // We'll be permissive here since TronWeb validation might be too strict
        console.log(`Using address: ${address}`);
        return address;
      }
      
      throw new Error(`Invalid address format: ${address}`);
    } catch (error) {
      console.error(`Address validation failed for ${address}:`, error.message);
      throw new Error(`Invalid address provided: ${address}`);
    }
  }

  async waitForTransaction(txId) {
    console.log(`⏳ Waiting for transaction confirmation: ${txId}`);
    
    let attempts = 0;
    const maxAttempts = 30; // 30 seconds max wait
    
    while (attempts < maxAttempts) {
      try {
        const tx = await this.tronWeb.trx.getTransaction(txId);
        
        if (tx && Object.keys(tx).length > 0) {
          console.log('✅ Transaction confirmed');
          return tx;
        }
        
        await new Promise(resolve => setTimeout(resolve, 1000)); // Wait 1 second
        attempts++;
        
      } catch (error) {
        await new Promise(resolve => setTimeout(resolve, 1000));
        attempts++;
      }
    }
    
    console.log('⚠️  Transaction confirmation timeout, but continuing...');
  }

  async run() {
    try {
      await this.initialize();
      await this.checkBalance();
      await this.approveToken();
      await this.createIntents();
      
    } catch (error) {
      console.error('\n❌ Script failed:', error.message);
      process.exit(1);
      
    } finally {
      rl.close();
    }
  }
}

// Run the script
if (require.main === module) {
  const script = new TronIntentScript();
  script.run();
}

module.exports = TronIntentScript; 