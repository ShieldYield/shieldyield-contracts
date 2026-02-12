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

# Deploy (all-in-one with mock bridge)
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast
```

### Testnet - Arbitrum Sepolia + Base Sepolia (with CCIP)

Both chains run identical full systems. CRE (AI) analyzes risk across chains and decides where to bridge funds for safety.

```bash
# 1. Set environment
cp .env.example .env
# Edit .env with your PRIVATE_KEY, ARBISCAN_API_KEY, BASESCAN_API_KEY

# 2. Deploy on Arbitrum Sepolia (full system + CCIP bridge)
forge script script/DeployArbitrum.s.sol --rpc-url arbitrum_sepolia --broadcast

# 3. Deploy on Base Sepolia (full system + CCIP bridge)
forge script script/DeployBase.s.sol --rpc-url base_sepolia --broadcast

# 4. Configure bidirectional CCIP bridge
# Arbitrum → Base
ARB_BRIDGE=<addr> BASE_BRIDGE=<addr> BASE_SAFE_HAVEN=<base_aave_addr> \
  forge script script/ConfigureBridge.s.sol --tc ConfigureBridgeArb --rpc-url arbitrum_sepolia --broadcast

# Base → Arbitrum
ARB_BRIDGE=<addr> BASE_BRIDGE=<addr> ARB_SAFE_HAVEN=<arb_aave_addr> \
  forge script script/ConfigureBridge.s.sol --tc ConfigureBridgeBase --rpc-url base_sepolia --broadcast
```

## Deployed Contract Addresses

> All contracts are verified on Arbiscan & Basescan.

### Arbitrum Sepolia (Chain ID: 421614)

| Contract | Address |
|----------|---------|
| MockUSDC | [`0x4d107C58DCda55ea6ea2B162d9C434F710E42038`](https://sepolia.arbiscan.io/address/0x4d107C58DCda55ea6ea2B162d9C434F710E42038) |
| Faucet | [`0x6E860FF2C4ea6b01815D74E54859Cdd9DD172256`](https://sepolia.arbiscan.io/address/0x6E860FF2C4ea6b01815D74E54859Cdd9DD172256) |
| RiskRegistry | [`0xa23BE1297F836FF7D4E3297320ff16dbc7903e6D`](https://sepolia.arbiscan.io/address/0xa23BE1297F836FF7D4E3297320ff16dbc7903e6D) |
| ShieldVault | [`0xcFBd47c63D284A8F824e586596Df4d5c57326c8B`](https://sepolia.arbiscan.io/address/0xcFBd47c63D284A8F824e586596Df4d5c57326c8B) |
| ShieldBridge (CCIP) | [`0xA5D0CF3DC85538FfC93EF8941819e2b1b0460387`](https://sepolia.arbiscan.io/address/0xA5D0CF3DC85538FfC93EF8941819e2b1b0460387) |
| AaveAdapter (LOW 25%) | [`0xB81961aA49d7E834404e299e688B3Dc09a5EFe5a`](https://sepolia.arbiscan.io/address/0xB81961aA49d7E834404e299e688B3Dc09a5EFe5a) |
| CompoundAdapter (LOW 25%) | [`0xcc547a2B0f18b34095623809977D54cfe306BEBF`](https://sepolia.arbiscan.io/address/0xcc547a2B0f18b34095623809977D54cfe306BEBF) |
| MorphoAdapter (MEDIUM 30%) | [`0x5f8A64Bc67f23b8d5d02c7CFE187AD42D59f1D59`](https://sepolia.arbiscan.io/address/0x5f8A64Bc67f23b8d5d02c7CFE187AD42D59f1D59) |
| YieldMaxAdapter (HIGH 20%) | [`0x5EbD6F3DA76C2B9C9d6aAC89DA08c388EaB2B3cb`](https://sepolia.arbiscan.io/address/0x5EbD6F3DA76C2B9C9d6aAC89DA08c388EaB2B3cb) |

### Base Sepolia (Chain ID: 84532)

| Contract | Address |
|----------|---------|
| MockUSDC | [`0x62428d5107E8846E1a9814941BD123c8B34c5716`](https://sepolia.basescan.org/address/0x62428d5107E8846E1a9814941BD123c8B34c5716) |
| Faucet | [`0xCc641dEBd179F2Af554dbd8fa9f9B4397967acf7`](https://sepolia.basescan.org/address/0xCc641dEBd179F2Af554dbd8fa9f9B4397967acf7) |
| RiskRegistry | [`0x986d494B19f8Eb3fa19f201Dcd1ee6f67003D57F`](https://sepolia.basescan.org/address/0x986d494B19f8Eb3fa19f201Dcd1ee6f67003D57F) |
| ShieldVault | [`0xb4a54D664c7f4c725e81bcBA4aC8ad665e6665B8`](https://sepolia.basescan.org/address/0xb4a54D664c7f4c725e81bcBA4aC8ad665e6665B8) |
| ShieldBridge (CCIP) | [`0x32583f9C0A0d9Fa6517cf4005826148d81C85056`](https://sepolia.basescan.org/address/0x32583f9C0A0d9Fa6517cf4005826148d81C85056) |
| AaveAdapter (LOW 25%) | [`0xbdAea5744AC79132c96420Ce13De3d18C38FEeca`](https://sepolia.basescan.org/address/0xbdAea5744AC79132c96420Ce13De3d18C38FEeca) |
| CompoundAdapter (LOW 25%) | [`0xcAf7B73f3fE685A3d87A1d150C1503334EdA79De`](https://sepolia.basescan.org/address/0xcAf7B73f3fE685A3d87A1d150C1503334EdA79De) |
| MorphoAdapter (MEDIUM 30%) | [`0xefD2e27C073e72aAEdd1276Ab4B2C1014d704CAe`](https://sepolia.basescan.org/address/0xefD2e27C073e72aAEdd1276Ab4B2C1014d704CAe) |
| YieldMaxAdapter (HIGH 20%) | [`0x315dc90494e041ea5Ab425E12A76B299aE2A584d`](https://sepolia.basescan.org/address/0x315dc90494e041ea5Ab425E12A76B299aE2A584d) |

### CCIP Configuration (Bidirectional)

| Route | CCIP Router | Chain Selector |
|-------|-------------|----------------|
| Arbitrum Sepolia | `0x2a9C5afB0d0e4BAb2BCdaE109EC4b0c4Be15a165` | `3478487238524512106` |
| Base Sepolia | `0xD3b06cEbF099CE7DA4AcCf578aaebFDBd6e88a93` | `10344971235874465080` |

**Bidirectional Emergency Bridge Flow**:
- Arbitrum risky → (CCIP) → Base Aave Safe Haven
- Base risky → (CCIP) → Arbitrum Aave Safe Haven
- CRE (AI) analyzes TVL, risk scores, and protocol health to decide optimal chain

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
