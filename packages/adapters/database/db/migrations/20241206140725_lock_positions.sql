-- migrate:up

CREATE TABLE lock_positions
(
    "user" character varying(66) NOT NULL,
    amount_locked character varying(255) NOT NULL,
    start bigint NOT NULL,
    expiry bigint NOT NULL,
    CONSTRAINT lock_positions_user_start_pkey PRIMARY KEY ("user", start)
);

-- migrate:down

DROP TABLE lock_positions;

