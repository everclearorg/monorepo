// NOTE: as importing solana-ed25519-program requires direct verify dependencies (rand_core etc that are
// hard to build in ebpf), we copy the constants and struct definition here instead
// Definition from https://github.com/anza-xyz/solana-sdk/blob/ed25519-program%40v2.2.2/ed25519-program/src/lib.rs

use bytemuck::{Pod, Zeroable};

pub const PUBKEY_SERIALIZED_SIZE: usize = 32;
pub const SIGNATURE_SERIALIZED_SIZE: usize = 64;
pub const SIGNATURE_OFFSETS_SERIALIZED_SIZE: usize = 14;
// bytemuck requires structures to be aligned
pub const SIGNATURE_OFFSETS_START: usize = 2;
pub const DATA_START: usize = SIGNATURE_OFFSETS_SERIALIZED_SIZE + SIGNATURE_OFFSETS_START;

#[derive(Default, Debug, Copy, Clone, Zeroable, Pod, Eq, PartialEq)]
#[repr(C)]
pub struct Ed25519SignatureOffsets {
    pub signature_offset: u16, // offset to ed25519 signature of 64 bytes
    pub signature_instruction_index: u16, // instruction index to find signature
    pub public_key_offset: u16, // offset to public key of 32 bytes
    pub public_key_instruction_index: u16, // instruction index to find public key
    pub message_data_offset: u16, // offset to start of message data
    pub message_data_size: u16, // size of message data
    pub message_instruction_index: u16, // index of instruction data to get message data
}
