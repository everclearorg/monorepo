use anchor_lang::prelude::*;

/// A borsh-serializable version of `AccountMeta`.
#[derive(Debug, AnchorSerialize, AnchorDeserialize)]
pub struct SerializableAccountMeta {
    pub pubkey: Pubkey,
    pub is_signer: bool,
    pub is_writable: bool,
}

pub fn to_serializable_account_meta(pubkey: Pubkey, is_writable: bool) -> SerializableAccountMeta {
    SerializableAccountMeta {
        pubkey,
        is_signer: false,
        is_writable,
    }
}

impl From<AccountMeta> for SerializableAccountMeta {
    fn from(account_meta: AccountMeta) -> Self {
        Self {
            pubkey: account_meta.pubkey,
            is_signer: account_meta.is_signer,
            is_writable: account_meta.is_writable,
        }
    }
}

impl From<SerializableAccountMeta> for AccountMeta {
    fn from(serializable_account_meta: SerializableAccountMeta) -> Self {
        Self {
            pubkey: serializable_account_meta.pubkey,
            is_signer: serializable_account_meta.is_signer,
            is_writable: serializable_account_meta.is_writable,
        }
    }
}
