-- migrate:up
CREATE TYPE message_status AS ENUM (
  'none',
  'pending',
  'delivered',
  'relayable'
);

ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS message_status public.message_status DEFAULT 'none'::public.message_status NOT NULL;

-- migrate:down
ALTER TABLE public.messages DROP COLUMN message_status;
DROP TYPE message_status;
