// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockProtocolAdapter} from "../src/mocks/MockProtocolAdapter.sol";
import {RiskRegistry} from "../src/RiskRegistry.sol";
import {ShieldVault} from "../src/ShieldVault.sol";
import {Faucet} from "../src/Faucet.sol";

/// @title FullReset
/// @notice Resets the entire on-chain state back to a clean baseline:
///         1. Restores all adapter health status
///         2. Resets all risk scores to SAFE baseline
///         3. Checks if pools are empty (from emergency withdrawals)
///         4. If empty: uses Faucet to claim fresh USDC and re-deposits into ShieldVault
///            so that the vault's pool.currentAmount is populated again
///
/// Run AFTER SimulateOnChain.s.sol to recover a withdrawable vault state.
///
/// Usage (dry-run):
///   forge script script/FullReset.s.sol --rpc-url arbitrum_sepolia -vvv
///
/// Usage (broadcast):
///   forge script script/FullReset.s.sol --rpc-url arbitrum_sepolia --broadcast -vvv
contract FullReset is Script {
    address constant USDC = 0x4d107C58DCda55ea6ea2B162d9C434F710E42038;
    address constant FAUCET = 0x6E860FF2C4ea6b01815D74E54859Cdd9DD172256;
    address constant RISK_REGISTRY = 0xa23BE1297F836FF7D4E3297320ff16dbc7903e6D;
    address constant SHIELD_VAULT = 0xcFBd47c63D284A8F824e586596Df4d5c57326c8B;

    address constant AAVE_ADAPTER = 0xB81961aA49d7E834404e299e688B3Dc09a5EFe5a;
    address constant COMPOUND_ADAPTER =
        0xcc547a2B0f18b34095623809977D54cfe306BEBF;
    address constant MORPHO_ADAPTER =
        0x5f8A64Bc67f23b8d5d02c7CFE187AD42D59f1D59;
    address constant YIELDMAX_ADAPTER =
        0x5EbD6F3DA76C2B9C9d6aAC89DA08c388EaB2B3cb;

    // Deposit amount to re-seed pools: 1 USDC (minimal, just to populate pool.currentAmount)
    uint256 constant RESEED_AMOUNT = 1 * 1e6;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log(
            "=========================================================="
        );
        console.log("  ShieldYield -- Full Reset (Arbitrum Sepolia)");
        console.log(
            "=========================================================="
        );
        console.log("Deployer:", deployer);
        console.log("");

        // ── Read current state BEFORE broadcast ────────────────────────────
        uint256 aaveBal = MockProtocolAdapter(AAVE_ADAPTER).getBalance();
        uint256 compBal = MockProtocolAdapter(COMPOUND_ADAPTER).getBalance();
        uint256 morphoBal = MockProtocolAdapter(MORPHO_ADAPTER).getBalance();
        uint256 yieldMaxBal = MockProtocolAdapter(YIELDMAX_ADAPTER)
            .getBalance();
        bool ymHealthy = MockProtocolAdapter(YIELDMAX_ADAPTER).isHealthy();
        uint256 totalInPools = aaveBal + compBal + morphoBal + yieldMaxBal;

        console.log("  Current state:");
        console.log("    Aave balance:       ", aaveBal / 1e6, "USDC");
        console.log("    Compound balance:   ", compBal / 1e6, "USDC");
        console.log("    Morpho balance:     ", morphoBal / 1e6, "USDC");
        console.log("    YieldMax balance:   ", yieldMaxBal / 1e6, "USDC");
        console.log("    YieldMax healthy:   ", ymHealthy ? "YES" : "NO");
        console.log("    Total in pools:     ", totalInPools / 1e6, "USDC");
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // ── Step 1: Restore YieldMax health ──────────────────────────────
        if (!ymHealthy) {
            console.log(
                "[ 1 ] Restoring YieldMaxAdapter.isHealthy -> true ..."
            );
            MockProtocolAdapter(YIELDMAX_ADAPTER).setHealthy(true);
            console.log("      -> Done");
        } else {
            console.log("[ 1 ] YieldMaxAdapter already healthy. Skipping.");
        }
        console.log("");

        // ── Step 2: Reset all risk scores to SAFE ──────────────────────
        console.log("[ 2 ] Resetting all risk scores to SAFE baseline ...");
        RiskRegistry(RISK_REGISTRY).updateRiskScore(
            AAVE_ADAPTER,
            10,
            "FullReset: baseline SAFE score"
        );
        RiskRegistry(RISK_REGISTRY).updateRiskScore(
            COMPOUND_ADAPTER,
            13,
            "FullReset: baseline SAFE score"
        );
        RiskRegistry(RISK_REGISTRY).updateRiskScore(
            MORPHO_ADAPTER,
            15,
            "FullReset: baseline SAFE score"
        );
        RiskRegistry(RISK_REGISTRY).updateRiskScore(
            YIELDMAX_ADAPTER,
            18,
            "FullReset: baseline SAFE score"
        );
        console.log(
            "      Aave: 10, Compound: 13, Morpho: 15, YieldMax: 18 (all SAFE)"
        );
        console.log("");

        // ── Step 3: Re-seed vault if pools are drained ────────────────
        if (totalInPools == 0) {
            console.log("[ 3 ] Pools are EMPTY (from emergency withdrawal).");
            console.log(
                "      Claiming USDC from Faucet and re-seeding vault ..."
            );

            Faucet(FAUCET).claim();
            uint256 usdcBalance = IERC20(USDC).balanceOf(deployer);
            console.log(
                "      Faucet claimed. USDC balance:",
                usdcBalance / 1e6
            );

            // Approve and deposit RESEED_AMOUNT
            IERC20(USDC).approve(SHIELD_VAULT, RESEED_AMOUNT);
            ShieldVault(SHIELD_VAULT).deposit(RESEED_AMOUNT);
            console.log(
                "      Deposited",
                RESEED_AMOUNT / 1e6,
                "USDC into ShieldVault."
            );
            console.log(
                "      Pool balances are now populated. Withdraw should work."
            );
        } else {
            console.log("[ 3 ] Pools still have funds. No re-seed needed.");
        }
        console.log("");

        vm.stopBroadcast();

        // ── Summary ────────────────────────────────────────────────────
        console.log(
            "=========================================================="
        );
        console.log("  FULL RESET COMPLETE!");
        console.log(
            "=========================================================="
        );
        console.log("  - All adapters: isHealthy = true");
        console.log("  - All risk scores: SAFE baseline");
        if (totalInPools == 0) {
            console.log(
                "  - Vault re-seeded with 1 USDC to restore withdrawability"
            );
        }
        console.log("");
        console.log("  Next steps:");
        console.log("  1. Refresh the dashboard in browser");
        console.log("  2. Try withdraw again should work now");
        console.log("");
        console.log(
            "  Verify: https://sepolia.arbiscan.io/address/0xcFBd47c63D284A8F824e586596Df4d5c57326c8B"
        );
        console.log(
            "=========================================================="
        );
    }
}
