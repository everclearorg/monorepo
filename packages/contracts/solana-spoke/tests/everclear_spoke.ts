import * as anchor from '@coral-xyz/anchor';
import { EverclearSpoke } from '../target/types/everclear_spoke';
import { expect } from '@chimera-monorepo/utils';
import * as token from '@solana/spl-token';
import { concat } from 'viem';
import * as nacl from 'tweetnacl';
import * as solana from '@solana-developers/helpers';

describe('#everclear_spoke', () => {
  anchor.setProvider(anchor.AnchorProvider.local());
  const connection = anchor.getProvider().connection;

  const program = anchor.workspace.EverclearSpoke as anchor.Program<EverclearSpoke>;

  const [spokeStateAddress] = anchor.web3.PublicKey.findProgramAddressSync(
    [Buffer.from('spoke-state')],
    program.programId,
  );

  const [feeAdapterStateAddress, feeAdapterStateBump] = anchor.web3.PublicKey.findProgramAddressSync(
    [Buffer.from('fee-adapter-state')],
    program.programId,
  );

  const feeSigner = nacl.sign.keyPair();
  const feeSignerAnchor = anchor.web3.Keypair.fromSecretKey(feeSigner.secretKey);

  const feeRecipient = anchor.web3.Keypair.generate();

  const [vaultAuthority, vaultAuthorityBump] = anchor.web3.PublicKey.findProgramAddressSync(
    [Buffer.from('vault')],
    program.programId,
  );
  const [dispatchAuthority, mailboxDispatchAuthorityBump] = anchor.web3.PublicKey.findProgramAddressSync(
    [Buffer.from('hyperlane_dispatcher'), Buffer.from('-'), Buffer.from('dispatch_authority')],
    program.programId,
  );
  const hyperlaneMailbox = new anchor.web3.PublicKey('E588QtVUvresuXq2KoNEwAmoifCzYGpRBdHByN9KQMbi'); // mainnet
  // const hyperlaneMailbox = new anchor.web3.PublicKey('75HBBLae3ddeneJVrZeyrDfv6vb7SMC3aCpBucSXS5aR'); // testnet
  const [mailboxOutbox] = anchor.web3.PublicKey.findProgramAddressSync(
    [Buffer.from('hyperlane'), Buffer.from('-'), Buffer.from('outbox')],
    hyperlaneMailbox,
  );
  const uniqueMessageAccountKeypair = anchor.web3.Keypair.generate();
  const [dispatchedMessagePda] = anchor.web3.PublicKey.findProgramAddressSync(
    [
      Buffer.from('hyperlane'),
      Buffer.from('-'),
      Buffer.from('dispatched_message'),
      Buffer.from('-'),
      uniqueMessageAccountKeypair.publicKey.toBuffer(),
    ],
    hyperlaneMailbox,
  );

  const igpProgram = new anchor.web3.PublicKey('BhNcatUDC2D5JTyeaqrdSukiVFsEHK7e3hVmKMztwefv'); // mainnet
  const configuredIgpAccount = new anchor.web3.PublicKey('JAvHW21tYXE9dtdG83DReqU2b4LUexFuCbtJT5tF8X6M'); // mainnet
  const innerIgpAccount = new anchor.web3.PublicKey('AkeHBbE5JkwVppujCQQ6WuxsVsJtruBAjUo6fDCFp6fF'); // mainnet
  // const igpProgram = new anchor.web3.PublicKey('5p7Hii6CJL4xGBYYTGEQmH9LnUSZteFJUu9AVLDExZX2'); // testnet
  // const configuredIgpAccount = new anchor.web3.PublicKey('9SQVtTNsbipdMzumhzi6X8GwojiSMwBfqAhS7FgyTcqy'); // testnet
  // const innerIgpAccount = new anchor.web3.PublicKey('hBHAApi5ZoeCYHqDdCKkCzVKmBdwywdT3hMqe327eZB'); // testnet
  const [igpProgramData] = anchor.web3.PublicKey.findProgramAddressSync(
    [Buffer.from('hyperlane_igp'), Buffer.from('-'), Buffer.from('program_data')],
    igpProgram,
  );
  const [igpPaymentPda] = anchor.web3.PublicKey.findProgramAddressSync(
    [
      Buffer.from('hyperlane_igp'),
      Buffer.from('-'),
      Buffer.from('gas_payment'),
      Buffer.from('-'),
      uniqueMessageAccountKeypair.publicKey.toBuffer(),
    ],
    igpProgram,
  );

  const mint = anchor.web3.Keypair.generate();
  const user = anchor.Wallet.local().payer;

  const outgoingIntentAmount = new anchor.BN((1e8).toString());
  const incomingIntentAmount = new anchor.BN('5000000000000000000000');
  const initialMessageGasLimit = new anchor.BN(10000);
  const TOKEN_DECIMALS = 8;

  const splNoopProgram = new anchor.web3.PublicKey('noopb9bkMVfRPU8AsbpTUg8AQkHtKwMYZiFUjNRtMmV');

  const lighthouseKeyPair = anchor.web3.Keypair.generate();
  const watchtowerKeyPair = anchor.web3.Keypair.generate();

  const toBytes32 = (value: number | anchor.BN) => {
    return new anchor.BN(value).toArray('be', 32);
  };

  const intentId = toBytes32(4);

  const [intentStatusPda] = anchor.web3.PublicKey.findProgramAddressSync(
    [Buffer.from('everclear_spoke'), Buffer.from('-'), Buffer.from('intent_status'), intentId],
    program.programId,
  );

  const [pdaPayer] = anchor.web3.PublicKey.findProgramAddressSync(
    [Buffer.from('everclear_spoke'), Buffer.from('-'), Buffer.from('pda_payer')],
    program.programId,
  );

  describe('#initialize', () => {
    it('should work', async () => {
      // Arrange
      const params = {
        domain: 1,
        hubDomain: 2,
        lighthouse: lighthouseKeyPair.publicKey,
        watchtower: watchtowerKeyPair.publicKey,
        messageGasLimit: initialMessageGasLimit,
        owner: user.publicKey,
        mailbox: hyperlaneMailbox,
        igp: igpProgram,
        igpType: {
          igp: {
            '0': configuredIgpAccount,
          },
        },
        mailboxDispatchAuthorityBump,
        vaultAuthorityBump,
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
      expect(spokeState.messageGasLimit.toString()).to.be.equal(params.messageGasLimit.toString());
      expect(spokeState.owner.toBase58()).to.be.equal(user.publicKey.toBase58());
      expect(spokeState.mailbox.toBase58()).to.be.equal(hyperlaneMailbox.toBase58());
      expect(spokeState.nonce.toString()).to.be.equal(new anchor.BN(0).toString());
      expect(spokeState.mailboxDispatchAuthorityBump).to.be.equal(mailboxDispatchAuthorityBump);
      expect(spokeState.igp.toBase58()).to.be.equal(igpProgram.toBase58());
      expect(spokeState.igpType.igp!['0'].toBase58()).to.be.equal(configuredIgpAccount.toBase58());
    });
  });

  const fillSigner = nacl.sign.keyPair();
  const fillSignerAnchor = anchor.web3.Keypair.fromSecretKey(fillSigner.secretKey);

  describe('#initialize_fee_adapter', () => {
    it('should work', async () => {
      const tx = await program.methods
        .initializeFeeAdapter(feeRecipient.publicKey, feeSignerAnchor.publicKey, fillSignerAnchor.publicKey)
        .accounts({
          program: program.programId,
        })
        .rpc();

      // Assert
      const feeAdapterState = await program.account.feeAdapterState.fetch(feeAdapterStateAddress);
      expect(feeAdapterState.initialized).to.be.equal(true);
      expect(feeAdapterState.paused).to.be.equal(false);
      expect(feeAdapterState.feeRecipient.toBase58()).to.be.equal(feeRecipient.publicKey.toBase58());
      expect(feeAdapterState.feeSigner.toBase58()).to.be.equal(feeSignerAnchor.publicKey.toBase58());
      expect(feeAdapterState.fillSigner.toBase58()).to.be.equal(fillSignerAnchor.publicKey.toBase58());
      expect(feeAdapterState.bump).to.be.equal(feeAdapterStateBump);
    });
  });

  describe('#new_intent', () => {
    it('should work', async () => {
      // Arrange

      // Create a mint account
      const mintPubkey = await token.createMint(
        connection,
        user, // fee payer
        mint.publicKey, // mint authority
        mint.publicKey, // freeze authority
        TOKEN_DECIMALS, // decimals
      );
      
      // Create a token account for fee recipient
      const feeRecipientTokenAccount = await token.createAssociatedTokenAccount(
        connection,
        user, // fee payer
        mintPubkey, // mint
        feeRecipient.publicKey, // owner,
      );

      // Create a user token account
      const userTokenAccount = await token.createAssociatedTokenAccount(
        connection,
        user, // fee payer
        mintPubkey, // mint
        user.publicKey, // owner,
      );

      // Mint some tokens to the user token account
      await token.mintToChecked(
        connection,
        user, // fee payer
        mintPubkey, // mint
        userTokenAccount, // receiver (should be a token account)
        mint, // mint authority
        5e8, // amount
        TOKEN_DECIMALS, // decimals
      );

      // Create a program vault account
      const programVault = await token.getOrCreateAssociatedTokenAccount(
        connection,
        user, // fee payer
        mintPubkey, // mint
        vaultAuthority, // owner
        true, // allowOwnerOffCurve is true because the owner is a PDA
      );

      const time = Date.now() / 1000;
      const receiver = anchor.web3.Keypair.generate().publicKey;
      const outputAsset = anchor.web3.Keypair.generate().publicKey;
      const amountOutMin = new anchor.BN(0);
      const destinations = [1];
      const data = Buffer.from('');
      const feeData = {
        destinations,
        input_asset: mintPubkey,
        output_asset: outputAsset,
        amount: outgoingIntentAmount,
        amount_out_min: amountOutMin,
        ttl: new anchor.BN(0),
        data,
        token_fee: new anchor.BN(1000),
        native_fee: new anchor.BN(0),
        deadline: new anchor.BN(time),
      };

      const buf = program.coder.types.encode('feeData', feeData);
      const signature = nacl.sign.detached(buf, feeSigner.secretKey);

      const signVerifyIx = anchor.web3.Ed25519Program.createInstructionWithPublicKey({
        publicKey: feeSigner.publicKey,
        message: buf,
        signature: signature,
      });

      // Act
      await program.methods
        .newIntent(
          receiver,
          outputAsset,
          outgoingIntentAmount,
          amountOutMin,
          new anchor.BN(0), // ttl
          destinations,
          data,
          new anchor.BN(4321), // message_gas_limit
          {
            tokenFee: feeData.token_fee,
            nativeFee: feeData.native_fee,
            deadline: feeData.deadline,
            signature: Buffer.from(signature),
          },
        )
        .accounts({
          authority: user.publicKey,
          mint: mintPubkey,
          userTokenAccount,
          programVaultAccount: programVault.address,
          hyperlaneMailbox,
          mailboxOutbox,
          dispatchAuthority,
          uniqueMessageAccount: uniqueMessageAccountKeypair.publicKey,
          dispatchedMessagePda,
          igpProgram,
          igpProgramData,
          igpPaymentPda,
          configuredIgpAccount,
          innerIgpAccount,
          feeRecipient: feeRecipient.publicKey,
          feeSigner: feeSignerAnchor.publicKey,
          feeRecipientTokenAccount: feeRecipientTokenAccount,
          program: program.programId
        })
        .preInstructions([signVerifyIx])
        .signers([uniqueMessageAccountKeypair])
        .rpc();

      // Assert
      const vaultBalance = await connection.getTokenAccountBalance(programVault.address);
      expect(vaultBalance.value.amount).to.be.equal(outgoingIntentAmount.toString());
    });

    it('should revert when fee adapter is paused (EVER1-8 fix)', async () => {
      const mintPubkey = await token.createMint(
        connection,
        user,
        mint.publicKey,
        mint.publicKey,
        TOKEN_DECIMALS,
      );
      const feeRecipientTokenAccount = await token.createAssociatedTokenAccount(
        connection,
        user,
        mintPubkey,
        feeRecipient.publicKey,
      );
      const userTokenAccount = await token.createAssociatedTokenAccount(
        connection,
        user,
        mintPubkey,
        user.publicKey,
      );
      await token.mintToChecked(
        connection,
        user,
        mintPubkey,
        userTokenAccount,
        mint,
        5e8,
        TOKEN_DECIMALS,
      );
      const programVault = await token.getOrCreateAssociatedTokenAccount(
        connection,
        user,
        mintPubkey,
        vaultAuthority,
        true,
      );
      await program.methods.pauseFeeAdapter().accounts({ admin: user.publicKey }).rpc();

      const feeAdapterState = await program.account.feeAdapterState.fetch(feeAdapterStateAddress);
      expect(feeAdapterState.paused).to.be.equal(true);

      const time = Date.now() / 1000;
      const feeData = {
        destinations: [1],
        input_asset: mintPubkey,
        output_asset: anchor.web3.Keypair.generate().publicKey,
        amount: outgoingIntentAmount,
        amount_out_min: new anchor.BN(0),
        ttl: new anchor.BN(0),
        data: Buffer.from(''),
        token_fee: new anchor.BN(1000),
        native_fee: new anchor.BN(0),
        deadline: new anchor.BN(time),
      };
      const buf = program.coder.types.encode('feeData', feeData);
      const signature = nacl.sign.detached(buf, feeSigner.secretKey);
      const signVerifyIx = anchor.web3.Ed25519Program.createInstructionWithPublicKey({
        publicKey: feeSigner.publicKey,
        message: buf,
        signature: signature,
      });

      try {
        await program.methods
          .newIntent(
            anchor.web3.Keypair.generate().publicKey,
            anchor.web3.Keypair.generate().publicKey,
            outgoingIntentAmount,
            new anchor.BN(0),
            new anchor.BN(0),
            [1],
            Buffer.from(''),
            new anchor.BN(4321),
            {
              tokenFee: feeData.token_fee,
              nativeFee: feeData.native_fee,
              deadline: feeData.deadline,
              signature: Buffer.from(signature),
            },
          )
          .accounts({
            authority: user.publicKey,
            mint: mintPubkey,
            userTokenAccount,
            programVaultAccount: programVault.address,
            hyperlaneMailbox,
            mailboxOutbox,
            dispatchAuthority,
            uniqueMessageAccount: uniqueMessageAccountKeypair.publicKey,
            dispatchedMessagePda,
            igpProgram,
            igpProgramData,
            igpPaymentPda,
            configuredIgpAccount,
            innerIgpAccount,
            feeRecipient: feeRecipient.publicKey,
            feeSigner: feeSignerAnchor.publicKey,
            feeRecipientTokenAccount: feeRecipientTokenAccount,
            program: program.programId,
          })
          .preInstructions([signVerifyIx])
          .signers([uniqueMessageAccountKeypair])
          .rpc();
        expect.fail('new_intent should have reverted when fee adapter is paused');
      } catch (err: unknown) {
        const e = err as { error?: { errorCode?: { code?: string; name?: string } } };
        expect(e.error?.errorCode?.code).to.be.equal('FeeAdapterPaused');
        expect(e.error?.errorCode?.name).to.be.equal('FeeAdapterPaused');
      }

      await program.methods.unpauseFeeAdapter().accounts({ admin: user.publicKey }).rpc();
    });
  });

  describe('#handle_as_admin', () => {
    it('should work', async () => {
      // Arrange
      await connection.requestAirdrop(pdaPayer, 50000000);

      // Create a mint account
      const mintPubkey = await token.createMint(
        connection,
        user, // fee payer
        mint.publicKey, // mint authority
        mint.publicKey, // freeze authority
        TOKEN_DECIMALS, // decimals
      );

      // Create a program vault account
      const programVault = await token.getOrCreateAssociatedTokenAccount(
        connection,
        user, // fee payer
        mintPubkey, // mint
        vaultAuthority, // owner
        true, // allowOwnerOffCurve is true because the owner is a PDA
      );

      // Mint some tokens to the user token account
      await token.mintToChecked(
        connection,
        user, // fee payer
        mintPubkey, // mint
        programVault.address, // receiver (should be a token account)
        mint, // mint authority
        7e11, // amount
        TOKEN_DECIMALS, // decimals
      );

      const vaultBalance = await connection.getTokenAccountBalance(programVault.address);
      expect(vaultBalance.value.amount).to.be.equal((7e11).toString());
      expect(vaultBalance.value.uiAmountString).to.be.equal((7000).toString());

      const type = toBytes32(2); // Settlement
      const ignored = toBytes32(0);
      const size = toBytes32(1);
      const header = concat([type, ignored, ignored, ignored, size]);

      const amount = toBytes32(incomingIntentAmount);
      const asset = mintPubkey.toBuffer();
      const recipient = user.publicKey.toBuffer();
      const updateVirtualBalance = toBytes32(0);
      const intent = concat([intentId, amount, asset, recipient, updateVirtualBalance]);

      const handle = {
        origin: 25327,
        sender: {
          0: [
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 239, 250, 183, 204, 235, 246, 63, 190, 251, 72, 132, 150, 75, 18, 37,
            157, 67, 116, 250, 170,
          ],
        },
        message: Buffer.from(concat([header, intent])),
      };

      // Act
      try {
        await program.methods
          .handleAsAdmin(handle)
          .accounts({
            authority: user.publicKey,
            spokeState: spokeStateAddress,
            intentStatusPda,
            systemProgram: anchor.web3.SystemProgram.programId,
            pdaPayer,
          })
          .rpc();
      } catch (e) {
        console.error(e);
      }

      // Assert
      const intentStatus = await program.account.intentStatusAccount.fetch(intentStatusPda);
      expect(intentStatus.status).to.be.deep.equal({ delivered: {} });
      expect(intentStatus.settlement!.intentId).to.be.deep.equal(intentId);
      expect(intentStatus.settlement!.asset.toBase58()).to.be.equal(mintPubkey.toBase58());
    });
  });

  describe('#settle_delivered_intent', () => {
    it('should work when the recipient ata is not created', async () => {
      // Arrange
      const settleIx = {
        intentId,
      };
      let intentStatus = await program.account.intentStatusAccount.fetch(intentStatusPda);
      const recipientTokenAccount = intentStatus.accounts[8].pubkey;
      const vaultTokenAccount = intentStatus.accounts[9].pubkey;

      // Sanity check
      expect(intentStatus.status).to.be.deep.equal({ delivered: {} });

      let vaultBalance = await connection.getTokenAccountBalance(vaultTokenAccount);
      expect(vaultBalance.value.amount).to.be.equal((7e11).toString());
      expect(vaultBalance.value.uiAmountString).to.be.equal((7000).toString());

      // assert recipient token account is not created yet
      expect(connection.getTokenAccountBalance(recipientTokenAccount)).to.be.rejectedWith(Error);

      // Act
      await program.methods
        .settleDeliveredIntent(settleIx)
        .accounts({
          authority: user.publicKey,
          spokeState: intentStatus.accounts[0].pubkey,
          intentStatusPda: intentStatus.accounts[1].pubkey,
          vaultAuthority: intentStatus.accounts[2].pubkey,
          mintAccount: intentStatus.accounts[5].pubkey,
          recipient: intentStatus.accounts[7].pubkey,
          recipientTokenAccount,
          vaultTokenAccount,
          program: program.programId,
        })
        .rpc();

      // Assert
      intentStatus = await program.account.intentStatusAccount.fetch(intentStatusPda);
      expect(intentStatus.status).to.be.deep.equal({ settled: {} });

      const incomingAmount = incomingIntentAmount.div(new anchor.BN(Math.pow(10, 18 - TOKEN_DECIMALS)));

      const recipientBalance = await connection.getTokenAccountBalance(recipientTokenAccount);
      expect(recipientBalance.value.amount).to.be.equal(incomingAmount.toString());
      expect(recipientBalance.value.uiAmountString).to.be.equal((5000).toString());

      vaultBalance = await connection.getTokenAccountBalance(vaultTokenAccount);
      expect(vaultBalance.value.amount).to.be.equal((2e11).toString());
      expect(vaultBalance.value.uiAmountString).to.be.equal((2000).toString());
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
      await program.methods
        .unpause()
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
      await program.methods
        .updateLighthouse(newLighthouseKeyPair.publicKey)
        .accounts({
          spokeState: spokeStateAddress,
          admin: user.publicKey,
        })
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
      await program.methods
        .updateWatchtower(newWatchtowerKeyPair.publicKey)
        .accounts({
          spokeState: spokeStateAddress,
          admin: user.publicKey,
        })
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
      expect(spokeState.mailbox.toBase58()).to.be.equal(hyperlaneMailbox.toBase58());

      // Act
      await program.methods
        .updateMailbox(newMailboxKeyPair.publicKey)
        .accounts({
          spokeState: spokeStateAddress,
          admin: user.publicKey,
        })
        .rpc();

      // Assert
      spokeState = await program.account.spokeState.fetch(spokeStateAddress);
      expect(spokeState.mailbox.toBase58()).to.be.equal(newMailboxKeyPair.publicKey.toBase58());
    });
  });

  describe('#update_igp', () => {
    it('should work', async () => {
      // Arrange
      const newIgp = anchor.web3.PublicKey.unique();
      const newInnerIgpAccount = anchor.web3.PublicKey.unique();
      const newIgpType = {
        overheadIgp: {
          '0': newInnerIgpAccount,
        }
      };

      // Sanity check
      let spokeState = await program.account.spokeState.fetch(spokeStateAddress);
      expect(spokeState.igp.toBase58()).to.be.equal(igpProgram.toBase58());
      expect(spokeState.igpType.igp!['0'].toBase58()).to.be.equal(configuredIgpAccount.toBase58());

      // Act
      await program.methods
        .updateIgp(newIgp, newIgpType)
        .accounts({
          spokeState: spokeStateAddress,
          admin: user.publicKey,
        })
        .rpc();

      // Assert
      spokeState = await program.account.spokeState.fetch(spokeStateAddress);
      expect(spokeState.igp.toBase58()).to.be.equal(newIgp.toBase58());
      expect(spokeState.igpType.overheadIgp!['0'].toBase58()).to.be.equal(newInnerIgpAccount.toBase58());
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
      await program.methods
        .updateMessageGasLimit(newMessageGasLimit)
        .accounts({
          spokeState: spokeStateAddress,
          admin: user.publicKey,
        })
        .rpc();

      // Assert
      spokeState = await program.account.spokeState.fetch(spokeStateAddress);
      expect(spokeState.messageGasLimit.toString()).to.be.equal(newMessageGasLimit.toString());
    });
  });

  describe('#update_mailbox_dispatch_authority_bump', () => {
    it('should work', async () => {
      // Arrange
      const newBump = 100;

      // Sanity check
      let spokeState = await program.account.spokeState.fetch(spokeStateAddress);
      expect(spokeState.mailboxDispatchAuthorityBump).to.be.equal(mailboxDispatchAuthorityBump);

      // Act
      await program.methods
        .updateMailboxDispatchAuthorityBump(newBump)
        .accounts({
          spokeState: spokeStateAddress,
          admin: user.publicKey,
        })
        .rpc();

      // Assert
      spokeState = await program.account.spokeState.fetch(spokeStateAddress);
      expect(spokeState.mailboxDispatchAuthorityBump).to.be.equal(newBump);
    });
  });

  describe('#update_vault_authority_bump', () => {
    it('should work', async () => {
      // Arrange
      const newBump = 150;

      // Sanity check
      let spokeState = await program.account.spokeState.fetch(spokeStateAddress);
      expect(spokeState.vaultAuthorityBump).to.be.equal(vaultAuthorityBump);

      // Act
      await program.methods
        .updateVaultAuthorityBump(newBump)
        .accounts({
          spokeState: spokeStateAddress,
          admin: user.publicKey,
        })
        .rpc();

      // Assert
      spokeState = await program.account.spokeState.fetch(spokeStateAddress);
      expect(spokeState.vaultAuthorityBump).to.be.equal(newBump);
    });
  });
});
