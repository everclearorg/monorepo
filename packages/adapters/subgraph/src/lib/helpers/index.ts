import * as parser from './parse';
import { execute } from './execute';

export const getHelpers = () => {
  return {
    execute,
    parser,
  };
};
