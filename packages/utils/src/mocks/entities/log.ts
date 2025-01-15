import { createMethodContext, createRequestContext } from '../../logging';
import { mkBytes32 } from '../mk';

export const log = {
  requestContext: (...args: string[]) =>
    createRequestContext(args[0] ?? 'requestOriginId', args[1] ?? mkBytes32('0x4545454')),
  methodContext: (name?: string) => createMethodContext(name ?? 'methodName'),
};
