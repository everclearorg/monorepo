import request from 'graphql-request';
export const gqlRequest = (endpoint: string, query: string) => {
  return request(endpoint, query);
};
