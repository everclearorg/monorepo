import * as anchor from "@coral-xyz/anchor";
import { EverclearSpoke } from "../target/types/everclear_spoke";
import { expect } from "@chimera-monorepo/utils";

describe("#everclear_spoke", () => {
  anchor.setProvider(anchor.AnchorProvider.local());
  const program = anchor.workspace.EverclearSpoke as anchor.Program<EverclearSpoke>;
  const [spokeStateAddress, _] = anchor.web3.PublicKey.findProgramAddressSync([Buffer.from('spoke-state')], program.programId);

  const lighthouseKeyPair = anchor.web3.Keypair.generate();
  const watchtowerKeyPair = anchor.web3.Keypair.generate();
  const gatewayKeyPair = anchor.web3.Keypair.generate();
  const mailboxKeyPair = anchor.web3.Keypair.generate();
  const ownerKeyPair = anchor.web3.Keypair.generate();
  const initialMessageGasLimit = new anchor.BN(10000);

  describe("#initialize", () => {
    it("should work", async () => {
      // Arrange
      const params = {
        domain: 1,
        hubDomain: 2,
        lighthouse: lighthouseKeyPair.publicKey,
        watchtower: watchtowerKeyPair.publicKey,
        callExecutor: anchor.web3.Keypair.generate().publicKey,
        messageReceiver: anchor.web3.Keypair.generate().publicKey,
        gateway: gatewayKeyPair.publicKey,
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
      expect(spokeState.gateway.toBase58()).to.be.equal(gatewayKeyPair.publicKey.toBase58());
      expect(spokeState.messageGasLimit.toString()).to.be.equal(params.messageGasLimit.toString());
      expect(spokeState.owner.toBase58()).to.be.equal(ownerKeyPair.publicKey.toBase58());
      expect(spokeState.mailbox.toBase58()).to.be.equal(mailboxKeyPair.publicKey.toBase58());
      expect(spokeState.nonce.toString()).to.be.equal(new anchor.BN(0).toString());
      expect(spokeState.status).to.be.empty;
    });
  });

  describe("#pause", () => {
    it("should work", async () => {
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

  describe("#unpause", () => {
    it("should work", async () => {
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

  describe("#update_gateway", () => {
    it("should work", async () => {
      // Arrange
      const newGatewayKeyPair = anchor.web3.Keypair.generate();

      // Sanity check
      let spokeState = await program.account.spokeState.fetch(spokeStateAddress);
      expect(spokeState.gateway.toBase58()).to.be.equal(gatewayKeyPair.publicKey.toBase58());

      // Act
      await program.methods.updateGateway(newGatewayKeyPair.publicKey)
        .accounts({
          spokeState: spokeStateAddress,
          admin: ownerKeyPair.publicKey,
        })
        .signers([ownerKeyPair])
        .rpc();

      // Assert
      spokeState = await program.account.spokeState.fetch(spokeStateAddress);
      expect(spokeState.gateway.toBase58()).to.be.equal(newGatewayKeyPair.publicKey.toBase58());
    });
  });

  describe("#update_lighthouse", () => {
    it("should work", async () => {
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

  describe("#update_watchtower", () => {
    it("should work", async () => {
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

  describe("#update_mailbox", () => {
    it("should work", async () => {
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

  describe("#update_message_gas_limit", () => {
    it("should work", async () => {
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
