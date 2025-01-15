import {
  Logger,
  expect,
  getNtpTimeSeconds,
  mkBytes32,
} from '@chimera-monorepo/utils';
import { restore, reset, stub, SinonStub, SinonStubbedInstance } from 'sinon';
import { checkMessageStatus, getIntentStatus } from '../../../src/checklist/queue';
import { getContextStub, mock } from '../../globalTestHook';
import { Database } from '@chimera-monorepo/database';
import * as mockFunctions from '../../../src/mockable';
import { ChainReader } from '@chimera-monorepo/chainservice';
import { createProcessEnv } from '../../mock';
import { SubgraphReader } from '@chimera-monorepo/adapters-subgraph';
import { Interface } from 'ethers/lib/utils';
import { IntentMessageSummary } from '../../../src/types';
import * as Mockable from '../../../src/mockable';

describe('checkMessageStatus', () => {
  let subgraph: SinonStubbedInstance<SubgraphReader>;
  let chainreader: SinonStubbedInstance<ChainReader>;
  let sendAlertsStub: SinonStub;
  let logger: SinonStubbedInstance<Logger>;
  let encode: SinonStub;
  let decode: SinonStub;
  let getHyperlaneMsgDeliveredStub: SinonStub;
  let getHyperlaneMessageStatusStub: SinonStub;
  let database: SinonStubbedInstance<Database>;

  beforeEach(() => {
    stub(process, 'env').value({
      ...process.env,
      ...createProcessEnv(),
    });
    chainreader = mock.instances.chainreader() as SinonStubbedInstance<ChainReader>;
    subgraph = mock.instances.subgraph() as SinonStubbedInstance<SubgraphReader>;
    logger = mock.instances.logger() as SinonStubbedInstance<Logger>;
    database = mock.instances.database() as SinonStubbedInstance<Database>;
    encode = stub(Interface.prototype, 'encodeFunctionData');
    decode = stub(Interface.prototype, 'decodeFunctionResult');
    getContextStub.returns({
      ...mock.context(),
      config: { ...mock.config() },
    });
    encode.returns('0xencoded');
    decode.returns(['FILLED']);
    getHyperlaneMsgDeliveredStub = stub(mockFunctions, 'getHyperlaneMsgDelivered');
    subgraph.getDestinationIntentById.resolves(mock.destinationIntent());

    sendAlertsStub = stub(Mockable, 'sendAlerts');
    sendAlertsStub.resolves();
    stub(Mockable, 'resolveAlerts').resolves();

    getHyperlaneMessageStatusStub = stub(mockFunctions, 'getHyperlaneMessageStatus');
  });

  afterEach(() => {
    restore();
    reset();
  });

  describe('#getIntentStatus', () => {
    it('should work', async () => {
      getHyperlaneMsgDeliveredStub.resolves(true);
      database.getMessagesByIds.resolves([mock.message()]);
      const result = await getIntentStatus('1337', ['1338'], mkBytes32('0x123'));
      const validStatus: IntentMessageSummary = {
        fill: {
          messageId: '0x4560000000000000000000000000000000000000000000000000000000000000',
          status: 'delivered',
        },
        settlement: {
          messageId: '',
          status: 'N/A',
        },
        add: {
          messageId: '',
          status: 'N/A',
        },
      };

      expect(result).to.deep.equal(validStatus);
    });

    it('should fail', async () => {
      getHyperlaneMsgDeliveredStub.resolves(true);
      database.getMessagesByIds.resolves([mock.message()]);
      const noEverclear = mock.chains({
        1337: {
          confirmations: undefined,
          deployments: {
            everclear: undefined,
            gateway: undefined,
          },
          assets: undefined,
          providers: [],
          subgraphUrls: [],
        },
      });
      getContextStub.returns({
        ...mock.context(),
        config: { ...mock.config({ chains: noEverclear }) },
      });

      expect(getIntentStatus('1337', ['1338'], mkBytes32('0x123'))).to.throw;
    });
  });

  describe('#checkMessageStatus', () => {
    it('should send alert if exceeds threshold', async () => {
      const curTime = getNtpTimeSeconds();
      database.getMessagesByStatus.resolves([mock.message({ timestamp: curTime - 1800 * 2 })]);
      getHyperlaneMsgDeliveredStub.resolves(false);
      database.getMessagesByIds.resolves([mock.message()]);
      getHyperlaneMessageStatusStub.resolves(undefined);

      await checkMessageStatus();
      expect(sendAlertsStub.callCount).to.eq(1);
    });

    it('should not send alert if no delayed message', async () => {
      const curTime = getNtpTimeSeconds();
      database.getMessagesByStatus.resolves([mock.message({ timestamp: curTime })]);
      getHyperlaneMsgDeliveredStub.resolves(false);
      database.getMessagesByIds.resolves([mock.message()]);

      await checkMessageStatus();
      expect(sendAlertsStub.callCount).to.eq(0);
    });
  });
});
