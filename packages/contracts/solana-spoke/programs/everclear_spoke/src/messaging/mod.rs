pub mod hyperlane;
pub mod ccip;

use crate::state::{MessagingProviderType, SpokeState};

pub fn get_messaging_provider(state: &SpokeState) -> MessagingProviderType {
    state.messaging_provider
}
