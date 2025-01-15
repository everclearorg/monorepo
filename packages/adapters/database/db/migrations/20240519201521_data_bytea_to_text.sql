-- migrate:up

ALTER TABLE destination_intents
ALTER COLUMN data TYPE text;

ALTER TABLE origin_intents
ALTER COLUMN data TYPE text;

-- migrate:down

ALTER TABLE origin_intents
ALTER COLUMN data TYPE bytea;

ALTER TABLE destination_intents
ALTER COLUMN data TYPE bytea;

