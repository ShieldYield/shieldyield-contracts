// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IRouterClient, IAny2EVMMessageReceiver} from "./IRouterClient.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title ShieldBridge
/// @notice CCIP-powered emergency bridge for cross-chain asset protection
/// @dev Layer 4 of ShieldYield protection - bridges assets to safe chain during emergencies
///
/// Emergency Flow:
/// 1. Dana di Arbitrum, protocol kena exploit
/// 2. Shield activate → Withdraw USDC dari protocol
/// 3. CCIP bridge USDC dari Arbitrum → Base
/// 4. Deposit ke Aave di Base (safe haven)
///
contract ShieldBridge is IAny2EVMMessageReceiver, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ State Variables ============

    /// @notice Chainlink CCIP Router
    IRouterClient public immutable router;

    /// @notice ShieldVault address (authorized to trigger emergency bridge)
    address public shieldVault;

    /// @notice CRE address (authorized to trigger emergency bridge)
    address public creAddress;

    /// @notice Mapping of destination chain selector to bridge receiver address
    mapping(uint64 => address) public chainToReceiver;

    /// @notice Mapping of destination chain selector to safe haven adapter
    mapping(uint64 => address) public chainToSafeHaven;

    /// @notice Supported destination chains
    uint64[] public supportedChains;

    /// @notice Emergency bridge counter
    uint256 public emergencyBridgeCount;

    // ============ CCIP Chain Selectors ============

    // Mainnet chain selectors
    uint64 public constant ETHEREUM_SELECTOR = 5009297550715157269;
    uint64 public constant ARBITRUM_SELECTOR = 4949039107694359620;
    uint64 public constant BASE_SELECTOR = 15971525489660198786;
    uint64 public constant OPTIMISM_SELECTOR = 3734403246176062136;
    uint64 public constant POLYGON_SELECTOR = 4051577828743386545;
    uint64 public constant AVALANCHE_SELECTOR = 6433500567565415381;

    // Testnet chain selectors (Sepolia ecosystem)
    uint64 public constant SEPOLIA_SELECTOR = 16015286601757825753;
    uint64 public constant ARB_SEPOLIA_SELECTOR = 3478487238524512106;
    uint64 public constant BASE_SEPOLIA_SELECTOR = 10344971235874465080;
    uint64 public constant OP_SEPOLIA_SELECTOR = 5224473277236331295;

    // ============ Events ============

    event EmergencyBridgeInitiated(
        bytes32 indexed messageId,
        uint64 indexed destinationChain,
        address indexed token,
        uint256 amount,
        address sender
    );

    event EmergencyBridgeReceived(
        bytes32 indexed messageId,
        uint64 indexed sourceChain,
        address indexed token,
        uint256 amount
    );

    event ReceiverUpdated(uint64 indexed chainSelector, address receiver);
    event SafeHavenUpdated(uint64 indexed chainSelector, address safeHaven);
    event ShieldVaultUpdated(address oldVault, address newVault);
    event CREAddressUpdated(address oldCRE, address newCRE);

    // ============ Errors ============

    error InvalidRouter();
    error InvalidChain();
    error UnsupportedChain(uint64 chainSelector);
    error UnsupportedToken(address token);
    error InsufficientFee(uint256 required, uint256 provided);
    error OnlyShieldVaultOrCRE();
    error OnlyRouter();
    error BridgeFailed();
    error InvalidReceiver();

    // ============ Modifiers ============

    modifier onlyShieldVaultOrCRE() {
        if (msg.sender != shieldVault && msg.sender != creAddress && msg.sender != owner()) {
            revert OnlyShieldVaultOrCRE();
        }
        _;
    }

    modifier onlyRouter() {
        if (msg.sender != address(router)) {
            revert OnlyRouter();
        }
        _;
    }

    // ============ Constructor ============

    /// @notice Initialize ShieldBridge with CCIP Router
    /// @param _router Chainlink CCIP Router address
    constructor(address _router) Ownable(msg.sender) {
        if (_router == address(0)) revert InvalidRouter();
        router = IRouterClient(_router);
    }

    // ============ Emergency Bridge Functions ============

    /// @notice Emergency bridge tokens to safe chain
    /// @dev Only callable by ShieldVault, CRE, or owner during emergencies
    /// @param token Token address to bridge
    /// @param amount Amount to bridge
    /// @param destinationChainSelector Destination chain CCIP selector
    /// @return messageId CCIP message ID for tracking
    function emergencyBridge(
        address token,
        uint256 amount,
        uint64 destinationChainSelector
    ) external payable onlyShieldVaultOrCRE nonReentrant returns (bytes32 messageId) {
        // Validate destination chain
        address receiver = chainToReceiver[destinationChainSelector];
        if (receiver == address(0)) revert UnsupportedChain(destinationChainSelector);

        // Transfer tokens from caller
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        // Approve router to spend tokens
        IERC20(token).safeIncreaseAllowance(address(router), amount);

        // Build CCIP message
        IRouterClient.EVMTokenAmount[] memory tokenAmounts = new IRouterClient.EVMTokenAmount[](1);
        tokenAmounts[0] = IRouterClient.EVMTokenAmount({
            token: token,
            amount: amount
        });

        // Encode payload: action type + safe haven address
        address safeHaven = chainToSafeHaven[destinationChainSelector];
        bytes memory payload = abi.encode(
            "EMERGENCY_DEPOSIT", // action
            safeHaven,           // safe haven adapter on destination
            msg.sender           // original sender for tracking
        );

        IRouterClient.EVM2AnyMessage memory message = IRouterClient.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: payload,
            tokenAmounts: tokenAmounts,
            feeToken: address(0), // Pay in native token
            extraArgs: _buildCCIPExtraArgs()
        });

        // Get fee
        uint256 fee = router.getFee(destinationChainSelector, message);
        if (msg.value < fee) revert InsufficientFee(fee, msg.value);

        // Send CCIP message
        messageId = router.ccipSend{value: fee}(destinationChainSelector, message);

        emergencyBridgeCount++;

        emit EmergencyBridgeInitiated(
            messageId,
            destinationChainSelector,
            token,
            amount,
            msg.sender
        );

        // Refund excess ETH
        if (msg.value > fee) {
            (bool success, ) = msg.sender.call{value: msg.value - fee}("");
            require(success, "Refund failed");
        }

        return messageId;
    }

    /// @notice Get fee estimate for emergency bridge
    /// @param token Token address to bridge
    /// @param amount Amount to bridge
    /// @param destinationChainSelector Destination chain CCIP selector
    /// @return fee Fee in native token (ETH)
    function getEmergencyBridgeFee(
        address token,
        uint256 amount,
        uint64 destinationChainSelector
    ) external view returns (uint256 fee) {
        address receiver = chainToReceiver[destinationChainSelector];
        if (receiver == address(0)) revert UnsupportedChain(destinationChainSelector);

        IRouterClient.EVMTokenAmount[] memory tokenAmounts = new IRouterClient.EVMTokenAmount[](1);
        tokenAmounts[0] = IRouterClient.EVMTokenAmount({
            token: token,
            amount: amount
        });

        address safeHaven = chainToSafeHaven[destinationChainSelector];
        bytes memory payload = abi.encode("EMERGENCY_DEPOSIT", safeHaven, msg.sender);

        IRouterClient.EVM2AnyMessage memory message = IRouterClient.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: payload,
            tokenAmounts: tokenAmounts,
            feeToken: address(0),
            extraArgs: _buildCCIPExtraArgs()
        });

        return router.getFee(destinationChainSelector, message);
    }

    // ============ CCIP Receiver ============

    /// @notice Handle incoming CCIP message
    /// @dev Called by CCIP Router when receiving cross-chain message
    /// @param message The received CCIP message
    function ccipReceive(Any2EVMMessage calldata message) external override onlyRouter {
        // Decode payload
        (string memory action, address safeHaven, address originalSender) =
            abi.decode(message.data, (string, address, address));

        // Process received tokens
        for (uint256 i = 0; i < message.destTokenAmounts.length; i++) {
            address token = message.destTokenAmounts[i].token;
            uint256 amount = message.destTokenAmounts[i].amount;

            // If action is EMERGENCY_DEPOSIT and safe haven is set, deposit there
            if (keccak256(bytes(action)) == keccak256(bytes("EMERGENCY_DEPOSIT")) && safeHaven != address(0)) {
                // Approve safe haven to spend tokens
                IERC20(token).safeIncreaseAllowance(safeHaven, amount);

                // Call deposit on safe haven (assuming it has a deposit function)
                // Note: Safe haven should be a ShieldVault or similar on destination chain
                (bool success, ) = safeHaven.call(
                    abi.encodeWithSignature("depositFor(address,uint256)", originalSender, amount)
                );

                // If deposit fails, tokens stay in bridge (can be rescued by owner)
                if (!success) {
                    // Tokens are safe in this contract, can be manually handled
                }
            }

            emit EmergencyBridgeReceived(
                message.messageId,
                message.sourceChainSelector,
                token,
                amount
            );
        }
    }

    // ============ Admin Functions ============

    /// @notice Set ShieldVault address
    /// @param _shieldVault New ShieldVault address
    function setShieldVault(address _shieldVault) external onlyOwner {
        emit ShieldVaultUpdated(shieldVault, _shieldVault);
        shieldVault = _shieldVault;
    }

    /// @notice Set CRE address
    /// @param _creAddress New CRE address
    function setCREAddress(address _creAddress) external onlyOwner {
        emit CREAddressUpdated(creAddress, _creAddress);
        creAddress = _creAddress;
    }

    /// @notice Set bridge receiver for a destination chain
    /// @param chainSelector Destination chain CCIP selector
    /// @param receiver ShieldBridge address on destination chain
    function setChainReceiver(uint64 chainSelector, address receiver) external onlyOwner {
        if (receiver == address(0)) revert InvalidReceiver();

        // Add to supported chains if new
        if (chainToReceiver[chainSelector] == address(0)) {
            supportedChains.push(chainSelector);
        }

        chainToReceiver[chainSelector] = receiver;
        emit ReceiverUpdated(chainSelector, receiver);
    }

    /// @notice Set safe haven adapter for a destination chain
    /// @param chainSelector Destination chain CCIP selector
    /// @param safeHaven Safe haven adapter address on destination chain
    function setChainSafeHaven(uint64 chainSelector, address safeHaven) external onlyOwner {
        chainToSafeHaven[chainSelector] = safeHaven;
        emit SafeHavenUpdated(chainSelector, safeHaven);
    }

    /// @notice Get all supported destination chains
    /// @return chains Array of supported chain selectors
    function getSupportedChains() external view returns (uint64[] memory) {
        return supportedChains;
    }

    /// @notice Rescue tokens stuck in bridge
    /// @param token Token address to rescue
    /// @param to Recipient address
    /// @param amount Amount to rescue
    function rescueTokens(address token, address to, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(to, amount);
    }

    /// @notice Rescue ETH stuck in bridge
    /// @param to Recipient address
    function rescueETH(address to) external onlyOwner {
        (bool success, ) = to.call{value: address(this).balance}("");
        require(success, "ETH rescue failed");
    }

    // ============ Internal Functions ============

    /// @notice Build CCIP extra args for gas limit
    /// @return extraArgs Encoded extra args
    function _buildCCIPExtraArgs() internal pure returns (bytes memory) {
        // CCIP extra args v1 tag
        // gasLimit: 500_000 for safe haven deposit
        return abi.encodePacked(
            bytes4(0x97a657c9), // CCIP_EXTRA_ARGS_V1_TAG
            abi.encode(uint256(500_000)) // gasLimit
        );
    }

    /// @notice Allow contract to receive ETH for CCIP fees
    receive() external payable {}
}
