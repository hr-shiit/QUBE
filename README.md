# BTC Lending Platform

A decentralized lending platform built on Aptos Move that enables users to deposit BTC as collateral and borrow against it using synthetic tokens. The platform implements over-collateralized lending with fixed interest rates based on loan-to-value (LTV) ratios.

## 🏗️ Architecture

The platform consists of five core modules:

1. **ctrlBTC Token**: ERC-20 compliant token representing BTC deposited as collateral
2. **lnBTC Token**: ERC-20 compliant token representing loan BTC issued to borrowers  
3. **CollateralVault**: Secure storage and management of user collateral
4. **LoanManager**: Core business logic for complete loan lifecycle management
5. **InterestRateModel**: Interest rate calculation based on LTV ratios

## ✨ Features

- **Over-collateralized lending** (up to 60% LTV)
- **Fixed interest rates** based on loan-to-value ratios
- **Secure collateral management** with atomic operations
- **Modular architecture** for maintainability and upgrades
- **Comprehensive event system** for tracking all operations
- **Admin controls** for emergency situations and system management
- **Full test coverage** including integration tests

## 💰 Interest Rate Structure

| LTV Ratio | Interest Rate | Use Case |
|-----------|---------------|----------|
| 30%       | 5%           | Conservative borrowing |
| 45%       | 8%           | Moderate borrowing |
| 60%       | 10%          | Maximum borrowing |

## 🔄 Core Workflow

### 1. Deposit Collateral
```move
// User deposits 1 BTC as collateral
collateral_vault::deposit_collateral(user, 100000000); // 1 BTC in satoshis
// This mints 1 ctrlBTC token to the user
```

### 2. Create Loan
```move
// User creates a loan with 30% LTV against their collateral
loan_manager::create_loan(user, 100000000, 30); // 1 BTC collateral, 30% LTV
// This locks the collateral and mints 0.3 lnBTC to the user
```

### 3. Repay Loan
```move
// User repays the loan (partial or full)
loan_manager::repay_loan(user, loan_id, repayment_amount);
// This burns lnBTC tokens and unlocks collateral proportionally
```

### 4. Withdraw Collateral
```move
// User withdraws their unlocked collateral
collateral_vault::withdraw_collateral(user, amount);
// This burns ctrlBTC tokens and releases the underlying BTC
```

## 🚀 Development

### Prerequisites

- Aptos CLI installed and configured
- Move development environment set up
- Testnet account with APT tokens for deployment

### Building

```bash
# Compile all modules
aptos move compile

# Compile with specific address
aptos move compile --named-addresses btc_lending_platform=0x123...
```

### Testing

```bash
# Run all tests
aptos move test

# Run specific test module
aptos move test --filter integration_tests

# Run with verbose output
aptos move test --verbose
```

### Deployment

```bash
# Deploy to testnet
aptos move publish --profile testnet

# Deploy with custom profile
aptos move publish --profile mainnet
```

## 📊 System Statistics

The platform tracks comprehensive statistics:

- **Total Active Loans**: Number of currently active loans
- **Total Outstanding Debt**: Sum of all outstanding loan principals
- **Total Loans Created**: Historical count of all loans created
- **Total Vault Collateral**: Total collateral deposited across all users

## 🔒 Security Features

### Access Controls
- **ctrlBTC**: Only CollateralVault can mint/burn
- **lnBTC**: Only LoanManager can mint/burn  
- **CollateralVault**: Only LoanManager can lock/unlock collateral
- **InterestRateModel**: Only admin can update rates
- **All contracts**: Admin-only emergency controls

### Over-Collateralization
- Maximum LTV: 60%
- Ensures system remains solvent
- Provides buffer against price volatility
- Prevents under-collateralized positions

### Emergency Controls
- **Pause/Unpause**: Admin can pause system operations
- **Admin Transfer**: Secure admin privilege transfer
- **Contract Updates**: Admin can update contract addresses
- **Emergency Loan Closure**: Admin can close loans in emergencies

## 🧪 Testing

The platform includes comprehensive test coverage:

### Unit Tests
- Individual contract function testing
- Access control verification
- Error condition testing
- Edge case validation

### Integration Tests
- End-to-end loan workflows
- Cross-contract interactions
- Multiple user scenarios
- System statistics tracking
- Error condition handling

### Test Coverage
- ✅ Token operations (mint, burn, transfer)
- ✅ Collateral management (deposit, withdraw, lock, unlock)
- ✅ Loan lifecycle (create, repay, close)
- ✅ Interest calculations
- ✅ System statistics
- ✅ Admin functions
- ✅ Error conditions

## 📈 Usage Examples

### Basic Loan Flow
```move
// 1. Deposit 1 BTC collateral
collateral_vault::deposit_collateral(user, 100000000);

// 2. Create 30% LTV loan (0.3 BTC loan)
loan_manager::create_loan(user, 100000000, 30);

// 3. Use the loan tokens (transfer, trade, etc.)
ln_btc_token::transfer(user, recipient, 15000000); // 0.15 BTC

// 4. Repay loan with interest
let (_, _, _, outstanding, _, _, interest_owed, _) = loan_manager::get_loan(1);
loan_manager::repay_loan(user, 1, outstanding + interest_owed);

// 5. Withdraw remaining collateral
collateral_vault::withdraw_collateral(user, 100000000);
```

### Multiple Loans
```move
// User can have multiple active loans
loan_manager::create_loan(user, 100000000, 30); // 0.3 BTC loan
loan_manager::create_loan(user, 50000000, 45);  // 0.225 BTC loan

// Check all user loans
let user_loans = loan_manager::get_borrower_loans(user_address);
```

### Admin Operations
```move
// Update interest rates
interest_rate_model::set_rate(admin, 40, 650); // 40% LTV -> 6.5% rate

// Pause system in emergency
loan_manager::pause_system(admin);

// Transfer admin privileges
loan_manager::transfer_admin(admin, new_admin_address);
```

## 🔧 Configuration

### Environment Variables
```bash
# For deployment
export APTOS_PROFILE=testnet
export APTOS_NETWORK=testnet
```

### Contract Addresses
After deployment, update your frontend/scripts with the deployed contract addresses:
- InterestRateModel
- CollateralVault  
- LoanManager
- ctrlBTC Token
- lnBTC Token

## 📝 Events

The platform emits comprehensive events for all operations:

- **DepositEvent**: When users deposit collateral
- **WithdrawalEvent**: When users withdraw collateral
- **LoanCreatedEvent**: When new loans are created
- **LoanRepaidEvent**: When loans are repaid
- **CollateralLockedEvent**: When collateral is locked for loans
- **CollateralUnlockedEvent**: When collateral is unlocked
- **LoanStateChangedEvent**: When loan states change

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details

## 🆘 Support

For questions, issues, or contributions:
- Create an issue on GitHub
- Review the test files for usage examples
- Check the integration tests for complete workflows