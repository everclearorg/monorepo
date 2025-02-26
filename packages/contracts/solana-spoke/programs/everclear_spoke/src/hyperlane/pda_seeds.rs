//! This file contains the PDA seeds for the Mailbox program.

/// The PDA seeds relating to a program's dispatch authority.
#[macro_export]
macro_rules! mailbox_message_dispatch_authority_pda_seeds {
    () => {{
        &[b"hyperlane_dispatcher", b"-", b"dispatch_authority"]
    }};

    ($bump_seed:expr) => {{
        &[
            b"hyperlane_dispatcher",
            b"-",
            b"dispatch_authority",
            &[$bump_seed],
        ]
    }};
}
