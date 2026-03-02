/**
 * Program IDL in camelCase format in order to be used in JS/TS.
 *
 * Note that this is only a type helper and is not the actual IDL. The original
 * IDL can be found at `target/idl/everclear_spoke.json`.
 */
export type EverclearSpoke = {
  "address": "Aw7BDNPNb5csVdskKaWnzX2rjQVKN1ak3tbSvXDz22rw",
  "metadata": {
    "name": "everclearSpoke",
    "version": "0.1.0",
    "spec": "0.1.0",
    "description": "Created with Anchor"
  },
  "instructions": [
    {
      "name": "ccipReceive",
      "docs": [
        "Receive a cross-chain message via CCIP.",
        "Called via CPI from CCIP OffRamp program."
      ],
      "discriminator": [
        11,
        244,
        9,
        249,
        44,
        83,
        47,
        245
      ],
      "accounts": [
        {
          "name": "authority",
          "signer": true,
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  101,
                  120,
                  116,
                  101,
                  114,
                  110,
                  97,
                  108,
                  95,
                  101,
                  120,
                  101,
                  99,
                  117,
                  116,
                  105,
                  111,
                  110,
                  95,
                  99,
                  111,
                  110,
                  102,
                  105,
                  103
                ]
              }
            ],
            "program": {
              "kind": "account",
              "path": "offrampProgram"
            }
          }
        },
        {
          "name": "offrampProgram"
        },
        {
          "name": "allowedOfframp",
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  97,
                  108,
                  108,
                  111,
                  119,
                  101,
                  100,
                  95,
                  111,
                  102,
                  102,
                  114,
                  97,
                  109,
                  112
                ]
              },
              {
                "kind": "arg",
                "path": "message.source_chain_selector"
              },
              {
                "kind": "account",
                "path": "offrampProgram"
              }
            ],
            "program": {
              "kind": "account",
              "path": "spoke_state.ccip_router",
              "account": "spokeState"
            }
          }
        },
        {
          "name": "externalExecutionConfig",
          "writable": true,
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  101,
                  120,
                  116,
                  101,
                  114,
                  110,
                  97,
                  108,
                  95,
                  101,
                  120,
                  101,
                  99,
                  117,
                  116,
                  105,
                  111,
                  110,
                  95,
                  99,
                  111,
                  110,
                  102,
                  105,
                  103
                ]
              }
            ]
          }
        },
        {
          "name": "spokeState",
          "writable": true,
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  115,
                  112,
                  111,
                  107,
                  101,
                  45,
                  115,
                  116,
                  97,
                  116,
                  101
                ]
              }
            ]
          }
        },
        {
          "name": "intentStatusPda",
          "writable": true
        },
        {
          "name": "systemProgram",
          "address": "11111111111111111111111111111111"
        },
        {
          "name": "pdaPayer",
          "writable": true,
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  101,
                  118,
                  101,
                  114,
                  99,
                  108,
                  101,
                  97,
                  114,
                  95,
                  115,
                  112,
                  111,
                  107,
                  101
                ]
              },
              {
                "kind": "const",
                "value": [
                  45
                ]
              },
              {
                "kind": "const",
                "value": [
                  112,
                  100,
                  97,
                  95,
                  112,
                  97,
                  121,
                  101,
                  114
                ]
              }
            ]
          }
        }
      ],
      "args": [
        {
          "name": "message",
          "type": {
            "defined": {
              "name": "any2SvmMessage"
            }
          }
        }
      ]
    },
    {
      "name": "fillIntent",
      "docs": [
        "Fills a new intent.",
        "The user \"locks\" funds (previously deposited) and fills an intent.",
        "NOTE: different from EVM, we do not support pullFunds, i.e. we requires funds to be sent during the tx",
        "and not deposited prior in the spoke."
      ],
      "discriminator": [
        68,
        255,
        62,
        77,
        155,
        136,
        145,
        148
      ],
      "accounts": [
        {
          "name": "spokeState",
          "writable": true,
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  115,
                  112,
                  111,
                  107,
                  101,
                  45,
                  115,
                  116,
                  97,
                  116,
                  101
                ]
              }
            ]
          }
        },
        {
          "name": "feeAdapterState",
          "writable": true,
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  102,
                  101,
                  101,
                  45,
                  97,
                  100,
                  97,
                  112,
                  116,
                  101,
                  114,
                  45,
                  115,
                  116,
                  97,
                  116,
                  101
                ]
              }
            ]
          }
        },
        {
          "name": "authority",
          "docs": [
            "NOTE: the message initiator, here its the filler."
          ],
          "writable": true,
          "signer": true
        },
        {
          "name": "originReceiver"
        },
        {
          "name": "mint"
        },
        {
          "name": "solverTokenAccount",
          "writable": true
        },
        {
          "name": "originReceiverTokenAccount",
          "writable": true,
          "pda": {
            "seeds": [
              {
                "kind": "account",
                "path": "originReceiver"
              },
              {
                "kind": "account",
                "path": "tokenProgram"
              },
              {
                "kind": "account",
                "path": "mint"
              }
            ],
            "program": {
              "kind": "const",
              "value": [
                140,
                151,
                37,
                143,
                78,
                36,
                137,
                241,
                187,
                61,
                16,
                41,
                20,
                142,
                13,
                131,
                11,
                90,
                19,
                153,
                218,
                255,
                16,
                132,
                4,
                142,
                123,
                216,
                219,
                233,
                248,
                89
              ]
            }
          }
        },
        {
          "name": "tokenProgram",
          "address": "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"
        },
        {
          "name": "intentStatusPda",
          "writable": true
        },
        {
          "name": "pdaPayer",
          "writable": true,
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  101,
                  118,
                  101,
                  114,
                  99,
                  108,
                  101,
                  97,
                  114,
                  95,
                  115,
                  112,
                  111,
                  107,
                  101
                ]
              },
              {
                "kind": "const",
                "value": [
                  45
                ]
              },
              {
                "kind": "const",
                "value": [
                  112,
                  100,
                  97,
                  95,
                  112,
                  97,
                  121,
                  101,
                  114
                ]
              }
            ]
          }
        },
        {
          "name": "hyperlaneMailbox"
        },
        {
          "name": "systemProgram",
          "address": "11111111111111111111111111111111"
        },
        {
          "name": "splNoopProgram",
          "address": "noopb9bkMVfRPU8AsbpTUg8AQkHtKwMYZiFUjNRtMmV"
        },
        {
          "name": "mailboxOutbox",
          "writable": true
        },
        {
          "name": "dispatchAuthority",
          "writable": true
        },
        {
          "name": "uniqueMessageAccount",
          "writable": true,
          "signer": true
        },
        {
          "name": "dispatchedMessagePda",
          "writable": true
        },
        {
          "name": "igpProgram"
        },
        {
          "name": "igpProgramData",
          "writable": true
        },
        {
          "name": "igpPaymentPda",
          "writable": true
        },
        {
          "name": "configuredIgpAccount",
          "writable": true
        },
        {
          "name": "signer"
        },
        {
          "name": "instructionSysvar",
          "address": "Sysvar1nstructions1111111111111111111111111"
        },
        {
          "name": "innerIgpAccount",
          "writable": true,
          "optional": true
        },
        {
          "name": "eventAuthority",
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  95,
                  95,
                  101,
                  118,
                  101,
                  110,
                  116,
                  95,
                  97,
                  117,
                  116,
                  104,
                  111,
                  114,
                  105,
                  116,
                  121
                ]
              }
            ]
          }
        },
        {
          "name": "program"
        }
      ],
      "args": [
        {
          "name": "originInitiator",
          "type": {
            "array": [
              "u8",
              32
            ]
          }
        },
        {
          "name": "originInputAsset",
          "type": {
            "array": [
              "u8",
              32
            ]
          }
        },
        {
          "name": "intentOrigin",
          "type": "u32"
        },
        {
          "name": "originNonce",
          "type": "u64"
        },
        {
          "name": "originTimestamp",
          "type": "u64"
        },
        {
          "name": "originTtl",
          "type": "u64"
        },
        {
          "name": "originAmount",
          "type": {
            "array": [
              "u8",
              32
            ]
          }
        },
        {
          "name": "originAmountOutMin",
          "type": {
            "array": [
              "u8",
              32
            ]
          }
        },
        {
          "name": "originDestinations",
          "type": {
            "vec": "u32"
          }
        },
        {
          "name": "originData",
          "type": "bytes"
        },
        {
          "name": "amountOut",
          "type": "u64"
        },
        {
          "name": "receiver",
          "type": "pubkey"
        },
        {
          "name": "destinations",
          "type": {
            "vec": "u32"
          }
        },
        {
          "name": "messageGasLimit",
          "type": "u64"
        },
        {
          "name": "signature",
          "type": "bytes"
        }
      ]
    },
    {
      "name": "handle",
      "docs": [
        "Receive a cross‑chain message via Hyperlane.",
        "In production, this would be invoked via CPI from Hyperlane's Mailbox."
      ],
      "discriminator": [
        33,
        210,
        5,
        66,
        196,
        212,
        239,
        142
      ],
      "accounts": [
        {
          "name": "authority",
          "signer": true
        },
        {
          "name": "spokeState",
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  115,
                  112,
                  111,
                  107,
                  101,
                  45,
                  115,
                  116,
                  97,
                  116,
                  101
                ]
              }
            ]
          }
        },
        {
          "name": "intentStatusPda",
          "writable": true
        },
        {
          "name": "systemProgram",
          "address": "11111111111111111111111111111111"
        },
        {
          "name": "pdaPayer",
          "writable": true,
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  101,
                  118,
                  101,
                  114,
                  99,
                  108,
                  101,
                  97,
                  114,
                  95,
                  115,
                  112,
                  111,
                  107,
                  101
                ]
              },
              {
                "kind": "const",
                "value": [
                  45
                ]
              },
              {
                "kind": "const",
                "value": [
                  112,
                  100,
                  97,
                  95,
                  112,
                  97,
                  121,
                  101,
                  114
                ]
              }
            ]
          }
        },
        {
          "name": "eventAuthority",
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  95,
                  95,
                  101,
                  118,
                  101,
                  110,
                  116,
                  95,
                  97,
                  117,
                  116,
                  104,
                  111,
                  114,
                  105,
                  116,
                  121
                ]
              }
            ]
          }
        },
        {
          "name": "program"
        }
      ],
      "args": [
        {
          "name": "handle",
          "type": {
            "defined": {
              "name": "handleInstruction"
            }
          }
        }
      ]
    },
    {
      "name": "handleAccountMetas",
      "discriminator": [
        194,
        141,
        30,
        82,
        241,
        41,
        169,
        52
      ],
      "accounts": [
        {
          "name": "accountMetasPda",
          "docs": [
            "ref: https://github.com/hyperlane-xyz/hyperlane-monorepo/blob/48b8508af42061d67cf46a3377e4569feb95d1d8/rust/main/chains/hyperlane-sealevel/src/mailbox.rs#L267"
          ]
        }
      ],
      "args": [
        {
          "name": "handle",
          "type": {
            "defined": {
              "name": "handleInstruction"
            }
          }
        }
      ],
      "returns": {
        "defined": {
          "name": "simulationReturnData",
          "generics": [
            {
              "kind": "type",
              "type": {
                "vec": {
                  "defined": {
                    "name": "serializableAccountMeta"
                  }
                }
              }
            }
          ]
        }
      }
    },
    {
      "name": "handleAsAdmin",
      "discriminator": [
        85,
        72,
        192,
        28,
        239,
        150,
        131,
        187
      ],
      "accounts": [
        {
          "name": "authority",
          "signer": true
        },
        {
          "name": "spokeState",
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  115,
                  112,
                  111,
                  107,
                  101,
                  45,
                  115,
                  116,
                  97,
                  116,
                  101
                ]
              }
            ]
          }
        },
        {
          "name": "intentStatusPda",
          "writable": true
        },
        {
          "name": "systemProgram",
          "address": "11111111111111111111111111111111"
        },
        {
          "name": "pdaPayer",
          "writable": true,
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  101,
                  118,
                  101,
                  114,
                  99,
                  108,
                  101,
                  97,
                  114,
                  95,
                  115,
                  112,
                  111,
                  107,
                  101
                ]
              },
              {
                "kind": "const",
                "value": [
                  45
                ]
              },
              {
                "kind": "const",
                "value": [
                  112,
                  100,
                  97,
                  95,
                  112,
                  97,
                  121,
                  101,
                  114
                ]
              }
            ]
          }
        },
        {
          "name": "eventAuthority",
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  95,
                  95,
                  101,
                  118,
                  101,
                  110,
                  116,
                  95,
                  97,
                  117,
                  116,
                  104,
                  111,
                  114,
                  105,
                  116,
                  121
                ]
              }
            ]
          }
        },
        {
          "name": "program"
        }
      ],
      "args": [
        {
          "name": "handle",
          "type": {
            "defined": {
              "name": "handleInstruction"
            }
          }
        }
      ]
    },
    {
      "name": "initialize",
      "docs": [
        "Initialize the global state.",
        "This function creates the SpokeState (global config) PDA."
      ],
      "discriminator": [
        175,
        175,
        109,
        31,
        13,
        152,
        155,
        237
      ],
      "accounts": [
        {
          "name": "spokeState",
          "writable": true,
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  115,
                  112,
                  111,
                  107,
                  101,
                  45,
                  115,
                  116,
                  97,
                  116,
                  101
                ]
              }
            ]
          }
        },
        {
          "name": "payer",
          "writable": true,
          "signer": true
        },
        {
          "name": "systemProgram",
          "address": "11111111111111111111111111111111"
        },
        {
          "name": "eventAuthority",
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  95,
                  95,
                  101,
                  118,
                  101,
                  110,
                  116,
                  95,
                  97,
                  117,
                  116,
                  104,
                  111,
                  114,
                  105,
                  116,
                  121
                ]
              }
            ]
          }
        },
        {
          "name": "program"
        }
      ],
      "args": [
        {
          "name": "init",
          "type": {
            "defined": {
              "name": "spokeInitializationParams"
            }
          }
        }
      ]
    },
    {
      "name": "initializeFeeAdapter",
      "discriminator": [
        188,
        187,
        33,
        55,
        168,
        179,
        246,
        25
      ],
      "accounts": [
        {
          "name": "spokeState",
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  115,
                  112,
                  111,
                  107,
                  101,
                  45,
                  115,
                  116,
                  97,
                  116,
                  101
                ]
              }
            ]
          }
        },
        {
          "name": "feeAdapterState",
          "writable": true,
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  102,
                  101,
                  101,
                  45,
                  97,
                  100,
                  97,
                  112,
                  116,
                  101,
                  114,
                  45,
                  115,
                  116,
                  97,
                  116,
                  101
                ]
              }
            ]
          }
        },
        {
          "name": "payer",
          "writable": true,
          "signer": true
        },
        {
          "name": "systemProgram",
          "address": "11111111111111111111111111111111"
        },
        {
          "name": "eventAuthority",
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  95,
                  95,
                  101,
                  118,
                  101,
                  110,
                  116,
                  95,
                  97,
                  117,
                  116,
                  104,
                  111,
                  114,
                  105,
                  116,
                  121
                ]
              }
            ]
          }
        },
        {
          "name": "program"
        }
      ],
      "args": [
        {
          "name": "feeRecipient",
          "type": "pubkey"
        },
        {
          "name": "feeSigner",
          "type": "pubkey"
        },
        {
          "name": "fillSigner",
          "type": "pubkey"
        }
      ]
    },
    {
      "name": "interchainSecurityModule",
      "discriminator": [
        45,
        18,
        245,
        87,
        234,
        46,
        246,
        15
      ],
      "accounts": [],
      "args": []
    },
    {
      "name": "interchainSecurityModuleAccountMetas",
      "discriminator": [
        190,
        214,
        218,
        129,
        67,
        97,
        4,
        76
      ],
      "accounts": [],
      "args": [],
      "returns": {
        "defined": {
          "name": "simulationReturnData",
          "generics": [
            {
              "kind": "type",
              "type": {
                "vec": {
                  "defined": {
                    "name": "serializableAccountMeta"
                  }
                }
              }
            }
          ]
        }
      }
    },
    {
      "name": "migrateFeeAdapterState",
      "discriminator": [
        177,
        245,
        82,
        48,
        253,
        60,
        192,
        150
      ],
      "accounts": [
        {
          "name": "spokeState",
          "writable": true,
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  115,
                  112,
                  111,
                  107,
                  101,
                  45,
                  115,
                  116,
                  97,
                  116,
                  101
                ]
              }
            ]
          }
        },
        {
          "name": "feeAdapterState",
          "writable": true
        },
        {
          "name": "admin",
          "writable": true,
          "signer": true
        },
        {
          "name": "systemProgram",
          "address": "11111111111111111111111111111111"
        }
      ],
      "args": [
        {
          "name": "fillSigner",
          "type": "pubkey"
        }
      ]
    },
    {
      "name": "migrateSpokeState",
      "docs": [
        "Migrate SpokeState PDA to new layout (adds CCIP fields). Call once per deployment after upgrade.",
        "Only the owner can run this. Safe to run only on accounts that still have the old layout."
      ],
      "discriminator": [
        57,
        49,
        198,
        20,
        162,
        35,
        84,
        28
      ],
      "accounts": [
        {
          "name": "spokeState",
          "writable": true
        },
        {
          "name": "admin",
          "writable": true,
          "signer": true
        },
        {
          "name": "systemProgram",
          "address": "11111111111111111111111111111111"
        }
      ],
      "args": []
    },
    {
      "name": "newIntent",
      "docs": [
        "Create a new intent.",
        "The user \"locks\" funds (previously deposited) and creates an intent.",
        "For simplicity, we assume full deposit has been made before.",
        "NOTE: max_fee is not used now and we do not support amountOutMin yet for swaps."
      ],
      "discriminator": [
        157,
        204,
        58,
        235,
        252,
        199,
        95,
        123
      ],
      "accounts": [
        {
          "name": "spokeState",
          "writable": true,
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  115,
                  112,
                  111,
                  107,
                  101,
                  45,
                  115,
                  116,
                  97,
                  116,
                  101
                ]
              }
            ]
          }
        },
        {
          "name": "feeAdapterState",
          "writable": true,
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  102,
                  101,
                  101,
                  45,
                  97,
                  100,
                  97,
                  112,
                  116,
                  101,
                  114,
                  45,
                  115,
                  116,
                  97,
                  116,
                  101
                ]
              }
            ]
          }
        },
        {
          "name": "authority",
          "writable": true,
          "signer": true
        },
        {
          "name": "mint"
        },
        {
          "name": "userTokenAccount",
          "writable": true
        },
        {
          "name": "programVaultAccount",
          "writable": true
        },
        {
          "name": "tokenProgram",
          "address": "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"
        },
        {
          "name": "hyperlaneMailbox"
        },
        {
          "name": "systemProgram",
          "address": "11111111111111111111111111111111"
        },
        {
          "name": "splNoopProgram",
          "address": "noopb9bkMVfRPU8AsbpTUg8AQkHtKwMYZiFUjNRtMmV"
        },
        {
          "name": "mailboxOutbox",
          "writable": true
        },
        {
          "name": "dispatchAuthority",
          "writable": true
        },
        {
          "name": "uniqueMessageAccount",
          "writable": true,
          "signer": true
        },
        {
          "name": "dispatchedMessagePda",
          "writable": true
        },
        {
          "name": "igpProgram"
        },
        {
          "name": "igpProgramData",
          "writable": true
        },
        {
          "name": "igpPaymentPda",
          "writable": true
        },
        {
          "name": "configuredIgpAccount",
          "writable": true
        },
        {
          "name": "feeSigner"
        },
        {
          "name": "feeRecipient",
          "writable": true
        },
        {
          "name": "feeRecipientTokenAccount",
          "writable": true
        },
        {
          "name": "instructionSysvar",
          "address": "Sysvar1nstructions1111111111111111111111111"
        },
        {
          "name": "innerIgpAccount",
          "writable": true,
          "optional": true
        },
        {
          "name": "eventAuthority",
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  95,
                  95,
                  101,
                  118,
                  101,
                  110,
                  116,
                  95,
                  97,
                  117,
                  116,
                  104,
                  111,
                  114,
                  105,
                  116,
                  121
                ]
              }
            ]
          }
        },
        {
          "name": "program"
        }
      ],
      "args": [
        {
          "name": "receiver",
          "type": "pubkey"
        },
        {
          "name": "outputAsset",
          "type": "pubkey"
        },
        {
          "name": "amount",
          "type": "u64"
        },
        {
          "name": "amountOutMin",
          "type": "u128"
        },
        {
          "name": "ttl",
          "type": "u64"
        },
        {
          "name": "destinations",
          "type": {
            "vec": "u32"
          }
        },
        {
          "name": "data",
          "type": "bytes"
        },
        {
          "name": "messageGasLimit",
          "type": "u64"
        },
        {
          "name": "feeParam",
          "type": {
            "defined": {
              "name": "feeParams"
            }
          }
        }
      ]
    },
    {
      "name": "newOrder",
      "discriminator": [
        153,
        0,
        116,
        34,
        241,
        46,
        40,
        139
      ],
      "accounts": [
        {
          "name": "spokeState",
          "writable": true,
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  115,
                  112,
                  111,
                  107,
                  101,
                  45,
                  115,
                  116,
                  97,
                  116,
                  101
                ]
              }
            ]
          }
        },
        {
          "name": "feeAdapterState",
          "writable": true,
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  102,
                  101,
                  101,
                  45,
                  97,
                  100,
                  97,
                  112,
                  116,
                  101,
                  114,
                  45,
                  115,
                  116,
                  97,
                  116,
                  101
                ]
              }
            ]
          }
        },
        {
          "name": "authority",
          "writable": true,
          "signer": true
        },
        {
          "name": "mint"
        },
        {
          "name": "userTokenAccount",
          "writable": true
        },
        {
          "name": "programVaultAccount",
          "writable": true
        },
        {
          "name": "tokenProgram",
          "address": "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"
        },
        {
          "name": "hyperlaneMailbox"
        },
        {
          "name": "systemProgram",
          "address": "11111111111111111111111111111111"
        },
        {
          "name": "splNoopProgram",
          "address": "noopb9bkMVfRPU8AsbpTUg8AQkHtKwMYZiFUjNRtMmV"
        },
        {
          "name": "mailboxOutbox",
          "writable": true
        },
        {
          "name": "dispatchAuthority",
          "writable": true
        },
        {
          "name": "uniqueMessageAccount",
          "writable": true,
          "signer": true
        },
        {
          "name": "dispatchedMessagePda",
          "writable": true
        },
        {
          "name": "igpProgram"
        },
        {
          "name": "igpProgramData",
          "writable": true
        },
        {
          "name": "igpPaymentPda",
          "writable": true
        },
        {
          "name": "configuredIgpAccount",
          "writable": true
        },
        {
          "name": "feeSigner"
        },
        {
          "name": "feeRecipient",
          "writable": true
        },
        {
          "name": "feeRecipientTokenAccount",
          "writable": true
        },
        {
          "name": "instructionSysvar",
          "address": "Sysvar1nstructions1111111111111111111111111"
        },
        {
          "name": "innerIgpAccount",
          "writable": true,
          "optional": true
        },
        {
          "name": "eventAuthority",
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  95,
                  95,
                  101,
                  118,
                  101,
                  110,
                  116,
                  95,
                  97,
                  117,
                  116,
                  104,
                  111,
                  114,
                  105,
                  116,
                  121
                ]
              }
            ]
          }
        },
        {
          "name": "program"
        }
      ],
      "args": [
        {
          "name": "params",
          "type": {
            "vec": {
              "defined": {
                "name": "orderParameters"
              }
            }
          }
        },
        {
          "name": "feeParam",
          "type": {
            "defined": {
              "name": "feeParams"
            }
          }
        }
      ]
    },
    {
      "name": "pause",
      "docs": [
        "Pause the program.",
        "Only the lighthouse or watchtower can call this."
      ],
      "discriminator": [
        211,
        22,
        221,
        251,
        74,
        121,
        193,
        47
      ],
      "accounts": [
        {
          "name": "spokeState",
          "writable": true,
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  115,
                  112,
                  111,
                  107,
                  101,
                  45,
                  115,
                  116,
                  97,
                  116,
                  101
                ]
              }
            ]
          }
        },
        {
          "name": "admin",
          "signer": true
        },
        {
          "name": "eventAuthority",
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  95,
                  95,
                  101,
                  118,
                  101,
                  110,
                  116,
                  95,
                  97,
                  117,
                  116,
                  104,
                  111,
                  114,
                  105,
                  116,
                  121
                ]
              }
            ]
          }
        },
        {
          "name": "program"
        }
      ],
      "args": []
    },
    {
      "name": "pauseFeeAdapter",
      "discriminator": [
        93,
        43,
        105,
        101,
        30,
        160,
        145,
        136
      ],
      "accounts": [
        {
          "name": "spokeState",
          "writable": true,
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  115,
                  112,
                  111,
                  107,
                  101,
                  45,
                  115,
                  116,
                  97,
                  116,
                  101
                ]
              }
            ]
          }
        },
        {
          "name": "feeAdapterState",
          "writable": true,
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  102,
                  101,
                  101,
                  45,
                  97,
                  100,
                  97,
                  112,
                  116,
                  101,
                  114,
                  45,
                  115,
                  116,
                  97,
                  116,
                  101
                ]
              }
            ]
          }
        },
        {
          "name": "admin",
          "writable": true,
          "signer": true
        },
        {
          "name": "systemProgram",
          "address": "11111111111111111111111111111111"
        },
        {
          "name": "eventAuthority",
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  95,
                  95,
                  101,
                  118,
                  101,
                  110,
                  116,
                  95,
                  97,
                  117,
                  116,
                  104,
                  111,
                  114,
                  105,
                  116,
                  121
                ]
              }
            ]
          }
        },
        {
          "name": "program"
        }
      ],
      "args": []
    },
    {
      "name": "rollbackToHyperlane",
      "discriminator": [
        48,
        59,
        183,
        238,
        71,
        236,
        115,
        182
      ],
      "accounts": [
        {
          "name": "spokeState",
          "writable": true,
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  115,
                  112,
                  111,
                  107,
                  101,
                  45,
                  115,
                  116,
                  97,
                  116,
                  101
                ]
              }
            ]
          }
        },
        {
          "name": "admin",
          "signer": true
        },
        {
          "name": "eventAuthority",
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  95,
                  95,
                  101,
                  118,
                  101,
                  110,
                  116,
                  95,
                  97,
                  117,
                  116,
                  104,
                  111,
                  114,
                  105,
                  116,
                  121
                ]
              }
            ]
          }
        },
        {
          "name": "program"
        }
      ],
      "args": []
    },
    {
      "name": "settleDeliveredIntent",
      "discriminator": [
        106,
        187,
        207,
        145,
        6,
        174,
        89,
        217
      ],
      "accounts": [
        {
          "name": "authority",
          "writable": true,
          "signer": true
        },
        {
          "name": "spokeState"
        },
        {
          "name": "intentStatusPda",
          "writable": true
        },
        {
          "name": "vaultAuthority"
        },
        {
          "name": "tokenProgram",
          "address": "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"
        },
        {
          "name": "systemProgram",
          "address": "11111111111111111111111111111111"
        },
        {
          "name": "mintAccount"
        },
        {
          "name": "associatedTokenProgram",
          "address": "ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL"
        },
        {
          "name": "recipient"
        },
        {
          "name": "recipientTokenAccount",
          "writable": true
        },
        {
          "name": "vaultTokenAccount",
          "writable": true
        },
        {
          "name": "eventAuthority",
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  95,
                  95,
                  101,
                  118,
                  101,
                  110,
                  116,
                  95,
                  97,
                  117,
                  116,
                  104,
                  111,
                  114,
                  105,
                  116,
                  121
                ]
              }
            ]
          }
        },
        {
          "name": "program"
        }
      ],
      "args": [
        {
          "name": "settleDeliveredIntent",
          "type": {
            "defined": {
              "name": "settleDeliveredIntentInstruction"
            }
          }
        }
      ]
    },
    {
      "name": "switchToCcip",
      "discriminator": [
        94,
        212,
        224,
        136,
        1,
        215,
        194,
        214
      ],
      "accounts": [
        {
          "name": "spokeState",
          "writable": true,
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  115,
                  112,
                  111,
                  107,
                  101,
                  45,
                  115,
                  116,
                  97,
                  116,
                  101
                ]
              }
            ]
          }
        },
        {
          "name": "admin",
          "signer": true
        },
        {
          "name": "eventAuthority",
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  95,
                  95,
                  101,
                  118,
                  101,
                  110,
                  116,
                  95,
                  97,
                  117,
                  116,
                  104,
                  111,
                  114,
                  105,
                  116,
                  121
                ]
              }
            ]
          }
        },
        {
          "name": "program"
        }
      ],
      "args": [
        {
          "name": "ccipRouter",
          "type": "pubkey"
        },
        {
          "name": "ccipOfframp",
          "type": "pubkey"
        },
        {
          "name": "ccipChainSelector",
          "type": "u64"
        },
        {
          "name": "everclearCcipChainSelector",
          "type": "u64"
        },
        {
          "name": "everclearGateway",
          "type": {
            "array": [
              "u8",
              32
            ]
          }
        }
      ]
    },
    {
      "name": "unpause",
      "docs": [
        "Unpause the program."
      ],
      "discriminator": [
        169,
        144,
        4,
        38,
        10,
        141,
        188,
        255
      ],
      "accounts": [
        {
          "name": "spokeState",
          "writable": true,
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  115,
                  112,
                  111,
                  107,
                  101,
                  45,
                  115,
                  116,
                  97,
                  116,
                  101
                ]
              }
            ]
          }
        },
        {
          "name": "admin",
          "signer": true
        },
        {
          "name": "eventAuthority",
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  95,
                  95,
                  101,
                  118,
                  101,
                  110,
                  116,
                  95,
                  97,
                  117,
                  116,
                  104,
                  111,
                  114,
                  105,
                  116,
                  121
                ]
              }
            ]
          }
        },
        {
          "name": "program"
        }
      ],
      "args": []
    },
    {
      "name": "unpauseFeeAdapter",
      "discriminator": [
        141,
        149,
        58,
        215,
        141,
        42,
        240,
        139
      ],
      "accounts": [
        {
          "name": "spokeState",
          "writable": true,
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  115,
                  112,
                  111,
                  107,
                  101,
                  45,
                  115,
                  116,
                  97,
                  116,
                  101
                ]
              }
            ]
          }
        },
        {
          "name": "feeAdapterState",
          "writable": true,
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  102,
                  101,
                  101,
                  45,
                  97,
                  100,
                  97,
                  112,
                  116,
                  101,
                  114,
                  45,
                  115,
                  116,
                  97,
                  116,
                  101
                ]
              }
            ]
          }
        },
        {
          "name": "admin",
          "writable": true,
          "signer": true
        },
        {
          "name": "systemProgram",
          "address": "11111111111111111111111111111111"
        },
        {
          "name": "eventAuthority",
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  95,
                  95,
                  101,
                  118,
                  101,
                  110,
                  116,
                  95,
                  97,
                  117,
                  116,
                  104,
                  111,
                  114,
                  105,
                  116,
                  121
                ]
              }
            ]
          }
        },
        {
          "name": "program"
        }
      ],
      "args": []
    },
    {
      "name": "updateFeeRecipient",
      "discriminator": [
        249,
        0,
        198,
        35,
        183,
        123,
        57,
        188
      ],
      "accounts": [
        {
          "name": "spokeState",
          "writable": true,
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  115,
                  112,
                  111,
                  107,
                  101,
                  45,
                  115,
                  116,
                  97,
                  116,
                  101
                ]
              }
            ]
          }
        },
        {
          "name": "feeAdapterState",
          "writable": true,
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  102,
                  101,
                  101,
                  45,
                  97,
                  100,
                  97,
                  112,
                  116,
                  101,
                  114,
                  45,
                  115,
                  116,
                  97,
                  116,
                  101
                ]
              }
            ]
          }
        },
        {
          "name": "admin",
          "writable": true,
          "signer": true
        },
        {
          "name": "systemProgram",
          "address": "11111111111111111111111111111111"
        },
        {
          "name": "eventAuthority",
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  95,
                  95,
                  101,
                  118,
                  101,
                  110,
                  116,
                  95,
                  97,
                  117,
                  116,
                  104,
                  111,
                  114,
                  105,
                  116,
                  121
                ]
              }
            ]
          }
        },
        {
          "name": "program"
        }
      ],
      "args": [
        {
          "name": "feeRecipient",
          "type": "pubkey"
        }
      ]
    },
    {
      "name": "updateFeeSigner",
      "discriminator": [
        140,
        214,
        89,
        41,
        218,
        25,
        185,
        97
      ],
      "accounts": [
        {
          "name": "spokeState",
          "writable": true,
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  115,
                  112,
                  111,
                  107,
                  101,
                  45,
                  115,
                  116,
                  97,
                  116,
                  101
                ]
              }
            ]
          }
        },
        {
          "name": "feeAdapterState",
          "writable": true,
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  102,
                  101,
                  101,
                  45,
                  97,
                  100,
                  97,
                  112,
                  116,
                  101,
                  114,
                  45,
                  115,
                  116,
                  97,
                  116,
                  101
                ]
              }
            ]
          }
        },
        {
          "name": "admin",
          "writable": true,
          "signer": true
        },
        {
          "name": "systemProgram",
          "address": "11111111111111111111111111111111"
        },
        {
          "name": "eventAuthority",
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  95,
                  95,
                  101,
                  118,
                  101,
                  110,
                  116,
                  95,
                  97,
                  117,
                  116,
                  104,
                  111,
                  114,
                  105,
                  116,
                  121
                ]
              }
            ]
          }
        },
        {
          "name": "program"
        }
      ],
      "args": [
        {
          "name": "feeSigner",
          "type": "pubkey"
        }
      ]
    },
    {
      "name": "updateFillSigner",
      "discriminator": [
        38,
        159,
        245,
        223,
        111,
        57,
        22,
        13
      ],
      "accounts": [
        {
          "name": "spokeState",
          "writable": true,
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  115,
                  112,
                  111,
                  107,
                  101,
                  45,
                  115,
                  116,
                  97,
                  116,
                  101
                ]
              }
            ]
          }
        },
        {
          "name": "feeAdapterState",
          "writable": true,
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  102,
                  101,
                  101,
                  45,
                  97,
                  100,
                  97,
                  112,
                  116,
                  101,
                  114,
                  45,
                  115,
                  116,
                  97,
                  116,
                  101
                ]
              }
            ]
          }
        },
        {
          "name": "admin",
          "writable": true,
          "signer": true
        },
        {
          "name": "systemProgram",
          "address": "11111111111111111111111111111111"
        },
        {
          "name": "eventAuthority",
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  95,
                  95,
                  101,
                  118,
                  101,
                  110,
                  116,
                  95,
                  97,
                  117,
                  116,
                  104,
                  111,
                  114,
                  105,
                  116,
                  121
                ]
              }
            ]
          }
        },
        {
          "name": "program"
        }
      ],
      "args": [
        {
          "name": "fillSigner",
          "type": "pubkey"
        }
      ]
    },
    {
      "name": "updateIgp",
      "docs": [
        "new_igp contains the IGP address",
        "new_igp_type contains either the IGP address (as in new_igp), or the overhead IGP address if the IGP is an overhead IGP."
      ],
      "discriminator": [
        228,
        15,
        51,
        100,
        221,
        15,
        217,
        59
      ],
      "accounts": [
        {
          "name": "spokeState",
          "writable": true,
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  115,
                  112,
                  111,
                  107,
                  101,
                  45,
                  115,
                  116,
                  97,
                  116,
                  101
                ]
              }
            ]
          }
        },
        {
          "name": "admin",
          "signer": true
        },
        {
          "name": "eventAuthority",
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  95,
                  95,
                  101,
                  118,
                  101,
                  110,
                  116,
                  95,
                  97,
                  117,
                  116,
                  104,
                  111,
                  114,
                  105,
                  116,
                  121
                ]
              }
            ]
          }
        },
        {
          "name": "program"
        }
      ],
      "args": [
        {
          "name": "newIgp",
          "type": "pubkey"
        },
        {
          "name": "newIgpType",
          "type": {
            "defined": {
              "name": "interchainGasPaymasterType"
            }
          }
        }
      ]
    },
    {
      "name": "updateLighthouse",
      "discriminator": [
        51,
        13,
        101,
        249,
        40,
        209,
        254,
        17
      ],
      "accounts": [
        {
          "name": "spokeState",
          "writable": true,
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  115,
                  112,
                  111,
                  107,
                  101,
                  45,
                  115,
                  116,
                  97,
                  116,
                  101
                ]
              }
            ]
          }
        },
        {
          "name": "admin",
          "signer": true
        },
        {
          "name": "eventAuthority",
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  95,
                  95,
                  101,
                  118,
                  101,
                  110,
                  116,
                  95,
                  97,
                  117,
                  116,
                  104,
                  111,
                  114,
                  105,
                  116,
                  121
                ]
              }
            ]
          }
        },
        {
          "name": "program"
        }
      ],
      "args": [
        {
          "name": "newLighthouse",
          "type": "pubkey"
        }
      ]
    },
    {
      "name": "updateMailbox",
      "discriminator": [
        213,
        10,
        94,
        69,
        72,
        226,
        161,
        204
      ],
      "accounts": [
        {
          "name": "spokeState",
          "writable": true,
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  115,
                  112,
                  111,
                  107,
                  101,
                  45,
                  115,
                  116,
                  97,
                  116,
                  101
                ]
              }
            ]
          }
        },
        {
          "name": "admin",
          "signer": true
        },
        {
          "name": "eventAuthority",
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  95,
                  95,
                  101,
                  118,
                  101,
                  110,
                  116,
                  95,
                  97,
                  117,
                  116,
                  104,
                  111,
                  114,
                  105,
                  116,
                  121
                ]
              }
            ]
          }
        },
        {
          "name": "program"
        }
      ],
      "args": [
        {
          "name": "newMailbox",
          "type": "pubkey"
        }
      ]
    },
    {
      "name": "updateMailboxDispatchAuthorityBump",
      "discriminator": [
        99,
        54,
        179,
        125,
        118,
        161,
        99,
        5
      ],
      "accounts": [
        {
          "name": "spokeState",
          "writable": true,
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  115,
                  112,
                  111,
                  107,
                  101,
                  45,
                  115,
                  116,
                  97,
                  116,
                  101
                ]
              }
            ]
          }
        },
        {
          "name": "admin",
          "signer": true
        },
        {
          "name": "eventAuthority",
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  95,
                  95,
                  101,
                  118,
                  101,
                  110,
                  116,
                  95,
                  97,
                  117,
                  116,
                  104,
                  111,
                  114,
                  105,
                  116,
                  121
                ]
              }
            ]
          }
        },
        {
          "name": "program"
        }
      ],
      "args": [
        {
          "name": "newBump",
          "type": "u8"
        }
      ]
    },
    {
      "name": "updateMessageGasLimit",
      "discriminator": [
        95,
        171,
        202,
        222,
        76,
        224,
        79,
        19
      ],
      "accounts": [
        {
          "name": "spokeState",
          "writable": true,
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  115,
                  112,
                  111,
                  107,
                  101,
                  45,
                  115,
                  116,
                  97,
                  116,
                  101
                ]
              }
            ]
          }
        },
        {
          "name": "admin",
          "signer": true
        },
        {
          "name": "eventAuthority",
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  95,
                  95,
                  101,
                  118,
                  101,
                  110,
                  116,
                  95,
                  97,
                  117,
                  116,
                  104,
                  111,
                  114,
                  105,
                  116,
                  121
                ]
              }
            ]
          }
        },
        {
          "name": "program"
        }
      ],
      "args": [
        {
          "name": "newLimit",
          "type": "u64"
        }
      ]
    },
    {
      "name": "updateVaultAuthorityBump",
      "discriminator": [
        124,
        42,
        9,
        237,
        19,
        224,
        189,
        190
      ],
      "accounts": [
        {
          "name": "spokeState",
          "writable": true,
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  115,
                  112,
                  111,
                  107,
                  101,
                  45,
                  115,
                  116,
                  97,
                  116,
                  101
                ]
              }
            ]
          }
        },
        {
          "name": "admin",
          "signer": true
        },
        {
          "name": "eventAuthority",
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  95,
                  95,
                  101,
                  118,
                  101,
                  110,
                  116,
                  95,
                  97,
                  117,
                  116,
                  104,
                  111,
                  114,
                  105,
                  116,
                  121
                ]
              }
            ]
          }
        },
        {
          "name": "program"
        }
      ],
      "args": [
        {
          "name": "newBump",
          "type": "u8"
        }
      ]
    },
    {
      "name": "updateWatchtower",
      "discriminator": [
        146,
        49,
        28,
        59,
        251,
        130,
        217,
        207
      ],
      "accounts": [
        {
          "name": "spokeState",
          "writable": true,
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  115,
                  112,
                  111,
                  107,
                  101,
                  45,
                  115,
                  116,
                  97,
                  116,
                  101
                ]
              }
            ]
          }
        },
        {
          "name": "admin",
          "signer": true
        },
        {
          "name": "eventAuthority",
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  95,
                  95,
                  101,
                  118,
                  101,
                  110,
                  116,
                  95,
                  97,
                  117,
                  116,
                  104,
                  111,
                  114,
                  105,
                  116,
                  121
                ]
              }
            ]
          }
        },
        {
          "name": "program"
        }
      ],
      "args": [
        {
          "name": "newWatchtower",
          "type": "pubkey"
        }
      ]
    }
  ],
  "accounts": [
    {
      "name": "feeAdapterState",
      "discriminator": [
        169,
        215,
        143,
        203,
        57,
        154,
        119,
        117
      ]
    },
    {
      "name": "intentStatusAccount",
      "discriminator": [
        31,
        58,
        221,
        56,
        60,
        126,
        214,
        23
      ]
    },
    {
      "name": "spokeState",
      "discriminator": [
        203,
        210,
        244,
        16,
        167,
        13,
        229,
        82
      ]
    }
  ],
  "events": [
    {
      "name": "feeAdapterPausedEvent",
      "discriminator": [
        161,
        21,
        99,
        234,
        228,
        118,
        39,
        29
      ]
    },
    {
      "name": "feeAdapterUnpausedEvent",
      "discriminator": [
        90,
        152,
        255,
        175,
        92,
        156,
        201,
        156
      ]
    },
    {
      "name": "feeData",
      "discriminator": [
        181,
        236,
        217,
        72,
        76,
        217,
        172,
        183
      ]
    },
    {
      "name": "feeRecipientUpdatedEvent",
      "discriminator": [
        253,
        5,
        188,
        179,
        215,
        147,
        124,
        145
      ]
    },
    {
      "name": "feeSignerUpdatedEvent",
      "discriminator": [
        171,
        163,
        120,
        226,
        91,
        69,
        238,
        4
      ]
    },
    {
      "name": "fillSignerUpdatedEvent",
      "discriminator": [
        11,
        118,
        112,
        68,
        18,
        26,
        210,
        146
      ]
    },
    {
      "name": "igpUpdatedEvent",
      "discriminator": [
        117,
        50,
        157,
        103,
        151,
        162,
        142,
        136
      ]
    },
    {
      "name": "initializedEvent",
      "discriminator": [
        136,
        202,
        63,
        120,
        152,
        146,
        41,
        79
      ]
    },
    {
      "name": "initializedFeeAdapterEvent",
      "discriminator": [
        190,
        147,
        108,
        88,
        200,
        230,
        169,
        237
      ]
    },
    {
      "name": "intentAddedEvent",
      "discriminator": [
        18,
        99,
        228,
        90,
        86,
        91,
        49,
        93
      ]
    },
    {
      "name": "intentFilledEvent",
      "discriminator": [
        151,
        229,
        192,
        91,
        52,
        187,
        168,
        33
      ]
    },
    {
      "name": "intentWithFeesAddedEvent",
      "discriminator": [
        89,
        204,
        201,
        228,
        78,
        165,
        77,
        71
      ]
    },
    {
      "name": "lighthouseUpdatedEvent",
      "discriminator": [
        76,
        188,
        81,
        137,
        120,
        178,
        82,
        45
      ]
    },
    {
      "name": "mailboxDispatchAuthorityBumpUpdatedEvent",
      "discriminator": [
        136,
        254,
        105,
        103,
        87,
        8,
        242,
        12
      ]
    },
    {
      "name": "mailboxUpdatedEvent",
      "discriminator": [
        6,
        80,
        174,
        219,
        230,
        25,
        176,
        6
      ]
    },
    {
      "name": "messageDeliveredEvent",
      "discriminator": [
        170,
        221,
        81,
        222,
        188,
        71,
        22,
        47
      ]
    },
    {
      "name": "messageGasLimitUpdatedEvent",
      "discriminator": [
        47,
        54,
        237,
        179,
        148,
        197,
        0,
        141
      ]
    },
    {
      "name": "messageReceivedEvent",
      "discriminator": [
        232,
        67,
        17,
        7,
        89,
        91,
        17,
        69
      ]
    },
    {
      "name": "messagingProviderSwitchedEvent",
      "discriminator": [
        62,
        53,
        222,
        112,
        47,
        129,
        232,
        14
      ]
    },
    {
      "name": "orderCreated",
      "discriminator": [
        224,
        1,
        229,
        63,
        254,
        60,
        190,
        159
      ]
    },
    {
      "name": "pausedEvent",
      "discriminator": [
        43,
        14,
        250,
        236,
        116,
        42,
        177,
        89
      ]
    },
    {
      "name": "settledEvent",
      "discriminator": [
        117,
        207,
        196,
        174,
        197,
        200,
        11,
        67
      ]
    },
    {
      "name": "unpausedEvent",
      "discriminator": [
        150,
        198,
        191,
        67,
        103,
        86,
        160,
        55
      ]
    },
    {
      "name": "vaultAuthorityBumpUpdatedEvent",
      "discriminator": [
        88,
        55,
        123,
        0,
        203,
        140,
        231,
        153
      ]
    },
    {
      "name": "watchtowerUpdatedEvent",
      "discriminator": [
        78,
        128,
        124,
        179,
        254,
        219,
        127,
        3
      ]
    }
  ],
  "errors": [
    {
      "code": 6000,
      "name": "onlyOwner",
      "msg": "Only the contract owner can call this method."
    },
    {
      "code": 6001,
      "name": "notAuthorizedToPause",
      "msg": "Not authorized to pause."
    },
    {
      "code": 6002,
      "name": "contractPaused",
      "msg": "Contract is paused."
    },
    {
      "code": 6003,
      "name": "invalidAmount",
      "msg": "Invalid amount provided."
    },
    {
      "code": 6004,
      "name": "invalidOperation",
      "msg": "Invalid operation or overflow."
    },
    {
      "code": 6005,
      "name": "intentNotFound",
      "msg": "Intent not found."
    },
    {
      "code": 6006,
      "name": "invalidIntentStatus",
      "msg": "Intent is in an invalid status for this operation."
    },
    {
      "code": 6007,
      "name": "maxFeeExceeded",
      "msg": "Max fee exceeded."
    },
    {
      "code": 6008,
      "name": "multipleOrderAssets",
      "msg": "Multiple input assets in a single order are not allowed."
    },
    {
      "code": 6009,
      "name": "emptyParams",
      "msg": "Empty Params in new order function are not allowed"
    },
    {
      "code": 6010,
      "name": "invalidOrigin",
      "msg": "Invalid origin for inbound message."
    },
    {
      "code": 6011,
      "name": "invalidSender",
      "msg": "Invalid sender for inbound message."
    },
    {
      "code": 6012,
      "name": "invalidMessage",
      "msg": "Invalid or unknown message."
    },
    {
      "code": 6013,
      "name": "unauthorized",
      "msg": "Unauthorized operation."
    },
    {
      "code": 6014,
      "name": "signatureExpired",
      "msg": "Signature has expired"
    },
    {
      "code": 6015,
      "name": "invalidSignature",
      "msg": "Invalid signature"
    },
    {
      "code": 6016,
      "name": "zeroAmount",
      "msg": "Zero amount provided"
    },
    {
      "code": 6017,
      "name": "decimalConversionOverflow",
      "msg": "Decimal conversion overflow"
    },
    {
      "code": 6018,
      "name": "alreadyInitialized",
      "msg": "Already initialized"
    },
    {
      "code": 6019,
      "name": "invalidOwner",
      "msg": "Invalid Owner"
    },
    {
      "code": 6020,
      "name": "invalidVarUpdate",
      "msg": "Invalid var update"
    },
    {
      "code": 6021,
      "name": "invalidIntent",
      "msg": "Invalid intent"
    },
    {
      "code": 6022,
      "name": "overflow",
      "msg": "overflow"
    },
    {
      "code": 6023,
      "name": "invalidAccount",
      "msg": "Invalid account meta"
    },
    {
      "code": 6024,
      "name": "invalidArgument",
      "msg": "Invalid argument data"
    },
    {
      "code": 6025,
      "name": "incorrectProgramId",
      "msg": "Incorrect program id"
    },
    {
      "code": 6026,
      "name": "missingRequiredSignature",
      "msg": "Missing required signature"
    },
    {
      "code": 6027,
      "name": "extraneousAccount",
      "msg": "Extraneous account"
    },
    {
      "code": 6028,
      "name": "integerOverflow",
      "msg": "Overflowing Integer"
    },
    {
      "code": 6029,
      "name": "invalidSeeds",
      "msg": "Invalid seeds for deriving pda"
    },
    {
      "code": 6030,
      "name": "invalidVaultAccount",
      "msg": "Invalid vault account"
    },
    {
      "code": 6031,
      "name": "invalidIntentPda",
      "msg": "Invalid intent pda"
    },
    {
      "code": 6032,
      "name": "invalidSettlementSize",
      "msg": "Invalid settlement size"
    },
    {
      "code": 6033,
      "name": "incorrectSettlementAccounts",
      "msg": "Incorrect settlement accounts, mismatch with intent PDA."
    },
    {
      "code": 6034,
      "name": "invalidIntentId",
      "msg": "Invalid intent id"
    },
    {
      "code": 6035,
      "name": "invalidDeadline",
      "msg": "Invalid deadline"
    },
    {
      "code": 6036,
      "name": "missingEd25519Instruction",
      "msg": "Missing ed25519 preinstructions"
    },
    {
      "code": 6037,
      "name": "invalidFeeSignature",
      "msg": "Invalid fee signature"
    },
    {
      "code": 6038,
      "name": "invalidFeeSignatureAccountsNotEmpty",
      "msg": "Invalid fee signature: preinstruction accounts not empty"
    },
    {
      "code": 6039,
      "name": "invalidFeeSignatureDataLength",
      "msg": "Invalid fee signature: preinstruction data length mismatch"
    },
    {
      "code": 6040,
      "name": "invalidFeeSignatureNumSignatures",
      "msg": "Invalid fee signature: number of signatures must be 1"
    },
    {
      "code": 6041,
      "name": "invalidFeeSignaturePadding",
      "msg": "Invalid fee signature: padding byte must be 0"
    },
    {
      "code": 6042,
      "name": "invalidFeeSignatureOffsets",
      "msg": "Invalid fee signature: offset mismatch"
    },
    {
      "code": 6043,
      "name": "invalidFeeSignaturePubkeyMismatch",
      "msg": "Invalid fee signature: public key mismatch with configured fee signer"
    },
    {
      "code": 6044,
      "name": "invalidFeeSignatureDataMismatch",
      "msg": "Invalid fee signature: signature data mismatch"
    },
    {
      "code": 6045,
      "name": "invalidFeeSignatureMessageMismatch",
      "msg": "Invalid fee signature: message data mismatch"
    },
    {
      "code": 6046,
      "name": "feeAdapterPaused",
      "msg": "Fee adapter paused"
    },
    {
      "code": 6047,
      "name": "wrongDestination",
      "msg": "Wrong destination for fill intent"
    },
    {
      "code": 6048,
      "name": "intentExpired",
      "msg": "fill intent expired"
    },
    {
      "code": 6049,
      "name": "amountOutInvalid",
      "msg": "fill intent amountOut is less than amountOutMin"
    },
    {
      "code": 6050,
      "name": "invalidDestinationArray",
      "msg": "invalid intent destinations"
    },
    {
      "code": 6051,
      "name": "invalidFillIntentStatus",
      "msg": "intent is already filled"
    },
    {
      "code": 6052,
      "name": "invalidIntentHash",
      "msg": "Intent hash mismatch - signature not bound to this intent"
    }
  ],
  "types": [
    {
      "name": "any2SvmMessage",
      "type": {
        "kind": "struct",
        "fields": [
          {
            "name": "messageId",
            "type": {
              "array": [
                "u8",
                32
              ]
            }
          },
          {
            "name": "sourceChainSelector",
            "type": "u64"
          },
          {
            "name": "sender",
            "type": "bytes"
          },
          {
            "name": "data",
            "type": "bytes"
          },
          {
            "name": "tokenAmounts",
            "type": {
              "vec": {
                "defined": {
                  "name": "tokenAmount"
                }
              }
            }
          }
        ]
      }
    },
    {
      "name": "evmIntent",
      "docs": [
        "Represents the 12 fields in our Intent struct, matching the Solidity layout.",
        "Anchor serde is added here for putting the intent in event."
      ],
      "type": {
        "kind": "struct",
        "fields": [
          {
            "name": "initiator",
            "type": {
              "array": [
                "u8",
                32
              ]
            }
          },
          {
            "name": "receiver",
            "type": {
              "array": [
                "u8",
                32
              ]
            }
          },
          {
            "name": "inputAsset",
            "type": {
              "array": [
                "u8",
                32
              ]
            }
          },
          {
            "name": "outputAsset",
            "type": {
              "array": [
                "u8",
                32
              ]
            }
          },
          {
            "name": "origin",
            "type": "u32"
          },
          {
            "name": "nonce",
            "type": "u64"
          },
          {
            "name": "timestamp",
            "type": "u64"
          },
          {
            "name": "ttl",
            "type": "u64"
          },
          {
            "name": "amount",
            "type": {
              "array": [
                "u8",
                32
              ]
            }
          },
          {
            "name": "amountOutMin",
            "type": {
              "array": [
                "u8",
                32
              ]
            }
          },
          {
            "name": "destinations",
            "type": {
              "vec": "u32"
            }
          },
          {
            "name": "data",
            "type": "bytes"
          }
        ]
      }
    },
    {
      "name": "feeAdapterPausedEvent",
      "type": {
        "kind": "struct",
        "fields": []
      }
    },
    {
      "name": "feeAdapterState",
      "type": {
        "kind": "struct",
        "fields": [
          {
            "name": "initialized",
            "type": "bool"
          },
          {
            "name": "paused",
            "type": "bool"
          },
          {
            "name": "feeRecipient",
            "type": "pubkey"
          },
          {
            "name": "feeSigner",
            "type": "pubkey"
          },
          {
            "name": "fillSigner",
            "type": "pubkey"
          },
          {
            "name": "bump",
            "type": "u8"
          }
        ]
      }
    },
    {
      "name": "feeAdapterUnpausedEvent",
      "type": {
        "kind": "struct",
        "fields": []
      }
    },
    {
      "name": "feeData",
      "type": {
        "kind": "struct",
        "fields": [
          {
            "name": "destinations",
            "type": {
              "vec": "u32"
            }
          },
          {
            "name": "inputAsset",
            "type": "pubkey"
          },
          {
            "name": "outputAsset",
            "type": "pubkey"
          },
          {
            "name": "amount",
            "type": "u64"
          },
          {
            "name": "amountOutMin",
            "type": "u128"
          },
          {
            "name": "ttl",
            "type": "u64"
          },
          {
            "name": "data",
            "type": "bytes"
          },
          {
            "name": "tokenFee",
            "type": "u64"
          },
          {
            "name": "nativeFee",
            "type": "u64"
          },
          {
            "name": "deadline",
            "type": "u64"
          }
        ]
      }
    },
    {
      "name": "feeParams",
      "type": {
        "kind": "struct",
        "fields": [
          {
            "name": "tokenFee",
            "type": "u64"
          },
          {
            "name": "nativeFee",
            "type": "u64"
          },
          {
            "name": "deadline",
            "type": "u64"
          },
          {
            "name": "signature",
            "type": "bytes"
          }
        ]
      }
    },
    {
      "name": "feeRecipientUpdatedEvent",
      "type": {
        "kind": "struct",
        "fields": [
          {
            "name": "oldFeeRecipient",
            "type": "pubkey"
          },
          {
            "name": "newFeeRecipient",
            "type": "pubkey"
          }
        ]
      }
    },
    {
      "name": "feeSignerUpdatedEvent",
      "type": {
        "kind": "struct",
        "fields": [
          {
            "name": "oldFeeSigner",
            "type": "pubkey"
          },
          {
            "name": "newFeeSigner",
            "type": "pubkey"
          }
        ]
      }
    },
    {
      "name": "fillSignerUpdatedEvent",
      "type": {
        "kind": "struct",
        "fields": [
          {
            "name": "oldFillSigner",
            "type": "pubkey"
          },
          {
            "name": "newFillSigner",
            "type": "pubkey"
          }
        ]
      }
    },
    {
      "name": "h256",
      "docs": [
        "256-bit hash type."
      ],
      "repr": {
        "kind": "c"
      },
      "type": {
        "kind": "struct",
        "fields": [
          {
            "array": [
              "u8",
              32
            ]
          }
        ]
      }
    },
    {
      "name": "handleInstruction",
      "type": {
        "kind": "struct",
        "fields": [
          {
            "name": "origin",
            "type": "u32"
          },
          {
            "name": "sender",
            "type": {
              "defined": {
                "name": "h256"
              }
            }
          },
          {
            "name": "message",
            "type": "bytes"
          }
        ]
      }
    },
    {
      "name": "igpUpdatedEvent",
      "type": {
        "kind": "struct",
        "fields": [
          {
            "name": "oldIgp",
            "type": "pubkey"
          },
          {
            "name": "newIgp",
            "type": "pubkey"
          },
          {
            "name": "oldIgpType",
            "type": {
              "defined": {
                "name": "interchainGasPaymasterType"
              }
            }
          },
          {
            "name": "newIgpType",
            "type": {
              "defined": {
                "name": "interchainGasPaymasterType"
              }
            }
          }
        ]
      }
    },
    {
      "name": "initializedEvent",
      "type": {
        "kind": "struct",
        "fields": [
          {
            "name": "owner",
            "type": "pubkey"
          },
          {
            "name": "domain",
            "type": "u32"
          },
          {
            "name": "everclear",
            "type": "u32"
          }
        ]
      }
    },
    {
      "name": "initializedFeeAdapterEvent",
      "type": {
        "kind": "struct",
        "fields": [
          {
            "name": "feeRecipient",
            "type": "pubkey"
          },
          {
            "name": "feeSigner",
            "type": "pubkey"
          },
          {
            "name": "fillSigner",
            "type": "pubkey"
          }
        ]
      }
    },
    {
      "name": "intentAddedEvent",
      "type": {
        "kind": "struct",
        "fields": [
          {
            "name": "intentId",
            "type": {
              "array": [
                "u8",
                32
              ]
            }
          },
          {
            "name": "messageId",
            "type": {
              "array": [
                "u8",
                32
              ]
            }
          },
          {
            "name": "initiator",
            "type": "pubkey"
          },
          {
            "name": "receiver",
            "type": "pubkey"
          },
          {
            "name": "inputAsset",
            "type": "pubkey"
          },
          {
            "name": "outputAsset",
            "type": "pubkey"
          },
          {
            "name": "normalizedAmount",
            "type": "u128"
          },
          {
            "name": "amountOutMin",
            "type": "u128"
          },
          {
            "name": "originDomain",
            "type": "u32"
          },
          {
            "name": "nonce",
            "type": "u64"
          },
          {
            "name": "ttl",
            "type": "u64"
          },
          {
            "name": "timestamp",
            "type": "u64"
          },
          {
            "name": "destinations",
            "type": {
              "vec": "u32"
            }
          },
          {
            "name": "data",
            "type": "bytes"
          }
        ]
      }
    },
    {
      "name": "intentFilledEvent",
      "type": {
        "kind": "struct",
        "fields": [
          {
            "name": "intentId",
            "type": {
              "array": [
                "u8",
                32
              ]
            }
          },
          {
            "name": "messageId",
            "type": {
              "array": [
                "u8",
                32
              ]
            }
          },
          {
            "name": "solver",
            "type": "pubkey"
          },
          {
            "name": "receiver",
            "type": {
              "array": [
                "u8",
                32
              ]
            }
          },
          {
            "name": "amountOut",
            "type": "u64"
          },
          {
            "name": "intent",
            "type": {
              "defined": {
                "name": "evmIntent"
              }
            }
          }
        ]
      }
    },
    {
      "name": "intentStatus",
      "docs": [
        "Intent status."
      ],
      "type": {
        "kind": "enum",
        "variants": [
          {
            "name": "none"
          },
          {
            "name": "added"
          },
          {
            "name": "filled"
          },
          {
            "name": "settled"
          },
          {
            "name": "settledAndManuallyExecuted"
          },
          {
            "name": "delivered"
          }
        ]
      }
    },
    {
      "name": "intentStatusAccount",
      "type": {
        "kind": "struct",
        "fields": [
          {
            "name": "status",
            "type": {
              "defined": {
                "name": "intentStatus"
              }
            }
          },
          {
            "name": "accounts",
            "type": {
              "vec": {
                "defined": {
                  "name": "serializableAccountMeta"
                }
              }
            }
          },
          {
            "name": "settlement",
            "type": {
              "option": {
                "defined": {
                  "name": "settlement"
                }
              }
            }
          }
        ]
      }
    },
    {
      "name": "intentWithFeesAddedEvent",
      "type": {
        "kind": "struct",
        "fields": [
          {
            "name": "intentId",
            "type": {
              "array": [
                "u8",
                32
              ]
            }
          },
          {
            "name": "initiator",
            "type": "pubkey"
          },
          {
            "name": "inputAsset",
            "type": "pubkey"
          },
          {
            "name": "amount",
            "docs": [
              "native amount in Solana"
            ],
            "type": "u64"
          },
          {
            "name": "fee",
            "docs": [
              "native amount in Solana"
            ],
            "type": "u64"
          }
        ]
      }
    },
    {
      "name": "interchainGasPaymasterType",
      "type": {
        "kind": "enum",
        "variants": [
          {
            "name": "igp",
            "fields": [
              "pubkey"
            ]
          },
          {
            "name": "overheadIgp",
            "fields": [
              "pubkey"
            ]
          }
        ]
      }
    },
    {
      "name": "lighthouseUpdatedEvent",
      "type": {
        "kind": "struct",
        "fields": [
          {
            "name": "oldLighthouse",
            "type": "pubkey"
          },
          {
            "name": "newLighthouse",
            "type": "pubkey"
          }
        ]
      }
    },
    {
      "name": "mailboxDispatchAuthorityBumpUpdatedEvent",
      "type": {
        "kind": "struct",
        "fields": [
          {
            "name": "oldBump",
            "type": "u8"
          },
          {
            "name": "newBump",
            "type": "u8"
          }
        ]
      }
    },
    {
      "name": "mailboxUpdatedEvent",
      "type": {
        "kind": "struct",
        "fields": [
          {
            "name": "oldMailbox",
            "type": "pubkey"
          },
          {
            "name": "newMailbox",
            "type": "pubkey"
          }
        ]
      }
    },
    {
      "name": "messageDeliveredEvent",
      "type": {
        "kind": "struct",
        "fields": [
          {
            "name": "domain",
            "type": "u32"
          },
          {
            "name": "settlement",
            "type": {
              "defined": {
                "name": "settlement"
              }
            }
          },
          {
            "name": "accountMetas",
            "type": {
              "vec": {
                "defined": {
                  "name": "serializableAccountMeta"
                }
              }
            }
          }
        ]
      }
    },
    {
      "name": "messageGasLimitUpdatedEvent",
      "type": {
        "kind": "struct",
        "fields": [
          {
            "name": "oldLimit",
            "type": "u64"
          },
          {
            "name": "newLimit",
            "type": "u64"
          }
        ]
      }
    },
    {
      "name": "messageReceivedEvent",
      "type": {
        "kind": "struct",
        "fields": [
          {
            "name": "origin",
            "type": "u32"
          },
          {
            "name": "sender",
            "type": "pubkey"
          }
        ]
      }
    },
    {
      "name": "messagingProviderSwitchedEvent",
      "type": {
        "kind": "struct",
        "fields": [
          {
            "name": "provider",
            "type": "u8"
          }
        ]
      }
    },
    {
      "name": "messagingProviderType",
      "type": {
        "kind": "enum",
        "variants": [
          {
            "name": "hyperlane"
          },
          {
            "name": "ccip"
          }
        ]
      }
    },
    {
      "name": "orderCreated",
      "type": {
        "kind": "struct",
        "fields": [
          {
            "name": "orderId",
            "type": {
              "array": [
                "u8",
                32
              ]
            }
          },
          {
            "name": "user",
            "type": "pubkey"
          },
          {
            "name": "intentIds",
            "type": {
              "vec": {
                "array": [
                  "u8",
                  32
                ]
              }
            }
          },
          {
            "name": "fee",
            "type": "u64"
          },
          {
            "name": "nativeValue",
            "type": "u64"
          }
        ]
      }
    },
    {
      "name": "orderParameters",
      "type": {
        "kind": "struct",
        "fields": [
          {
            "name": "destinations",
            "type": {
              "vec": "u32"
            }
          },
          {
            "name": "receiver",
            "type": "pubkey"
          },
          {
            "name": "outputAsset",
            "type": "pubkey"
          },
          {
            "name": "amount",
            "type": "u64"
          },
          {
            "name": "amountOutMin",
            "type": "u128"
          },
          {
            "name": "maxFee",
            "type": "u32"
          },
          {
            "name": "ttl",
            "type": "u64"
          },
          {
            "name": "data",
            "type": "bytes"
          },
          {
            "name": "messageGasLimit",
            "type": "u64"
          }
        ]
      }
    },
    {
      "name": "pausedEvent",
      "type": {
        "kind": "struct",
        "fields": []
      }
    },
    {
      "name": "serializableAccountMeta",
      "docs": [
        "A borsh-serializable version of `AccountMeta`."
      ],
      "type": {
        "kind": "struct",
        "fields": [
          {
            "name": "pubkey",
            "type": "pubkey"
          },
          {
            "name": "isSigner",
            "type": "bool"
          },
          {
            "name": "isWritable",
            "type": "bool"
          }
        ]
      }
    },
    {
      "name": "settleDeliveredIntentInstruction",
      "type": {
        "kind": "struct",
        "fields": [
          {
            "name": "intentId",
            "type": {
              "array": [
                "u8",
                32
              ]
            }
          }
        ]
      }
    },
    {
      "name": "settledEvent",
      "type": {
        "kind": "struct",
        "fields": [
          {
            "name": "intentId",
            "type": {
              "array": [
                "u8",
                32
              ]
            }
          },
          {
            "name": "recipient",
            "type": "pubkey"
          },
          {
            "name": "asset",
            "type": "pubkey"
          },
          {
            "name": "amount",
            "type": "u64"
          },
          {
            "name": "domain",
            "type": "u32"
          }
        ]
      }
    },
    {
      "name": "settlement",
      "type": {
        "kind": "struct",
        "fields": [
          {
            "name": "intentId",
            "type": {
              "array": [
                "u8",
                32
              ]
            }
          },
          {
            "name": "amount",
            "type": {
              "defined": {
                "name": "u256"
              }
            }
          },
          {
            "name": "asset",
            "type": "pubkey"
          },
          {
            "name": "recipient",
            "type": "pubkey"
          },
          {
            "name": "updateVirtualBalance",
            "type": "bool"
          }
        ]
      }
    },
    {
      "name": "simulationReturnData",
      "docs": [
        "NOTE: This is used for hyperlane interop only and should not be used anywhere else",
        "A ridiculous workaround for `<https://github.com/solana-labs/solana/issues/31391>`,",
        "which is a bug where if a simulated transaction's return data ends with zero byte(s),",
        "they end up being incorrectly truncated.",
        "As a workaround, we can (de)serialize data with a trailing non-zero byte."
      ],
      "generics": [
        {
          "kind": "type",
          "name": "t"
        }
      ],
      "type": {
        "kind": "struct",
        "fields": [
          {
            "name": "returnData",
            "type": {
              "generic": "t"
            }
          },
          {
            "name": "trailingByte",
            "type": "u8"
          }
        ]
      }
    },
    {
      "name": "spokeInitializationParams",
      "type": {
        "kind": "struct",
        "fields": [
          {
            "name": "domain",
            "type": "u32"
          },
          {
            "name": "hubDomain",
            "type": "u32"
          },
          {
            "name": "lighthouse",
            "type": "pubkey"
          },
          {
            "name": "watchtower",
            "type": "pubkey"
          },
          {
            "name": "messageGasLimit",
            "type": "u64"
          },
          {
            "name": "owner",
            "type": "pubkey"
          },
          {
            "name": "mailbox",
            "type": "pubkey"
          },
          {
            "name": "igp",
            "type": "pubkey"
          },
          {
            "name": "igpType",
            "type": {
              "defined": {
                "name": "interchainGasPaymasterType"
              }
            }
          },
          {
            "name": "mailboxDispatchAuthorityBump",
            "type": "u8"
          },
          {
            "name": "vaultAuthorityBump",
            "type": "u8"
          }
        ]
      }
    },
    {
      "name": "spokeState",
      "docs": [
        "SpokeState – global configuration."
      ],
      "type": {
        "kind": "struct",
        "fields": [
          {
            "name": "initializedVersion",
            "type": "u8"
          },
          {
            "name": "paused",
            "type": "bool"
          },
          {
            "name": "domain",
            "type": "u32"
          },
          {
            "name": "everclear",
            "type": "u32"
          },
          {
            "name": "lighthouse",
            "type": "pubkey"
          },
          {
            "name": "watchtower",
            "type": "pubkey"
          },
          {
            "name": "messageGasLimit",
            "type": "u64"
          },
          {
            "name": "nonce",
            "type": "u64"
          },
          {
            "name": "owner",
            "type": "pubkey"
          },
          {
            "name": "bump",
            "type": "u8"
          },
          {
            "name": "mailbox",
            "type": "pubkey"
          },
          {
            "name": "mailboxDispatchAuthorityBump",
            "type": "u8"
          },
          {
            "name": "igp",
            "type": "pubkey"
          },
          {
            "name": "igpType",
            "type": {
              "defined": {
                "name": "interchainGasPaymasterType"
              }
            }
          },
          {
            "name": "vaultAuthorityBump",
            "type": "u8"
          },
          {
            "name": "ccipRouter",
            "type": {
              "option": "pubkey"
            }
          },
          {
            "name": "ccipOfframp",
            "type": {
              "option": "pubkey"
            }
          },
          {
            "name": "ccipChainSelector",
            "type": {
              "option": "u64"
            }
          },
          {
            "name": "everclearCcipChainSelector",
            "type": {
              "option": "u64"
            }
          },
          {
            "name": "messagingProvider",
            "type": {
              "defined": {
                "name": "messagingProviderType"
              }
            }
          },
          {
            "name": "everclearGateway",
            "type": {
              "array": [
                "u8",
                32
              ]
            }
          }
        ]
      }
    },
    {
      "name": "tokenAmount",
      "type": {
        "kind": "struct",
        "fields": [
          {
            "name": "token",
            "type": "pubkey"
          },
          {
            "name": "amount",
            "type": "u64"
          }
        ]
      }
    },
    {
      "name": "u256",
      "docs": [
        "Little-endian large integer type",
        "256-bit unsigned integer."
      ],
      "repr": {
        "kind": "c"
      },
      "type": {
        "kind": "struct",
        "fields": [
          {
            "array": [
              "u64",
              4
            ]
          }
        ]
      }
    },
    {
      "name": "unpausedEvent",
      "type": {
        "kind": "struct",
        "fields": []
      }
    },
    {
      "name": "vaultAuthorityBumpUpdatedEvent",
      "type": {
        "kind": "struct",
        "fields": [
          {
            "name": "oldBump",
            "type": "u8"
          },
          {
            "name": "newBump",
            "type": "u8"
          }
        ]
      }
    },
    {
      "name": "watchtowerUpdatedEvent",
      "type": {
        "kind": "struct",
        "fields": [
          {
            "name": "oldWatchtower",
            "type": "pubkey"
          },
          {
            "name": "newWatchtower",
            "type": "pubkey"
          }
        ]
      }
    }
  ]
};
