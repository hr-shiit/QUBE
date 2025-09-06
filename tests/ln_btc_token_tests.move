#[test_only]
module btc_lending_platform::ln_btc_token_tests {
    use btc_lending_platform::ln_btc_token;
    use aptos_framework::account;
    use aptos_framework::fungible_asset;
    use std::signer;

    #[test(admin = @btc_lending_platform, loan_manager = @0x123, borrower1 = @0x456, borrower2 = @0x789)]
    public fun test_complete_loan_token_lifecycle(
        admin: &signer, 
        loan_manager: &signer, 
        borrower1: &signer, 
        borrower2: &signer
    ) {
        // Setup accounts
        account::create_account_for_test(signer::address_of(loan_manager));
        account::create_account_for_test(signer::address_of(borrower1));
        account::create_account_for_test(signer::address_of(borrower2));
        
        let loan_manager_address = signer::address_of(loan_manager);
        let borrower1_address = signer::address_of(borrower1);
        let borrower2_address = signer::address_of(borrower2);
        
        // Initialize token
        let _metadata = ln_btc_token::initialize(admin, loan_manager_address);
        
        // Verify initial state
        assert!(ln_btc_token::total_supply() == 0, 1);
        assert!(ln_btc_token::balance(loan_manager_address) == 0, 2);
        
        // Issue loans (mint tokens to borrowers)
        ln_btc_token::mint(loan_manager_address, borrower1_address, 5000); // 0.05 BTC loan
        ln_btc_token::mint(loan_manager_address, borrower2_address, 3000); // 0.03 BTC loan
        
        // Verify loan issuance
        assert!(ln_btc_token::total_supply() == 8000, 3);
        assert!(ln_btc_token::balance(borrower1_address) == 5000, 4);
        assert!(ln_btc_token::balance(borrower2_address) == 3000, 5);
        
        // Borrowers can transfer loan tokens
        ln_btc_token::transfer(borrower1, borrower2_address, 1000);
        
        // Verify transfer
        assert!(ln_btc_token::balance(borrower1_address) == 4000, 6);
        assert!(ln_btc_token::balance(borrower2_address) == 4000, 7);
        
        // Simulate loan repayment - borrower1 repays partial loan
        let repayment_tokens = ln_btc_token::withdraw(borrower1, 2000);
        ln_btc_token::burn(loan_manager_address, repayment_tokens);
        
        // Verify partial repayment
        assert!(ln_btc_token::balance(borrower1_address) == 2000, 8);
        assert!(ln_btc_token::total_supply() == 6000, 9);
        
        // Simulate full repayment - borrower2 repays entire remaining balance
        let full_repayment = ln_btc_token::withdraw(borrower2, 4000);
        ln_btc_token::burn(loan_manager_address, full_repayment);
        
        // Verify full repayment
        assert!(ln_btc_token::balance(borrower2_address) == 0, 10);
        assert!(ln_btc_token::total_supply() == 2000, 11); // Only borrower1's remaining debt
    }

    #[test(admin = @btc_lending_platform, loan_manager = @0x123, attacker = @0x999)]
    #[expected_failure(abort_code = 0x50001, location = btc_lending_platform::ln_btc_token)]
    public fun test_unauthorized_mint_fails(admin: &signer, loan_manager: &signer, attacker: &signer) {
        account::create_account_for_test(signer::address_of(loan_manager));
        account::create_account_for_test(signer::address_of(attacker));
        
        let loan_manager_address = signer::address_of(loan_manager);
        let attacker_address = signer::address_of(attacker);
        
        ln_btc_token::initialize(admin, loan_manager_address);
        
        // Attacker tries to mint tokens - should fail
        ln_btc_token::mint(attacker_address, attacker_address, 1000);
    }

    #[test(admin = @btc_lending_platform, loan_manager = @0x123, attacker = @0x999)]
    #[expected_failure(abort_code = 0x50001, location = btc_lending_platform::ln_btc_token)]
    public fun test_unauthorized_burn_fails(admin: &signer, loan_manager: &signer, attacker: &signer) {
        account::create_account_for_test(signer::address_of(loan_manager));
        account::create_account_for_test(signer::address_of(attacker));
        
        let loan_manager_address = signer::address_of(loan_manager);
        let attacker_address = signer::address_of(attacker);
        
        ln_btc_token::initialize(admin, loan_manager_address);
        
        // Mint some tokens first
        ln_btc_token::mint(loan_manager_address, loan_manager_address, 1000);
        
        // Get tokens to burn
        let tokens = ln_btc_token::withdraw(loan_manager, 500);
        
        // Attacker tries to burn tokens - should fail
        ln_btc_token::burn(attacker_address, tokens);
    }

    #[test(admin = @btc_lending_platform)]
    public fun test_loan_manager_address_update(admin: &signer) {
        let old_loan_manager = @0x123;
        let new_loan_manager = @0x456;
        
        ln_btc_token::initialize(admin, old_loan_manager);
        
        // Update loan manager address
        ln_btc_token::update_loan_manager_address(admin, new_loan_manager);
        
        // Test that new loan manager can mint
        account::create_account_for_test(new_loan_manager);
        ln_btc_token::mint(new_loan_manager, new_loan_manager, 1000);
        assert!(ln_btc_token::balance(new_loan_manager) == 1000, 1);
    }

    #[test(admin = @btc_lending_platform, non_admin = @0x999)]
    #[expected_failure(abort_code = 0x50001, location = btc_lending_platform::ln_btc_token)]
    public fun test_unauthorized_loan_manager_update_fails(admin: &signer, non_admin: &signer) {
        let loan_manager_address = @0x123;
        let new_loan_manager = @0x456;
        
        ln_btc_token::initialize(admin, loan_manager_address);
        
        // Non-admin tries to update loan manager address - should fail
        ln_btc_token::update_loan_manager_address(non_admin, new_loan_manager);
    }

    #[test(admin = @btc_lending_platform, loan_manager = @0x123)]
    public fun test_metadata_properties(admin: &signer, loan_manager: &signer) {
        let loan_manager_address = signer::address_of(loan_manager);
        let metadata = ln_btc_token::initialize(admin, loan_manager_address);
        
        // Verify token properties
        assert!(fungible_asset::name(metadata) == std::string::utf8(b"Loan BTC"), 1);
        assert!(fungible_asset::symbol(metadata) == std::string::utf8(b"lnBTC"), 2);
        assert!(fungible_asset::decimals(metadata) == 8, 3);
    }

    #[test(admin = @btc_lending_platform, loan_manager = @0x123, borrower = @0x456)]
    #[expected_failure(abort_code = 0x10002, location = btc_lending_platform::ln_btc_token)]
    public fun test_zero_transfer_fails(admin: &signer, loan_manager: &signer, borrower: &signer) {
        account::create_account_for_test(signer::address_of(loan_manager));
        account::create_account_for_test(signer::address_of(borrower));
        
        let loan_manager_address = signer::address_of(loan_manager);
        let borrower_address = signer::address_of(borrower);
        
        ln_btc_token::initialize(admin, loan_manager_address);
        
        // Try to transfer zero amount - should fail
        ln_btc_token::transfer(loan_manager, borrower_address, 0);
    }

    #[test(admin = @btc_lending_platform, loan_manager = @0x123, borrower = @0x456)]
    #[expected_failure(abort_code = 0x10002, location = btc_lending_platform::ln_btc_token)]
    public fun test_zero_withdraw_fails(admin: &signer, loan_manager: &signer, borrower: &signer) {
        account::create_account_for_test(signer::address_of(loan_manager));
        account::create_account_for_test(signer::address_of(borrower));
        
        let loan_manager_address = signer::address_of(loan_manager);
        let borrower_address = signer::address_of(borrower);
        
        ln_btc_token::initialize(admin, loan_manager_address);
        
        // Mint some tokens first
        ln_btc_token::mint(loan_manager_address, borrower_address, 1000);
        
        // Try to withdraw zero amount - should fail
        let _tokens = ln_btc_token::withdraw(borrower, 0);
        // This line should never be reached due to the expected failure
        ln_btc_token::burn(loan_manager_address, _tokens);
    }

    #[test(admin = @btc_lending_platform, loan_manager = @0x123)]
    public fun test_large_loan_amounts(admin: &signer, loan_manager: &signer) {
        account::create_account_for_test(signer::address_of(loan_manager));
        
        let loan_manager_address = signer::address_of(loan_manager);
        ln_btc_token::initialize(admin, loan_manager_address);
        
        // Test with large loan amounts (1000 BTC = 1e11 satoshis)
        let large_loan = 100000000000u64; // 1000 BTC in satoshis
        
        ln_btc_token::mint(loan_manager_address, loan_manager_address, large_loan);
        assert!(ln_btc_token::balance(loan_manager_address) == large_loan, 1);
        assert!(ln_btc_token::total_supply() == (large_loan as u128), 2);
    }

    #[test(admin = @btc_lending_platform, loan_manager = @0x123)]
    public fun test_precision_handling(admin: &signer, loan_manager: &signer) {
        account::create_account_for_test(signer::address_of(loan_manager));
        
        let loan_manager_address = signer::address_of(loan_manager);
        ln_btc_token::initialize(admin, loan_manager_address);
        
        // Test with 1 satoshi (smallest loan unit)
        ln_btc_token::mint(loan_manager_address, loan_manager_address, 1);
        assert!(ln_btc_token::balance(loan_manager_address) == 1, 1);
        
        // Test with fractional BTC amounts
        ln_btc_token::mint(loan_manager_address, loan_manager_address, 12345678); // 0.12345678 BTC
        assert!(ln_btc_token::balance(loan_manager_address) == 12345679, 2);
    }

    #[test(admin = @btc_lending_platform, loan_manager = @0x123, borrower1 = @0x456, borrower2 = @0x789, borrower3 = @0xabc)]
    public fun test_multiple_concurrent_loans(
        admin: &signer, 
        loan_manager: &signer, 
        borrower1: &signer, 
        borrower2: &signer,
        borrower3: &signer
    ) {
        // Setup accounts
        account::create_account_for_test(signer::address_of(loan_manager));
        account::create_account_for_test(signer::address_of(borrower1));
        account::create_account_for_test(signer::address_of(borrower2));
        account::create_account_for_test(signer::address_of(borrower3));
        
        let loan_manager_address = signer::address_of(loan_manager);
        let borrower1_address = signer::address_of(borrower1);
        let borrower2_address = signer::address_of(borrower2);
        let borrower3_address = signer::address_of(borrower3);
        
        ln_btc_token::initialize(admin, loan_manager_address);
        
        // Issue multiple loans simultaneously
        ln_btc_token::mint(loan_manager_address, borrower1_address, 100000000); // 1 BTC
        ln_btc_token::mint(loan_manager_address, borrower2_address, 50000000);  // 0.5 BTC
        ln_btc_token::mint(loan_manager_address, borrower3_address, 25000000);  // 0.25 BTC
        
        // Verify all loans issued correctly
        assert!(ln_btc_token::balance(borrower1_address) == 100000000, 1);
        assert!(ln_btc_token::balance(borrower2_address) == 50000000, 2);
        assert!(ln_btc_token::balance(borrower3_address) == 25000000, 3);
        assert!(ln_btc_token::total_supply() == 175000000, 4);
        
        // Simulate partial repayments
        let repayment1 = ln_btc_token::withdraw(borrower1, 30000000); // 0.3 BTC
        let repayment2 = ln_btc_token::withdraw(borrower2, 20000000); // 0.2 BTC
        
        ln_btc_token::burn(loan_manager_address, repayment1);
        ln_btc_token::burn(loan_manager_address, repayment2);
        
        // Verify partial repayments
        assert!(ln_btc_token::balance(borrower1_address) == 70000000, 5);  // 0.7 BTC remaining
        assert!(ln_btc_token::balance(borrower2_address) == 30000000, 6);  // 0.3 BTC remaining
        assert!(ln_btc_token::balance(borrower3_address) == 25000000, 7);  // 0.25 BTC unchanged
        assert!(ln_btc_token::total_supply() == 125000000, 8); // Total reduced by repayments
        
        // Borrower3 transfers some tokens to borrower1
        ln_btc_token::transfer(borrower3, borrower1_address, 10000000); // 0.1 BTC
        
        // Verify transfer
        assert!(ln_btc_token::balance(borrower1_address) == 80000000, 9);   // 0.8 BTC
        assert!(ln_btc_token::balance(borrower3_address) == 15000000, 10);  // 0.15 BTC
        assert!(ln_btc_token::total_supply() == 125000000, 11); // Total unchanged by transfer
    }

    #[test(admin = @btc_lending_platform, loan_manager = @0x123, borrower = @0x456)]
    public fun test_full_loan_cycle(admin: &signer, loan_manager: &signer, borrower: &signer) {
        account::create_account_for_test(signer::address_of(loan_manager));
        account::create_account_for_test(signer::address_of(borrower));
        
        let loan_manager_address = signer::address_of(loan_manager);
        let borrower_address = signer::address_of(borrower);
        
        ln_btc_token::initialize(admin, loan_manager_address);
        
        // Issue loan
        let loan_amount = 50000000u64; // 0.5 BTC
        ln_btc_token::mint(loan_manager_address, borrower_address, loan_amount);
        
        // Verify loan issuance
        assert!(ln_btc_token::balance(borrower_address) == loan_amount, 1);
        assert!(ln_btc_token::total_supply() == (loan_amount as u128), 2);
        
        // Borrower uses loan tokens (transfers to another address)
        let recipient = @0x999;
        account::create_account_for_test(recipient);
        ln_btc_token::transfer(borrower, recipient, 20000000); // Use 0.2 BTC
        
        // Verify loan usage
        assert!(ln_btc_token::balance(borrower_address) == 30000000, 3);
        assert!(ln_btc_token::balance(recipient) == 20000000, 4);
        
        // Full repayment - borrower prepares for repayment
        let repayment_from_borrower = ln_btc_token::withdraw(borrower, 30000000);
        
        // Get tokens from recipient for full repayment
        let recipient_signer = account::create_signer_for_test(recipient);
        let repayment_from_recipient = ln_btc_token::withdraw(&recipient_signer, 20000000);
        
        // Burn all repayment tokens
        ln_btc_token::burn(loan_manager_address, repayment_from_borrower);
        ln_btc_token::burn(loan_manager_address, repayment_from_recipient);
        
        // Verify full repayment
        assert!(ln_btc_token::balance(borrower_address) == 0, 5);
        assert!(ln_btc_token::balance(recipient) == 0, 6);
        assert!(ln_btc_token::total_supply() == 0, 7);
    }
}