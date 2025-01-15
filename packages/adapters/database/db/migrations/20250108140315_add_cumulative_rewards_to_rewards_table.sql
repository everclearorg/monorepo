-- migrate:up
ALTER TABLE public.epoch_results ADD COLUMN IF NOT EXISTS cumulative_rewards VARCHAR NOT NULL DEFAULT '0';
ALTER TABLE public.rewards ADD COLUMN IF NOT EXISTS cumulative_rewards VARCHAR NOT NULL DEFAULT '0';

-- migrate:down
ALTER TABLE public.rewards DROP COLUMN cumulative_rewards;
ALTER TABLE public.epoch_results DROP COLUMN cumulative_rewards;
