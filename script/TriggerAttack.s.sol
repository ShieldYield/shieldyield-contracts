// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {RiskRegistry} from "../src/RiskRegistry.sol";

contract TriggerAttack is Script {
    address constant RISK_REGISTRY = 0xa23BE1297F836FF7D4E3297320ff16dbc7903e6D;
    address constant YIELDMAX_ADAPTER = 0x5EbD6F3DA76C2B9C9d6aAC89DA08c388EaB2B3cb;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("==========================================================");
        console.log("  ⚠️ TRIGGERING ON-CHAIN ATTACK SIMULATION ⚠️");
        console.log("==========================================================");

        vm.startBroadcast(deployerPrivateKey);

        // This will emit the RiskScoreUpdated event on-chain!
        // The real CRE workflow should automatically catch this event
        // and execute the 'shieldVault.emergencyWithdraw()' in response.
        RiskRegistry(RISK_REGISTRY).updateRiskScore(
            YIELDMAX_ADAPTER,
            95,
            "HACKER ATTACK: Liquidity pool drained, critical risk!"
        );

        console.log("  -> Risk score for YieldMax successfully updated to 95 (CRITICAL).");
        console.log("  -> Event 'RiskScoreUpdated' emitted to Arbitrum Sepolia.");
        console.log("  -> NOW: Check your running CRE workflow. It should respond to this event!");
        console.log("==========================================================");

        vm.stopBroadcast();
    }
}
