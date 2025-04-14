use anchor_lang::prelude::*;

use crate::hyperlane::{SerializableAccountMeta, SimulationReturnData};

pub fn interchain_security_module(_ctx: Context<InterchainSecurityModule>) -> Result<()> {
    // NOTE: return nothing to use the default ISM
    // ref: https://github.com/hyperlane-xyz/hyperlane-monorepo/blob/main/rust/sealevel/programs/mailbox/src/processor.rs#L475
    Ok(())
}

#[derive(Accounts)]
pub struct InterchainSecurityModule {}

pub fn interchain_security_module_account_metas(
    _ctx: Context<InterchainSecurityModuleAccountMetas>,
) -> Result<SimulationReturnData<Vec<SerializableAccountMeta>>> {
    // NOTE: we dont need to any account meta for the ISM call
    Ok(SimulationReturnData::new(vec![]))
}

#[derive(Accounts)]
pub struct InterchainSecurityModuleAccountMetas {}
