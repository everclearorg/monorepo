-- migrate:up
ALTER TABLE origin_intents ADD COLUMN auto_id bigserial;
CREATE INDEX origin_intents_auto_id_index ON origin_intents(auto_id);

ALTER TABLE destination_intents ADD COLUMN auto_id bigserial;
CREATE INDEX destination_intents_auto_id_index ON destination_intents(auto_id);

ALTER TABLE hub_intents ADD COLUMN auto_id bigserial;
CREATE INDEX hub_intents_auto_id_index ON hub_intents(auto_id);

ALTER TABLE messages ADD COLUMN auto_id bigserial;
CREATE INDEX messages_auto_id_index ON messages(auto_id);

ALTER TABLE auctions ADD COLUMN auto_id bigserial;
CREATE INDEX auctions_auto_id_index ON auctions(auto_id);

-- migrate:down
DROP INDEX origin_intents_auto_id_index;
ALTER TABLE origin_intents DROP COLUMN auto_id;

DROP INDEX destination_intents_auto_id_index;
ALTER TABLE destination_intents DROP COLUMN auto_id;

DROP INDEX hub_intents_auto_id_index;
ALTER TABLE hub_intents DROP COLUMN auto_id;

DROP INDEX messages_auto_id_index;
ALTER TABLE messages DROP COLUMN auto_id;

DROP INDEX auctions_auto_id_index;
ALTER TABLE auctions DROP COLUMN auto_id;