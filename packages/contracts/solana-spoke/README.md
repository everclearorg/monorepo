## prerequisties

- `anchor 0.31.0`

## build

Build the contract code locally to ebpf using:

`anchor build`

If you need a verifiable build (for crosschecking and contract verification), use:
`anchor build --verifiable`

NOTE:
The upstream image is not pushed yet (it will be updated to `solanafoundation/anchor:v0.31.1`) and this is blocked (due to some perm issue  and docker org/image changes from the anchor side).

To temporary resolve this, the `docker/` in `anchor@v0.31.0` git is copied here.

Go to the `docker/` and run `make build`. This will create a local build for `backpackapp/build:v0.31.0` which is used in the verifiable build commands.

## deploy
`Anchor.toml` was set to be deployed on devnet.

For local deployment, run `anchor deploy --provider.cluster localnet`. This is the recommended things since you can always hold authority of the contract locally and redeploy as needed.

For devnet deployment, run `anchor deploy`. This should deploy/upgrade into the same address configured in Anchor.toml; note 

To deploy on an alternate address, you will need to do the following
- update the public key in `declare_id!` macro for each program
- copy the new keypair file to target/deploy/<program>-keypair.json
- update `Anchor.toml` [programs.devnet] entry

where this can be simplified by using `anchor init` for another workspace, creating all new programs with `anchor new`, and copy the files / address there.
