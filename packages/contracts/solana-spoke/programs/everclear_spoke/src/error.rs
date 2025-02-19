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
    #[msg("Queue operation invalid (zero or too many items).")]
    InvalidQueueOperation,
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
}
