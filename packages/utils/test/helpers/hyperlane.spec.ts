import {
  expect,
  HyperlaneStatus,
  stringToPostgresBytea,
  postgresByteaToString,
  MessageQuery,
  getMailboxInterface,
  getGatewayInterface,
} from '../../src';

describe('Hyperlane Helper', () => {
  describe('HyperlaneStatus', () => {
    it('should have correct status values', () => {
      expect(HyperlaneStatus.none).to.equal('none');
      expect(HyperlaneStatus.pending).to.equal('pending');
      expect(HyperlaneStatus.delivered).to.equal('delivered');
      expect(HyperlaneStatus.relayable).to.equal('relayable');
    });
  });

  describe('stringToPostgresBytea', () => {
    it('should convert hex string with 0x prefix to postgres bytea', () => {
      const result = stringToPostgresBytea('0x1234567890abcdef');
      expect(result).to.equal('\\x1234567890abcdef');
    });

    it('should convert hex string without 0x prefix to postgres bytea', () => {
      const result = stringToPostgresBytea('1234567890abcdef');
      expect(result).to.equal('\\x1234567890abcdef');
    });

    it('should convert uppercase hex to lowercase', () => {
      const result = stringToPostgresBytea('0xABCDEF');
      expect(result).to.equal('\\xabcdef');
    });

    it('should handle empty string', () => {
      const result = stringToPostgresBytea('');
      expect(result).to.equal('\\x');
    });

    it('should handle single character', () => {
      const result = stringToPostgresBytea('0xa');
      expect(result).to.equal('\\xa');
    });

    it('should handle mixed case', () => {
      const result = stringToPostgresBytea('0xAbCdEf');
      expect(result).to.equal('\\xabcdef');
    });
  });

  describe('postgresByteaToString', () => {
    it('should convert postgres bytea with \\x prefix to hex string with 0x', () => {
      const result = postgresByteaToString('\\x1234567890abcdef');
      expect(result).to.equal('0x1234567890abcdef');
    });

    it('should convert postgres bytea without \\x prefix to hex string with 0x', () => {
      const result = postgresByteaToString('1234567890abcdef');
      expect(result).to.equal('0x1234567890abcdef');
    });

    it('should handle bytea that already has 0x prefix', () => {
      const result = postgresByteaToString('0x1234567890abcdef');
      expect(result).to.equal('0x1234567890abcdef');
    });

    it('should handle empty string', () => {
      const result = postgresByteaToString('');
      expect(result).to.equal('0x');
    });

    it('should handle single character', () => {
      const result = postgresByteaToString('\\xa');
      expect(result).to.equal('0xa');
    });

    it('should handle mixed case', () => {
      const result = postgresByteaToString('\\xAbCdEf');
      expect(result).to.equal('0xAbCdEf');
    });
  });

  describe('MessageQuery', () => {
    it('should be a valid GraphQL query string', () => {
      expect(MessageQuery).to.contain('query ($id: bytea!)');
      expect(MessageQuery).to.contain('message_view');
      expect(MessageQuery).to.contain('msg_id');
      expect(MessageQuery).to.contain('is_delivered');
      expect(MessageQuery).to.contain('message_body');
      expect(MessageQuery).to.contain('origin_mailbox');
      expect(MessageQuery).to.contain('destination_mailbox');
    });

    it('should have proper query structure', () => {
      expect(MessageQuery).to.contain('where: {msg_id: {_eq: $id}}');
      expect(MessageQuery).to.contain('limit: 10');
    });
  });

  describe('getMailboxInterface', () => {
    it('should return Interface with process and delivered functions', () => {
      const result = getMailboxInterface();
      expect(result).to.exist;
      expect(result).to.have.property('encodeFunctionData');
      expect(result).to.have.property('decodeFunctionResult');
      expect(result).to.have.property('getFunction');
    });

    it('should be callable', () => {
      expect(getMailboxInterface).to.be.a('function');
    });
  });

  describe('getGatewayInterface', () => {
    it('should return Interface with mailbox function', () => {
      const result = getGatewayInterface();
      expect(result).to.exist;
      expect(result).to.have.property('encodeFunctionData');
      expect(result).to.have.property('decodeFunctionResult');
      expect(result).to.have.property('getFunction');
    });

    it('should be callable', () => {
      expect(getGatewayInterface).to.be.a('function');
    });
  });
});
