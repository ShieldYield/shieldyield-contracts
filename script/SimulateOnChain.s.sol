// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockProtocolAdapter} from "../src/mocks/MockProtocolAdapter.sol";
import {RiskRegistry} from "../src/RiskRegistry.sol";
import {ShieldVault} from "../src/ShieldVault.sol";
import {Faucet} from "../src/Faucet.sol";

/// @title SimulateOnChain
/// @notice End-to-end on-chain simulation on Arbitrum Sepolia
/// @dev Each step produces a real TxHash + event logs visible on Arbiscan
///
/// Usage (dry-run):
///   forge script script/SimulateOnChain.s.sol --rpc-url arbitrum_sepolia -vvv
///
/// Usage (broadcast — real transactions):
///   forge script script/SimulateOnChain.s.sol --rpc-url arbitrum_sepolia --broadcast -vvv
///
/// Prerequisites:
///   - PRIVATE_KEY env var set (deployer wallet)
///   - Deployer must have ETH on Arbitrum Sepolia for gas
///   - Deployer must be set as CRE address on ShieldVault
///   - Deployer must be authorized updater on RiskRegistry
contract SimulateOnChain is Script {
    // ============ Deployed Contract Addresses (Arbitrum Sepolia) ============
    address constant USDC = 0x4d107C58DCda55ea6ea2B162d9C434F710E42038;
    address constant FAUCET = 0x6E860FF2C4ea6b01815D74E54859Cdd9DD172256;
    address constant RISK_REGISTRY = 0xa23BE1297F836FF7D4E3297320ff16dbc7903e6D;
    address constant SHIELD_VAULT = 0xcFBd47c63D284A8F824e586596Df4d5c57326c8B;

    // Adapter addresses
    address constant AAVE_ADAPTER = 0xB81961aA49d7E834404e299e688B3Dc09a5EFe5a;
    address constant COMPOUND_ADAPTER =
        0xcc547a2B0f18b34095623809977D54cfe306BEBF;
    address constant MORPHO_ADAPTER =
        0x5f8A64Bc67f23b8d5d02c7CFE187AD42D59f1D59;
    address constant YIELDMAX_ADAPTER =
        0x5EbD6F3DA76C2B9C9d6aAC89DA08c388EaB2B3cb;

    // Deposit amount: 10,000 USDC (6 decimals)
    uint256 constant DEPOSIT_AMOUNT = 10_000 * 1e6;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log(
            "=========================================================="
        );
        console.log(
            "  ShieldYield -- On-Chain E2E Simulation (Arbitrum Sepolia)"
        );
        console.log(
            "=========================================================="
        );
        console.log("Deployer/CRE:", deployer);
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // ====================================================================
        // STEP 1: Claim test USDC from Faucet
        // ====================================================================
        console.log("------------------------------------------------------");
        console.log("STEP 1: Claiming 10,000 test USDC from Faucet...");
        console.log("------------------------------------------------------");

        uint256 usdcBefore = IERC20(USDC).balanceOf(deployer);
        Faucet(FAUCET).claim();
        uint256 usdcAfter = IERC20(USDC).balanceOf(deployer);

        console.log("  USDC balance before:", usdcBefore / 1e6);
        console.log("  USDC balance after: ", usdcAfter / 1e6);
        console.log("  -> Faucet.claim() TX sent");
        console.log("");

        // ====================================================================
        // STEP 2: Approve & Deposit into ShieldVault
        // ====================================================================
        console.log("------------------------------------------------------");
        console.log("STEP 2: Approve & Deposit 10,000 USDC into ShieldVault");
        console.log("------------------------------------------------------");

        IERC20(USDC).approve(SHIELD_VAULT, DEPOSIT_AMOUNT);
        console.log("  -> USDC.approve(ShieldVault, 10000 USDC) TX sent");

        uint256 shares = ShieldVault(SHIELD_VAULT).deposit(DEPOSIT_AMOUNT);
        console.log("  -> ShieldVault.deposit(10000 USDC) TX sent");
        console.log("  Shares received:", shares / 1e6);
        console.log("  EVENT: Deposited(deployer, 10000 USDC, shares)");
        console.log("");

        // Verify distribution
        _printAdapterBalances("After deposit");

        // ====================================================================
        // STEP 3: Update YieldMax risk score to WARNING (65)
        // ====================================================================
        console.log("------------------------------------------------------");
        console.log("STEP 3: AI Sentinel detects threat -> WARNING (65/100)");
        console.log("------------------------------------------------------");
        console.log("  Simulating: 'YieldMax unauthorized admin key access'");

        RiskRegistry(RISK_REGISTRY).updateRiskScore(
            YIELDMAX_ADAPTER,
            65,
            "AI Sentinel: unauthorized admin key access detected on YieldMax"
        );
        console.log(
            "  -> RiskRegistry.updateRiskScore(YieldMax, 65, reason) TX sent"
        );
        console.log(
            "  EVENT: RiskScoreUpdated(YieldMax, oldScore, 65, WARNING)"
        );
        console.log("");

        // ====================================================================
        // STEP 4: Shield Execute — Partial Withdraw 50% from YieldMax
        // ====================================================================
        console.log("------------------------------------------------------");
        console.log("STEP 4: Shield Execute (WARNING) -> Partial Withdraw 50%");
        console.log("------------------------------------------------------");
        console.log("  CRE triggers partialWithdraw on YieldMax...");

        ShieldVault(SHIELD_VAULT).partialWithdraw(
            YIELDMAX_ADAPTER,
            5000, // 50% in basis points
            "ShieldYield WARNING: Risk score 65/100. Partial withdrawal triggered."
        );
        console.log(
            "  -> ShieldVault.partialWithdraw(YieldMax, 50%, reason) TX sent"
        );
        console.log(
            "  EVENT: EmergencyWithdrawExecuted(YieldMax, amount, WARNING, reason)"
        );
        console.log(
            "  EVENT: ShieldActionLogged(vault, YieldMax, WARNING, amount, reason)"
        );
        console.log("");

        _printAdapterBalances("After partial withdraw (50%)");

        // ====================================================================
        // STEP 5: Escalate YieldMax risk score to CRITICAL (92)
        // ====================================================================
        console.log("------------------------------------------------------");
        console.log("STEP 5: THREAT ESCALATION -> CRITICAL (92/100)");
        console.log("------------------------------------------------------");
        console.log("  Simulating: 'YieldMax hacked! $15M drained'");

        RiskRegistry(RISK_REGISTRY).updateRiskScore(
            YIELDMAX_ADAPTER,
            92,
            "AI Sentinel CRITICAL: YieldMax exploited, liquidity pool drained"
        );
        console.log(
            "  -> RiskRegistry.updateRiskScore(YieldMax, 92, reason) TX sent"
        );
        console.log("  EVENT: RiskScoreUpdated(YieldMax, 65, 92, CRITICAL)");
        console.log("");

        // Also mark adapter as unhealthy (optional — for FE display)
        MockProtocolAdapter(YIELDMAX_ADAPTER).setHealthy(false);
        console.log("  -> YieldMaxAdapter.setHealthy(false) TX sent");
        console.log("");

        // ====================================================================
        // STEP 6: Shield Execute — Emergency Withdraw 100% from YieldMax
        // ====================================================================
        console.log("------------------------------------------------------");
        console.log("STEP 6: Shield Execute (CRITICAL) -> EMERGENCY WITHDRAW");
        console.log("------------------------------------------------------");
        console.log("  CRE triggers emergencyWithdraw on YieldMax...");

        ShieldVault(SHIELD_VAULT).emergencyWithdraw(
            YIELDMAX_ADAPTER,
            "ShieldYield CRITICAL: Risk score 92/100. Emergency full withdrawal."
        );
        console.log(
            "  -> ShieldVault.emergencyWithdraw(YieldMax, reason) TX sent"
        );
        console.log(
            "  EVENT: EmergencyWithdrawExecuted(YieldMax, amount, CRITICAL, reason)"
        );
        console.log(
            "  EVENT: ShieldActivated(vault, YieldMax, amount, reason)"
        );
        console.log(
            "  EVENT: ShieldActionLogged(vault, YieldMax, CRITICAL, amount, reason)"
        );
        console.log("");

        _printAdapterBalances("After emergency withdraw (100%)");

        vm.stopBroadcast();

        // ====================================================================
        // SUMMARY
        // ====================================================================
        console.log(
            "=========================================================="
        );
        console.log("  SIMULATION COMPLETE!");
        console.log(
            "=========================================================="
        );
        console.log("");
        console.log("  Transactions sent to Arbitrum Sepolia.");
        console.log("  Check TxHashes in the terminal output above.");
        console.log("");
        console.log("  Verify on Arbiscan:");
        console.log("    ShieldVault Events:");
        console.log(
            "    https://sepolia.arbiscan.io/address/0xcFBd47c63D284A8F824e586596Df4d5c57326c8B#events"
        );
        console.log("");
        console.log("    RiskRegistry Events:");
        console.log(
            "    https://sepolia.arbiscan.io/address/0xa23BE1297F836FF7D4E3297320ff16dbc7903e6D#events"
        );
        console.log("");
        console.log("  Frontend Dashboard:");
        console.log(
            "    Open http://localhost:3000 and connect deployer wallet."
        );
        console.log(
            "    The dashboard reads on-chain data and will reflect changes."
        );
        console.log(
            "=========================================================="
        );
    }

    /// @notice Helper: print adapter balances for debugging
    function _printAdapterBalances(string memory label) internal view {
        console.log("");
        console.log("  --- Adapter Balances (%s) ---", label);

        uint256 aaveBal = MockProtocolAdapter(AAVE_ADAPTER).getBalance();
        uint256 compBal = MockProtocolAdapter(COMPOUND_ADAPTER).getBalance();
        uint256 morphBal = MockProtocolAdapter(MORPHO_ADAPTER).getBalance();
        uint256 ymBal = MockProtocolAdapter(YIELDMAX_ADAPTER).getBalance();
        uint256 total = aaveBal + compBal + morphBal + ymBal;

        console.log("    Aave:       ", aaveBal / 1e6, "USDC");
        console.log("    Compound:   ", compBal / 1e6, "USDC");
        console.log("    Morpho:     ", morphBal / 1e6, "USDC");
        console.log("    YieldMax:   ", ymBal / 1e6, "USDC");
        console.log("    ---------------------");
        console.log("    Total:      ", total / 1e6, "USDC");
        console.log("");
    }
}
