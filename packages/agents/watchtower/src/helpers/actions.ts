// Internal imports

import {
  Address,
  BaseRequestContext,
  RequestContext,
  createMethodContext,
  jsonifyError,
} from '@chimera-monorepo/utils';
import { ActionStatus, Report, Severity } from '../lib/entities';
import { getContext } from '../watcher';
import { BigNumber, utils } from 'ethers';
import { ITransactionReceipt, WriteTransaction } from '@chimera-monorepo/chainservice';
import { sendAlerts } from './alerts';

/**
 * Pauses the protocol for all domains
 * @param requestContext The request context for the logger
 * @param report The report to send to the alerts
 * @param config The watcher config
 * @returns An array with the action status for each domain
 */
export const pauseProtocol = async (report: Report, requestContext: RequestContext): Promise<ActionStatus[]> => {
  try {
    const { config, logger } = getContext();
    const methodContext = createMethodContext(pauseProtocol.name);
    const { logger: _, ...toLog } = report;
    logger.info('Pausing protocol.', requestContext, methodContext, { report: toLog });

    // pause all domains simultaneously
    const domainIds = Object.keys(config.chains).concat(config.hub.domain);
    const requests = domainIds.map((domainId: string) => pauseDomain(domainId, requestContext));
    const results = await Promise.all(requests);

    // Send alerts
    await sendAlerts(report, logger, config, requestContext);

    // We will send alerts again to domains that need action (failed to pause)
    await sendFailedDomainAlerts(results, requestContext);

    return results;
  } catch (error) {
    throw new Error(`An error happened when executing pauseProtocol(): ${(error as Error).message}`);
  }
};

/**
 * Pauses a domain by sending a pause tx to the everclear contract
 * @param domainId The domain to pause
 * @param gasMultiplier The gas multiplier to use
 * @param requestContext The request context for the logger
 * @param isStaging The enviroment we are running it in (staging or production)
 * @returns The action status for the domain
 */
export const pauseDomain = async (domainId: string, requestContext: RequestContext): Promise<ActionStatus> => {
  const { config, logger } = getContext();

  const methodContext = createMethodContext(pauseDomain.name);

  logger.info(`Trying to pause domain ${domainId}`, requestContext, methodContext, { domain: domainId });

  // get everclear deployment for this domain
  const everclear =
    domainId === config.hub.domain ? config.hub.deployments?.everclear : config.chains[domainId].deployments?.everclear;
  if (!everclear) {
    const reason = `Skipping domain(${domainId}) pause since deployment not exist`;
    logger.error(reason, requestContext, methodContext);
    return {
      paused: false,
      needsAction: false,
      domainId,
      reason,
    };
  }
  const everclearInterface = new utils.Interface(config.abis.spoke.everclear as string[]);

  const logCtx = { domain: domainId, everclear: everclear };

  // check if protocol is already paused
  try {
    // if it is paused, return
    const isPaused: boolean = await isDomainPaused(domainId, everclear, everclearInterface);
    if (isPaused) {
      const reason = `Skipping domain(${domainId}) pause since it is already paused`;
      logger.info(reason, requestContext, methodContext, logCtx);
      return {
        paused: false,
        needsAction: false,
        domainId,
        reason,
      };
    }

    // if it is not paused, send pause tx
    let pauseTx;
    try {
      // send pause tx and return the tx receipt
      pauseTx = await sendPauseDomainTx(
        everclearInterface,
        everclear,
        domainId,
        domainId === config.hub.domain ? config.hub.gasMultiplier : config.chains[domainId].gasMultiplier,
        requestContext,
      );
      const { tx, receipt } = pauseTx;
      logger.info('Domain pause transaction sent successfully', requestContext, methodContext, {
        ...logCtx,
        tx,
        receipt,
      });

      return {
        paused: true,
        reason: 'Domain paused successfully',
        needsAction: false,
        domainId,
        tx: receipt.transactionHash,
      };
    } catch (error) {
      // if sending pause tx fails, return
      const reason = `Failed to pause domain ${domainId}, transaction failed`;
      logger.error(reason, requestContext, methodContext, jsonifyError(error as Error), { ...logCtx, pauseTx });
      return {
        paused: false,
        needsAction: true,
        domainId,
        reason,
        error,
      };
    }
  } catch (error) {
    try {
      // if fetching paused status fails, try to pause
      // send pause tx and return the tx receipt
      const { tx, receipt } = await sendPauseDomainTx(
        everclearInterface,
        everclear,
        domainId,
        config.chains[domainId].gasMultiplier,
        requestContext,
      );
      logger.info('Domain pause transaction sent successfully', requestContext, methodContext, {
        ...logCtx,
        tx,
        receipt,
      });

      return {
        paused: true,
        reason: 'Domain paused successfully',
        needsAction: false,
        domainId,
        tx: receipt.transactionHash,
      };
    } catch (error) {
      // if sending pause tx fails, return
      const reason = `Failed to pause domain ${domainId}, transaction failed`;

      logger.error(reason, requestContext, methodContext, jsonifyError(error as Error), logCtx);
      return {
        paused: false,
        needsAction: true,
        domainId,
        reason,
        error,
      };
    }
  }
};

/**
 * Returns true if the domain is paused, false otherwise
 * @param domain The domain id to check
 * @param everclearAddress The everclear contract address
 * @param everclearInterface The everclear contract interface
 * @returns True if the domain is paused, false otherwise
 */
export const isDomainPaused = async (
  domain: string,
  everclearAddress: Address,
  everclearInterface: utils.Interface,
): Promise<boolean> => {
  const {
    adapters: { chainservice },
  } = getContext();
  const encoded = await chainservice.readTx(
    {
      domain: +domain,
      to: everclearAddress,
      data: everclearInterface.encodeFunctionData('paused'),
    },
    'latest',
  );
  const [paused] = everclearInterface.decodeFunctionResult('paused', encoded);
  return paused;
};

/**
 * Sends a pause tx to the everclear contract
 * @param everclearInterface The everclear contract interface
 * @param everclearAddress The everclear contract address
 * @param domainId The domain id to pause
 * @param requestContext The request context for the logger
 * @returns The tx and receipt of the pause tx
 */
export const sendPauseDomainTx = async (
  everclearInterface: utils.Interface,
  everclearAddress: Address,
  domainId: string,
  gasMultiplier: number,
  requestContext: BaseRequestContext,
): Promise<{ tx: WriteTransaction; receipt: ITransactionReceipt }> => {
  try {
    const {
      adapters: { wallet, chainservice },
    } = getContext();
    const pauseCalldata = everclearInterface.encodeFunctionData('pause');
    const price = await chainservice.getGasPrice(+domainId, requestContext);

    const tx = {
      to: everclearAddress,
      data: pauseCalldata,
      value: '0',
      domain: +domainId,
      from: await wallet.getAddress(),
      gasPrice: BigNumber.from(price).mul(gasMultiplier).toString(),
      gasLimit: BigNumber.from(100_000).toString(), // NOTE: fails on e2e tests without it, we can safely hardcode this since this function is not computationally expensive
    };
    const receipt = await chainservice.sendTx(tx, requestContext);
    if (!receipt.status) throw new Error(`Transaction failed with status: ${receipt.status}`);
    return { tx, receipt };
  } catch (error) {
    throw new Error(`An error happened when executing sendPauseDomainTx(${domainId}): ${(error as Error).message}`);
  }
};

/**
 * Sends alerts for domains that should pause but failed and needs a manual action
 * @param results The results from the pause of domains
 * @param config The watcher config
 * @param requestContext The request context
 * @returns A boolean of if any alerts were sent
 */
const sendFailedDomainAlerts = async (results: ActionStatus[], requestContext: RequestContext): Promise<void> => {
  try {
    const { config, logger } = getContext();

    const failedDomains: string[] = [];
    results.forEach((result) => {
      if (result.needsAction) {
        // If a pause failed we will send save the domain
        failedDomains.push(result.domainId);
      }
    });

    if (failedDomains.length) {
      const reasons: string[] = results.map((result) => result.reason);

      const domainReport: Report = {
        severity: Severity.Critical,
        type: 'Failed to pause',
        domains: failedDomains,
        reason: reasons.join(' - '),
        timestamp: Date.now(),
        logger: logger,
        env: config.environment,
      };

      logger.warn('Sending alerts for domains that failed to pause', requestContext, undefined, { failedDomains });
      await sendAlerts(domainReport, logger, config, requestContext);
    }
  } catch (error) {
    throw new Error(`An error happened when executing sendFailedDomainAlerts(): ${(error as Error).message}`);
  }
};
