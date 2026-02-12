// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IShieldBridge} from "../interfaces/IShieldBridge.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title MockShieldBridge
/// @notice Mock CCIP bridge for testing - simulates cross-chain transfer
/// @dev Holds tokens locally and simulates the bridge behavior
contract MockShieldBridge is IShieldBridge, Ownable {
    using SafeERC20 for IERC20;

    // ============ State ============

    address public shieldVault;
    address public creAddress;
    uint256 public override emergencyBridgeCount;
    uint256 public mockFee = 0.01 ether;

    mapping(uint64 => address) public override chainToReceiver;
    mapping(uint64 => address) public override chainToSafeHaven;
    uint64[] private _supportedChains;

    // Track bridged amounts for testing
    mapping(uint64 => mapping(address => uint256)) public bridgedAmounts;

    // ============ Events ============

    event MockEmergencyBridge(
        bytes32 indexed messageId,
        uint64 indexed destinationChain,
        address indexed token,
        uint256 amount,
        address sender
    );

    event MockBridgeReceived(
        uint64 indexed sourceChain,
        address indexed token,
        uint256 amount,
        address safeHaven
    );

    // ============ Constructor ============

    constructor() Ownable(msg.sender) {}

    // ============ Bridge Functions ============

    /// @notice Mock emergency bridge - holds tokens locally
    function emergencyBridge(
        address token,
        uint256 amount,
        uint64 destinationChainSelector
    ) external payable override returns (bytes32 messageId) {
        require(chainToReceiver[destinationChainSelector] != address(0), "Unsupported chain");
        require(msg.value >= mockFee, "Insufficient fee");

        // Transfer tokens from caller
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        // Track bridged amount
        bridgedAmounts[destinationChainSelector][token] += amount;
        emergencyBridgeCount++;

        // Generate mock message ID
        messageId = keccak256(abi.encodePacked(
            block.timestamp,
            destinationChainSelector,
            token,
            amount,
            msg.sender,
            emergencyBridgeCount
        ));

        emit MockEmergencyBridge(
            messageId,
            destinationChainSelector,
            token,
            amount,
            msg.sender
        );

        // Refund excess ETH
        if (msg.value > mockFee) {
            (bool success, ) = msg.sender.call{value: msg.value - mockFee}("");
            require(success, "Refund failed");
        }

        return messageId;
    }

    /// @notice Get mock fee
    function getEmergencyBridgeFee(
        address,
        uint256,
        uint64 destinationChainSelector
    ) external view override returns (uint256) {
        require(chainToReceiver[destinationChainSelector] != address(0), "Unsupported chain");
        return mockFee;
    }

    /// @notice Simulate receiving bridged tokens (for testing)
    /// @dev Call this to simulate tokens arriving from source chain
    function simulateBridgeReceive(
        uint64 sourceChain,
        address token,
        uint256 amount,
        address safeHaven
    ) external onlyOwner {
        // Mint or transfer tokens to safe haven
        // In real scenario, CCIP would deliver the tokens

        if (safeHaven != address(0)) {
            // Approve and deposit to safe haven
            IERC20(token).safeIncreaseAllowance(safeHaven, amount);

            // Try to call deposit on safe haven
            (bool success, ) = safeHaven.call(
                abi.encodeWithSignature("deposit(uint256)", amount)
            );

            // If deposit fails, tokens stay in bridge
            if (!success) {
                // Tokens are safe here
            }
        }

        emit MockBridgeReceived(sourceChain, token, amount, safeHaven);
    }

    // ============ View Functions ============

    function getSupportedChains() external view override returns (uint64[] memory) {
        return _supportedChains;
    }

    function getBridgedAmount(uint64 chainSelector, address token) external view returns (uint256) {
        return bridgedAmounts[chainSelector][token];
    }

    // ============ Admin Functions ============

    function setShieldVault(address _shieldVault) external onlyOwner {
        shieldVault = _shieldVault;
    }

    function setCREAddress(address _creAddress) external onlyOwner {
        creAddress = _creAddress;
    }

    function setChainReceiver(uint64 chainSelector, address receiver) external onlyOwner {
        if (chainToReceiver[chainSelector] == address(0)) {
            _supportedChains.push(chainSelector);
        }
        chainToReceiver[chainSelector] = receiver;
    }

    function setChainSafeHaven(uint64 chainSelector, address safeHaven) external onlyOwner {
        chainToSafeHaven[chainSelector] = safeHaven;
    }

    function setMockFee(uint256 _fee) external onlyOwner {
        mockFee = _fee;
    }

    function rescueTokens(address token, address to, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(to, amount);
    }

    function rescueETH(address to) external onlyOwner {
        (bool success, ) = to.call{value: address(this).balance}("");
        require(success, "ETH rescue failed");
    }

    receive() external payable {}
}
