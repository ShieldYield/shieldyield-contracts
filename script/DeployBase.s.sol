// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MockProtocolAdapter} from "../src/mocks/MockProtocolAdapter.sol";
import {ShieldBridge} from "../src/bridge/ShieldBridge.sol";
import {RiskRegistry} from "../src/RiskRegistry.sol";
import {ShieldVault} from "../src/ShieldVault.sol";
import {IShieldVault} from "../src/interfaces/IShieldVault.sol";

/// @title DeployBase
/// @notice Deploys full ShieldYield system on Base Sepolia using CCIP-BnM token
/// @dev Both chains run identical systems; CRE decides which chain is safest
contract DeployBase is Script {
    // Chainlink CCIP Router on Base Sepolia
    address constant CCIP_ROUTER_BASE_SEPOLIA = 0xD3b06cEbF099CE7DA4AcCf578aaebFDBd6e88a93;

    // Arbitrum Sepolia CCIP chain selector
    uint64 constant ARB_SEPOLIA_SELECTOR = 3478487238524512106;

    // CCIP-BnM token on Base Sepolia (18 decimals, whitelisted for CCIP)
    address constant BNM_BASE_SEPOLIA = 0x88A2d74F47a237a62e7A51cdDa67270CE381555e;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("========== DEPLOYING SHIELDYIELD ON BASE SEPOLIA ==========");
        console.log("Deployer:", deployer);
        console.log("Asset (BnM):", BNM_BASE_SEPOLIA);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy RiskRegistry
        RiskRegistry registry = new RiskRegistry();
        console.log("RiskRegistry deployed:", address(registry));

        // 2. Deploy ShieldVault (using BnM as asset)
        ShieldVault vault = new ShieldVault(BNM_BASE_SEPOLIA, address(registry));
        registry.setShieldVault(address(vault));
        console.log("ShieldVault deployed:", address(vault));

        // 3. Deploy Mock Adapters (using BnM as underlying)
        MockProtocolAdapter aaveAdapter = new MockProtocolAdapter(
            BNM_BASE_SEPOLIA, "Aave V3", 500 // 5% APY
        );
        MockProtocolAdapter compoundAdapter = new MockProtocolAdapter(
            BNM_BASE_SEPOLIA, "Compound V3", 450 // 4.5% APY
        );
        MockProtocolAdapter morphoAdapter = new MockProtocolAdapter(
            BNM_BASE_SEPOLIA, "Morpho", 800 // 8% APY
        );
        MockProtocolAdapter yieldMaxAdapter = new MockProtocolAdapter(
            BNM_BASE_SEPOLIA, "YieldMax", 1500 // 15% APY
        );

        console.log("AaveAdapter deployed:", address(aaveAdapter));
        console.log("CompoundAdapter deployed:", address(compoundAdapter));
        console.log("MorphoAdapter deployed:", address(morphoAdapter));
        console.log("YieldMaxAdapter deployed:", address(yieldMaxAdapter));

        // 4. Setup adapters
        aaveAdapter.setShieldVault(address(vault));
        compoundAdapter.setShieldVault(address(vault));
        morphoAdapter.setShieldVault(address(vault));
        yieldMaxAdapter.setShieldVault(address(vault));

        // 5. Add pools to vault with risk-based tranching
        vault.addPool(address(aaveAdapter), IShieldVault.RiskTier.LOW, 2500);      // 25%
        vault.addPool(address(compoundAdapter), IShieldVault.RiskTier.LOW, 2500);  // 25%
        vault.addPool(address(morphoAdapter), IShieldVault.RiskTier.MEDIUM, 3000); // 30%
        vault.addPool(address(yieldMaxAdapter), IShieldVault.RiskTier.HIGH, 2000); // 20%

        // 6. Set Aave as safe haven
        vault.setSafeHaven(address(aaveAdapter));

        // 7. Set deployer as CRE (for testing)
        vault.setCREAddress(deployer);

        // 8. Set initial risk scores
        registry.setAuthorizedUpdater(deployer, true);
        registry.updateRiskScore(address(aaveAdapter), 15, "Initial: Blue chip protocol");
        registry.updateRiskScore(address(compoundAdapter), 18, "Initial: Blue chip protocol");
        registry.updateRiskScore(address(morphoAdapter), 35, "Initial: Established but newer");
        registry.updateRiskScore(address(yieldMaxAdapter), 55, "Initial: New protocol, higher risk");

        // 9. Deploy ShieldBridge with REAL CCIP Router
        ShieldBridge bridge = new ShieldBridge(CCIP_ROUTER_BASE_SEPOLIA);
        bridge.setShieldVault(address(vault));
        bridge.setCREAddress(deployer);
        console.log("ShieldBridge (CCIP) deployed:", address(bridge));

        // Note: Base bridge only RECEIVES, no ETH funding needed for CCIP fees

        vm.stopBroadcast();

        // Print summary
        console.log("\n========== BASE SEPOLIA DEPLOYMENT SUMMARY ==========");
        console.log("Asset (BnM):      ", BNM_BASE_SEPOLIA);
        console.log("RiskRegistry:     ", address(registry));
        console.log("ShieldVault:      ", address(vault));
        console.log("ShieldBridge:     ", address(bridge));
        console.log("-----------------------------------------------------");
        console.log("LOW RISK (50%):");
        console.log("  AaveAdapter:    ", address(aaveAdapter));
        console.log("  CompoundAdapter:", address(compoundAdapter));
        console.log("MEDIUM RISK (30%):");
        console.log("  MorphoAdapter:  ", address(morphoAdapter));
        console.log("HIGH RISK (20%):");
        console.log("  YieldMaxAdapter:", address(yieldMaxAdapter));
        console.log("=====================================================");
        console.log("\nCCIP Router:       ", CCIP_ROUTER_BASE_SEPOLIA);
        console.log("\n>> NEXT: Run ConfigureBridge.s.sol to link both bridges");
    }
}
