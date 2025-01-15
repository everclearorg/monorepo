-- migrate:up
CREATE TYPE public.queue_type_new AS ENUM (
    'INTENT',
    'FILL',
    'SETTLEMENT'
);

ALTER TABLE queues
ALTER COLUMN type DROP DEFAULT,
ALTER COLUMN type TYPE public.queue_type_new USING type::text::public.queue_type_new;

DROP TYPE public.queue_type;
ALTER TYPE public.queue_type_new RENAME TO queue_type;

-- migrate:down

