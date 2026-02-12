import { TriageToolDefinition } from './types';

export const TRIAGE_TOOL_DEFINITIONS = {
  check_rpc_health: {
    name: 'check_rpc_health',
    description: 'Check live RPC health for a domain and endpoint.',
    parameters: {
      type: 'object',
      properties: {
        domain: { type: 'string' },
        rpcOrigin: { type: 'string' },
      },
      required: ['domain'],
      additionalProperties: false,
    },
  } satisfies TriageToolDefinition,
  get_gas_balance: {
    name: 'get_gas_balance',
    description: 'Read native gas balance for an address on a chain.',
    parameters: {
      type: 'object',
      properties: {
        domain: { type: 'string' },
        address: { type: 'string' },
      },
      required: ['domain', 'address'],
      additionalProperties: false,
    },
  } satisfies TriageToolDefinition,
  get_block_numbers: {
    name: 'get_block_numbers',
    description: 'Fetch current RPC and subgraph block numbers for a domain.',
    parameters: {
      type: 'object',
      properties: {
        domain: { type: 'string' },
      },
      required: ['domain'],
      additionalProperties: false,
    },
  } satisfies TriageToolDefinition,
  get_queue_depth: {
    name: 'get_queue_depth',
    description: 'Get queue depth and oldest entry age for queue family and domain.',
    parameters: {
      type: 'object',
      properties: {
        queueFamily: { type: 'string', enum: ['deposit', 'intent', 'execution', 'settlement'] },
        domain: { type: 'string' },
      },
      required: ['queueFamily', 'domain'],
      additionalProperties: false,
    },
  } satisfies TriageToolDefinition,
  get_custodied_balance: {
    name: 'get_custodied_balance',
    description: 'Read current custodied balance for an asset hash on hub.',
    parameters: {
      type: 'object',
      properties: {
        assetHash: { type: 'string' },
      },
      required: ['assetHash'],
      additionalProperties: false,
    },
  } satisfies TriageToolDefinition,
  get_current_epoch: {
    name: 'get_current_epoch',
    description: 'Get current protocol epoch from hub contract.',
    parameters: {
      type: 'object',
      properties: {},
      additionalProperties: false,
    },
  } satisfies TriageToolDefinition,
  get_hyperlane_message_status: {
    name: 'get_hyperlane_message_status',
    description: 'Check current Hyperlane delivery status for a message.',
    parameters: {
      type: 'object',
      properties: {
        messageId: { type: 'string' },
      },
      required: ['messageId'],
      additionalProperties: false,
    },
  } satisfies TriageToolDefinition,
  get_solana_nonce_status: {
    name: 'get_solana_nonce_status',
    description: 'Compare Solana onchain nonce with local pipeline checkpoint.',
    parameters: {
      type: 'object',
      properties: {
        checkpointKey: { type: 'string' },
      },
      additionalProperties: false,
    },
  } satisfies TriageToolDefinition,
} as const;

const toolsForType: Record<string, TriageToolDefinition[]> = {
  BadRpcDetected: [TRIAGE_TOOL_DEFINITIONS.check_rpc_health],
  ChainDelayed: [TRIAGE_TOOL_DEFINITIONS.get_block_numbers],
  LowGasRelayer: [TRIAGE_TOOL_DEFINITIONS.get_gas_balance],
  LowGasGateway: [TRIAGE_TOOL_DEFINITIONS.get_gas_balance],
  LowGasTokenomicsGateway: [TRIAGE_TOOL_DEFINITIONS.get_gas_balance],
  MissingSpokeBalance: [TRIAGE_TOOL_DEFINITIONS.get_custodied_balance],
  AverageElapsedEpochsAboveThreshold: [TRIAGE_TOOL_DEFINITIONS.get_current_epoch],
  SolanaPipelineDelay: [TRIAGE_TOOL_DEFINITIONS.get_solana_nonce_status],
  SettlementQueueCountExceeded: [TRIAGE_TOOL_DEFINITIONS.get_queue_depth],
  SettlementQueueAmountExceeded: [TRIAGE_TOOL_DEFINITIONS.get_queue_depth],
  SettlementQueueLatencyExceeded: [TRIAGE_TOOL_DEFINITIONS.get_queue_depth],
  ExecutionQueueCountExceeded: [TRIAGE_TOOL_DEFINITIONS.get_queue_depth],
  ExecutionQueueLatencyExceeded: [TRIAGE_TOOL_DEFINITIONS.get_queue_depth],
  IntentQueueCountExceeded: [TRIAGE_TOOL_DEFINITIONS.get_queue_depth],
  IntentQueueLatencyExceeded: [TRIAGE_TOOL_DEFINITIONS.get_queue_depth],
  DepositQueueCountExceeded: [TRIAGE_TOOL_DEFINITIONS.get_queue_depth],
  DepositQueueLatencyExceeded: [TRIAGE_TOOL_DEFINITIONS.get_queue_depth],
  InvoiceDiscountedMoreThan5Times: [TRIAGE_TOOL_DEFINITIONS.get_current_epoch],
  InvoiceAmountLessThanCustodiedAmount: [TRIAGE_TOOL_DEFINITIONS.get_custodied_balance],
  HyperlaneMessagesProcessingDelayed: [TRIAGE_TOOL_DEFINITIONS.get_hyperlane_message_status],
};

export const getToolsForAlertType = (alertType: string): TriageToolDefinition[] => {
  return toolsForType[alertType] ?? [];
};
