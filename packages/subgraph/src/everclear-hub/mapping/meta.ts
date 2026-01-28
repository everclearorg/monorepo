import { Address, BigInt, Bytes, ByteArray, crypto, ethereum } from '@graphprotocol/graph-ts';
import { Meta, Domain, HubMetaUpdate } from '../../../generated/schema';
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
  Paused as PausedEvent,
  Unpaused as UnpausedEvent,
  ClosedEpochsProcessed,
  LastEpochProcessedSet,
  RoleAssigned,
  GasConfigUpdated,
  ModuleAddressUpdated,
} from '../../../generated/EverclearHub/EverclearHub';
import { generateIdFromTx, generateTxNonce, getChainId } from '../../common';

const HUB_META_ID = 'HUB_META_ID';

export function logHubMetaUpdate(
  kind: string,
  event: ethereum.Event,
  key: string | null = null,
  valueBytes: Bytes | null = null,
  valueBigInt: BigInt | null = null,
): void {
  const log = new HubMetaUpdate(generateIdFromTx(event));
  log.kind = kind;
  log.key = key;
  log.valueBytes = valueBytes;
  log.valueBigInt = valueBigInt;
  log.transactionHash = event.transaction.hash;
  log.timestamp = event.block.timestamp;
  log.blockNumber = event.block.number;
  log.txOrigin = event.transaction.from;
  log.txNonce = generateTxNonce(event);
  log.save();
}

// Use this when you need a stable unique id for multiple logs in one tx
export function logHubMetaUpdateWithId(
  kind: string,
  event: ethereum.Event,
  key: string | null,
  valueBytes: Bytes | null,
  valueBigInt: BigInt | null,
  id: Bytes,
): void {
  const log = new HubMetaUpdate(id);
  log.kind = kind;
  log.key = key;
  log.valueBytes = valueBytes;
  log.valueBigInt = valueBigInt;
  log.transactionHash = event.transaction.hash;
  log.timestamp = event.block.timestamp;
  log.blockNumber = event.block.number;
  log.txOrigin = event.transaction.from;
  log.txNonce = generateTxNonce(event);
  log.save();
}

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

    meta.mailbox = Address.zero();
    meta.securityModule = Address.zero();

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

  logHubMetaUpdate('OWNERSHIP_PROPOSED', event, 'proposedOwner', event.params._proposedOwner, event.params._timestamp);
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

  logHubMetaUpdate('OWNERSHIP_TRANSFERRED', event, 'owner', event.params._newOwner, null);
}

/**
 * Creates subgraph records when Paused events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handlePaused(event: PausedEvent): void {
  const meta = getOrCreateMeta();
  meta.paused = true;
  meta.save();

  logHubMetaUpdate('PAUSED', event, 'paused', null, BigInt.fromI32(1));
}

/**
 * Creates subgraph records when Unpaused events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handleUnpaused(event: UnpausedEvent): void {
  const meta = getOrCreateMeta();
  meta.paused = false;
  meta.save();

  logHubMetaUpdate('UNPAUSED', event, 'paused', null, BigInt.fromI32(0));
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

  logHubMetaUpdate('GATEWAY_UPDATED', event, 'gateway', event.params._newGateway, null);
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

  logHubMetaUpdate('ACCEPTANCE_DELAY_UPDATED', event, 'acceptanceDelay', null, event.params._newAcceptanceDelay);
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

  logHubMetaUpdate(
    'MIN_SOLVER_SUPPORTED_DOMAINS_UPDATED',
    event,
    'minSolverSupportedDomains',
    null,
    BigInt.fromI32(event.params._newMinSolverSupportedDomains),
  );
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

  logHubMetaUpdate('EPOCH_LENGTH_UPDATED', event, 'epochLength', null, event.params._newEpochLength);
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

  logHubMetaUpdate('EXPIRY_TIME_BUFFER_UPDATED', event, 'expiryTimeBuffer', null, event.params._newExpiryTimeBuffer);
}

/**
 * Creates subgraph records when SupportedDomainsAdded events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handleSupportedDomainsAdded(event: SupportedDomainsAdded): void {
  const meta = getOrCreateMeta();

  let domains = meta.supportedDomains;
  if (domains == null) {
    domains = new Array<Bytes>();
  }
  const domainsToAdd = event.params._domains;
  for (let i = 0; i < domainsToAdd.length; i++) {
    const entity = new Domain(Bytes.fromByteArray(Bytes.fromBigInt(domainsToAdd[i].id)));
    entity.domain = domainsToAdd[i].id;
    entity.blockGasLimit = domainsToAdd[i].blockGasLimit;
    entity.save();
    domains.push(entity.id);

    const id = generateIdFromTx(event).concatI32(i);
    logHubMetaUpdateWithId(
      'SUPPORTED_DOMAINS_ADDED',
      event,
      'supportedDomains',
      Bytes.fromByteArray(Bytes.fromBigInt(domainsToAdd[i].id)),
      domainsToAdd[i].blockGasLimit,
      id,
    );
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

  let domains = meta.supportedDomains;
  if (domains == null) {
    domains = new Array<Bytes>();
  }
  // eslint-disable-next-line @typescript-eslint/ban-types
  const remain: Array<Bytes> = [];
  const domainsToRemove = event.params._domains;
  for (let i = 0; i < domains.length; i++) {
    let exist = false;
    for (let j = 0; j < domainsToRemove.length; j++) {
      if (domains[i].equals(Bytes.fromByteArray(Bytes.fromBigInt(domainsToRemove[j])))) {
        exist = true;
        break;
      }
    }
    if (!exist) {
      remain.push(domains[i]);
      const id = generateIdFromTx(event).concatI32(i);
      logHubMetaUpdateWithId('SUPPORTED_DOMAINS_REMOVED', event, 'supportedDomains', domains[i], null, id);
    }
  }

  meta.supportedDomains = remain;
  meta.save();
}

/**
 * Creates subgraph records when ClosedEpochsProcessed events are emitted.
 */
export function handleClosedEpochsProcessed(event: ClosedEpochsProcessed): void {
  // Log as a generic meta update; this does not currently mutate Meta fields
  logHubMetaUpdate(
    'CLOSED_EPOCHS_PROCESSED',
    event,
    'closedEpochs',
    event.params._tickerHash,
    event.params._lastClosedEpochProcessed,
  );
}

/**
 * Creates subgraph records when LastEpochProcessedSet events are emitted.
 */
export function handleLastEpochProcessedSet(event: LastEpochProcessedSet): void {
  // Log as a generic meta update; this does not currently mutate Meta fields
  logHubMetaUpdate(
    'LAST_EPOCH_PROCESSED_SET',
    event,
    'lastEpochProcessed',
    null,
    event.params._params.lastEpochProcessed,
  );
}

/**
 * Creates subgraph records when RoleAssigned events are emitted.
 */
export function handleRoleAssigned(event: RoleAssigned): void {
  // Log as a generic meta update; this does not currently mutate Meta fields
  logHubMetaUpdate('ROLE_ASSIGNED', event, 'role', event.params._account, BigInt.fromI32(event.params._role));
}

/**
 * Creates subgraph records when GasConfigUpdated events are emitted.
 */
export function handleGasConfigUpdated(event: GasConfigUpdated): void {
  // Log as a generic meta update; this does not currently mutate Meta fields
  const config = event.params._newGasConfig;
  logHubMetaUpdate('GAS_CONFIG_UPDATED', event, 'gasConfig', null, config.bufferDBPS);
}

/**
 * Creates subgraph records when ModuleAddressUpdated events are emitted.
 */
export function handleModuleAddressUpdated(event: ModuleAddressUpdated): void {
  const SETTLEMENT_MODULE_TYPE = Bytes.fromByteArray(crypto.keccak256(ByteArray.fromUTF8('settlement_module')));
  const MANAGER_MODULE_TYPE = Bytes.fromByteArray(crypto.keccak256(ByteArray.fromUTF8('manager_module')));
  
  const meta = getOrCreateMeta();
  const typeParam = event.params._type;
  const newAddress = event.params._newAddress;

  if (typeParam.equals(SETTLEMENT_MODULE_TYPE)) {
    meta.settler = newAddress;

    logHubMetaUpdate('SETTLEMENT_MODULE_UPDATED', event, 'settler', newAddress, null);
  } else if (typeParam.equals(MANAGER_MODULE_TYPE)) {
    meta.manager = newAddress;

    logHubMetaUpdate('MANAGER_MODULE_UPDATED', event, 'manager', newAddress, null);
  }
  meta.save();
}
