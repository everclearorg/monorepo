use anchor_lang::prelude::*;

// =====================================================================
// ERRORS
// =====================================================================

#[error_code]
pub enum SpokeError {
    #[msg("Only the contract owner can call this method.")]
    OnlyOwner,
    #[msg("Not authorized to pause.")]
    NotAuthorizedToPause,
    #[msg("Contract is paused.")]
    ContractPaused,
    #[msg("Invalid amount provided.")]
    InvalidAmount,
    #[msg("Invalid operation or overflow.")]
    InvalidOperation,
    #[msg("Intent not found.")]
    IntentNotFound,
    #[msg("Intent is in an invalid status for this operation.")]
    InvalidIntentStatus,
    #[msg("Max fee exceeded.")]
    MaxFeeExceeded,
    #[msg("Multiple input assets in a single order are not allowed.")]
    MultipleOrderAssets,
    #[msg("Empty Params in new order function are not allowed")]
    EmptyParams,
    #[msg("Invalid origin for inbound message.")]
    InvalidOrigin,
    #[msg("Invalid sender for inbound message.")]
    InvalidSender,
    #[msg("Invalid or unknown message.")]
    InvalidMessage,
    #[msg("Unauthorized operation.")]
    Unauthorized,
    #[msg("Signature has expired")]
    SignatureExpired,
    #[msg("Invalid signature")]
    InvalidSignature,
    #[msg("Zero amount provided")]
    ZeroAmount,
    #[msg("Decimal conversion overflow")]
    DecimalConversionOverflow,
    #[msg("Already initialized")]
    AlreadyInitialized,
    #[msg("Invalid Owner")]
    InvalidOwner,
    #[msg("Invalid var update")]
    InvalidVarUpdate,
    #[msg("Invalid intent")]
    InvalidIntent,
    #[msg("Overflow")]
    Overflow,
    #[msg("Invalid account meta")]
    InvalidAccount,
    #[msg("Invalid argument data")]
    InvalidArgument,
    #[msg("Incorrect program id")]
    IncorrectProgramId,
    #[msg("Missing required signature")]
    MissingRequiredSignature,
    #[msg("Extraneous account")]
    ExtraneousAccount,
    #[msg("Overflowing Integer")]
    IntegerOverflow,
    #[msg("Invalid seeds for deriving pda")]
    InvalidSeeds,
    #[msg("Invalid vault account")]
    InvalidVaultAccount,
    #[msg("Invalid intent pda")]
    InvalidIntentPda,
    #[msg("Invalid settlement size")]
    InvalidSettlementSize,
    #[msg("Incorrect settlement accounts, mismatch with intent PDA.")]
    IncorrectSettlementAccounts,
    #[msg("Invalid intent id")]
    InvalidIntentId,
    #[msg("Invalid deadline")]
    InvalidDeadline,
    #[msg("Missing ed25519 preinstructions")]
    MissingEd25519Instruction,
    #[msg("Invalid fee signature")]
    InvalidFeeSignature,
    #[msg("Invalid fee signature: preinstruction accounts not empty")]
    InvalidFeeSignatureAccountsNotEmpty,
    #[msg("Invalid fee signature: preinstruction data length mismatch")]
    InvalidFeeSignatureDataLength,
    #[msg("Invalid fee signature: number of signatures must be 1")]
    InvalidFeeSignatureNumSignatures,
    #[msg("Invalid fee signature: padding byte must be 0")]
    InvalidFeeSignaturePadding,
    #[msg("Invalid fee signature: offset mismatch")]
    InvalidFeeSignatureOffsets,
    #[msg("Invalid fee signature: public key mismatch with configured fee signer")]
    InvalidFeeSignaturePubkeyMismatch,
    #[msg("Invalid fee signature: signature data mismatch")]
    InvalidFeeSignatureDataMismatch,
    #[msg("Invalid fee signature: message data mismatch")]
    InvalidFeeSignatureMessageMismatch,
    #[msg("Fee adapter paused")]
    FeeAdapterPaused,
    #[msg("Wrong destination for fill intent")]
    WrongDestination,
    #[msg("fill intent expired")]
    IntentExpired,
    #[msg("fill intent amountOut is less than amountOutMin")]
    AmountOutInvalid,
    #[msg("invalid intent destinations")]
    InvalidDestinationArray,
    #[msg("intent is already filled")]
    InvalidFillIntentStatus,
    #[msg("Intent hash mismatch - signature not bound to this intent")]
    InvalidIntentHash,
    #[msg("A pending CCIP settlement already exists — settle it first")]
    PendingSettlementExists,
    #[msg("No pending CCIP settlement to settle")]
    NoPendingSettlement,
}
