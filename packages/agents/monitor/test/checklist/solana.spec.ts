import { expect } from '@chimera-monorepo/utils';
import { restore, reset, stub, SinonStub, SinonStubbedInstance } from 'sinon';
import { getContextStub, mock } from '../globalTestHook';
import { Database } from '@chimera-monorepo/database';
import { createProcessEnv } from '../mock';
import * as Mockable from '../../src/mockable';
import * as SolanaHelpers from '../../src/helpers/solana';
import { checkSolanaPipelineStatus } from "../../src/checklist/solana";

describe('solana pipeline status', () => {
  let sendAlertsStub: SinonStub;
  let getLastSolanaIntentNonceStub: SinonStub;
  let database: SinonStubbedInstance<Database>;

  beforeEach(() => {
    stub(process, 'env').value({
      ...process.env,
      ...createProcessEnv(),
    });
    database = mock.instances.database() as SinonStubbedInstance<Database>;
    getContextStub.returns({
      ...mock.context(),
      config: { ...mock.config() },
    });

    sendAlertsStub = stub(Mockable, 'sendAlerts');
    sendAlertsStub.resolves();
    stub(Mockable, 'resolveAlerts').resolves();

    getLastSolanaIntentNonceStub = stub(SolanaHelpers, 'getLastSolanaIntentNonce');
    getLastSolanaIntentNonceStub.resolves(7);
  });

  afterEach(() => {
    restore();
    reset();
  });

  describe('#checkSolanaPipelineStatus', () => {
    it('should send alert if nonces mismatch', async () => {
      database.getCheckPoint.resolves(5);
      database.getOriginIntentsLastNonce.resolves(6);

      await checkSolanaPipelineStatus();
      expect(sendAlertsStub.callCount).to.eq(1);
    });

    it('should not send alert if nonces match', async () => {
      database.getCheckPoint.resolves(6);
      database.getOriginIntentsLastNonce.resolves(7);

      await checkSolanaPipelineStatus();
      expect(sendAlertsStub.callCount).to.eq(0);
    });
  });
});
