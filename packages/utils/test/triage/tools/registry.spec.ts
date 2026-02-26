import { expect } from '../../../src';
import { getToolsForAlertType } from '../../../src/triage/tools/registry';

describe('triage:tools:registry', () => {
  it('returns configured tools for known alert types', () => {
    const rpcTools = getToolsForAlertType('BadRpcDetected');
    expect(rpcTools.map((tool) => tool.name)).to.deep.eq(['check_rpc_health']);

    const queueTools = getToolsForAlertType('ExecutionQueueLatencyExceeded');
    expect(queueTools.map((tool) => tool.name)).to.deep.eq(['get_queue_depth']);
  });

  it('returns empty list for unknown alert type', () => {
    expect(getToolsForAlertType('UnknownAlertType')).to.deep.eq([]);
  });
});
