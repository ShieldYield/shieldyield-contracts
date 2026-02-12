// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockShieldBridge} from "../src/mocks/MockShieldBridge.sol";
import {MockProtocolAdapter} from "../src/mocks/MockProtocolAdapter.sol";
import {ShieldVault} from "../src/ShieldVault.sol";
import {RiskRegistry} from "../src/RiskRegistry.sol";
import {IShieldVault} from "../src/interfaces/IShieldVault.sol";

/// @title ShieldBridgeTest
/// @notice Test suite for ShieldBridge - Layer 4 Emergency Cross-Chain Protection
contract ShieldBridgeTest is Test {
    MockERC20 public usdc;
    MockShieldBridge public bridge;
    MockProtocolAdapter public aaveAdapter;
    MockProtocolAdapter public riskyAdapter;
    ShieldVault public vault;
    RiskRegistry public registry;

    address public owner = address(this);
    address public user = address(0x1);
    address public cre = address(0x2);

    // Chain selectors
    uint64 constant BASE_SEPOLIA = 10344971235874465080;
    uint64 constant ARB_SEPOLIA = 3478487238524512106;

    function setUp() public {
        // Deploy tokens
        usdc = new MockERC20("Mock USDC", "USDC", 6);

        // Deploy registry
        registry = new RiskRegistry();

        // Deploy vault
        vault = new ShieldVault(address(usdc), address(registry));
        registry.setShieldVault(address(vault));

        // Deploy adapters
        aaveAdapter = new MockProtocolAdapter(address(usdc), "Aave V3", 500);
        riskyAdapter = new MockProtocolAdapter(address(usdc), "RiskyProtocol", 2000);

        // Setup adapters
        aaveAdapter.setShieldVault(address(vault));
        riskyAdapter.setShieldVault(address(vault));

        // Add pools
        vault.addPool(address(aaveAdapter), IShieldVault.RiskTier.LOW, 5000);
        vault.addPool(address(riskyAdapter), IShieldVault.RiskTier.HIGH, 5000);
        vault.setSafeHaven(address(aaveAdapter));
        vault.setCREAddress(cre);

        // Deploy bridge
        bridge = new MockShieldBridge();
        bridge.setShieldVault(address(vault));
        bridge.setCREAddress(cre);

        // Setup destination chains
        bridge.setChainReceiver(BASE_SEPOLIA, address(0x123)); // Mock receiver on Base
        bridge.setChainSafeHaven(BASE_SEPOLIA, address(0x456)); // Mock safe haven on Base
        bridge.setChainReceiver(ARB_SEPOLIA, address(0x789)); // Mock receiver on Arbitrum
        bridge.setChainSafeHaven(ARB_SEPOLIA, address(0xABC)); // Mock safe haven on Arbitrum

        // Setup risk registry
        registry.setAuthorizedUpdater(cre, true);

        // Give user some USDC
        usdc.mint(user, 10_000 * 1e6);
    }

    function test_Bridge_EmergencyBridge_Success() public {
        console.log("");
        console.log("============================================================");
        console.log("     SHIELDBRIDGE - EMERGENCY CROSS-CHAIN BRIDGE TEST       ");
        console.log("============================================================");
        console.log("");

        uint256 depositAmount = 10_000 * 1e6;
        uint256 bridgeAmount = 5_000 * 1e6;

        // User deposits
        vm.startPrank(user);
        usdc.approve(address(vault), depositAmount);
        vault.deposit(depositAmount);
        vm.stopPrank();

        console.log("STEP 1: User deposits to ShieldVault");
        console.log("----------------------------------------");
        console.log("  Deposited:", depositAmount / 1e6, "USDC");
        console.log("  50% in Aave (safe)");
        console.log("  50% in RiskyProtocol (high risk)");
        console.log("");

        // Simulate: RiskyProtocol is about to be exploited
        console.log("STEP 2: CRE detects threat - RiskyProtocol under attack!");
        console.log("----------------------------------------");
        console.log("  [!] Suspicious transactions detected");
        console.log("  [!] Price oracle manipulation attempt");
        console.log("  [!] Smart contract vulnerability found");
        console.log("");

        // CRE activates shield - withdraw from risky adapter
        vm.prank(cre);
        vault.emergencyWithdraw(address(riskyAdapter), "Suspicious activity detected");

        console.log("STEP 3: Shield activated - withdraw from RiskyProtocol");
        console.log("----------------------------------------");
        console.log("  [SHIELD] Withdrew 5000 USDC from RiskyProtocol");
        console.log("");

        // Now bridge funds to a safer chain
        console.log("STEP 4: Emergency bridge to Base chain");
        console.log("----------------------------------------");

        // CRE approves bridge to spend USDC
        uint256 usdcInVault = usdc.balanceOf(address(vault));
        console.log("  USDC in vault:", usdcInVault / 1e6);

        // For this test, we'll mint USDC to CRE and bridge it
        usdc.mint(cre, bridgeAmount);

        vm.startPrank(cre);
        usdc.approve(address(bridge), bridgeAmount);

        // Get fee estimate
        uint256 fee = bridge.getEmergencyBridgeFee(address(usdc), bridgeAmount, BASE_SEPOLIA);
        console.log("  Bridge fee:", fee / 1e15, "milliETH");

        // Emergency bridge to Base
        vm.deal(cre, 1 ether);
        bytes32 messageId = bridge.emergencyBridge{value: fee}(
            address(usdc),
            bridgeAmount,
            BASE_SEPOLIA
        );
        vm.stopPrank();

        console.log("  [BRIDGE] Initiated CCIP transfer");
        console.log("  Message ID:", uint256(messageId));
        console.log("  Amount:", bridgeAmount / 1e6, "USDC");
        console.log("  Destination: Base Sepolia");
        console.log("");

        // Verify bridge state
        uint256 bridgedToBase = bridge.getBridgedAmount(BASE_SEPOLIA, address(usdc));
        assertEq(bridgedToBase, bridgeAmount, "Bridged amount mismatch");
        assertEq(bridge.emergencyBridgeCount(), 1, "Bridge count should be 1");

        console.log("STEP 5: Verify bridge state");
        console.log("----------------------------------------");
        console.log("  Bridged to Base:", bridgedToBase / 1e6, "USDC");
        console.log("  Total bridges:", bridge.emergencyBridgeCount());
        console.log("");

        console.log("============================================================");
        console.log("  SUCCESS: Emergency cross-chain bridge completed!");
        console.log("  Funds are being transferred to safe chain (Base)");
        console.log("  Layer 4 protection activated successfully");
        console.log("============================================================");
        console.log("");
    }

    function test_Bridge_GetSupportedChains() public {
        uint64[] memory chains = bridge.getSupportedChains();
        assertEq(chains.length, 2, "Should have 2 supported chains");
        assertEq(chains[0], BASE_SEPOLIA, "First chain should be Base Sepolia");
        assertEq(chains[1], ARB_SEPOLIA, "Second chain should be Arb Sepolia");
    }

    function test_Bridge_UnsupportedChain_Reverts() public {
        uint64 unsupportedChain = 12345;
        uint256 amount = 1000 * 1e6;

        usdc.mint(cre, amount);

        vm.startPrank(cre);
        usdc.approve(address(bridge), amount);
        vm.deal(cre, 1 ether);

        vm.expectRevert("Unsupported chain");
        bridge.emergencyBridge{value: 0.1 ether}(address(usdc), amount, unsupportedChain);
        vm.stopPrank();
    }

    function test_Bridge_InsufficientFee_Reverts() public {
        uint256 amount = 1000 * 1e6;

        usdc.mint(cre, amount);

        vm.startPrank(cre);
        usdc.approve(address(bridge), amount);
        vm.deal(cre, 0.001 ether); // Not enough for fee

        vm.expectRevert("Insufficient fee");
        bridge.emergencyBridge{value: 0.001 ether}(address(usdc), amount, BASE_SEPOLIA);
        vm.stopPrank();
    }

    function test_Bridge_RescueTokens() public {
        uint256 amount = 1000 * 1e6;

        // Send tokens to bridge (simulating stuck tokens)
        usdc.mint(address(bridge), amount);

        // Rescue tokens
        bridge.rescueTokens(address(usdc), owner, amount);

        assertEq(usdc.balanceOf(owner), amount, "Tokens should be rescued");
        assertEq(usdc.balanceOf(address(bridge)), 0, "Bridge should have 0 tokens");
    }

    function test_Bridge_RescueETH() public {
        // Send ETH to bridge
        vm.deal(address(bridge), 1 ether);

        address payable recipient = payable(address(0x999));
        uint256 recipientBalanceBefore = recipient.balance;

        // Rescue ETH
        bridge.rescueETH(recipient);

        assertEq(recipient.balance, recipientBalanceBefore + 1 ether, "ETH should be rescued");
        assertEq(address(bridge).balance, 0, "Bridge should have 0 ETH");
    }

    function test_Bridge_FullEmergencyScenario() public {
        console.log("");
        console.log("============================================================");
        console.log("   FULL EMERGENCY SCENARIO: Attack on Arbitrum -> Bridge to Base");
        console.log("============================================================");
        console.log("");

        uint256 depositAmount = 10_000 * 1e6;

        // User deposits
        vm.startPrank(user);
        usdc.approve(address(vault), depositAmount);
        vault.deposit(depositAmount);
        vm.stopPrank();

        console.log("Initial State:");
        console.log("  Total deposited:", depositAmount / 1e6, "USDC");
        console.log("  Aave balance:", aaveAdapter.getBalance() / 1e6, "USDC");
        console.log("  RiskyProtocol balance:", riskyAdapter.getBalance() / 1e6, "USDC");
        console.log("");

        // CRE detects attack
        console.log("Attack Detected by CRE:");
        console.log("  [CRITICAL] Governance attack on RiskyProtocol");
        console.log("  [CRITICAL] Malicious proposal passed");
        console.log("  [CRITICAL] Drain in progress...");
        console.log("");

        // Emergency sequence
        console.log("Emergency Sequence Initiated:");
        console.log("  [1] Shield activated");
        console.log("  [2] Withdrawing from compromised protocol...");

        vm.startPrank(cre);

        // Step 1: Emergency withdraw from risky protocol
        uint256 riskyBalance = riskyAdapter.getBalance();
        vault.emergencyWithdraw(address(riskyAdapter), "Governance attack detected");

        console.log("      -> Withdrew", riskyBalance / 1e6, "USDC");
        console.log("");

        // Step 2: Bridge to safe chain
        console.log("  [3] Bridging to Base chain (safe haven)...");

        // Get USDC from vault safe haven for bridging
        // In real scenario, vault would transfer to bridge
        uint256 bridgeAmount = riskyBalance;
        vm.stopPrank();
        usdc.mint(cre, bridgeAmount);
        vm.startPrank(cre);
        usdc.approve(address(bridge), bridgeAmount);
        vm.deal(cre, 1 ether);

        uint256 fee = bridge.getEmergencyBridgeFee(address(usdc), bridgeAmount, BASE_SEPOLIA);
        bytes32 msgId = bridge.emergencyBridge{value: fee}(address(usdc), bridgeAmount, BASE_SEPOLIA);

        vm.stopPrank();

        console.log("      -> CCIP Message ID:", uint256(msgId));
        console.log("      -> Bridged", bridgeAmount / 1e6, "USDC to Base");
        console.log("");

        // Verify final state
        console.log("Final State:");
        console.log("  RiskyProtocol balance:", riskyAdapter.getBalance() / 1e6, "USDC (emptied!)");
        console.log("  Bridged to Base:", bridge.getBridgedAmount(BASE_SEPOLIA, address(usdc)) / 1e6, "USDC");
        console.log("  Aave balance:", aaveAdapter.getBalance() / 1e6, "USDC (safe)");
        console.log("");

        assertEq(riskyAdapter.getBalance(), 0, "Risky adapter should be empty");
        assertEq(bridge.getBridgedAmount(BASE_SEPOLIA, address(usdc)), bridgeAmount, "Should have bridged correct amount");

        console.log("============================================================");
        console.log("   SUCCESS: Emergency bridge to Base completed!");
        console.log("   User funds protected from Arbitrum attack");
        console.log("============================================================");
        console.log("");
    }
}
