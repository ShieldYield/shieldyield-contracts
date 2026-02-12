// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockProtocolAdapter} from "../src/mocks/MockProtocolAdapter.sol";
import {MockShieldBridge} from "../src/mocks/MockShieldBridge.sol";
import {Faucet} from "../src/Faucet.sol";
import {RiskRegistry} from "../src/RiskRegistry.sol";
import {ShieldVault} from "../src/ShieldVault.sol";
import {IShieldVault} from "../src/interfaces/IShieldVault.sol";

/// @title Deploy
/// @notice Deployment script for ShieldYield testnet demo
contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying ShieldYield...");
        console.log("Deployer:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy MockUSDC
        MockERC20 usdc = new MockERC20("Mock USDC", "USDC", 6);
        console.log("MockUSDC deployed:", address(usdc));

        // 2. Deploy Faucet
        Faucet faucet = new Faucet(address(usdc));
        console.log("Faucet deployed:", address(faucet));

        // 3. Add Faucet as minter
        usdc.addMinter(address(faucet));
        console.log("Faucet added as minter");

        // 4. Disable cooldown for demo (judges can claim multiple times)
        faucet.disableCooldown();
        console.log("Faucet cooldown disabled for demo");

        // 5. Deploy RiskRegistry
        RiskRegistry registry = new RiskRegistry();
        console.log("RiskRegistry deployed:", address(registry));

        // 6. Deploy ShieldVault
        ShieldVault vault = new ShieldVault(address(usdc), address(registry));
        console.log("ShieldVault deployed:", address(vault));

        // 7. Set ShieldVault in RiskRegistry
        registry.setShieldVault(address(vault));

        // 8. Deploy Mock Adapters (simulating Aave, Compound, etc.)
        MockProtocolAdapter aaveAdapter = new MockProtocolAdapter(
            address(usdc),
            "Aave V3",
            500 // 5% APY
        );
        console.log("AaveAdapter (Mock) deployed:", address(aaveAdapter));

        MockProtocolAdapter compoundAdapter = new MockProtocolAdapter(
            address(usdc),
            "Compound V3",
            450 // 4.5% APY
        );
        console.log("CompoundAdapter (Mock) deployed:", address(compoundAdapter));

        MockProtocolAdapter morphoAdapter = new MockProtocolAdapter(
            address(usdc),
            "Morpho",
            800 // 8% APY (medium risk)
        );
        console.log("MorphoAdapter (Mock) deployed:", address(morphoAdapter));

        // HIGH risk pool - newer protocol, higher APY
        MockProtocolAdapter yieldMaxAdapter = new MockProtocolAdapter(
            address(usdc),
            "YieldMax",
            1500 // 15% APY (high risk, high reward)
        );
        console.log("YieldMaxAdapter (Mock) deployed:", address(yieldMaxAdapter));

        // 9. Setup adapters - set ShieldVault
        aaveAdapter.setShieldVault(address(vault));
        compoundAdapter.setShieldVault(address(vault));
        morphoAdapter.setShieldVault(address(vault));
        yieldMaxAdapter.setShieldVault(address(vault));

        // 10. Add pools to vault with tranching weights
        // LOW risk: 50% (Aave 25% + Compound 25%)
        vault.addPool(address(aaveAdapter), IShieldVault.RiskTier.LOW, 2500);      // 25%
        vault.addPool(address(compoundAdapter), IShieldVault.RiskTier.LOW, 2500);  // 25%
        // MEDIUM risk: 30%
        vault.addPool(address(morphoAdapter), IShieldVault.RiskTier.MEDIUM, 3000); // 30%
        // HIGH risk: 20%
        vault.addPool(address(yieldMaxAdapter), IShieldVault.RiskTier.HIGH, 2000); // 20%

        console.log("Pools added to vault");

        // 11. Set Aave as safe haven (most trusted)
        vault.setSafeHaven(address(aaveAdapter));
        console.log("Safe haven set to Aave");

        // 12. Set deployer as CRE (for testing)
        vault.setCREAddress(deployer);
        console.log("CRE address set to deployer (for testing)");

        // 13. Set initial risk scores
        registry.setAuthorizedUpdater(deployer, true);
        registry.updateRiskScore(address(aaveAdapter), 15, "Initial: Blue chip protocol");
        registry.updateRiskScore(address(compoundAdapter), 18, "Initial: Blue chip protocol");
        registry.updateRiskScore(address(morphoAdapter), 35, "Initial: Established but newer");
        registry.updateRiskScore(address(yieldMaxAdapter), 55, "Initial: New protocol, higher risk");
        console.log("Initial risk scores set");

        // 14. Deploy MockShieldBridge (Layer 4: Emergency Cross-Chain)
        MockShieldBridge bridge = new MockShieldBridge();
        bridge.setShieldVault(address(vault));
        bridge.setCREAddress(deployer);
        // Setup Base Sepolia as emergency destination
        bridge.setChainReceiver(10344971235874465080, address(bridge)); // BASE_SEPOLIA_SELECTOR
        bridge.setChainSafeHaven(10344971235874465080, address(aaveAdapter)); // Safe haven on Base
        console.log("ShieldBridge (Mock) deployed:", address(bridge));

        vm.stopBroadcast();

        // Print summary
        console.log("\n========== DEPLOYMENT SUMMARY ==========");
        console.log("MockUSDC:         ", address(usdc));
        console.log("Faucet:           ", address(faucet));
        console.log("RiskRegistry:     ", address(registry));
        console.log("ShieldVault:      ", address(vault));
        console.log("ShieldBridge:     ", address(bridge));
        console.log("----------------------------------------");
        console.log("LOW RISK (50%):");
        console.log("  AaveAdapter:    ", address(aaveAdapter));
        console.log("  CompoundAdapter:", address(compoundAdapter));
        console.log("MEDIUM RISK (30%):");
        console.log("  MorphoAdapter:  ", address(morphoAdapter));
        console.log("HIGH RISK (20%):");
        console.log("  YieldMaxAdapter:", address(yieldMaxAdapter));
        console.log("==========================================\n");

        console.log("To claim test USDC, call:");
        console.log("  Faucet.claim() -> gives 10,000 USDC");
        console.log("\nTo deposit into ShieldYield:");
        console.log("  1. USDC.approve(ShieldVault, amount)");
        console.log("  2. ShieldVault.deposit(amount)");
    }
}
