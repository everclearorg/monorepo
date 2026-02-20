import { expect } from 'chai';
import { restore } from 'sinon';
import {
  toOriginIntents,
  fromOriginIntent,
  originIntentFromIntent,
  settlementIntentFromIntent,
  toSettlementIntents,
  fromSettlementIntents,
  toDestinationIntents,
  fromDestinationIntent,
  toHubIntents,
  fromHubIntent,
  toMessages,
  fromMessages,
  toQueues,
  fromQueue,
  toAssets,
  fromAsset,
  toTokens,
  fromToken,
  toBalances,
  fromBalance,
  toHubInvoices,
  fromHubInvoices,
  toHubDeposits,
  fromHubDeposits,
  toMerkleTree,
  fromMerkleTree,
  toLockPosition,
  fromLockPosition,
  toProtocolUpdateLog,
  fromProtocolUpdateLogs,
  toHubTokenUpdateLog,
  toHubAssetUpdateLog,
  toHubMeta,
  fromHubMeta,
  toSpokeMeta,
  fromSpokeMeta,
} from '../src/lib/converters';
import {
  createOriginIntent,
  createDestinationIntent,
  createSettlementIntent,
  createHubIntent,
  createMessage,
  createQueue,
  createAsset,
  createToken,
  createHubInvoice,
  createHubDeposit,
  createMerkleTree,
  createLockPosition,
  createHubTokenUpdateLog,
  createHubAssetUpdateLog,
} from './mock';

describe('Database Converters', () => {
  afterEach(() => {
    restore();
  });

  describe('toOriginIntents', () => {
    it('should convert origin intent to database format', () => {
      const originIntent = createOriginIntent({
        id: '0x1',
        queueIdx: 1,
        messageId: '0x2',
        status: 'ADDED',
        receiver: '0x123',
        inputAsset: '0x456',
        outputAsset: '0x789',
        amount: '100',
        maxFee: 100,
        destinations: ['1338'],
        origin: '1337',
        nonce: 1,
        data: '0x',
        initiator: '0x123',
        ttl: 10000,
        transactionHash: '0xdef',
        timestamp: 1234567890,
        blockNumber: 1,
        gasLimit: '1231243',
        gasPrice: '12234234',
        txOrigin: '0x123',
        txNonce: 1,
        nativeFee: '100',
        tokenFee: '200',
        feeAdapterInitiator: '0x999',
        orderId: '0x888',
      });

      const result = toOriginIntents(originIntent);

      expect(result).to.deep.include({
        id: '0x1',
        queue_idx: 1,
        message_id: '0x2',
        status: 'ADDED',
        receiver: '0x123',
        input_asset: '0x456',
        output_asset: '0x789',
        amount: '100',
        max_fee: '0',
        destinations: ['1338'],
        origin: '1337',
        nonce: 1,
        data: '0x',
        initiator: '0x123',
        ttl: 10000,
        transaction_hash: '0xdef',
        timestamp: 1234567890,
        block_number: 1,
        gas_limit: 1231243,
        gas_price: 12234234,
        tx_origin: '0x123',
        tx_nonce: 1,
        native_fee: '100',
        token_fee: '200',
        fee_adapter_initiator: '0x999',
        order_id: '0x888',
      });
    });

    it('should handle undefined optional fields', () => {
      const originIntent = createOriginIntent({
        messageId: undefined,
        nativeFee: undefined,
        tokenFee: undefined,
        feeAdapterInitiator: undefined,
        orderId: undefined,
      });

      const result = toOriginIntents(originIntent);

      expect(result.message_id).to.be.undefined;
      expect(result.native_fee).to.be.undefined;
      expect(result.token_fee).to.be.undefined;
      expect(result.fee_adapter_initiator).to.be.undefined;
      expect(result.order_id).to.be.undefined;
    });
  });

  describe('fromOriginIntent', () => {
    it('should convert database record to origin intent', () => {
      const dbRecord = {
        id: '0x1',
        queue_idx: 1,
        message_id: '0x2',
        status: 'ADDED',
        receiver: '0x123',
        input_asset: '0x456',
        output_asset: '0x789',
        amount: '100',
        max_fee: '100',
        destinations: ['1338'],
        origin: '1337',
        nonce: 1,
        data: '0x',
        initiator: '0x123',
        ttl: 10000,
        transaction_hash: '0xdef ',
        timestamp: 1234567890,
        block_number: 1,
        gas_limit: 1231243,
        gas_price: 12234234,
        tx_origin: '0x123',
        tx_nonce: 1,
        native_fee: '100',
        token_fee: '200',
        fee_adapter_initiator: '0x999',
        order_id: '0x888',
      };

      const result = fromOriginIntent(dbRecord);

      expect(result).to.deep.include({
        id: '0x1',
        queueIdx: 1,
        messageId: '0x2',
        status: 'ADDED',
        receiver: '0x123',
        inputAsset: '0x456',
        outputAsset: '0x789',
        amount: '100',
        destinations: ['1338'],
        origin: '1337',
        nonce: 1,
        data: '0x',
        initiator: '0x123',
        ttl: 10000,
        transactionHash: '0xdef',
        timestamp: 1234567890,
        blockNumber: 1,
        gasLimit: '1231243',
        gasPrice: '12234234',
        txOrigin: '0x123',
        txNonce: 1,
        nativeFee: '100',
        tokenFee: '200',
        feeAdapterInitiator: '0x999',
        orderId: '0x888',
      });
    });

    it('should handle null optional fields', () => {
      const dbRecord = {
        id: '0x1',
        queue_idx: 1,
        message_id: null,
        status: 'ADDED',
        receiver: '0x123',
        input_asset: '0x456',
        output_asset: '0x789',
        amount: '100',
        max_fee: '100',
        destinations: ['1338'],
        origin: '1337',
        nonce: 1,
        data: null,
        initiator: '0x123',
        ttl: 10000,
        transaction_hash: '0xdef',
        timestamp: 1234567890,
        block_number: 1,
        gas_limit: 1231243,
        gas_price: 12234234,
        tx_origin: '0x123',
        tx_nonce: 1,
        native_fee: null,
        token_fee: null,
        fee_adapter_initiator: null,
        order_id: null,
      };

      const result = fromOriginIntent(dbRecord);

      expect(result.messageId).to.be.undefined;
      expect(result.data).to.equal('0x');
      expect(result.nativeFee).to.be.undefined;
      expect(result.tokenFee).to.be.undefined;
      expect(result.feeAdapterInitiator).to.be.undefined;
      expect(result.orderId).to.be.undefined;
    });
  });

  describe('originIntentFromIntent', () => {
    it('should convert intent record to origin intent', () => {
      const intentRecord = {
        id: '0x1',
        origin_initiator: '0x123',
        origin_queue_idx: 1,
        origin_message_id: '0x2',
        origin_status: 'ADDED',
        origin_receiver: '0x123',
        origin_input_asset: '0x456',
        origin_output_asset: '0x789',
        origin_amount: '100',
        origin_max_fee: '100',
        origin_destinations: ['1338'],
        origin_origin: '1337',
        origin_nonce: 1,
        origin_data: '0x',
        origin_ttl: 10000,
        origin_transaction_hash: '0xdef ',
        origin_timestamp: 1234567890,
        origin_block_number: 1,
        origin_gas_limit: 1231243,
        origin_gas_price: 12234234,
        origin_tx_origin: '0x123',
        origin_tx_nonce: 1,
        origin_native_fee: '100',
        origin_token_fee: '200',
        origin_fee_adapter_initiator: '0x999',
        origin_order_id: '0x888',
      };

      const result = originIntentFromIntent(intentRecord);

      expect(result).to.deep.include({
        id: '0x1',
        queueIdx: 1,
        messageId: '0x2',
        status: 'ADDED',
        receiver: '0x123',
        inputAsset: '0x456',
        outputAsset: '0x789',
        amount: '100',
        destinations: ['1338'],
        origin: '1337',
        nonce: 1,
        data: '0x',
        initiator: '0x123',
        ttl: 10000,
        transactionHash: '0xdef',
        timestamp: 1234567890,
        blockNumber: 1,
        gasLimit: '1231243',
        gasPrice: '12234234',
        txOrigin: '0x123',
        txNonce: 1,
        nativeFee: '100',
        tokenFee: '200',
        feeAdapterInitiator: '0x999',
        orderId: '0x888',
      });
    });

    it('should throw error when origin_origin is missing', () => {
      const intentRecord = {
        id: '0x1',
        origin_origin: null,
      };

      expect(() => originIntentFromIntent(intentRecord)).to.throw('Origin intent not found for intent 0x1');
    });

    it('should handle null optional fields', () => {
      const intentRecord = {
        id: '0x1',
        origin_initiator: '0x123',
        origin_queue_idx: 1,
        origin_message_id: null,
        origin_status: 'ADDED',
        origin_receiver: '0x123',
        origin_input_asset: '0x456',
        origin_output_asset: '0x789',
        origin_amount: '100',
        origin_max_fee: '100',
        origin_destinations: ['1338'],
        origin_origin: '1337',
        origin_nonce: 1,
        origin_data: null,
        origin_ttl: 10000,
        origin_transaction_hash: '0xdef',
        origin_timestamp: 1234567890,
        origin_block_number: 1,
        origin_gas_limit: 1231243,
        origin_gas_price: 12234234,
        origin_tx_origin: '0x123',
        origin_tx_nonce: 1,
        origin_native_fee: null,
        origin_token_fee: null,
        origin_fee_adapter_initiator: null,
        origin_order_id: null,
      };

      const result = originIntentFromIntent(intentRecord);

      expect(result.messageId).to.be.undefined;
      expect(result.data).to.equal('0x');
      expect(result.nativeFee).to.be.undefined;
      expect(result.tokenFee).to.be.undefined;
      expect(result.feeAdapterInitiator).to.be.undefined;
      expect(result.orderId).to.be.undefined;
    });
  });

  describe('settlementIntentFromIntent', () => {
    it('should convert intent record to settlement intent', () => {
      const intentRecord = {
        id: '0x1',
        settlement_amount: '1000',
        settlement_asset: '0x2',
        settlement_recipient: '0x123',
        settlement_domain: '1337',
        settlement_status: 'SETTLED',
        settlement_transaction_hash: '0xdef',
        settlement_timestamp: 1234567890,
        settlement_block_number: 1,
        settlement_tx_origin: '0x123',
        settlement_tx_nonce: 1,
        settlement_gas_limit: 1231243,
        settlement_gas_price: 12234234,
      };

      const result = settlementIntentFromIntent(intentRecord);

      expect(result).to.deep.include({
        intentId: '0x1',
        amount: '1000',
        asset: '0x2',
        recipient: '0x123',
        domain: '1337',
        status: 'SETTLED',
        transactionHash: '0xdef',
        timestamp: 1234567890,
        blockNumber: 1,
        txOrigin: '0x123',
        txNonce: 1,
        gasLimit: '1231243',
        gasPrice: '12234234',
      });
    });

    it('should throw error when settlement_amount is missing', () => {
      const intentRecord = {
        id: '0x1',
        settlement_amount: null,
      };

      expect(() => settlementIntentFromIntent(intentRecord)).to.throw('Settlement intent not found for intent 0x1');
    });
  });

  describe('toSettlementIntents', () => {
    it('should convert settlement intent to database format', () => {
      const settlementIntent = createSettlementIntent({
        intentId: '0x1',
        amount: '1000',
        asset: '0x2',
        recipient: '0x123',
        domain: '1337',
        status: 'SETTLED',
        returnData: '0x',
        transactionHash: '0xdef',
        timestamp: 1234567890,
        blockNumber: 1,
        txOrigin: '0x123',
        txNonce: 1,
        gasLimit: '1231243',
        gasPrice: '12234234',
      });

      const result = toSettlementIntents(settlementIntent);

      expect(result).to.deep.include({
        id: '0x1',
        amount: '1000',
        asset: '0x2',
        recipient: '0x123',
        domain: '1337',
        status: 'SETTLED',
        return_data: '0x',
        transaction_hash: '0xdef',
        timestamp: 1234567890,
        block_number: 1,
        tx_origin: '0x123',
        tx_nonce: 1,
        gas_limit: 1231243,
        gas_price: 12234234,
      });
    });
  });

  describe('fromSettlementIntents', () => {
    it('should convert database record to settlement intent', () => {
      const dbRecord = {
        id: '0x1',
        amount: '1000',
        asset: '0x2',
        recipient: '0x123',
        domain: '1337',
        status: 'SETTLED',
        return_data: '0x',
        transaction_hash: '0xdef',
        timestamp: 1234567890,
        block_number: 1,
        tx_origin: '0x123',
        tx_nonce: 1,
        gas_limit: 1231243,
        gas_price: 12234234,
      };

      const result = fromSettlementIntents(dbRecord);

      expect(result).to.deep.include({
        intentId: '0x1',
        amount: '1000',
        asset: '0x2',
        recipient: '0x123',
        domain: '1337',
        status: 'SETTLED',
        returnData: '0x',
        transactionHash: '0xdef',
        timestamp: 1234567890,
        blockNumber: 1,
        txOrigin: '0x123',
        txNonce: 1,
        gasLimit: '1231243',
        gasPrice: '12234234',
      });
    });
  });

  describe('toDestinationIntents', () => {
    it('should convert destination intent to database format', () => {
      const destinationIntent = createDestinationIntent({
        id: '0x1',
        queueIdx: 1,
        messageId: '0x2',
        status: 'ADDED',
        receiver: '0x123',
        inputAsset: '0x456',
        outputAsset: '0x789',
        amount: '100',
        destination: '1338',
        origin: '1337',
        nonce: 1,
        solver: '0xfffffff',
        initiator: '0x11111',
        fee: '100',
        data: '0x',
        maxFee: 500,
        destinations: ['1338'],
        ttl: 10000,
        returnData: '0x',
        transactionHash: '0xdef',
        timestamp: 1234567890,
        blockNumber: 1,
        gasLimit: '1231243',
        gasPrice: '12234234',
        txOrigin: '0x123',
        txNonce: 1,
      });

      const result = toDestinationIntents(destinationIntent);

      expect(result).to.deep.include({
        id: '0x1',
        queue_idx: 1,
        message_id: '0x2',
        status: 'ADDED',
        receiver: '0x123',
        input_asset: '0x456',
        output_asset: '0x789',
        amount: '100',
        filled_domain: '1338',
        origin: '1337',
        nonce: 1,
        solver: '0xfffffff',
        initiator: '0x11111',
        fee: '100',
        data: '0x',
        max_fee: '0',
        destinations: ['1338'],
        ttl: 10000,
        return_data: '0x',
        transaction_hash: '0xdef',
        timestamp: 1234567890,
        block_number: 1,
        gas_limit: 1231243,
        gas_price: 12234234,
        tx_origin: '0x123',
        tx_nonce: 1,
      });
    });
  });

  describe('fromDestinationIntent', () => {
    it('should convert database record to destination intent', () => {
      const dbRecord = {
        id: '0x1',
        queue_idx: 1,
        message_id: '0x2',
        status: 'ADDED',
        receiver: '0x123',
        input_asset: '0x456',
        output_asset: '0x789',
        amount: '100',
        filled_domain: '1338',
        origin: '1337',
        nonce: 1,
        solver: '0xfffffff',
        initiator: '0x11111',
        fee: '100',
        data: '0x',
        max_fee: '500',
        destinations: ['1338'],
        ttl: 10000,
        return_data: '0x',
        transaction_hash: '0xdef ',
        timestamp: 1234567890,
        block_number: 1,
        gas_limit: 1231243,
        gas_price: 12234234,
        tx_origin: '0x123',
        tx_nonce: 1,
      };

      const result = fromDestinationIntent(dbRecord);

      expect(result).to.deep.include({
        id: '0x1',
        queueIdx: 1,
        messageId: '0x2',
        status: 'ADDED',
        receiver: '0x123',
        inputAsset: '0x456',
        outputAsset: '0x789',
        amount: '100',
        destination: '1338',
        origin: '1337',
        nonce: 1,
        solver: '0xfffffff',
        initiator: '0x11111',
        fee: '100',
        data: '0x',
        destinations: ['1338'],
        ttl: 10000,
        returnData: '0x',
        transactionHash: '0xdef',
        timestamp: 1234567890,
        blockNumber: 1,
        gasLimit: '1231243',
        gasPrice: '12234234',
        txOrigin: '0x123',
        txNonce: 1,
      });
    });
  });

  describe('toHubIntents', () => {
    it('should convert hub intent to database format', () => {
      const hubIntent = createHubIntent({
        id: '0x1',
        status: 'ADDED',
        domain: '1339',
        queueIdx: 1,
        messageId: '0xhub-settlement',
        addedTimestamp: 1234567890,
        addedTxNonce: 1,
        filledTimestamp: 1234567890,
        filledTxNonce: 1,
        settlementEnqueuedTimestamp: 1234567890,
        settlementEnqueuedTxNonce: 1,
        settlementDomain: '1337',
        settlementEnqueuedBlockNumber: 1,
        settlementAmount: '1000',
        settlementEpoch: 1,
        updateVirtualBalance: false,
      });

      const result = toHubIntents(hubIntent);

      expect(result).to.deep.include({
        id: '0x1',
        status: 'ADDED',
        domain: '1339',
        queue_idx: 1,
        message_id: '0xhub-settlement',
        added_timestamp: 1234567890,
        added_tx_nonce: 1,
        filled_timestamp: 1234567890,
        filled_tx_nonce: 1,
        settlement_enqueued_timestamp: 1234567890,
        settlement_enqueued_tx_nonce: 1,
        settlement_domain: '1337',
        settlement_enqueued_block_number: 1,
        settlement_amount: '1000',
        settlement_epoch: 1,
        update_virtual_balance: false,
      });
    });
  });

  describe('fromHubIntent', () => {
    it('should convert database record to hub intent', () => {
      const dbRecord = {
        id: '0x1',
        status: 'ADDED',
        domain: '1339',
        queue_idx: 1,
        message_id: '0xhub-settlement',
        added_timestamp: 1234567890,
        added_tx_nonce: 1,
        filled_timestamp: 1234567890,
        filled_tx_nonce: 1,
        settlement_enqueued_timestamp: 1234567890,
        settlement_enqueued_tx_nonce: 1,
        settlement_domain: '1337',
        settlement_enqueued_block_number: 1,
        settlement_amount: '1000',
        settlement_epoch: 1,
        update_virtual_balance: false,
      };

      const result = fromHubIntent(dbRecord);

      expect(result).to.deep.include({
        id: '0x1',
        status: 'ADDED',
        domain: '1339',
        queueIdx: 1,
        messageId: '0xhub-settlement',
        addedTimestamp: 1234567890,
        addedTxNonce: 1,
        filledTimestamp: 1234567890,
        filledTxNonce: 1,
        settlementEnqueuedTimestamp: 1234567890,
        settlementEnqueuedTxNonce: 1,
        settlementDomain: '1337',
        settlementEnqueuedBlockNumber: 1,
        settlementAmount: '1000',
        settlementEpoch: 1,
        updateVirtualBalance: false,
      });
    });
  });

  describe('toMessages', () => {
    it('should convert message to database format', () => {
      const message = createMessage({
        id: '0x1',
        type: 'INTENT',
        domain: '1337',
        originDomain: '1337',
        destinationDomain: '1338',
        quote: '100',
        first: 1,
        last: 2,
        intentIds: ['0x1'],
        status: 'none',
        txOrigin: '0x123',
        transactionHash: '0x456',
        timestamp: 1234567890,
        blockNumber: 1,
        txNonce: 1,
        gasPrice: '100000',
        gasLimit: '10000',
      });

      const result = toMessages(message);

      expect(result).to.deep.include({
        id: '0x1',
        type: 'INTENT',
        domain: '1337',
        origin_domain: '1337',
        destination_domain: '1338',
        quote: '100',
        first: 1,
        last: 2,
        intent_ids: ['0x1'],
        message_status: 'none',
        tx_origin: '0x123',
        transaction_hash: '0x456',
        timestamp: 1234567890,
        block_number: 1,
        tx_nonce: 1,
        gas_price: 100000,
        gas_limit: 10000,
      });
    });
  });

  describe('fromMessages', () => {
    it('should convert database record to message', () => {
      const dbRecord = {
        id: '0x1',
        type: 'INTENT',
        domain: '1337',
        origin_domain: '1337',
        destination_domain: '1338',
        quote: '100',
        first: 1,
        last: 2,
        intent_ids: ['0x1'],
        status: 'none',
        tx_origin: '0x123',
        transaction_hash: '0x456',
        timestamp: 1234567890,
        block_number: 1,
        tx_nonce: 1,
        gas_price: '100000',
        gas_limit: '10000',
      };

      const result = fromMessages(dbRecord);

      expect(result).to.deep.include({
        id: '0x1',
        type: 'INTENT',
        domain: '1337',
        originDomain: '1337',
        destinationDomain: '1338',
        quote: '100',
        first: 1,
        last: 2,
        intentIds: ['0x1'],
        status: 'none',
        txOrigin: '0x123',
        transactionHash: '0x456',
        timestamp: 1234567890,
        blockNumber: 1,
        txNonce: 1,
        gasPrice: '100000',
        gasLimit: '10000',
      });
    });
  });

  describe('toQueues', () => {
    it('should convert queue to database format', () => {
      const queue = createQueue({
        id: '0x1',
        domain: '1337',
        lastProcessed: 1,
        size: 1,
        first: 1,
        last: 1,
        type: 'INTENT',
      });

      const result = toQueues(queue);

      expect(result).to.deep.include({
        id: '0x1',
        domain: '1337',
        last_processed: 1,
        size: 1,
        first: 1,
        last: 1,
        type: 'INTENT',
      });
    });
  });

  describe('fromQueue', () => {
    it('should convert database record to queue', () => {
      const dbRecord = {
        id: '0x1',
        domain: '1337',
        last_processed: 1,
        size: 1,
        first: 1,
        last: 1,
        type: 'INTENT',
      };

      const result = fromQueue(dbRecord);

      expect(result).to.deep.include({
        id: '0x1',
        domain: '1337',
        lastProcessed: 1,
        size: 1,
        first: 1,
        last: 1,
        type: 'INTENT',
      });
    });
  });

  describe('toAssets', () => {
    it('should convert asset to database format', () => {
      const asset = createAsset({
        id: '0xaa',
        token: '0xee',
        domain: '1337',
        adopted: '0xad',
        approval: true,
        strategy: 'DEFAULT',
      });

      const result = toAssets(asset);

      expect(result).to.deep.include({
        id: '0xaa',
        token_id: '0xee',
        domain: '1337',
        adopted: '0xad',
        approval: true,
        strategy: 'DEFAULT',
      });
    });
  });

  describe('fromAsset', () => {
    it('should convert database record to asset', () => {
      const dbRecord = {
        id: '0xaa',
        token_id: '0xee',
        domain: '1337',
        adopted: '0xad',
        approval: true,
        strategy: 'DEFAULT',
      };

      const result = fromAsset(dbRecord);

      expect(result).to.deep.include({
        id: '0xaa',
        token: '0xee',
        domain: '1337',
        adopted: '0xad',
        approval: true,
        strategy: 'DEFAULT',
      });
    });
  });

  describe('toTokens', () => {
    it('should convert token to database format', () => {
      const token = createToken({
        id: '0xee',
        feeRecipients: ['0xfee'],
        feeAmounts: ['100'],
        maxDiscountBps: 100,
        discountPerEpoch: 100,
        prioritizedStrategy: 'DEFAULT',
      });

      const result = toTokens(token);

      expect(result).to.deep.include({
        id: '0xee',
        fee_recipients: ['0xfee'],
        fee_amounts: ['100'],
        max_discount_bps: 100,
        discount_per_epoch: 100,
        prioritized_strategy: 'DEFAULT',
      });
    });
  });

  describe('fromToken', () => {
    it('should convert database record to token', () => {
      const dbRecord = {
        id: '0xee',
        fee_recipients: ['0xfee'],
        fee_amounts: ['100'],
        max_discount_bps: 100,
        discount_per_epoch: 100,
        prioritized_strategy: 'DEFAULT',
      };

      const result = fromToken(dbRecord);

      expect(result).to.deep.include({
        id: '0xee',
        feeRecipients: ['0xfee'],
        feeAmounts: ['100'],
        maxDiscountBps: 100,
        discountPerEpoch: 100,
        prioritizedStrategy: 'DEFAULT',
      });
    });
  });


  describe('toBalances', () => {
    it('should convert balance to database format', () => {
      const balance = {
        id: '0x1',
        account: '0x123',
        asset: '0x456',
        amount: '1000',
      };

      const result = toBalances(balance);

      expect(result).to.deep.include({
        id: '0x1',
        account: '0x123',
        asset: '0x456',
        amount: '1000',
      });
    });
  });

  describe('fromBalance', () => {
    it('should convert database record to balance', () => {
      const dbRecord = {
        id: '0x1',
        account: '0x123',
        asset: '0x456',
        amount: '1000',
      };

      const result = fromBalance(dbRecord);

      expect(result).to.deep.include({
        id: '0x1',
        account: '0x123',
        asset: '0x456',
        amount: '1000',
      });
    });
  });

  describe('toHubInvoices', () => {
    it('should convert hub invoice to database format', () => {
      const hubInvoice = createHubInvoice({
        id: '0xaa',
        intentId: '0xbb',
        tickerHash: '0xee',
        amount: '100',
        owner: '0xad',
        entryEpoch: 1,
        enqueuedTimestamp: 1234567890,
        enqueuedTxNonce: 1,
        enqueuedBlockNumber: 1,
        enqueuedTransactionHash: '0x123',
      });

      const result = toHubInvoices(hubInvoice);

      expect(result).to.deep.include({
        id: '0xaa',
        intent_id: '0xbb',
        ticker_hash: '0xee',
        amount: '100',
        owner: '0xad',
        entry_epoch: 1,
        enqueued_timestamp: 1234567890,
        enqueued_tx_nonce: 1,
        enqueued_block_number: 1,
        enqueued_transaction_hash: '0x123',
      });
    });
  });

  describe('fromHubInvoices', () => {
    it('should convert database record to hub invoice', () => {
      const dbRecord = {
        id: '0xaa',
        intent_id: '0xbb',
        ticker_hash: '0xee',
        amount: '100',
        owner: '0xad',
        entry_epoch: 1,
        enqueued_timestamp: 1234567890,
        enqueued_tx_nonce: 1,
        enqueued_block_number: 1,
        enqueued_transaction_hash: '0x123',
      };

      const result = fromHubInvoices(dbRecord);

      expect(result).to.deep.include({
        id: '0xaa',
        intentId: '0xbb',
        tickerHash: '0xee',
        amount: '100',
        owner: '0xad',
        entryEpoch: 1,
        enqueuedTimestamp: 1234567890,
        enqueuedTxNonce: 1,
        enqueuedBlockNumber: 1,
        enqueuedTransactionHash: '0x123',
      });
    });
  });

  describe('toHubDeposits', () => {
    it('should convert hub deposit to database format', () => {
      const hubDeposit = createHubDeposit({
        id: '0x1',
        intentId: '0x1',
        domain: '1337',
        epoch: 1,
        amount: '100',
        tickerHash: '0x123',
        enqueuedTimestamp: 1234567890,
        enqueuedTxNonce: 12,
        processedTimestamp: 1234567890,
        processedTxNonce: 13,
      });

      const result = toHubDeposits(hubDeposit);

      expect(result).to.deep.include({
        id: '0x1',
        intent_id: '0x1',
        domain: '1337',
        epoch: 1,
        amount: '100',
        ticker_hash: '0x123',
        enqueued_timestamp: 1234567890,
        enqueued_tx_nonce: 12,
        processed_timestamp: 1234567890,
        processed_tx_nonce: 13,
      });
    });
  });

  describe('fromHubDeposits', () => {
    it('should convert database record to hub deposit', () => {
      const dbRecord = {
        id: '0x1',
        intent_id: '0x1',
        domain: '1337',
        epoch: 1,
        amount: '100',
        ticker_hash: '0x123',
        enqueued_timestamp: 1234567890,
        enqueued_tx_nonce: 12,
        processed_timestamp: 1234567890,
        processed_tx_nonce: 13,
      };

      const result = fromHubDeposits(dbRecord);

      expect(result).to.deep.include({
        id: '0x1',
        intentId: '0x1',
        domain: '1337',
        epoch: 1,
        amount: '100',
        tickerHash: '0x123',
        enqueuedTimestamp: 1234567890,
        enqueuedTxNonce: 12,
        processedTimestamp: 1234567890,
        processedTxNonce: 13,
      });
    });
  });

  describe('toMerkleTree', () => {
    it('should convert merkle tree to database format', () => {
      const merkleTree = createMerkleTree({
        asset: '0x123',
        epochEndTimestamp: new Date('2024-01-01T00:00:00Z'),
        merkleTree: '{}',
        root: '0x1',
        proof: '0x1',
      });

      const result = toMerkleTree(merkleTree);

      expect(result).to.deep.include({
        asset: '0x123',
        epoch_end_timestamp: '2024-01-01T00:00:00.000',
        merkle_tree: '{}',
        root: '0x1',
        proof: '0x1',
      });
    });
  });

  describe('fromMerkleTree', () => {
    it('should convert database record to merkle tree', () => {
      const dbRecord = {
        asset: '0x123',
        epoch_end_timestamp: new Date('2024-01-01T00:00:00Z'),
        merkle_tree: '{}',
        root: '0x1',
        proof: '0x1',
      };

      const result = fromMerkleTree(dbRecord);

      expect(result).to.have.property('epochEndTimestamp').that.is.a('Date');
      expect(result).to.deep.include({
        asset: '0x123',
        merkleTree: '{}',
        root: '0x1',
        proof: '0x1',
      });
    });
  });

  describe('toLockPosition', () => {
    it('should convert lock position to database format', () => {
      const lockPosition = createLockPosition({
        user: '0x1',
        amountLocked: '98765',
        start: 1733405000,
        expiry: 1735990000,
      });

      const result = toLockPosition(lockPosition);

      expect(result).to.deep.include({
        user: '0x1',
        amount_locked: '98765',
        start: 1733405000,
        expiry: 1735990000,
      });
    });
  });

  describe('fromLockPosition', () => {
    it('should convert database record to lock position', () => {
      const dbRecord = {
        user: '0x1',
        amount_locked: '98765',
        start: 1733405000,
        expiry: 1735990000,
      };

      const result = fromLockPosition(dbRecord);

      expect(result).to.deep.include({
        user: '0x1',
        amountLocked: '98765',
        start: 1733405000,
        expiry: 1735990000,
      });
    });
  });

  describe('toProtocolUpdateLog', () => {
    it('should convert protocol update log to database format', () => {
      const log = {
        id: '0xlog1',
        domain: '1337',
        chainId: '1337',
        event: 'GATEWAY_UPDATED',
        key: 'gateway',
        updated: '0x1234',
        transactionHash: '0xabc',
        timestamp: 1000,
        blockNumber: 200,
        txOrigin: '0x1',
        txNonce: 5,
      };

      const result = toProtocolUpdateLog(log);

      expect(result).to.deep.equal({
        id: '0xlog1',
        domain: '1337',
        event: 'GATEWAY_UPDATED',
        key: 'gateway',
        updated: '0x1234',
        chain_id: '1337',
        transaction_hash: '0xabc',
        timestamp: 1000,
        block_number: 200,
        tx_origin: '0x1',
        tx_nonce: 5,
      });
    });

    it('should use domain as chain_id when chainId is missing', () => {
      const log = {
        id: '0xlog2',
        domain: '1338',
        event: 'PAUSED',
        key: 'paused',
        updated: '1',
        transactionHash: '0xdef',
        timestamp: 2000,
        blockNumber: 300,
        txOrigin: '0x2',
        txNonce: 6,
      };

      const result = toProtocolUpdateLog(log as Parameters<typeof toProtocolUpdateLog>[0]);

      expect(result.chain_id).to.equal('1338');
    });
  });

  describe('toHubTokenUpdateLog', () => {
    it('should convert hub token update log to database format', () => {
      const log = createHubTokenUpdateLog({
        id: 'token-log-1',
        domain: '1339',
        tickerHash: '0xticker',
        kind: 'MAX_DISCOUNT_DBPS_SET',
        feeRecipients: ['0xaaa'],
        feeAmounts: ['1', '2'],
        maxDiscountBps: 777,
        discountPerEpoch: 11,
        prioritizedStrategy: 'DEFAULT',
        transactionHash: '0xtx',
        timestamp: 123,
        blockNumber: 456,
        txOrigin: '0xabc',
        txNonce: 9,
      });

      const result = toHubTokenUpdateLog(log);
      expect(result).to.deep.equal({
        id: 'token-log-1',
        domain: '1339',
        ticker_hash: '0xticker',
        kind: 'MAX_DISCOUNT_DBPS_SET',
        fee_recipients: ['0xaaa'],
        fee_amounts: ['1', '2'],
        max_discount_bps: 777,
        discount_per_epoch: 11,
        prioritized_strategy: 'DEFAULT',
        transaction_hash: '0xtx',
        timestamp: 123,
        block_number: 456,
        tx_origin: '0xabc',
        tx_nonce: 9,
      });
    });
  });

  describe('toHubAssetUpdateLog', () => {
    it('should convert hub asset update log to database format', () => {
      const log = createHubAssetUpdateLog({
        id: 'asset-log-1',
        domain: '1339',
        assetId: '0xasset',
        tokenId: '0xticker',
        tickerHash: '0xticker',
        assetDomain: '1337',
        kind: 'ASSET_CONFIG_SET',
        assetHash: '0xhash',
        adopted: '0xadopted',
        approval: true,
        strategy: 'DEFAULT',
        transactionHash: '0xtx2',
        timestamp: 321,
        blockNumber: 654,
        txOrigin: '0xdef',
        txNonce: 10,
      });

      const result = toHubAssetUpdateLog(log);
      expect(result).to.deep.equal({
        id: 'asset-log-1',
        domain: '1339',
        asset_id: '0xasset',
        token_id: '0xticker',
        ticker_hash: '0xticker',
        asset_domain: '1337',
        kind: 'ASSET_CONFIG_SET',
        asset_hash: '0xhash',
        adopted: '0xadopted',
        approval: true,
        strategy: 'DEFAULT',
        transaction_hash: '0xtx2',
        timestamp: 321,
        block_number: 654,
        tx_origin: '0xdef',
        tx_nonce: 10,
      });
    });
  });

  describe('fromProtocolUpdateLogs', () => {
    it('should convert database record to protocol update log', () => {
      const dbRecord = {
        id: '0xlog1',
        domain: '1337',
        chain_id: '1337',
        event: 'GATEWAY_UPDATED',
        key: 'gateway',
        updated: '0x1234',
        transaction_hash: '0xabc ',
        timestamp: 1000,
        block_number: 200,
        tx_origin: '0x1',
        tx_nonce: 5,
      };

      const result = fromProtocolUpdateLogs(dbRecord);

      expect(result).to.deep.include({
        id: '0xlog1',
        domain: '1337',
        chainId: '1337',
        event: 'GATEWAY_UPDATED',
        key: 'gateway',
        updated: '0x1234',
        transactionHash: '0xabc',
        timestamp: 1000,
        blockNumber: 200,
        txOrigin: '0x1',
        txNonce: 5,
      });
    });
  });

  describe('toHubMeta', () => {
    it('should convert hub meta to database format', () => {
      const meta = {
        id: '1339',
        domain: '1339',
        acceptanceDelay: '1',
        gateway: '0xgateway',
        watchtower: '0xwatchtower',
        manager: '0xmanager',
        settler: '0xsettler',
        proposedOwnershipTimestamp: '0',
        mailbox: '0xmailbox',
        securityModule: '0xsecurity',
        minSolverSupportedDomains: '1',
        expiryTimeBuffer: '0',
        discountPerEpoch: '0',
        epochLength: '1',
        supportedDomains: [{ domain: '1337', blockGasLimit: '10000000' }],
        chainGateways: [{ chainId: '1337', gateway: '0xg' }],
      };

      const result = toHubMeta(meta);

      expect(result.id).to.equal('1339');
      expect(result.domain).to.equal('1339');
      expect(result.gateway).to.equal('0xgateway');
      expect(result.supported_domains).to.equal(JSON.stringify(meta.supportedDomains));
      expect(result.chain_gateways).to.equal(JSON.stringify(meta.chainGateways));
    });

    it('should set optional fields to null when missing', () => {
      const meta = {
        id: '1339',
        domain: '1339',
      };

      const result = toHubMeta(meta as Parameters<typeof toHubMeta>[0]);

      expect(result.gateway).to.be.null;
      expect(result.supported_domains).to.be.null;
      expect(result.chain_gateways).to.be.null;
    });
  });

  describe('fromHubMeta', () => {
    it('should convert database record to hub meta', () => {
      const supportedDomains = [{ domain: '1337', blockGasLimit: '10000000' }];
      const chainGateways = [{ chainId: '1337', gateway: '0xg' }];
      const dbRecord = {
        id: '1339',
        domain: '1339',
        gateway: '0xgateway',
        supported_domains: JSON.stringify(supportedDomains),
        chain_gateways: JSON.stringify(chainGateways),
      };

      const result = fromHubMeta(dbRecord);

      expect(result.id).to.equal('1339');
      expect(result.domain).to.equal('1339');
      expect(result.gateway).to.equal('0xgateway');
      expect(result.supportedDomains).to.deep.equal(supportedDomains);
      expect(result.chainGateways).to.deep.equal(chainGateways);
    });
  });

  describe('toSpokeMeta', () => {
    it('should convert spoke meta to database format', () => {
      const meta = {
        id: '1337',
        domain: '1337',
        messageReceiver: '0xreceiver',
        messageGasLimit: '100000',
        feeAdapter: '0xfeeAdapter',
        moduleForStrategies: [{ strategy: '1', module: '0xm' }],
      };

      const result = toSpokeMeta(meta);

      expect(result.id).to.equal('1337');
      expect(result.domain).to.equal('1337');
      expect(result.message_receiver).to.equal('0xreceiver');
      expect(result.module_for_strategies).to.equal(JSON.stringify(meta.moduleForStrategies));
    });

    it('should set optional fields to null when missing', () => {
      const meta = {
        id: '1337',
        domain: '1337',
      };

      const result = toSpokeMeta(meta as Parameters<typeof toSpokeMeta>[0]);

      expect(result.message_receiver).to.be.null;
      expect(result.module_for_strategies).to.be.null;
    });
  });

  describe('fromSpokeMeta', () => {
    it('should convert database record to spoke meta', () => {
      const moduleForStrategies = [{ strategy: '1', module: '0xm' }];
      const dbRecord = {
        id: '1337',
        domain: '1337',
        message_receiver: '0xreceiver',
        module_for_strategies: JSON.stringify(moduleForStrategies),
      };

      const result = fromSpokeMeta(dbRecord);

      expect(result.id).to.equal('1337');
      expect(result.domain).to.equal('1337');
      expect(result.messageReceiver).to.equal('0xreceiver');
      expect(result.moduleForStrategies).to.deep.equal(moduleForStrategies);
    });
  });
});
