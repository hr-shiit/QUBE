/// InterestRateModel Contract
/// Manages interest rates based on Loan-to-Value (LTV) ratios
/// Provides rate queries for the LoanManager contract
module btc_lending_platform::interest_rate_model {
    use aptos_framework::table::{Self, Table};
    use std::error;
    use std::signer;
    use std::vector;

    /// Error codes
    const E_NOT_AUTHORIZED: u64 = 1;
    const E_ALREADY_INITIALIZED: u64 = 2;
    const E_INVALID_LTV: u64 = 3;
    const E_INVALID_RATE: u64 = 4;
    const E_RATE_NOT_FOUND: u64 = 5;

    /// Maximum LTV ratio allowed (60%)
    const MAX_LTV_RATIO: u64 = 60;
    
    /// Maximum interest rate allowed (50% = 5000 basis points)
    const MAX_INTEREST_RATE: u64 = 5000;

    /// Interest rate model storage
    struct InterestRateModel has key {
        /// Mapping from LTV ratio to interest rate (in basis points)
        /// Example: 30 -> 500 means 30% LTV has 5% interest rate
        rate_table: Table<u64, u64>,
        /// Admin address that can update rates
        admin: address,
    }

    /// Initialize the InterestRateModel with default rates
    /// Can only be called once during deployment
    public fun initialize(admin: &signer): address {
        let admin_address = signer::address_of(admin);
        
        // Ensure this hasn't been initialized before
        assert!(!exists<InterestRateModel>(admin_address), error::already_exists(E_ALREADY_INITIALIZED));

        // Create the rate table with default values
        let rate_table = table::new<u64, u64>();
        
        // Set default rates as specified in requirements
        table::add(&mut rate_table, 30, 500);  // 30% LTV -> 5% interest (500 basis points)
        table::add(&mut rate_table, 45, 800);  // 45% LTV -> 8% interest (800 basis points)
        table::add(&mut rate_table, 60, 1000); // 60% LTV -> 10% interest (1000 basis points)

        // Store the interest rate model
        let model = InterestRateModel {
            rate_table,
            admin: admin_address,
        };

        move_to(admin, model);
        admin_address
    }

    /// Set interest rate for a specific LTV ratio (admin only)
    public fun set_rate(admin: &signer, ltv_ratio: u64, rate_basis_points: u64) acquires InterestRateModel {
        let admin_address = signer::address_of(admin);
        let model = borrow_global_mut<InterestRateModel>(@btc_lending_platform);
        
        // Verify admin authorization
        assert!(admin_address == model.admin, error::permission_denied(E_NOT_AUTHORIZED));
        
        // Validate LTV ratio
        assert!(ltv_ratio > 0 && ltv_ratio <= MAX_LTV_RATIO, error::invalid_argument(E_INVALID_LTV));
        
        // Validate interest rate
        assert!(rate_basis_points <= MAX_INTEREST_RATE, error::invalid_argument(E_INVALID_RATE));

        // Update or add the rate
        if (table::contains(&model.rate_table, ltv_ratio)) {
            *table::borrow_mut(&mut model.rate_table, ltv_ratio) = rate_basis_points;
        } else {
            table::add(&mut model.rate_table, ltv_ratio, rate_basis_points);
        };
    }

    /// Get interest rate for a specific LTV ratio
    public fun get_rate(ltv_ratio: u64): u64 acquires InterestRateModel {
        let model = borrow_global<InterestRateModel>(@btc_lending_platform);
        
        // Validate LTV ratio
        assert!(ltv_ratio > 0 && ltv_ratio <= MAX_LTV_RATIO, error::invalid_argument(E_INVALID_LTV));

        // Check if exact rate exists
        if (table::contains(&model.rate_table, ltv_ratio)) {
            return *table::borrow(&model.rate_table, ltv_ratio)
        };

        // If exact rate doesn't exist, find the nearest higher LTV rate
        // This ensures conservative pricing for intermediate LTV ratios
        let nearest_rate = find_nearest_rate(&model.rate_table, ltv_ratio);
        assert!(nearest_rate > 0, error::not_found(E_RATE_NOT_FOUND));
        
        nearest_rate
    }

    /// Get all LTV ratios that have defined rates
    public fun get_all_ltv_ratios(): vector<u64> acquires InterestRateModel {
        let model = borrow_global<InterestRateModel>(@btc_lending_platform);
        let ltvs = vector::empty<u64>();
        
        // Check common LTV ratios and add those that exist
        let possible_ltvs = vector[10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60];
        let i = 0;
        let len = vector::length(&possible_ltvs);
        
        while (i < len) {
            let ltv = *vector::borrow(&possible_ltvs, i);
            if (table::contains(&model.rate_table, ltv)) {
                vector::push_back(&mut ltvs, ltv);
            };
            i = i + 1;
        };
        
        ltvs
    }

    /// Remove a rate for a specific LTV ratio (admin only)
    public fun remove_rate(admin: &signer, ltv_ratio: u64) acquires InterestRateModel {
        let admin_address = signer::address_of(admin);
        let model = borrow_global_mut<InterestRateModel>(@btc_lending_platform);
        
        // Verify admin authorization
        assert!(admin_address == model.admin, error::permission_denied(E_NOT_AUTHORIZED));
        
        // Validate LTV ratio
        assert!(ltv_ratio > 0 && ltv_ratio <= MAX_LTV_RATIO, error::invalid_argument(E_INVALID_LTV));
        
        // Remove the rate if it exists
        if (table::contains(&model.rate_table, ltv_ratio)) {
            table::remove(&mut model.rate_table, ltv_ratio);
        };
    }

    /// Update admin address (current admin only)
    public fun update_admin(current_admin: &signer, new_admin: address) acquires InterestRateModel {
        let current_admin_address = signer::address_of(current_admin);
        let model = borrow_global_mut<InterestRateModel>(@btc_lending_platform);
        
        // Verify current admin authorization
        assert!(current_admin_address == model.admin, error::permission_denied(E_NOT_AUTHORIZED));
        
        // Update admin address
        model.admin = new_admin;
    }

    /// Get current admin address
    public fun get_admin(): address acquires InterestRateModel {
        let model = borrow_global<InterestRateModel>(@btc_lending_platform);
        model.admin
    }

    /// Check if a rate exists for a specific LTV ratio
    public fun has_rate(ltv_ratio: u64): bool acquires InterestRateModel {
        let model = borrow_global<InterestRateModel>(@btc_lending_platform);
        table::contains(&model.rate_table, ltv_ratio)
    }

    /// Helper function to find the nearest rate for a given LTV ratio
    /// Returns the rate for the nearest higher LTV ratio
    fun find_nearest_rate(rate_table: &Table<u64, u64>, target_ltv: u64): u64 {
        // Check common LTV ratios in ascending order
        let ltv_options = vector[30, 45, 60];
        let i = 0;
        let len = vector::length(&ltv_options);
        
        while (i < len) {
            let ltv = *vector::borrow(&ltv_options, i);
            if (ltv >= target_ltv && table::contains(rate_table, ltv)) {
                return *table::borrow(rate_table, ltv)
            };
            i = i + 1;
        };
        
        // If no suitable rate found, return 0 (will cause error in caller)
        0
    }

    #[test_only]
    use aptos_framework::account;

    #[test(admin = @btc_lending_platform)]
    public fun test_initialize(admin: &signer) acquires InterestRateModel {
        let admin_address = initialize(admin);
        
        // Verify initialization
        assert!(exists<InterestRateModel>(admin_address), 1);
        assert!(get_admin() == admin_address, 2);
        
        // Verify default rates
        assert!(get_rate(30) == 500, 3);  // 5%
        assert!(get_rate(45) == 800, 4);  // 8%
        assert!(get_rate(60) == 1000, 5); // 10%
    }

    #[test(admin = @btc_lending_platform)]
    #[expected_failure(abort_code = 0x80002, location = Self)]
    public fun test_initialize_twice_fails(admin: &signer) {
        initialize(admin);
        initialize(admin); // Should fail
    }

    #[test(admin = @btc_lending_platform)]
    public fun test_set_rate_authorized(admin: &signer) acquires InterestRateModel {
        initialize(admin);
        
        // Set new rate
        set_rate(admin, 40, 650); // 40% LTV -> 6.5% interest
        
        // Verify rate was set
        assert!(get_rate(40) == 650, 1);
        assert!(has_rate(40) == true, 2);
    }

    #[test(admin = @btc_lending_platform, unauthorized = @0x456)]
    #[expected_failure(abort_code = 0x50001, location = Self)]
    public fun test_set_rate_unauthorized_fails(admin: &signer, unauthorized: &signer) acquires InterestRateModel {
        initialize(admin);
        
        // Unauthorized user tries to set rate - should fail
        set_rate(unauthorized, 40, 650);
    }

    #[test(admin = @btc_lending_platform)]
    #[expected_failure(abort_code = 0x10003, location = Self)]
    public fun test_invalid_ltv_fails(admin: &signer) acquires InterestRateModel {
        initialize(admin);
        
        // Try to set rate for invalid LTV (over 60%) - should fail
        set_rate(admin, 70, 1200);
    }

    #[test(admin = @btc_lending_platform)]
    #[expected_failure(abort_code = 0x10004, location = Self)]
    public fun test_invalid_rate_fails(admin: &signer) acquires InterestRateModel {
        initialize(admin);
        
        // Try to set rate over maximum (50%) - should fail
        set_rate(admin, 30, 6000); // 60% interest rate
    }

    #[test(admin = @btc_lending_platform)]
    public fun test_get_rate_interpolation(admin: &signer) acquires InterestRateModel {
        initialize(admin);
        
        // Test getting rate for LTV between defined values
        // Should return the rate for the next higher LTV
        assert!(get_rate(35) == 800, 1); // Should use 45% LTV rate
        assert!(get_rate(50) == 1000, 2); // Should use 60% LTV rate
        assert!(get_rate(25) == 500, 3); // Should use 30% LTV rate
    }

    #[test(admin = @btc_lending_platform)]
    public fun test_get_all_ltv_ratios(admin: &signer) acquires InterestRateModel {
        initialize(admin);
        
        let ltvs = get_all_ltv_ratios();
        assert!(vector::length(&ltvs) == 3, 1);
        
        // Verify default LTV ratios are present
        assert!(vector::contains(&ltvs, &30), 2);
        assert!(vector::contains(&ltvs, &45), 3);
        assert!(vector::contains(&ltvs, &60), 4);
    }

    #[test(admin = @btc_lending_platform)]
    public fun test_remove_rate(admin: &signer) acquires InterestRateModel {
        initialize(admin);
        
        // Remove a rate
        remove_rate(admin, 45);
        
        // Verify rate was removed
        assert!(has_rate(45) == false, 1);
        
        // Verify other rates still exist
        assert!(has_rate(30) == true, 2);
        assert!(has_rate(60) == true, 3);
    }

    #[test(admin = @btc_lending_platform)]
    public fun test_update_admin(admin: &signer) acquires InterestRateModel {
        initialize(admin);
        
        let new_admin = @0x999;
        update_admin(admin, new_admin);
        
        // Verify admin was updated
        assert!(get_admin() == new_admin, 1);
    }

    #[test(admin = @btc_lending_platform, new_admin_signer = @0x999)]
    public fun test_new_admin_can_set_rates(admin: &signer, new_admin_signer: &signer) acquires InterestRateModel {
        account::create_account_for_test(signer::address_of(new_admin_signer));
        
        initialize(admin);
        
        let new_admin = signer::address_of(new_admin_signer);
        update_admin(admin, new_admin);
        
        // New admin should be able to set rates
        set_rate(new_admin_signer, 35, 600);
        assert!(get_rate(35) == 600, 1);
    }
}