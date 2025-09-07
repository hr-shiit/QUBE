/// CollateralVault Contract
/// Manages secure storage and handling of user collateral for the BTC lending platform
/// Coordinates with ctrlBTC token for collateral representation and LoanManager for loan operations
module btc_lending_platform::collateral_vault {
    use aptos_std::table::{Self, Table};
    use aptos_framework::event;
    use aptos_framework::primary_fungible_store;
    use std::error;
    use std::signer;
    use btc_lending_platform::ctrl_btc_token;

    /// Error codes
    const E_NOT_AUTHORIZED: u64 = 1;
    const E_INVALID_AMOUNT: u64 = 2;
    const E_INSUFFICIENT_COLLATERAL: u64 = 3;
    const E_INSUFFICIENT_LOCKED: u64 = 4;
    const E_ALREADY_INITIALIZED: u64 = 5;
    const E_VAULT_PAUSED: u64 = 6;
    const E_TOKEN_OPERATION_FAILED: u64 = 7;

    /// CollateralVault resource storing all vault state
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

    /// Event emitted when user deposits collateral
    #[event]
    struct DepositEvent has drop, store {
        user: address,
        amount: u64,
        new_total_balance: u64,
    }

    /// Event emitted when user withdraws collateral
    #[event]
    struct WithdrawalEvent has drop, store {
        user: address,
        amount: u64,
        new_total_balance: u64,
    }

    /// Event emitted when collateral is locked for a loan
    #[event]
    struct CollateralLockedEvent has drop, store {
        user: address,
        amount: u64,
        locked_by: address,
        new_locked_balance: u64,
    }

    /// Event emitted when collateral is unlocked after loan repayment
    #[event]
    struct CollateralUnlockedEvent has drop, store {
        user: address,
        amount: u64,
        unlocked_by: address,
        new_locked_balance: u64,
    }

    /// Event emitted when admin updates LoanManager address
    #[event]
    struct LoanManagerUpdatedEvent has drop, store {
        old_address: address,
        new_address: address,
        updated_by: address,
    }

    /// Event emitted when admin privileges are transferred
    #[event]
    struct AdminUpdatedEvent has drop, store {
        old_admin: address,
        new_admin: address,
    }

    /// Event emitted when vault pause state changes
    #[event]
    struct PauseStateChangedEvent has drop, store {
        is_paused: bool,
        changed_by: address,
    }

    /// Initialize the CollateralVault with admin and LoanManager addresses
    /// Can only be called once during deployment
    public fun initialize(
        admin: &signer, 
        loan_manager_address: address
    ): address {
        let admin_address = signer::address_of(admin);
        
        // Ensure this hasn't been initialized before
        assert!(!exists<CollateralVault>(admin_address), error::already_exists(E_ALREADY_INITIALIZED));

        // Create the vault with empty tables and initial state
        let vault = CollateralVault {
            user_collateral: table::new<address, u64>(),
            locked_collateral: table::new<address, u64>(),
            total_vault_collateral: 0,
            loan_manager_address,
            admin_address,
            is_paused: false,
        };

        move_to(admin, vault);
        admin_address
    }

    /// Helper function to validate amount is positive
    fun validate_amount(amount: u64) {
        assert!(amount > 0, error::invalid_argument(E_INVALID_AMOUNT));
    }

    /// Helper function to check if vault is not paused
    fun check_not_paused() acquires CollateralVault {
        let vault = borrow_global<CollateralVault>(@btc_lending_platform);
        assert!(!vault.is_paused, error::permission_denied(E_VAULT_PAUSED));
    }

    /// Helper function to verify admin authorization
    fun verify_admin(caller: &signer) acquires CollateralVault {
        let vault = borrow_global<CollateralVault>(@btc_lending_platform);
        assert!(signer::address_of(caller) == vault.admin_address, error::permission_denied(E_NOT_AUTHORIZED));
    }

    /// Helper function to verify LoanManager authorization
    fun verify_loan_manager(caller: &signer) acquires CollateralVault {
        let vault = borrow_global<CollateralVault>(@btc_lending_platform);
        assert!(signer::address_of(caller) == vault.loan_manager_address, error::permission_denied(E_NOT_AUTHORIZED));
    }

    /// Helper function to get user's total collateral (0 if not exists)
    fun get_user_collateral_internal(user_address: address): u64 acquires CollateralVault {
        let vault = borrow_global<CollateralVault>(@btc_lending_platform);
        if (table::contains(&vault.user_collateral, user_address)) {
            *table::borrow(&vault.user_collateral, user_address)
        } else {
            0
        }
    }

    /// Helper function to get user's locked collateral (0 if not exists)
    fun get_user_locked_internal(user_address: address): u64 acquires CollateralVault {
        let vault = borrow_global<CollateralVault>(@btc_lending_platform);
        if (table::contains(&vault.locked_collateral, user_address)) {
            *table::borrow(&vault.locked_collateral, user_address)
        } else {
            0
        }
    }

    /// Helper function to set user's total collateral
    fun set_user_collateral_internal(user_address: address, amount: u64) acquires CollateralVault {
        let vault = borrow_global_mut<CollateralVault>(@btc_lending_platform);
        if (table::contains(&vault.user_collateral, user_address)) {
            *table::borrow_mut(&mut vault.user_collateral, user_address) = amount;
        } else {
            table::add(&mut vault.user_collateral, user_address, amount);
        };
    }

    /// Helper function to set user's locked collateral
    fun set_user_locked_internal(user_address: address, amount: u64) acquires CollateralVault {
        let vault = borrow_global_mut<CollateralVault>(@btc_lending_platform);
        if (table::contains(&vault.locked_collateral, user_address)) {
            *table::borrow_mut(&mut vault.locked_collateral, user_address) = amount;
        } else {
            table::add(&mut vault.locked_collateral, user_address, amount);
        };
    }

    /// Deposit BTC collateral and mint ctrlBTC tokens
    /// This function simulates BTC deposit by minting ctrlBTC directly
    /// In a real implementation, this would be called after BTC is received
    public fun deposit_collateral(
        user: &signer,
        amount: u64
    ) acquires CollateralVault {
        check_not_paused();
        validate_amount(amount);
        
        let user_address = signer::address_of(user);
        let current_collateral = get_user_collateral_internal(user_address);
        let new_total = current_collateral + amount;
        
        // Update user's total collateral
        set_user_collateral_internal(user_address, new_total);
        
        // Update vault total
        let vault = borrow_global_mut<CollateralVault>(@btc_lending_platform);
        vault.total_vault_collateral = vault.total_vault_collateral + amount;
        
        // Mint ctrlBTC tokens to user
        ctrl_btc_token::mint(@btc_lending_platform, user_address, amount);
        
        // Emit deposit event
        let deposit_event = DepositEvent {
            user: user_address,
            amount,
            new_total_balance: new_total,
        };
        event::emit(deposit_event);
    }

    /// Withdraw BTC collateral (burn ctrlBTC tokens)
    /// Can only withdraw unlocked collateral
    public fun withdraw_collateral(
        user: &signer,
        amount: u64
    ) acquires CollateralVault {
        check_not_paused();
        validate_amount(amount);
        
        let user_address = signer::address_of(user);
        let current_collateral = get_user_collateral_internal(user_address);
        let locked_collateral = get_user_locked_internal(user_address);
        let available_collateral = current_collateral - locked_collateral;
        
        // Ensure user has enough available collateral
        assert!(amount <= available_collateral, error::invalid_argument(E_INSUFFICIENT_COLLATERAL));
        
        let new_total = current_collateral - amount;
        
        // Update user's total collateral
        set_user_collateral_internal(user_address, new_total);
        
        // Update vault total
        let vault = borrow_global_mut<CollateralVault>(@btc_lending_platform);
        vault.total_vault_collateral = vault.total_vault_collateral - amount;
        
        // Burn ctrlBTC tokens from user
        let metadata = ctrl_btc_token::get_metadata();
        let tokens = primary_fungible_store::withdraw(user, metadata, amount);
        ctrl_btc_token::burn(@btc_lending_platform, tokens);
        
        // Emit withdrawal event
        let withdrawal_event = WithdrawalEvent {
            user: user_address,
            amount,
            new_total_balance: new_total,
        };
        event::emit(withdrawal_event);
    }

    /// Lock collateral for a loan (called by LoanManager)
    public fun lock_collateral(
        loan_manager: &signer,
        user_address: address,
        amount: u64
    ) acquires CollateralVault {
        check_not_paused();
        verify_loan_manager(loan_manager);
        validate_amount(amount);
        
        let current_collateral = get_user_collateral_internal(user_address);
        let current_locked = get_user_locked_internal(user_address);
        let available_collateral = current_collateral - current_locked;
        
        // Ensure user has enough available collateral
        assert!(amount <= available_collateral, error::invalid_argument(E_INSUFFICIENT_COLLATERAL));
        
        let new_locked = current_locked + amount;
        
        // Update user's locked collateral
        set_user_locked_internal(user_address, new_locked);
        
        // Emit collateral locked event
        let lock_event = CollateralLockedEvent {
            user: user_address,
            amount,
            locked_by: signer::address_of(loan_manager),
            new_locked_balance: new_locked,
        };
        event::emit(lock_event);
    }

    /// Unlock collateral after loan repayment (called by LoanManager)
    public fun unlock_collateral(
        loan_manager: &signer,
        user_address: address,
        amount: u64
    ) acquires CollateralVault {
        check_not_paused();
        verify_loan_manager(loan_manager);
        validate_amount(amount);
        
        let current_locked = get_user_locked_internal(user_address);
        
        // Ensure user has enough locked collateral
        assert!(amount <= current_locked, error::invalid_argument(E_INSUFFICIENT_LOCKED));
        
        let new_locked = current_locked - amount;
        
        // Update user's locked collateral
        set_user_locked_internal(user_address, new_locked);
        
        // Emit collateral unlocked event
        let unlock_event = CollateralUnlockedEvent {
            user: user_address,
            amount,
            unlocked_by: signer::address_of(loan_manager),
            new_locked_balance: new_locked,
        };
        event::emit(unlock_event);
    }

    /// Get user's total collateral balance
    public fun get_user_collateral(user_address: address): u64 acquires CollateralVault {
        get_user_collateral_internal(user_address)
    }

    /// Get user's locked collateral balance
    public fun get_user_locked_collateral(user_address: address): u64 acquires CollateralVault {
        get_user_locked_internal(user_address)
    }

    /// Get user's available collateral (total - locked)
    public fun get_user_available_collateral(user_address: address): u64 acquires CollateralVault {
        let total = get_user_collateral_internal(user_address);
        let locked = get_user_locked_internal(user_address);
        if (total >= locked) {
            total - locked
        } else {
            0
        }
    }

    /// Get total collateral in the vault
    public fun get_total_vault_collateral(): u64 acquires CollateralVault {
        let vault = borrow_global<CollateralVault>(@btc_lending_platform);
        vault.total_vault_collateral
    }

    /// Get total locked collateral across all users
    public fun get_total_locked_collateral(): u64 acquires CollateralVault {
        let _vault = borrow_global<CollateralVault>(@btc_lending_platform);
        let total_locked = 0u64;
        
        // Note: In a real implementation, we'd iterate through all users
        // For now, this is a placeholder that would need to be tracked separately
        // or calculated by iterating through the locked_collateral table
        total_locked
    }

    /// Update LoanManager address (admin only)
    public fun update_loan_manager_address(admin: &signer, new_loan_manager_address: address) acquires CollateralVault {
        verify_admin(admin);
        
        let vault = borrow_global_mut<CollateralVault>(@btc_lending_platform);
        let old_address = vault.loan_manager_address;
        vault.loan_manager_address = new_loan_manager_address;
        
        // Emit update event
        let update_event = LoanManagerUpdatedEvent {
            old_address,
            new_address: new_loan_manager_address,
            updated_by: signer::address_of(admin),
        };
        event::emit(update_event);
    }

    /// Transfer admin privileges (current admin only)
    public fun transfer_admin(admin: &signer, new_admin: address) acquires CollateralVault {
        verify_admin(admin);
        
        let vault = borrow_global_mut<CollateralVault>(@btc_lending_platform);
        let old_admin = vault.admin_address;
        vault.admin_address = new_admin;
        
        // Emit admin transfer event
        let admin_event = AdminUpdatedEvent {
            old_admin,
            new_admin,
        };
        event::emit(admin_event);
    }

    /// Pause the vault (admin only)
    public fun pause_vault(admin: &signer) acquires CollateralVault {
        verify_admin(admin);
        
        let vault = borrow_global_mut<CollateralVault>(@btc_lending_platform);
        vault.is_paused = true;
        
        // Emit pause event
        let pause_event = PauseStateChangedEvent {
            is_paused: true,
            changed_by: signer::address_of(admin),
        };
        event::emit(pause_event);
    }

    /// Unpause the vault (admin only)
    public fun unpause_vault(admin: &signer) acquires CollateralVault {
        verify_admin(admin);
        
        let vault = borrow_global_mut<CollateralVault>(@btc_lending_platform);
        vault.is_paused = false;
        
        // Emit unpause event
        let unpause_event = PauseStateChangedEvent {
            is_paused: false,
            changed_by: signer::address_of(admin),
        };
        event::emit(unpause_event);
    }

    /// Check if vault is paused
    public fun is_paused(): bool acquires CollateralVault {
        let vault = borrow_global<CollateralVault>(@btc_lending_platform);
        vault.is_paused
    }

    /// Get current admin address
    public fun get_admin(): address acquires CollateralVault {
        let vault = borrow_global<CollateralVault>(@btc_lending_platform);
        vault.admin_address
    }

    /// Get current LoanManager address
    public fun get_loan_manager_address(): address acquires CollateralVault {
        let vault = borrow_global<CollateralVault>(@btc_lending_platform);
        vault.loan_manager_address
    }

    #[test_only]
    use aptos_framework::account;

    #[test(admin = @btc_lending_platform)]
    public fun test_initialize(admin: &signer) acquires CollateralVault {
        let loan_manager = @0x123;
        let admin_address = initialize(admin, loan_manager);
        
        // Verify initialization
        assert!(exists<CollateralVault>(admin_address), 1);
        assert!(admin_address == signer::address_of(admin), 2);
        
        // Verify initial state
        let vault = borrow_global<CollateralVault>(@btc_lending_platform);
        assert!(vault.total_vault_collateral == 0, 3);
        assert!(vault.loan_manager_address == loan_manager, 4);
        assert!(vault.admin_address == admin_address, 5);
        assert!(!vault.is_paused, 6);
    }

    #[test(admin = @btc_lending_platform)]
    #[expected_failure(abort_code = 0x80005, location = Self)]
    public fun test_initialize_twice_fails(admin: &signer) {
        let loan_manager = @0x123;
        initialize(admin, loan_manager);
        initialize(admin, loan_manager); // Should fail
    }

    #[test(admin = @btc_lending_platform)]
    public fun test_helper_functions(admin: &signer) acquires CollateralVault {
        let loan_manager = @0x123;
        initialize(admin, loan_manager);
        
        let user = @0x456;
        
        // Test initial values
        assert!(get_user_collateral_internal(user) == 0, 1);
        assert!(get_user_locked_internal(user) == 0, 2);
        
        // Test setting values
        set_user_collateral_internal(user, 1000);
        set_user_locked_internal(user, 300);
        
        assert!(get_user_collateral_internal(user) == 1000, 3);
        assert!(get_user_locked_internal(user) == 300, 4);
        
        // Test updating values
        set_user_collateral_internal(user, 1500);
        set_user_locked_internal(user, 500);
        
        assert!(get_user_collateral_internal(user) == 1500, 5);
        assert!(get_user_locked_internal(user) == 500, 6);
    }

    #[test(admin = @btc_lending_platform)]
    public fun test_validation_functions(admin: &signer) acquires CollateralVault {
        let loan_manager = @0x123;
        initialize(admin, loan_manager);
        
        // Test amount validation
        validate_amount(1);
        validate_amount(1000);
        validate_amount(18446744073709551615); // Max u64
        
        // Test not paused check
        check_not_paused();
        
        // Test admin verification
        verify_admin(admin);
    }

    #[test(admin = @btc_lending_platform)]
    #[expected_failure(abort_code = 0x10002, location = Self)]
    public fun test_validate_zero_amount_fails(admin: &signer) {
        let loan_manager = @0x123;
        initialize(admin, loan_manager);
        
        validate_amount(0); // Should fail
    }

    #[test(admin = @btc_lending_platform, non_admin = @0x456)]
    #[expected_failure(abort_code = 0x50001, location = Self)]
    public fun test_verify_admin_fails_for_non_admin(admin: &signer, non_admin: &signer) acquires CollateralVault {
        account::create_account_for_test(signer::address_of(non_admin));
        
        let loan_manager = @0x123;
        initialize(admin, loan_manager);
        
        verify_admin(non_admin); // Should fail
    }

    #[test(admin = @btc_lending_platform, non_loan_manager = @0x456)]
    #[expected_failure(abort_code = 0x50001, location = Self)]
    public fun test_verify_loan_manager_fails_for_unauthorized(admin: &signer, non_loan_manager: &signer) acquires CollateralVault {
        account::create_account_for_test(signer::address_of(non_loan_manager));
        
        let loan_manager = @0x123;
        initialize(admin, loan_manager);
        
        verify_loan_manager(non_loan_manager); // Should fail
    }
}