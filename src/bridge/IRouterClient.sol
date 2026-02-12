// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Chainlink CCIP Router Client Interface
/// @notice Interface for interacting with Chainlink CCIP Router
interface IRouterClient {
    /// @notice CCIP EVM2Any message structure
    struct EVM2AnyMessage {
        bytes receiver; // abi.encode(receiverAddress) for EVM chains
        bytes data; // arbitrary data payload
        EVMTokenAmount[] tokenAmounts; // tokens to transfer
        address feeToken; // address(0) means native token
        bytes extraArgs; // extra arguments for the message
    }

    /// @notice Token amount structure
    struct EVMTokenAmount {
        address token;
        uint256 amount;
    }

    /// @notice Get the fee for sending a message
    /// @param destinationChainSelector The destination chain selector
    /// @param message The message to send
    /// @return fee The fee in the fee token
    function getFee(
        uint64 destinationChainSelector,
        EVM2AnyMessage memory message
    ) external view returns (uint256 fee);

    /// @notice Send a message to the destination chain
    /// @param destinationChainSelector The destination chain selector
    /// @param message The message to send
    /// @return messageId The message ID
    function ccipSend(
        uint64 destinationChainSelector,
        EVM2AnyMessage calldata message
    ) external payable returns (bytes32 messageId);

    /// @notice Check if a chain is supported
    /// @param chainSelector The chain selector to check
    /// @return supported Whether the chain is supported
    function isChainSupported(uint64 chainSelector) external view returns (bool supported);

    /// @notice Get supported tokens for a destination chain
    /// @param chainSelector The destination chain selector
    /// @return tokens Array of supported token addresses
    function getSupportedTokens(uint64 chainSelector) external view returns (address[] memory tokens);
}

/// @title CCIP Receiver Interface
/// @notice Interface for contracts that receive CCIP messages
interface IAny2EVMMessageReceiver {
    /// @notice CCIP Any2EVM message structure
    struct Any2EVMMessage {
        bytes32 messageId;
        uint64 sourceChainSelector;
        bytes sender;
        bytes data;
        EVMTokenAmount[] destTokenAmounts;
    }

    /// @notice Token amount structure
    struct EVMTokenAmount {
        address token;
        uint256 amount;
    }

    /// @notice Handle a received message
    /// @param message The received message
    function ccipReceive(Any2EVMMessage calldata message) external;
}
