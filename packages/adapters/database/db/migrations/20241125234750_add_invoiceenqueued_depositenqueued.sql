-- migrate:up
CREATE MATERIALIZED VIEW invoice_enqueued_not_settled AS
 SELECT
    invoiceenqueued.address AS invoiceenqueued_address,
    invoiceenqueued.block_hash AS invoiceenqueued_block_hash,
    invoiceenqueued.block_number AS invoiceenqueued_block_number,
    invoiceenqueued.block_timestamp AS invoiceenqueued_block_timestamp,
    invoiceenqueued.chain AS invoiceenqueued_chain,
    invoiceenqueued.block_log_index AS invoiceenqueued_block_log_index,
    invoiceenqueued.name AS invoiceenqueued_name,
    invoiceenqueued.network AS invoiceenqueued_network,
    invoiceenqueued.topic_0 AS invoiceenqueued_topic_0,
    invoiceenqueued.topic_1 AS invoiceenqueued_topic_1,
    invoiceenqueued.topic_2 AS invoiceenqueued_topic_2,
    invoiceenqueued.topic_3 AS invoiceenqueued_topic_3,
    invoiceenqueued.transaction_hash AS invoiceenqueued_transaction_hash,
    invoiceenqueued.transaction_index AS invoiceenqueued_transaction_index,
    invoiceenqueued.transaction_log_index AS invoiceenqueued_transaction_log_index,
    invoiceenqueued.data___amount AS invoiceenqueued_data___amount,
    invoiceenqueued.data___entry_epoch AS invoiceenqueued_data___entry_epoch,
    invoiceenqueued.data___intent_id AS invoiceenqueued_data___intent_id,
    invoiceenqueued.data___owner AS invoiceenqueued_data___owner,
    invoiceenqueued.data___ticker_hash AS invoiceenqueued_data___ticker_hash,
    settlementenqueued.address AS settlementenqueued_address,
    settlementenqueued.block_hash AS settlementenqueued_block_hash,
    settlementenqueued.block_number AS settlementenqueued_block_number,
    settlementenqueued.block_timestamp AS settlementenqueued_block_timestamp,
    settlementenqueued.chain AS settlementenqueued_chain,
    settlementenqueued.block_log_index AS settlementenqueued_block_log_index,
    settlementenqueued.name AS settlementenqueued_name,
    settlementenqueued.network AS settlementenqueued_network,
    settlementenqueued.topic_0 AS settlementenqueued_topic_0,
    settlementenqueued.topic_1 AS settlementenqueued_topic_1,
    settlementenqueued.topic_2 AS settlementenqueued_topic_2,
    settlementenqueued.topic_3 AS settlementenqueued_topic_3,
    settlementenqueued.transaction_hash AS settlementenqueued_transaction_hash,
    settlementenqueued.transaction_index AS settlementenqueued_transaction_index,
    settlementenqueued.transaction_log_index AS settlementenqueued_transaction_log_index,
    settlementenqueued.data___amount AS settlementenqueued_data___amount,
    settlementenqueued.data___asset AS settlementenqueued_data___asset,
    settlementenqueued.data___domain AS settlementenqueued_data___domain,
    settlementenqueued.data___entry_epoch AS settlementenqueued_data___entry_epoch,
    settlementenqueued.data___intent_id AS settlementenqueued_data___intent_id,
    settlementenqueued.data___owner AS settlementenqueued_data___owner,
    settlementenqueued.data___update_virtual_balance AS settlementenqueued_data___update_virtual_balance
FROM public.invoiceenqueued
LEFT JOIN public.settlementenqueued ON ((invoiceenqueued.data___intent_id = settlementenqueued.data___intent_id))
WHERE settlementenqueued.data___intent_id IS NULL;

CREATE MATERIALIZED VIEW deposit_enqueued_not_processed AS
SELECT
    depositenqueued.address,
    depositenqueued.block_hash,
    depositenqueued.block_number,
    depositenqueued.block_timestamp,
    depositenqueued.chain,
    depositenqueued.block_log_index,
    depositenqueued.name,
    depositenqueued.network,
    depositenqueued.topic_0,
    depositenqueued.topic_1,
    depositenqueued.topic_2,
    depositenqueued.topic_3,
    depositenqueued.transaction_hash,
    depositenqueued.transaction_index,
    depositenqueued.transaction_log_index,
    depositenqueued.data___amount,
    depositenqueued.data___domain,
    depositenqueued.data___epoch,
    depositenqueued.data___intent_id,
    depositenqueued.data___ticker_hash,
    depositprocessed.address AS depositprocessed_address,
    depositprocessed.block_hash AS depositprocessed_block_hash,
    depositprocessed.block_number AS depositprocessed_block_number,
    depositprocessed.block_timestamp AS depositprocessed_block_timestamp,
    depositprocessed.chain AS depositprocessed_chain,
    depositprocessed.block_log_index AS depositprocessed_block_log_index,
    depositprocessed.name AS depositprocessed_name,
    depositprocessed.network AS depositprocessed_network,
    depositprocessed.topic_0 AS depositprocessed_topic_0,
    depositprocessed.topic_1 AS depositprocessed_topic_1,
    depositprocessed.topic_2 AS depositprocessed_topic_2,
    depositprocessed.topic_3 AS depositprocessed_topic_3,
    depositprocessed.transaction_hash AS depositprocessed_transaction_hash,
    depositprocessed.transaction_index AS depositprocessed_transaction_index,
    depositprocessed.transaction_log_index AS depositprocessed_transaction_log_index,
    depositprocessed.data___amount_and_rewards AS depositprocessed_data___amount_and_rewards,
    depositprocessed.data___domain AS depositprocessed_data___domain,
    depositprocessed.data___epoch AS depositprocessed_data___epoch,
    depositprocessed.data___intent_id AS depositprocessed_data___intent_id,
    depositprocessed.data___ticker_hash AS depositprocessed_data___ticker_hash
FROM public.depositenqueued
LEFT JOIN public.depositprocessed ON ((depositenqueued.data___intent_id = depositprocessed.data___intent_id))
WHERE depositprocessed.data___intent_id IS NULL;

REFRESH MATERIALIZED VIEW public.invoice_enqueued_not_settled;
REFRESH MATERIALIZED VIEW public.deposit_enqueued_not_processed;
SELECT cron.schedule('* * * * *', $$REFRESH MATERIALIZED VIEW public.invoice_enqueued_not_settled;$$);
SELECT cron.schedule('* * * * *', $$REFRESH MATERIALIZED VIEW public.deposit_enqueued_not_processed;$$);

GRANT SELECT ON public.invoice_enqueued_not_settled TO reader;
GRANT SELECT ON public.invoice_enqueued_not_settled TO query;
GRANT SELECT ON public.deposit_enqueued_not_processed TO reader;
GRANT SELECT ON public.deposit_enqueued_not_processed TO query;

-- migrate:down
DROP MATERIALIZED VIEW IF EXISTS invoice_enqueued_not_settled;
DROP MATERIALIZED VIEW IF EXISTS deposit_enqueued_not_processed;

