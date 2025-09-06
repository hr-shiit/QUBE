/// LoanManager Contract
/// Central orchestrator for the BTC lending platform managing complete loan lifecycle
/// Coordinates with CollateralVault, InterestRateModel, and token contracts
module btc_lending_platform::loan_manager {
    use aptos_std::table::{Self, Table};
    use std::error;
    use std::signer;
    use std::vector;

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
    struct LoanCreatedEvent has drop, store {
        loan_id: u64,
        borrower: address,
        collateral_amount: u64,
        loan_amount: u64,
        interest_rate: u64,
        ltv_ratio: u64,
    }

    /// Event emitted when a loan is repaid (full or partial)
    struct LoanRepaidEvent has drop, store {
        loan_id: u64,
        borrower: address,
        repayment_amount: u64,
        interest_paid: u64,
        remaining_balance: u64,
        is_full_repayment: bool,
    }

    /// Event emitted when collateral is unlocked
    struct CollateralUnlockedEvent has drop, store {
        loan_id: u64,
        borrower: address,
        unlocked_amount: u64,
        remaining_locked: u64,
    }

    /// Event emitted when loan state changes
    struct LoanStateChangedEvent has drop, store {
        loan_id: u64,
        borrower: address,
        old_state: u8,
        new_state: u8,
    }

    /// Event emitted when contract addresses are updated
    struct ContractUpdatedEvent has drop, store {
        contract_type: vector<u8>, // "collateral_vault" or "interest_rate_model"
        old_address: address,
        new_address: address,
        updated_by: address,
    }

    /// Event emitted when admin privileges are transferred
    struct AdminUpdatedEvent has drop, store {
        old_admin: address,
        new_admin: address,
    }

    /// Event emitted when system pause state changes
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

    #[test_only]
    use aptos_framework::account;

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