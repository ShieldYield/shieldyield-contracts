// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IRiskRegistry} from "./interfaces/IRiskRegistry.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title RiskRegistry
/// @notice Stores risk scores, threat levels, and shield action history
/// @dev Only CRE (Chainlink Runtime Environment) can update risk scores
contract RiskRegistry is IRiskRegistry, Ownable {
    // Protocol address => Risk data
    mapping(address => ProtocolRisk) private _protocolRisks;

    // User address => Shield action history
    mapping(address => ShieldAction[]) private _shieldHistory;

    // Addresses authorized to update risk scores (CRE nodes)
    mapping(address => bool) public isAuthorizedUpdater;

    // ShieldVault contract address
    address public shieldVault;

    // Risk score thresholds for threat levels
    uint8 public constant SAFE_THRESHOLD = 25;
    uint8 public constant WATCH_THRESHOLD = 50;
    uint8 public constant WARNING_THRESHOLD = 75;

    modifier onlyAuthorized() {
        require(
            isAuthorizedUpdater[msg.sender] || msg.sender == owner(),
            "RiskRegistry: not authorized"
        );
        _;
    }

    modifier onlyShieldVault() {
        require(msg.sender == shieldVault, "RiskRegistry: only ShieldVault");
        _;
    }

    constructor() Ownable(msg.sender) {}

    /// @notice Set the ShieldVault contract address
    /// @param _shieldVault Address of the ShieldVault contract
    function setShieldVault(address _shieldVault) external onlyOwner {
        require(_shieldVault != address(0), "RiskRegistry: zero address");
        shieldVault = _shieldVault;
    }

    /// @notice Add or remove an authorized updater (CRE node)
    /// @param updater Address of the updater
    /// @param authorized Whether to authorize or deauthorize
    function setAuthorizedUpdater(address updater, bool authorized) external onlyOwner {
        require(updater != address(0), "RiskRegistry: zero address");
        isAuthorizedUpdater[updater] = authorized;
    }

    /// @notice Update the risk score for a protocol
    /// @param protocol Address of the protocol (or adapter)
    /// @param score Risk score (0-100)
    /// @param reason Reason for the score update
    function updateRiskScore(
        address protocol,
        uint8 score,
        string calldata reason
    ) external onlyAuthorized {
        require(protocol != address(0), "RiskRegistry: zero address");
        require(score <= 100, "RiskRegistry: score exceeds 100");

        ProtocolRisk storage risk = _protocolRisks[protocol];
        uint8 oldScore = risk.riskScore;

        risk.riskScore = score;
        risk.threatLevel = _calculateThreatLevel(score);
        risk.lastUpdated = block.timestamp;
        risk.isActive = true;

        emit RiskScoreUpdated(protocol, oldScore, score, risk.threatLevel);
    }

    /// @notice Get the risk data for a protocol
    /// @param protocol Address of the protocol
    /// @return Risk data struct
    function getProtocolRisk(address protocol) external view returns (ProtocolRisk memory) {
        return _protocolRisks[protocol];
    }

    /// @notice Get the current threat level for a protocol
    /// @param protocol Address of the protocol
    /// @return Current threat level
    function getThreatLevel(address protocol) external view returns (ThreatLevel) {
        return _protocolRisks[protocol].threatLevel;
    }

    /// @notice Check if a protocol is considered safe (SAFE or WATCH level)
    /// @param protocol Address of the protocol
    /// @return True if the protocol is safe for deposits
    function isProtocolSafe(address protocol) external view returns (bool) {
        ThreatLevel level = _protocolRisks[protocol].threatLevel;
        return level == ThreatLevel.SAFE || level == ThreatLevel.WATCH;
    }

    /// @notice Log a shield action (called by ShieldVault)
    /// @param user Address of the user whose funds were protected
    /// @param protocol Address of the protocol
    /// @param threatLevel Threat level that triggered the action
    /// @param amountSaved Amount of funds saved
    /// @param reason Reason for the action
    function logShieldAction(
        address user,
        address protocol,
        ThreatLevel threatLevel,
        uint256 amountSaved,
        string calldata reason
    ) external onlyShieldVault {
        ShieldAction memory action = ShieldAction({
            protocol: protocol,
            threatLevel: threatLevel,
            amountSaved: amountSaved,
            reason: reason,
            timestamp: block.timestamp
        });

        _shieldHistory[user].push(action);

        emit ShieldActionLogged(user, protocol, threatLevel, amountSaved, reason);
    }

    /// @notice Get the shield action history for a user
    /// @param user Address of the user
    /// @return Array of shield actions
    function getShieldHistory(address user) external view returns (ShieldAction[] memory) {
        return _shieldHistory[user];
    }

    /// @notice Get the total amount saved for a user across all shield actions
    /// @param user Address of the user
    /// @return Total amount saved
    function getTotalAmountSaved(address user) external view returns (uint256) {
        ShieldAction[] storage history = _shieldHistory[user];
        uint256 total = 0;
        for (uint256 i = 0; i < history.length; i++) {
            total += history[i].amountSaved;
        }
        return total;
    }

    /// @notice Batch update risk scores for multiple protocols
    /// @param protocols Array of protocol addresses
    /// @param scores Array of risk scores
    /// @param reasons Array of reasons
    function batchUpdateRiskScores(
        address[] calldata protocols,
        uint8[] calldata scores,
        string[] calldata reasons
    ) external onlyAuthorized {
        require(
            protocols.length == scores.length && scores.length == reasons.length,
            "RiskRegistry: array length mismatch"
        );

        for (uint256 i = 0; i < protocols.length; i++) {
            require(protocols[i] != address(0), "RiskRegistry: zero address");
            require(scores[i] <= 100, "RiskRegistry: score exceeds 100");

            ProtocolRisk storage risk = _protocolRisks[protocols[i]];
            uint8 oldScore = risk.riskScore;

            risk.riskScore = scores[i];
            risk.threatLevel = _calculateThreatLevel(scores[i]);
            risk.lastUpdated = block.timestamp;
            risk.isActive = true;

            emit RiskScoreUpdated(protocols[i], oldScore, scores[i], risk.threatLevel);
        }
    }

    /// @notice Calculate threat level from risk score
    /// @param score Risk score (0-100)
    /// @return Threat level enum
    function _calculateThreatLevel(uint8 score) internal pure returns (ThreatLevel) {
        if (score <= SAFE_THRESHOLD) {
            return ThreatLevel.SAFE;
        } else if (score <= WATCH_THRESHOLD) {
            return ThreatLevel.WATCH;
        } else if (score <= WARNING_THRESHOLD) {
            return ThreatLevel.WARNING;
        } else {
            return ThreatLevel.CRITICAL;
        }
    }
}
