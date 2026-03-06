// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {RiskRegistry} from "../src/RiskRegistry.sol";

/// @title ApplyWorkflowScores
/// @notice Applies CRE workflow-computed risk scores to RiskRegistry.
///         Run this after `bunx cre workflow simulate --broadcast` to sync
///         the computed scores on-chain (bridging CRE simulation output → SC).
///
/// Usage:
///   forge script script/ApplyWorkflowScores.s.sol \
///     --sig "run(uint8,uint8,uint8,uint8)" <aave> <compound> <morpho> <yieldmax> \
///     --rpc-url arbitrum_sepolia --broadcast
///
/// Example (scores from last workflow run):
///   forge script script/ApplyWorkflowScores.s.sol \
///     --sig "run(uint8,uint8,uint8,uint8)" 0 10 0 0 \
///     --rpc-url https://sepolia-rollup.arbitrum.io/rpc --broadcast
contract ApplyWorkflowScores is Script {
    address constant RISK_REGISTRY    = 0xDd00b97Cd8Df07BbC95D9eAfb680A86358943C06;
    address constant AAVE_ADAPTER     = 0x2AB8a676Ca67bAB1C9e78f70C48b5b04eb288D8a;
    address constant COMPOUND_ADAPTER = 0x7816D0b6399CfA2e81AE3c07721EE43cb3b3c6c8;
    address constant MORPHO_ADAPTER   = 0x9D64139FEd95CFAd4d606aA8f145351068Cf36ac;
    address constant YIELDMAX_ADAPTER = 0xf6b7306abe85B6B7236C4e5e79443773Ef13B4f3;

    function run(uint8 aave, uint8 compound, uint8 morpho, uint8 yieldmax) external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        address[] memory protocols = new address[](4);
        uint8[] memory scores = new uint8[](4);
        string[] memory reasons = new string[](4);

        protocols[0] = AAVE_ADAPTER;     scores[0] = aave;
        protocols[1] = COMPOUND_ADAPTER; scores[1] = compound;
        protocols[2] = MORPHO_ADAPTER;   scores[2] = morpho;
        protocols[3] = YIELDMAX_ADAPTER; scores[3] = yieldmax;

        reasons[0] = string(abi.encodePacked("CRE Workflow: score=", _uint2str(aave)));
        reasons[1] = string(abi.encodePacked("CRE Workflow: score=", _uint2str(compound)));
        reasons[2] = string(abi.encodePacked("CRE Workflow: score=", _uint2str(morpho)));
        reasons[3] = string(abi.encodePacked("CRE Workflow: score=", _uint2str(yieldmax)));

        RiskRegistry(RISK_REGISTRY).batchUpdateRiskScores(protocols, scores, reasons);

        vm.stopBroadcast();

        console.log("Scores applied:");
        console.log("  AaveAdapter:     ", aave);
        console.log("  CompoundAdapter: ", compound);
        console.log("  MorphoAdapter:   ", morpho);
        console.log("  YieldMaxAdapter: ", yieldmax);
    }

    function _uint2str(uint8 v) internal pure returns (string memory) {
        if (v == 0) return "0";
        uint8 temp = v; uint8 digits;
        while (temp != 0) { digits++; temp /= 10; }
        bytes memory buf = new bytes(digits);
        while (v != 0) { digits--; buf[digits] = bytes1(48 + (v % 10)); v /= 10; }
        return string(buf);
    }
}
