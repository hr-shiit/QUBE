# BTC Lending Platform Architecture

## Overview

The BTC Lending Platform is a decentralized lending protocol built on Aptos Move that enables over-collateralized lending using synthetic BTC tokens.

## Core Components

### 1. Token Contracts

#### ctrlBTC Token (`sources/ctrl_btc_token.move`)
- **Purpose**: Represents BTC deposited as collateral
- **Type**: Fungible Asset (FA) compliant token
- **Decimals**: 8 (matching BTC)
- **Minting Authority**: CollateralVault contract only
- **Key Features**:
  - 1:1 backing with deposited BTC
  - Transferable between users
  - Burnable only by CollateralVault

#### lnBTC Token (`sources/ln_btc_token.move`)
- **Purpose**: Represents loan BTC issued to borrowers
- **Type**: Fungible Asset (FA) compliant token
- **Decimals**: 8 (matching BTC)
- **Minting Authority**: LoanManager contract only
- **Key Features**:
  - Minted when loans are created
  - Burned when loans are repaid
  - Freely transferable

### 2. Core Contracts

#### CollateralVault (`sources/collateral_vault.move`)
- **Purpose**: Secure storage and management of collateral
- **Responsibilities**:
  - Accept BTC deposits and mint ctrlBTC
  - Lock/unlock collateral for loans
  - Release collateral after loan repayment
  - Manage user collateral balances

#### LoanManager (`sources/loan_manager.move`)
- **Purpose**: Core business logic for loan lifecycle
- **Responsibilities**:
  - Create loans with LTV validation
  - Calculate interest and repayment amounts
  - Coordinate with other contracts
  - Manage loan state transitions
  - Handle loan repayments and closures

#### InterestRateModel (`sources/interest_rate_model.move`)
- **Purpose**: Interest rate calculation and management
- **Responsibilities**:
  - Store LTV → interest rate mappings
  - Provide rate queries for loan creation
  - Allow admin updates to rate structure

## Data Flow

### Loan Creation Flow
1. User deposits BTC → CollateralVault mints ctrlBTC
2. User requests loan → LoanManager validates LTV
3. LoanManager queries InterestRateModel for rate
4. LoanManager locks collateral in CollateralVault
5. LoanManager mints lnBTC to borrower

### Loan Repayment Flow
1. User repays with lnBTC → LoanManager burns tokens
2. LoanManager calculates interest owed
3. LoanManager unlocks collateral in CollateralVault
4. User can withdraw original BTC collateral

## Security Model

### Access Controls
- **ctrlBTC**: Only CollateralVault can mint/burn
- **lnBTC**: Only LoanManager can mint/burn
- **CollateralVault**: Only LoanManager can lock/unlock collateral
- **InterestRateModel**: Only admin can update rates

### Over-Collateralization
- Maximum LTV: 60%
- Ensures system remains solvent
- Provides buffer against price volatility

### Atomic Operations
- All state changes within transactions are atomic
- Prevents partial state updates
- Ensures system consistency

## Interest Rate Structure

| LTV Ratio | Interest Rate |
|-----------|---------------|
| 30%       | 5%           |
| 45%       | 8%           |
| 60%       | 10%          |

## Error Handling

### Error Categories
- **Authorization**: Unauthorized access attempts
- **Validation**: Invalid parameters or amounts
- **State**: Invalid state transitions
- **Resources**: Insufficient balances or collateral

### Error Codes
- `E_NOT_AUTHORIZED`: Permission denied
- `E_INVALID_AMOUNT`: Invalid amount (zero or negative)
- `E_INSUFFICIENT_COLLATERAL`: Not enough collateral
- `E_INVALID_LTV`: LTV exceeds maximum
- `E_LOAN_NOT_FOUND`: Loan doesn't exist
- `E_LOAN_NOT_ACTIVE`: Loan is not in active state

## Testing Strategy

### Unit Tests
- Individual contract function testing
- Access control verification
- Error condition testing
- Edge case validation

### Integration Tests
- End-to-end loan workflows
- Cross-contract interactions
- Concurrent operation testing
- State consistency verification

## Deployment

### Prerequisites
- Aptos CLI installed
- Move development environment
- Testnet account with APT tokens

### Deployment Order
1. InterestRateModel (independent)
2. CollateralVault (independent)
3. LoanManager (depends on CollateralVault)
4. ctrlBTC Token (depends on CollateralVault)
5. lnBTC Token (depends on LoanManager)

### Configuration
- Set proper contract addresses
- Initialize default interest rates
- Configure admin permissions
- Verify cross-contract references