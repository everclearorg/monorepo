// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @title IGasTank
 * @notice Interface for contracts that can receive gas
 */
interface IGasTank {
  /*//////////////////////////////////////////////////////////////
                                EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when gas is deposited
   * @param _sender The sender of the gas
   * @param _amount The amount of gas deposited
   */
  event GasTankDeposited(address indexed _sender, uint256 _amount);

  /**
   * @notice Emitted when gas is withdrawn
   * @param _sender The sender of the gas
   * @param _amount The amount of gas withdrawn
   */
  event GasTankWithdrawn(address indexed _sender, uint256 _amount);

  /**
   * @notice Emitted when gas is spent
   * @param _amount The amount of gas spent
   */
  event GasTankSpent(uint256 indexed _amount);

  /**
   * @notice Emitted when an address is authorized to receive gas
   * @param _address The address that was authorized
   * @param _authorized True if the address was authorized false if unauthorized
   */
  event GasReceiverAuthorized(address indexed _address, bool _authorized);

  /*//////////////////////////////////////////////////////////////
                                ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when the contract has insufficient funds
   */
  error GasTank_InsufficientFunds();

  /**
   * @notice Thrown when the caller is not authorized
   */
  error GasTank_NotAuthorized();

  /**
   * @notice Thrown when a call fails
   */
  error GasTank_CallFailed();

  /*///////////////////////////////////////////////////////////////
                              LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Withdraws gas from the contract
   * @param _amount The amount of gas to withdraw
   */
  function withdrawGas(
    uint256 _amount
  ) external;

  /**
   * @notice Authorizes a contract to receive gas
   * @param _address The address to authorize
   * @param _authorized True if the address is to be authorized
   */
  function authorizeGasReceiver(address _address, bool _authorized) external;

  /*//////////////////////////////////////////////////////////////
                                  VIEWS
    //////////////////////////////////////////////////////////////*/

  /**
   * @notice Checks if an address is authorized to receive gas
   * @param _address The address to check
   * @return _authorized True if the address is authorized
   */
  function isAuthorizedGasReceiver(
    address _address
  ) external view returns (bool _authorized);
}
