// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @title IEverclear
 * @notice Common interface for EverclearHub and EverclearSpoke
 */
interface IEverclear {
  /*//////////////////////////////////////////////////////////////
                                ENUMS
    //////////////////////////////////////////////////////////////*/
  /**
   * @notice Enum representing statuses of an intent
   */
  enum IntentStatus {
    NONE, // 0
    ADDED, // 1
    DEPOSIT_PROCESSED, // 2
    FILLED, // 3
    ADDED_AND_FILLED, // 4
    INVOICED, // 5
    SETTLED, // 6
    SETTLED_AND_MANUALLY_EXECUTED, // 7
    UNSUPPORTED, // 8
    UNSUPPORTED_RETURNED // 9

  }

  /**
   * @notice Enum representing asset strategies
   */
  enum Strategy {
    DEFAULT,
    XERC20
  }

  /*///////////////////////////////////////////////////////////////
                            STRUCTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice The structure of an intent
   * @param initiator The address of the intent initiator
   * @param receiver The address of the intent receiver
   * @param inputAsset The address of the intent asset on origin
   * @param outputAsset The address of the intent asset on destination
   * @param maxFee The maximum fee that can be taken by solvers
   * @param origin The origin chain of the intent
   * @param destinations The possible destination chains of the intent
   * @param nonce The nonce of the intent
   * @param timestamp The timestamp of the intent
   * @param ttl The time to live of the intent
   * @param amount The amount of the intent asset normalized to 18 decimals
   * @param data The data of the intent
   */
  struct Intent {
    bytes32 initiator;
    bytes32 receiver;
    bytes32 inputAsset;
    bytes32 outputAsset;
    uint24 maxFee;
    uint32 origin;
    uint64 nonce;
    uint48 timestamp;
    uint48 ttl;
    uint256 amount;
    uint32[] destinations;
    bytes data;
  }

  /**
   * @notice The structure of a fill message
   * @param intentId The ID of the intent
   * @param solver The address of the intent solver in bytes32 format
   * @param initiator The address of the intent initiator
   * @param fee The total fee of the expressed in dbps, represents the solver fee plus the sum of protocol fees for the token
   * @param executionTimestamp The execution timestamp of the intent
   */
  struct FillMessage {
    bytes32 intentId;
    bytes32 solver;
    bytes32 initiator;
    uint24 fee;
    uint48 executionTimestamp;
  }

  /**
   * @notice The structure of a settlement
   * @param intentId The ID of the intent
   * @param amount The amount of the asset
   * @param asset The address of the asset
   * @param recipient The address of the recipient
   * @param updateVirtualBalance If set to true, the settlement will not be transferred to the recipient in spoke domain and the virtual balance will be increased
   */
  struct Settlement {
    bytes32 intentId;
    uint256 amount;
    bytes32 asset;
    bytes32 recipient;
    bool updateVirtualBalance;
  }
}
