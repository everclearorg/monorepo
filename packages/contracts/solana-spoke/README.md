## prerequisties

- `anchor 0.30.1`

// NOTE: because of dependency resolving issue, I couldnt make `patch-crate` work in the build chain (`build.rs`) directly. Therefore, a seperate
command is required in the build chain.

Install cargo patch crate with this specific hash (the current main on 28 Feb 2025, manually reviewed code for security):
`cargo install --git https://github.com/mokeyish/cargo-patch-crate.git --rev ddbb58591d81daf6272ace7d66a7426999b42adf`

Run `patch-crate` to patch `anchor-syn`. This is required as `anchor 0.30.1` does not have support for discriminator:

`cargo patch-crate`

## build

Build the contract code locally to ebpf using:

`anchor build`

## deploy
`Anchor.toml` was set to be deployed on devnet.

For local deployment, run `anchor deploy --provider.cluster localnet`. This is the recommended things since you can always hold authority of the contract locally and redeploy as needed.

For devnet deployment, run `anchor deploy`. This should deploy/upgrade into the same address configured in Anchor.toml; note 

To deploy on an alternate address, you will need to do the following
- update the public key in `declare_id!` macro for each program
- copy the new keypair file to target/deploy/<program>-keypair.json
- update `Anchor.toml` [programs.devnet] entry

where this can be simplified by using `anchor init` for another workspace, creating all new programs with `anchor new`, and copy the files / address there.
