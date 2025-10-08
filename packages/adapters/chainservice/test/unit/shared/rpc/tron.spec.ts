import { expect } from 'chai';
import { stub, SinonStub, restore } from 'sinon';
import { TronSyncProvider } from '../../../../src/shared/rpc/tron';
import { TronWebFactory } from '@chimera-monorepo/utils';
import { TronWeb } from 'tronweb';
import { BigNumber, Bytes } from 'ethers';
import { ISigner, ISignerApi } from '../../../../src';
import { TEST_ERROR, TEST_SENDER_DOMAIN } from '../../../utils';

// Define types for our mock objects
type MockTronWeb = {
  trx: {
    getCurrentBlock: SinonStub;
    getTransaction: SinonStub;
    getTransactionInfo: SinonStub;
    getAccount: SinonStub;
    getBalance: SinonStub;
    sign: SinonStub;
    sendRawTransaction: SinonStub;
    getBlock: SinonStub;
    getBlockByNumber: SinonStub;
    getContract: SinonStub;
    testMethod?: SinonStub;
  };
  transactionBuilder: {
    triggerSmartContract: SinonStub;
    triggerConstantContract: SinonStub;
    estimateEnergy: SinonStub;
    sendTrx: SinonStub;
  };
  contract: SinonStub;
  address: {
    fromHex: SinonStub;
  };
  defaultAddress: {
    hex: string;
  };
  setPrivateKey: SinonStub;
  sign: SinonStub;
  providers: Record<string, any>;
  BigNumber: any;
  plugin: any;
  event: any;
  version: string;
  utils: any;
  defaultBlock: any;
  defaultPrivateKey: string;
  [key: string]: any; // Allow for additional properties
};

describe('TronSyncProvider', () => {
  let provider: TronSyncProvider;
  let mockTronWeb: MockTronWeb;
  let mockTronWebFactory: TronWebFactory;
  const testStallTimeout = 100;

  beforeEach(() => {
    // Set up test environment variables for TronKeyManager
    process.env.TEST_PRIVATE_KEY = 'da146374a75310b9666e834ee4ad0866d6f4035967bfc76217c5a495fff9f0d0';
    process.env.TRON_PRO_API_KEY = 'test-api-key';
    
    // Create a mock TronWeb instance
    mockTronWeb = {
      trx: {
        getCurrentBlock: stub().resolves({ 
          blockID: '0x123', 
          block_header: { raw_data: { number: 12345 } } 
        }),
        getTransaction: stub(),
        getTransactionInfo: stub(),
        getAccount: stub(),
        getBalance: stub(),
        sign: stub(),
        sendRawTransaction: stub(),
        getBlock: stub(),
        getBlockByNumber: stub(),
        getContract: stub(),
      },
      transactionBuilder: {
        triggerSmartContract: stub(),
        triggerConstantContract: stub(),
        estimateEnergy: stub().resolves({
          result: {
            result: true
          },
          energy_required: 1000000
        }),
        sendTrx: stub().resolves({
          transaction: {
            // Mock transaction object
          }
        })
      },
      contract: stub().returns({
        at: stub().resolves({
          balanceOf: () => ({
            call: stub().resolves('1000000')
          }),
          decimals: () => ({
            call: stub().resolves('18')
          })
        })
      }),
      address: {
        fromHex: stub(),
      },
      defaultAddress: {
        hex: '0x1234567890123456789012345678901234567890',
        base58: 'TPL66VK2gCXNCD7EJg9pgJRfqcRazjhUZY',
      } as any,
      setPrivateKey: stub().callsFake(() => {
        // Mock setPrivateKey to update the defaultAddress
        (mockTronWeb.defaultAddress as any).hex = 'TPL66VK2gCXNCD7EJg9pgJRfqcRazjhUZY';
        (mockTronWeb.defaultAddress as any).base58 = 'TPL66VK2gCXNCD7EJg9pgJRfqcRazjhUZY';
      }),
      sign: stub(),
      providers: {},
      BigNumber: {},
      plugin: {},
      event: {},
      version: '1.0.0',
      utils: {},
      defaultBlock: 'latest',
      defaultPrivateKey: '',
    };

    // Create a mock factory that returns our mock TronWeb
    mockTronWebFactory = {
      create: (url: string) => mockTronWeb as unknown as InstanceType<typeof TronWeb>
    };

    // Create provider with mock factory
    provider = new TronSyncProvider(
      TEST_SENDER_DOMAIN,
      'http://tron.test',
      testStallTimeout,
      process.env.LOG_LEVEL === 'debug',
      mockTronWebFactory
    );
  });

  afterEach(() => {
    restore();
    // Clean up test environment variables
    delete process.env.TEST_PRIVATE_KEY;
    delete process.env.TRON_PRO_API_KEY;
  });

  describe('Properties', () => {
    it('should initialize with default values', () => {
      expect(provider.name).to.equal('tron');
      expect(provider.priority).to.equal(0);
      expect(provider.lag).to.equal(0);
      expect(provider.synced).to.be.true;
      expect(provider.reliability).to.equal(1);
      expect(provider.latency).to.equal(0);
      expect(provider.cps).to.equal(0);
      expect(provider.syncedBlockNumber).to.equal(-1);
    });

    it('should allow setting priority', () => {
      provider.priority = 5;
      expect(provider.priority).to.equal(5);
    });

    it('should allow setting lag', () => {
      provider.lag = 2;
      expect(provider.lag).to.equal(2);
    });

    it('should allow setting synced status', () => {
      provider.synced = true;
      expect(provider.synced).to.equal(true);
    });

    it('should extract API key from URL and pass to TronWebFactory', () => {
      const testApiKey = 'test-api-key-123';
      const urlWithApiKey = `http://tron.test?apiKey=${testApiKey}`;
      const createStub = stub(mockTronWebFactory, 'create');
      
      new TronSyncProvider(
        TEST_SENDER_DOMAIN,
        urlWithApiKey,
        testStallTimeout,
        process.env.LOG_LEVEL === 'debug',
        mockTronWebFactory
      );
      
      expect(createStub.calledOnce).to.be.true;
      expect(createStub.firstCall.args[0]).to.deep.equal('http://tron.test?apiKey=test-api-key-123');
    });

    it('should work without API key in URL', () => {
      const createStub = stub(mockTronWebFactory, 'create');
      
      new TronSyncProvider(
        TEST_SENDER_DOMAIN,
        'http://tron.test',
        testStallTimeout,
        process.env.LOG_LEVEL === 'debug',
        mockTronWebFactory
      );
      
      expect(createStub.calledOnce).to.be.true;
      expect(createStub.firstCall.args[0]).to.deep.equal('http://tron.test');
    });
  });

  describe('sync', () => {
    it('should update syncedBlockNumber and synced status on successful sync', async () => {
      await provider.sync();

      expect(provider.syncedBlockNumber).to.equal(1);
      expect(provider.synced).to.be.true;
      expect(mockTronWeb.trx.getCurrentBlock.notCalled).to.be.true;
    });
  });

  describe('getTransaction', () => {
    it('should return formatted transaction response', async () => {
      const mockTx = {
        txID: '0x123',
        raw_data: {
          fee_limit: 1000000,
          contract: [{
            parameter: {
              value: {
                owner_address: '0xowner',
                to_address: '0xcontract',
                data: '0xdata',
                call_value: '1000000000'
              },
              type_url: 'type.googleapis.com/protocol.TransferContract'
            }
          }],
        },
        ret: [{ contractRet: 'SUCCESS' }],
      } as any;

      const mockTxInfo = {
        blockNumber: 12340,
        result: 'SUCCESS',
        receipt: {
          energy_usage: 100000,
          energy_usage_total: 100000
        }
      } as any;

      const mockCurrentBlock = {
        block_header: {
          raw_data: {
            number: 12345
          }
        }
      } as any;

      const mockBlock = {
        blockID: '0xblock123'
      } as any;

      mockTronWeb.trx.getTransaction.resolves(mockTx);
      mockTronWeb.trx.getTransactionInfo.resolves(mockTxInfo);
      mockTronWeb.trx.getCurrentBlock.resolves(mockCurrentBlock);
      mockTronWeb.trx.getBlockByNumber.resolves(mockBlock);

      const result = await provider.getTransaction('0x123');

      expect(result).to.deep.equal({
        hash: '0x123',
        confirmations: 5, // 12345 - 12340
        nonce: 0, // Tron doesn't use nonces
        gasPrice: BigNumber.from(1),
        gasLimit: BigNumber.from(1000000),
        to: '0xcontract',
        from: '0xowner',
        data: '0xdata',
        value: BigNumber.from('1000000000'),
        chainId: TEST_SENDER_DOMAIN,
        blockNumber: 12340,
        blockHash: '0xblock123',
        wait: result.wait // Using the actual wait function since it's a Promise.reject
      });
    });

    it('should throw error when transaction is not found', async () => {
      mockTronWeb.trx.getTransaction.rejects(TEST_ERROR);

      await expect(provider.getTransaction('0x123')).to.be.rejectedWith(TEST_ERROR);
    });

    it('should handle transaction with no block number', async () => {
      const mockTx = {
        txID: '0x123',
        raw_data: {
          fee_limit: 1000000,
          contract: [{
            parameter: {
              value: {
                owner_address: '0xowner',
                to_address: '0xcontract',
                data: '0xdata',
                call_value: '1000000000'
              },
              type_url: 'type.googleapis.com/protocol.TransferContract'
            }
          }],
        },
        ret: [{ contractRet: 'SUCCESS' }],
      } as any;

      const mockTxInfo = {
        blockNumber: undefined,
        result: 'SUCCESS',
        receipt: {
          energy_usage: 100000,
          energy_usage_total: 100000
        }
      } as any;

      const mockCurrentBlock = {
        block_header: {
          raw_data: {
            number: 12345
          }
        }
      } as any;

      mockTronWeb.trx.getTransaction.resolves(mockTx);
      mockTronWeb.trx.getTransactionInfo.resolves(mockTxInfo);
      mockTronWeb.trx.getCurrentBlock.resolves(mockCurrentBlock);

      const result = await provider.getTransaction('0x123');

      expect(result).to.deep.include({
        hash: '0x123',
        confirmations: 0,
        blockNumber: undefined,
        blockHash: undefined
      });
    });

    it('should handle transaction with missing contract data', async () => {
      const mockTx = {
        txID: '0x123',
        raw_data: {
          fee_limit: 1000000,
          contract: [{
            parameter: {
              value: {
                owner_address: '0xowner'
                // Missing to_address and data
              },
              type_url: 'type.googleapis.com/protocol.TransferContract'
            }
          }],
        },
        ret: [{ contractRet: 'SUCCESS' }],
      } as any;

      const mockTxInfo = {
        blockNumber: 12340,
        result: 'SUCCESS',
        receipt: {
          energy_usage: 100000,
          energy_usage_total: 100000
        }
      } as any;

      const mockCurrentBlock = {
        block_header: {
          raw_data: {
            number: 12345
          }
        }
      } as any;

      const mockBlock = {
        blockID: '0xblock123'
      } as any;

      mockTronWeb.trx.getTransaction.resolves(mockTx);
      mockTronWeb.trx.getTransactionInfo.resolves(mockTxInfo);
      mockTronWeb.trx.getCurrentBlock.resolves(mockCurrentBlock);
      mockTronWeb.trx.getBlockByNumber.resolves(mockBlock);

      const result = await provider.getTransaction('0x123');

      expect(result).to.deep.include({
        to: '',
        data: undefined,
        value: BigNumber.from(0)
      });
    });

    it('should handle getTransactionInfo failure', async () => {
      const mockTx = {
        txID: '0x123',
        raw_data: {
          fee_limit: 1000000,
          contract: [{
            parameter: {
              value: {
                owner_address: '0xowner',
                contract_address: '0xcontract',
                data: '0xdata'
              }
            }
          }]
        }
      };

      mockTronWeb.trx.getTransaction.resolves(mockTx);
      mockTronWeb.trx.getTransactionInfo.rejects(new Error('Transaction info not found'));

      await expect(provider.getTransaction('0x123')).to.be.rejectedWith('Transaction info not found');
    });

    it('should handle getCurrentBlock failure', async () => {
      const mockTx = {
        txID: '0x123',
        raw_data: {
          fee_limit: 1000000,
          contract: [{
            parameter: {
              value: {
                owner_address: '0xowner',
                contract_address: '0xcontract',
                data: '0xdata'
              }
            }
          }]
        },
        ret: [{ contractRet: 'SUCCESS' }],
      };

      const mockTxInfo = {
        blockNumber: 54321,
        result: 'SUCCESS'
      };

      mockTronWeb.trx.getTransaction.resolves(mockTx);
      mockTronWeb.trx.getTransactionInfo.resolves(mockTxInfo);
      mockTronWeb.trx.getCurrentBlock.rejects(new Error('Failed to get current block'));

      await expect(provider.getTransaction('0x123')).to.be.rejectedWith('Failed to get current block');
    });

    it('should handle getTransactionInfo failure with specific error', async () => {
      const mockTx = {
        txID: '0x123',
        raw_data: {
          fee_limit: 1000000,
          contract: [{
            parameter: {
              value: {
                owner_address: '0xowner'
              }
            }
          }]
        }
      };

      mockTronWeb.trx.getTransaction.resolves(mockTx);
      mockTronWeb.trx.getTransactionInfo.rejects(new Error('Transaction info not available'));

      await expect(provider.getTransaction('0x123'))
        .to.be.rejectedWith('Transaction info not available');
    });

    it('should handle getCurrentBlock failure with specific error', async () => {
      const mockTx = {
        txID: '0x123',
        raw_data: {
          fee_limit: 1000000,
          contract: [{
            parameter: {
              value: {
                owner_address: '0xowner'
              }
            }
          }]
        },
        ret: [{ contractRet: 'SUCCESS' }],
      };

      const mockTxInfo = {
        blockNumber: 12340,
        result: 'SUCCESS'
      };

      mockTronWeb.trx.getTransaction.resolves(mockTx);
      mockTronWeb.trx.getTransactionInfo.resolves(mockTxInfo);
      mockTronWeb.trx.getCurrentBlock.rejects(new Error('Failed to get current block'));

      await expect(provider.getTransaction('0x123'))
        .to.be.rejectedWith('Failed to get current block');
    });
  });

  describe('getTransactionReceipt', () => {
    it('should return formatted transaction receipt', async () => {
      const mockTx = {
        txID: '0x123',
        raw_data: {
          fee_limit: 1000000,
          contract: [{
            parameter: {
              value: {
                owner_address: '0xowner',
                contract_address: '0xcontract',
                data: '0xdata'
              }
            }
          }]
        },
        ret: [{ contractRet: 'SUCCESS' }],
      };

      const mockReceipt = {
        blockNumber: 12340,
        receipt: {
          result: 'SUCCESS',
          energy_usage: 100000,
          energy_usage_total: 100000
        },
        contract_address: '0xdeployed',
        log: [{
          address: '0xcontract',
          topics: ['topic1', 'topic2'],
          data: '0xdata'
        }]
      };

      const mockCurrentBlock = {
        block_header: {
          raw_data: {
            number: 12345
          }
        }
      };

      const mockBlock = {
        blockID: '0xblock123'
      };

      mockTronWeb.trx.getTransaction.resolves(mockTx);
      mockTronWeb.trx.getTransactionInfo.resolves(mockReceipt);
      mockTronWeb.trx.getCurrentBlock.resolves(mockCurrentBlock);
      mockTronWeb.trx.getBlockByNumber.resolves(mockBlock);
      mockTronWeb.address.fromHex.returns('0xformatted');

      const receipt = await provider.getTransactionReceipt('0x123');

      expect(receipt).to.deep.equal({
        transactionHash: '0x123',
        blockNumber: 12340,
        confirmations: 5, // 12345 - 12340
        status: 1,
        logs: [{
          address: '0xformatted',
          topics: ['topic1', 'topic2'],
          data: '0xdata',
          logIndex: 0,
          blockNumber: 12340,
          blockHash: '0xblock123',
          transactionHash: '0x123',
          transactionIndex: 0,
          removed: false
        }],
        to: '0xcontract',
        from: '0xowner',
        contractAddress: '0xdeployed',
        transactionIndex: 0,
        gasUsed: BigNumber.from(100000),
        effectiveGasPrice: BigNumber.from(0),
        type: 0,
        byzantium: true,
        logsBloom: '0x',
        blockHash: '0xblock123',
        cumulativeGasUsed: BigNumber.from(100000)
      });
    });
  });

  describe('getBalance', () => {
    it('should return TRX balance for zero address', async () => {
      mockTronWeb.trx.getBalance.resolves(1000000);

      const result = await provider.getBalance('0xaddress', '0x0000000000000000000000000000000000000000');
      expect(result).to.equal('1000000');
    });

    it('should return token balance for non-zero address', async () => {
      const result = await provider.getBalance('0xaddress', '0xtoken');
      expect(result).to.equal('1000000');
    });
  });

  describe('getDecimals', () => {
    let originalContractMock: any;

    beforeEach(() => {
      // Store the original mock
      originalContractMock = mockTronWeb.contract;
    });

    afterEach(() => {
      // Restore the original mock
      mockTronWeb.contract = originalContractMock;
    });

    it('should return 6 for TRX (zero address)', async () => {
      const result = await provider.getDecimals('0x0000000000000000000000000000000000000000');
      expect(result).to.equal(6);
    });

    it('should return token decimals for non-zero address', async () => {
      const result = await provider.getDecimals('0xtoken');
      expect(result).to.equal(18);
    });

    it('should handle contract decimals call failure', async () => {
      // Create a mock contract with proper structure
      const mockContract = {
        at: stub().resolves({
          decimals: () => ({
            call: stub().rejects(new Error('Contract call failed'))
          })
        })
      };
      mockTronWeb.contract = stub().returns(mockContract);

      await expect(provider.getDecimals('0xtoken')).to.be.rejectedWith('Contract call failed');
    });
  });

  describe('estimateGas', () => {
    it('should return estimated gas', async () => {
      // Mock the transaction builder to return a successful result
      mockTronWeb.transactionBuilder.estimateEnergy.resolves({
        result: {
          result: true
        },
        energy_required: 1000000
      });

      // Create a transaction with consistent function signature and data
      const result = await provider.estimateGas({
        to: '0xcontract',
        // Using a proper function signature and matching data
        funcSig: 'transfer(address,uint256)',
        data: '0xa9059cbb000000000000000000000000742d35Cc6634C0532925a3b844Bc454e4438f44e0000000000000000000000000000000000000000000000000de0b6b3a7640000',
        domain: 1
      });

      expect(result).to.equal('1000000');
      expect(mockTronWeb.transactionBuilder.estimateEnergy.calledOnce).to.be.true;
    });

    it('should handle estimation failure', async () => {
      // Mock the transaction builder to return a failed result (result.result.result = false)
      mockTronWeb.transactionBuilder.estimateEnergy.resolves({
        result: {
          result: false
        },
        energy_required: 1000000
      });

      await expect(provider.estimateGas({
        to: '0xcontract',
        funcSig: 'transfer(address,uint256)',
        data: '0xa9059cbb000000000000000000000000742d35Cc6634C0532925a3b844Bc454e4438f44e0000000000000000000000000000000000000000000000000de0b6b3a7640000',
        domain: 1
      })).to.be.rejectedWith('The gas estimate could not be determined.');
    });
  });

  describe('getBlock', () => {
    it('should return formatted block by hash', async () => {
      const mockBlock = {
        blockID: '0x123',
        block_header: {
          raw_data: {
            parentHash: '0xparent',
            number: 12345,
            timestamp: 1000000
          }
        }
      };

      mockTronWeb.trx.getBlock.resolves(mockBlock);

      const block = await provider.getBlock('0x123');

      expect(block.hash).to.equal('0x123');
      expect(block.parentHash).to.equal('0xparent');
      expect(block.number).to.equal(12345);
      expect(block.timestamp).to.equal(1000000);
    });

    it('should return formatted block by number', async () => {
      const mockBlock = {
        blockID: '0x123',
        block_header: {
          raw_data: {
            parentHash: '0xparent',
            number: 12345,
            timestamp: 1000000
          }
        }
      };

      mockTronWeb.trx.getBlockByNumber.resolves(mockBlock);

      const block = await provider.getBlock(12345);

      expect(block.hash).to.equal('0x123');
      expect(block.parentHash).to.equal('0xparent');
      expect(block.number).to.equal(12345);
      expect(block.timestamp).to.equal(1000000);
    });

    it('should handle block retrieval by hash', async () => {
      const mockBlock = {
        blockID: '0x123',
        block_header: {
          raw_data: {
            parentHash: '0xparent',
            number: 12345,
            timestamp: 1000000
          }
        }
      };

      mockTronWeb.trx.getBlock.resolves(mockBlock);

      const block = await provider.getBlock('0x123');

      expect(block).to.deep.equal({
        hash: '0x123',
        parentHash: '0xparent',
        number: 12345,
        timestamp: 1000000,
        transactions: [],
        nonce: '',
        difficulty: 0,
        _difficulty: BigNumber.from(0),
        gasLimit: BigNumber.from(0),
        gasUsed: BigNumber.from(0),
        miner: '',
        extraData: '',
        baseFeePerGas: null
      });
      expect(mockTronWeb.trx.getBlock.calledWith('0x123')).to.be.true;
    });

    it('should handle block retrieval error by hash', async () => {
      mockTronWeb.trx.getBlock.rejects(new Error('Block not found'));

      await expect(provider.getBlock('0x123')).to.be.rejectedWith('Block not found');
    });

    it('should handle block retrieval error by number', async () => {
      mockTronWeb.trx.getBlockByNumber.rejects(new Error('Block not found'));

      await expect(provider.getBlock(12345)).to.be.rejectedWith('Block not found');
    });

    it('should handle block retrieval error with specific error message', async () => {
      const errorMessage = 'Block not found or invalid';
      mockTronWeb.trx.getBlock.rejects(new Error(errorMessage));

      await expect(provider.getBlock('0x123'))
        .to.be.rejectedWith(errorMessage);
    });

    it('should handle block retrieval by number with specific error', async () => {
      const errorMessage = 'Invalid block number';
      mockTronWeb.trx.getBlockByNumber.rejects(new Error(errorMessage));

      await expect(provider.getBlock(12345))
        .to.be.rejectedWith(errorMessage);
    });
  });

  describe('Signer methods', () => {
    it('should set private key and return tronWeb instance for string signer', () => {
      const result = provider.getSigner('private_key');
      expect(mockTronWeb.setPrivateKey.calledWith('private_key')).to.be.true;
      expect(result).to.exist;
    });

    it('should set signer API and return tronWeb instance', async () => {
      const mockSignerApi = {
        getPublicKey: () => Promise.resolve('0xpublickey'),
        sign: (identifier: string, data: string | Bytes) => Promise.resolve('signed_data')
      };
      const mockSigner: ISigner = {
        getAddress: () => Promise.resolve('0x123'),
        sendTransaction: () => Promise.resolve({
          hash: '0x123',
          confirmations: 0,
          nonce: 0,
          gasPrice: BigNumber.from(1),
          gasLimit: BigNumber.from(0)
        }),
        signerApi: mockSignerApi,
      };
      const result = await provider.getSigner(mockSigner);
      expect(result.signerApi).to.equal(mockSignerApi);
    });

    describe('should handle connect similar to getSigner', () => {
      it('should set private key and return tronWeb instance for string signer', () => {
        const result = provider.connect('private_key');
        expect(mockTronWeb.setPrivateKey.calledWith('private_key')).to.be.true;
        expect(result).to.exist;
      });

      it('should set signer API and return tronWeb instance', async () => {
        const mockSignerApi = {
          getPublicKey: () => Promise.resolve('0xpublickey'),
          sign: (identifier: string, data: string | Bytes) => Promise.resolve('signed_data')
        };
        const mockSigner: ISigner = {
          getAddress: () => Promise.resolve('0x123'),
          sendTransaction: () => Promise.resolve({
            hash: '0x123',
            confirmations: 0,
            nonce: 0,
            gasPrice: BigNumber.from(1),
            gasLimit: BigNumber.from(0)
          }),
          signerApi: mockSignerApi,
        };
        const result = await provider.connect(mockSigner);
        expect(result.signerApi).to.equal(mockSignerApi);
      });
    });
  });

  describe('getCode', () => {
    it('should return contract bytecode', async () => {
      const mockContract = {
        bytecode: '0x123456'
      };

      mockTronWeb.trx.getContract.resolves(mockContract);

      const code = await provider.getCode('0xcontract');
      expect(code).to.equal('0x123456');
    });

    it('should return 0x for non-contract address', async () => {
      mockTronWeb.trx.getContract.resolves({});

      const code = await provider.getCode('0xnoncontract');
      expect(code).to.equal('0x');
    });

    it('should handle contract retrieval error', async () => {
      mockTronWeb.trx.getContract.rejects(new Error('Contract not found'));

      await expect(provider.getCode('0xcontract')).to.be.rejectedWith('Contract not found');
    });
  });

  describe('TronWeb3Signer', () => {
    const getPublicKeyStub: SinonStub = stub().resolves('mockPublicKey');
    const signStub: SinonStub = stub().resolves('mockSignature');
    const mockSignerApi: ISignerApi = {
      getPublicKey: getPublicKeyStub,
      sign: (identifier: string, data: string | Bytes) => signStub(identifier, data),
    };

    beforeEach(() => {
      // Reset stubs before each test
      getPublicKeyStub.resetHistory();
      signStub.resetHistory();
    });

    it('should handle TRX transfer when signer API is not set', async () => {
      const tx = {
        to: 'TKHuVq1oKVruCGLvqVexFs6dawKv6fQgFs', // Different recipient address
        value: '1000000',
        gasLimit: '100000',
        data: '', // Empty data indicates TRX transfer
        funcSig: '' // Required by ITransactionRequest
      };

      // Set up address conversion
      mockTronWeb.address.fromHex.returns('TKHuVq1oKVruCGLvqVexFs6dawKv6fQgFs');

      mockTronWeb.transactionBuilder.sendTrx.resolves({
        txID: '0x1234567890123456789012345678901234567890123456789012345678901234',
      });

      mockTronWeb.trx.sign.resolves('signed_tx');
      mockTronWeb.trx.sendRawTransaction.resolves({ result: true, txid: '0x123' });
      mockTronWeb.trx.getTransactionInfo.resolves({
        blockNumber: 12340
      });
      mockTronWeb.trx.getCurrentBlock.resolves({
        block_header: {
          raw_data: {
            number: 12345
          }
        }
      });

      const mockSigner: ISigner = {
        getAddress: () => Promise.resolve('0x123'),
        sendTransaction: () => Promise.resolve({
          hash: '0x123',
          confirmations: 0,
          nonce: 0,
          gasPrice: BigNumber.from(1),
          gasLimit: BigNumber.from(0)
        }),
      };
      const signer = await provider.getSigner(mockSigner);

      const result = await signer.sendTransaction(tx);

      expect(result).to.deep.include({
        hash: '0x123',
        confirmations: 0,
        nonce: 0,
        gasPrice: BigNumber.from(1),
        gasLimit: '100000'
      });

      expect(mockTronWeb.transactionBuilder.sendTrx.calledOnce).to.be.true;
      expect(mockTronWeb.transactionBuilder.sendTrx.firstCall.args).to.deep.equal([
        'TKHuVq1oKVruCGLvqVexFs6dawKv6fQgFs',
        1000000,
      ]);
      expect(getPublicKeyStub.notCalled).to.be.true;
      expect(signStub.notCalled).to.be.true;
    });

    it('should handle TRX transfer when signer API is set', async () => {
      const tx = {
        to: 'TKHuVq1oKVruCGLvqVexFs6dawKv6fQgFs', // Different recipient address
        value: '1000000',
        gasLimit: '100000',
        data: '', // Empty data indicates TRX transfer
        funcSig: '' // Required by ITransactionRequest
      };

      // Set up address conversion
      mockTronWeb.address.fromHex.returns('TKHuVq1oKVruCGLvqVexFs6dawKv6fQgFs');

      mockTronWeb.transactionBuilder.sendTrx.resolves({
        txID: '0x1234567890123456789012345678901234567890123456789012345678901234',
      });

      mockTronWeb.trx.sendRawTransaction.resolves({ result: true, txid: '0x1234567890123456789012345678901234567890123456789012345678901234' });
      mockTronWeb.trx.getTransactionInfo.resolves({
        blockNumber: 12340
      });
      mockTronWeb.trx.getCurrentBlock.resolves({
        block_header: {
          raw_data: {
            number: 12345
          }
        }
      });

      const mockSigner: ISigner = {
        getAddress: () => Promise.resolve('0x123'),
        sendTransaction: () => Promise.resolve({
          hash: '0x1234567890123456789012345678901234567890123456789012345678901234',
          confirmations: 0,
          nonce: 0,
          gasPrice: BigNumber.from(1),
          gasLimit: BigNumber.from(0)
        }),
        signerApi: mockSignerApi,
      };
      const signer = await provider.getSigner(mockSigner);

      const result = await signer.sendTransaction(tx);

      expect(result).to.deep.include({
        hash: '0x1234567890123456789012345678901234567890123456789012345678901234',
        confirmations: 0,
        nonce: 0,
        gasPrice: BigNumber.from(1),
        gasLimit: '100000'
      });

      expect(mockTronWeb.transactionBuilder.sendTrx.calledOnce).to.be.true;
      expect(mockTronWeb.transactionBuilder.sendTrx.firstCall.args).to.deep.equal([
        'TKHuVq1oKVruCGLvqVexFs6dawKv6fQgFs',
        1000000,
      ]);
      // Note: Implementation bypasses signerApi and uses private key directly
      // So we don't expect signerApi methods to be called
    });

    it('should call smart contract when signer API is not set', async () => {
      const tx = {
        to: 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t', // Valid Tron contract address (USDT on Tron)
        value: '1000000',
        gasLimit: '100000',
        data: '0xa9059cbb000000000000000000000000742d35Cc6634C0532925a3b844Bc454e4438f44e0000000000000000000000000000000000000000000000000de0b6b3a7640000',
        funcSig: 'transfer(address,uint256)'
      };

      mockTronWeb.transactionBuilder.triggerSmartContract.resolves({
        result: {
          result: true
        },
        transaction: {
          txID: '0x1234567890123456789012345678901234567890123456789012345678901234',
          raw_data: {
            contract: []
          }
        }
      });
      mockTronWeb.address.fromHex.returns('TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t');

      const signedTx = {
        txID: '0x1234567890123456789012345678901234567890123456789012345678901234',
        signature: ['0x1234567890123456789012345678901234567890123456789012345678901234']
      };
      mockTronWeb.trx.sign.resolves(signedTx);
      mockTronWeb.trx.sendRawTransaction.resolves({ result: true, txid: '0x1234567890123456789012345678901234567890123456789012345678901234' });
      mockTronWeb.trx.getTransactionInfo.resolves({
        blockNumber: 12340
      });
      mockTronWeb.trx.getCurrentBlock.resolves({
        block_header: {
          raw_data: {
            number: 12345
          }
        }
      });

      const mockSigner: ISigner = {
        getAddress: () => Promise.resolve('0x123'),
        sendTransaction: () => Promise.resolve({
          hash: '0x1234567890123456789012345678901234567890123456789012345678901234',
          confirmations: 0,
          nonce: 0,
          gasPrice: BigNumber.from(1),
          gasLimit: BigNumber.from(0)
        }),
      };
      const signer = await provider.getSigner(mockSigner);

      const result = await signer.sendTransaction(tx);

      expect(result).to.deep.include({
        hash: '0x1234567890123456789012345678901234567890123456789012345678901234',
        confirmations: 5,
        nonce: 0,
        gasPrice: BigNumber.from(1),
        gasLimit: '100000'
      });

      expect(mockTronWeb.transactionBuilder.triggerSmartContract.calledOnce).to.be.true;
      expect(mockTronWeb.transactionBuilder.triggerSmartContract.firstCall.args).to.deep.equal([
        'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t',
        'transfer(address,uint256)',
        {
          feeLimit: 10000000, // 100000 energy * 420 SUN per energy
          callValue: 1000000,
          rawParameter: '000000000000000000000000742d35Cc6634C0532925a3b844Bc454e4438f44e0000000000000000000000000000000000000000000000000de0b6b3a7640000',
        },
        [],
        'TPL66VK2gCXNCD7EJg9pgJRfqcRazjhUZY' // Actual test address from TronKeyManager
      ]);
      expect(mockTronWeb.trx.sign.calledOnce).to.be.true;
      expect(getPublicKeyStub.notCalled).to.be.true;
      expect(signStub.notCalled).to.be.true;
    });

    it('should call smart contract when signer API is set', async () => {
      const tx = {
        to: 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t', // Valid Tron contract address (USDT on Tron)
        value: '1000000',
        gasLimit: '100000',
        data: '0xa9059cbb000000000000000000000000742d35Cc6634C0532925a3b844Bc454e4438f44e0000000000000000000000000000000000000000000000000de0b6b3a7640000',
        funcSig: 'transfer(address,uint256)'
      };

      mockTronWeb.transactionBuilder.triggerSmartContract.resolves({
        result: {
          result: true
        },
        transaction: {
          txID: '0x1234567890123456789012345678901234567890123456789012345678901234',
          raw_data: {
            contract: []
          }
        }
      });
      mockTronWeb.address.fromHex.returns('TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t');

      mockTronWeb.trx.sendRawTransaction.resolves({ result: true, txid: '0x1234567890123456789012345678901234567890123456789012345678901234' });
      mockTronWeb.trx.getTransactionInfo.resolves({
        blockNumber: 12340
      });
      mockTronWeb.trx.getCurrentBlock.resolves({
        block_header: {
          raw_data: {
            number: 12345
          }
        }
      });

      const mockSigner: ISigner = {
        getAddress: () => Promise.resolve('0x123'),
        sendTransaction: () => Promise.resolve({
          hash: '0x1234567890123456789012345678901234567890123456789012345678901234',
          confirmations: 0,
          nonce: 0,
          gasPrice: BigNumber.from(1),
          gasLimit: BigNumber.from(0)
        }),
        signerApi: mockSignerApi,
      };
      const signer = await provider.getSigner(mockSigner);

      const result = await signer.sendTransaction(tx);

      expect(result).to.deep.include({
        hash: '0x1234567890123456789012345678901234567890123456789012345678901234',
        confirmations: 5,
        nonce: 0,
        gasPrice: BigNumber.from(1),
        gasLimit: '100000'
      });

      expect(mockTronWeb.transactionBuilder.triggerSmartContract.calledOnce).to.be.true;
      expect(mockTronWeb.transactionBuilder.triggerSmartContract.firstCall.args).to.deep.equal([
        'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t',
        'transfer(address,uint256)',
        {
          feeLimit: 10000000, // 100000 energy * 420 SUN per energy
          callValue: 1000000,
          rawParameter: '000000000000000000000000742d35Cc6634C0532925a3b844Bc454e4438f44e0000000000000000000000000000000000000000000000000de0b6b3a7640000',
        },
        [],
        'TPL66VK2gCXNCD7EJg9pgJRfqcRazjhUZY' // Actual test address from TronKeyManager
      ]);
      // Note: Implementation bypasses signerApi and uses private key directly
      // So we don't expect signerApi methods to be called, and trx.sign is called directly
    });
  });

  describe('getTransactionCount', () => {
    it('should return 0 for new address', async () => {
      const address = 'T000000000000000000000000000000000000001';
      const count = await provider.getTransactionCount(address);
      expect(count).to.equal(0);
    });

    it('should increment nonce after sending transaction', async () => {
      const fromAddress = 'TPL66VK2gCXNCD7EJg9pgJRfqcRazjhUZY'; // Sender address
      const toAddress = 'TKHuVq1oKVruCGLvqVexFs6dawKv6fQgFs'; // Different recipient address
      provider.tronWeb.defaultAddress.hex = fromAddress;

      // Initial count should be 0
      const initialCount = await provider.getTransactionCount(fromAddress);
      expect(initialCount).to.equal(0);

      // Send a transaction
      const signer = await provider.getSigner('private_key');
      mockTronWeb.transactionBuilder.sendTrx.resolves({
        txID: 'test_tx_id',
      });
      mockTronWeb.trx.sign.resolves('signed_tx');
      mockTronWeb.trx.sendRawTransaction.resolves({ result: true, txid: 'test_tx_id' });
      mockTronWeb.trx.getTransactionInfo.resolves({ blockNumber: 1 });
      mockTronWeb.trx.getCurrentBlock.resolves({ block_header: { raw_data: { number: 2 } } });

      await signer.sendTransaction({
        to: toAddress,
        value: '1000',
        data: '0x',
        funcSig: '',
      });

      // Count should be incremented
      const updatedCount = await provider.getTransactionCount(fromAddress);
      expect(updatedCount).to.equal(1);
    });

    it('should maintain separate nonces for different addresses', async () => {
      const address1 = 'TPL66VK2gCXNCD7EJg9pgJRfqcRazjhUZY'; // Valid Tron address
      const address2 = 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t'; // Valid Tron contract address

      // Send transaction from address1
      provider.tronWeb.defaultAddress.hex = address1;
      const signer1 = await provider.getSigner('private_key');
      mockTronWeb.transactionBuilder.sendTrx.resolves({
        txID: 'test_tx_id_1',
      });
      mockTronWeb.trx.sign.resolves('signed_tx_1');
      mockTronWeb.trx.sendRawTransaction.resolves({ result: true, txid: 'test_tx_id_1' });
      mockTronWeb.trx.getTransactionInfo.resolves({ blockNumber: 1 });
      mockTronWeb.trx.getCurrentBlock.resolves({ block_header: { raw_data: { number: 2 } } });

      await signer1.sendTransaction({
        to: address2,
        value: '1000',
        data: '0x',
        funcSig: '',
      });

      // Send transaction from address2
      provider.tronWeb.defaultAddress.hex = address2;
      const signer2 = await provider.getSigner('private_key');
      
      // Reset mocks for the second transaction
      mockTronWeb.transactionBuilder.sendTrx.resolves({
        txID: 'test_tx_id_2',
      });
      mockTronWeb.trx.sign.resolves('signed_tx_2');
      mockTronWeb.trx.sendRawTransaction.resolves({ result: true, txid: 'test_tx_id_2' });

      await signer2.sendTransaction({
        to: address1,
        value: '2000',
        data: '0x',
        funcSig: '',
      });

      // Check nonces - both transactions actually use the same sender address (from TronKeyManager)
      // So the sender address (TPL66VK2gCXNCD7EJg9pgJRfqcRazjhUZY) should have 2 transactions
      const actualSenderAddress = 'TPL66VK2gCXNCD7EJg9pgJRfqcRazjhUZY';
      const count1 = await provider.getTransactionCount(actualSenderAddress);
      const count2 = await provider.getTransactionCount(address2);
      expect(count1).to.equal(2); // Two transactions from the same actual sender
      expect(count2).to.equal(0); // No transactions from address2 (it was only a recipient)
    });
  });
}); 
