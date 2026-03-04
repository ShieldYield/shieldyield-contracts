// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title WorkflowLogger
/// @notice Logs CRE Workflow executions on-chain for auditability.
///         Emits descriptive events that prove a specific Workflow ID triggered
///         a security action, complete with context for block explorer readability.
/// @dev Mirrors the Chainlink CRE on-chain report pattern with enriched metadata.
contract WorkflowLogger {
    // ============ Structs ============

    struct ExecutionReport {
        bytes32 workflowId;
        uint8 action;
        address adapter;
        string protocolName;
        uint8 riskScore;
        uint8 threatLevel;
        string actionDescription;
        string resolutionCriteria;
        string dataSources;
    }

    // ============ Events ============

    /// @notice Compact event matching Chainlink CRE reference pattern
    event ReportReceived(uint8 indexed action, bytes32 workflowId);

    /// @notice Descriptive event for full auditability on block explorers
    event ShieldInterventionReport(
        bytes32 indexed workflowId,
        address indexed adapter,
        string protocolName,
        uint8 riskScore,
        uint8 threatLevel,
        string actionDescription,
        string resolutionCriteria,
        string dataSources
    );

    /// @notice Execution metadata event
    event WorkflowExecutionMeta(
        bytes32 indexed workflowId,
        address indexed executor,
        uint256 timestamp,
        uint256 executionIndex
    );

    // ============ State ============

    uint256 public totalExecutions;

    // ============ Functions ============

    /// @notice Log a full CRE workflow execution with descriptive metadata
    /// @param report Struct containing all execution details
    function logExecution(ExecutionReport calldata report) external {
        totalExecutions++;

        emit ReportReceived(report.action, report.workflowId);

        emit ShieldInterventionReport(
            report.workflowId,
            report.adapter,
            report.protocolName,
            report.riskScore,
            report.threatLevel,
            report.actionDescription,
            report.resolutionCriteria,
            report.dataSources
        );

        emit WorkflowExecutionMeta(
            report.workflowId,
            msg.sender,
            block.timestamp,
            totalExecutions
        );
    }
}
