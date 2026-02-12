// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

interface IMintableERC20 is IERC20 {
    function mint(address to, uint256 amount) external;
}

/// @title Faucet
/// @notice Simple faucet for testnet - allows users to claim test USDC
/// @dev For hackathon demo - judges can easily get test tokens
contract Faucet is Ownable {
    /// @notice The token to distribute (MockUSDC)
    IMintableERC20 public token;

    /// @notice Amount to give per claim (default: 10,000 USDC)
    uint256 public claimAmount = 10_000 * 1e6; // 6 decimals

    /// @notice Cooldown between claims (default: 1 hour)
    uint256 public cooldown = 1 hours;

    /// @notice Last claim timestamp per address
    mapping(address => uint256) public lastClaim;

    /// @notice Total claims made
    uint256 public totalClaims;

    event Claimed(address indexed user, uint256 amount);
    event ClaimAmountUpdated(uint256 oldAmount, uint256 newAmount);
    event CooldownUpdated(uint256 oldCooldown, uint256 newCooldown);

    constructor(address _token) Ownable(msg.sender) {
        require(_token != address(0), "Faucet: zero address");
        token = IMintableERC20(_token);
    }

    /// @notice Claim test USDC - one click for judges!
    function claim() external {
        require(
            block.timestamp >= lastClaim[msg.sender] + cooldown,
            "Faucet: please wait before claiming again"
        );

        lastClaim[msg.sender] = block.timestamp;
        totalClaims++;

        // Mint tokens directly to user
        token.mint(msg.sender, claimAmount);

        emit Claimed(msg.sender, claimAmount);
    }

    /// @notice Check if user can claim
    /// @param user Address to check
    /// @return canClaimNow Whether user can claim now
    /// @return timeUntilNextClaim Seconds until next claim (0 if can claim now)
    function canClaim(address user) external view returns (bool canClaimNow, uint256 timeUntilNextClaim) {
        uint256 nextClaimTime = lastClaim[user] + cooldown;
        if (block.timestamp >= nextClaimTime) {
            return (true, 0);
        }
        return (false, nextClaimTime - block.timestamp);
    }

    /// @notice Get user's current balance
    /// @param user Address to check
    /// @return balance User's token balance
    function getBalance(address user) external view returns (uint256 balance) {
        return token.balanceOf(user);
    }

    // ============ Admin Functions ============

    /// @notice Update claim amount
    /// @param newAmount New amount per claim
    function setClaimAmount(uint256 newAmount) external onlyOwner {
        emit ClaimAmountUpdated(claimAmount, newAmount);
        claimAmount = newAmount;
    }

    /// @notice Update cooldown period
    /// @param newCooldown New cooldown in seconds
    function setCooldown(uint256 newCooldown) external onlyOwner {
        emit CooldownUpdated(cooldown, newCooldown);
        cooldown = newCooldown;
    }

    /// @notice Disable cooldown for demo (judges can claim multiple times)
    function disableCooldown() external onlyOwner {
        cooldown = 0;
    }
}
