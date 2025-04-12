#[macro_export]
macro_rules! intent_status_pda_seeds {
    ($intent_id:expr) => {{
        &[
            b"everclear_spoke",
            b"-",
            b"intent_status",
            $intent_id.as_ref(),
        ]
    }};

    ($intent_id:expr, $bump_seed:expr) => {{
        &[
            b"everclear_spoke",
            b"-",
            b"intent_status",
            $intent_id.as_ref(),
            &[$bump_seed],
        ]
    }};
}
