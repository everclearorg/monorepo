// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

/**
 * @title IPermit2
 * @notice Interface for permit2
 */
interface IPermit2 {
  /*///////////////////////////////////////////////////////////////
                                STRUCTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Struct for token and amount in a permit message
   * @param token The token to transfer
   * @param amount The amount to transfer
   */
  struct TokenPermissions {
    IERC20 token;
    uint256 amount;
  }

  /**
   * @notice Struct for the permit2 message
   * @param permitted The permitted token and amount
   * @param nonce The unique identifier for this permit
   * @param deadline The expiration for this permit
   */
  struct PermitTransferFrom {
    TokenPermissions permitted;
    uint256 nonce;
    uint256 deadline;
  }

  /**
   * @notice Struct for the transfer details for permitTransferFrom()
   * @param to The recipient of the tokens
   * @param requestedAmount The amount to transfer
   */
  struct SignatureTransferDetails {
    address to;
    uint256 requestedAmount;
  }

  /*///////////////////////////////////////////////////////////////
                                LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Consume a permit2 message and transfer tokens
   * @param permit The permit message
   * @param transferDetails The transfer details
   * @param owner The owner of the tokens
   * @param signature The signature of the permit
   */
  function permitTransferFrom(
    PermitTransferFrom calldata permit,
    SignatureTransferDetails calldata transferDetails,
    address owner,
    bytes calldata signature
  ) external;
}
