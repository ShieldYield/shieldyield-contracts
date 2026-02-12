// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IProtocolAdapter {
    /// @notice Returns the name of the protocol
    function protocolName() external view returns (string memory);

    /// @notice Returns the underlying asset (e.g., USDC)
    function asset() external view returns (address);

    /// @notice Deposit assets into the protocol
    /// @param amount Amount of assets to deposit
    /// @return shares Amount of shares/receipt tokens received
    function deposit(uint256 amount) external returns (uint256 shares);

    /// @notice Withdraw assets from the protocol
    /// @param amount Amount of assets to withdraw
    /// @return withdrawn Actual amount withdrawn
    function withdraw(uint256 amount) external returns (uint256 withdrawn);

    /// @notice Emergency withdraw all assets (may incur penalties)
    /// @return withdrawn Amount of assets withdrawn
    function emergencyWithdraw() external returns (uint256 withdrawn);

    /// @notice Get current balance in underlying asset terms
    /// @return balance Current balance in asset terms
    function getBalance() external view returns (uint256 balance);

    /// @notice Get current APY (in basis points, e.g., 500 = 5%)
    /// @return apy Current APY in basis points
    function getCurrentAPY() external view returns (uint256 apy);

    /// @notice Check if the adapter is healthy and operational
    /// @return healthy True if the protocol is operational
    function isHealthy() external view returns (bool healthy);
}
