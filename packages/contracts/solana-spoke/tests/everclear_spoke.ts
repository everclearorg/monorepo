import * as anchor from "@coral-xyz/anchor";
import { EverclearSpoke } from "../target/types/everclear_spoke";
import { expect } from "@chimera-monorepo/utils";

describe("#everclear_spoke", () => {
  anchor.setProvider(anchor.AnchorProvider.local());
  const program = anchor.workspace.EverclearSpoke as anchor.Program<EverclearSpoke>;

  describe("#initialize", () => {
    it("should work", async () => {
      const params = {
        domain: 1,
        hubDomain: 2,
        lighthouse: anchor.web3.Keypair.generate().publicKey,
        watchtower: anchor.web3.Keypair.generate().publicKey,
        callExecutor: anchor.web3.Keypair.generate().publicKey,
        messageReceiver: anchor.web3.Keypair.generate().publicKey,
        gateway: anchor.web3.Keypair.generate().publicKey,
        messageGasLimit: new anchor.BN(100),
        owner: anchor.web3.Keypair.generate().publicKey,
      };

      const txSig = await program.methods.initialize(params).rpc();
      expect(txSig).to.exist;
    });
  });
});
