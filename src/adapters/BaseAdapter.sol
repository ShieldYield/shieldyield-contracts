// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IProtocolAdapter} from "../interfaces/IProtocolAdapter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title BaseAdapter
/// @notice Abstract base contract for protocol adapters
/// @dev All adapters must inherit from this and implement protocol-specific logic
abstract contract BaseAdapter is IProtocolAdapter, Ownable {
    using SafeERC20 for IERC20;

    /// @notice The underlying asset (e.g., USDC)
    address public immutable override asset;

    /// @notice The ShieldVault contract that owns this adapter
    address public shieldVault;

    /// @notice Whether the adapter is paused
    bool public paused;

    event ShieldVaultSet(address indexed shieldVault);
    event Paused(address indexed by);
    event Unpaused(address indexed by);
    event Deposited(uint256 amount, uint256 shares);
    event Withdrawn(uint256 amount, uint256 received);
    event EmergencyWithdrawn(uint256 amount);

    modifier onlyShieldVault() {
        require(msg.sender == shieldVault, "BaseAdapter: only ShieldVault");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "BaseAdapter: paused");
        _;
    }

    constructor(address _asset) Ownable(msg.sender) {
        require(_asset != address(0), "BaseAdapter: zero address");
        asset = _asset;
    }

    /// @notice Set the ShieldVault contract address
    /// @param _shieldVault Address of the ShieldVault
    function setShieldVault(address _shieldVault) external onlyOwner {
        require(_shieldVault != address(0), "BaseAdapter: zero address");
        shieldVault = _shieldVault;
        emit ShieldVaultSet(_shieldVault);
    }

    /// @notice Pause the adapter (emergency use)
    function pause() external onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    /// @notice Unpause the adapter
    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }

    /// @notice Deposit assets into the protocol
    /// @param amount Amount of assets to deposit
    /// @return shares Amount of shares received
    function deposit(uint256 amount) external override onlyShieldVault whenNotPaused returns (uint256 shares) {
        require(amount > 0, "BaseAdapter: zero amount");

        // Transfer assets from ShieldVault to this adapter
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        // Protocol-specific deposit logic
        shares = _deposit(amount);

        emit Deposited(amount, shares);
    }

    /// @notice Withdraw assets from the protocol
    /// @param amount Amount of assets to withdraw
    /// @return withdrawn Actual amount withdrawn
    function withdraw(uint256 amount) external override onlyShieldVault whenNotPaused returns (uint256 withdrawn) {
        require(amount > 0, "BaseAdapter: zero amount");

        // Protocol-specific withdraw logic
        withdrawn = _withdraw(amount);

        // Transfer assets back to ShieldVault
        IERC20(asset).safeTransfer(msg.sender, withdrawn);

        emit Withdrawn(amount, withdrawn);
    }

    /// @notice Emergency withdraw all assets
    /// @return withdrawn Amount of assets withdrawn
    function emergencyWithdraw() external override onlyShieldVault returns (uint256 withdrawn) {
        // Protocol-specific emergency withdraw logic
        withdrawn = _emergencyWithdraw();

        // Transfer all assets back to ShieldVault
        uint256 balance = IERC20(asset).balanceOf(address(this));
        if (balance > 0) {
            IERC20(asset).safeTransfer(msg.sender, balance);
        }

        emit EmergencyWithdrawn(withdrawn);
    }

    /// @notice Rescue stuck tokens (not the main asset)
    /// @param token Address of the token to rescue
    /// @param to Address to send tokens to
    function rescueTokens(address token, address to) external onlyOwner {
        require(token != asset, "BaseAdapter: cannot rescue asset");
        uint256 balance = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransfer(to, balance);
    }

    // ============ Abstract Functions (Protocol-Specific) ============

    /// @notice Protocol-specific deposit implementation
    function _deposit(uint256 amount) internal virtual returns (uint256 shares);

    /// @notice Protocol-specific withdraw implementation
    function _withdraw(uint256 amount) internal virtual returns (uint256 withdrawn);

    /// @notice Protocol-specific emergency withdraw implementation
    function _emergencyWithdraw() internal virtual returns (uint256 withdrawn);
}
