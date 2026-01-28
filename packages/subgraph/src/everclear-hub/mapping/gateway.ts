import { BigInt } from '@graphprotocol/graph-ts';
import {
  ChainGatewayAdded,
  ChainGatewayRemoved,
  MailboxUpdated as HubGatewayMailboxUpdated,
  SecurityModuleUpdated as HubGatewaySecurityModuleUpdated,
} from '../../../generated/HubGateway/HubGateway';
import { getOrCreateMeta, logHubMetaUpdate } from './meta';

/**
 * HubGateway: ChainGatewayAdded
 */
export function handleChainGatewayAdded(event: ChainGatewayAdded): void {
  const chainId = event.params._chainId;
  logHubMetaUpdate('HUB_CHAIN_GATEWAY_ADDED', event, 'chainGateway', event.params._gateway, chainId);
}

/**
 * HubGateway: ChainGatewayRemoved
 */
export function handleChainGatewayRemoved(event: ChainGatewayRemoved): void {
  const chainId = event.params._chainId;
  logHubMetaUpdate('HUB_CHAIN_GATEWAY_REMOVED', event, 'chainGateway', event.params._gateway, chainId);
}

/**
 * HubGateway: MailboxUpdated (IGateway)
 */
export function handleHubGatewayMailboxUpdated(event: HubGatewayMailboxUpdated): void {
  const meta = getOrCreateMeta();
  meta.mailbox = event.params._newMailbox;
  meta.save();

  logHubMetaUpdate('HUB_GATEWAY_MAILBOX_UPDATED', event, 'hubGatewayMailbox', event.params._newMailbox, null);
}

/**
 * HubGateway: SecurityModuleUpdated (IGateway)
 */
export function handleHubGatewaySecurityModuleUpdated(event: HubGatewaySecurityModuleUpdated): void {
  const meta = getOrCreateMeta();
  meta.securityModule = event.params._newSecurityModule;
  meta.save();

  logHubMetaUpdate(
    'HUB_GATEWAY_SECURITY_MODULE_UPDATED',
    event,
    'hubGatewaySecurityModule',
    event.params._newSecurityModule,
    null,
  );
}
