// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {RiskRegistry} from "../src/RiskRegistry.sol";
import {ShieldVault} from "../src/ShieldVault.sol";
import {Faucet} from "../src/Faucet.sol";

contract TestCRE is Script {
    address constant USDC = 0x4d107C58DCda55ea6ea2B162d9C434F710E42038;
    address constant FAUCET = 0x6E860FF2C4ea6b01815D74E54859Cdd9DD172256;
    address constant RISK_REGISTRY = 0xa23BE1297F836FF7D4E3297320ff16dbc7903e6D;
    address constant SHIELD_VAULT = 0xcFBd47c63D284A8F824e586596Df4d5c57326c8B;
    address constant YIELDMAX_ADAPTER = 0x5EbD6F3DA76C2B9C9d6aAC89DA08c388EaB2B3cb;

    // We deposit 1,000 USDC just so YieldMax has some funds to be rescued by your CRE
    uint256 constant DEPOSIT_AMOUNT = 1_000 * 1e6;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("==========================================================");
        console.log("  ⚠️ TRIGGERING ATTACK TO TEST YOUR CRE ⚠️");
        console.log("==========================================================");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Reset YieldMax to SAFE first (in case it was CRITICAL before)
        RiskRegistry(RISK_REGISTRY).updateRiskScore(
            YIELDMAX_ADAPTER,
            10,
            "Reset to SAFE for testing CRE"
        );

        // 2. We claim Faucet just in case we are out of USDC
        Faucet(FAUCET).claim();

        // 3. Deposit money so YieldMax adapter has something to rescue!
        IERC20(USDC).approve(SHIELD_VAULT, DEPOSIT_AMOUNT);
        uint256 shares = ShieldVault(SHIELD_VAULT).deposit(DEPOSIT_AMOUNT);
        
        console.log("  -> Injected 1,000 USDC into ShieldVault. (YieldMax receiving 20%).");
        console.log("");
        
        // 4. THE ATTACK: We update risk score to CRITICAL (95)
        RiskRegistry(RISK_REGISTRY).updateRiskScore(
            YIELDMAX_ADAPTER,
            95,
            "HACKER ATTACK: Liquidity pool drained, critical risk!"
        );

        console.log("  -> Risk score for YieldMax suddenly spiked to 95 (CRITICAL).");
        console.log("  -> Event 'RiskScoreUpdated(protocol, 10, 95, CRITICAL)' emitted.");
        console.log("==========================================================");
        console.log("  ⏳ NOW WAITING FOR YOUR CRE TO RESPOND...");
        console.log("  Jika CRE Anda berfungsi, dia harus membaca event ini dan ");
        console.log("  mengirim transaksi otomatis memanggil emergencyWithdraw()!");
        console.log("==========================================================");

        vm.stopBroadcast();
    }
}
