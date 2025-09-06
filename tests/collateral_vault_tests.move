#[test_only]
module btc_lending_platform::collateral_vault_tests {
    use btc_lending_platform::collateral_vault;
    use aptos_framework::account;
    use std::signer;

    #[test(admin = @btc_lending_platform, loan_manager = @0x123)]
    public fun test_initialize_success(admin: &signer, loan_manager: &signer) {
        let loan_manager_address = signer::address_of(loan_manager);
        account::create_account_for_test(loan_manager_address);
        
        let admin_address = collateral_vault::initialize(admin, loan_manager_address);
        
        // Verify initialization returns admin address
        assert!(admin_address == signer::address_of(admin), 1);
    }

    #[test(admin = @btc_lending_platform, loan_manager = @0x123)]
    #[expected_failure(abort_code = 0x80005, location = btc_lending_platform::collateral_vault)]
    public fun test_initialize_twice_fails(admin: &signer, loan_manager: &signer) {
        let loan_manager_address = signer::address_of(loan_manager);
        account::create_account_for_test(loan_manager_address);
        
        collateral_vault::initialize(admin, loan_manager_address);
        
        // Try to initialize again - should fail
        collateral_vault::initialize(admin, loan_manager_address);
    }


}
