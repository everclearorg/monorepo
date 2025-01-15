import { getSubgraphReaderConfig } from '../../../src/lib/operations/helper';

import { createCartographerConfig } from '../../mock';
import { expect } from '@chimera-monorepo/utils';

describe('Helpers', () => {
  describe('#getSubgraphReaderConfig', () => {
    it('should work', () => {
      const config = createCartographerConfig();
      const { subgraphs: _subgraphs } = getSubgraphReaderConfig(config);
      expect(_subgraphs['1337'].endpoints).to.be.deep.equal(config.chains['1337'].subgraphUrls);
    });
  });
});
