# LoanManager Contract Design

## Overview

The LoanManager contract serves as the central orchestrator of the BTC lending platform, implementing the core business logic for loan lifecycle management. It coordinates between the CollateralVault for collateral operations, InterestRateModel for rate determination, and both token contracts (ctrlBTC and lnBTC) for loan token management. The contract ensures secure, over-collateralized lending with comprehensive risk management and transparent operations.

## Architecture

### Core Responsibilities
1. **Loan Creation**: Validate loan requests, determine interest rates, and coordinate collateral locking
2. **Loan Management**: Track loan states, calculate interest, and manage loan lifecycle
3. **Repayment Processing**: Handle full and partial repayments with interest calculations
4. **Risk Management**: Enforce LTV limits and maintain system solvency
5. **Integration Coordination**: Orchestrate operations across CollateralVault and token contracts

### Integration Points
- **CollateralVault**: Lock/unlock collateral for loan operations
- **InterestRateModel**: Query interest rates based on LTV ratios
- **lnBTC Token**: Mint tokens on loan creation, burn on repayment
- **External Users**: Direct interaction for loan creation and repayment

## Components and Interfaces

### Data Structures

#### LoanManager Resource
```move
struct LoanManager has key {
    /// Mapping from loan ID to loan details
    loans: Table<u64, Loan>,
    /// Next available loan ID
    next_loan_id: u64,
    /// Mapping from borrower address to their loan IDs
    borrower_loans: Table<address, vector<u64>>,
    /// Total number of active loans
    total_active_loans: u64,
    /// Total outstanding debt across all loans
    total_outstanding_debt: u64,
    /// Address of the CollateralVault contract
    collateral_vault_address: address,
    /// Address of the InterestRateModel contract
    interest_rate_model_address: address,
    /// Admin address for contract management
    admin_address: address,
    /// Emergency pause flag
    is_paused: bool,
}
```

#### Loan Structure
```move
struct Loan has store {
    /// Unique loan identifier
    loan_id: u64,
    /// Address of the borrower
    borrower: address,
    /// Amount of collateral locked (in satoshis)
    collateral_amount: u64,
    /// Original loan amount (in satoshis)
    loan_amount: u64,
    /// Current outstanding balance (principal only)
    outstanding_balance: u64,
    /// Interest rate in basis points (e.g., 500 = 5%)
    interest_rate: u64,
    /// Timestamp when loan was created
    creation_timestamp: u64,
    /// Current loan state
    state: u8, // 0 = Active, 1 = Repaid, 2 = Defaulted
}
```

#### Event Structures
```move
struct LoanCreatedEvent has drop, store {
    loan_id: u64,
    borrower: address,
    collateral_amount: u64,
    loan_amount: u64,
    interest_rate: u64,
    ltv_ratio: u64,
}

struct LoanRepaidEvent has drop, store {
    loan_id: u64,
    borrower: address,
    repayment_amount: u64,
    interest_paid: u64,
    remaining_balance: u64,
    is_full_repayment: bool,
}

struct CollateralUnlockedEvent has drop, store {
    loan_id: u64,
    borrower: address,
    unlocked_amount: u64,
    remaining_locked: u64,
}
```

### Public Interface Functions

#### Loan Operations
```move
/// Create a new loan against deposited collateral
public fun create_loan(
    borrower: &signer,
    collateral_amount: u64,
    loan_amount: u64
): u64

/// Repay a loan (full or partial)
public fun repay_loan(
    borrower: &signer,
    loan_id: u64,
    repayment_amount: u64
): (u64, u64) // Returns (interest_paid, remaining_balance)

/// Calculate current outstanding balance including interest
public fun calculate_outstanding_balance(loan_id: u64): u64

/// Calculate current interest owed on a loan
public fun calculate_interest_owed(loan_id: u64): u64
```

#### Query Functions
```move
/// Get complete loan details
public fun get_loan_details(loan_id: u64): (u64, address, u64, u64, u64, u64, u64, u8)

/// Get all active loan IDs for a borrower
public fun get_borrower_loans(borrower: address): vector<u64>

/// Get current LTV ratio for a loan
public fun get_loan_ltv_ratio(loan_id: u64): u64

/// Get system-wide statistics
public fun get_system_stats(): (u64, u64, u64) // (total_loans, active_loans, total_debt)
```

#### Administrative Functions
```move
/// Update CollateralVault contract address (admin only)
public fun update_collateral_vault(admin: &signer, new_address: address)

/// Update InterestRateModel contract address (admin only)
public fun update_interest_rate_model(admin: &signer, new_address: address)

/// Transfer admin privileges (admin only)
public fun update_admin(admin: &signer, new_admin: address)

/// Emergency pause/unpause operations (admin only)
public fun set_pause_state(admin: &signer, paused: bool)
```

## Data Models

### Loan State Machine
```
Active (0) → Repaid (1)    [via full repayment]
Active (0) → Active (0)    [via partial repayment]
Active (0) → Defaulted (2) [via admin action - future enhancement]
```

### Interest Calculation Model
- **Simple Interest**: Interest = Principal × Rate × Time
- **Time Basis**: Calculated in seconds since loan creation
- **Rate Basis**: Interest rates stored in basis points (100 = 1%)
- **Precision**: All calculations maintain 8 decimal precision for BTC amounts

### LTV Calculation Model
```
LTV = (Outstanding Balance / Collateral Amount) × 100
```

### Risk Management Model
- **Maximum LTV**: 60% at loan creation
- **Over-collateralization**: Required to maintain system solvency
- **Dynamic Collateral**: Excess collateral unlocked on partial repayments

## Error Handling

### Error Codes and Scenarios
```move
const E_NOT_AUTHORIZED: u64 = 1;           // Unauthorized access
const E_INVALID_AMOUNT: u64 = 2;           // Zero or negative amounts
const E_INSUFFICIENT_COLLATERAL: u64 = 3;  // Not enough collateral
const E_LOAN_NOT_FOUND: u64 = 4;          // Invalid loan ID
const E_LOAN_NOT_ACTIVE: u64 = 5;         // Loan not in active state
const E_INVALID_LTV: u64 = 6;             // LTV exceeds maximum
const E_ALREADY_INITIALIZED: u64 = 7;     // Contract already initialized
const E_SYSTEM_PAUSED: u64 = 8;           // Operations paused
const E_INSUFFICIENT_REPAYMENT: u64 = 9;  // Repayment amount too low
const E_INTEGRATION_FAILED: u64 = 10;     // External contract call failed
```

### Validation Logic
1. **Amount Validation**: All amounts must be positive and within reasonable limits
2. **LTV Validation**: Loan-to-value ratio must not exceed 60%
3. **State Validation**: Operations only allowed on loans in appropriate states
4. **Authorization Validation**: Verify caller permissions for restricted functions
5. **Integration Validation**: Ensure external contract calls succeed

## Testing Strategy

### Unit Test Categories

#### Loan Creation Testing
- Valid loan creation with proper LTV ratios
- LTV validation and rejection of over-leveraged loans
- Collateral locking integration with CollateralVault
- lnBTC token minting integration
- Interest rate determination from InterestRateModel

#### Repayment Processing Testing
- Full loan repayment with interest calculation
- Partial repayment with balance updates
- Collateral unlocking on repayment
- lnBTC token burning integration
- Interest calculation accuracy over time

#### Access Control Testing
- Unauthorized loan operations fail appropriately
- Admin function access control
- Borrower-specific loan access validation
- Emergency pause functionality

#### Integration Testing
- End-to-end loan creation and repayment workflows
- Cross-contract coordination and error handling
- Atomic transaction behavior across integrations
- State consistency across all operations

#### Edge Case Testing
- Minimum and maximum loan amounts
- Boundary LTV ratios (exactly 60%)
- Zero interest scenarios
- Rapid sequential operations
- Concurrent operations by multiple users

### Test Scenarios

#### Happy Path Scenarios
1. **Complete Loan Lifecycle**: Create loan, partial repayment, full repayment
2. **Multiple Loans**: User creates multiple loans with different terms
3. **Interest Accrual**: Loans with various time periods and interest calculations
4. **Collateral Management**: Dynamic collateral locking and unlocking

#### Error Scenarios
1. **Over-leveraged Loans**: Attempts to create loans exceeding 60% LTV
2. **Insufficient Collateral**: Loan requests with inadequate collateral
3. **Invalid Repayments**: Repayment attempts on non-existent or repaid loans
4. **Integration Failures**: External contract failures during operations

#### Stress Testing
1. **High Volume**: Many loans created and managed simultaneously
2. **Large Amounts**: Loans with maximum possible amounts
3. **Time-based**: Long-running loans with significant interest accrual
4. **Concurrent Operations**: Multiple users operating simultaneously

## Security Considerations

### Access Control Matrix
| Function | Borrower | Admin | External |
|----------|----------|-------|----------|
| create_loan | ✓ (own) | ✓ | ✗ |
| repay_loan | ✓ (own) | ✓ | ✗ |
| get_loan_details | ✓ (any) | ✓ | ✓ |
| update_contracts | ✗ | ✓ | ✗ |
| set_pause_state | ✗ | ✓ | ✗ |

### Security Measures
1. **Strict Authorization**: Each function validates caller permissions
2. **State Validation**: Prevent invalid state transitions
3. **Atomic Operations**: All state changes within transactions are atomic
4. **Integration Safety**: Handle external contract failures gracefully
5. **Emergency Controls**: Admin can pause operations in emergencies

### Attack Vector Mitigation
1. **Reentrancy**: Move's ownership model prevents reentrancy attacks
2. **Integer Overflow**: Use safe arithmetic operations with proper bounds checking
3. **Unauthorized Access**: Comprehensive permission checks on all functions
4. **State Corruption**: Maintain invariants through validation
5. **Economic Attacks**: Over-collateralization prevents system insolvency

## Performance Considerations

### Gas Optimization
1. **Efficient Storage**: Use tables for loan and borrower mappings
2. **Minimal Computation**: Cache frequently used values
3. **Batch Operations**: Group related operations when possible
4. **Event Optimization**: Structured events for efficient filtering

### Scalability
1. **Loan Isolation**: Individual loan operations scale independently
2. **Borrower Isolation**: Per-borrower loan tracking scales with users
3. **Query Efficiency**: Direct table lookups for loan data
4. **State Management**: Efficient state updates and tracking

## Integration Specifications

### CollateralVault Integration
```move
// Lock collateral for loan creation
collateral_vault::lock_collateral(loan_manager_signer, borrower_address, amount)

// Unlock collateral on repayment
collateral_vault::unlock_collateral(loan_manager_signer, borrower_address, amount)
```

### InterestRateModel Integration
```move
// Query interest rate for LTV ratio
let rate = interest_rate_model::get_rate(ltv_ratio)
```

### lnBTC Token Integration
```move
// Mint tokens on loan creation
ln_btc_token::mint(loan_manager_address, borrower_address, loan_amount)

// Burn tokens on repayment
ln_btc_token::burn_from_user(borrower_address, repayment_amount)
```

### Event Integration
External systems can monitor loan events for:
- Loan creation and repayment tracking
- Interest calculation and payment monitoring
- Risk management and LTV monitoring
- System health and performance metrics

## Deployment and Configuration

### Initialization Parameters
- Admin address for contract management
- CollateralVault contract address
- InterestRateModel contract address
- Initial pause state (typically false)

### Post-Deployment Setup
1. Initialize lnBTC token with LoanManager address
2. Configure CollateralVault with LoanManager address
3. Verify cross-contract integration
4. Set up monitoring for events and system health

### Upgrade Considerations
- Contract addresses can be updated for upgrades
- Admin address can be transferred for governance
- Emergency pause provides safety during upgrades
- Existing loan data preserved across configuration changes
- Event history maintained for audit trails