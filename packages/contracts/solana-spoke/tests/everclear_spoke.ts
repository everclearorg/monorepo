import * as anchor from '@coral-xyz/anchor';
import { EverclearSpoke } from '../target/types/everclear_spoke';
import { expect } from '@chimera-monorepo/utils';
import * as token from '@solana/spl-token';

describe('#everclear_spoke', () => {
  anchor.setProvider(anchor.AnchorProvider.local());
  const connection = anchor.getProvider().connection;
  const program = anchor.workspace.EverclearSpoke as anchor.Program<EverclearSpoke>;
  const [spokeStateAddress, _] = anchor.web3.PublicKey.findProgramAddressSync([Buffer.from('spoke-state')], program.programId);

  const lighthouseKeyPair = anchor.web3.Keypair.generate();
  const watchtowerKeyPair = anchor.web3.Keypair.generate();
  const mailboxKeyPair = anchor.web3.Keypair.generate();
  const ownerKeyPair = anchor.web3.Keypair.generate();
  const mint = anchor.web3.Keypair.generate();
  const vault = anchor.web3.Keypair.generate();
  const user = anchor.web3.Keypair.generate();
  const payer = anchor.Wallet.local().payer;

  const intentAmount = new anchor.BN(1000);
  const initialMessageGasLimit = new anchor.BN(10000);
  const TOKEN_DECIMALS = 18;

  describe('#initialize', () => {
    it('should work', async () => {
      // Arrange
      const params = {
        domain: 1,
        hubDomain: 2,
        lighthouse: lighthouseKeyPair.publicKey,
        watchtower: watchtowerKeyPair.publicKey,
        callExecutor: anchor.web3.Keypair.generate().publicKey,
        messageReceiver: anchor.web3.Keypair.generate().publicKey,
        messageGasLimit: initialMessageGasLimit,
        owner: ownerKeyPair.publicKey,
        mailbox: mailboxKeyPair.publicKey,
      };

      // Act
      await program.methods.initialize(params).rpc();

      // Assert
      const spokeState = await program.account.spokeState.fetch(spokeStateAddress);
      expect(spokeState.initializedVersion).to.be.equal(1);
      expect(spokeState.paused).to.be.equal(false);
      expect(spokeState.domain).to.be.equal(params.domain);
      expect(spokeState.everclear).to.be.equal(params.hubDomain);
      expect(spokeState.lighthouse.toBase58()).to.be.equal(lighthouseKeyPair.publicKey.toBase58());
      expect(spokeState.watchtower.toBase58()).to.be.equal(watchtowerKeyPair.publicKey.toBase58());
      expect(spokeState.callExecutor.toBase58()).to.be.equal(params.callExecutor.toBase58());
      expect(spokeState.messageReceiver.toBase58()).to.be.equal(params.messageReceiver.toBase58());
      expect(spokeState.messageGasLimit.toString()).to.be.equal(params.messageGasLimit.toString());
      expect(spokeState.owner.toBase58()).to.be.equal(ownerKeyPair.publicKey.toBase58());
      expect(spokeState.mailbox.toBase58()).to.be.equal(mailboxKeyPair.publicKey.toBase58());
      expect(spokeState.nonce.toString()).to.be.equal(new anchor.BN(0).toString());
      expect(spokeState.status).to.be.empty;
    });
  });

  describe('#new_intent', () => {

    it('should work', async () => {
      // Arrange

      // Create a mint account
      const mintPubkey = await token.createMint(
        connection,
        payer, // fee payer
        mint.publicKey, // mint authority
        mint.publicKey, // freeze authority
        TOKEN_DECIMALS, // decimals
      );

      // Create a user token account
      const userTokenAccount = await token.createAssociatedTokenAccount(
        connection,
        payer, // fee payer
        mintPubkey, // mint
        user.publicKey, // owner,
      );

      // Mint some tokens to the user token account
      await token.mintToChecked(
        connection,
        payer, // fee payer
        mintPubkey, // mint
        userTokenAccount, // receiver (should be a token account)
        mint, // mint authority
        50000, // amount
        TOKEN_DECIMALS, // decimals
      );

      // Create a program vault account
      const programVaultAccount = await token.createAssociatedTokenAccount(
        connection,
        payer, // fee payer
        mintPubkey, // mint
        vault.publicKey, // owner,
      );

      // Act
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
        spokeState: spokeStateAddress,
        payer: payer.publicKey,
        authority: user.publicKey,
        mint: mintPubkey,
        userTokenAccount,
        programVaultAccount,
      })
      .signers([user])
      .rpc();

      // Assert
      const vaultBalance = await connection.getTokenAccountBalance(programVaultAccount);
      expect(vaultBalance.value.amount).to.be.equal(intentAmount.toString());

      const spokeState = await program.account.spokeState.fetch(spokeStateAddress);
      expect(spokeState.status.length).to.be.equal(1);
    });
  });

  describe('#pause', () => {
    it('should work', async () => {
      // Sanity check
      let spokeState = await program.account.spokeState.fetch(spokeStateAddress);
      expect(spokeState.paused).to.be.equal(false);

      // Act
      await program.methods.pause()
        .accounts({
          spokeState: spokeStateAddress,
          admin: lighthouseKeyPair.publicKey,
        })
        .signers([lighthouseKeyPair])
        .rpc();

      // Assert
      spokeState = await program.account.spokeState.fetch(spokeStateAddress);
      expect(spokeState.paused).to.be.equal(true);
    });
  });

  describe('#unpause', () => {
    it('should work', async () => {
      // Sanity check
      let spokeState = await program.account.spokeState.fetch(spokeStateAddress);
      expect(spokeState.paused).to.be.equal(true);

      // Act
      await program.methods.unpause()
        .accounts({
          spokeState: spokeStateAddress,
          admin: watchtowerKeyPair.publicKey,
        })
        .signers([watchtowerKeyPair])
        .rpc();

      // Assert
      spokeState = await program.account.spokeState.fetch(spokeStateAddress);
      expect(spokeState.paused).to.be.equal(false);
    });
  });

  describe('#update_lighthouse', () => {
    it('should work', async () => {
      // Arrange
      const newLighthouseKeyPair = anchor.web3.Keypair.generate();

      // Sanity check
      let spokeState = await program.account.spokeState.fetch(spokeStateAddress);
      expect(spokeState.lighthouse.toBase58()).to.be.equal(lighthouseKeyPair.publicKey.toBase58());

      // Act
      await program.methods.updateLighthouse(newLighthouseKeyPair.publicKey)
        .accounts({
          spokeState: spokeStateAddress,
          admin: ownerKeyPair.publicKey,
        })
        .signers([ownerKeyPair])
        .rpc();

      // Assert
      spokeState = await program.account.spokeState.fetch(spokeStateAddress);
      expect(spokeState.lighthouse.toBase58()).to.be.equal(newLighthouseKeyPair.publicKey.toBase58());
    });
  });

  describe('#update_watchtower', () => {
    it('should work', async () => {
      // Arrange
      const newWatchtowerKeyPair = anchor.web3.Keypair.generate();

      // Sanity check
      let spokeState = await program.account.spokeState.fetch(spokeStateAddress);
      expect(spokeState.watchtower.toBase58()).to.be.equal(watchtowerKeyPair.publicKey.toBase58());

      // Act
      await program.methods.updateWatchtower(newWatchtowerKeyPair.publicKey)
        .accounts({
          spokeState: spokeStateAddress,
          admin: ownerKeyPair.publicKey,
        })
        .signers([ownerKeyPair])
        .rpc();

      // Assert
      spokeState = await program.account.spokeState.fetch(spokeStateAddress);
      expect(spokeState.watchtower.toBase58()).to.be.equal(newWatchtowerKeyPair.publicKey.toBase58());
    });
  });

  describe('#update_mailbox', () => {
    it('should work', async () => {
      // Arrange
      const newMailboxKeyPair = anchor.web3.Keypair.generate();

      // Sanity check
      let spokeState = await program.account.spokeState.fetch(spokeStateAddress);
      expect(spokeState.mailbox.toBase58()).to.be.equal(mailboxKeyPair.publicKey.toBase58());

      // Act
      await program.methods.updateMailbox(newMailboxKeyPair.publicKey)
        .accounts({
          spokeState: spokeStateAddress,
          admin: ownerKeyPair.publicKey,
        })
        .signers([ownerKeyPair])
        .rpc();

      // Assert
      spokeState = await program.account.spokeState.fetch(spokeStateAddress);
      expect(spokeState.mailbox.toBase58()).to.be.equal(newMailboxKeyPair.publicKey.toBase58());
    });
  });

  describe('#update_message_gas_limit', () => {
    it('should work', async () => {
      // Arrange
      const newMessageGasLimit = new anchor.BN(20000);

      // Sanity check
      let spokeState = await program.account.spokeState.fetch(spokeStateAddress);
      expect(spokeState.messageGasLimit.toString()).to.be.equal(initialMessageGasLimit.toString());

      // Act
      await program.methods.updateMessageGasLimit(newMessageGasLimit)
        .accounts({
          spokeState: spokeStateAddress,
          admin: ownerKeyPair.publicKey,
        })
        .signers([ownerKeyPair])
        .rpc();

      // Assert
      spokeState = await program.account.spokeState.fetch(spokeStateAddress);
      expect(spokeState.messageGasLimit.toString()).to.be.equal(newMessageGasLimit.toString());
    });
  });
});
