// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MockProtocolAdapter} from "../src/mocks/MockProtocolAdapter.sol";
import {RiskRegistry} from "../src/RiskRegistry.sol";

/// @title ResetState
/// @notice Resets all adapter risk scores and health status back to a clean baseline.
///         Run this after a simulation to return the on-chain state to "all healthy, all SAFE".
///
/// Usage (dry-run):
///   forge script script/ResetState.s.sol --rpc-url arbitrum_sepolia -vvv
///
/// Usage (broadcast — writes real transactions):
///   forge script script/ResetState.s.sol --rpc-url arbitrum_sepolia --broadcast -vvv
///
/// Prerequisites:
///   - PRIVATE_KEY env var set (deployer wallet)
///   - Deployer must be authorized updater on RiskRegistry
contract ResetState is Script {
    // ─── Contract Addresses (Arbitrum Sepolia) ───────────────────────────────
    address constant RISK_REGISTRY = 0xa23BE1297F836FF7D4E3297320ff16dbc7903e6D;

    address constant AAVE_ADAPTER = 0xB81961aA49d7E834404e299e688B3Dc09a5EFe5a;
    address constant COMPOUND_ADAPTER =
        0xcc547a2B0f18b34095623809977D54cfe306BEBF;
    address constant MORPHO_ADAPTER =
        0x5f8A64Bc67f23b8d5d02c7CFE187AD42D59f1D59;
    address constant YIELDMAX_ADAPTER =
        0x5EbD6F3DA76C2B9C9d6aAC89DA08c388EaB2B3cb;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log(
            "=========================================================="
        );
        console.log(
            "  ShieldYield -- Reset On-Chain State (Arbitrum Sepolia)  "
        );
        console.log(
            "=========================================================="
        );
        console.log("Deployer:", deployer);
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // ── Step 1: Reset YieldMax ──────────────────────────────────────────
        console.log("[ 1/5 ] Restoring YieldMaxAdapter health -> true ...");
        MockProtocolAdapter(YIELDMAX_ADAPTER).setHealthy(true);
        console.log("  -> YieldMaxAdapter.setHealthy(true) TX sent");
        console.log("");

        // ── Step 2: Reset risk scores to SAFE baseline ──────────────────────
        console.log(
            "[ 2/5 ] Resetting AaveAdapter risk score -> 10 (SAFE) ..."
        );
        RiskRegistry(RISK_REGISTRY).updateRiskScore(
            AAVE_ADAPTER,
            10,
            unicode"ResetState: Manual reset — baseline SAFE score"
        );
        console.log(
            "  -> RiskRegistry.updateRiskScore(Aave, 10, SAFE) TX sent"
        );
        console.log("");

        console.log(
            "[ 3/5 ] Resetting CompoundAdapter risk score -> 13 (SAFE) ..."
        );
        RiskRegistry(RISK_REGISTRY).updateRiskScore(
            COMPOUND_ADAPTER,
            13,
            unicode"ResetState: Manual reset — baseline SAFE score"
        );
        console.log(
            "  -> RiskRegistry.updateRiskScore(Compound, 13, SAFE) TX sent"
        );
        console.log("");

        console.log(
            "[ 4/5 ] Resetting MorphoAdapter risk score -> 15 (SAFE) ..."
        );
        RiskRegistry(RISK_REGISTRY).updateRiskScore(
            MORPHO_ADAPTER,
            15,
            unicode"ResetState: Manual reset — baseline SAFE score"
        );
        console.log(
            "  -> RiskRegistry.updateRiskScore(Morpho, 15, SAFE) TX sent"
        );
        console.log("");

        console.log(
            "[ 5/5 ] Resetting YieldMaxAdapter risk score -> 18 (SAFE) ..."
        );
        RiskRegistry(RISK_REGISTRY).updateRiskScore(
            YIELDMAX_ADAPTER,
            18,
            unicode"ResetState: Manual reset — baseline SAFE score after simulation"
        );
        console.log(
            "  -> RiskRegistry.updateRiskScore(YieldMax, 18, SAFE) TX sent"
        );
        console.log("");

        vm.stopBroadcast();

        // ── Summary ──────────────────────────────────────────────────────────
        console.log(
            "=========================================================="
        );
        console.log("  RESET COMPLETE! On-chain state restored to baseline.");
        console.log(
            "=========================================================="
        );
        console.log("");
        console.log("  New risk scores:");
        console.log("    AaveAdapter:     10  (SAFE)");
        console.log("    CompoundAdapter: 13  (SAFE)");
        console.log("    MorphoAdapter:   15  (SAFE)");
        console.log("    YieldMaxAdapter: 18  (SAFE)  + isHealthy = true");
        console.log("");
        console.log("  Verify on Arbiscan:");
        console.log(
            "    https://sepolia.arbiscan.io/address/0xa23BE1297F836FF7D4E3297320ff16dbc7903e6D#events"
        );
        console.log("");
        console.log(
            "  Refresh the dashboard and YieldMax should be SAFE again."
        );
        console.log(
            "=========================================================="
        );
    }
}
