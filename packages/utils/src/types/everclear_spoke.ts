/**
 * Program IDL in camelCase format in order to be used in JS/TS.
 *
 * Note that this is only a type helper and is not the actual IDL. The original
 * IDL can be found at `target/idl/everclear_spoke.json`.
 */
export type EverclearSpoke = {
  address: 'everUnMiUkvZG8EyXAtW8HfMavCBTVeMhQszbrtpUQm';
  metadata: {
    name: 'everclearSpoke';
    version: '0.1.0';
    spec: '0.1.0';
    description: 'Created with Anchor';
  };
  instructions: [
    {
      name: 'handle';
      docs: [
        'Receive a cross‑chain message via Hyperlane.',
        "In production, this would be invoked via CPI from Hyperlane's Mailbox.",
      ];
      discriminator: [33, 210, 5, 66, 196, 212, 239, 142];
      accounts: [
        {
          name: 'authority';
          signer: true;
        },
        {
          name: 'spokeState';
          pda: {
            seeds: [
              {
                kind: 'const';
                value: [115, 112, 111, 107, 101, 45, 115, 116, 97, 116, 101];
              },
            ];
          };
        },
        {
          name: 'intentStatusPda';
          writable: true;
        },
        {
          name: 'systemProgram';
          address: '11111111111111111111111111111111';
        },
        {
          name: 'pdaPayer';
          writable: true;
          pda: {
            seeds: [
              {
                kind: 'const';
                value: [101, 118, 101, 114, 99, 108, 101, 97, 114, 95, 115, 112, 111, 107, 101];
              },
              {
                kind: 'const';
                value: [45];
              },
              {
                kind: 'const';
                value: [112, 100, 97, 95, 112, 97, 121, 101, 114];
              },
            ];
          };
        },
        {
          name: 'eventAuthority';
          pda: {
            seeds: [
              {
                kind: 'const';
                value: [95, 95, 101, 118, 101, 110, 116, 95, 97, 117, 116, 104, 111, 114, 105, 116, 121];
              },
            ];
          };
        },
        {
          name: 'program';
        },
      ];
      args: [
        {
          name: 'handle';
          type: {
            defined: {
              name: 'handleInstruction';
            };
          };
        },
      ];
    },
    {
      name: 'handleAccountMetas';
      discriminator: [194, 141, 30, 82, 241, 41, 169, 52];
      accounts: [
        {
          name: 'accountMetasPda';
          docs: [
            'ref: https://github.com/hyperlane-xyz/hyperlane-monorepo/blob/48b8508af42061d67cf46a3377e4569feb95d1d8/rust/main/chains/hyperlane-sealevel/src/mailbox.rs#L267',
          ];
        },
      ];
      args: [
        {
          name: 'handle';
          type: {
            defined: {
              name: 'handleInstruction';
            };
          };
        },
      ];
      returns: {
        defined: {
          name: 'simulationReturnData';
          generics: [
            {
              kind: 'type';
              type: {
                vec: {
                  defined: {
                    name: 'serializableAccountMeta';
                  };
                };
              };
            },
          ];
        };
      };
    },
    {
      name: 'handleAsAdmin';
      discriminator: [85, 72, 192, 28, 239, 150, 131, 187];
      accounts: [
        {
          name: 'authority';
          signer: true;
        },
        {
          name: 'spokeState';
          pda: {
            seeds: [
              {
                kind: 'const';
                value: [115, 112, 111, 107, 101, 45, 115, 116, 97, 116, 101];
              },
            ];
          };
        },
        {
          name: 'intentStatusPda';
          writable: true;
        },
        {
          name: 'systemProgram';
          address: '11111111111111111111111111111111';
        },
        {
          name: 'pdaPayer';
          writable: true;
          pda: {
            seeds: [
              {
                kind: 'const';
                value: [101, 118, 101, 114, 99, 108, 101, 97, 114, 95, 115, 112, 111, 107, 101];
              },
              {
                kind: 'const';
                value: [45];
              },
              {
                kind: 'const';
                value: [112, 100, 97, 95, 112, 97, 121, 101, 114];
              },
            ];
          };
        },
        {
          name: 'eventAuthority';
          pda: {
            seeds: [
              {
                kind: 'const';
                value: [95, 95, 101, 118, 101, 110, 116, 95, 97, 117, 116, 104, 111, 114, 105, 116, 121];
              },
            ];
          };
        },
        {
          name: 'program';
        },
      ];
      args: [
        {
          name: 'handle';
          type: {
            defined: {
              name: 'handleInstruction';
            };
          };
        },
      ];
    },
    {
      name: 'initialize';
      docs: ['Initialize the global state.', 'This function creates the SpokeState (global config) PDA.'];
      discriminator: [175, 175, 109, 31, 13, 152, 155, 237];
      accounts: [
        {
          name: 'spokeState';
          writable: true;
          pda: {
            seeds: [
              {
                kind: 'const';
                value: [115, 112, 111, 107, 101, 45, 115, 116, 97, 116, 101];
              },
            ];
          };
        },
        {
          name: 'payer';
          writable: true;
          signer: true;
        },
        {
          name: 'systemProgram';
          address: '11111111111111111111111111111111';
        },
        {
          name: 'eventAuthority';
          pda: {
            seeds: [
              {
                kind: 'const';
                value: [95, 95, 101, 118, 101, 110, 116, 95, 97, 117, 116, 104, 111, 114, 105, 116, 121];
              },
            ];
          };
        },
        {
          name: 'program';
        },
      ];
      args: [
        {
          name: 'init';
          type: {
            defined: {
              name: 'spokeInitializationParams';
            };
          };
        },
      ];
    },
    {
      name: 'interchainSecurityModule';
      discriminator: [45, 18, 245, 87, 234, 46, 246, 15];
      accounts: [];
      args: [];
    },
    {
      name: 'interchainSecurityModuleAccountMetas';
      discriminator: [190, 214, 218, 129, 67, 97, 4, 76];
      accounts: [];
      args: [];
      returns: {
        defined: {
          name: 'simulationReturnData';
          generics: [
            {
              kind: 'type';
              type: {
                vec: {
                  defined: {
                    name: 'serializableAccountMeta';
                  };
                };
              };
            },
          ];
        };
      };
    },
    {
      name: 'newIntent';
      docs: [
        'Create a new intent.',
        'The user "locks" funds (previously deposited) and creates an intent.',
        'For simplicity, we assume full deposit has been made before.',
      ];
      discriminator: [157, 204, 58, 235, 252, 199, 95, 123];
      accounts: [
        {
          name: 'spokeState';
          writable: true;
          pda: {
            seeds: [
              {
                kind: 'const';
                value: [115, 112, 111, 107, 101, 45, 115, 116, 97, 116, 101];
              },
            ];
          };
        },
        {
          name: 'authority';
          writable: true;
          signer: true;
        },
        {
          name: 'mint';
        },
        {
          name: 'userTokenAccount';
          writable: true;
        },
        {
          name: 'programVaultAccount';
          writable: true;
        },
        {
          name: 'tokenProgram';
          address: 'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA';
        },
        {
          name: 'hyperlaneMailbox';
        },
        {
          name: 'systemProgram';
          address: '11111111111111111111111111111111';
        },
        {
          name: 'splNoopProgram';
          address: 'noopb9bkMVfRPU8AsbpTUg8AQkHtKwMYZiFUjNRtMmV';
        },
        {
          name: 'mailboxOutbox';
          writable: true;
        },
        {
          name: 'dispatchAuthority';
          writable: true;
        },
        {
          name: 'uniqueMessageAccount';
          writable: true;
          signer: true;
        },
        {
          name: 'dispatchedMessagePda';
          writable: true;
        },
        {
          name: 'igpProgram';
        },
        {
          name: 'igpProgramData';
          writable: true;
        },
        {
          name: 'igpPaymentPda';
          writable: true;
        },
        {
          name: 'configuredIgpAccount';
          writable: true;
        },
        {
          name: 'innerIgpAccount';
          writable: true;
          optional: true;
        },
        {
          name: 'eventAuthority';
          pda: {
            seeds: [
              {
                kind: 'const';
                value: [95, 95, 101, 118, 101, 110, 116, 95, 97, 117, 116, 104, 111, 114, 105, 116, 121];
              },
            ];
          };
        },
        {
          name: 'program';
        },
      ];
      args: [
        {
          name: 'receiver';
          type: 'pubkey';
        },
        {
          name: 'inputAsset';
          type: 'pubkey';
        },
        {
          name: 'outputAsset';
          type: 'pubkey';
        },
        {
          name: 'amount';
          type: 'u64';
        },
        {
          name: 'maxFee';
          type: 'u32';
        },
        {
          name: 'ttl';
          type: 'u64';
        },
        {
          name: 'destinations';
          type: {
            vec: 'u32';
          };
        },
        {
          name: 'data';
          type: 'bytes';
        },
        {
          name: 'messageGasLimit';
          type: 'u64';
        },
      ];
    },
    {
      name: 'pause';
      docs: ['Pause the program.', 'Only the lighthouse or watchtower can call this.'];
      discriminator: [211, 22, 221, 251, 74, 121, 193, 47];
      accounts: [
        {
          name: 'spokeState';
          writable: true;
        },
        {
          name: 'admin';
          signer: true;
        },
        {
          name: 'eventAuthority';
          pda: {
            seeds: [
              {
                kind: 'const';
                value: [95, 95, 101, 118, 101, 110, 116, 95, 97, 117, 116, 104, 111, 114, 105, 116, 121];
              },
            ];
          };
        },
        {
          name: 'program';
        },
      ];
      args: [];
    },
    {
      name: 'settleDeliveredIntent';
      discriminator: [106, 187, 207, 145, 6, 174, 89, 217];
      accounts: [
        {
          name: 'authority';
          writable: true;
          signer: true;
        },
        {
          name: 'spokeState';
        },
        {
          name: 'intentStatusPda';
          writable: true;
        },
        {
          name: 'vaultAuthority';
        },
        {
          name: 'tokenProgram';
          address: 'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA';
        },
        {
          name: 'systemProgram';
          address: '11111111111111111111111111111111';
        },
        {
          name: 'mintAccount';
        },
        {
          name: 'associatedTokenProgram';
          address: 'ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL';
        },
        {
          name: 'recipient';
        },
        {
          name: 'recipientTokenAccount';
          writable: true;
        },
        {
          name: 'vaultTokenAccount';
          writable: true;
        },
        {
          name: 'eventAuthority';
          pda: {
            seeds: [
              {
                kind: 'const';
                value: [95, 95, 101, 118, 101, 110, 116, 95, 97, 117, 116, 104, 111, 114, 105, 116, 121];
              },
            ];
          };
        },
        {
          name: 'program';
        },
      ];
      args: [
        {
          name: 'settleDeliveredIntent';
          type: {
            defined: {
              name: 'settleDeliveredIntentInstruction';
            };
          };
        },
      ];
    },
    {
      name: 'unpause';
      docs: ['Unpause the program.'];
      discriminator: [169, 144, 4, 38, 10, 141, 188, 255];
      accounts: [
        {
          name: 'spokeState';
          writable: true;
        },
        {
          name: 'admin';
          signer: true;
        },
        {
          name: 'eventAuthority';
          pda: {
            seeds: [
              {
                kind: 'const';
                value: [95, 95, 101, 118, 101, 110, 116, 95, 97, 117, 116, 104, 111, 114, 105, 116, 121];
              },
            ];
          };
        },
        {
          name: 'program';
        },
      ];
      args: [];
    },
    {
      name: 'updateIgp';
      docs: [
        'new_igp contains the IGP address',
        'new_igp_type contains either the IGP address (as in new_igp), or the overhead IGP address if the IGP is an overhead IGP.',
      ];
      discriminator: [228, 15, 51, 100, 221, 15, 217, 59];
      accounts: [
        {
          name: 'spokeState';
          writable: true;
        },
        {
          name: 'admin';
          signer: true;
        },
        {
          name: 'eventAuthority';
          pda: {
            seeds: [
              {
                kind: 'const';
                value: [95, 95, 101, 118, 101, 110, 116, 95, 97, 117, 116, 104, 111, 114, 105, 116, 121];
              },
            ];
          };
        },
        {
          name: 'program';
        },
      ];
      args: [
        {
          name: 'newIgp';
          type: 'pubkey';
        },
        {
          name: 'newIgpType';
          type: {
            defined: {
              name: 'interchainGasPaymasterType';
            };
          };
        },
      ];
    },
    {
      name: 'updateLighthouse';
      discriminator: [51, 13, 101, 249, 40, 209, 254, 17];
      accounts: [
        {
          name: 'spokeState';
          writable: true;
        },
        {
          name: 'admin';
          signer: true;
        },
        {
          name: 'eventAuthority';
          pda: {
            seeds: [
              {
                kind: 'const';
                value: [95, 95, 101, 118, 101, 110, 116, 95, 97, 117, 116, 104, 111, 114, 105, 116, 121];
              },
            ];
          };
        },
        {
          name: 'program';
        },
      ];
      args: [
        {
          name: 'newLighthouse';
          type: 'pubkey';
        },
      ];
    },
    {
      name: 'updateMailbox';
      discriminator: [213, 10, 94, 69, 72, 226, 161, 204];
      accounts: [
        {
          name: 'spokeState';
          writable: true;
        },
        {
          name: 'admin';
          signer: true;
        },
        {
          name: 'eventAuthority';
          pda: {
            seeds: [
              {
                kind: 'const';
                value: [95, 95, 101, 118, 101, 110, 116, 95, 97, 117, 116, 104, 111, 114, 105, 116, 121];
              },
            ];
          };
        },
        {
          name: 'program';
        },
      ];
      args: [
        {
          name: 'newMailbox';
          type: 'pubkey';
        },
      ];
    },
    {
      name: 'updateMailboxDispatchAuthorityBump';
      discriminator: [99, 54, 179, 125, 118, 161, 99, 5];
      accounts: [
        {
          name: 'spokeState';
          writable: true;
        },
        {
          name: 'admin';
          signer: true;
        },
        {
          name: 'eventAuthority';
          pda: {
            seeds: [
              {
                kind: 'const';
                value: [95, 95, 101, 118, 101, 110, 116, 95, 97, 117, 116, 104, 111, 114, 105, 116, 121];
              },
            ];
          };
        },
        {
          name: 'program';
        },
      ];
      args: [
        {
          name: 'newBump';
          type: 'u8';
        },
      ];
    },
    {
      name: 'updateMessageGasLimit';
      discriminator: [95, 171, 202, 222, 76, 224, 79, 19];
      accounts: [
        {
          name: 'spokeState';
          writable: true;
        },
        {
          name: 'admin';
          signer: true;
        },
        {
          name: 'eventAuthority';
          pda: {
            seeds: [
              {
                kind: 'const';
                value: [95, 95, 101, 118, 101, 110, 116, 95, 97, 117, 116, 104, 111, 114, 105, 116, 121];
              },
            ];
          };
        },
        {
          name: 'program';
        },
      ];
      args: [
        {
          name: 'newLimit';
          type: 'u64';
        },
      ];
    },
    {
      name: 'updateVaultAuthorityBump';
      discriminator: [124, 42, 9, 237, 19, 224, 189, 190];
      accounts: [
        {
          name: 'spokeState';
          writable: true;
        },
        {
          name: 'admin';
          signer: true;
        },
        {
          name: 'eventAuthority';
          pda: {
            seeds: [
              {
                kind: 'const';
                value: [95, 95, 101, 118, 101, 110, 116, 95, 97, 117, 116, 104, 111, 114, 105, 116, 121];
              },
            ];
          };
        },
        {
          name: 'program';
        },
      ];
      args: [
        {
          name: 'newBump';
          type: 'u8';
        },
      ];
    },
    {
      name: 'updateWatchtower';
      discriminator: [146, 49, 28, 59, 251, 130, 217, 207];
      accounts: [
        {
          name: 'spokeState';
          writable: true;
        },
        {
          name: 'admin';
          signer: true;
        },
        {
          name: 'eventAuthority';
          pda: {
            seeds: [
              {
                kind: 'const';
                value: [95, 95, 101, 118, 101, 110, 116, 95, 97, 117, 116, 104, 111, 114, 105, 116, 121];
              },
            ];
          };
        },
        {
          name: 'program';
        },
      ];
      args: [
        {
          name: 'newWatchtower';
          type: 'pubkey';
        },
      ];
    },
  ];
  accounts: [
    {
      name: 'intentStatusAccount';
      discriminator: [31, 58, 221, 56, 60, 126, 214, 23];
    },
    {
      name: 'spokeState';
      discriminator: [203, 210, 244, 16, 167, 13, 229, 82];
    },
  ];
  events: [
    {
      name: 'igpUpdatedEvent';
      discriminator: [117, 50, 157, 103, 151, 162, 142, 136];
    },
    {
      name: 'initializedEvent';
      discriminator: [136, 202, 63, 120, 152, 146, 41, 79];
    },
    {
      name: 'intentAddedEvent';
      discriminator: [18, 99, 228, 90, 86, 91, 49, 93];
    },
    {
      name: 'lighthouseUpdatedEvent';
      discriminator: [76, 188, 81, 137, 120, 178, 82, 45];
    },
    {
      name: 'mailboxDispatchAuthorityBumpUpdatedEvent';
      discriminator: [136, 254, 105, 103, 87, 8, 242, 12];
    },
    {
      name: 'mailboxUpdatedEvent';
      discriminator: [6, 80, 174, 219, 230, 25, 176, 6];
    },
    {
      name: 'messageDeliveredEvent';
      discriminator: [170, 221, 81, 222, 188, 71, 22, 47];
    },
    {
      name: 'messageGasLimitUpdatedEvent';
      discriminator: [47, 54, 237, 179, 148, 197, 0, 141];
    },
    {
      name: 'messageReceivedEvent';
      discriminator: [232, 67, 17, 7, 89, 91, 17, 69];
    },
    {
      name: 'pausedEvent';
      discriminator: [43, 14, 250, 236, 116, 42, 177, 89];
    },
    {
      name: 'settledEvent';
      discriminator: [117, 207, 196, 174, 197, 200, 11, 67];
    },
    {
      name: 'unpausedEvent';
      discriminator: [150, 198, 191, 67, 103, 86, 160, 55];
    },
    {
      name: 'vaultAuthorityBumpUpdatedEvent';
      discriminator: [88, 55, 123, 0, 203, 140, 231, 153];
    },
    {
      name: 'watchtowerUpdatedEvent';
      discriminator: [78, 128, 124, 179, 254, 219, 127, 3];
    },
  ];
  errors: [
    {
      code: 6000;
      name: 'onlyOwner';
      msg: 'Only the contract owner can call this method.';
    },
    {
      code: 6001;
      name: 'notAuthorizedToPause';
      msg: 'Not authorized to pause.';
    },
    {
      code: 6002;
      name: 'contractPaused';
      msg: 'Contract is paused.';
    },
    {
      code: 6003;
      name: 'invalidAmount';
      msg: 'Invalid amount provided.';
    },
    {
      code: 6004;
      name: 'invalidOperation';
      msg: 'Invalid operation or overflow.';
    },
    {
      code: 6005;
      name: 'intentNotFound';
      msg: 'Intent not found.';
    },
    {
      code: 6006;
      name: 'invalidIntentStatus';
      msg: 'Intent is in an invalid status for this operation.';
    },
    {
      code: 6007;
      name: 'maxFeeExceeded';
      msg: 'Max fee exceeded.';
    },
    {
      code: 6008;
      name: 'invalidOrigin';
      msg: 'Invalid origin for inbound message.';
    },
    {
      code: 6009;
      name: 'invalidSender';
      msg: 'Invalid sender for inbound message.';
    },
    {
      code: 6010;
      name: 'invalidMessage';
      msg: 'Invalid or unknown message.';
    },
    {
      code: 6011;
      name: 'unauthorized';
      msg: 'Unauthorized operation.';
    },
    {
      code: 6012;
      name: 'signatureExpired';
      msg: 'Signature has expired';
    },
    {
      code: 6013;
      name: 'invalidSignature';
      msg: 'Invalid signature';
    },
    {
      code: 6014;
      name: 'zeroAmount';
      msg: 'Zero amount provided';
    },
    {
      code: 6015;
      name: 'decimalConversionOverflow';
      msg: 'Decimal conversion overflow';
    },
    {
      code: 6016;
      name: 'alreadyInitialized';
      msg: 'Already initialized';
    },
    {
      code: 6017;
      name: 'invalidOwner';
      msg: 'Invalid Owner';
    },
    {
      code: 6018;
      name: 'invalidVarUpdate';
      msg: 'Invalid var update';
    },
    {
      code: 6019;
      name: 'invalidIntent';
      msg: 'Invalid intent';
    },
    {
      code: 6020;
      name: 'overflow';
      msg: 'overflow';
    },
    {
      code: 6021;
      name: 'invalidAccount';
      msg: 'Invalid account meta';
    },
    {
      code: 6022;
      name: 'invalidArgument';
      msg: 'Invalid argument data';
    },
    {
      code: 6023;
      name: 'incorrectProgramId';
      msg: 'Incorrect program id';
    },
    {
      code: 6024;
      name: 'missingRequiredSignature';
      msg: 'Missing required signature';
    },
    {
      code: 6025;
      name: 'extraneousAccount';
      msg: 'Extraneous account';
    },
    {
      code: 6026;
      name: 'integerOverflow';
      msg: 'Overflowing Integer';
    },
    {
      code: 6027;
      name: 'invalidSeeds';
      msg: 'Invalid seeds for deriving pda';
    },
    {
      code: 6028;
      name: 'invalidVaultAccount';
      msg: 'Invalid vault account';
    },
    {
      code: 6029;
      name: 'invalidIntentPda';
      msg: 'Invalid intent pda';
    },
    {
      code: 6030;
      name: 'invalidSettlementSize';
      msg: 'Invalid settlement size';
    },
    {
      code: 6031;
      name: 'incorrectSettlementAccounts';
      msg: 'Incorrect settlement accounts, mismatch with intent PDA.';
    },
    {
      code: 6032;
      name: 'invalidIntentId';
      msg: 'Invalid intent id';
    },
  ];
  types: [
    {
      name: 'h256';
      docs: ['256-bit hash type.'];
      repr: {
        kind: 'c';
      };
      type: {
        kind: 'struct';
        fields: [
          {
            array: ['u8', 32];
          },
        ];
      };
    },
    {
      name: 'handleInstruction';
      type: {
        kind: 'struct';
        fields: [
          {
            name: 'origin';
            type: 'u32';
          },
          {
            name: 'sender';
            type: {
              defined: {
                name: 'h256';
              };
            };
          },
          {
            name: 'message';
            type: 'bytes';
          },
        ];
      };
    },
    {
      name: 'igpUpdatedEvent';
      type: {
        kind: 'struct';
        fields: [
          {
            name: 'oldIgp';
            type: 'pubkey';
          },
          {
            name: 'newIgp';
            type: 'pubkey';
          },
          {
            name: 'oldIgpType';
            type: {
              defined: {
                name: 'interchainGasPaymasterType';
              };
            };
          },
          {
            name: 'newIgpType';
            type: {
              defined: {
                name: 'interchainGasPaymasterType';
              };
            };
          },
        ];
      };
    },
    {
      name: 'initializedEvent';
      type: {
        kind: 'struct';
        fields: [
          {
            name: 'owner';
            type: 'pubkey';
          },
          {
            name: 'domain';
            type: 'u32';
          },
          {
            name: 'everclear';
            type: 'u32';
          },
        ];
      };
    },
    {
      name: 'intentAddedEvent';
      type: {
        kind: 'struct';
        fields: [
          {
            name: 'intentId';
            type: {
              array: ['u8', 32];
            };
          },
          {
            name: 'messageId';
            type: {
              array: ['u8', 32];
            };
          },
          {
            name: 'initiator';
            type: 'pubkey';
          },
          {
            name: 'receiver';
            type: 'pubkey';
          },
          {
            name: 'inputAsset';
            type: 'pubkey';
          },
          {
            name: 'outputAsset';
            type: 'pubkey';
          },
          {
            name: 'normalizedAmount';
            type: 'u128';
          },
          {
            name: 'maxFee';
            type: 'u32';
          },
          {
            name: 'originDomain';
            type: 'u32';
          },
          {
            name: 'nonce';
            type: 'u64';
          },
          {
            name: 'ttl';
            type: 'u64';
          },
          {
            name: 'timestamp';
            type: 'u64';
          },
          {
            name: 'destinations';
            type: {
              vec: 'u32';
            };
          },
          {
            name: 'data';
            type: 'bytes';
          },
        ];
      };
    },
    {
      name: 'intentStatus';
      docs: ['Intent status.'];
      type: {
        kind: 'enum';
        variants: [
          {
            name: 'none';
          },
          {
            name: 'added';
          },
          {
            name: 'filled';
          },
          {
            name: 'settled';
          },
          {
            name: 'settledAndManuallyExecuted';
          },
          {
            name: 'delivered';
          },
        ];
      };
    },
    {
      name: 'intentStatusAccount';
      type: {
        kind: 'struct';
        fields: [
          {
            name: 'status';
            type: {
              defined: {
                name: 'intentStatus';
              };
            };
          },
          {
            name: 'accounts';
            type: {
              vec: {
                defined: {
                  name: 'serializableAccountMeta';
                };
              };
            };
          },
          {
            name: 'settlement';
            type: {
              option: {
                defined: {
                  name: 'settlement';
                };
              };
            };
          },
        ];
      };
    },
    {
      name: 'interchainGasPaymasterType';
      type: {
        kind: 'enum';
        variants: [
          {
            name: 'igp';
            fields: ['pubkey'];
          },
          {
            name: 'overheadIgp';
            fields: ['pubkey'];
          },
        ];
      };
    },
    {
      name: 'lighthouseUpdatedEvent';
      type: {
        kind: 'struct';
        fields: [
          {
            name: 'oldLighthouse';
            type: 'pubkey';
          },
          {
            name: 'newLighthouse';
            type: 'pubkey';
          },
        ];
      };
    },
    {
      name: 'mailboxDispatchAuthorityBumpUpdatedEvent';
      type: {
        kind: 'struct';
        fields: [
          {
            name: 'oldBump';
            type: 'u8';
          },
          {
            name: 'newBump';
            type: 'u8';
          },
        ];
      };
    },
    {
      name: 'mailboxUpdatedEvent';
      type: {
        kind: 'struct';
        fields: [
          {
            name: 'oldMailbox';
            type: 'pubkey';
          },
          {
            name: 'newMailbox';
            type: 'pubkey';
          },
        ];
      };
    },
    {
      name: 'messageDeliveredEvent';
      type: {
        kind: 'struct';
        fields: [
          {
            name: 'domain';
            type: 'u32';
          },
          {
            name: 'settlement';
            type: {
              defined: {
                name: 'settlement';
              };
            };
          },
          {
            name: 'accountMetas';
            type: {
              vec: {
                defined: {
                  name: 'serializableAccountMeta';
                };
              };
            };
          },
        ];
      };
    },
    {
      name: 'messageGasLimitUpdatedEvent';
      type: {
        kind: 'struct';
        fields: [
          {
            name: 'oldLimit';
            type: 'u64';
          },
          {
            name: 'newLimit';
            type: 'u64';
          },
        ];
      };
    },
    {
      name: 'messageReceivedEvent';
      type: {
        kind: 'struct';
        fields: [
          {
            name: 'origin';
            type: 'u32';
          },
          {
            name: 'sender';
            type: 'pubkey';
          },
        ];
      };
    },
    {
      name: 'pausedEvent';
      type: {
        kind: 'struct';
        fields: [];
      };
    },
    {
      name: 'serializableAccountMeta';
      docs: ['A borsh-serializable version of `AccountMeta`.'];
      type: {
        kind: 'struct';
        fields: [
          {
            name: 'pubkey';
            type: 'pubkey';
          },
          {
            name: 'isSigner';
            type: 'bool';
          },
          {
            name: 'isWritable';
            type: 'bool';
          },
        ];
      };
    },
    {
      name: 'settleDeliveredIntentInstruction';
      type: {
        kind: 'struct';
        fields: [
          {
            name: 'intentId';
            type: {
              array: ['u8', 32];
            };
          },
        ];
      };
    },
    {
      name: 'settledEvent';
      type: {
        kind: 'struct';
        fields: [
          {
            name: 'intentId';
            type: {
              array: ['u8', 32];
            };
          },
          {
            name: 'recipient';
            type: 'pubkey';
          },
          {
            name: 'asset';
            type: 'pubkey';
          },
          {
            name: 'amount';
            type: 'u64';
          },
          {
            name: 'domain';
            type: 'u32';
          },
        ];
      };
    },
    {
      name: 'settlement';
      type: {
        kind: 'struct';
        fields: [
          {
            name: 'intentId';
            type: {
              array: ['u8', 32];
            };
          },
          {
            name: 'amount';
            type: {
              defined: {
                name: 'u256';
              };
            };
          },
          {
            name: 'asset';
            type: 'pubkey';
          },
          {
            name: 'recipient';
            type: 'pubkey';
          },
          {
            name: 'updateVirtualBalance';
            type: 'bool';
          },
        ];
      };
    },
    {
      name: 'simulationReturnData';
      docs: [
        'NOTE: This is used for hyperlane interop only and should not be used anywhere else',
        'A ridiculous workaround for `<https://github.com/solana-labs/solana/issues/31391>`,',
        "which is a bug where if a simulated transaction's return data ends with zero byte(s),",
        'they end up being incorrectly truncated.',
        'As a workaround, we can (de)serialize data with a trailing non-zero byte.',
      ];
      generics: [
        {
          kind: 'type';
          name: 't';
        },
      ];
      type: {
        kind: 'struct';
        fields: [
          {
            name: 'returnData';
            type: {
              generic: 't';
            };
          },
          {
            name: 'trailingByte';
            type: 'u8';
          },
        ];
      };
    },
    {
      name: 'spokeInitializationParams';
      type: {
        kind: 'struct';
        fields: [
          {
            name: 'domain';
            type: 'u32';
          },
          {
            name: 'hubDomain';
            type: 'u32';
          },
          {
            name: 'lighthouse';
            type: 'pubkey';
          },
          {
            name: 'watchtower';
            type: 'pubkey';
          },
          {
            name: 'messageGasLimit';
            type: 'u64';
          },
          {
            name: 'owner';
            type: 'pubkey';
          },
          {
            name: 'mailbox';
            type: 'pubkey';
          },
          {
            name: 'igp';
            type: 'pubkey';
          },
          {
            name: 'igpType';
            type: {
              defined: {
                name: 'interchainGasPaymasterType';
              };
            };
          },
          {
            name: 'mailboxDispatchAuthorityBump';
            type: 'u8';
          },
          {
            name: 'vaultAuthorityBump';
            type: 'u8';
          },
        ];
      };
    },
    {
      name: 'spokeState';
      docs: ['SpokeState – global configuration.'];
      type: {
        kind: 'struct';
        fields: [
          {
            name: 'initializedVersion';
            type: 'u8';
          },
          {
            name: 'paused';
            type: 'bool';
          },
          {
            name: 'domain';
            type: 'u32';
          },
          {
            name: 'everclear';
            type: 'u32';
          },
          {
            name: 'lighthouse';
            type: 'pubkey';
          },
          {
            name: 'watchtower';
            type: 'pubkey';
          },
          {
            name: 'messageGasLimit';
            type: 'u64';
          },
          {
            name: 'nonce';
            type: 'u64';
          },
          {
            name: 'owner';
            type: 'pubkey';
          },
          {
            name: 'bump';
            type: 'u8';
          },
          {
            name: 'mailbox';
            type: 'pubkey';
          },
          {
            name: 'mailboxDispatchAuthorityBump';
            type: 'u8';
          },
          {
            name: 'igp';
            type: 'pubkey';
          },
          {
            name: 'igpType';
            type: {
              defined: {
                name: 'interchainGasPaymasterType';
              };
            };
          },
          {
            name: 'vaultAuthorityBump';
            type: 'u8';
          },
        ];
      };
    },
    {
      name: 'u256';
      docs: ['Little-endian large integer type', '256-bit unsigned integer.'];
      repr: {
        kind: 'c';
      };
      type: {
        kind: 'struct';
        fields: [
          {
            array: ['u64', 4];
          },
        ];
      };
    },
    {
      name: 'unpausedEvent';
      type: {
        kind: 'struct';
        fields: [];
      };
    },
    {
      name: 'vaultAuthorityBumpUpdatedEvent';
      type: {
        kind: 'struct';
        fields: [
          {
            name: 'oldBump';
            type: 'u8';
          },
          {
            name: 'newBump';
            type: 'u8';
          },
        ];
      };
    },
    {
      name: 'watchtowerUpdatedEvent';
      type: {
        kind: 'struct';
        fields: [
          {
            name: 'oldWatchtower';
            type: 'pubkey';
          },
          {
            name: 'newWatchtower';
            type: 'pubkey';
          },
        ];
      };
    },
  ];
};
