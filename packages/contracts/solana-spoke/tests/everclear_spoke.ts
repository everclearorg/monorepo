import * as anchor from '@coral-xyz/anchor';
import { EverclearSpoke } from '../target/types/everclear_spoke';
import * as token from '@solana/spl-token';

describe('#everclear_spoke', () => {
  process.env.ANCHOR_PROVIDER_URL = 'https://api.mainnet-beta.solana.com';
  anchor.setProvider(anchor.AnchorProvider.env());
  const program = anchor.workspace.EverclearSpoke as anchor.Program<EverclearSpoke>;

  const [spokeStateAddress] = anchor.web3.PublicKey.findProgramAddressSync([
    Buffer.from('spoke-state'),
  ], program.programId);
  const [dispatchAuthority] = anchor.web3.PublicKey.findProgramAddressSync([
    Buffer.from('hyperlane_dispatcher'),
    Buffer.from('-'),
    Buffer.from('dispatch_authority'),
  ], program.programId);

  const hyperlaneMailbox = new anchor.web3.PublicKey('E588QtVUvresuXq2KoNEwAmoifCzYGpRBdHByN9KQMbi');
  const [mailboxOutbox] = anchor.web3.PublicKey.findProgramAddressSync([
    Buffer.from('hyperlane'),
    Buffer.from('-'),
    Buffer.from('outbox'),
  ], hyperlaneMailbox);
  const uniqueMessageAccountKeypair = anchor.web3.Keypair.generate();
  const [dispatchedMessagePda] = anchor.web3.PublicKey.findProgramAddressSync([
    Buffer.from('hyperlane'),
    Buffer.from('-'),
    Buffer.from('dispatched_message'),
    Buffer.from('-'),
    uniqueMessageAccountKeypair.publicKey.toBuffer(),
  ], hyperlaneMailbox);

  const igpProgram = new anchor.web3.PublicKey('BhNcatUDC2D5JTyeaqrdSukiVFsEHK7e3hVmKMztwefv');
  const [igpProgramData] = anchor.web3.PublicKey.findProgramAddressSync([
    Buffer.from('hyperlane_igp'),
    Buffer.from('-'),
    Buffer.from('program_data'),
  ], igpProgram);
  const uniqueGasPaymentAccountKeypair = anchor.web3.Keypair.generate();
  const [igpPaymentPda] = anchor.web3.PublicKey.findProgramAddressSync([
    Buffer.from('hyperlane_igp'),
    Buffer.from('-'),
    Buffer.from('gas_payment'),
    Buffer.from('-'),
    uniqueGasPaymentAccountKeypair.publicKey.toBuffer(),
  ], igpProgram);

  const payer = anchor.Wallet.local().payer;

  const intentAmount = new anchor.BN('1000000000000000000');

  const mintPubkey = new anchor.web3.PublicKey('F3dhCVbGDo69yq2aV1YA2hWNn9Ggi2FYBovncmKeimvE');
  const userTokenAccount = new anchor.web3.PublicKey('3eT6apsdoc8f4cFaYPXHt8jbSn1kPrikt981o5kAQsmT');
  const programVaultAccount = new anchor.web3.PublicKey('7JYu1yBjgghqqwYDyW64xPytRB13ZkNZjBTXwYp7htLo');

  const splNoopProgram = new anchor.web3.PublicKey('noopb9bkMVfRPU8AsbpTUg8AQkHtKwMYZiFUjNRtMmV');

  describe('#new_intent', () => {
    it('should work', async () => {
      try {
        await program.methods.newIntent(
          anchor.web3.Keypair.generate().publicKey, // receiver
          anchor.web3.Keypair.generate().publicKey, // input_asset
          anchor.web3.Keypair.generate().publicKey, // output_asset
          intentAmount, // amount
          123, // max_fee
          new anchor.BN(0), // ttl
          [1], // destinations
          Buffer.from(''), // data
          new anchor.BN(4321) // message_gas_limit
        )
          .accounts({
            igpProgram,
            spokeState: spokeStateAddress,
            payer: payer.publicKey,
            authority: payer.publicKey,
            mint: mintPubkey,
            userTokenAccount,
            programVaultAccount,
            tokenProgram: token.TOKEN_PROGRAM_ID,
            hyperlaneMailbox,
            systemProgram: anchor.web3.SystemProgram.programId,
            splNoopProgram,
            mailboxOutbox,
            dispatchAuthority,
            uniqueMessageAccount: uniqueMessageAccountKeypair.publicKey,
            dispatchedMessagePda,
            igpProgramData,
            igpPaymentPda,
            configuredIgpAccount: igpProgram,
            innerIgpAccount: igpProgram,
          })
          .signers([
            uniqueMessageAccountKeypair,
          ])
          .rpc();
      } catch (e) {
        console.log(e);
      }
    });
  });
});
