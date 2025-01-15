-- migrate:up
CREATE INDEX origin_intents_origin_status_idx ON origin_intents (origin, status);
CREATE INDEX destination_intents_destination_status_idx ON destination_intents (destination, status);
CREATE INDEX hub_intents_domain_status_queue_id_idx ON hub_intents (domain, status, queue_id);
CREATE INDEX queues_domain_type_idx ON queues (domain, type);
CREATE INDEX routers_owner_idx ON routers (owner);
CREATE INDEX assets_domain_token_id_idx ON assets (token_id, domain);

CREATE INDEX origin_intents_tx_nonce_idx ON origin_intents (tx_nonce);
CREATE INDEX destination_intents_tx_nonce_idx ON destination_intents (tx_nonce);
CREATE INDEX messages_tx_nonce_idx ON messages (tx_nonce);

-- migrate:down
DROP INDEX IF EXISTS origin_intents_origin_status_idx;
DROP INDEX IF EXISTS destination_intents_destination_status_idx;
DROP INDEX IF EXISTS hub_intents_domain_status_queue_id_idx;
DROP INDEX IF EXISTS queues_domain_type_idx;
DROP INDEX IF EXISTS routers_owner_idx;
DROP INDEX IF EXISTS assets_domain_token_id_idx;
DROP INDEX IF EXISTS origin_intents_tx_nonce_idx;
DROP INDEX IF EXISTS destination_intents_tx_nonce_idx;
DROP INDEX IF EXISTS messages_tx_nonce_idx;