// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IShieldBridge
/// @notice Interface for ShieldBridge - CCIP emergency cross-chain bridge
interface IShieldBridge {
    /// @notice Emergency bridge tokens to safe chain
    /// @param token Token address to bridge
    /// @param amount Amount to bridge
    /// @param destinationChainSelector Destination chain CCIP selector
    /// @return messageId CCIP message ID for tracking
    function emergencyBridge(
        address token,
        uint256 amount,
        uint64 destinationChainSelector
    ) external payable returns (bytes32 messageId);

    /// @notice Get fee estimate for emergency bridge
    /// @param token Token address to bridge
    /// @param amount Amount to bridge
    /// @param destinationChainSelector Destination chain CCIP selector
    /// @return fee Fee in native token (ETH)
    function getEmergencyBridgeFee(
        address token,
        uint256 amount,
        uint64 destinationChainSelector
    ) external view returns (uint256 fee);

    /// @notice Get all supported destination chains
    /// @return chains Array of supported chain selectors
    function getSupportedChains() external view returns (uint64[] memory);

    /// @notice Get receiver address for a chain
    /// @param chainSelector Chain selector
    /// @return receiver Receiver address on that chain
    function chainToReceiver(uint64 chainSelector) external view returns (address);

    /// @notice Get safe haven address for a chain
    /// @param chainSelector Chain selector
    /// @return safeHaven Safe haven address on that chain
    function chainToSafeHaven(uint64 chainSelector) external view returns (address);

    /// @notice Total emergency bridge operations
    function emergencyBridgeCount() external view returns (uint256);
}
