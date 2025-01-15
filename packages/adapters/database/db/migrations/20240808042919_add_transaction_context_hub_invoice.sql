-- migrate:up

ALTER TABLE hub_invoices ADD COLUMN enqueued_transaction_hash character varying(66) NOT NULL;
ALTER TABLE hub_invoices ADD COLUMN enqueued_block_number bigint NOT NULL;

-- migrate:down

ALTER TABLE hub_invoices DROP COLUMN enqueued_block_number;
ALTER TABLE hub_invoices DROP COLUMN enqueued_transaction_hash;