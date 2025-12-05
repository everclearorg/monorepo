import * as parser from './parse';
import { execute, executeEnvioQuery } from './execute';

export const getHelpers = () => {
  return {
    execute,
    parser,
    executeEnvioQuery,
  };
};
