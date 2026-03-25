import { expect } from '@chimera-monorepo/utils';
import { stub, restore, SinonStub } from 'sinon';
import { AppContext } from '@chimera-monorepo/cartographer-core';

import { processTronLog } from '../../src/processors/tronLogProcessor';
import * as notify from '../../src/notify';
import { createAppContext } from '../mock';

describe('tronLogProcessor', () => {
  let context: AppContext;
  let notifyStub: SinonStub;

  beforeEach(() => {
    context = createAppContext();
    notifyStub = stub(notify, 'notifyLighthouse').resolves();
  });

  afterEach(() => {
    restore();
  });

  it('should notify INTENT queue for IntentAdded topic', async () => {
    const payload = { topics: '0x80eb6c87e9da127233fe2ecab8adf29403109adc6bec90147df35eeee0745991' };
    await processTronLog(payload, context);

    expect(notifyStub.callCount).to.equal(1);
    expect(notifyStub.getCall(0).args[0]).to.equal('lighthouse-intent');
  });

  it('should notify INTENT queue for IntentWithFeesAdded topic', async () => {
    const payload = { topics: '0x4cc03dfa265ccd4670a5059498b2551525947958b26b5e70f6a6dc62a950fd4e' };
    await processTronLog(payload, context);

    expect(notifyStub.callCount).to.equal(1);
    expect(notifyStub.getCall(0).args[0]).to.equal('lighthouse-intent');
  });

  it('should notify INTENT queue for OrderCreated topic', async () => {
    const payload = { topics: '0xc5929cfdbbc98a41855839bee1396d17ee4a149e40d5c324b6f4332655f5cffd' };
    await processTronLog(payload, context);

    expect(notifyStub.callCount).to.equal(1);
    expect(notifyStub.getCall(0).args[0]).to.equal('lighthouse-intent');
  });

  it('should notify FILL queue for IntentFilled topic', async () => {
    const payload = { topics: '0xe3bc4b05ac625e8c55084d86f8bb9a4c1ff02777dccc7ec0f3b3b7e7468cf383' };
    await processTronLog(payload, context);

    expect(notifyStub.callCount).to.equal(1);
    expect(notifyStub.getCall(0).args[0]).to.equal('lighthouse-fill');
  });

  it('should notify SETTLEMENT queue for Settled topic', async () => {
    const payload = { topics: '0x4190759d37d5cfe7a1a70e06ec7508a05d12fd9cb76f353da1c9e028e5a48dcf' };
    await processTronLog(payload, context);

    expect(notifyStub.callCount).to.equal(1);
    expect(notifyStub.getCall(0).args[0]).to.equal('lighthouse-settlement');
  });

  it('should notify SETTLEMENT queue for IntentQueueProcessed topic', async () => {
    const payload = { topics: '0x43a52e9a77f317a192970b363b14ece56df243fe0dd94f459f63029d657efec3' };
    await processTronLog(payload, context);

    expect(notifyStub.callCount).to.equal(1);
    expect(notifyStub.getCall(0).args[0]).to.equal('lighthouse-settlement');
  });

  it('should notify SETTLEMENT queue for FillQueueProcessed topic', async () => {
    const payload = { topics: '0x5e3a5b80dcf8e0fb984fe128ed0db507a86cc0674c4f5980f83b129b2cfdc69e' };
    await processTronLog(payload, context);

    expect(notifyStub.callCount).to.equal(1);
    expect(notifyStub.getCall(0).args[0]).to.equal('lighthouse-settlement');
  });

  it('should skip when topics field is missing', async () => {
    await processTronLog({}, context);
    expect(notifyStub.callCount).to.equal(0);
  });

  it('should skip when topic hash is unknown', async () => {
    const payload = { topics: '0x0000000000000000000000000000000000000000000000000000000000000000' };
    await processTronLog(payload, context);
    expect(notifyStub.callCount).to.equal(0);
  });

  it('should handle topics with additional data after the first hash', async () => {
    // topics field may contain multiple topic hashes concatenated
    const payload = {
      topics:
        '0x80eb6c87e9da127233fe2ecab8adf29403109adc6bec90147df35eeee07459910000000000000000000000001234567890abcdef',
    };
    await processTronLog(payload, context);

    expect(notifyStub.callCount).to.equal(1);
    expect(notifyStub.getCall(0).args[0]).to.equal('lighthouse-intent');
  });

  it('should be case-insensitive for topic hashes', async () => {
    const payload = { topics: '0x80EB6C87E9DA127233FE2ECAB8ADF29403109ADC6BEC90147DF35EEEE0745991' };
    await processTronLog(payload, context);

    expect(notifyStub.callCount).to.equal(1);
    expect(notifyStub.getCall(0).args[0]).to.equal('lighthouse-intent');
  });
});
