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

impl SVM2AnyMessage {
    pub fn new_data_only(receiver: Vec<u8>, data: Vec<u8>) -> Self {
        // Build extra_args with GenericExtraArgsV2
        // Tag: 0x181dcf10 (GENERIC_EXTRA_ARGS_V2_TAG)
        // Struct: { gas_limit: u128, allow_out_of_order_execution: bool }
        let mut extra_args = Vec::new();
        extra_args.extend_from_slice(&0x181dcf10u32.to_be_bytes()); // Tag
        extra_args.extend_from_slice(&0u128.to_le_bytes()); // gas_limit: 0 (use default)
        extra_args.push(1u8); // allow_out_of_order_execution: true
        
        Self {
            receiver,
            data,
            token_amounts: Vec::new(),
            fee_token: Pubkey::default(),
            extra_args,
        }
    }
    
    #[allow(dead_code)]
    pub fn new_data_only_with_fee_token(receiver: Vec<u8>, data: Vec<u8>, fee_token: Pubkey) -> Self {
        Self {
            receiver,
            data,
            token_amounts: Vec::new(),
            fee_token,
            extra_args: Vec::new(),
        }
    }
}

