# CollateralVault Contract Design

## Overview

The CollateralVault contract serves as the secure storage and management system for user collateral in the BTC lending platform. It acts as the central hub for collateral operations, coordinating between user deposits/withdrawals and the loan management system. The contract maintains strict access controls while providing transparent balance tracking and event emission.

## Architecture

### Core Responsibilities
1. **Collateral Storage**: Securely store user BTC collateral with precise balance tracking
2. **Token Integration**: Mint/burn ctrlBTC tokens to represent collateral deposits
3. **Loan Coordination**: Lock/unlock collateral for active loans via LoanManager
4. **Access Control**: Enforce strict permissions for sensitive operations
5. **Balance Management**: Track total, locked, and available collateral per user

### Integration Points
- **ctrlBTC Token**: Mints tokens on deposit, burns on withdrawal
- **LoanManager**: Receives lock/unlock requests for loan collateral
- **External Users**: Direct interaction for deposit/withdrawal operations

## Components and Interfaces

### Data Structures

#### CollateralVault Resource
```move
struct CollateralVault has key {
    /// Total collateral deposited by each user
    user_collateral: Table<address, u64>,
    /// Locked collateral per user (for active loans)
    locked_collateral: Table<address, u64>,
    /// Total collateral in the vault across all users
    total_vault_collateral: u64,
    /// Address of the LoanManager contract (authorized for lock/unlock)
    loan_manager_address: address,
    /// Admin address for vault management
    admin_address: address,
    /// Emergency pause flag
    is_paused: bool,
}
```

#### Event Structures
```move
struct DepositEvent has drop, store {
    user: address,
    amount: u64,
    new_total_balance: u64,
    timestamp: u64,
}

struct WithdrawalEvent has drop, store {
    user: address,
    amount: u64,
    new_total_balance: u64,
    timestamp: u64,
}

struct CollateralLockedEvent has drop, store {
    user: address,
    amount: u64,
    locked_by: address,
    new_locked_balance: u64,
}

struct CollateralUnlockedEvent has drop, store {
    user: address,
    amount: u64,
    unlocked_by: address,
    new_locked_balance: u64,
}
```

### Public Interface Functions

#### User Operations
```move
/// Deposit BTC collateral and receive ctrlBTC tokens
public fun deposit_collateral(user: &signer, amount: u64)

/// Withdraw BTC collateral by burning ctrlBTC tokens
public fun withdraw_collateral(user: &signer, amount: u64)
```

#### LoanManager Operations
```move
/// Lock collateral for a loan (LoanManager only)
public fun lock_collateral(loan_manager: &signer, user_address: address, amount: u64)

/// Unlock collateral after loan repayment (LoanManager only)
public fun unlock_collateral(loan_manager: &signer, user_address: address, amount: u64)
```

#### Query Functions
```move
/// Get total collateral balance for a user
public fun get_user_total_collateral(user_address: address): u64

/// Get locked collateral balance for a user
public fun get_user_locked_collateral(user_address: address): u64

/// Get available (unlocked) collateral balance for a user
public fun get_user_available_collateral(user_address: address): u64

/// Get total vault collateral across all users
public fun get_total_vault_collateral(): u64
```

#### Administrative Functions
```move
/// Update the LoanManager contract address (admin only)
public fun update_loan_manager(admin: &signer, new_loan_manager: address)

/// Transfer admin privileges (admin only)
public fun update_admin(admin: &signer, new_admin: address)

/// Emergency pause/unpause vault operations (admin only)
public fun set_pause_state(admin: &signer, paused: bool)
```

## Data Models

### Balance Tracking Model
The vault maintains three types of balances per user:
- **Total Collateral**: All BTC deposited by the user
- **Locked Collateral**: BTC currently securing active loans
- **Available Collateral**: BTC that can be withdrawn (Total - Locked)

### Invariants
1. `locked_collateral[user] <= user_collateral[user]` for all users
2. `sum(user_collateral) == total_vault_collateral`
3. Available collateral = Total collateral - Locked collateral
4. ctrlBTC total supply = total_vault_collateral

### State Transitions
```
Deposit: user_collateral[user] += amount, total_vault_collateral += amount
Withdraw: user_collateral[user] -= amount, total_vault_collateral -= amount
Lock: locked_collateral[user] += amount
Unlock: locked_collateral[user] -= amount
```

## Error Handling

### Error Codes and Scenarios
```move
const E_NOT_AUTHORIZED: u64 = 1;        // Unauthorized access attempt
const E_INVALID_AMOUNT: u64 = 2;        // Zero or negative amount
const E_INSUFFICIENT_COLLATERAL: u64 = 3; // Not enough available collateral
const E_INSUFFICIENT_LOCKED: u64 = 4;   // Not enough locked collateral to unlock
const E_ALREADY_INITIALIZED: u64 = 5;   // Contract already initialized
const E_VAULT_PAUSED: u64 = 6;          // Operations paused by admin
const E_TOKEN_OPERATION_FAILED: u64 = 7; // ctrlBTC mint/burn failed
```

### Validation Logic
1. **Amount Validation**: All amounts must be positive (> 0)
2. **Balance Validation**: Operations must not exceed available balances
3. **Authorization Validation**: Verify caller permissions for restricted functions
4. **State Validation**: Ensure vault is not paused for user operations
5. **Integration Validation**: Verify ctrlBTC operations succeed

## Testing Strategy

### Unit Test Categories

#### Basic Operations Testing
- Deposit collateral with valid amounts
- Withdraw collateral with sufficient balance
- Lock/unlock collateral with proper authorization
- Query balance functions return correct values

#### Access Control Testing
- Unauthorized lock/unlock attempts fail
- Non-admin administrative function calls fail
- Admin privilege transfer works correctly
- LoanManager address updates require admin

#### Edge Case Testing
- Zero amount deposits/withdrawals fail
- Withdraw more than available balance fails
- Lock more than total balance fails
- Unlock more than locked balance fails

#### Integration Testing
- ctrlBTC minting on successful deposits
- ctrlBTC burning on successful withdrawals
- Token operation failures cause transaction revert
- Balance consistency across operations

#### State Management Testing
- Pause/unpause functionality works correctly
- Paused state prevents user operations
- Admin operations work during pause
- Balance invariants maintained across all operations

### Test Scenarios

#### Happy Path Scenarios
1. **Complete Deposit-Withdraw Cycle**: User deposits, receives ctrlBTC, later withdraws
2. **Loan Collateral Cycle**: User deposits, LoanManager locks collateral, later unlocks
3. **Multiple User Operations**: Concurrent operations by different users
4. **Administrative Management**: Admin updates, pause/unpause operations

#### Error Scenarios
1. **Insufficient Balance Withdrawals**: Attempt to withdraw more than available
2. **Unauthorized Operations**: Non-LoanManager attempts to lock/unlock
3. **Invalid Amounts**: Zero or negative amount operations
4. **Paused State Operations**: User operations during emergency pause

#### Stress Testing
1. **Large Amount Operations**: Test with maximum possible amounts
2. **Rapid Sequential Operations**: Multiple operations in quick succession
3. **Boundary Conditions**: Operations at exact balance limits
4. **Concurrent User Operations**: Multiple users operating simultaneously

## Security Considerations

### Access Control Matrix
| Function | User | LoanManager | Admin |
|----------|------|-------------|-------|
| deposit_collateral | ✓ | ✗ | ✓ |
| withdraw_collateral | ✓ | ✗ | ✓ |
| lock_collateral | ✗ | ✓ | ✗ |
| unlock_collateral | ✗ | ✓ | ✗ |
| update_loan_manager | ✗ | ✗ | ✓ |
| update_admin | ✗ | ✗ | ✓ |
| set_pause_state | ✗ | ✗ | ✓ |

### Security Measures
1. **Strict Authorization**: Each function validates caller permissions
2. **Balance Validation**: Prevent operations exceeding available balances
3. **Atomic Operations**: All state changes within transactions are atomic
4. **Emergency Controls**: Admin can pause operations in emergencies
5. **Integration Safety**: Verify external contract calls succeed

### Attack Vector Mitigation
1. **Reentrancy**: Move's ownership model prevents reentrancy attacks
2. **Integer Overflow**: Use safe arithmetic operations
3. **Unauthorized Access**: Comprehensive permission checks
4. **State Corruption**: Maintain invariants through validation
5. **External Dependencies**: Handle ctrlBTC operation failures gracefully

## Performance Considerations

### Gas Optimization
1. **Efficient Storage**: Use tables for user balance mappings
2. **Minimal Computation**: Simple arithmetic operations
3. **Event Batching**: Single event per operation
4. **State Caching**: Cache frequently accessed values

### Scalability
1. **User Isolation**: Per-user balance tracking scales independently
2. **Operation Independence**: Most operations don't affect other users
3. **Query Efficiency**: Direct table lookups for balance queries
4. **Event Filtering**: Structured events for efficient filtering

## Integration Specifications

### ctrlBTC Token Integration
```move
// On deposit
ctrl_btc_token::mint(user_address, amount)

// On withdrawal  
ctrl_btc_token::burn_from_user(user_address, amount)
```

### LoanManager Integration
```move
// LoanManager calls for collateral management
collateral_vault::lock_collateral(loan_manager_signer, user_address, amount)
collateral_vault::unlock_collateral(loan_manager_signer, user_address, amount)
```

### Event Integration
External systems can monitor vault events for:
- User deposit/withdrawal tracking
- Loan collateral status changes
- Administrative actions
- System health monitoring

## Deployment and Configuration

### Initialization Parameters
- Admin address for vault management
- Initial LoanManager address (can be updated later)
- Emergency pause state (initially false)

### Post-Deployment Setup
1. Initialize ctrlBTC token with vault address
2. Configure LoanManager with vault address
3. Verify cross-contract integration
4. Set up monitoring for events and balances

### Upgrade Considerations
- Admin address can be transferred for governance
- LoanManager address can be updated for contract upgrades
- Emergency pause provides safety during upgrades
- Event history preserved across configuration changes