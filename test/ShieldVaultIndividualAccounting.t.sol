// SPDX-License-Identifier: MIT
import {Test, console} from "forge-std/Test.sol";
import {ShieldVault} from "../src/ShieldVault.sol";
import {IShieldVault} from "../src/interfaces/IShieldVault.sol";
import {IRiskRegistry} from "../src/interfaces/IRiskRegistry.sol";
import {RiskRegistry} from "../src/RiskRegistry.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockProtocolAdapter} from "../src/mocks/MockProtocolAdapter.sol";

contract ShieldVaultIndividualAccountingTest is Test {
    ShieldVault public vault;
    RiskRegistry public registry;
    MockERC20 public asset;
    MockProtocolAdapter public adapter1;

    address public owner = address(this);
    address public creAddress = address(0x10);
    address public bridgeAddress = address(0x20); // The address posing as the bridge

    address public alice = address(0xA);
    address public bob = address(0xB);

    function setUp() public {
        asset = new MockERC20("USDC", "USDC", 18);
        registry = new RiskRegistry();
        vault = new ShieldVault(address(asset), address(registry));

        vault.setCREAddress(creAddress);
        vault.setBridgeAddress(bridgeAddress);

        adapter1 = new MockProtocolAdapter(address(asset), "Aave", 500);
        adapter1.setShieldVault(address(vault));
        vault.addPool(address(adapter1), IShieldVault.RiskTier.LOW, 10000); // 100% allocation

        asset.mint(address(vault), 0);
    }

    function test_CCIPBridgeDepositForGoesToPool() public {
        uint256 bridgeAmount = 1000e18;
        asset.mint(bridgeAddress, bridgeAmount);

        vm.startPrank(bridgeAddress);
        asset.approve(address(vault), bridgeAmount);
        // CCIP calls depositFor(OriginalSender, amount)
        // Here, original sender is the source chain vault address (could be anything, proxy logic intercepts it if msg.sender == shieldBridge)
        uint256 sharesMinted = vault.depositFor(address(0x999), bridgeAmount);
        vm.stopPrank();

        assertEq(sharesMinted, 0, "Should mint 0 shares");
        assertEq(
            vault.totalCrossChainPool(),
            bridgeAmount,
            "Should go to cross chain pool"
        );
        assertEq(
            adapter1.getBalance(),
            bridgeAmount,
            "Should invest into adapters automatically"
        );
        assertEq(vault.totalShares(), 0, "No actual shares minted yet");
    }

    function test_CRECanSetClaims() public {
        test_CCIPBridgeDepositForGoesToPool();

        address[] memory users = new address[](2);
        users[0] = alice;
        users[1] = bob;

        uint256[] memory claims = new uint256[](2);
        claims[0] = 600e18;
        claims[1] = 400e18;

        vm.prank(creAddress);
        vault.setCrossChainClaims(users, claims);

        assertEq(vault.crossChainClaims(alice), 600e18);
        assertEq(vault.crossChainClaims(bob), 400e18);
    }

    function test_UserCanClaimFunds() public {
        test_CRECanSetClaims();

        // Alice claims her 600 USDC
        vm.prank(alice);
        vault.claimCrossChainFunds();

        assertEq(
            vault.crossChainClaims(alice),
            0,
            "Alice claim should be zeroed"
        );
        assertEq(
            vault.totalCrossChainPool(),
            400e18,
            "Pool should deduct Alice claim"
        );

        // Alice should have shares equal precisely to 600
        uint256 aliceShares = vault.getUserPosition(alice).totalShares;
        assertEq(
            aliceShares,
            600e18,
            "Alice should have 600 shares since it's the first claim"
        );

        assertEq(
            vault.getTotalAssets(),
            1000e18,
            "Total assets remain the same because they were already in the adapter"
        );

        // Bob claims his 400 USDC
        vm.prank(bob);
        vault.claimCrossChainFunds();

        assertEq(vault.crossChainClaims(bob), 0);
        assertEq(vault.totalCrossChainPool(), 0);

        uint256 bobShares = vault.getUserPosition(bob).totalShares;
        assertEq(bobShares, 400e18, "Bob should have exactly 400 shares");

        // Alice and Bob should collectively own the 1000 USDC
        assertEq(vault.getUserBalance(alice), 600e18);
        assertEq(vault.getUserBalance(bob), 400e18);
    }
}
