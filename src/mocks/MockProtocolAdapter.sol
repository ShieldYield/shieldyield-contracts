// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseAdapter} from "../adapters/BaseAdapter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title MockProtocolAdapter
/// @notice Mock adapter for testing - simulates a lending protocol with real-time yield
/// @dev Calculates yield per second based on APY for gamification effect
contract MockProtocolAdapter is BaseAdapter {
    using SafeERC20 for IERC20;

    string private _protocolName;
    uint256 private _principal;        // Deposited amount (before yield)
    uint256 private _accruedYield;     // Accumulated yield from previous periods
    uint256 private _lastUpdateTime;   // Last time yield was calculated
    uint256 private _apy;              // APY in basis points (500 = 5%)
    bool private _healthy;

    // Constants for yield calculation
    uint256 private constant SECONDS_PER_YEAR = 365 days;
    uint256 private constant BASIS_POINTS = 10000;

    event MockDeposit(uint256 amount);
    event MockWithdraw(uint256 amount);
    event YieldAccrued(uint256 yieldAmount, uint256 newBalance);

    constructor(
        address _asset,
        string memory protocolName_,
        uint256 apy_
    ) BaseAdapter(_asset) {
        _protocolName = protocolName_;
        _apy = apy_;
        _healthy = true;
        _lastUpdateTime = block.timestamp;
    }

    function protocolName() external view override returns (string memory) {
        return _protocolName;
    }

    /// @notice Get current balance including real-time accrued yield
    /// @dev Calculates yield per second: principal * APY / 10000 / 31536000
    /// @return Current balance with accrued yield
    function getBalance() external view override returns (uint256) {
        return _calculateCurrentBalance();
    }

    /// @notice Get balance breakdown
    /// @return principal The deposited amount
    /// @return accruedYield Total yield earned
    /// @return currentBalance Total balance (principal + yield)
    function getBalanceBreakdown() external view returns (
        uint256 principal,
        uint256 accruedYield,
        uint256 currentBalance
    ) {
        uint256 newYield = _calculatePendingYield();
        return (
            _principal,
            _accruedYield + newYield,
            _calculateCurrentBalance()
        );
    }

    /// @notice Get yield earned per second (for UI display)
    /// @return yieldPerSecond Amount of yield earned per second (in token decimals)
    function getYieldPerSecond() external view returns (uint256 yieldPerSecond) {
        // Formula: principal * APY / BASIS_POINTS / SECONDS_PER_YEAR
        // For 10,000 USDC at 5% APY:
        // 10000 * 1e6 * 500 / 10000 / 31536000 = ~15.8 (micro USDC per second)
        if (_principal == 0) return 0;
        return (_principal * _apy) / BASIS_POINTS / SECONDS_PER_YEAR;
    }

    function getCurrentAPY() external view override returns (uint256) {
        return _apy;
    }

    function isHealthy() external view override returns (bool) {
        return _healthy;
    }

    function _deposit(uint256 amount) internal override returns (uint256) {
        // First, materialize any pending yield
        _materializeYield();

        // Then add new deposit to principal
        _principal += amount;

        emit MockDeposit(amount);
        return amount;
    }

    function _withdraw(uint256 amount) internal override returns (uint256) {
        // Materialize yield first
        _materializeYield();

        uint256 totalBalance = _principal + _accruedYield;
        uint256 toWithdraw = amount > totalBalance ? totalBalance : amount;

        // Withdraw from yield first, then principal
        if (toWithdraw <= _accruedYield) {
            _accruedYield -= toWithdraw;
        } else {
            uint256 fromPrincipal = toWithdraw - _accruedYield;
            _accruedYield = 0;
            _principal -= fromPrincipal;
        }

        emit MockWithdraw(toWithdraw);
        return toWithdraw;
    }

    function _emergencyWithdraw() internal override returns (uint256) {
        _materializeYield();
        uint256 totalBalance = _principal + _accruedYield;
        _principal = 0;
        _accruedYield = 0;
        emit MockWithdraw(totalBalance);
        return totalBalance;
    }

    // ============ Internal Functions ============

    /// @notice Calculate current balance including pending yield
    function _calculateCurrentBalance() internal view returns (uint256) {
        return _principal + _accruedYield + _calculatePendingYield();
    }

    /// @notice Calculate pending yield since last update
    function _calculatePendingYield() internal view returns (uint256) {
        if (_principal == 0 || _lastUpdateTime == 0) return 0;

        uint256 elapsed = block.timestamp - _lastUpdateTime;
        if (elapsed == 0) return 0;

        // Yield = principal * APY * elapsed / BASIS_POINTS / SECONDS_PER_YEAR
        // Use careful ordering to avoid overflow while maintaining precision
        return (_principal * _apy * elapsed) / BASIS_POINTS / SECONDS_PER_YEAR;
    }

    /// @notice Materialize pending yield into accruedYield
    function _materializeYield() internal {
        uint256 pendingYield = _calculatePendingYield();
        if (pendingYield > 0) {
            _accruedYield += pendingYield;
            emit YieldAccrued(pendingYield, _principal + _accruedYield);
        }
        _lastUpdateTime = block.timestamp;
    }

    // ============ Mock Control Functions ============

    /// @notice Simulate instant yield accrual (for testing)
    function simulateYield(uint256 yieldAmount) external {
        _accruedYield += yieldAmount;
    }

    /// @notice Simulate loss/exploit (for testing)
    function simulateLoss(uint256 lossAmount) external {
        _materializeYield();
        uint256 totalBalance = _principal + _accruedYield;
        if (lossAmount >= totalBalance) {
            _principal = 0;
            _accruedYield = 0;
        } else {
            // Take from yield first
            if (lossAmount <= _accruedYield) {
                _accruedYield -= lossAmount;
            } else {
                uint256 fromPrincipal = lossAmount - _accruedYield;
                _accruedYield = 0;
                _principal -= fromPrincipal;
            }
        }
    }

    /// @notice Set APY (for testing) - simulates DeFiLlama data update
    /// @param apy_ New APY in basis points (500 = 5%, 1500 = 15%)
    function setAPY(uint256 apy_) external {
        // Materialize yield at old APY before changing
        _materializeYield();
        _apy = apy_;
    }

    /// @notice Set health status (for testing)
    function setHealthy(bool healthy_) external {
        _healthy = healthy_;
    }

    /// @notice Fast-forward time simulation (for demo)
    /// @param secondsToAdd Seconds to simulate passing
    function simulateTimePassing(uint256 secondsToAdd) external {
        // This won't actually change block.timestamp, but we can
        // manually add the yield that would have accrued
        uint256 simulatedYield = (_principal * _apy * secondsToAdd) / BASIS_POINTS / SECONDS_PER_YEAR;
        _accruedYield += simulatedYield;
    }
}
