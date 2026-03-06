// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {RiskRegistry} from "../src/RiskRegistry.sol";
import {ShieldVault} from "../src/ShieldVault.sol";

/// @title RedeployRegistry
/// @notice Deploys a new RiskRegistry (with open batchUpdateRiskScores)
///         and links it to the existing ShieldVault + adapters.
contract RedeployRegistry is Script {
    address constant SHIELD_VAULT      = 0x4d0A651776F789c4a7E23563aC3110Aa63A20F7C;
    address constant AAVE_ADAPTER      = 0x2AB8a676Ca67bAB1C9e78f70C48b5b04eb288D8a;
    address constant COMPOUND_ADAPTER  = 0x7816D0b6399CfA2e81AE3c07721EE43cb3b3c6c8;
    address constant MORPHO_ADAPTER    = 0x9D64139FEd95CFAd4d606aA8f145351068Cf36ac;
    address constant YIELDMAX_ADAPTER  = 0xf6b7306abe85B6B7236C4e5e79443773Ef13B4f3;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);

        console.log("Deployer:", deployer);
        vm.startBroadcast(pk);

        // 1. Deploy new RiskRegistry
        RiskRegistry registry = new RiskRegistry();
        console.log("New RiskRegistry:", address(registry));

        // 2. Link to ShieldVault (one-way only — ShieldVault has no setter)
        registry.setShieldVault(SHIELD_VAULT);

        // 3. Authorize deployer as updater
        registry.setAuthorizedUpdater(deployer, true);

        // 4. Set initial risk scores
        registry.updateRiskScore(AAVE_ADAPTER,     15, "Initial: Blue chip protocol");
        registry.updateRiskScore(COMPOUND_ADAPTER, 18, "Initial: Blue chip protocol");
        registry.updateRiskScore(MORPHO_ADAPTER,   35, "Initial: Established but newer");
        registry.updateRiskScore(YIELDMAX_ADAPTER, 55, "Initial: New protocol, higher risk");

        vm.stopBroadcast();

        console.log("\n=== UPDATE THESE FILES ===");
        console.log(".env ARBITRUM_SEPOLIA_RISK_REGISTRY =", address(registry));
        console.log("config.staging.json riskRegistry    =", address(registry));
    }
}
