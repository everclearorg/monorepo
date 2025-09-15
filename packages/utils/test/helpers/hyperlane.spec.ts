import { expect } from 'chai';
import { stub, restore } from 'sinon';
import { 
  stringToPostgresBytea, 
  postgresByteaToString, 
  getMailboxInterface, 
  getGatewayInterface,
  getHyperlaneMessageStatusViaGraphql,
  getHyperlaneMessageStatusViaRestApi,
  getHyperlaneMessageStatus,
  getHyperlaneMsgDelivered,
  HyperlaneStatus,
  HYPERLANE_GRAPHQL_URL
} from '../../src';

describe('Hyperlane Helper Functions', () => {
  afterEach(() => {
    restore();
  });

  describe('stringToPostgresBytea', () => {
    it('should convert hex string with 0x prefix to postgres bytea format', () => {
      const hexString = '0x1234567890abcdef';
      const result = stringToPostgresBytea(hexString);
      
      expect(result).to.equal('\\x1234567890abcdef');
    });

    it('should convert hex string without 0x prefix to postgres bytea format', () => {
      const hexString = '1234567890abcdef';
      const result = stringToPostgresBytea(hexString);
      
      expect(result).to.equal('\\x1234567890abcdef');
    });

    it('should convert uppercase hex string to lowercase', () => {
      const hexString = '0xABCDEF123456';
      const result = stringToPostgresBytea(hexString);
      
      expect(result).to.equal('\\xabcdef123456');
    });

    it('should handle empty string', () => {
      const hexString = '';
      const result = stringToPostgresBytea(hexString);
      
      expect(result).to.equal('\\x');
    });
  });

  describe('postgresByteaToString', () => {
    it('should convert postgres bytea format to hex string with 0x prefix', () => {
      const byteString = '\\x1234567890abcdef';
      const result = postgresByteaToString(byteString);
      
      expect(result).to.equal('0x1234567890abcdef');
    });

    it('should handle string that already has 0x prefix', () => {
      const byteString = '0x1234567890abcdef';
      const result = postgresByteaToString(byteString);
      
      expect(result).to.equal('0x1234567890abcdef');
    });

    it('should handle empty string', () => {
      const byteString = '';
      const result = postgresByteaToString(byteString);
      
      expect(result).to.equal('0x');
    });
  });

  describe('getMailboxInterface', () => {
    it('should return mailbox interface with process and delivered functions', () => {
      const interface_ = getMailboxInterface();
      
      expect(interface_).to.be.an('array');
      expect(interface_).to.have.length(3); // 2 functions + 1 event
      
      // Check for process function
      const processFunction = interface_.find(item => item.name === 'process');
      expect(processFunction).to.exist;
      expect(processFunction.type).to.equal('function');
      expect(processFunction.inputs).to.have.length(2);
      expect(processFunction.stateMutability).to.equal('payable');
      
      // Check for delivered function
      const deliveredFunction = interface_.find(item => item.name === 'delivered');
      expect(deliveredFunction).to.exist;
      expect(deliveredFunction.type).to.equal('function');
      expect(deliveredFunction.inputs).to.have.length(1);
      expect(deliveredFunction.outputs).to.have.length(1);
      expect(deliveredFunction.stateMutability).to.equal('view');
      
      // Check for Dispatch event
      const dispatchEvent = interface_.find(item => item.name === 'Dispatch');
      expect(dispatchEvent).to.exist;
      expect(dispatchEvent.type).to.equal('event');
      expect(dispatchEvent.anonymous).to.be.false;
    });
  });

  describe('getGatewayInterface', () => {
    it('should return gateway interface with mailbox function', () => {
      const interface_ = getGatewayInterface();
      
      expect(interface_).to.be.an('array');
      expect(interface_).to.have.length(1);
      
      const mailboxFunction = interface_[0];
      expect(mailboxFunction.name).to.equal('mailbox');
      expect(mailboxFunction.inputs).to.have.length(0);
      expect(mailboxFunction.outputs).to.have.length(1);
      expect(mailboxFunction.outputs[0].type).to.equal('address');
    });
  });

  describe('getHyperlaneMessageStatusViaGraphql', () => {
    it('should return message status when found', async () => {
      const messageId = '0x1234567890abcdef';
      const mockResponse = {
        data: {
          message_view: [{
            msg_id: messageId,
            nonce: 1,
            sender: '0xsender',
            recipient: '0xrecipient',
            is_delivered: true,
            message_body: '0xbody',
            origin_mailbox: '0xorigin',
            origin_domain_id: 1,
            origin_chain_id: 1,
            destination_chain_id: 2,
            destination_domain_id: 2,
            destination_mailbox: '0xdest',
            send_occurred_at: '2023-01-01T00:00:00Z',
            delivery_occurred_at: '2023-01-01T00:01:00Z',
            delivery_latency: 60,
            num_payments: 1,
            total_payment: '1000000000000000000',
            total_gas_amount: '21000',
          }],
        },
      };
      
      // Mock the GraphQL client with proper toPromise method
      const mockClient = {
        query: stub().returns({
          toPromise: stub().resolves(mockResponse),
        }),
      };
      
      // Stub the Client import
      const clientStub = stub().returns(mockClient);
      stub(require('@urql/core'), 'Client').callsFake(clientStub);
      
      const result = await getHyperlaneMessageStatusViaGraphql(messageId);
      
      expect(result).to.exist;
      expect(result.id).to.equal(messageId);
      expect(result.status).to.equal(HyperlaneStatus.delivered);
      expect(result.body).to.equal('0xbody');
      expect(result.originMailbox).to.equal('0xorigin');
      expect(result.originDomainId).to.equal(1);
      expect(result.destinationDomainId).to.equal(2);
      expect(result.destinationMailbox).to.equal('0xdest');
      expect(result.recipient).to.equal('0xrecipient');
      expect(result.sender).to.equal('0xsender');
      expect(result.nonce).to.equal(1);
    });

    it('should return undefined when message not found', async () => {
      const messageId = '0x1234567890abcdef';
      const mockResponse = {
        data: {
          message_view: [],
        },
      };
      
      // Mock the GraphQL client with proper toPromise method
      const mockClient = {
        query: stub().returns({
          toPromise: stub().resolves(mockResponse),
        }),
      };
      
      // Stub the Client import
      const clientStub = stub().returns(mockClient);
      stub(require('@urql/core'), 'Client').callsFake(clientStub);
      
      const result = await getHyperlaneMessageStatusViaGraphql(messageId);
      
      expect(result).to.be.undefined;
    });

    it('should handle GraphQL errors', async () => {
      const messageId = '0x1234567890abcdef';
      
      // Mock the GraphQL client to throw an error
      const mockClient = {
        query: stub().returns({
          toPromise: stub().rejects(new Error('GraphQL error')),
        }),
      };
      
      // Stub the Client import
      const clientStub = stub().returns(mockClient);
      stub(require('@urql/core'), 'Client').callsFake(clientStub);
      
      try {
        await getHyperlaneMessageStatusViaGraphql(messageId);
        expect.fail('Should have thrown an error');
      } catch (error) {
        expect(error).to.be.instanceOf(Error);
        expect(error.message).to.equal('GraphQL error');
      }
    });
  });

  describe('getHyperlaneMessageStatusViaRestApi', () => {
    it('should return message status when found', async () => {
      const messageId = '0x1234567890abcdef';
      const mockResponse = {
        data: {
          result: [{
            id: messageId,
            status: 'delivered',
            body: '0xbody',
            originMailbox: '0xorigin',
            originDomainId: 1,
            destinationDomainId: 2,
            destinationMailbox: '0xdest',
            recipient: '0xrecipient',
            sender: '0xsender',
            nonce: 1,
          }],
        },
      };
      
      const axiosGetStub = stub().resolves(mockResponse);
      stub(require('../../src/helpers/axios'), 'axiosGet').callsFake(axiosGetStub);
      
      const result = await getHyperlaneMessageStatusViaRestApi(messageId);
      
      expect(result).to.exist;
      expect(result.id).to.equal(messageId);
      expect(result.status).to.equal(HyperlaneStatus.delivered);
      expect(result.body).to.equal('0xbody');
    });

    it('should return undefined when message not found', async () => {
      const messageId = '0x1234567890abcdef';
      
      const axiosGetStub = stub().rejects(new Error('Not found'));
      stub(require('../../src/helpers/axios'), 'axiosGet').callsFake(axiosGetStub);
      
      const result = await getHyperlaneMessageStatusViaRestApi(messageId);
      
      expect(result).to.be.undefined;
    });
  });

  describe('getHyperlaneMessageStatus', () => {
    it('should try GraphQL first, then REST API', async () => {
      const messageId = '0x1234567890abcdef';
      const mockResponse = {
        data: {
          message_view: [{
            msg_id: messageId,
            nonce: 1,
            sender: '0xsender',
            recipient: '0xrecipient',
            is_delivered: true,
            message_body: '0xbody',
            origin_mailbox: '0xorigin',
            origin_domain_id: 1,
            origin_chain_id: 1,
            destination_chain_id: 2,
            destination_domain_id: 2,
            destination_mailbox: '0xdest',
            send_occurred_at: '2023-01-01T00:00:00Z',
            delivery_occurred_at: '2023-01-01T00:01:00Z',
            delivery_latency: 60,
            num_payments: 1,
            total_payment: '1000000000000000000',
            total_gas_amount: '21000',
          }],
        },
      };
      
      // Mock the GraphQL client with proper toPromise method
      const mockClient = {
        query: stub().returns({
          toPromise: stub().resolves(mockResponse),
        }),
      };
      
      // Stub the Client import
      const clientStub = stub().returns(mockClient);
      stub(require('@urql/core'), 'Client').callsFake(clientStub);
      
      const result = await getHyperlaneMessageStatus(messageId);
      
      expect(result).to.exist;
      expect(result.id).to.equal(messageId);
    });

    it('should fallback to REST API when GraphQL fails', async () => {
      const messageId = '0x1234567890abcdef';
      const mockRestResponse = {
        data: {
          result: [{
            id: messageId,
            status: 'delivered',
            body: '0xbody',
            originMailbox: '0xorigin',
            originDomainId: 1,
            destinationDomainId: 2,
            destinationMailbox: '0xdest',
            recipient: '0xrecipient',
            sender: '0xsender',
            nonce: 1,
          }],
        },
      };
      
      // Mock the GraphQL client to fail
      const mockClient = {
        query: stub().returns({
          toPromise: stub().rejects(new Error('GraphQL error')),
        }),
      };
      
      // Stub the Client import
      const clientStub = stub().returns(mockClient);
      stub(require('@urql/core'), 'Client').callsFake(clientStub);
      
      // Mock REST API to succeed
      const axiosGetStub = stub().resolves(mockRestResponse);
      stub(require('../../src/helpers/axios'), 'axiosGet').callsFake(axiosGetStub);
      
      const result = await getHyperlaneMessageStatus(messageId);
      
      expect(result).to.exist;
      expect(result.id).to.equal(messageId);
    });
  });

  describe('getHyperlaneMsgDelivered', () => {
    it('should return true when message is delivered', async () => {
      const messageId = '0x1234567890abcdef';
      const rpcUrls = ['https://rpc.example.com'];
      const gateway = '0x1234567890123456789012345678901234567890';
      
      // Mock the GraphQL client
      const mockClient = {
        query: stub().resolves({
          data: {
            message_view: [{
              is_delivered: true,
            }],
          },
        }),
      };
      
      // Stub the Client import
      const clientStub = stub().returns(mockClient);
      stub(require('@urql/core'), 'Client').callsFake(clientStub);
      
      // Mock getBestProvider to return a valid provider
      const getBestProviderStub = stub().resolves('https://rpc.example.com');
      stub(require('../../src/helpers/provider'), 'getBestProvider').callsFake(getBestProviderStub);
      
      // Mock chainWrapper functions
      const createPublicClientStub = stub().returns({
        readContract: stub()
          .onFirstCall().resolves('0x1234567890123456789012345678901234567890') // mailbox call
          .onSecondCall().resolves(true), // delivered call
      });
      stub(require('../../src/helpers/chain'), 'chainWrapper').value({
        ...require('../../src/helpers/chain').chainWrapper,
        createPublicClient: createPublicClientStub,
        http: stub().returns({}),
      });
      
      const result = await getHyperlaneMsgDelivered(messageId, rpcUrls, gateway);
      
      expect(result).to.be.true;
    });

    it('should return false when message is not delivered', async () => {
      const messageId = '0x1234567890abcdef';
      const rpcUrls = ['https://rpc.example.com'];
      const gateway = '0x1234567890123456789012345678901234567890';
      
      // Mock the GraphQL client
      const mockClient = {
        query: stub().resolves({
          data: {
            message_view: [{
              is_delivered: false,
            }],
          },
        }),
      };
      
      // Stub the Client import
      const clientStub = stub().returns(mockClient);
      stub(require('@urql/core'), 'Client').callsFake(clientStub);
      
      // Mock getBestProvider to return a valid provider
      const getBestProviderStub = stub().resolves('https://rpc.example.com');
      stub(require('../../src/helpers/provider'), 'getBestProvider').callsFake(getBestProviderStub);
      
      // Mock chainWrapper functions
      const createPublicClientStub = stub().returns({
        readContract: stub()
          .onFirstCall().resolves('0x1234567890123456789012345678901234567890') // mailbox call
          .onSecondCall().resolves(false), // delivered call
      });
      stub(require('../../src/helpers/chain'), 'chainWrapper').value({
        ...require('../../src/helpers/chain').chainWrapper,
        createPublicClient: createPublicClientStub,
        http: stub().returns({}),
      });
      
      const result = await getHyperlaneMsgDelivered(messageId, rpcUrls, gateway);
      
      expect(result).to.be.false;
    });

    it('should return false when message not found', async () => {
      const messageId = '0x1234567890abcdef';
      const rpcUrls = ['https://rpc.example.com'];
      const gateway = '0x1234567890123456789012345678901234567890';
      
      // Mock the GraphQL client
      const mockClient = {
        query: stub().resolves({
          data: {
            message_view: [],
          },
        }),
      };
      
      // Stub the Client import
      const clientStub = stub().returns(mockClient);
      stub(require('@urql/core'), 'Client').callsFake(clientStub);
      
      // Mock getBestProvider to return a valid provider
      const getBestProviderStub = stub().resolves('https://rpc.example.com');
      stub(require('../../src/helpers/provider'), 'getBestProvider').callsFake(getBestProviderStub);
      
      // Mock chainWrapper functions
      const createPublicClientStub = stub().returns({
        readContract: stub()
          .onFirstCall().resolves('0x1234567890123456789012345678901234567890') // mailbox call
          .onSecondCall().resolves(false), // delivered call
      });
      stub(require('../../src/helpers/chain'), 'chainWrapper').value({
        ...require('../../src/helpers/chain').chainWrapper,
        createPublicClient: createPublicClientStub,
        http: stub().returns({}),
      });
      
      const result = await getHyperlaneMsgDelivered(messageId, rpcUrls, gateway);
      
      expect(result).to.be.false;
    });

    it('should return false when no provider is available', async () => {
      const messageId = '0x1234567890abcdef';
      const rpcUrls = ['https://rpc.example.com'];
      const gateway = '0x1234567890123456789012345678901234567890';
      
      // Mock getBestProvider to return undefined (no working provider)
      const getBestProviderStub = stub().resolves(undefined);
      stub(require('../../src/helpers/provider'), 'getBestProvider').callsFake(getBestProviderStub);
      
      const result = await getHyperlaneMsgDelivered(messageId, rpcUrls, gateway);
      
      expect(result).to.be.false;
    });
  });

  describe('HyperlaneStatus', () => {
    it('should have correct status values', () => {
      expect(HyperlaneStatus.none).to.equal('none');
      expect(HyperlaneStatus.pending).to.equal('pending');
      expect(HyperlaneStatus.delivered).to.equal('delivered');
      expect(HyperlaneStatus.relayable).to.equal('relayable');
    });
  });

  describe('HYPERLANE_GRAPHQL_URL', () => {
    it('should have correct URL', () => {
      expect(HYPERLANE_GRAPHQL_URL).to.equal('https://explorer4.hasura.app/v1/graphql');
    });
  });
});
