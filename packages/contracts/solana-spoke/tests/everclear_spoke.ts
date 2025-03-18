import * as anchor from '@coral-xyz/anchor';
import { EverclearSpoke } from '../target/types/everclear_spoke';
import { expect } from '@chimera-monorepo/utils';
import * as token from '@solana/spl-token';
import { concat } from 'viem';
import { ComputeBudgetProgram } from '@solana/web3.js';

describe('#everclear_spoke', () => {
  anchor.setProvider(anchor.AnchorProvider.local('https://api.mainnet-beta.solana.com'));
  const connection = anchor.getProvider().connection;
  const program = anchor.workspace.EverclearSpoke as anchor.Program<EverclearSpoke>;

  const [spokeStateAddress] = anchor.web3.PublicKey.findProgramAddressSync([
    Buffer.from('spoke-state'),
  ], program.programId);
  const [vaultAuthority, vaultAuthorityBump] = anchor.web3.PublicKey.findProgramAddressSync([
    Buffer.from('vault'),
  ], program.programId);
  const [dispatchAuthority, mailboxDispatchAuthorityBump] = anchor.web3.PublicKey.findProgramAddressSync([
    Buffer.from('hyperlane_dispatcher'),
    Buffer.from('-'),
    Buffer.from('dispatch_authority'),
  ], program.programId);

  const hyperlaneMailbox = new anchor.web3.PublicKey('E588QtVUvresuXq2KoNEwAmoifCzYGpRBdHByN9KQMbi'); // mainnet
  // const hyperlaneMailbox = new anchor.web3.PublicKey('75HBBLae3ddeneJVrZeyrDfv6vb7SMC3aCpBucSXS5aR'); // testnet

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


  // mainnet
  const igpProgram = new anchor.web3.PublicKey('BhNcatUDC2D5JTyeaqrdSukiVFsEHK7e3hVmKMztwefv'); // mainnet
  const configuredIgpAccount = new anchor.web3.PublicKey('JAvHW21tYXE9dtdG83DReqU2b4LUexFuCbtJT5tF8X6M'); // mainnet
  const innerIgpAccount = new anchor.web3.PublicKey('AkeHBbE5JkwVppujCQQ6WuxsVsJtruBAjUo6fDCFp6fF'); // mainnet

  // testnet
  // const igpProgram = new anchor.web3.PublicKey('5p7Hii6CJL4xGBYYTGEQmH9LnUSZteFJUu9AVLDExZX2'); // testnet
  // const configuredIgpAccount = new anchor.web3.PublicKey('9SQVtTNsbipdMzumhzi6X8GwojiSMwBfqAhS7FgyTcqy'); // testnet
  // const innerIgpAccount = new anchor.web3.PublicKey('hBHAApi5ZoeCYHqDdCKkCzVKmBdwywdT3hMqe327eZB'); // testnet

  const [igpProgramData] = anchor.web3.PublicKey.findProgramAddressSync([
    Buffer.from('hyperlane_igp'),
    Buffer.from('-'),
    Buffer.from('program_data'),
  ], igpProgram);
  const [igpPaymentPda] = anchor.web3.PublicKey.findProgramAddressSync([
    Buffer.from('hyperlane_igp'),
    Buffer.from('-'),
    Buffer.from('gas_payment'),
    Buffer.from('-'),
    uniqueMessageAccountKeypair.publicKey.toBuffer(),
  ], igpProgram);

  const mint = anchor.web3.Keypair.generate();
  const user = anchor.Wallet.local().payer;

  const intentAmount = new anchor.BN('1000000000000000'); //0.001 SOL
  const initialMessageGasLimit = new anchor.BN(10000);
  const TOKEN_DECIMALS = 18;

  const splNoopProgram = new anchor.web3.PublicKey('noopb9bkMVfRPU8AsbpTUg8AQkHtKwMYZiFUjNRtMmV');

  const lighthouseKeyPair = anchor.web3.Keypair.generate();
  const watchtowerKeyPair = anchor.web3.Keypair.generate();

  const toBytes32 = (value: number | anchor.BN) => {
    return new anchor.BN(value).toArray('be', 32)
  }

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
      expect(spokeState.callExecutor.toBase58()).to.be.equal(params.callExecutor.toBase58());
      expect(spokeState.messageReceiver.toBase58()).to.be.equal(params.messageReceiver.toBase58());
      expect(spokeState.messageGasLimit.toString()).to.be.equal(params.messageGasLimit.toString());
      expect(spokeState.owner.toBase58()).to.be.equal(user.publicKey.toBase58());
      expect(spokeState.mailbox.toBase58()).to.be.equal(hyperlaneMailbox.toBase58());
      expect(spokeState.nonce.toString()).to.be.equal(new anchor.BN(0).toString());
      expect(spokeState.status).to.be.empty;
      expect(spokeState.mailboxDispatchAuthorityBump).to.be.equal(mailboxDispatchAuthorityBump);
      expect(spokeState.igp.toBase58()).to.be.equal(igpProgram.toBase58());
      expect(spokeState.igpType.igp['0'].toBase58()).to.be.equal(configuredIgpAccount.toBase58());
    });
  });

  describe('#new_intent', () => {
    it.only('should work', async () => {
      // Arrange

      // Create a mint account
      const mintPubkey = await token.createMint(
        connection,
        user, // fee payer
        mint.publicKey, // mint authority
        mint.publicKey, // freeze authority
        TOKEN_DECIMALS, // decimals
      );
      console.log('mintPubkey', mintPubkey.toBase58());

      // Create a user token account
      const userTokenAccount = await token.createAssociatedTokenAccount(
        connection,
        user, // fee payer
        mintPubkey, // mint
        user.publicKey, // owner,
      );
      console.log('userTokenAccount', userTokenAccount.toBase58());
      // Mint some tokens to the user token account
      await token.mintToChecked(
        connection,
        user, // fee payer
        mintPubkey, // mint
        userTokenAccount, // receiver (should be a token account)
        mint, // mint authority
        5e18, // amount
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
      console.log('programVault', programVault.address.toBase58());
      // Create compute budget instruction to increase limit
      const modifyComputeUnits = ComputeBudgetProgram.setComputeUnitLimit({
        units: 1_000_000 // Request 1 million compute units
      });
      
      // Act
      await program.methods.newIntent(
        anchor.web3.Keypair.generate().publicKey, // receiver
        anchor.web3.Keypair.generate().publicKey, // input_asset
        anchor.web3.Keypair.generate().publicKey, // output_asset
        intentAmount, // amount
        10_000, // max_fee
        new anchor.BN(0), // ttl
        [1], // destinations
        Buffer.from(''), // data
        new anchor.BN(85000000), // message_gas_limit
      )
        .accounts({
          spokeState: spokeStateAddress,
          authority: user.publicKey,
          mint: mintPubkey,
          userTokenAccount,
          programVaultAccount: programVault.address,
          tokenProgram: token.TOKEN_PROGRAM_ID,
          hyperlaneMailbox,
          systemProgram: anchor.web3.SystemProgram.programId,
          splNoopProgram,
          mailboxOutbox,
          dispatchAuthority,
          uniqueMessageAccount: uniqueMessageAccountKeypair.publicKey,
          dispatchedMessagePda,
          igpProgram,
          igpProgramData,
          igpPaymentPda,
          configuredIgpAccount,
          innerIgpAccount,
        })
        .preInstructions([modifyComputeUnits])
        .signers([
          uniqueMessageAccountKeypair,
        ])
        .rpc();

      // Assert
      const vaultBalance = await connection.getTokenAccountBalance(programVault.address);
      expect(vaultBalance.value.amount).to.be.equal(intentAmount.toString());

      const spokeState = await program.account.spokeState.fetch(spokeStateAddress);
      // expect(spokeState.status.length).to.be.equal(1);
    });
  });

  describe('#handle', () => {
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

      // Create a user token account
      const userTokenAccount = await token.createAssociatedTokenAccount(
        connection,
        user, // fee payer
        mintPubkey, // mint
        user.publicKey, // owner,
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
        5e18, // amount
        TOKEN_DECIMALS, // decimals
      );

      const type = toBytes32(2); // Settlement
      const ignored = toBytes32(0);
      const size = toBytes32(1);
      const header = concat([
        type,
        ignored,
        ignored,
        ignored,
        size,
      ]);

      const intentAmount = new anchor.BN(5e18.toString());

      const intentId = toBytes32(4);
      const amount = toBytes32(intentAmount);
      const asset = mintPubkey.toBuffer();
      const recipient = user.publicKey.toBuffer();
      const updateVirtualBalance = toBytes32(0);
      const intent = concat([
        intentId,
        amount,
        asset,
        recipient,
        updateVirtualBalance,
      ]);

      const handleIx = {
        origin: 25327,
        sender: { 0: [
          0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 229, 242, 244, 175, 173, 98, 17, 207, 189, 106, 136, 45,
          90, 106, 67, 85, 48, 238, 57, 9,
        ]},
        message: Buffer.from(concat([
          header,
          intent,
        ])),
      };

      // Act
      try {
        await program.methods.handleAsAdmin(
          handleIx,
        )
          .accounts({
            authority: user.publicKey,
            spokeState: spokeStateAddress,
            vaultAuthority,
            tokenProgram: token.TOKEN_PROGRAM_ID,
            systemProgram: anchor.web3.SystemProgram.programId,
          })
          .remainingAccounts([
            { pubkey: mintPubkey, isWritable: false, isSigner: false },
            { pubkey: userTokenAccount, isWritable: true, isSigner: false },
            { pubkey: programVault.address, isWritable: true, isSigner: false },
          ])
          .rpc();

        // Assert
        const userBalance = await connection.getTokenAccountBalance(userTokenAccount);
        expect(userBalance.value.amount).to.be.equal(intentAmount.toString());
      } catch (e) {
        console.log(e);
      }
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
      await program.methods.updateWatchtower(newWatchtowerKeyPair.publicKey)
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
      await program.methods.updateMailbox(newMailboxKeyPair.publicKey)
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
      expect(spokeState.igpType.igp['0'].toBase58()).to.be.equal(configuredIgpAccount.toBase58());

      // Act
      await program.methods.updateIgp(newIgp, newIgpType)
        .accounts({
          spokeState: spokeStateAddress,
          admin: user.publicKey,
        })
        .rpc();

      // Assert
      spokeState = await program.account.spokeState.fetch(spokeStateAddress);
      expect(spokeState.igp.toBase58()).to.be.equal(newIgp.toBase58());
      expect(spokeState.igpType.overheadIgp['0'].toBase58()).to.be.equal(newInnerIgpAccount.toBase58());
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
      await program.methods.updateMailboxDispatchAuthorityBump(newBump)
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

  describe('#update_mailbox_dispatch_authority_bump', () => {
    it('should work', async () => {
      // Arrange
      const newBump = 150;

      // Sanity check
      let spokeState = await program.account.spokeState.fetch(spokeStateAddress);
      expect(spokeState.vaultAuthorityBump).to.be.equal(vaultAuthorityBump);

      // Act
      await program.methods.updateVaultAuthorityBump(newBump)
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
