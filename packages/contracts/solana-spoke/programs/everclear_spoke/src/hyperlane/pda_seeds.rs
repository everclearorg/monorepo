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

/// The PDA seeds relating to the Mailbox's process authority for a particular recipient.
#[macro_export]
macro_rules! mailbox_process_authority_pda_seeds {
    ($recipient_pubkey:expr) => {{
        &[
            b"hyperlane",
            b"-",
            b"process_authority",
            b"-",
            $recipient_pubkey.as_ref(),
        ]
    }};

    ($recipient_pubkey:expr, $bump_seed:expr) => {{
        &[
            b"hyperlane",
            b"-",
            b"process_authority",
            b"-",
            $recipient_pubkey.as_ref(),
            &[$bump_seed],
        ]
    }};
}

/// The PDA seeds relating to the vault's authority.
#[macro_export]
macro_rules! vault_authority_pda_seeds {
    () => {{
        &[b"vault"]
    }};

    ($bump_seed:expr) => {{
        &[
            b"vault",
            &[$bump_seed],
        ]
    }};
}
