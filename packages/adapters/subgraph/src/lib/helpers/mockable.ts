import request from 'graphql-request';
export const gqlRequest = (endpoint: string, query: any) => {
  return request(endpoint, query);
};
