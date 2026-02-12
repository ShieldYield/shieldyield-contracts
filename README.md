# ShieldYield Smart Contracts

> AI-Powered DeFi Guardian - Protecting Your Yield with Smart Tranching & Real-Time Risk Monitoring

## Overview

ShieldYield adalah DeFi vault yang melindungi dana user dari exploit dengan:
- **Smart Tranching**: Auto-diversifikasi ke berbagai risk tier (50% LOW, 30% MEDIUM, 20% HIGH)
- **AI Risk Monitoring**: CRE (Chainlink Runtime Environment) memantau protokol 24/7
- **Shield Protection**: Auto-withdraw sebelum exploit terjadi
- **CCIP Bridge**: Emergency cross-chain transfer ke chain yang lebih aman

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         USER DEPOSIT                             │
│                              │                                   │
│                              ▼                                   │
│                    ┌─────────────────┐                          │
│                    │   ShieldVault   │                          │
│                    │   (Main Vault)  │                          │
│                    └────────┬────────┘                          │
│                              │                                   │
│              ┌───────────────┼───────────────┐                  │
│              ▼               ▼               ▼                  │
│     ┌────────────┐   ┌────────────┐   ┌────────────┐           │
│     │ LOW (50%)  │   │MEDIUM(30%) │   │ HIGH (20%) │           │
│     │ Aave 25%   │   │  Morpho    │   │  YieldMax  │           │
│     │Compound 25%│   │            │   │            │           │
│     └────────────┘   └────────────┘   └────────────┘           │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                    CRE MONITORING                          │ │
│  │  On-Chain: EVM Read, Data Stream, Pool Health, Whale Move  │ │
│  │  Off-Chain: GitHub, Social, Audit, Governance, Team Wallet │ │
│  └──────────────────────────┬─────────────────────────────────┘ │
│                              │                                   │
│                              ▼                                   │
│                    ┌─────────────────┐                          │
│                    │  RiskRegistry   │                          │
│                    │ (Risk Scoring)  │                          │
│                    └────────┬────────┘                          │
│                              │                                   │
│              ┌───────────────┼───────────────┐                  │
│              ▼               ▼               ▼                  │
│           SAFE          WARNING         CRITICAL                │
│            │                │               │                   │
│            ▼                ▼               ▼                   │
│         No Action     Partial (20-50%)   Full (100%)           │
│                             │               │                   │
│                             └───────┬───────┘                   │
│                                     ▼                           │
│                            ┌─────────────────┐                  │
│                            │   Safe Haven    │                  │
│                            │ (Aave/Compound) │                  │
│                            └────────┬────────┘                  │
│                                     │                           │
│                                     ▼                           │
│                            ┌─────────────────┐                  │
│                            │  ShieldBridge   │                  │
│                            │  (CCIP Bridge)  │                  │
│                            └─────────────────┘                  │
└─────────────────────────────────────────────────────────────────┘
```

## Smart Contracts

### Core Contracts

| Contract | Description | Key Functions |
|----------|-------------|---------------|
| `ShieldVault.sol` | Main vault - handles deposits, withdrawals, tranching | `deposit()`, `withdraw()`, `rebalance()` |
| `RiskRegistry.sol` | Stores risk scores & threat levels | `updateRiskScore()`, `getThreatLevel()` |
| `BaseAdapter.sol` | Base class for protocol adapters | `deposit()`, `withdraw()`, `emergencyWithdraw()` |

### Bridge Contracts

| Contract | Description | Key Functions |
|----------|-------------|---------------|
| `ShieldBridge.sol` | CCIP emergency cross-chain bridge | `emergencyBridge()`, `getEmergencyBridgeFee()` |
| `IRouterClient.sol` | Chainlink CCIP Router interface | - |

### Mock Contracts (for Testing/Demo)

| Contract | Description |
|----------|-------------|
| `MockERC20.sol` | Mintable test USDC |
| `MockProtocolAdapter.sol` | Simulates lending protocols with real-time yield |
| `MockShieldBridge.sol` | Mock CCIP bridge for testing |
| `Faucet.sol` | Claim 10,000 test USDC for demo |

## Key Features

### 1. Smart Tranching

Deposits auto-distributed across risk tiers:

```solidity
// Distribution weights (basis points)
LOW (50%):    Aave (2500) + Compound (2500)
MEDIUM (30%): Morpho (3000)
HIGH (20%):   YieldMax (2000)
```

### 2. Threat Levels & Actions

| Threat Level | Risk Score | Action | Function |
|--------------|------------|--------|----------|
| SAFE | 0-25 | No action | - |
| WATCH | 26-50 | Monitor closely | - |
| WARNING | 51-75 | Partial withdraw (20-50%) | `partialWithdraw()` |
| CRITICAL | 76-100 | Full withdraw (100%) | `emergencyWithdraw()` |

### 3. Real-Time Yield

Mock adapters calculate yield per second based on APY:

```solidity
// Get yield info
adapter.getBalance();           // Total balance with accrued yield
adapter.getYieldPerSecond();    // Yield rate per second
adapter.getBalanceBreakdown();  // Principal + yield breakdown
adapter.simulateTimePassing(3600); // Fast-forward 1 hour for demo
```

### 4. Emergency Actions

```solidity
// WARNING level: Partial withdraw
vault.partialWithdraw(adapter, 5000, "TVL dropping"); // 50%

// CRITICAL level: Full withdraw
vault.emergencyWithdraw(adapter, "Exploit detected!"); // 100%

// Cross-chain escape
bridge.emergencyBridge{value: fee}(token, amount, destinationChain);
```

## Events (for Dashboard)

```solidity
// ShieldVault
event Deposited(address indexed user, uint256 amount, uint256 shares);
event Withdrawn(address indexed user, uint256 shares, uint256 amount);
event ShieldActivated(address indexed user, address indexed adapter, uint256 amount, string reason);
event EmergencyWithdrawExecuted(address adapter, uint256 withdrawn, ThreatLevel level, string reason);
event Rebalanced(address indexed caller, uint256 timestamp);

// RiskRegistry
event RiskScoreUpdated(address indexed protocol, uint256 oldScore, uint256 newScore, string reason);
event ShieldActionLogged(address indexed user, address indexed protocol, ThreatLevel threatLevel, uint256 amountSaved, string reason);

// ShieldBridge
event EmergencyBridgeInitiated(bytes32 messageId, uint64 destinationChain, address token, uint256 amount, address sender);
```

## Installation

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Install dependencies
forge install

# Build
forge build

# Test
forge test -vv
```

## Testing

```bash
# Run all tests
forge test

# Run with verbose output
forge test -vv

# Run specific test
forge test --match-test test_FullFlow_DepositMonitorShield -vvv
```

### Test Coverage

- 21 tests passing
- Full flow demo test showing Shield protection
- Bridge emergency scenario test

## Deployment

### Local (Anvil)

```bash
# Start local node
anvil

# Deploy
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast
```

### Testnet (Sepolia/Base Sepolia)

```bash
# Set environment
export PRIVATE_KEY=your_private_key
export RPC_URL=https://sepolia.infura.io/v3/YOUR_KEY

# Deploy
forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast --verify
```

## Contract Addresses (After Deployment)

| Contract | Address |
|----------|---------|
| MockUSDC | `TBD` |
| Faucet | `TBD` |
| RiskRegistry | `TBD` |
| ShieldVault | `TBD` |
| ShieldBridge | `TBD` |

## Usage Flow

### For Users

```solidity
// 1. Claim test USDC (testnet only)
faucet.claim(); // Get 10,000 USDC

// 2. Approve & Deposit
usdc.approve(shieldVault, amount);
shieldVault.deposit(amount);

// 3. Check balance (includes real-time yield)
shieldVault.getUserBalance(userAddress);

// 4. Withdraw
shieldVault.withdraw(shares);
```

### For CRE (Off-chain AI)

```solidity
// 1. Update risk score
riskRegistry.updateRiskScore(protocol, 85, "TVL dropped 50%, whale exit");

// 2. Trigger emergency action based on threat level
if (threatLevel == CRITICAL) {
    shieldVault.emergencyWithdraw(protocol, "Exploit imminent");
} else if (threatLevel == WARNING) {
    shieldVault.partialWithdraw(protocol, 5000, "High risk activity"); // 50%
}

// 3. Optional: Bridge to safe chain
shieldBridge.emergencyBridge{value: fee}(usdc, amount, BASE_SELECTOR);

// 4. Rebalance after threat resolved
shieldVault.rebalance();
```

## Security Considerations

- Only CRE address can trigger emergency actions
- Only owner can add/remove pools
- ReentrancyGuard on all state-changing functions
- SafeERC20 for token transfers
- Pausable functionality for emergencies

## License

MIT

## Links

- [Chainlink CRE Documentation](https://docs.chain.link/)
- [Chainlink CCIP Documentation](https://docs.chain.link/ccip)
- [Foundry Book](https://book.getfoundry.sh/)
