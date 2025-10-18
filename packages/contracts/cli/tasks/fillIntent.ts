import * as c from '../common';
import { Realm } from '../types';
import fetch from 'node-fetch';
import { select } from '@inquirer/prompts';
import { execSync } from 'child_process';

interface ApiIntent {
  intent_id: string;
  status: string;
  receiver: string;
  input_asset: string;
  output_asset: string;
  origin_amount: string;
  destination_amount: string;
  origin: string;
  destinations: string[];
  nonce: number;
  intent_created_timestamp: number;
  max_fee: string;
  call_data: string;
  filled: boolean;
  initiator: string;
  ttl: number;
  transaction_hash?: string;
  queue_idx?: number;
  message_id?: string;
  receive_tx_hash?: string;
  settlement_timestamp?: number;
  intent_created_block_number?: number;
  receive_blocknumber?: number;
  tx_origin?: string;
  tx_nonce?: number;
  auto_id?: number;
  native_fee?: string;
  token_fee?: string;
  fee_adapter_initiator?: string;
  origin_gas_fees?: string;
  destination_gas_fees?: string;
  hub_settlement_domain?: string;
}

interface ApiResponse {
  intents: ApiIntent[];
  nextCursor: string;
  prevCursor: string;
  maxCount: number;
}

export async function fillIntent(): Promise<void> {
  const environment = await c.chooseEnvironment();

  // Select destination chain where we want to fill the intent
  const destinationDomain = await c.chooseDomain(environment, Realm.SPOKE);
  const destinationAddress = await c.getContractAddress(destinationDomain!, Realm.SPOKE, environment);
  if (!destinationAddress) return;

  console.log('Destination Domain:', destinationDomain!.name, `(${destinationDomain!.id})`);
  console.log('Spoke address:', destinationAddress);

  // Get the account private key
  const account = await c.chooseAccount();
  
  // Get the solver address from the private key
  const solverAddress = await c.getAddressFromAccount(account, destinationDomain!.rpc);
  console.log('Solver address:', solverAddress);

  // Fetch intents from API
  console.log('\n--- Fetching intents from API ---');
  const apiUrl = environment === 'MainnetStaging' 
    ? 'https://api.staging.everclear.org/intents' 
    : 'https://api.everclear.org/intents';
  
  console.log('API URL:', apiUrl);

  const response = await fetch(apiUrl, {
    method: 'GET',
    headers: {
      'Accept': '*/*'
    },
  });

  if (!response.ok) {
    console.error(`API request failed: ${response.status} ${response.statusText}`);
    const errorText = await response.text();
    console.error('Error details:', errorText);
    return;
  }

  const data: ApiResponse = await response.json() as ApiResponse;
  console.log(`Found ${data.intents.length} total intents`);
  
  // Filter for unfilled intents
  const unfilledIntents = data.intents.filter(intent => !intent.filled);
  console.log(`Found ${unfilledIntents.length} unfilled intents`);

  if (unfilledIntents.length === 0) {
    console.log('No unfilled intents found.');
    return;
  }

  console.log(`\n--- Filtering for destination domain: ${destinationDomain!.id} ---`);

  // Filter intents that can be filled on the selected destination
  // An intent is fillable if it has ttl != 0 and maxFee != 0
  // Also accept specific statuses: ADDED, INVOICED, ADDED_HUB, DISPATCHED_SPOKE
  const fillableIntents = unfilledIntents.filter(intent => {
    const hasDestination = intent.destinations.includes(destinationDomain!.id.toString());
    const hasTTL = intent.ttl && intent.ttl !== 0;
    const hasMaxFee = intent.max_fee && intent.max_fee !== '0';
    const hasValidStatus = intent.status === 'ADDED' || intent.status === 'INVOICED' || intent.status === 'ADDED_HUB' || intent.status === 'DISPATCHED_SPOKE' || intent.status === 'DEPOSIT_PROCESSED';
    
    // An intent is fillable if it matches destination AND (has TTL+maxFee OR has valid status)
    const isFillable = hasDestination && (hasTTL && hasMaxFee) && hasValidStatus;
    
    console.log(`Intent ${intent.intent_id.slice(0, 10)}... - Destination: ${hasDestination}, TTL: ${intent.ttl}, MaxFee: ${intent.max_fee}, Status: ${intent.status}, Fillable: ${isFillable}`);
    return isFillable;
  });

  // Log detailed information only for fillable intents
  if (fillableIntents.length > 0) {
    console.log('\n=== Fillable Intents Details ===');
    fillableIntents.forEach((intent, idx) => {
      console.log(`\nIntent ${idx + 1}:`);
      console.log(`  ID: ${intent.intent_id.slice(0, 20)}...`);
      console.log(`  Status: ${intent.status}`);
      console.log(`  Filled: ${intent.filled}`);
      console.log(`  Initiator: ${intent.initiator}`);
      console.log(`  Receiver: ${intent.receiver}`);
      console.log(`  Origin: ${intent.origin}`);
      console.log(`  Destinations: [${intent.destinations.join(', ')}]`);
      console.log(`  Input Asset: ${intent.input_asset}`);
      console.log(`  Output Asset: ${intent.output_asset}`);
      console.log(`  Origin Amount: ${intent.origin_amount}`);
      console.log(`  Destination Amount: ${intent.destination_amount}`);
      console.log(`  Max Fee: ${intent.max_fee}`);
      console.log(`  TTL: ${intent.ttl}`);
      console.log(`  Nonce: ${intent.nonce}`);
      console.log(`  Timestamp: ${intent.intent_created_timestamp}`);
      console.log(`  Call Data: ${intent.call_data || '(empty)'}`);
      console.log(`  Transaction Hash: ${intent.transaction_hash || '(none)'}`);
    });
  }

  if (fillableIntents.length === 0) {
    console.log(`No fillable intents found for destination domain ${destinationDomain!.name}`);
    return;
  }

  console.log(`\nFound ${fillableIntents.length} fillable intents for ${destinationDomain!.name}`);

  // Let user select an intent to fill
  const selectedIntent = await select({
    message: 'Select an intent to fill',
    choices: fillableIntents.map((intent, idx) => ({
      name: `${idx + 1}. Intent ${intent.intent_id.slice(0, 10)}... | Amount: ${intent.origin_amount} | From domain: ${intent.origin}`,
      value: intent
    }))
  });

  console.log('\n=== Selected Intent - Full Object ===');
  console.log(JSON.stringify(selectedIntent, null, 2));
  
  // Get the fee adapter address from config for the origin domain
  const originDomain = parseInt(selectedIntent.origin);
  const spokeConfig = require('../config/spoke.json');
  const originSpokeConfig = spokeConfig.find((config: any) => 
    config.domainId === originDomain && config.environment === environment
  );
  
  if (!originSpokeConfig || !originSpokeConfig.feeAdapterAddress) {
    console.error(`❌ Error: No fee adapter address found for origin domain ${originDomain} in environment ${environment}`);
    return;
  }
  
  const feeAdapterAddress = originSpokeConfig.feeAdapterAddress;
  console.log(`Using fee adapter address for origin domain ${originDomain}: ${feeAdapterAddress}`);
  
  // Get token decimals for proper normalization
  let tokenDecimals = 18; // Default to 18 decimals
  try {
    // Convert bytes32 to address format if needed
    let outputAssetAddress = selectedIntent.output_asset;
    if (outputAssetAddress.length === 66) { // bytes32 format (0x + 64 chars)
      // Extract the last 40 characters (20 bytes) and add 0x prefix
      outputAssetAddress = '0x' + outputAssetAddress.slice(-40);
    }
    
    console.log(`Output asset for decimals query: ${outputAssetAddress}`);
    const decimalsCommand = `cast call ${outputAssetAddress} "decimals()(uint8)" --rpc-url ${destinationDomain!.rpc}`;
    const decimalsRaw = execSync(decimalsCommand, { encoding: 'utf-8' }).trim();
    tokenDecimals = parseInt(decimalsRaw.split(/[\s\[]/)[0]);
    console.log(`Token decimals: ${tokenDecimals}`);
  } catch (error) {
    console.log(`Could not fetch token decimals, using default 18: ${error}`);
  }
  
  // Normalize amount to 18 decimals (same as smart contract logic)
  const normalizeAmount = (amount: string, decimals: number) => {
    const amountBigInt = BigInt(amount);
    if (decimals === 18) {
      return amountBigInt.toString();
    } else if (decimals < 18) {
      // Multiply by 10^(18-decimals) to normalize to 18 decimals
      const multiplier = BigInt(10) ** BigInt(18 - decimals);
      return (amountBigInt * multiplier).toString();
    } else {
      // Divide by 10^(decimals-18) to normalize to 18 decimals
      const divisor = BigInt(10) ** BigInt(decimals - 18);
      return (amountBigInt / divisor).toString();
    }
  };
  
  const normalizedAmount = normalizeAmount(selectedIntent.origin_amount, tokenDecimals);
  console.log(`Original amount: ${selectedIntent.origin_amount}, Normalized to 18 decimals: ${normalizedAmount}`);

  console.log('\n=== Selected Intent Details ===');
  console.log('Intent ID:', selectedIntent.intent_id);
  console.log('Initiator (Fee Adapter):', feeAdapterAddress);
  console.log('Receiver:', selectedIntent.receiver);
  console.log('Origin Domain:', selectedIntent.origin);
  console.log('Destination Domains:', selectedIntent.destinations.join(', '));
  console.log('Input Asset:', selectedIntent.input_asset);
  console.log('Output Asset:', selectedIntent.output_asset);
  console.log('Origin Amount (Raw):', selectedIntent.origin_amount);
  console.log('Normalized Amount (18 decimals):', normalizedAmount);
  console.log('Destination Amount:', selectedIntent.destination_amount);
  console.log('Max Fee (BPS):', selectedIntent.max_fee);
  console.log('TTL:', selectedIntent.ttl);
  console.log('Nonce:', selectedIntent.nonce);
  console.log('Timestamp:', selectedIntent.intent_created_timestamp);
  console.log('Call Data:', selectedIntent.call_data);
  
  // Check if we have the necessary amount data
  if (!selectedIntent.origin_amount) {
    console.error('\n❌ Error: origin_amount is null!');
    console.error('This intent cannot be filled without amount information.');
    return;
  }

  // Input the fee the solver wants to charge (must be <= max_fee)
  const feeInput = await c.inputNumber(`Fee in BPS (maximum ${selectedIntent.max_fee})`);
  let fee = parseInt(feeInput);
  const maxFee = parseInt(selectedIntent.max_fee);
  if (fee > maxFee) {
    console.log(`Fee cannot exceed max fee of ${maxFee} BPS. Setting to max fee.`);
    fee = maxFee;
  }

  console.log('\n--- Checking solver balance and allowance ---');

  // Calculate amounts for balance checking (use actual token amounts)
  const originalAmountBigInt = BigInt(selectedIntent.origin_amount);
  console.log(`Using original amount for balance checking: ${originalAmountBigInt.toString()}`);
  
  // Fee is in BPS (basis points), so divide by 1000000 to get the percentage
  const feeAmount = (originalAmountBigInt * BigInt(fee)) / BigInt(1000000);
  const finalAmount = originalAmountBigInt - feeAmount;

  console.log('Original Amount (for balance check):', originalAmountBigInt.toString());
  console.log('Fee Amount:', feeAmount.toString());
  console.log('Final Amount (after fee):', finalAmount.toString());
  
  // Normalized amount is only used for the fillIntent call
  const normalizedAmountBigInt = BigInt(normalizedAmount);
  console.log('Normalized Amount (for fillIntent):', normalizedAmountBigInt.toString());
  
  // Debug: Check what the contract expects for fee calculation
  const normalizedFeeAmount = (normalizedAmountBigInt * BigInt(fee)) / BigInt(1000000);
  const normalizedFinalAmount = normalizedAmountBigInt - normalizedFeeAmount;
  console.log('Normalized Fee Amount:', normalizedFeeAmount.toString());
  console.log('Normalized Final Amount:', normalizedFinalAmount.toString());

  // Check wallet balance
  try {
    // Convert bytes32 to address format if needed for balance check
    let outputAssetAddress = selectedIntent.output_asset;
    if (outputAssetAddress.length === 66) { // bytes32 format (0x + 64 chars)
      // Extract the last 40 characters (20 bytes) and add 0x prefix
      outputAssetAddress = '0x' + outputAssetAddress.slice(-40);
    }
    
    const balanceCommand = `cast call ${outputAssetAddress} "balanceOf(address)(uint256)" ${solverAddress} --rpc-url ${destinationDomain!.rpc}`;
    const balanceRaw = execSync(balanceCommand, { encoding: 'utf-8' }).trim();
    const walletBalance = BigInt(balanceRaw.split(/[\s\[]/)[0]);
    
    console.log('Solver wallet balance:', walletBalance.toString());

    if (walletBalance < finalAmount) {
      console.error(`Insufficient balance! Required: ${finalAmount.toString()}, Have: ${walletBalance.toString()}`);
      return;
    }
  } catch (error) {
    console.error('Error checking balance:', error);
    return;
  }

  // Check deposited balance in spoke contract
  let depositedBalance = BigInt(0);
  // Convert addresses to bytes32 for the mapping lookup
  const outputAssetBytes32 = '0x' + selectedIntent.output_asset.slice(2).padStart(64, '0');
  const solverBytes32 = '0x' + solverAddress.slice(2).padStart(64, '0');
  
  try {
    console.log('Checking balance with:');
    console.log('  Output Asset (bytes32):', outputAssetBytes32);
    console.log('  Solver Address (bytes32):', solverBytes32);
    console.log('  Contract:', destinationAddress);
    
    const depositCommand = `cast call ${destinationAddress} "balances(bytes32,bytes32)(uint256)" ${outputAssetBytes32} ${solverBytes32} --rpc-url ${destinationDomain!.rpc}`;
    console.log('Balance command:', depositCommand);
    
    const depositRaw = execSync(depositCommand, { encoding: 'utf-8' }).trim();
    depositedBalance = BigInt(depositRaw.split(/[\s\[]/)[0]);
    
    console.log('Deposited balance in spoke:', depositedBalance.toString());
  } catch (error) {
    console.error('Error checking deposited balance:', error);
    return;
  }

  // Check if we need to deposit more
  if (depositedBalance < finalAmount) {
    const depositAmount = finalAmount - depositedBalance;
    console.log(`\nNeed to deposit ${depositAmount.toString()} to spoke contract`);

    // Check allowance for spoke contract
    let currentAllowance = BigInt(0);
    try {
      // Convert bytes32 to address format if needed for allowance check
      let outputAssetAddress = selectedIntent.output_asset;
      if (outputAssetAddress.length === 66) { // bytes32 format (0x + 64 chars)
        // Extract the last 40 characters (20 bytes) and add 0x prefix
        outputAssetAddress = '0x' + outputAssetAddress.slice(-40);
      }
      
      const allowanceCommand = `cast call ${outputAssetAddress} "allowance(address,address)(uint256)" ${solverAddress} ${destinationAddress} --rpc-url ${destinationDomain!.rpc}`;
      const allowanceRaw = execSync(allowanceCommand, { encoding: 'utf-8' }).trim();
      currentAllowance = BigInt(allowanceRaw.split(/[\s\[]/)[0]);
      
      console.log('Current allowance for spoke:', currentAllowance.toString());
    } catch (error) {
      console.error('Error checking allowance:', error);
      return;
    }

    // Approve if needed
    if (currentAllowance < depositAmount) {
      console.log(`\nApproving ${depositAmount.toString()} tokens for spoke contract...`);
      try {
        // Convert bytes32 to address format if needed for approval
        let outputAssetAddress = selectedIntent.output_asset;
        if (outputAssetAddress.length === 66) { // bytes32 format (0x + 64 chars)
          // Extract the last 40 characters (20 bytes) and add 0x prefix
          outputAssetAddress = '0x' + outputAssetAddress.slice(-40);
        }
        
        const approveCommand = `cast send ${outputAssetAddress} "approve(address,uint256)" ${destinationAddress} ${depositAmount.toString()} --rpc-url ${destinationDomain!.rpc} --private-key $${account}`;
        console.log('Executing approval transaction...');
        const approveResult = execSync(approveCommand, { encoding: 'utf-8' });
        console.log('Approval transaction result:', approveResult);
        console.log('✓ Approval successful');
      } catch (error) {
        console.error('Error approving tokens:', error);
        return;
      }
    }

    // Deposit to spoke contract
    console.log(`\nDepositing ${depositAmount.toString()} tokens to spoke contract...`);
    try {
      // Convert bytes32 to address format if needed for deposit
      let outputAssetAddress = selectedIntent.output_asset;
      if (outputAssetAddress.length === 66) { // bytes32 format (0x + 64 chars)
        // Extract the last 40 characters (20 bytes) and add 0x prefix
        outputAssetAddress = '0x' + outputAssetAddress.slice(-40);
      }
      
      const depositCommand = `cast send ${destinationAddress} "deposit(address,uint256)" ${outputAssetAddress} ${depositAmount.toString()} --rpc-url ${destinationDomain!.rpc} --private-key $${account}`;
      console.log('Executing deposit transaction...');
      const depositResult = execSync(depositCommand, { encoding: 'utf-8' });
      console.log('Deposit transaction result:', depositResult);
      console.log('✓ Deposit successful');
    } catch (error) {
      console.error('Error depositing tokens:', error);
      return;
    }
  } else {
    console.log('✓ Sufficient balance already deposited in spoke contract');
  }

  // Construct the Intent struct for fillIntent call
  console.log('\n=== Constructing Intent Struct ===');
  
  // Parse destinations array
  const destinationsArray = selectedIntent.destinations.map(d => parseInt(d));
  
  const intentStruct = {
    initiator: feeAdapterAddress, // Use fee adapter address from config
    receiver: selectedIntent.receiver,
    inputAsset: selectedIntent.input_asset,
    outputAsset: selectedIntent.output_asset,
    maxFee: selectedIntent.max_fee,
    origin: parseInt(selectedIntent.origin),
    nonce: selectedIntent.nonce,
    timestamp: selectedIntent.intent_created_timestamp,
    ttl: selectedIntent.ttl,
    amount: normalizedAmount, // Use normalized amount (18 decimals)
    destinations: destinationsArray,
    data: selectedIntent.call_data || '0x'
  };

  console.log('Intent Struct:');
  console.log(JSON.stringify(intentStruct, null, 2));
  
  // Debug: Check the format of the values from API
  console.log('\n=== Debug: API Values Format ===');
  console.log('Initiator from API:', selectedIntent.initiator, '(length:', selectedIntent.initiator.length, ')');
  console.log('Receiver from API:', selectedIntent.receiver, '(length:', selectedIntent.receiver.length, ')');
  console.log('Input Asset from API:', selectedIntent.input_asset, '(length:', selectedIntent.input_asset.length, ')');
  console.log('Output Asset from API:', selectedIntent.output_asset, '(length:', selectedIntent.output_asset.length, ')');
  console.log('Amount from API:', selectedIntent.origin_amount);

  // Call fillIntent function
  console.log('\n=== Calling FillIntent ===');
  
  // Convert addresses to bytes32 if needed (API might return address format)
  const convertToBytes32 = (value: string) => {
    if (value.length === 42) { // Address format (0x + 40 chars)
      return '0x' + value.slice(2).padStart(64, '0');
    }
    return value; // Already bytes32 format
  };
  
  const initiatorBytes32 = convertToBytes32(intentStruct.initiator);
  const receiverBytes32 = convertToBytes32(intentStruct.receiver);
  const inputAssetBytes32 = convertToBytes32(intentStruct.inputAsset);
  const outputAssetBytes32ForIntent = convertToBytes32(intentStruct.outputAsset);
  
  console.log('\n=== Debug: Converted Values ===');
  console.log('Initiator bytes32:', initiatorBytes32);
  console.log('Receiver bytes32:', receiverBytes32);
  console.log('Input Asset bytes32:', inputAssetBytes32);
  console.log('Output Asset bytes32:', outputAssetBytes32ForIntent);
  
  // Use the converted values
  const intentTuple = `(${initiatorBytes32},${receiverBytes32},${inputAssetBytes32},${outputAssetBytes32ForIntent},${intentStruct.maxFee},${intentStruct.origin},${intentStruct.nonce},${intentStruct.timestamp},${intentStruct.ttl},${intentStruct.amount},[${intentStruct.destinations.join(',')}],${intentStruct.data})`;
  
  console.log('Intent Tuple:', intentTuple);
  console.log('Fee:', fee);

  // Execute the fillIntent transaction
  try {
    console.log('\nExecuting fillIntent transaction...');
    const fillIntentCommand = `cast send ${destinationAddress} "fillIntent((bytes32,bytes32,bytes32,bytes32,uint24,uint32,uint64,uint48,uint48,uint256,uint32[],bytes),uint24)" "${intentTuple}" ${fee} --rpc-url ${destinationDomain!.rpc} --private-key $${account}`;
    console.log('Command:', fillIntentCommand);
    
    const fillIntentResult = execSync(fillIntentCommand, { encoding: 'utf-8' });
    console.log('FillIntent transaction result:', fillIntentResult);
    console.log('✓ FillIntent transaction successful');
  } catch (error) {
    console.error('Error executing fillIntent transaction:', error);
    return;
  }

  console.log('\n=== Summary ===');
  console.log('Intent ID:', selectedIntent.intent_id);
  console.log('Destination:', destinationDomain!.name, `(${destinationDomain!.id})`);
  console.log('Spoke Contract:', destinationAddress);
  console.log('Output Asset:', selectedIntent.output_asset);
  console.log('Amount to Transfer:', finalAmount.toString());
  console.log('Fee (BPS):', fee);
  console.log('Solver Address:', solverAddress);
  console.log('\n✓ Intent fill transaction completed successfully!');
}

