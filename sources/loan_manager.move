/// LoanManager Contract
/// Central orchestrator for the BTC lending platform managing complete loan lifecycle
/// Coordinates with CollateralVault, InterestRateModel, and token contracts
module btc_lending_platform::loan_manager {
    use aptos_std::table::{Self, Table};
    use aptos_framework::event;
    use aptos_framework::timestamp;
    use std::error;
    use std::signer;
    use std::vector;
    use btc_lending_platform::collateral_vault;
    use btc_lending_platform::interest_rate_model;
    use btc_lending_platform::ln_btc_token;

    /// Error codes
    const E_NOT_AUTHORIZED: u64 = 1;
    const E_INVALID_AMOUNT: u64 = 2;
    const E_INSUFFICIENT_COLLATERAL: u64 = 3;
    const E_LOAN_NOT_FOUND: u64 = 4;
    const E_LOAN_NOT_ACTIVE: u64 = 5;
    const E_INVALID_LTV: u64 = 6;
    const E_ALREADY_INITIALIZED: u64 = 7;
    const E_SYSTEM_PAUSED: u64 = 8;
    const E_INSUFFICIENT_REPAYMENT: u64 = 9;
    const E_INTEGRATION_FAILED: u64 = 10;

    /// Loan state constants
    const LOAN_STATE_ACTIVE: u8 = 0;
    const LOAN_STATE_REPAID: u8 = 1;
    const LOAN_STATE_DEFAULTED: u8 = 2;

    /// Maximum LTV ratio allowed (60%)
    const MAX_LTV_RATIO: u64 = 60;

    /// Basis points for percentage calculations (10000 = 100%)
    const BASIS_POINTS_SCALE: u64 = 10000;

    /// Seconds per year for interest calculations (365.25 days)
    const SECONDS_PER_YEAR: u64 = 31557600;

    /// LoanManager resource storing all loan management state
    struct LoanManager has key {
        /// Mapping from loan ID to loan details
        loans: Table<u64, Loan>,
        /// Next available loan ID
        next_loan_id: u64,
        /// Mapping from borrower address to their loan IDs
        borrower_loans: Table<address, vector<u64>>,
        /// Total number of active loans
        total_active_loans: u64,
        /// Total outstanding debt across all loans (principal only)
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

    /// Individual loan details and state
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
        /// Current loan state (0=Active, 1=Repaid, 2=Defaulted)
        state: u8,
    }

    /// Event emitted when a new loan is created
    #[event]
    struct LoanCreatedEvent has drop, store {
        loan_id: u64,
        borrower: address,
        collateral_amount: u64,
        loan_amount: u64,
        interest_rate: u64,
        ltv_ratio: u64,
    }

    /// Event emitted when a loan is repaid (full or partial)
    #[event]
    struct LoanRepaidEvent has drop, store {
        loan_id: u64,
        borrower: address,
        repayment_amount: u64,
        interest_paid: u64,
        remaining_balance: u64,
        is_full_repayment: bool,
    }

    /// Event emitted when collateral is unlocked
    #[event]
    struct CollateralUnlockedEvent has drop, store {
        loan_id: u64,
        borrower: address,
        unlocked_amount: u64,
        remaining_locked: u64,
    }

    /// Event emitted when loan state changes
    #[event]
    struct LoanStateChangedEvent has drop, store {
        loan_id: u64,
        borrower: address,
        old_state: u8,
        new_state: u8,
    }

    /// Event emitted when contract addresses are updated
    #[event]
    struct ContractUpdatedEvent has drop, store {
        contract_type: vector<u8>, // "collateral_vault" or "interest_rate_model"
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

    /// Event emitted when system pause state changes
    #[event]
    struct PauseStateChangedEvent has drop, store {
        is_paused: bool,
        changed_by: address,
    }

    /// Initialize the LoanManager with contract addresses and admin
    /// Can only be called once during deployment
    public fun initialize(
        admin: &signer,
        collateral_vault_address: address,
        interest_rate_model_address: address
    ): address {
        let admin_address = signer::address_of(admin);
        
        // Ensure this hasn't been initialized before
        assert!(!exists<LoanManager>(admin_address), error::already_exists(E_ALREADY_INITIALIZED));

        // Create the loan manager with empty tables and initial state
        let loan_manager = LoanManager {
            loans: table::new<u64, Loan>(),
            next_loan_id: 1,
            borrower_loans: table::new<address, vector<u64>>(),
            total_active_loans: 0,
            total_outstanding_debt: 0,
            collateral_vault_address,
            interest_rate_model_address,
            admin_address,
            is_paused: false,
        };

        move_to(admin, loan_manager);
        admin_address
    }

    /// Helper function to validate amount is positive
    fun validate_amount(amount: u64) {
        assert!(amount > 0, error::invalid_argument(E_INVALID_AMOUNT));
    }

    /// Helper function to check if system is not paused
    fun check_not_paused() acquires LoanManager {
        let loan_manager = borrow_global<LoanManager>(@btc_lending_platform);
        assert!(!loan_manager.is_paused, error::permission_denied(E_SYSTEM_PAUSED));
    }

    /// Helper function to verify admin authorization
    fun verify_admin(caller: &signer) acquires LoanManager {
        let loan_manager = borrow_global<LoanManager>(@btc_lending_platform);
        assert!(signer::address_of(caller) == loan_manager.admin_address, error::permission_denied(E_NOT_AUTHORIZED));
    }

    /// Helper function to validate LTV ratio
    fun validate_ltv_ratio(ltv_ratio: u64) {
        assert!(ltv_ratio > 0 && ltv_ratio <= MAX_LTV_RATIO, error::invalid_argument(E_INVALID_LTV));
    }

    /// Helper function to calculate LTV ratio
    fun calculate_ltv_ratio(loan_amount: u64, collateral_amount: u64): u64 {
        assert!(collateral_amount > 0, error::invalid_argument(E_INVALID_AMOUNT));
        (loan_amount * 100) / collateral_amount
    }

    /// Helper function to generate next loan ID
    fun get_next_loan_id(): u64 acquires LoanManager {
        let loan_manager = borrow_global_mut<LoanManager>(@btc_lending_platform);
        let loan_id = loan_manager.next_loan_id;
        loan_manager.next_loan_id = loan_id + 1;
        loan_id
    }

    /// Helper function to check if loan exists
    fun loan_exists(loan_id: u64): bool acquires LoanManager {
        let loan_manager = borrow_global<LoanManager>(@btc_lending_platform);
        table::contains(&loan_manager.loans, loan_id)
    }

    /// Helper function to verify loan ownership
    fun verify_loan_ownership(loan_id: u64, borrower: address) acquires LoanManager {
        assert!(loan_exists(loan_id), error::not_found(E_LOAN_NOT_FOUND));
        let loan_manager = borrow_global<LoanManager>(@btc_lending_platform);
        let loan = table::borrow(&loan_manager.loans, loan_id);
        assert!(loan.borrower == borrower, error::permission_denied(E_NOT_AUTHORIZED));
    }

    /// Helper function to verify loan is active
    fun verify_loan_active(loan_id: u64) acquires LoanManager {
        assert!(loan_exists(loan_id), error::not_found(E_LOAN_NOT_FOUND));
        let loan_manager = borrow_global<LoanManager>(@btc_lending_platform);
        let loan = table::borrow(&loan_manager.loans, loan_id);
        assert!(loan.state == LOAN_STATE_ACTIVE, error::invalid_state(E_LOAN_NOT_ACTIVE));
    }

    /// Helper function to add loan to borrower's loan list
    fun add_loan_to_borrower(borrower: address, loan_id: u64) acquires LoanManager {
        let loan_manager = borrow_global_mut<LoanManager>(@btc_lending_platform);
        
        if (table::contains(&loan_manager.borrower_loans, borrower)) {
            let borrower_loan_list = table::borrow_mut(&mut loan_manager.borrower_loans, borrower);
            vector::push_back(borrower_loan_list, loan_id);
        } else {
            let new_loan_list = vector::empty<u64>();
            vector::push_back(&mut new_loan_list, loan_id);
            table::add(&mut loan_manager.borrower_loans, borrower, new_loan_list);
        };
    }

    /// Helper function to update system statistics
    fun update_system_stats(active_loans_delta: u64, debt_delta: u64, increase: bool) acquires LoanManager {
        let loan_manager = borrow_global_mut<LoanManager>(@btc_lending_platform);
        
        if (increase) {
            loan_manager.total_active_loans = loan_manager.total_active_loans + active_loans_delta;
            loan_manager.total_outstanding_debt = loan_manager.total_outstanding_debt + debt_delta;
        } else {
            loan_manager.total_active_loans = loan_manager.total_active_loans - active_loans_delta;
            loan_manager.total_outstanding_debt = loan_manager.total_outstanding_debt - debt_delta;
        };
    }

    /// Create a new loan for a borrower (admin function)
    public fun create_loan(
        admin: &signer,
        borrower_address: address,
        collateral_amount: u64,
        ltv_ratio: u64
    ) acquires LoanManager {
        check_not_paused();
        validate_amount(collateral_amount);
        validate_ltv_ratio(ltv_ratio);
        
        // Verify admin authorization
        let loan_manager = borrow_global<LoanManager>(@btc_lending_platform);
        assert!(signer::address_of(admin) == loan_manager.admin_address, error::permission_denied(E_NOT_AUTHORIZED));
        
        // Calculate loan amount based on LTV ratio
        let loan_amount = (collateral_amount * ltv_ratio) / 100;
        assert!(loan_amount > 0, error::invalid_argument(E_INVALID_AMOUNT));
        
        // Get interest rate from InterestRateModel
        let interest_rate = interest_rate_model::get_rate(ltv_ratio);
        
        // Generate new loan ID
        let loan_id = get_next_loan_id();
        
        // Create loan record
        let loan = Loan {
            loan_id,
            borrower: borrower_address,
            collateral_amount,
            loan_amount,
            outstanding_balance: loan_amount,
            interest_rate,
            creation_timestamp: timestamp::now_seconds(),
            state: LOAN_STATE_ACTIVE,
        };
        
        // Store loan in mapping
        let loan_manager = borrow_global_mut<LoanManager>(@btc_lending_platform);
        table::add(&mut loan_manager.loans, loan_id, loan);
        
        // Add loan to borrower's loan list
        add_loan_to_borrower(borrower_address, loan_id);
        
        // Update system statistics
        update_system_stats(1, loan_amount, true);
        
        // Lock collateral in CollateralVault
        // Note: In production, the LoanManager contract address will be authorized
        // For now, we'll use the admin signer who deployed the contracts
        collateral_vault::lock_collateral(admin, borrower_address, collateral_amount);
        
        // Mint lnBTC tokens to borrower
        ln_btc_token::mint(@btc_lending_platform, borrower_address, loan_amount);
        
        // Emit loan created event
        let loan_created_event = LoanCreatedEvent {
            loan_id,
            borrower: borrower_address,
            collateral_amount,
            loan_amount,
            interest_rate,
            ltv_ratio,
        };
        event::emit(loan_created_event);
    }

    /// Repay a loan (partial or full)
    public fun repay_loan(
        admin: &signer,
        borrower_address: address,
        loan_id: u64,
        repayment_amount: u64
    ) acquires LoanManager {
        check_not_paused();
        validate_amount(repayment_amount);
        verify_loan_ownership(loan_id, borrower_address);
        verify_loan_active(loan_id);
        
        // Verify admin authorization
        let loan_manager = borrow_global<LoanManager>(@btc_lending_platform);
        assert!(signer::address_of(admin) == loan_manager.admin_address, error::permission_denied(E_NOT_AUTHORIZED));
        
        let loan_manager = borrow_global_mut<LoanManager>(@btc_lending_platform);
        let loan = table::borrow_mut(&mut loan_manager.loans, loan_id);
        
        // Calculate interest owed
        let interest_owed = calculate_interest_owed(loan);
        let total_owed = loan.outstanding_balance + interest_owed;
        
        // Ensure repayment doesn't exceed what's owed
        assert!(repayment_amount <= total_owed, error::invalid_argument(E_INSUFFICIENT_REPAYMENT));
        
        // Determine if this is a full repayment
        let is_full_repayment = (repayment_amount == total_owed);
        
        // Calculate how much goes to principal vs interest
        let interest_paid = if (repayment_amount >= interest_owed) {
            interest_owed
        } else {
            repayment_amount
        };
        let principal_paid = repayment_amount - interest_paid;
        
        // Update loan balance
        loan.outstanding_balance = loan.outstanding_balance - principal_paid;
        
        // Store values needed after releasing the borrow
        let borrower_address = loan.borrower;
        let collateral_amount = loan.collateral_amount;
        let remaining_balance = loan.outstanding_balance;
        let admin_address = loan_manager.admin_address;
        
        // Update system statistics
        update_system_stats(0, principal_paid, false);
        
        // Note: In a real implementation, the borrower would need to approve the loan manager
        // to burn their lnBTC tokens, or the tokens would be held in escrow
        // For this deployment, we'll assume the admin handles the token burning
        // ln_btc_token::burn(@btc_lending_platform, repayment_amount);
        
        // If full repayment, unlock collateral and close loan
        if (is_full_repayment) {
            // Update loan state
            let loan_manager = borrow_global_mut<LoanManager>(@btc_lending_platform);
            let loan = table::borrow_mut(&mut loan_manager.loans, loan_id);
            loan.state = LOAN_STATE_REPAID;
            
            // Update system statistics
            update_system_stats(1, 0, false); // Decrease active loan count
            
            // Unlock collateral in CollateralVault
            // Note: In production, the LoanManager contract address will be authorized
            // For now, we'll use the admin signer who deployed the contracts
            collateral_vault::unlock_collateral(admin, borrower_address, collateral_amount);
            
            // Emit collateral unlocked event
            let unlock_event = CollateralUnlockedEvent {
                loan_id,
                borrower: borrower_address,
                unlocked_amount: collateral_amount,
                remaining_locked: 0,
            };
            event::emit(unlock_event);
            
            // Emit loan state change event
            let state_event = LoanStateChangedEvent {
                loan_id,
                borrower: borrower_address,
                old_state: LOAN_STATE_ACTIVE,
                new_state: LOAN_STATE_REPAID,
            };
            event::emit(state_event);
        };
        
        // Emit loan repaid event
        let repaid_event = LoanRepaidEvent {
            loan_id,
            borrower: borrower_address,
            repayment_amount,
            interest_paid,
            remaining_balance,
            is_full_repayment,
        };
        event::emit(repaid_event);
    }

    /// Close a loan (admin only - for emergency situations)
    public fun close_loan(
        admin: &signer,
        loan_id: u64
    ) acquires LoanManager {
        verify_admin(admin);
        assert!(loan_exists(loan_id), error::not_found(E_LOAN_NOT_FOUND));
        
        let loan_manager = borrow_global_mut<LoanManager>(@btc_lending_platform);
        let loan = table::borrow_mut(&mut loan_manager.loans, loan_id);
        
        // Only close active loans
        assert!(loan.state == LOAN_STATE_ACTIVE, error::invalid_state(E_LOAN_NOT_ACTIVE));
        
        // Update loan state
        let old_state = loan.state;
        loan.state = LOAN_STATE_DEFAULTED;
        
        // Store values needed after releasing the borrow
        let borrower_address = loan.borrower;
        let collateral_amount = loan.collateral_amount;
        let outstanding_balance = loan.outstanding_balance;
        let admin_address = loan_manager.admin_address;
        
        // Update system statistics
        update_system_stats(1, outstanding_balance, false);
        
        // Unlock collateral (goes back to borrower)
        // Note: In production, the LoanManager contract address will be authorized
        // For now, we'll use the admin signer who deployed the contracts
        collateral_vault::unlock_collateral(admin, borrower_address, collateral_amount);
        
        // Emit events
        let state_event = LoanStateChangedEvent {
            loan_id,
            borrower: borrower_address,
            old_state,
            new_state: LOAN_STATE_DEFAULTED,
        };
        event::emit(state_event);
        
        let unlock_event = CollateralUnlockedEvent {
            loan_id,
            borrower: borrower_address,
            unlocked_amount: collateral_amount,
            remaining_locked: 0,
        };
        event::emit(unlock_event);
    }

    /// Calculate interest owed on a loan
    fun calculate_interest_owed(loan: &Loan): u64 {
        let time_elapsed = timestamp::now_seconds() - loan.creation_timestamp;
        let interest_per_second = (loan.outstanding_balance * loan.interest_rate) / (BASIS_POINTS_SCALE * SECONDS_PER_YEAR);
        time_elapsed * interest_per_second
    }

    /// Get loan details by ID
    public fun get_loan(loan_id: u64): (address, u64, u64, u64, u64, u64, u64, u8) acquires LoanManager {
        assert!(loan_exists(loan_id), error::not_found(E_LOAN_NOT_FOUND));
        
        let loan_manager = borrow_global<LoanManager>(@btc_lending_platform);
        let loan = table::borrow(&loan_manager.loans, loan_id);
        
        (
            loan.borrower,
            loan.collateral_amount,
            loan.loan_amount,
            loan.outstanding_balance,
            loan.interest_rate,
            loan.creation_timestamp,
            calculate_interest_owed(loan),
            loan.state
        )
    }

    /// Get all loan IDs for a borrower
    public fun get_borrower_loans(borrower_address: address): vector<u64> acquires LoanManager {
        let loan_manager = borrow_global<LoanManager>(@btc_lending_platform);
        
        if (table::contains(&loan_manager.borrower_loans, borrower_address)) {
            *table::borrow(&loan_manager.borrower_loans, borrower_address)
        } else {
            vector::empty<u64>()
        }
    }

    /// Get system statistics
    public fun get_system_stats(): (u64, u64, u64) acquires LoanManager {
        let loan_manager = borrow_global<LoanManager>(@btc_lending_platform);
        (
            loan_manager.total_active_loans,
            loan_manager.total_outstanding_debt,
            loan_manager.next_loan_id - 1 // Total loans created
        )
    }

    /// Update CollateralVault address (admin only)
    public fun update_collateral_vault_address(admin: &signer, new_vault_address: address) acquires LoanManager {
        verify_admin(admin);
        
        let loan_manager = borrow_global_mut<LoanManager>(@btc_lending_platform);
        let old_address = loan_manager.collateral_vault_address;
        loan_manager.collateral_vault_address = new_vault_address;
        
        // Emit update event
        let update_event = ContractUpdatedEvent {
            contract_type: b"collateral_vault",
            old_address,
            new_address: new_vault_address,
            updated_by: signer::address_of(admin),
        };
        event::emit(update_event);
    }

    /// Update InterestRateModel address (admin only)
    public fun update_interest_rate_model_address(admin: &signer, new_model_address: address) acquires LoanManager {
        verify_admin(admin);
        
        let loan_manager = borrow_global_mut<LoanManager>(@btc_lending_platform);
        let old_address = loan_manager.interest_rate_model_address;
        loan_manager.interest_rate_model_address = new_model_address;
        
        // Emit update event
        let update_event = ContractUpdatedEvent {
            contract_type: b"interest_rate_model",
            old_address,
            new_address: new_model_address,
            updated_by: signer::address_of(admin),
        };
        event::emit(update_event);
    }

    /// Transfer admin privileges (current admin only)
    public fun transfer_admin(admin: &signer, new_admin: address) acquires LoanManager {
        verify_admin(admin);
        
        let loan_manager = borrow_global_mut<LoanManager>(@btc_lending_platform);
        let old_admin = loan_manager.admin_address;
        loan_manager.admin_address = new_admin;
        
        // Emit admin transfer event
        let admin_event = AdminUpdatedEvent {
            old_admin,
            new_admin,
        };
        event::emit(admin_event);
    }

    /// Pause the system (admin only)
    public fun pause_system(admin: &signer) acquires LoanManager {
        verify_admin(admin);
        
        let loan_manager = borrow_global_mut<LoanManager>(@btc_lending_platform);
        loan_manager.is_paused = true;
        
        // Emit pause event
        let pause_event = PauseStateChangedEvent {
            is_paused: true,
            changed_by: signer::address_of(admin),
        };
        event::emit(pause_event);
    }

    /// Unpause the system (admin only)
    public fun unpause_system(admin: &signer) acquires LoanManager {
        verify_admin(admin);
        
        let loan_manager = borrow_global_mut<LoanManager>(@btc_lending_platform);
        loan_manager.is_paused = false;
        
        // Emit unpause event
        let unpause_event = PauseStateChangedEvent {
            is_paused: false,
            changed_by: signer::address_of(admin),
        };
        event::emit(unpause_event);
    }

    /// Check if system is paused
    public fun is_paused(): bool acquires LoanManager {
        let loan_manager = borrow_global<LoanManager>(@btc_lending_platform);
        loan_manager.is_paused
    }

    /// Get current admin address
    public fun get_admin(): address acquires LoanManager {
        let loan_manager = borrow_global<LoanManager>(@btc_lending_platform);
        loan_manager.admin_address
    }

    /// Get current CollateralVault address
    public fun get_collateral_vault_address(): address acquires LoanManager {
        let loan_manager = borrow_global<LoanManager>(@btc_lending_platform);
        loan_manager.collateral_vault_address
    }

    /// Get current InterestRateModel address
    public fun get_interest_rate_model_address(): address acquires LoanManager {
        let loan_manager = borrow_global<LoanManager>(@btc_lending_platform);
        loan_manager.interest_rate_model_address
    }


    #[test(admin = @btc_lending_platform)]
    public fun test_initialize(admin: &signer) acquires LoanManager {
        let collateral_vault = @0x123;
        let interest_rate_model = @0x456;
        let admin_address = initialize(admin, collateral_vault, interest_rate_model);
        
        // Verify initialization
        assert!(exists<LoanManager>(admin_address), 1);
        assert!(admin_address == signer::address_of(admin), 2);
        
        // Verify initial state
        let loan_manager = borrow_global<LoanManager>(@btc_lending_platform);
        assert!(loan_manager.next_loan_id == 1, 3);
        assert!(loan_manager.total_active_loans == 0, 4);
        assert!(loan_manager.total_outstanding_debt == 0, 5);
        assert!(loan_manager.collateral_vault_address == collateral_vault, 6);
        assert!(loan_manager.interest_rate_model_address == interest_rate_model, 7);
        assert!(loan_manager.admin_address == admin_address, 8);
        assert!(!loan_manager.is_paused, 9);
    }

    #[test(admin = @btc_lending_platform)]
    #[expected_failure(abort_code = 0x80007, location = Self)]
    public fun test_initialize_twice_fails(admin: &signer) {
        let collateral_vault = @0x123;
        let interest_rate_model = @0x456;
        initialize(admin, collateral_vault, interest_rate_model);
        initialize(admin, collateral_vault, interest_rate_model); // Should fail
    }

    #[test(admin = @btc_lending_platform)]
    public fun test_helper_functions(admin: &signer) acquires LoanManager {
        let collateral_vault = @0x123;
        let interest_rate_model = @0x456;
        initialize(admin, collateral_vault, interest_rate_model);
        
        // Test amount validation
        validate_amount(1);
        validate_amount(1000);
        validate_amount(18446744073709551615); // Max u64
        
        // Test LTV validation
        validate_ltv_ratio(1);
        validate_ltv_ratio(30);
        validate_ltv_ratio(60);
        
        // Test LTV calculation
        assert!(calculate_ltv_ratio(30, 100) == 30, 1);
        assert!(calculate_ltv_ratio(60, 100) == 60, 2);
        assert!(calculate_ltv_ratio(1, 2) == 50, 3);
        
        // Test loan ID generation
        assert!(get_next_loan_id() == 1, 4);
        assert!(get_next_loan_id() == 2, 5);
        assert!(get_next_loan_id() == 3, 6);
        
        // Test loan existence (should be false for non-existent loans)
        assert!(!loan_exists(1), 7);
        assert!(!loan_exists(999), 8);
        
        // Test system not paused
        check_not_paused();
        
        // Test admin verification
        verify_admin(admin);
    }

    #[test(admin = @btc_lending_platform)]
    public fun test_borrower_loan_management(admin: &signer) acquires LoanManager {
        let collateral_vault = @0x123;
        let interest_rate_model = @0x456;
        initialize(admin, collateral_vault, interest_rate_model);
        
        let borrower1 = @0x111;
        let borrower2 = @0x222;
        
        // Add loans to borrowers
        add_loan_to_borrower(borrower1, 1);
        add_loan_to_borrower(borrower1, 2);
        add_loan_to_borrower(borrower2, 3);
        
        // Verify borrower loan lists
        let loan_manager = borrow_global<LoanManager>(@btc_lending_platform);
        
        let borrower1_loans = table::borrow(&loan_manager.borrower_loans, borrower1);
        assert!(vector::length(borrower1_loans) == 2, 1);
        assert!(*vector::borrow(borrower1_loans, 0) == 1, 2);
        assert!(*vector::borrow(borrower1_loans, 1) == 2, 3);
        
        let borrower2_loans = table::borrow(&loan_manager.borrower_loans, borrower2);
        assert!(vector::length(borrower2_loans) == 1, 4);
        assert!(*vector::borrow(borrower2_loans, 0) == 3, 5);
    }

    #[test(admin = @btc_lending_platform)]
    public fun test_system_stats_management(admin: &signer) acquires LoanManager {
        let collateral_vault = @0x123;
        let interest_rate_model = @0x456;
        initialize(admin, collateral_vault, interest_rate_model);
        
        // Test increasing stats
        update_system_stats(1, 1000, true);
        update_system_stats(2, 2000, true);
        
        let loan_manager = borrow_global<LoanManager>(@btc_lending_platform);
        assert!(loan_manager.total_active_loans == 3, 1);
        assert!(loan_manager.total_outstanding_debt == 3000, 2);
        
        // Test decreasing stats
        update_system_stats(1, 500, false);
        
        let loan_manager = borrow_global<LoanManager>(@btc_lending_platform);
        assert!(loan_manager.total_active_loans == 2, 3);
        assert!(loan_manager.total_outstanding_debt == 2500, 4);
    }

    #[test(admin = @btc_lending_platform)]
    #[expected_failure(abort_code = 0x10002, location = Self)]
    public fun test_validate_zero_amount_fails(admin: &signer) {
        let collateral_vault = @0x123;
        let interest_rate_model = @0x456;
        initialize(admin, collateral_vault, interest_rate_model);
        
        validate_amount(0); // Should fail
    }

    #[test(admin = @btc_lending_platform)]
    #[expected_failure(abort_code = 0x10006, location = Self)]
    public fun test_validate_invalid_ltv_fails(admin: &signer) {
        let collateral_vault = @0x123;
        let interest_rate_model = @0x456;
        initialize(admin, collateral_vault, interest_rate_model);
        
        validate_ltv_ratio(61); // Should fail (over 60%)
    }

    #[test(admin = @btc_lending_platform)]
    #[expected_failure(abort_code = 0x10006, location = Self)]
    public fun test_validate_zero_ltv_fails(admin: &signer) {
        let collateral_vault = @0x123;
        let interest_rate_model = @0x456;
        initialize(admin, collateral_vault, interest_rate_model);
        
        validate_ltv_ratio(0); // Should fail
    }

    #[test(admin = @btc_lending_platform, non_admin = @0x999)]
    #[expected_failure(abort_code = 0x50001, location = Self)]
    public fun test_verify_admin_fails_for_non_admin(admin: &signer, non_admin: &signer) acquires LoanManager {
        account::create_account_for_test(signer::address_of(non_admin));
        
        let collateral_vault = @0x123;
        let interest_rate_model = @0x456;
        initialize(admin, collateral_vault, interest_rate_model);
        
        verify_admin(non_admin); // Should fail
    }

    #[test(admin = @btc_lending_platform)]
    #[expected_failure(abort_code = 0x60004, location = Self)]
    public fun test_verify_loan_ownership_fails_for_nonexistent_loan(admin: &signer) acquires LoanManager {
        let collateral_vault = @0x123;
        let interest_rate_model = @0x456;
        initialize(admin, collateral_vault, interest_rate_model);
        
        verify_loan_ownership(999, @0x111); // Should fail - loan doesn't exist
    }

    #[test(admin = @btc_lending_platform)]
    #[expected_failure(abort_code = 0x60004, location = Self)]
    public fun test_verify_loan_active_fails_for_nonexistent_loan(admin: &signer) acquires LoanManager {
        let collateral_vault = @0x123;
        let interest_rate_model = @0x456;
        initialize(admin, collateral_vault, interest_rate_model);
        
        verify_loan_active(999); // Should fail - loan doesn't exist
    }
}