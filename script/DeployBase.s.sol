// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockProtocolAdapter} from "../src/mocks/MockProtocolAdapter.sol";
import {ShieldBridge} from "../src/bridge/ShieldBridge.sol";
import {Faucet} from "../src/Faucet.sol";
import {RiskRegistry} from "../src/RiskRegistry.sol";
import {ShieldVault} from "../src/ShieldVault.sol";
import {IShieldVault} from "../src/interfaces/IShieldVault.sol";

/// @title DeployBase
/// @notice Deploys full ShieldYield system on Base Sepolia (mirror of Arbitrum)
/// @dev Both chains run identical systems; CRE decides which chain is safest
contract DeployBase is Script {
    // Chainlink CCIP Router on Base Sepolia
    address constant CCIP_ROUTER_BASE_SEPOLIA = 0xD3b06cEbF099CE7DA4AcCf578aaebFDBd6e88a93;

    // Arbitrum Sepolia CCIP chain selector
    uint64 constant ARB_SEPOLIA_SELECTOR = 3478487238524512106;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("========== DEPLOYING SHIELDYIELD ON BASE SEPOLIA ==========");
        console.log("Deployer:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy MockUSDC
        MockERC20 usdc = new MockERC20("Mock USDC", "USDC", 6);
        console.log("MockUSDC deployed:", address(usdc));

        // 2. Deploy Faucet
        Faucet faucet = new Faucet(address(usdc));
        usdc.addMinter(address(faucet));
        faucet.disableCooldown();
        console.log("Faucet deployed:", address(faucet));

        // 3. Deploy RiskRegistry
        RiskRegistry registry = new RiskRegistry();
        console.log("RiskRegistry deployed:", address(registry));

        // 4. Deploy ShieldVault
        ShieldVault vault = new ShieldVault(address(usdc), address(registry));
        registry.setShieldVault(address(vault));
        console.log("ShieldVault deployed:", address(vault));

        // 5. Deploy Mock Adapters (identical to Arbitrum)
        MockProtocolAdapter aaveAdapter = new MockProtocolAdapter(
            address(usdc), "Aave V3", 500 // 5% APY
        );
        MockProtocolAdapter compoundAdapter = new MockProtocolAdapter(
            address(usdc), "Compound V3", 450 // 4.5% APY
        );
        MockProtocolAdapter morphoAdapter = new MockProtocolAdapter(
            address(usdc), "Morpho", 800 // 8% APY
        );
        MockProtocolAdapter yieldMaxAdapter = new MockProtocolAdapter(
            address(usdc), "YieldMax", 1500 // 15% APY
        );

        console.log("AaveAdapter deployed:", address(aaveAdapter));
        console.log("CompoundAdapter deployed:", address(compoundAdapter));
        console.log("MorphoAdapter deployed:", address(morphoAdapter));
        console.log("YieldMaxAdapter deployed:", address(yieldMaxAdapter));

        // 6. Setup adapters
        aaveAdapter.setShieldVault(address(vault));
        compoundAdapter.setShieldVault(address(vault));
        morphoAdapter.setShieldVault(address(vault));
        yieldMaxAdapter.setShieldVault(address(vault));

        // 7. Add pools to vault with risk-based tranching
        vault.addPool(address(aaveAdapter), IShieldVault.RiskTier.LOW, 2500);      // 25%
        vault.addPool(address(compoundAdapter), IShieldVault.RiskTier.LOW, 2500);  // 25%
        vault.addPool(address(morphoAdapter), IShieldVault.RiskTier.MEDIUM, 3000); // 30%
        vault.addPool(address(yieldMaxAdapter), IShieldVault.RiskTier.HIGH, 2000); // 20%

        // 8. Set Aave as safe haven
        vault.setSafeHaven(address(aaveAdapter));

        // 9. Set deployer as CRE (for testing)
        vault.setCREAddress(deployer);

        // 10. Set initial risk scores
        registry.setAuthorizedUpdater(deployer, true);
        registry.updateRiskScore(address(aaveAdapter), 15, "Initial: Blue chip protocol");
        registry.updateRiskScore(address(compoundAdapter), 18, "Initial: Blue chip protocol");
        registry.updateRiskScore(address(morphoAdapter), 35, "Initial: Established but newer");
        registry.updateRiskScore(address(yieldMaxAdapter), 55, "Initial: New protocol, higher risk");

        // 11. Deploy ShieldBridge with REAL CCIP Router
        ShieldBridge bridge = new ShieldBridge(CCIP_ROUTER_BASE_SEPOLIA);
        bridge.setShieldVault(address(vault));
        bridge.setCREAddress(deployer);
        console.log("ShieldBridge (CCIP) deployed:", address(bridge));

        vm.stopBroadcast();

        // Print summary
        console.log("\n========== BASE SEPOLIA DEPLOYMENT SUMMARY ==========");
        console.log("MockUSDC:         ", address(usdc));
        console.log("Faucet:           ", address(faucet));
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
