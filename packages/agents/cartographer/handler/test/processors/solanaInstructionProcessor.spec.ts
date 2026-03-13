import { expect } from '@chimera-monorepo/utils';
import { stub, restore } from 'sinon';
import { AppContext } from '@chimera-monorepo/cartographer-core';
import bs58 from 'bs58';

import { processSolanaInstruction } from '../../src/processors/solanaInstructionProcessor';
import * as notify from '../../src/notify';
import { createAppContext } from '../mock';

describe('solanaInstructionProcessor', () => {
  let context: AppContext;
  let notifyStub: sinon.SinonStub;

  // CPI discriminator: e445a52e51cb9a1d
  const CPI_DISC = Buffer.from('e445a52e51cb9a1d', 'hex');

  function makeData(eventDiscHex: string, payloadLength = 32): string {
    const eventDisc = Buffer.from(eventDiscHex, 'hex');
    const payload = Buffer.alloc(payloadLength);
    const full = Buffer.concat([CPI_DISC, eventDisc, payload]);
    return bs58.encode(full);
  }

  beforeEach(() => {
    context = createAppContext();
    notifyStub = stub(notify, 'notifyLighthouse').resolves();
  });

  afterEach(() => {
    restore();
  });

  it('should notify INTENT queue for IntentAdded discriminator', async () => {
    const payload = { data: makeData('1263e45a565b315d') };
    await processSolanaInstruction(payload, context);

    expect(notifyStub.callCount).to.equal(1);
    expect(notifyStub.getCall(0).args[0]).to.equal('lighthouse:intent');
  });

  it('should notify FILL queue for IntentFilled discriminator', async () => {
    const payload = { data: makeData('97e5c05b34bba821') };
    await processSolanaInstruction(payload, context);

    expect(notifyStub.callCount).to.equal(1);
    expect(notifyStub.getCall(0).args[0]).to.equal('lighthouse:fill');
  });

  it('should notify SOLANA queue for Settled discriminator', async () => {
    const payload = { data: makeData('75cfc4aec5c80b43') };
    await processSolanaInstruction(payload, context);

    expect(notifyStub.callCount).to.equal(1);
    expect(notifyStub.getCall(0).args[0]).to.equal('lighthouse:solana');
  });

  it('should notify SOLANA queue for Delivered discriminator', async () => {
    const payload = { data: makeData('aadd51debc47162f') };
    await processSolanaInstruction(payload, context);

    expect(notifyStub.callCount).to.equal(1);
    expect(notifyStub.getCall(0).args[0]).to.equal('lighthouse:solana');
  });

  it('should skip when data field is missing', async () => {
    await processSolanaInstruction({}, context);
    expect(notifyStub.callCount).to.equal(0);
  });

  it('should skip when data is not valid base58', async () => {
    await processSolanaInstruction({ data: '!!!invalid!!!' }, context);
    expect(notifyStub.callCount).to.equal(0);
  });

  it('should skip when data is too short', async () => {
    const shortData = bs58.encode(Buffer.alloc(10));
    await processSolanaInstruction({ data: shortData }, context);
    expect(notifyStub.callCount).to.equal(0);
  });

  it('should skip when CPI discriminator does not match', async () => {
    const wrongCpi = Buffer.from('0000000000000000', 'hex');
    const eventDisc = Buffer.from('1263e45a565b315d', 'hex');
    const data = bs58.encode(Buffer.concat([wrongCpi, eventDisc, Buffer.alloc(32)]));

    await processSolanaInstruction({ data }, context);
    expect(notifyStub.callCount).to.equal(0);
  });

  it('should skip when event discriminator is unknown', async () => {
    const payload = { data: makeData('0000000000000000') };
    await processSolanaInstruction(payload, context);
    expect(notifyStub.callCount).to.equal(0);
  });
});
