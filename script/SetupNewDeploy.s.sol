// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockProtocolAdapter} from "../src/mocks/MockProtocolAdapter.sol";
import {RiskRegistry} from "../src/RiskRegistry.sol";
import {ShieldVault} from "../src/ShieldVault.sol";
import {IShieldVault} from "../src/interfaces/IShieldVault.sol";
import {Faucet} from "../src/Faucet.sol";

/// @title SetupNewDeploy
/// @notice Configures newly deployed contracts (addPool, setShieldVault, etc.)
///         without redeploying anything.
/// Usage:
///   forge script script/SetupNewDeploy.s.sol --rpc-url arbitrum_sepolia --broadcast -vvv
contract SetupNewDeploy is Script {
    address constant USDC            = 0x0678D3a3711D18e6cAd57De3bB35467683602DBA;
    address constant FAUCET          = 0x0f92aADcE1C457EF3355B28D9d3a9524b2cA81Db;
    address constant RISK_REGISTRY   = 0xbDA1098dC2d0147Ac596244D0D07C6BD4E7B09Ec;
    address constant SHIELD_VAULT    = 0x4d0A651776F789c4a7E23563aC3110Aa63A20F7C;
    address constant AAVE_ADAPTER    = 0x2AB8a676Ca67bAB1C9e78f70C48b5b04eb288D8a;
    address constant COMPOUND_ADAPTER = 0x7816D0b6399CfA2e81AE3c07721EE43cb3b3c6c8;
    address constant MORPHO_ADAPTER  = 0x9D64139FEd95CFAd4d606aA8f145351068Cf36ac;
    address constant YIELDMAX_ADAPTER = 0xf6b7306abe85B6B7236C4e5e79443773Ef13B4f3;

    uint256 constant RESEED_AMOUNT = 10 * 1e6; // 10 USDC

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("========== SETUP NEW DEPLOY ==========");
        console.log("Deployer:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // 1. (Skip: addPool already done — pools exist)
        // 2. (Skip: setShieldVault already done)

        // 3. Set Aave as safe haven for emergency withdrawals
        console.log("[3] Setting safe haven...");
        ShieldVault(SHIELD_VAULT).setSafeHaven(AAVE_ADAPTER);

        // 4. Authorize deployer as CRE address (for workflow writes)
        console.log("[4] Setting CRE address on vault...");
        ShieldVault(SHIELD_VAULT).setCREAddress(deployer);

        // 5. Authorize deployer to update risk scores
        console.log("[5] Setting authorized updater on RiskRegistry...");
        RiskRegistry(RISK_REGISTRY).setAuthorizedUpdater(deployer, true);

        // 6. Set initial risk scores
        console.log("[6] Setting initial risk scores...");
        RiskRegistry(RISK_REGISTRY).updateRiskScore(AAVE_ADAPTER, 15, "Initial: Blue chip protocol");
        RiskRegistry(RISK_REGISTRY).updateRiskScore(COMPOUND_ADAPTER, 18, "Initial: Blue chip protocol");
        RiskRegistry(RISK_REGISTRY).updateRiskScore(MORPHO_ADAPTER, 35, "Initial: Established but newer");
        RiskRegistry(RISK_REGISTRY).updateRiskScore(YIELDMAX_ADAPTER, 55, "Initial: New protocol, higher risk");

        // 7. Claim USDC from faucet and seed vault
        console.log("[7] Claiming USDC and seeding vault...");
        Faucet(FAUCET).claim();
        IERC20(USDC).approve(SHIELD_VAULT, RESEED_AMOUNT);
        ShieldVault(SHIELD_VAULT).deposit(RESEED_AMOUNT);

        vm.stopBroadcast();

        console.log("\n========== SETUP COMPLETE ==========");
        console.log("ShieldVault:      ", SHIELD_VAULT);
        console.log("RiskRegistry:     ", RISK_REGISTRY);
        console.log("  AaveAdapter:    ", AAVE_ADAPTER, "-> LOW tier, 25%");
        console.log("  CompoundAdapter:", COMPOUND_ADAPTER, "-> LOW tier, 25%");
        console.log("  MorphoAdapter:  ", MORPHO_ADAPTER, "-> MEDIUM tier, 30%");
        console.log("  YieldMaxAdapter:", YIELDMAX_ADAPTER, "-> HIGH tier, 20%");
        console.log("Seeded vault with", RESEED_AMOUNT / 1e6, "USDC");
        console.log("\nVerify: https://sepolia.arbiscan.io/address/", SHIELD_VAULT);
    }
}
