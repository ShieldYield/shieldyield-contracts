# 📜 ShieldYield Contracts

The core smart contract system for the ShieldYield vault. Built with **Foundry**.

## 🏗️ Architecture

- **`ShieldVault.sol`**: The main interface for users. Handles deposits, withdrawals, and proportional distribution to protocol adapters.
- **`RiskRegistry.sol`**: Stores risk scores and threat levels for different protocols. Updated by the AI Risk Engine (CRE).
- **`ShieldBridge.sol`**: Integrates with **Chainlink CCIP** to evacuate funds to a "Safe Haven" on a destination chain (e.g., Base).
- **`WorkflowLogger.sol`**: Emits detailed events for off-chain monitoring and indexing.

## 🛠️ Development

### Prerequisites
- [Foundry](https://book.getfoundry.sh/getting-started/installation)

### Build
```bash
forge build
```

### Test
```bash
forge test
forge test -vv # Verbose
```

### Deploy (Local)
1. Start a local node:
   ```bash
   anvil
   ```
2. Deploy the contracts:
   ```bash
   forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast
   ```

## 🛡️ Security

- **Access Control**: Critical functions (emergency withdrawals, bridging) are restricted to the `onlyCRE` modifier or the contract owner.
- **SafeERC20**: Used for all token interactions to prevent silent failures.
- **ReentrancyGuard**: Applied to all user-facing state-changing functions.

---
🛡️ *Shielding your yield, one block at a time.*
