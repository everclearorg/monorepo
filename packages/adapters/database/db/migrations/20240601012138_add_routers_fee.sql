-- migrate:up
ALTER TABLE destination_intents
ADD max_routers_fee character varying(255) NOT NULL;

-- migrate:down
ALTER TABLE destination_intents
DROP COLUMN max_routers_fee;

