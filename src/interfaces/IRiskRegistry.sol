// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRiskRegistry {
    enum ThreatLevel {
        SAFE,      // 0-25: No action needed
        WATCH,     // 26-50: Monitor closely
        WARNING,   // 51-75: Partial withdrawal
        CRITICAL   // 76-100: Emergency full withdrawal
    }

    struct ProtocolRisk {
        uint8 riskScore;        // 0-100
        ThreatLevel threatLevel;
        uint256 lastUpdated;
        bool isActive;
    }

    struct ShieldAction {
        address protocol;g
        ThreatLevel threatLevel;
        uint256 amountSaved;
        string reason;
        uint256 timestamp;
    }

    event RiskScoreUpdated(
        address indexed protocol,
        uint8 oldScore,
        uint8 newScore,
        ThreatLevel threatLevel
    );

    event ShieldActionLogged(
        address indexed user,
        address indexed protocol,
        ThreatLevel threatLevel,
        uint256 amountSaved,
        string reason
    );

    function updateRiskScore(address protocol, uint8 score, string calldata reason) external;
    function getProtocolRisk(address protocol) external view returns (ProtocolRisk memory);
    function getThreatLevel(address protocol) external view returns (ThreatLevel);
    function isProtocolSafe(address protocol) external view returns (bool);
    function logShieldAction(
        address user,
        address protocol,
        ThreatLevel threatLevel,
        uint256 amountSaved,
        string calldata reason
    ) external;
    function getShieldHistory(address user) external view returns (ShieldAction[] memory);
}
