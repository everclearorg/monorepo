import { sendWithRelayerWithBackup } from '@chimera-monorepo/adapters-relayer';
import {
  QueueType,
  Queue,
  RequestContext,
  createLoggingContext,
  domainToChainId,
  jsonifyError,
  getNtpTimeSeconds,
  SOLANA_CHAINID,
  TRON_CHAINID,
} from '@chimera-monorepo/utils';
import { Interface, keccak256, defaultAbiCoder } from 'ethers/lib/utils';
import { WriteTransaction } from '@chimera-monorepo/chainservice';
import { getContext } from '../../context';
import { getQueueMethodName, getTypeHash } from './getMessageQueueConstants';
import { RelayerSendFailed } from '../../errors';
import { BigNumber } from 'ethers';
import { ethers } from 'ethers';
import { TronWeb } from 'tronweb';

const DEFAULT_SIGNATURE_TTL = 60 * 60; // 60 minutes

// NOTE: these values are stored onchain, and should be pulled from hub
const BASE_GAS = 40_000; // base gas for a transaction
const DEFAULT_GAS_BUFFER = 10_000; // 10% stored onchain
const DESTINATION_GAS_CONSUMPTION: Record<QueueType, number> = {
  [QueueType.Intent]: 1_750_000, // generous assumptions, variable gas consumption.
  [QueueType.Settlement]: 50_000, // NOTE: also stored onchain, should ideally be pulled from settler.
  [QueueType.Fill]: 1_750_000, // generous assumptions, variable gas consumption.
  [QueueType.Deposit]: 0, // Deposit queue is not a message queue, irrelevant
};

// NOTE: When sending messages from hub, may hit the gas limit on the origin if the destination chain
// has a higher gas limit. These values are derived from forge.
const MAX_SETTLEMENT_DEQUEUE = 900;
// Solana settlement message is limited because of the 1kb tx size limit.
const MAX_SETTLEMENT_DEQUEUE_SOLANA = 1;

// NOTE: We are now capping intents because of hyperlane gas calculations
// NOTE: This is reduced from 6 to 5 because of "default" gas limit on spoke is currently at 2M < 605_000 + 300_000 * 5
// TODO: increase this while increase messageGasLimit on spoke
const MAX_INTENT_DEQUEUE = 5;

const DEFAULT_HYPERLANE_BUFFER = 15_000; // 15%
const BPS_DENOMINATOR = 100_000;
const DEFAULT_BASE_MESSAGE_GAS_LIMIT = 605_000;
const DEFAULT_EXTRA_INTENT_MESSAGE_GAS_LIMIT = 300_000;

/**
 * Converts OriginIntent objects to the Intent struct format expected by the smart contract
 * @param originIntents Array of OriginIntent objects
 * @returns Array of Intent structs properly formatted for contract encoding
 */
function convertOriginIntentsToIntentStructs(originIntents: unknown[]): unknown[] {
  return originIntents.map((originIntent: unknown) => {
    const intent = originIntent as Record<string, unknown>;

    // Convert string addresses to bytes32 format for contract compatibility
    // The contract expects bytes32 for address fields, but database stores them as strings
    const convertAddressToBytes32 = (address: unknown, origin: unknown): string => {
      if (origin === TRON_CHAINID && typeof address === 'string' && !address.startsWith('0x')) {
        // Convert Tron address to Ethereum format
        return '0x' + TronWeb.address.toHex(address).slice(2).padStart(64, '0');
      }

      if (typeof address === 'string' && address.startsWith('0x')) {
        // Left-pad the address to 32 bytes (64 hex characters + 0x)
        // Ethereum addresses are 20 bytes, so we need to left-pad with zeros to make 32 bytes
        return '0x' + address.slice(2).padStart(64, '0');
      }

      return address as string;
    };

    return {
      initiator: convertAddressToBytes32(intent.initiator, intent.origin),
      receiver: convertAddressToBytes32(intent.receiver, intent.origin),
      inputAsset: convertAddressToBytes32(intent.inputAsset, intent.origin),
      outputAsset: convertAddressToBytes32(intent.outputAsset, intent.origin),
      amountOutMin: intent.amountOutMin,
      origin: intent.origin,
      nonce: intent.nonce,
      timestamp: intent.timestamp,
      ttl: intent.ttl,
      amount: intent.amount,
      destinations: intent.destinations,
      data: intent.data || '0x',
    };
  });
}

function messageGasLimit(domain: string, intentCount: number): number {
  const {
    config: { hub, chains },
  } = getContext();
  const defaultMessageGasLimit = {
    base: DEFAULT_BASE_MESSAGE_GAS_LIMIT,
    extraIntent: DEFAULT_EXTRA_INTENT_MESSAGE_GAS_LIMIT,
  };
  const chainMessageGasLimit = chains[domain]?.messageGasLimit ?? defaultMessageGasLimit;
  // NOTE: if queue = hub, we call contract with _bufferDBPS as hub contract do not have dynamic message gas limit upgrade
  return domain === hub.domain
    ? DEFAULT_HYPERLANE_BUFFER
    : chainMessageGasLimit.base + (intentCount - 1) * chainMessageGasLimit.extraIntent;
}

export const dispatchMessageQueueViaRelayers = async (
  type: QueueType,
  queue: Queue,
  sortedContents: unknown[], // OriginIntent, DestinationIntent, HubIntent
  _requestContext: RequestContext,
): Promise<string[]> => {
  const {
    config: { chains, hub, abis },
    logger,
    adapters: { relayers, wallet, chainservice },
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(dispatchMessageQueueViaRelayers.name, _requestContext);
  logger.debug('Method started', requestContext, methodContext, { type, queue });
  const spokes = Object.keys(chains).filter((d) => d !== hub.domain);

  // Ensure the spoke is configured
  if (!chains[queue.domain]) {
    logger.warn('Missing chain config', requestContext, methodContext, {
      queue,
      spokes,
      hub: hub.domain,
    });
    return [];
  }

  // Get addresses from deployment
  const transactionDomain = queue.type === 'SETTLEMENT' ? hub.domain : queue.domain;
  const { gateway, everclear } =
    transactionDomain === hub.domain ? hub.deployments : chains[transactionDomain].deployments ?? {};
  if (!gateway || !everclear) {
    logger.warn('Missing gateway or everclear address', requestContext, methodContext, {
      queue,
      spoke: queue.domain,
      chains,
    });
    return [];
  }
  const everclearIface = new Interface(transactionDomain === hub.domain ? abis.hub.everclear : abis.spoke.everclear);

  // Get the number of elements to dequeue
  // Maxes are defined by the lowest block gas limit on the message route.
  // Message route is defined by origin chain, the queue type, and the environment
  // hub chain.

  // Get the destination. If transacting on hub, destination is the spoke and vice versa.
  const destinationDomain = transactionDomain === hub.domain ? queue.domain : hub.domain;
  const blockLimit = BigNumber.from(chains[destinationDomain].gasLimit!);
  const bufferMultiple = BigNumber.from(BPS_DENOMINATOR + DEFAULT_GAS_BUFFER).div(BPS_DENOMINATOR);
  const gasAvailable = blockLimit
    .mul(BPS_DENOMINATOR)
    .div(BPS_DENOMINATOR + DEFAULT_GAS_BUFFER)
    .sub(BASE_GAS);
  const calculatedMax = gasAvailable.div(DESTINATION_GAS_CONSUMPTION[type]).toNumber();
  let maxDequeue = calculatedMax;
  switch (type) {
    case QueueType.Settlement:
      if (destinationDomain === SOLANA_CHAINID) {
        maxDequeue = Math.min(calculatedMax, MAX_SETTLEMENT_DEQUEUE_SOLANA);
      } else {
        maxDequeue = Math.min(calculatedMax, MAX_SETTLEMENT_DEQUEUE);
      }
      break;
    case QueueType.Intent:
      maxDequeue = Math.min(calculatedMax, MAX_INTENT_DEQUEUE);
      break;
  }

  if (maxDequeue === 0) {
    logger.warn('Unable to retrieve max dequeue elements', requestContext, methodContext, {
      transactionDomain,
      destinationDomain,
      bufferMultiple: bufferMultiple.toString(),
      blockLimit: blockLimit.toString(),
    });
    return [];
  }

  const totalIntents = queue.size;
  logger.debug('Processing queue', requestContext, methodContext, { type, queue, totalIntents, maxDequeue });

  // Dequeue in batches
  // This handles the case where the queue is too large to dequeue in a single transaction
  // Can happen in failure scenarios where the queue is not processed for a long time

  // Get the nonce for the signer (each transaction in the batch must increment the nonce)

  // Use `pending` block tag for hub chains because they're lazy blockchains right now.
  const blockTag = transactionDomain == hub.domain ? 'pending' : 'latest';

  const walletAddr = await wallet.getAddress();

  // Get the nonce for the signer from the contract
  let nonce: BigNumber;
  if (transactionDomain === SOLANA_CHAINID) {
    // Solana doesn't have EVM-style contracts, use default nonce
    logger.info('Using default nonce for Solana chain', requestContext, methodContext, {
      transactionDomain,
    });
    nonce = BigNumber.from(0);
  } else {
    // For EVM-compatible chains (including Tron), read nonce from contract
    logger.info('Reading nonce from contract', requestContext, methodContext, {
      transactionDomain,
      chainType: transactionDomain === TRON_CHAINID ? 'Tron' : 'EVM',
      walletAddr,
      everclear,
    });

    try {
      const encodedNonce = await chainservice.readTx(
        {
          to: everclear,
          data: everclearIface.encodeFunctionData('nonces', [walletAddr]),
          domain: +transactionDomain,
          funcSig: everclearIface.getFunction('nonces').format(),
        },
        blockTag,
      );
      [nonce] = everclearIface.decodeFunctionResult('nonces', encodedNonce) as [BigNumber];

      logger.info('Successfully read nonce from contract', requestContext, methodContext, {
        transactionDomain,
        walletAddr,
        nonce: nonce.toString(),
      });
    } catch (error) {
      logger.error(
        'Failed to read nonce from contract - CRITICAL ERROR',
        requestContext,
        methodContext,
        jsonifyError(error as Error),
        {
          transactionDomain,
          walletAddr,
          everclear,
        },
      );
      // DO NOT fallback to nonce 0 - throw error to identify root cause
      throw new Error(
        `Failed to read nonce from contract for domain ${transactionDomain}: ${(error as Error).message}`,
      );
    }
  }

  const taskIds: Record<number, string> = {};
  for (let i = 0; i < totalIntents; i += maxDequeue) {
    const toDequeue = Math.min(maxDequeue, totalIntents - i);
    // Trim intents to match max elements, sorted by block number
    const trimmedIntents = sortedContents.slice(i, i + toDequeue);
    if (trimmedIntents.length !== toDequeue) {
      logger.error('Trimmed intents do not match dequeue target', requestContext, methodContext, undefined, {
        trimmedIntents: trimmedIntents.length ? trimmedIntents : '[]',
        toDequeue,
        sortedContents: sortedContents.length ? sortedContents : '[]',
        totalIntents,
        index: i,
      });
      break;
    }

    // NOTE: the signature _must_ include the relayer address, meaning a different
    // relayer transaction will be required for each configured relayer.
    const errors: Error[] = [];
    for (const relayer of relayers) {
      try {
        logger.debug('Generating transaction for relayer', requestContext, methodContext, {
          relayer: relayer.type,
          queue,
          toDequeue,
          owner: walletAddr,
        });
        const relayerAddress = await relayer.instance.getRelayerAddress(domainToChainId(transactionDomain));

        // Generate the signature
        const ttl = getNtpTimeSeconds() + DEFAULT_SIGNATURE_TTL;
        logger.debug('Generating signature', requestContext, methodContext, {
          typeHash: getTypeHash(type),
          domain: transactionDomain,
          toDequeue,
          relayerAddress,
          ttl,
          nonce: nonce.toString(),
          signer: walletAddr,
        });

        // NOTE: Settlement queue encodes buffer after the nonce. Spoke queues do not.
        const types = ['bytes32', 'uint32', 'uint32', 'address', 'uint256', 'uint256', 'uint256'];
        const payload = defaultAbiCoder.encode(types, [
          getTypeHash(type),
          +queue.domain, // Fix: Convert string domain to number for proper ABI encoding
          toDequeue,
          relayerAddress,
          ttl,
          nonce,
          messageGasLimit(queue.type === 'SETTLEMENT' ? hub.domain : queue.domain, toDequeue),
        ]);
        const digest = keccak256(payload);

        // Use different signing methods for different chains
        let signature: string;
        if (transactionDomain === TRON_CHAINID) {
          // For Tron, the contract uses MessageHashUtils.toEthSignedMessageHash()
          // which applies the Ethereum message prefix "\x19Ethereum Signed Message:\n32"
          // We can use wallet.signMessage(digest) which applies the same prefix automatically
          logger.info('Using Tron signing with Ethereum message prefix compatibility', requestContext, methodContext, {
            digest,
            transactionDomain,
          });

          // For Tron, use the lighthouse's web3signer (which has the correct lighthouse private key)
          // This ensures the signature comes from the lighthouse address expected by the contract
          signature = await wallet.signMessage(ethers.utils.arrayify(digest));

          // Calculate prefixed hash for logging
          const prefix = '\x19Ethereum Signed Message:\n32';
          const prefixedMessage = ethers.utils.concat([
            ethers.utils.toUtf8Bytes(prefix),
            ethers.utils.arrayify(digest),
          ]);
          const prefixedHash = ethers.utils.keccak256(prefixedMessage);

          logger.info('Generated Tron signature with Ethereum message prefix', requestContext, methodContext, {
            signature,
            digest,
            prefixedHash,
          });
        } else {
          // For Ethereum and other EVM chains, use standard Ethereum message signing
          // The contract will apply MessageHashUtils.toEthSignedMessageHash to the payload hash,
          // so we need to sign the raw digest bytes using signMessage which applies the same prefix
          signature = await wallet.signMessage(ethers.utils.arrayify(digest));
        }
        logger.info('Generated signature', requestContext, methodContext, {
          typeHash: getTypeHash(type),
          domain: transactionDomain,
          toDequeue,
          relayerAddress,
          ttl,
          nonce: nonce.toString(),
          payload,
          signature,
          signer: walletAddr,
        });

        const queueMethodName = getQueueMethodName(type);

        // Convert OriginIntent objects to Intent structs for proper contract encoding
        const intentStructs = type === 'INTENT' ? convertOriginIntentsToIntentStructs(trimmedIntents) : toDequeue;

        // CRITICAL FIX: Use the actual length of intentStructs for signature generation
        // This ensures the signature matches what the contract will validate
        const actualIntentCount = type === 'INTENT' ? (intentStructs as unknown[]).length : (intentStructs as number);

        // Re-generate payload with the correct intent count
        const correctedPayload = defaultAbiCoder.encode(types, [
          getTypeHash(type),
          +queue.domain, // Fix: Convert string domain to number for proper ABI encoding
          actualIntentCount, // Use actual intent count instead of toDequeue
          relayerAddress,
          ttl,
          nonce,
          messageGasLimit(queue.type === 'SETTLEMENT' ? hub.domain : queue.domain, actualIntentCount),
        ]);
        const correctedDigest = keccak256(correctedPayload);

        // Re-generate signature with corrected payload
        let correctedSignature: string;
        if (transactionDomain === TRON_CHAINID) {
          logger.info('Re-generating Tron signature with corrected intent count', requestContext, methodContext, {
            originalToDequeue: toDequeue,
            actualIntentCount,
            correctedDigest,
            transactionDomain,
          });
          correctedSignature = await wallet.signMessage(ethers.utils.arrayify(correctedDigest));
        } else {
          correctedSignature = await wallet.signMessage(ethers.utils.arrayify(correctedDigest));
        }

        logger.info('Generated corrected signature', requestContext, methodContext, {
          typeHash: getTypeHash(type),
          domain: transactionDomain,
          originalToDequeue: toDequeue,
          actualIntentCount,
          relayerAddress,
          ttl,
          nonce: nonce.toString(),
          correctedPayload,
          correctedSignature,
          signer: walletAddr,
        });

        const funcSig = everclearIface.getFunction(queueMethodName).format();

        logger.info('Generating transaction', requestContext, methodContext, {
          queueDomain: queue.domain,
          transactionDomain,
          funcSig,
          intentStructs,
        });

        const tx: WriteTransaction = {
          data: everclearIface.encodeFunctionData(queueMethodName, [
            +queue.domain, // Fix: Convert string domain to number for proper ABI encoding
            intentStructs,
            relayerAddress,
            ttl,
            nonce,
            messageGasLimit(queue.type === 'SETTLEMENT' ? hub.domain : queue.domain, actualIntentCount),
            correctedSignature, // Use corrected signature
          ]),
          to: everclear,
          value: '0',
          domain: +transactionDomain,
          funcSig,
        };

        logger.debug(
          'Sending process queue transaction to relayer with corrected signature',
          requestContext,
          methodContext,
          {
            type,
            queue,
            originalToDequeue: toDequeue,
            actualIntentCount,
            relayerAddress,
            ttl,
            nonce: nonce.toString(),
            correctedSignature,
            correctedPayload,
            tx,
          },
        );

        const { taskId, relayerType } = await sendWithRelayerWithBackup(
          domainToChainId(tx.domain),
          tx.domain.toString(),
          tx.to,
          tx.data,
          tx.value,
          tx.funcSig,
          [relayer],
          chainservice,
          logger,
          requestContext,
        );
        logger.info('Dispatched queue', requestContext, methodContext, {
          type,
          taskId,
          relayerType,
          queue,
        });
        taskIds[i] = taskId;
        // exit early if the task was dispatched
        break;
      } catch (e) {
        logger.error('Failed to dispatch queue', requestContext, methodContext, jsonifyError(e as Error), {
          relayer: relayer.type,
          type,
          queue,
          toDequeue,
        });
        errors.push(e as Error);
      }
    }

    // Error if all relayers fail for any batch
    if (errors.length === relayers.length) {
      logger.info('Failed to dispatch full queue', requestContext, methodContext, {
        completed: Object.keys(taskIds).length,
        pending: totalIntents - Object.keys(taskIds).length,
        tasks: Object.values(taskIds),
        type,
        queue,
      });
      throw new RelayerSendFailed(
        queue.domain,
        relayers.map((r) => r.type),
        errors,
      );
    }

    // Increment the nonce for the next batch
    nonce = nonce.add(1);
    // FIXME: Should process the full batch
    break;
  }
  return Object.values(taskIds);
};
