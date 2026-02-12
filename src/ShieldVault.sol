// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IShieldVault} from "./interfaces/IShieldVault.sol";
import {IProtocolAdapter} from "./interfaces/IProtocolAdapter.sol";
import {IRiskRegistry} from "./interfaces/IRiskRegistry.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title ShieldVault
/// @notice Main vault contract for ShieldYield - AI-powered DeFi guardian
/// @dev Manages user deposits, distributes across risk-tiered pools, and handles emergency actions
contract ShieldVault is IShieldVault, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // ============ Constants ============

    /// @notice Basis points denominator (100% = 10000)
    uint256 public constant BASIS_POINTS = 10000;

    /// @notice Minimum deposit amount (to prevent dust)
    uint256 public constant MIN_DEPOSIT = 1e6; // 1 USDC (6 decimals)

    /// @notice Partial withdrawal percentages for WARNING level
    uint256 public constant WARNING_WITHDRAW_PERCENT = 5000; // 50%

    // ============ State Variables ============

    /// @notice The underlying asset (e.g., USDC)
    IERC20 public immutable asset;

    /// @notice The RiskRegistry contract
    IRiskRegistry public riskRegistry;

    /// @notice Total shares issued
    uint256 public totalShares;

    /// @notice Safe haven adapter (where funds go during emergency)
    address public safeHaven;

    /// @notice CRE (Chainlink Runtime Environment) address - only this can trigger actions
    address public creAddress;

    /// @notice Whether the vault is paused
    bool public paused;

    /// @notice Pool allocations array
    PoolAllocation[] private _pools;

    /// @notice User positions mapping
    mapping(address => UserPosition) private _positions;

    /// @notice Adapter address => pool index mapping
    mapping(address => uint256) private _poolIndex;

    /// @notice Adapter address => is registered
    mapping(address => bool) private _isPool;

    // ============ Modifiers ============

    modifier onlyCRE() {
        require(msg.sender == creAddress, "ShieldVault: only CRE");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "ShieldVault: paused");
        _;
    }

    // ============ Constructor ============

    constructor(
        address _asset,
        address _riskRegistry
    ) Ownable(msg.sender) {
        require(_asset != address(0), "ShieldVault: zero asset address");
        require(_riskRegistry != address(0), "ShieldVault: zero registry address");

        asset = IERC20(_asset);
        riskRegistry = IRiskRegistry(_riskRegistry);
    }

    // ============ Admin Functions ============

    /// @notice Set the CRE address (only CRE can trigger rebalance/emergency)
    /// @param _creAddress Address of the CRE contract/node
    function setCREAddress(address _creAddress) external onlyOwner {
        require(_creAddress != address(0), "ShieldVault: zero address");
        creAddress = _creAddress;
    }

    /// @notice Set the safe haven adapter (where funds go during CRITICAL emergencies)
    /// @param _safeHaven Address of the safe haven adapter
    function setSafeHaven(address _safeHaven) external onlyOwner {
        require(_safeHaven != address(0), "ShieldVault: zero address");
        require(_isPool[_safeHaven], "ShieldVault: not a registered pool");
        safeHaven = _safeHaven;
    }

    /// @notice Pause/unpause the vault
    /// @param _paused Whether to pause
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }

    /// @notice Add a new pool (adapter) to the vault
    /// @param adapter Address of the protocol adapter
    /// @param tier Risk tier of the pool
    /// @param targetWeight Target allocation weight in basis points
    function addPool(
        address adapter,
        RiskTier tier,
        uint256 targetWeight
    ) external onlyOwner {
        require(adapter != address(0), "ShieldVault: zero address");
        require(!_isPool[adapter], "ShieldVault: pool exists");
        require(targetWeight <= BASIS_POINTS, "ShieldVault: weight exceeds 100%");

        _poolIndex[adapter] = _pools.length;
        _isPool[adapter] = true;

        _pools.push(PoolAllocation({
            adapter: adapter,
            tier: tier,
            targetWeight: targetWeight,
            currentAmount: 0,
            isActive: true
        }));

        // Approve adapter to pull funds
        asset.approve(adapter, type(uint256).max);

        emit PoolAdded(adapter, tier, targetWeight);
    }

    /// @notice Remove a pool from the vault
    /// @param adapter Address of the adapter to remove
    function removePool(address adapter) external onlyOwner {
        require(_isPool[adapter], "ShieldVault: pool not found");

        uint256 index = _poolIndex[adapter];
        PoolAllocation storage pool = _pools[index];

        // Withdraw all funds from the pool first
        if (pool.currentAmount > 0) {
            IProtocolAdapter(adapter).emergencyWithdraw();
            pool.currentAmount = 0;
        }

        pool.isActive = false;
        _isPool[adapter] = false;

        emit PoolRemoved(adapter);
    }

    /// @notice Update target weight for a pool
    /// @param adapter Address of the adapter
    /// @param newWeight New target weight in basis points
    function updatePoolWeight(address adapter, uint256 newWeight) external onlyOwner {
        require(_isPool[adapter], "ShieldVault: pool not found");
        require(newWeight <= BASIS_POINTS, "ShieldVault: weight exceeds 100%");

        _pools[_poolIndex[adapter]].targetWeight = newWeight;
    }

    // ============ User Functions ============

    /// @notice Deposit assets into the vault
    /// @param amount Amount of assets to deposit
    /// @return shares Amount of shares minted
    function deposit(uint256 amount) external nonReentrant whenNotPaused returns (uint256 shares) {
        require(amount >= MIN_DEPOSIT, "ShieldVault: below minimum");

        // Calculate shares
        uint256 totalAssets = getTotalAssets();
        if (totalShares == 0 || totalAssets == 0) {
            shares = amount;
        } else {
            shares = (amount * totalShares) / totalAssets;
        }

        require(shares > 0, "ShieldVault: zero shares");

        // Transfer assets from user
        asset.safeTransferFrom(msg.sender, address(this), amount);

        // Update user position
        UserPosition storage position = _positions[msg.sender];
        position.totalDeposited += amount;
        position.totalShares += shares;
        position.lastDepositTime = block.timestamp;

        // Update total shares
        totalShares += shares;

        // Distribute to pools based on target weights
        _distributeToPoolsProportionally(amount);

        emit Deposited(msg.sender, amount, shares);
    }

    /// @notice Withdraw assets from the vault
    /// @param shares Amount of shares to redeem
    /// @return amount Amount of assets withdrawn
    function withdraw(uint256 shares) external nonReentrant whenNotPaused returns (uint256 amount) {
        require(shares > 0, "ShieldVault: zero shares");

        UserPosition storage position = _positions[msg.sender];
        require(position.totalShares >= shares, "ShieldVault: insufficient shares");

        // Calculate amount
        uint256 totalAssets = getTotalAssets();
        amount = (shares * totalAssets) / totalShares;

        // Update user position
        position.totalShares -= shares;

        // Update total shares
        totalShares -= shares;

        // Withdraw from pools proportionally
        uint256 withdrawn = _withdrawFromPoolsProportionally(amount);

        // Transfer to user
        asset.safeTransfer(msg.sender, withdrawn);

        emit Withdrawn(msg.sender, withdrawn, shares);
    }

    /// @notice Get user position
    /// @param user Address of the user
    /// @return User position struct
    function getUserPosition(address user) external view returns (UserPosition memory) {
        return _positions[user];
    }

    /// @notice Get user balance in asset terms
    /// @param user Address of the user
    /// @return balance User's balance in underlying asset
    function getUserBalance(address user) external view returns (uint256 balance) {
        UserPosition storage position = _positions[user];
        if (position.totalShares == 0 || totalShares == 0) {
            return 0;
        }
        return (position.totalShares * getTotalAssets()) / totalShares;
    }

    // ============ CRE Functions ============

    /// @notice Rebalance pools based on current target weights (CRE only)
    function rebalance() external onlyCRE nonReentrant {
        uint256 totalAssets = getTotalAssets();
        if (totalAssets == 0) return;

        // First, calculate target amounts for each pool
        uint256[] memory targetAmounts = new uint256[](_pools.length);
        uint256 totalWeight = _getTotalActiveWeight();

        for (uint256 i = 0; i < _pools.length; i++) {
            if (_pools[i].isActive && totalWeight > 0) {
                targetAmounts[i] = (totalAssets * _pools[i].targetWeight) / totalWeight;
            }
        }

        // Withdraw from over-allocated pools
        for (uint256 i = 0; i < _pools.length; i++) {
            if (_pools[i].isActive && _pools[i].currentAmount > targetAmounts[i]) {
                uint256 excess = _pools[i].currentAmount - targetAmounts[i];
                uint256 withdrawn = IProtocolAdapter(_pools[i].adapter).withdraw(excess);
                _pools[i].currentAmount -= withdrawn;
            }
        }

        // Deposit to under-allocated pools
        uint256 available = asset.balanceOf(address(this));
        for (uint256 i = 0; i < _pools.length; i++) {
            if (_pools[i].isActive && _pools[i].currentAmount < targetAmounts[i]) {
                uint256 needed = targetAmounts[i] - _pools[i].currentAmount;
                uint256 toDeposit = needed > available ? available : needed;
                if (toDeposit > 0) {
                    IProtocolAdapter(_pools[i].adapter).deposit(toDeposit);
                    _pools[i].currentAmount += toDeposit;
                    available -= toDeposit;
                }
            }
        }

        emit Rebalanced(msg.sender, block.timestamp);
    }

    /// @notice Emergency withdraw from a specific adapter (CRE only)
    /// @param adapter Address of the adapter
    /// @param reason Reason for the emergency withdrawal
    function emergencyWithdraw(
        address adapter,
        string calldata reason
    ) external onlyCRE nonReentrant {
        require(_isPool[adapter], "ShieldVault: pool not found");

        uint256 index = _poolIndex[adapter];
        PoolAllocation storage pool = _pools[index];

        require(pool.currentAmount > 0, "ShieldVault: no funds in pool");

        uint256 amountBefore = pool.currentAmount;

        // Emergency withdraw all from the adapter
        uint256 withdrawn = IProtocolAdapter(adapter).emergencyWithdraw();
        pool.currentAmount = 0;

        // Get threat level from registry
        IRiskRegistry.ThreatLevel threatLevel = riskRegistry.getThreatLevel(adapter);

        // Log the shield action for affected users
        // Note: In production, would need to track per-user allocation
        riskRegistry.logShieldAction(
            address(this), // Could be expanded to track per-user
            adapter,
            threatLevel,
            withdrawn,
            reason
        );

        // If CRITICAL and safe haven exists, move funds there
        if (threatLevel == IRiskRegistry.ThreatLevel.CRITICAL && safeHaven != address(0)) {
            uint256 balance = asset.balanceOf(address(this));
            if (balance > 0) {
                IProtocolAdapter(safeHaven).deposit(balance);
                _pools[_poolIndex[safeHaven]].currentAmount += balance;
            }
        }

        emit EmergencyWithdrawExecuted(adapter, withdrawn, threatLevel, reason);
        emit ShieldActivated(address(this), adapter, withdrawn, reason);
    }

    /// @notice Partial withdraw from a specific adapter (CRE only, for WARNING level)
    /// @param adapter Address of the adapter
    /// @param percentage Percentage to withdraw (in basis points, e.g., 5000 = 50%)
    /// @param reason Reason for the partial withdrawal
    function partialWithdraw(
        address adapter,
        uint256 percentage,
        string calldata reason
    ) external onlyCRE nonReentrant {
        require(_isPool[adapter], "ShieldVault: pool not found");
        require(percentage <= BASIS_POINTS, "ShieldVault: percentage exceeds 100%");

        uint256 index = _poolIndex[adapter];
        PoolAllocation storage pool = _pools[index];

        require(pool.currentAmount > 0, "ShieldVault: no funds in pool");

        uint256 amountToWithdraw = (pool.currentAmount * percentage) / BASIS_POINTS;
        uint256 withdrawn = IProtocolAdapter(adapter).withdraw(amountToWithdraw);
        pool.currentAmount -= withdrawn;

        // Get threat level from registry
        IRiskRegistry.ThreatLevel threatLevel = riskRegistry.getThreatLevel(adapter);

        // Log the shield action
        riskRegistry.logShieldAction(
            address(this),
            adapter,
            threatLevel,
            withdrawn,
            reason
        );

        emit EmergencyWithdrawExecuted(adapter, withdrawn, threatLevel, reason);
    }

    // ============ View Functions ============

    /// @notice Get total assets across all pools
    /// @return total Total assets in the vault
    function getTotalAssets() public view returns (uint256 total) {
        // Assets held directly in vault
        total = asset.balanceOf(address(this));

        // Assets in each pool
        for (uint256 i = 0; i < _pools.length; i++) {
            if (_pools[i].isActive) {
                total += IProtocolAdapter(_pools[i].adapter).getBalance();
            }
        }
    }

    /// @notice Get all pool allocations
    /// @return Array of pool allocations
    function getPoolAllocations() external view returns (PoolAllocation[] memory) {
        return _pools;
    }

    /// @notice Preview shares for a deposit amount
    /// @param amount Amount to deposit
    /// @return shares Expected shares
    function previewDeposit(uint256 amount) external view returns (uint256 shares) {
        uint256 totalAssets = getTotalAssets();
        if (totalShares == 0 || totalAssets == 0) {
            shares = amount;
        } else {
            shares = (amount * totalShares) / totalAssets;
        }
    }

    /// @notice Preview amount for a share withdrawal
    /// @param shares Shares to redeem
    /// @return amount Expected amount
    function previewWithdraw(uint256 shares) external view returns (uint256 amount) {
        if (totalShares == 0) {
            return 0;
        }
        amount = (shares * getTotalAssets()) / totalShares;
    }

    /// @notice Get number of active pools
    /// @return count Number of active pools
    function getActivePoolCount() external view returns (uint256 count) {
        for (uint256 i = 0; i < _pools.length; i++) {
            if (_pools[i].isActive) {
                count++;
            }
        }
    }

    // ============ Internal Functions ============

    /// @notice Distribute assets to pools proportionally based on weights
    /// @param amount Amount to distribute
    function _distributeToPoolsProportionally(uint256 amount) internal {
        uint256 totalWeight = _getTotalActiveWeight();
        if (totalWeight == 0) return;

        uint256 remaining = amount;

        for (uint256 i = 0; i < _pools.length; i++) {
            if (_pools[i].isActive && _pools[i].targetWeight > 0) {
                uint256 poolAmount = (amount * _pools[i].targetWeight) / totalWeight;

                // Last pool gets remaining to handle rounding
                if (i == _pools.length - 1 || poolAmount > remaining) {
                    poolAmount = remaining;
                }

                if (poolAmount > 0) {
                    IProtocolAdapter(_pools[i].adapter).deposit(poolAmount);
                    _pools[i].currentAmount += poolAmount;
                    remaining -= poolAmount;
                }
            }
        }
    }

    /// @notice Withdraw assets from pools proportionally
    /// @param amount Amount to withdraw
    /// @return totalWithdrawn Total amount withdrawn
    function _withdrawFromPoolsProportionally(uint256 amount) internal returns (uint256 totalWithdrawn) {
        uint256 totalInPools = 0;
        for (uint256 i = 0; i < _pools.length; i++) {
            if (_pools[i].isActive) {
                totalInPools += _pools[i].currentAmount;
            }
        }

        if (totalInPools == 0) {
            // Use vault balance directly
            return amount > asset.balanceOf(address(this)) ? asset.balanceOf(address(this)) : amount;
        }

        uint256 remaining = amount;

        for (uint256 i = 0; i < _pools.length && remaining > 0; i++) {
            if (_pools[i].isActive && _pools[i].currentAmount > 0) {
                uint256 poolShare = (amount * _pools[i].currentAmount) / totalInPools;
                poolShare = poolShare > remaining ? remaining : poolShare;
                poolShare = poolShare > _pools[i].currentAmount ? _pools[i].currentAmount : poolShare;

                if (poolShare > 0) {
                    uint256 withdrawn = IProtocolAdapter(_pools[i].adapter).withdraw(poolShare);
                    _pools[i].currentAmount -= withdrawn;
                    totalWithdrawn += withdrawn;
                    remaining -= withdrawn;
                }
            }
        }

        // Add any vault balance
        uint256 vaultBalance = asset.balanceOf(address(this));
        if (remaining > 0 && vaultBalance > 0) {
            uint256 fromVault = remaining > vaultBalance ? vaultBalance : remaining;
            totalWithdrawn += fromVault;
        }
    }

    /// @notice Get total active weight across all pools
    /// @return total Total weight of active pools
    function _getTotalActiveWeight() internal view returns (uint256 total) {
        for (uint256 i = 0; i < _pools.length; i++) {
            if (_pools[i].isActive) {
                total += _pools[i].targetWeight;
            }
        }
    }
}
