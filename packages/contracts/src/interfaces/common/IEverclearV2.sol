// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/**
 * @title IEverclear
 * @notice Common interface for EverclearHub and EverclearSpoke
 */
interface IEverclearV2 {
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
   * @param origin The origin chain of the intent
   * @param destinations The possible destination chains of the intent
   * @param nonce The nonce of the intent
   * @param timestamp The timestamp of the intent
   * @param ttl The time to live of the intent
   * @param amount The amount of the intent asset normalized to 18 decimals
   * @param amountOutMin The minimum amount of the output asset that the intent solver should return
   * @param data The data of the intent
   */
  struct Intent {
    bytes32 initiator;
    bytes32 receiver;
    bytes32 inputAsset;
    bytes32 outputAsset;
    uint32 origin;
    uint64 nonce;
    uint48 timestamp;
    uint48 ttl;
    uint256 amount;
    uint256 amountOutMin;
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
  struct DeprecatedFillMessage {
    bytes32 intentId;
    bytes32 solver;
    bytes32 initiator;
    uint24 fee;
    uint48 executionTimestamp;
  }

  /**
   * @notice The structure of a fill message
   * @param intentId The ID of the intent
   * @param solver The address of the intent solver in bytes32 format
   * @param initiator The address of the intent initiator
   * @param intentInputAsset The input asset of the intent (i.e. asset the solver will be repaid in)
   * @param intentOrigin The origin chain of the intent
   * @param amountOut The amount being sent to the user by the solver
   * @param destinations The settlement destinations for the fill
   * @param executionTimestamp The execution timestamp of the intent
   */
  struct FillMessage {
    bytes32 intentId;
    bytes32 solver;
    bytes32 initiator;
    bytes32 intentInputAsset;
    uint32 intentOrigin;
    uint256 amountOut;
    uint32[] destinations;
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
