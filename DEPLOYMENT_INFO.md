# BTC Lending Platform - Deployment Information

## Contract Addresses (After Deployment)

The contracts will be deployed at the following addresses (replace `YOUR_WALLET_ADDRESS` with your actual wallet address):

- **InterestRateModel**: `YOUR_WALLET_ADDRESS::interest_rate_model`
- **CollateralVault**: `YOUR_WALLET_ADDRESS::collateral_vault`
- **LoanManager**: `YOUR_WALLET_ADDRESS::loan_manager`
- **ctrlBTC Token**: `YOUR_WALLET_ADDRESS::ctrl_btc_token`
- **lnBTC Token**: `YOUR_WALLET_ADDRESS::ln_btc_token`

## Deployment Files

The following files are ready for deployment in the `build/btc_lending_platform/` directory:

### Bytecode Files
- `bytecode_modules/interest_rate_model.mv`
- `bytecode_modules/collateral_vault.mv`
- `bytecode_modules/loan_manager.mv`
- `bytecode_modules/ctrl_btc_token.mv`
- `bytecode_modules/ln_btc_token.mv`

### Deployment Script
- `bytecode_scripts/deploy.mv`

### Package Metadata
- `package-metadata.bcs`

## Contract ABIs (Function Signatures)

### InterestRateModel Contract
```move
// Initialize the interest rate model
public fun initialize(admin: &signer): address

// Get interest rate for a given LTV ratio
public fun get_interest_rate(ltv_ratio: u64): u64

// Update interest rate for a given LTV ratio (admin only)
public fun update_interest_rate(admin: &signer, ltv_ratio: u64, new_rate: u64)

// Transfer admin privileges
public fun transfer_admin(admin: &signer, new_admin: address)
```

### CollateralVault Contract
```move
// Initialize the collateral vault
public fun initialize(admin: &signer, loan_manager_address: address): address

// Deposit BTC collateral (mint ctrlBTC tokens)
public fun deposit_collateral(user: &signer, amount: u64)

// Withdraw BTC collateral (burn ctrlBTC tokens)
public fun withdraw_collateral(user: &signer, amount: u64)

// Lock collateral for a loan (loan manager only)
public fun lock_collateral(loan_manager: &signer, user_address: address, amount: u64)

// Unlock collateral after loan repayment (loan manager only)
public fun unlock_collateral(loan_manager: &signer, user_address: address, amount: u64)

// Get user's total collateral balance
public fun get_user_collateral(user_address: address): u64

// Get user's locked collateral amount
public fun get_user_locked_collateral(user_address: address): u64

// Get user's available collateral
public fun get_user_available_collateral(user_address: address): u64

// Update loan manager address (admin only)
public fun update_loan_manager_address(admin: &signer, new_loan_manager: address)

// Transfer admin privileges
public fun transfer_admin(admin: &signer, new_admin: address)

// Pause/unpause vault operations
public fun pause_vault(admin: &signer)
public fun unpause_vault(admin: &signer)
```

### LoanManager Contract
```move
// Initialize the loan manager
public fun initialize(
    admin: &signer,
    collateral_vault_address: address,
    interest_rate_model_address: address
): address

// Create a new loan (admin function)
public fun create_loan(
    admin: &signer,
    borrower_address: address,
    collateral_amount: u64,
    ltv_ratio: u64
)

// Repay a loan (admin function)
public fun repay_loan(
    admin: &signer,
    borrower_address: address,
    loan_id: u64,
    repayment_amount: u64
)

// Close a loan (admin function)
public fun close_loan(admin: &signer, loan_id: u64)

// Calculate interest owed for a loan
public fun calculate_interest_owed(loan_id: u64): u64

// Get loan details
public fun get_loan(loan_id: u64): (address, u64, u64, u64, u64, u64, u64, u8)

// Get all loans for a borrower
public fun get_borrower_loans(borrower_address: address): vector<u64>

// Get system statistics
public fun get_system_stats(): (u64, u64, u64, u64)

// Update contract addresses (admin only)
public fun update_collateral_vault_address(admin: &signer, new_address: address)
public fun update_interest_rate_model_address(admin: &signer, new_address: address)

// Transfer admin privileges
public fun transfer_admin(admin: &signer, new_admin: address)

// Pause/unpause system operations
public fun pause_system(admin: &signer)
public fun unpause_system(admin: &signer)
```

### ctrlBTC Token Contract
```move
// Initialize the ctrlBTC token
public fun initialize(admin: &signer, collateral_vault_address: address): FungibleAssetMetadata

// Mint ctrlBTC tokens (collateral vault only)
public fun mint(amount: u64, to: address)

// Burn ctrlBTC tokens (collateral vault only)
public fun burn(amount: u64, from: address)

// Get token metadata
public fun get_metadata(): FungibleAssetMetadata
```

### lnBTC Token Contract
```move
// Initialize the lnBTC token
public fun initialize(admin: &signer, loan_manager_address: address): FungibleAssetMetadata

// Mint lnBTC tokens (loan manager only)
public fun mint(amount: u64, to: address)

// Burn lnBTC tokens (loan manager only)
public fun burn(amount: u64, from: address)

// Get token metadata
public fun get_metadata(): FungibleAssetMetadata
```

## Deployment Steps

1. **Prepare your wallet**: Ensure you have sufficient APT for gas fees
2. **Deploy the package**: Use the `package-metadata.bcs` file to deploy all contracts
3. **Run the deployment script**: Execute the `deploy.mv` script to initialize all contracts
4. **Verify deployment**: Check that all contracts are properly initialized and connected

## Integration Notes

- All loan operations require admin privileges in the current implementation
- The system uses over-collateralization with a maximum 60% LTV ratio
- Interest rates are fixed based on LTV ratios (30% → 5%, 45% → 8%, 60% → 10%)
- Both ctrlBTC and lnBTC tokens are ERC-20 compliant fungible assets
- The system includes comprehensive event logging for all operations

## Security Considerations

- Admin functions are protected by authorization checks
- The system includes pause/unpause functionality for emergency situations
- All operations validate input parameters and system state
- Over-collateralization ensures system solvency
- Modular design separates concerns for better security auditing
