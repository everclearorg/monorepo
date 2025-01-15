import fastify, { FastifyInstance } from 'fastify';

export const getFastifyInstance = (): FastifyInstance => {
  return fastify();
};
