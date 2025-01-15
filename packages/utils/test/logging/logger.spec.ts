import { Logger, expect, LogLevel, mkAddress } from '../../src';
import fs from 'fs';
import { Bindings, LoggerOptions } from 'pino';
import { config } from '../../src/mocks/entities/config';

const logFile = 'tmp.log';

describe('Peripherals:Logger', () => {
  let logger: Logger;
  let childLogger: Logger;
  const ctx = { config: config({
    chains: {
      '1': {
        providers: [
          'https://eth-mainnet.blastapi.io/JNc0KMUVatTVoe8xM7TT',
          'https://eth-mainnet.g.alchemy.com/v2/k4OYcoB8RMy2NA0mMxy',
        ],
        confirmations: 3,
        deployments: {
          everclear: '0xa05A3380889115bf313f1Db9d5f335157Be4D816',
          gateway: '0x9ADA72CCbAfe94248aFaDE6B604D1bEAacc899A7'
        },
      },
      '10': {
        providers: [
          'https://optimism-mainnet.blastapi.io/CKTo3T5q8r9yWMnVvGR5',
          'https://opt-mainnet.g.alchemy.com/v2/LruHuVXZV1yd0c42BFuF',
        ],
        confirmations: 3,
        deployments: {
          everclear: '0xa05A3380889115bf313f1Db9d5f335157Be4D816',
          gateway: '0x9ADA72CCbAfe94248aFaDE6B604D1bEAacc899A7'
        },
      },
      '56': {
        providers: [
          'https://bsc-mainnet.blastapi.io/YraCYsRwzoUrm3zeIrMS',
          'https://bnb-mainnet.g.alchemy.com/v2/8tqW3yyRGxPCkI9lN5PM',
        ],
        confirmations: 3,
        deployments: {
          everclear: '0xa05A3380889115bf313f1Db9d5f335157Be4D816',
          gateway: '0x9ADA72CCbAfe94248aFaDE6B604D1bEAacc899A7'
        },
      },
    },
    hub: {
      domain: '12312',
      providers: ['https://rpc.everclear.raas.gelato.cloud'],
      deployments: {
        everclear: '0xa05A3380889115bf313f1Db9d5f335157Be4D816',
        gateway: '0xEFfAB7cCEBF63FbEFB4884964b12259d4374FaAa',
      },
    }
  })};

  const createLogger = (opts: LoggerOptions, forcedLevel?: LogLevel, sync: Boolean = true) => {
    logger = new Logger(opts, forcedLevel, fs.openSync(logFile, 'w+'), sync);
  };

  const createChildLogger = (bindings: Bindings, forcedLevel?: LogLevel, dest?: number | string, sync: boolean = false) => {
    childLogger = logger.child(bindings, forcedLevel, dest, sync);
  };

  afterEach(() => {
    if (fs.existsSync(logFile))
      fs.rmSync(logFile);
  });

  describe('#constructor', () => {
    it('with default options', () => {
      createLogger({});

      expect(logger).to.be.instanceOf(Logger);

      logger.info('message');

      const log = JSON.parse(fs.readFileSync(logFile).toString());
      expect(log.level).to.equal(30);
      expect(log.msg).to.equal('message');
    });

    it('with forced log level', () => {
      createLogger({}, 'warn');

      logger.info('message');

      const log = JSON.parse(fs.readFileSync(logFile).toString());
      expect(log.level).to.equal(40);
      expect(log.msg).to.equal('message');
    });

    it('with level option', () => {
      createLogger({ level: 'debug' });

      logger.debug('message');

      const log = JSON.parse(fs.readFileSync(logFile).toString());
      expect(log.level).to.equal(20);
      expect(log.msg).to.equal('message');
    });

    it('with name option', () => {
      createLogger({ name: 'logger test' });

      logger.warn('message');

      const log = JSON.parse(fs.readFileSync(logFile).toString());
      expect(log.level).to.equal(40);
      expect(log.msg).to.equal('message');
      expect(log.name).to.equal('logger test');
    });

    it('with level formatter option', () => {
      createLogger({
        formatters: {
          level: (label) => {
            return { level: label.toUpperCase() };
          },
        },
      });

      logger.error('message');

      const log = JSON.parse(fs.readFileSync(logFile).toString());
      expect(log.level).to.equal('ERROR');
      expect(log.msg).to.equal('message');
    });
  });

  it('can create child', () => {
    createLogger({});
    createChildLogger({ a: 1 });

    expect(childLogger).to.be.instanceOf(Logger);
  });

  describe('#redact', () => {
    it('default', () => {
      createLogger({ level: 'trace'}, 'info');

      logger.debug('message', undefined, undefined, ctx);

      const log = JSON.parse(fs.readFileSync(logFile).toString());
      expect(log.config.healthUrls.poller).to.equal('https://uptime.betterstack.com');
      expect(log.config.hub.providers[0]).to.equal('https://rpc.everclear.raas.gelato.cloud');
      expect(log.config.server.adminToken).to.equal('**********');
      expect(log.config.web3SignerUrl).to.equal('https://relayer-web3signer.chimera.mainnet.everclear.ninja');
      expect(log.config.database.url).to.equal('postgresql://0.0.0.0:5432');

      expect(log.config.chains[1].providers[0]).to.equal('https://eth-mainnet.blastapi.io');
      expect(log.config.chains[1].providers[1]).to.equal('https://eth-mainnet.g.alchemy.com');

      expect(log.config.chains[10].providers[0]).to.equal('https://optimism-mainnet.blastapi.io');
      expect(log.config.chains[10].providers[1]).to.equal('https://opt-mainnet.g.alchemy.com');

      expect(log.config.chains[56].providers[0]).to.equal('https://bsc-mainnet.blastapi.io');
      expect(log.config.chains[56].providers[1]).to.equal('https://bnb-mainnet.g.alchemy.com');;
    });

    it('default (web3 signer is a private key)', () => {
      createLogger({ level: 'trace'}, 'info');
      const web3SignerUrl = ctx.config.web3SignerUrl;
      ctx.config.web3SignerUrl = 'c7923bfa09cb350d4fca3715b1a44ead8e546086f891386584bca2a3a1c35d10';

      logger.debug('message', undefined, undefined, ctx);

      ctx.config.web3SignerUrl = web3SignerUrl;

      const log = JSON.parse(fs.readFileSync(logFile).toString());
      expect(log.config.web3SignerUrl).to.equal('**********');
    });

    describe('custom', () => {
      it('remove', () => {
        createLogger({
          level: 'debug',
          redact: {
            paths: ['config.server', 'config.hub.domain', 'config.chains[1].deployments'],
            remove: true,
          }
        });

        logger.info('message', undefined, undefined, ctx);

        const log = JSON.parse(fs.readFileSync(logFile).toString());
        expect(log.config.server).undefined;
        expect(log.config.hub.domain).undefined;
        expect(log.config.chains[1].deployments).undefined;
      });

      it('replace with default string', () => {
        createLogger({
          redact: {
            paths: ['config.server', 'config.hub.domain', 'config.chains[1].deployments'],
          }
        });

        logger.info('message', undefined, undefined, ctx);

        const log = JSON.parse(fs.readFileSync(logFile).toString());
        expect(log.config.server).to.equal('[Redacted]');
        expect(log.config.hub.domain).to.equal('[Redacted]');
        expect(log.config.chains[1].deployments).to.equal('[Redacted]');
      });

      it('replace with custom string', () => {
        createLogger({
          redact: {
            paths: ['config.server', 'config.hub.domain', 'config.chains[1].deployments'],
            censor: 'deadbeef',
          }
        });

        logger.warn('message', undefined, undefined, ctx);

        const log = JSON.parse(fs.readFileSync(logFile).toString());
        expect(log.config.server).to.equal('deadbeef');
        expect(log.config.hub.domain).to.equal('deadbeef');
        expect(log.config.chains[1].deployments).to.equal('deadbeef');
      });

      it('mixed', () => {
        createLogger(
          {
            redact: {
              paths: ['config.server', 'config.hub.domain', 'config.chains[1].deployments'],
              censor: (value: string, path: string[]) => {
                const fieldName = path[path.length - 1];
                if (fieldName == 'server') {
                  return 'https://' + ctx.config.server.host + ':' + ctx.config.server.port;
                } else if (fieldName == 'domain') {
                  return logger.sanitizedValue;
                } else if (fieldName == 'deployments') {
                  return undefined;
                }
              },
            }
          },
          'info',
        );
        logger.sanitizedValue = 'sanitized';

        logger.warn('message', undefined, undefined, ctx);

        const log = JSON.parse(fs.readFileSync(logFile).toString());
        expect(log.config.server).to.equal('https://0.0.0.0:8080');
        expect(log.config.hub.domain).to.equal('sanitized');
        expect(log.config.chains[1].deployments).undefined;
      });
    });
  });
});
