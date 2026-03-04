// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {WorkflowLogger} from "../src/WorkflowLogger.sol";

/// @title DeployWorkflowLogger
/// @notice Deploys the WorkflowLogger contract to Arbitrum Sepolia
contract DeployWorkflowLogger is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("========== DEPLOYING WORKFLOW LOGGER ==========");
        console.log("Deployer:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        WorkflowLogger logger = new WorkflowLogger();
        console.log("WorkflowLogger deployed:", address(logger));

        vm.stopBroadcast();

        console.log("");
        console.log("========== DEPLOYMENT COMPLETE ==========");
        console.log("WorkflowLogger:", address(logger));
        console.log("");
        console.log(">> Update config.staging.json with this address!");
    }
}
