import { Logger, expect } from '@chimera-monorepo/utils';
import { restore, reset, stub, SinonStubbedInstance, SinonStub } from 'sinon';
import { checkTronChains, checkTronRpcs, checkTronGas } from '../../src/checklist/tron';
import { getContextStub, mock } from '../globalTestHook';
import { createProcessEnv } from '../mock';
import { Database } from '@chimera-monorepo/database';
import { ChainReader } from '@chimera-monorepo/chainservice';
import { SubgraphReader } from '@chimera-monorepo/adapters-subgraph';
import * as Mockable from '../../src/mockable';

describe('Tron Monitoring Checklist', () => {
  let database: SinonStubbedInstance<Database>;
  let chainreader: SinonStubbedInstance<ChainReader>;
  let subgraph: SinonStubbedInstance<SubgraphReader>;
  let logger: SinonStubbedInstance<Logger>;
  let sendAlertsStub: SinonStub;
  let resolveAlertsStub: SinonStub;

  beforeEach(() => {
    stub(process, 'env').value({
      ...process.env,
      ...createProcessEnv(),
    });
    getContextStub.returns({
      ...mock.context(),
      config: { ...mock.config() },
    });
    database = mock.instances.database() as SinonStubbedInstance<Database>;
    chainreader = mock.instances.chainreader() as SinonStubbedInstance<ChainReader>;
    logger = mock.instances.logger() as SinonStubbedInstance<Logger>;
    subgraph = mock.instances.subgraph() as SinonStubbedInstance<SubgraphReader>;

    sendAlertsStub = stub(Mockable, 'sendAlerts');
    sendAlertsStub.resolves();
    resolveAlertsStub = stub(Mockable, 'resolveAlerts');
    resolveAlertsStub.resolves();

    // Setup Tron chain mocks
    chainreader.getBlockNumber.resolves(12345678);
    chainreader.getBlock.resolves({
      number: 12345678,
      timestamp: Math.floor(Date.now() / 1000),
      hash: '0x1234567890abcdef',
    });
    chainreader.getBalance.resolves('1000000000'); // 1000 TRX (6 decimals)
  });

  afterEach(() => {
    restore();
    reset();
  });

  describe('#checkTronRpcs', () => {
    it('should check Tron RPC connectivity successfully', async () => {
      await checkTronRpcs();
      
      // Should call getBlockNumber for Tron domain
      expect(chainreader.getBlockNumber.calledWith(728126428)).to.be.true;
      
      // Should resolve alerts for good RPCs
      expect(resolveAlertsStub.called).to.be.true;
      
      // Should not send alerts for working RPCs
      expect(sendAlertsStub.called).to.be.false;
    });

    it('should handle RPC connection failures', async () => {
      chainreader.getBlockNumber.rejects(new Error('Connection timeout'));
      
      await checkTronRpcs();
      
      // Should send alerts for bad RPCs
      expect(sendAlertsStub.called).to.be.true;
      expect(sendAlertsStub.firstCall.args[0].type).to.equal('BadRpcDetected');
    });

    it('should not check non-Tron chains', async () => {
      // Mock config with only EVM chains
      getContextStub.returns({
        ...mock.context(),
        config: {
          ...mock.config(),
          chains: {
            '1337': {
              network: 'evm',
              providers: ['http://test-evm-rpc.com'],
            },
          },
        },
      });

      await checkTronRpcs();
      
      // Should not call chainreader for EVM chains
      expect(chainreader.getBlockNumber.called).to.be.false;
    });
  });

  describe('#checkTronChains', () => {
    beforeEach(() => {
      subgraph.getLatestBlockNumber.resolves(
        new Map<string, number>([
          ['728126428', 12345670], // Tron subgraph 8 blocks behind
        ])
      );
    });

    it('should check Tron chain status successfully', async () => {
      const result = await checkTronChains();
      
      expect(result).to.have.length(1);
      expect(result[0].domain).to.equal('728126428');
      expect(result[0].rpc.blockNumber).to.equal(12345678);
      expect(result[0].subgraphBlockNumber).to.equal(12345670);
      
      // Should call chainreader.getBlock for Tron domain
      expect(chainreader.getBlock.calledWith(728126428, 'latest')).to.be.true;
    });

    it('should alert when subgraph is behind threshold', async () => {
      // Configure a low threshold
      getContextStub.returns({
        ...mock.context(),
        config: {
          ...mock.config(),
          chains: {
            '728126428': {
              ...mock.config().chains['728126428'],
              network: 'tvm',
              maxDelayedSubgraphBlock: 5, // Low threshold
            },
          },
        },
      });

      await checkTronChains();
      
      // Should send alert for delayed subgraph
      expect(sendAlertsStub.called).to.be.true;
      expect(sendAlertsStub.firstCall.args[0].type).to.equal('SubgraphDelayed');
    });

    it('should resolve alerts when subgraph is within threshold', async () => {
      subgraph.getLatestBlockNumber.resolves(
        new Map<string, number>([
          ['728126428', 12345678], // Tron subgraph up to date
        ])
      );

      await checkTronChains();
      
      // Should resolve alerts when within threshold
      expect(resolveAlertsStub.called).to.be.true;
      expect(sendAlertsStub.called).to.be.false;
    });
  });

  describe('#checkTronGas', () => {
    beforeEach(() => {
      // Mock fetch for relayer address
      global.fetch = stub().resolves({
        text: () => Promise.resolve('TRelayerAddress1234567890123'),
      } as Response);
    });

    afterEach(() => {
      if (global.fetch && typeof global.fetch.restore === 'function') {
        global.fetch.restore();
      }
    });

    it('should check Tron TRX balances successfully', async () => {
      const result = await checkTronGas();
      
      expect(result).to.have.length(1);
      expect(result[0].domain).to.equal('728126428');
      expect(result[0].relayerGas).to.equal('1000000000'); // 1000 TRX
      expect(result[0].gatewayGas).to.equal('1000000000');
      expect(result[0].belowRelayerThreshold).to.be.false;
      expect(result[0].belowGatewayThreshold).to.be.false;
    });

    it('should alert when relayer TRX balance is below threshold', async () => {
      chainreader.getBalance.resolves('50000000'); // 50 TRX (below 100 TRX threshold)
      
      await checkTronGas();
      
      // Should send alert for low relayer balance
      expect(sendAlertsStub.calledTwice).to.be.true; // Once for relayer, once for gateway
      const relayerAlert = sendAlertsStub.firstCall.args[0];
      expect(relayerAlert.type).to.equal('LowGasRelayer');
      expect(relayerAlert.ids).to.include('728126428');
    });

    it('should alert when gateway TRX balance is below threshold', async () => {
      // Mock different balances for relayer vs gateway
      chainreader.getBalance.callsFake(async (domainId: number, address: string) => {
        if (address === 'TRelayerAddress1234567890123') {
          return '200000000'; // 200 TRX - above threshold
        }
        return '30000000'; // 30 TRX - below 50 TRX threshold for gateway
      });
      
      await checkTronGas();
      
      // Should send alert for low gateway balance but not relayer
      expect(sendAlertsStub.called).to.be.true;
      const gatewayAlert = sendAlertsStub.firstCall.args[0];
      expect(gatewayAlert.type).to.equal('LowGasGateway');
    });

    it('should resolve alerts when balances are sufficient', async () => {
      chainreader.getBalance.resolves('500000000'); // 500 TRX - above thresholds
      
      await checkTronGas();
      
      // Should resolve alerts when balances are sufficient
      expect(resolveAlertsStub.called).to.be.true;
      expect(sendAlertsStub.called).to.be.false;
    });

    it('should handle missing relayer configuration gracefully', async () => {
      getContextStub.returns({
        ...mock.context(),
        config: {
          ...mock.config(),
          relayers: [], // No relayers configured
        },
      });

      const result = await checkTronGas();
      
      expect(result[0].relayerAddress).to.be.undefined;
      expect(result[0].relayerGas).to.be.undefined;
      expect(result[0].belowRelayerThreshold).to.be.false;
    });

    it('should use TRX decimals (6) for threshold calculations', async () => {
      // This test verifies that we're using 6 decimals for TRX, not 18 like ETH
      chainreader.getBalance.resolves('99999999'); // Just under 100 TRX
      
      await checkTronGas();
      
      const result = await checkTronGas(false); // Don't send alerts, just get result
      expect(result[0].belowRelayerThreshold).to.be.true; // Should be below 100 TRX threshold
    });
  });

  describe('Tron-specific behavior', () => {
    it('should only process chains with network: "tvm"', async () => {
      // Mock config with mixed chain types
      getContextStub.returns({
        ...mock.context(),
        config: {
          ...mock.config(),
          chains: {
            '1337': { network: 'evm', providers: ['http://evm-rpc'] },
            '728126428': { network: 'tvm', providers: ['http://tron-rpc'] },
            '1151111081099710': { network: 'svm', providers: ['http://solana-rpc'] },
          },
        },
      });

      await checkTronRpcs();
      
      // Should only call for Tron domain (728126428)
      expect(chainreader.getBlockNumber.calledOnce).to.be.true;
      expect(chainreader.getBlockNumber.calledWith(728126428)).to.be.true;
    });

    it('should use constants.AddressZero for native TRX balance checks', async () => {
      await checkTronGas();
      
      // Verify chainreader.getBalance was called with constants.AddressZero for TRX
      const balanceCalls = chainreader.getBalance.getCalls();
      expect(balanceCalls.some(call => call.args[2] === '0x0000000000000000000000000000000000000000')).to.be.true;
    });
  });
});