// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {ShieldBridge} from "../src/bridge/ShieldBridge.sol";

/// @title ConfigureBridge
/// @notice Configures bidirectional CCIP bridge after deployment on both chains
/// @dev Run this AFTER deploying on both Arbitrum Sepolia and Base Sepolia
///
/// Usage:
///   # Step 1: Configure Arbitrum bridge → Base
///   ARB_BRIDGE=<addr> BASE_BRIDGE=<addr> BASE_SAFE_HAVEN=<base_aave_addr> \
///     forge script script/ConfigureBridge.s.sol --tc ConfigureBridgeArb --rpc-url arbitrum_sepolia --broadcast
///
///   # Step 2: Configure Base bridge → Arbitrum
///   ARB_BRIDGE=<addr> BASE_BRIDGE=<addr> ARB_SAFE_HAVEN=<arb_aave_addr> \
///     forge script script/ConfigureBridge.s.sol --tc ConfigureBridgeBase --rpc-url base_sepolia --broadcast

/// @title ConfigureBridgeArb
/// @notice Configure Arbitrum bridge to point to Base (receiver + safe haven)
contract ConfigureBridgeArb is Script {
    uint64 constant BASE_SEPOLIA_SELECTOR = 10344971235874465080;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address arbBridge = vm.envAddress("ARB_BRIDGE");
        address baseBridge = vm.envAddress("BASE_BRIDGE");
        address baseSafeHaven = vm.envAddress("BASE_SAFE_HAVEN");

        console.log("Configuring Arbitrum ShieldBridge -> Base...");
        console.log("ARB Bridge:", arbBridge);
        console.log("BASE Bridge (receiver):", baseBridge);
        console.log("BASE Safe Haven:", baseSafeHaven);

        vm.startBroadcast(deployerPrivateKey);

        ShieldBridge bridge = ShieldBridge(payable(arbBridge));
        bridge.setChainReceiver(BASE_SEPOLIA_SELECTOR, baseBridge);
        bridge.setChainSafeHaven(BASE_SEPOLIA_SELECTOR, baseSafeHaven);

        vm.stopBroadcast();

        console.log("Arbitrum -> Base configured!");
    }
}

/// @title ConfigureBridgeBase
/// @notice Configure Base bridge to point to Arbitrum (receiver + safe haven)
contract ConfigureBridgeBase is Script {
    uint64 constant ARB_SEPOLIA_SELECTOR = 3478487238524512106;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address baseBridge = vm.envAddress("BASE_BRIDGE");
        address arbBridge = vm.envAddress("ARB_BRIDGE");
        address arbSafeHaven = vm.envAddress("ARB_SAFE_HAVEN");

        console.log("Configuring Base ShieldBridge -> Arbitrum...");
        console.log("BASE Bridge:", baseBridge);
        console.log("ARB Bridge (receiver):", arbBridge);
        console.log("ARB Safe Haven:", arbSafeHaven);

        vm.startBroadcast(deployerPrivateKey);

        ShieldBridge bridge = ShieldBridge(payable(baseBridge));
        bridge.setChainReceiver(ARB_SEPOLIA_SELECTOR, arbBridge);
        bridge.setChainSafeHaven(ARB_SEPOLIA_SELECTOR, arbSafeHaven);

        vm.stopBroadcast();

        console.log("Base -> Arbitrum configured!");
    }
}
