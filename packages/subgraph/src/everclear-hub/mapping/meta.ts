import { Address, BigInt, Bytes } from '@graphprotocol/graph-ts';
import { Meta, Domain } from '../../../generated/schema';
import {
  AcceptanceDelayUpdated,
  OwnershipProposed,
  OwnershipTransferred,
  SupportedDomainsAdded,
  SupportedDomainsRemoved,
  GatewayUpdated,
  MinSolverSupportedDomainsUpdated,
  ExpiryTimeBufferUpdated,
  EpochLengthUpdated,
} from '../../../generated/EverclearHub/EverclearHub';
import { getChainId } from '../../common';

const HUB_META_ID = 'HUB_META_ID';

export function getOrCreateMeta(): Meta {
  const id = Bytes.fromUTF8(HUB_META_ID);
  let meta = Meta.load(id);
  if (meta == null) {
    meta = new Meta(id);

    meta.domain = getChainId();
    meta.paused = false;
    meta.owner = Address.zero();
    meta.proposedOwner = Address.zero();
    meta.proposedOwnershipTimestamp = new BigInt(0);

    meta.gateway = Address.zero();
    meta.acceptanceDelay = new BigInt(0);
    meta.minSolverSupportedDomains = new BigInt(0);
    meta.discountPerEpoch = new BigInt(0);
    meta.expiryTimeBuffer = new BigInt(0);
    meta.epochLength = new BigInt(0);

    meta.supportedDomains = [];

    meta.save();
  }

  return meta;
}

/**
 * Creates subgraph records when OwnershipProposed events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handleOwnershipProposed(event: OwnershipProposed): void {
  const meta = getOrCreateMeta();

  meta.proposedOwner = event.params._proposedOwner;
  meta.proposedOwnershipTimestamp = event.params._timestamp;
  meta.save();
}

/**
 * Creates subgraph records when OwnershipTransferred events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handleOwnershipTransferred(event: OwnershipTransferred): void {
  const meta = getOrCreateMeta();

  meta.owner = event.params._newOwner;
  meta.save();
}

/**
 * Creates subgraph records when Paused events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handlePaused(): void {
  const meta = getOrCreateMeta();

  meta.paused = true;
  meta.save();
}

/**
 * Creates subgraph records when Unpaused events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handleUnpaused(): void {
  const meta = getOrCreateMeta();

  meta.paused = false;
  meta.save();
}

/**
 * Creates subgraph records when GatewayUpdated events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handleGatewayUpdated(event: GatewayUpdated): void {
  const meta = getOrCreateMeta();

  meta.gateway = event.params._newGateway;
  meta.save();
}

/**
 * Creates subgraph records when AcceptanceDelayUpdated events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handleAcceptanceDelayUpdated(event: AcceptanceDelayUpdated): void {
  const meta = getOrCreateMeta();

  meta.acceptanceDelay = event.params._newAcceptanceDelay;
  meta.save();
}

/**
 * Creates subgraph records when MinSolverSupportedDomainsUpdated events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handleMinSolverSupportedDomainsUpdated(event: MinSolverSupportedDomainsUpdated): void {
  const meta = getOrCreateMeta();

  meta.minSolverSupportedDomains = BigInt.fromI32(event.params._newMinSolverSupportedDomains);
  meta.save();
}

/**
 * Creates subgraph records when EpochLengthUpdated events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handleEpochLengthUpdated(event: EpochLengthUpdated): void {
  const meta = getOrCreateMeta();

  meta.epochLength = event.params._newEpochLength;
  meta.save();
}

/**
 * Creates subgraph records when ExpiryTimeBufferUpdated events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handleExpiryTimeBufferUpdated(event: ExpiryTimeBufferUpdated): void {
  const meta = getOrCreateMeta();

  meta.expiryTimeBuffer = event.params._newExpiryTimeBuffer;
  meta.save();
}

/**
 * Creates subgraph records when SupportedDomainsAdded events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handleSupportedDomainsAdded(event: SupportedDomainsAdded): void {
  const meta = getOrCreateMeta();

  const domains = meta.supportedDomains || [];
  const domainsToAdd = event.params._domains;
  for (let i = 0; i < domainsToAdd.length; i++) {
    const entity = new Domain(Bytes.fromByteArray(Bytes.fromBigInt(domainsToAdd[i].id)));
    entity.domain = domainsToAdd[i].id;
    entity.blockGasLimit = domainsToAdd[i].blockGasLimit;
    entity.save();
    domains!.push(entity.id);
  }

  meta.supportedDomains = domains;
  meta.save();
}

/**
 * Creates subgraph records when SupportedDomainsRemoved events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handleSupportedDomainsRemoved(event: SupportedDomainsRemoved): void {
  const meta = getOrCreateMeta();

  const domains = meta.supportedDomains || [];
  // eslint-disable-next-line @typescript-eslint/ban-types
  const remain: Array<Bytes> = [];
  const domainsToRemove = event.params._domains;
  for (let i = 0; i < domains!.length; i++) {
    let exist = false;
    for (let j = 0; j < domainsToRemove.length; j++) {
      if (domains![i].equals(Bytes.fromBigInt(domainsToRemove[j]))) {
        exist = true;
        break;
      }
    }
    if (!exist) remain.push(domains![i]);
  }

  meta.supportedDomains = remain;
  meta.save();
}
