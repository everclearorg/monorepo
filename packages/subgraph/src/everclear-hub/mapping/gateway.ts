import { Bytes } from '@graphprotocol/graph-ts';
import {
  ChainGatewayAdded,
  ChainGatewayRemoved,
  MailboxUpdated as HubGatewayMailboxUpdated,
  SecurityModuleUpdated as HubGatewaySecurityModuleUpdated,
} from '../../../generated/HubGateway/HubGateway';
import { ChainGateway } from '../../../generated/schema';
import { generateIdFromTx } from '../../common';
import { getOrCreateMeta, logHubMetaUpdate, logHubMetaUpdateWithId } from './meta';

/**
 * HubGateway: ChainGatewayAdded
 */
/**
 * Helper function to ensure an array field is initialized (not null).
 *
 * @param array - The array field that may be null
 * @returns A non-null array
 */
function ensureArrayInitialized<T>(array: Array<T> | null): Array<T> {
  if (array == null) {
    return new Array<T>();
  }
  return array;
}

export function handleChainGatewayAdded(event: ChainGatewayAdded): void {
  const meta = getOrCreateMeta();

  const chainGateways = ensureArrayInitialized(meta.chainGateways);

  const chainId = event.params._chainId;
  const chainIdBytes = Bytes.fromByteArray(Bytes.fromBigInt(chainId));

  // Check if chain gateway already exists
  let exists = false;
  for (let i = 0; i < chainGateways.length; i++) {
    const existing = ChainGateway.load(chainGateways[i]);
    if (existing != null && existing.chainId.equals(chainId)) {
      exists = true;
      // Update existing gateway
      existing.gateway = event.params._gateway;
      existing.save();
      break;
    }
  }

  if (!exists) {
    // Create new ChainGateway entity
    const entity = new ChainGateway(chainIdBytes);
    entity.chainId = chainId;
    entity.gateway = event.params._gateway;
    entity.save();
    chainGateways.push(entity.id);
  }

  meta.chainGateways = chainGateways;
  meta.save();

  logHubMetaUpdate('HUB_CHAIN_GATEWAY_ADDED', event, 'chainGateway', event.params._gateway, chainId);
}

/**
 * HubGateway: ChainGatewayRemoved
 */
export function handleChainGatewayRemoved(event: ChainGatewayRemoved): void {
  const meta = getOrCreateMeta();

  const chainGateways = ensureArrayInitialized(meta.chainGateways);

  const chainId = event.params._chainId;
  const remain: Array<Bytes> = [];

  for (let i = 0; i < chainGateways.length; i++) {
    const existing = ChainGateway.load(chainGateways[i]);
    if (existing != null && existing.chainId.equals(chainId)) {
      // Skip this one (it's being removed)
      const id = generateIdFromTx(event).concatI32(i);
      logHubMetaUpdateWithId('HUB_CHAIN_GATEWAY_REMOVED', event, 'chainGateway', event.params._gateway, chainId, id);
    } else {
      remain.push(chainGateways[i]);
    }
  }

  meta.chainGateways = remain;
  meta.save();
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
