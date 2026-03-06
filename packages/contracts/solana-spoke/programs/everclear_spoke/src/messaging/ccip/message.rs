use anchor_lang::prelude::*;

#[derive(AnchorSerialize, AnchorDeserialize, Clone, Debug)]
pub struct SVM2AnyMessage {
    pub receiver: Vec<u8>,
    pub data: Vec<u8>,
    pub token_amounts: Vec<TokenAmount>,
    pub fee_token: Pubkey,
    pub extra_args: Vec<u8>,
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone, Debug)]
pub struct TokenAmount {
    pub token: Pubkey,
    pub amount: u64,
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone, Debug)]
pub struct Any2SVMMessage {
    pub message_id: [u8; 32],
    pub source_chain_selector: u64,
    pub sender: Vec<u8>,
    pub data: Vec<u8>,
    pub token_amounts: Vec<TokenAmount>,
}

impl SVM2AnyMessage {
    pub fn new_data_only(receiver: Vec<u8>, data: Vec<u8>) -> Self {
        let mut extra_args = Vec::new();
        extra_args.extend_from_slice(&0x181dcf10u32.to_be_bytes());
        extra_args.extend_from_slice(&0u128.to_le_bytes());
        extra_args.push(1u8);

        Self {
            receiver,
            data,
            token_amounts: Vec::new(),
            fee_token: Pubkey::default(),
            extra_args,
        }
    }
}
