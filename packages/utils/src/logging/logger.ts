/* eslint-disable @typescript-eslint/no-explicit-any */
import pino, { BaseLogger, Bindings, LoggerOptions, destination } from 'pino';

import { ErrorJson } from '..';

import { createMethodContext, createRequestContext, MethodContext, RequestContext } from '.';

import { chainIds } from '../constants';

export type LogLevel = 'fatal' | 'error' | 'warn' | 'info' | 'debug' | 'trace' | 'silent';

const DEFAULT_REDACTED_PATHS = [
  'config.healthUrls.poller',
  'config.hub.providers',
  'config.server.adminToken',
  'config.web3SignerUrl',
  'config.database.url',
];
for (const chainId of chainIds) {
  DEFAULT_REDACTED_PATHS.push(`config.chains[${chainId}].providers`);
}

/**
 * @classdesc Designed to log information in a uniform way to make parsing easier
 */
export class Logger {
  private log: BaseLogger;
  public sanitizedValue: string = '**********';
  constructor(
    private readonly opts: LoggerOptions,
    public readonly forcedLevel?: LogLevel,
    private readonly dest?: number | string,
    private readonly sync: boolean = false,
  ) {
    if (!this.opts.redact) {
      this.opts.redact = this.createDefaultRedactOption();
    }
    this.log = pino(this.opts, destination({ dest, sync }));
  }

  child(bindings: Bindings, forcedLevel?: LogLevel, dest?: number | string, sync: boolean = false) {
    return new Logger({ ...this.opts, ...bindings }, forcedLevel, dest, sync);
  }

  debug(msg: string, requestContext?: RequestContext, methodContext?: MethodContext, ctx?: any): void {
    this.print(
      this.forcedLevel ?? 'debug',
      requestContext,
      methodContext,
      this.forcedLevel ? { ...ctx, intendedLevel: 'debug' } : ctx,
      msg,
    );
  }

  info(msg: string, requestContext?: RequestContext, methodContext?: MethodContext, ctx?: any): void {
    this.print(
      this.forcedLevel ?? 'info',
      requestContext,
      methodContext,
      this.forcedLevel ? { ...ctx, intendedLevel: 'info' } : ctx,
      msg,
    );
  }

  warn(msg: string, requestContext?: RequestContext, methodContext?: MethodContext, ctx?: any): void {
    this.print(
      this.forcedLevel ?? 'warn',
      requestContext,
      methodContext,
      this.forcedLevel ? { ...ctx, intendedLevel: 'warn' } : ctx,
      msg,
    );
  }

  error(
    msg: string,
    requestContext?: RequestContext,
    methodContext?: MethodContext,
    error?: ErrorJson,
    ctx?: any,
  ): void {
    this.print(
      this.forcedLevel ?? 'error',
      requestContext,
      methodContext,
      this.forcedLevel ? { ...ctx, error, intendedLevel: 'error' } : { ...ctx, error },
      msg,
    );
  }

  private print(
    level: LogLevel,
    requestContext: RequestContext = createRequestContext('Logger.print'),
    methodContext: MethodContext = createMethodContext('Logger.print'),
    ctx: any = {},
    msg: string,
  ): void {
    return this.log[level]({ requestContext, methodContext, ...ctx }, msg);
  }

  private createDefaultRedactOption() {
    const isUrl = (value: string) => {
      try {
        new URL(value);
        return true;
        // eslint-disable-next-line
      } catch (_) {}

      return false;
    };

    const sanitizeUrl = (value: string) => {
      const url = new URL(value);
      if (url.origin != 'null') {
        return url.origin;
      }

      return url.protocol + '//' + url.host;
    };

    const censor = (value: string, path: string[]) => {
      const fieldName = path[path.length - 1];
      if (fieldName === 'poller' || fieldName === 'url') {
        return sanitizeUrl(value);
      } else if (fieldName === 'providers') {
        const providers = [];
        for (const provider of value) {
          providers.push(isUrl(provider) ? sanitizeUrl(provider) : provider);
        }
        return providers;
      } else if (fieldName === 'adminToken') {
        return this.sanitizedValue;
      } else if (fieldName === 'web3SignerUrl') {
        if (isUrl(value)) {
          return sanitizeUrl(value);
        } else {
          return this.sanitizedValue;
        }
      }
    };
    return {
      paths: DEFAULT_REDACTED_PATHS,
      censor,
    };
  }
}
