import SafeApiKit from '@safe-global/api-kit';
import Safe from '@safe-global/protocol-kit';
import { MetaTransactionData, OperationType } from '@safe-global/types-kit';
import { Wallet } from 'ethers';
import { SafeServiceConfig } from './config';
import { createLoggingContext, Logger, RequestContext } from '@chimera-monorepo/utils';
import { WriteTransaction } from './shared';
import { ContractNetworksConfig } from '@safe-global/protocol-kit/dist/src/types/contracts';

/**
 * @classdesc Proposes transactions to a Safe transaction service.
 */
export class SafeService {
  protected senderAddress: string;

  constructor(
    protected readonly logger: Logger,
    protected readonly config: SafeServiceConfig,
  ) {
    const wallet = new Wallet(this.config.safe.signer);
    this.senderAddress = wallet.address;
  }

  /**
   * Creates a new multi-signature transaction and stores it in the Safe transaction service.
   *
   * @param tx - Tx to propose
   * @param tx.to - Address to send tx to
   * @param tx.value - Value to send tx with
   * @param tx.data - Calldata to execute
   * @param context - RequestContext for logging
   *
   * @returns The hash of the Safe transaction proposed
   *
   * @throws "Invalid Safe address"
   * @throws "Invalid safeTxHash"
   * @throws "Invalid data"
   * @throws "Invalid ethereum address/User is not an owner/Invalid signature/
   * Nonce already executed/Sender is not an owner"
   */
  public async proposeTransaction(tx: WriteTransaction, context: RequestContext): Promise<string> {
    const { requestContext, methodContext } = createLoggingContext(this.proposeTransaction.name, context);
    this.logger.debug('Method start', requestContext, methodContext, {
      tx: { ...tx, value: tx.value.toString(), data: `${tx.data.substring(0, 9)}...` },
    });

    // Safe SDK does not support Everclear networks, hence need to set contract addresses ourselves.
    const contractNetworks = {
      [tx.domain.toString()]: {
        multiSendAddress: this.config.safe.safeAddress,
        multiSendCallOnlyAddress: this.config.safe.safeAddress,
        safeMasterCopyAddress: this.config.safe.masterCopyAddress,
        fallbackHandlerAddress: this.config.safe.fallbackHandlerAddress,
      },
    } as unknown as ContractNetworksConfig;

    const protocolKit = await Safe.init({
      provider: this.config.provider,
      signer: this.config.safe.signer,
      safeAddress: this.config.safe.safeAddress,
      contractNetworks,
    });

    const apiKit = new SafeApiKit({
      chainId: BigInt(this.config.domain),
      txServiceUrl: this.config.safe.txService,
    });

    // Create a Safe transaction
    const safeTransactionData: MetaTransactionData = {
      to: tx.to,
      value: tx.value,
      data: tx.data,
      operation: OperationType.Call,
    };

    const safeTransaction = await protocolKit.createTransaction({
      transactions: [safeTransactionData],
    });

    // Sign the transaction hash
    const safeTxHash = await protocolKit.getTransactionHash(safeTransaction);
    const signature = await protocolKit.signHash(safeTxHash);

    // Send the transaction to the transaction service
    await apiKit.proposeTransaction({
      safeAddress: this.config.safe.safeAddress,
      safeTransactionData: safeTransaction.data,
      safeTxHash,
      senderAddress: this.senderAddress,
      senderSignature: signature.data,
    });

    return safeTxHash;
  }
}
