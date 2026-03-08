// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {ShieldBridge} from "../src/bridge/ShieldBridge.sol";

/// @title RedeployBridge
/// @notice Redeploys only the ShieldBridge on Arbitrum Sepolia with self-funded ETH fee model
/// @dev Run this after modifying emergencyBridge to use address(this).balance for CCIP fees
///
/// Usage:
///   SHIELD_VAULT=<arb_vault_addr> BASE_BRIDGE=<base_bridge_addr> BASE_SAFE_HAVEN=<base_vault_addr> \
///     forge script script/RedeployBridge.s.sol --rpc-url arbitrum_sepolia --broadcast
contract RedeployBridge is Script {
    address constant CCIP_ROUTER_ARB_SEPOLIA = 0x2a9C5afB0d0e4BAb2BCdaE109EC4b0c4Be15a165;
    uint64  constant BASE_SEPOLIA_SELECTOR   = 10344971235874465080;

    // Amount of ETH to pre-fund the bridge for CCIP fees (~0.05 ETH covers many bridges)
    uint256 constant BRIDGE_FUND_ETH = 0.05 ether;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        address shieldVault  = vm.envAddress("SHIELD_VAULT");
        address baseBridge   = vm.envAddress("BASE_BRIDGE");
        address baseSafeHaven = vm.envAddress("BASE_SAFE_HAVEN");

        console.log("=== RedeployBridge: Arbitrum Sepolia ===");
        console.log("Deployer:       ", deployer);
        console.log("ShieldVault:    ", shieldVault);
        console.log("Base Bridge:    ", baseBridge);
        console.log("Base SafeHaven: ", baseSafeHaven);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy new ShieldBridge (with self-funded ETH fee model)
        ShieldBridge bridge = new ShieldBridge(CCIP_ROUTER_ARB_SEPOLIA);
        console.log("New ShieldBridge deployed:", address(bridge));

        // 2. Configure: set ShieldVault + CRE
        bridge.setShieldVault(shieldVault);
        bridge.setCREAddress(deployer);

        // 3. Configure: Arbitrum → Base Sepolia
        bridge.setChainReceiver(BASE_SEPOLIA_SELECTOR, baseBridge);
        bridge.setChainSafeHaven(BASE_SEPOLIA_SELECTOR, baseSafeHaven);
        console.log("Bridge configured: Arb -> Base Sepolia");

        // 4. Fund bridge with ETH for CCIP fees
        (bool sent, ) = address(bridge).call{value: BRIDGE_FUND_ETH}("");
        require(sent, "ETH funding failed");
        console.log("Bridge funded with 0.05 ETH for CCIP fees");
        console.log("Bridge ETH balance:", address(bridge).balance);

        vm.stopBroadcast();

        console.log("\n=== SUMMARY ===");
        console.log("New ShieldBridge (Arb Sepolia):", address(bridge));
        console.log("Pre-funded with:", BRIDGE_FUND_ETH, "wei");
        console.log(">> Update config.staging.json shieldBridge with:", address(bridge));
    }
}
