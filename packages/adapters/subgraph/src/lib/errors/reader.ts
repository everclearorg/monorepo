import { EverclearError } from '@chimera-monorepo/utils';

export class DomainInvalid extends EverclearError {
  constructor(domain: string, context: any = {}) {
    super(
      'Domain invalid: no supported subgraph found for given domain.',
      { ...context, invalidDomain: domain },
      DomainInvalid.name,
    );
  }
}

export class DocumentInvalid extends EverclearError {
  constructor(context: any = {}) {
    super('Document invalid', context, DocumentInvalid.name);
  }
}

export class RuntimeError extends EverclearError {
  constructor(context: any = {}) {
    super('Executing the query failed!', context, RuntimeError.name);
  }
}
