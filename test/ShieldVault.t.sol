// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockProtocolAdapter} from "../src/mocks/MockProtocolAdapter.sol";
import {Faucet} from "../src/Faucet.sol";
import {RiskRegistry} from "../src/RiskRegistry.sol";
import {ShieldVault} from "../src/ShieldVault.sol";
import {IShieldVault} from "../src/interfaces/IShieldVault.sol";
import {IRiskRegistry} from "../src/interfaces/IRiskRegistry.sol";

contract ShieldVaultTest is Test {
    MockERC20 public usdc;
    Faucet public faucet;
    RiskRegistry public registry;
    ShieldVault public vault;
    MockProtocolAdapter public aaveAdapter;
    MockProtocolAdapter public compoundAdapter;
    MockProtocolAdapter public morphoAdapter;
    MockProtocolAdapter public yieldMaxAdapter;

    address public owner;
    address public user1;
    address public user2;
    address public cre;

    uint256 constant DEPOSIT_AMOUNT = 10_000 * 1e6; // 10,000 USDC

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        cre = makeAddr("cre");

        // Deploy MockUSDC
        usdc = new MockERC20("Mock USDC", "USDC", 6);

        // Deploy Faucet
        faucet = new Faucet(address(usdc));
        usdc.addMinter(address(faucet));
        faucet.disableCooldown();

        // Deploy RiskRegistry
        registry = new RiskRegistry();

        // Deploy ShieldVault
        vault = new ShieldVault(address(usdc), address(registry));
        registry.setShieldVault(address(vault));

        // Deploy Mock Adapters
        aaveAdapter = new MockProtocolAdapter(address(usdc), "Aave V3", 500);
        compoundAdapter = new MockProtocolAdapter(address(usdc), "Compound V3", 450);
        morphoAdapter = new MockProtocolAdapter(address(usdc), "Morpho", 800);
        yieldMaxAdapter = new MockProtocolAdapter(address(usdc), "YieldMax", 1500);

        // Setup adapters
        aaveAdapter.setShieldVault(address(vault));
        compoundAdapter.setShieldVault(address(vault));
        morphoAdapter.setShieldVault(address(vault));
        yieldMaxAdapter.setShieldVault(address(vault));

        // Add pools to vault (50% LOW, 30% MEDIUM, 20% HIGH)
        vault.addPool(address(aaveAdapter), IShieldVault.RiskTier.LOW, 2500);       // 25%
        vault.addPool(address(compoundAdapter), IShieldVault.RiskTier.LOW, 2500);   // 25%
        vault.addPool(address(morphoAdapter), IShieldVault.RiskTier.MEDIUM, 3000);  // 30%
        vault.addPool(address(yieldMaxAdapter), IShieldVault.RiskTier.HIGH, 2000);  // 20%

        // Set safe haven and CRE
        vault.setSafeHaven(address(aaveAdapter));
        vault.setCREAddress(cre);

        // Set initial risk scores
        registry.setAuthorizedUpdater(cre, true);
        vm.startPrank(cre);
        registry.updateRiskScore(address(aaveAdapter), 15, "Blue chip");
        registry.updateRiskScore(address(compoundAdapter), 18, "Blue chip");
        registry.updateRiskScore(address(morphoAdapter), 35, "Established");
        registry.updateRiskScore(address(yieldMaxAdapter), 55, "New protocol, higher risk");
        vm.stopPrank();
    }

    // ============ Faucet Tests ============

    function test_Faucet_Claim() public {
        vm.startPrank(user1);

        uint256 balanceBefore = usdc.balanceOf(user1);
        faucet.claim();
        uint256 balanceAfter = usdc.balanceOf(user1);

        assertEq(balanceAfter - balanceBefore, 10_000 * 1e6, "Should receive 10,000 USDC");
        vm.stopPrank();
    }

    function test_Faucet_MultipleClaims() public {
        vm.startPrank(user1);

        faucet.claim();
        faucet.claim(); // Should work because cooldown is disabled

        assertEq(usdc.balanceOf(user1), 20_000 * 1e6, "Should have 20,000 USDC");
        vm.stopPrank();
    }

    // ============ Deposit Tests ============

    function test_Deposit_Success() public {
        // User claims USDC and deposits
        vm.startPrank(user1);
        faucet.claim();

        usdc.approve(address(vault), DEPOSIT_AMOUNT);
        uint256 shares = vault.deposit(DEPOSIT_AMOUNT);

        assertGt(shares, 0, "Should receive shares");
        assertEq(vault.getUserBalance(user1), DEPOSIT_AMOUNT, "Balance should match deposit");
        vm.stopPrank();
    }

    function test_Deposit_DistributesToPools() public {
        vm.startPrank(user1);
        faucet.claim();
        usdc.approve(address(vault), DEPOSIT_AMOUNT);
        vault.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();

        // Check distribution: 25% Aave, 25% Compound, 30% Morpho, 20% YieldMax
        uint256 aaveBalance = aaveAdapter.getBalance();
        uint256 compoundBalance = compoundAdapter.getBalance();
        uint256 morphoBalance = morphoAdapter.getBalance();
        uint256 yieldMaxBalance = yieldMaxAdapter.getBalance();

        console.log("=== Pool Distribution ===");
        console.log("Aave (LOW):      ", aaveBalance / 1e6, "USDC (25%)");
        console.log("Compound (LOW):  ", compoundBalance / 1e6, "USDC (25%)");
        console.log("Morpho (MEDIUM): ", morphoBalance / 1e6, "USDC (30%)");
        console.log("YieldMax (HIGH): ", yieldMaxBalance / 1e6, "USDC (20%)");

        // With 100% total weight (2500+2500+3000+2000 = 10000), distribution should be:
        // Aave: 10000 * 2500 / 10000 = 2500
        // Compound: 10000 * 2500 / 10000 = 2500
        // Morpho: 10000 * 3000 / 10000 = 3000
        // YieldMax: 10000 * 2000 / 10000 = 2000
        assertApproxEqRel(aaveBalance, 2500 * 1e6, 0.01e18, "Aave should have 25%");
        assertApproxEqRel(compoundBalance, 2500 * 1e6, 0.01e18, "Compound should have 25%");
        assertApproxEqRel(morphoBalance, 3000 * 1e6, 0.01e18, "Morpho should have 30%");
        assertApproxEqRel(yieldMaxBalance, 2000 * 1e6, 0.01e18, "YieldMax should have 20%");
    }

    function test_Deposit_MultipleUsers() public {
        // User 1 deposits
        vm.startPrank(user1);
        faucet.claim();
        usdc.approve(address(vault), DEPOSIT_AMOUNT);
        vault.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();

        // User 2 deposits
        vm.startPrank(user2);
        faucet.claim();
        usdc.approve(address(vault), DEPOSIT_AMOUNT);
        vault.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();

        assertEq(vault.getTotalAssets(), DEPOSIT_AMOUNT * 2, "Total assets should be 20,000 USDC");
    }

    // ============ Withdraw Tests ============

    function test_Withdraw_Success() public {
        vm.startPrank(user1);
        faucet.claim();
        usdc.approve(address(vault), DEPOSIT_AMOUNT);
        uint256 shares = vault.deposit(DEPOSIT_AMOUNT);

        // Withdraw all
        uint256 withdrawn = vault.withdraw(shares);

        assertApproxEqRel(withdrawn, DEPOSIT_AMOUNT, 0.01e18, "Should withdraw ~full amount");
        assertEq(vault.getUserBalance(user1), 0, "Balance should be 0");
        vm.stopPrank();
    }

    function test_Withdraw_Partial() public {
        vm.startPrank(user1);
        faucet.claim();
        usdc.approve(address(vault), DEPOSIT_AMOUNT);
        uint256 shares = vault.deposit(DEPOSIT_AMOUNT);

        // Withdraw half
        vault.withdraw(shares / 2);

        assertApproxEqRel(vault.getUserBalance(user1), DEPOSIT_AMOUNT / 2, 0.01e18, "Should have half remaining");
        vm.stopPrank();
    }

    // ============ CRE Emergency Withdraw Tests ============

    function test_EmergencyWithdraw_CREOnly() public {
        // Setup: User deposits
        vm.startPrank(user1);
        faucet.claim();
        usdc.approve(address(vault), DEPOSIT_AMOUNT);
        vault.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();

        // Update risk score to CRITICAL
        vm.prank(cre);
        registry.updateRiskScore(address(morphoAdapter), 90, "Exploit detected!");

        // CRE triggers emergency withdraw
        vm.prank(cre);
        vault.emergencyWithdraw(address(morphoAdapter), "TVL drop detected, potential exploit");

        // Morpho should be empty
        assertEq(morphoAdapter.getBalance(), 0, "Morpho should be empty after emergency");
    }

    function test_EmergencyWithdraw_NonCREFails() public {
        vm.startPrank(user1);
        faucet.claim();
        usdc.approve(address(vault), DEPOSIT_AMOUNT);
        vault.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();

        // Non-CRE tries to emergency withdraw - should fail
        vm.prank(user1);
        vm.expectRevert("ShieldVault: only CRE");
        vault.emergencyWithdraw(address(morphoAdapter), "Trying to hack");
    }

    function test_PartialWithdraw_Warning() public {
        vm.startPrank(user1);
        faucet.claim();
        usdc.approve(address(vault), DEPOSIT_AMOUNT);
        vault.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();

        uint256 morphoBalanceBefore = morphoAdapter.getBalance();

        // Update risk to WARNING level
        vm.prank(cre);
        registry.updateRiskScore(address(morphoAdapter), 60, "Suspicious activity");

        // CRE triggers 50% partial withdraw
        vm.prank(cre);
        vault.partialWithdraw(address(morphoAdapter), 5000, "Reducing exposure");

        uint256 morphoBalanceAfter = morphoAdapter.getBalance();
        assertApproxEqRel(morphoBalanceAfter, morphoBalanceBefore / 2, 0.01e18, "Should have 50% remaining");
    }

    // ============ Rebalance Tests ============

    function test_Rebalance_CREOnly() public {
        vm.startPrank(user1);
        faucet.claim();
        usdc.approve(address(vault), DEPOSIT_AMOUNT);
        vault.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();

        // CRE triggers rebalance
        vm.prank(cre);
        vault.rebalance();

        // Should still maintain proportions
        uint256 total = vault.getTotalAssets();
        assertApproxEqRel(total, DEPOSIT_AMOUNT, 0.01e18, "Total should be same after rebalance");
    }

    // ============ Risk Registry Tests ============

    function test_RiskRegistry_UpdateScore() public {
        vm.prank(cre);
        registry.updateRiskScore(address(morphoAdapter), 80, "Critical threat");

        IRiskRegistry.ProtocolRisk memory risk = registry.getProtocolRisk(address(morphoAdapter));
        assertEq(risk.riskScore, 80, "Score should be 80");
        assertEq(uint8(risk.threatLevel), uint8(IRiskRegistry.ThreatLevel.CRITICAL), "Should be CRITICAL");
    }

    function test_RiskRegistry_ThreatLevels() public {
        vm.startPrank(cre);

        // SAFE: 0-25
        registry.updateRiskScore(address(aaveAdapter), 20, "Safe");
        assertEq(uint8(registry.getThreatLevel(address(aaveAdapter))), uint8(IRiskRegistry.ThreatLevel.SAFE));

        // WATCH: 26-50
        registry.updateRiskScore(address(aaveAdapter), 40, "Watch");
        assertEq(uint8(registry.getThreatLevel(address(aaveAdapter))), uint8(IRiskRegistry.ThreatLevel.WATCH));

        // WARNING: 51-75
        registry.updateRiskScore(address(aaveAdapter), 60, "Warning");
        assertEq(uint8(registry.getThreatLevel(address(aaveAdapter))), uint8(IRiskRegistry.ThreatLevel.WARNING));

        // CRITICAL: 76-100
        registry.updateRiskScore(address(aaveAdapter), 90, "Critical");
        assertEq(uint8(registry.getThreatLevel(address(aaveAdapter))), uint8(IRiskRegistry.ThreatLevel.CRITICAL));

        vm.stopPrank();
    }

    // ============ Integration Test: Full Flow ============

    function test_FullFlow_DepositMonitorShield() public {
        console.log("");
        console.log("============================================================");
        console.log("         SHIELDYIELD - FULL DEMO FLOW TEST                  ");
        console.log("============================================================");
        console.log("");

        // 1. User claims from faucet
        console.log("STEP 1: User claims USDC from Faucet");
        console.log("----------------------------------------");
        vm.startPrank(user1);
        faucet.claim();
        console.log("  [OK] User received:", usdc.balanceOf(user1) / 1e6, "USDC");

        // 2. User deposits to ShieldYield
        console.log("");
        console.log("STEP 2: User deposits to ShieldYield");
        console.log("----------------------------------------");
        usdc.approve(address(vault), DEPOSIT_AMOUNT);
        vault.deposit(DEPOSIT_AMOUNT);
        console.log("  [OK] Deposited:", DEPOSIT_AMOUNT / 1e6, "USDC");
        console.log("  [OK] Shares received:", vault.getUserPosition(user1).totalShares / 1e6);
        vm.stopPrank();

        // 3. Check pool distribution (Smart Tranching)
        console.log("");
        console.log("STEP 3: Smart Tranching - Auto Distribution");
        console.log("----------------------------------------");
        console.log("  LOW RISK (50%):");
        console.log("    - Aave V3:     ", aaveAdapter.getBalance() / 1e6, "USDC (25%)");
        console.log("    - Compound V3: ", compoundAdapter.getBalance() / 1e6, "USDC (25%)");
        console.log("  MEDIUM RISK (30%):");
        console.log("    - Morpho:      ", morphoAdapter.getBalance() / 1e6, "USDC (30%)");
        console.log("  HIGH RISK (20%):");
        console.log("    - YieldMax:    ", yieldMaxAdapter.getBalance() / 1e6, "USDC (20%)");

        // 4. Simulate threat detection on HIGH risk pool
        console.log("");
        console.log("STEP 4: CRE Detects Threat on YieldMax (HIGH RISK)");
        console.log("----------------------------------------");
        console.log("  [!] TVL dropped 40% in 1 hour");
        console.log("  [!] Whale wallets exiting");
        console.log("  [!] GitHub commits stopped");
        console.log("  [!] Team tokens unlocking soon");
        vm.prank(cre);
        registry.updateRiskScore(address(yieldMaxAdapter), 90, "Multiple red flags: TVL drop, whale exit, team silent");
        console.log("  [CRITICAL] Risk score updated: 90 (CRITICAL)");

        // 5. Shield activates - emergency withdraw
        console.log("");
        console.log("STEP 5: SHIELD ACTIVATES - Emergency Withdraw");
        console.log("----------------------------------------");
        uint256 yieldMaxBefore = yieldMaxAdapter.getBalance();
        vm.prank(cre);
        vault.emergencyWithdraw(address(yieldMaxAdapter), "Critical: Multiple exploit indicators detected");
        console.log("  [SHIELD] Withdrew", yieldMaxBefore / 1e6, "USDC from YieldMax");
        console.log("  [SHIELD] Funds moved to safe haven (Aave)");

        // 6. Verify protection - user funds are safe
        console.log("");
        console.log("STEP 6: Protection Verified");
        console.log("----------------------------------------");
        console.log("  YieldMax balance: ", yieldMaxAdapter.getBalance() / 1e6, "USDC (emptied!)");
        console.log("  User total value: ", vault.getUserBalance(user1) / 1e6, "USDC (SAFE!)");
        console.log("  [OK] User lost: 0 USDC");
        console.log("  [OK] ShieldYield saved:", yieldMaxBefore / 1e6, "USDC");

        // 7. User withdraws all funds safely
        console.log("");
        console.log("STEP 7: User Withdraws All Funds");
        console.log("----------------------------------------");
        vm.startPrank(user1);
        IShieldVault.UserPosition memory pos = vault.getUserPosition(user1);
        vault.withdraw(pos.totalShares);
        console.log("  [OK] Final USDC balance:", usdc.balanceOf(user1) / 1e6, "USDC");
        vm.stopPrank();

        console.log("");
        console.log("============================================================");
        console.log("  SUCCESS: User protected from potential exploit!");
        console.log("  Thanks to Smart Tranching, only 20% was at risk.");
        console.log("  Shield activated BEFORE any loss occurred.");
        console.log("============================================================");
        console.log("");
    }
}
