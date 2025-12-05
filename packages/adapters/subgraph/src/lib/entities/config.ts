import { Type, Static } from '@sinclair/typebox';

export const SubgraphConfigSchema = Type.Object({
  subgraphs: Type.Record(
    Type.String(),
    Type.Object({
      endpoints: Type.Array(Type.String()),
      timeout: Type.Number({ minimum: 1, maximum: 60, default: 10 }),
    }),
  ),
  envio: Type.Optional(
    Type.Object({
      url: Type.String({ format: 'uri' }),
      apiKey: Type.Optional(Type.String()),
      timeout: Type.Optional(Type.Number({ minimum: 1, maximum: 60, default: 10 })),
    }),
  ),
});

export type SubgraphConfig = Static<typeof SubgraphConfigSchema>;
