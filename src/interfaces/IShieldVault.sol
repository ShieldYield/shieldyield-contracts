// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IRiskRegistry} from "./IRiskRegistry.sol";

interface IShieldVault {
    enum RiskTier {
        LOW,    // 50% allocation - Aave, Compound
        MEDIUM, // 30% allocation - Morpho, established LPs
        HIGH    // 20% allocation - Newer protocols, higher APY
    }

    struct PoolAllocation {
        address adapter;
        RiskTier tier;
        uint256 targetWeight;  // in basis points (5000 = 50%)
        uint256 currentAmount;
        bool isActive;
    }

    struct UserPosition {
        uint256 totalDeposited;
        uint256 totalShares;
        uint256 lastDepositTime;
    }

    event Deposited(
        address indexed user,
        uint256 amount,
        uint256 shares
    );

    event Withdrawn(
        address indexed user,
        uint256 amount,
        uint256 shares
    );

    event Rebalanced(
        address indexed triggeredBy,
        uint256 timestamp
    );

    event EmergencyWithdrawExecuted(
        address indexed protocol,
        uint256 amountWithdrawn,
        IRiskRegistry.ThreatLevel threatLevel,
        string reason
    );

    event ShieldActivated(
        address indexed user,
        address indexed fromProtocol,
        uint256 amountSaved,
        string reason
    );

    event PoolAdded(
        address indexed adapter,
        RiskTier tier,
        uint256 targetWeight
    );

    event PoolRemoved(address indexed adapter);

    // User functions
    function deposit(uint256 amount) external returns (uint256 shares);
    function withdraw(uint256 shares) external returns (uint256 amount);
    function getUserPosition(address user) external view returns (UserPosition memory);
    function getUserBalance(address user) external view returns (uint256);

    // CRE-only functions
    function rebalance() external;
    function emergencyWithdraw(address adapter, string calldata reason) external;
    function partialWithdraw(address adapter, uint256 percentage, string calldata reason) external;

    // View functions
    function getTotalAssets() external view returns (uint256);
    function getPoolAllocations() external view returns (PoolAllocation[] memory);
    function previewDeposit(uint256 amount) external view returns (uint256 shares);
    function previewWithdraw(uint256 shares) external view returns (uint256 amount);
}
