#[test_only]
module btc_lending_platform::ctrl_btc_token_tests {
    use btc_lending_platform::ctrl_btc_token;
    use aptos_framework::account;
    use aptos_framework::fungible_asset;
    use aptos_framework::primary_fungible_store;
    use std::signer;

    #[test(admin = @btc_lending_platform, vault = @0x123, user1 = @0x456, user2 = @0x789)]
    public fun test_complete_token_lifecycle(
        admin: &signer, 
        vault: &signer, 
        user1: &signer, 
        user2: &signer
    ) {
        // Setup accounts
        account::create_account_for_test(signer::address_of(vault));
        account::create_account_for_test(signer::address_of(user1));
        account::create_account_for_test(signer::address_of(user2));
        
        let vault_address = signer::address_of(vault);
        let user1_address = signer::address_of(user1);
        let user2_address = signer::address_of(user2);
        
        // Initialize token
        let metadata = ctrl_btc_token::initialize(admin, vault_address);
        
        // Verify initial state
        assert!(ctrl_btc_token::total_supply() == 0, 1);
        assert!(ctrl_btc_token::balance(vault_address) == 0, 2);
        
        // Mint tokens to vault
        ctrl_btc_token::mint(vault_address, vault_address, 10000);
        
        // Verify minting
        assert!(ctrl_btc_token::total_supply() == 10000, 3);
        assert!(ctrl_btc_token::balance(vault_address) == 10000, 4);
        
        // Transfer tokens to users
        ctrl_btc_token::transfer(vault, user1_address, 3000);
        ctrl_btc_token::transfer(vault, user2_address, 2000);
        
        // Verify transfers
        assert!(ctrl_btc_token::balance(vault_address) == 5000, 5);
        assert!(ctrl_btc_token::balance(user1_address) == 3000, 6);
        assert!(ctrl_btc_token::balance(user2_address) == 2000, 7);
        
        // Transfer between users
        ctrl_btc_token::transfer(user1, user2_address, 1000);
        
        // Verify user-to-user transfer
        assert!(ctrl_btc_token::balance(user1_address) == 2000, 8);
        assert!(ctrl_btc_token::balance(user2_address) == 3000, 9);
        
        // Burn some tokens
        let tokens_to_burn = primary_fungible_store::withdraw(user2, metadata, 1000);
        ctrl_btc_token::burn(vault_address, tokens_to_burn);
        
        // Verify burning
        assert!(ctrl_btc_token::total_supply() == 9000, 10);
        assert!(ctrl_btc_token::balance(user2_address) == 2000, 11);
    }

    #[test(admin = @btc_lending_platform, vault = @0x123, attacker = @0x999)]
    #[expected_failure(abort_code = 0x50001, location = btc_lending_platform::ctrl_btc_token)]
    public fun test_unauthorized_mint_fails(admin: &signer, vault: &signer, attacker: &signer) {
        account::create_account_for_test(signer::address_of(vault));
        account::create_account_for_test(signer::address_of(attacker));
        
        let vault_address = signer::address_of(vault);
        let attacker_address = signer::address_of(attacker);
        
        ctrl_btc_token::initialize(admin, vault_address);
        
        // Attacker tries to mint tokens - should fail
        ctrl_btc_token::mint(attacker_address, attacker_address, 1000);
    }

    #[test(admin = @btc_lending_platform, vault = @0x123, attacker = @0x999)]
    #[expected_failure(abort_code = 0x50001, location = btc_lending_platform::ctrl_btc_token)]
    public fun test_unauthorized_burn_fails(admin: &signer, vault: &signer, attacker: &signer) {
        account::create_account_for_test(signer::address_of(vault));
        account::create_account_for_test(signer::address_of(attacker));
        
        let vault_address = signer::address_of(vault);
        let attacker_address = signer::address_of(attacker);
        
        ctrl_btc_token::initialize(admin, vault_address);
        
        // Mint some tokens first
        ctrl_btc_token::mint(vault_address, vault_address, 1000);
        
        // Get tokens to burn
        let metadata = ctrl_btc_token::get_metadata();
        let tokens = primary_fungible_store::withdraw(vault, metadata, 500);
        
        // Attacker tries to burn tokens - should fail
        ctrl_btc_token::burn(attacker_address, tokens);
    }

    #[test(admin = @btc_lending_platform)]
    public fun test_vault_address_update(admin: &signer) {
        let old_vault = @0x123;
        let new_vault = @0x456;
        
        ctrl_btc_token::initialize(admin, old_vault);
        
        // Update vault address
        ctrl_btc_token::update_vault_address(admin, new_vault);
        
        // Test that new vault can mint (basic verification)
        account::create_account_for_test(new_vault);
        ctrl_btc_token::mint(new_vault, new_vault, 1000);
        assert!(ctrl_btc_token::balance(new_vault) == 1000, 1);
    }

    #[test(admin = @btc_lending_platform, non_admin = @0x999)]
    #[expected_failure(abort_code = 0x50001, location = btc_lending_platform::ctrl_btc_token)]
    public fun test_unauthorized_vault_update_fails(admin: &signer, non_admin: &signer) {
        let vault_address = @0x123;
        let new_vault = @0x456;
        
        ctrl_btc_token::initialize(admin, vault_address);
        
        // Non-admin tries to update vault address - should fail
        ctrl_btc_token::update_vault_address(non_admin, new_vault);
    }

    #[test(admin = @btc_lending_platform, vault = @0x123)]
    public fun test_metadata_properties(admin: &signer, vault: &signer) {
        let vault_address = signer::address_of(vault);
        let metadata = ctrl_btc_token::initialize(admin, vault_address);
        
        // Verify token properties
        assert!(fungible_asset::name(metadata) == std::string::utf8(b"Collateral BTC"), 1);
        assert!(fungible_asset::symbol(metadata) == std::string::utf8(b"ctrlBTC"), 2);
        assert!(fungible_asset::decimals(metadata) == 8, 3);
    }

    #[test(admin = @btc_lending_platform, vault = @0x123, user = @0x456)]
    #[expected_failure(abort_code = 0x10002, location = btc_lending_platform::ctrl_btc_token)]
    public fun test_zero_transfer_fails(admin: &signer, vault: &signer, user: &signer) {
        account::create_account_for_test(signer::address_of(vault));
        account::create_account_for_test(signer::address_of(user));
        
        let vault_address = signer::address_of(vault);
        let user_address = signer::address_of(user);
        
        ctrl_btc_token::initialize(admin, vault_address);
        
        // Try to transfer zero amount - should fail
        ctrl_btc_token::transfer(vault, user_address, 0);
    }

    #[test(admin = @btc_lending_platform, vault = @0x123)]
    public fun test_large_amounts(admin: &signer, vault: &signer) {
        account::create_account_for_test(signer::address_of(vault));
        
        let vault_address = signer::address_of(vault);
        ctrl_btc_token::initialize(admin, vault_address);
        
        // Test with large BTC amounts (21 million BTC = 2.1e15 satoshis)
        let large_amount = 2100000000000000u64; // 21M BTC in satoshis
        
        ctrl_btc_token::mint(vault_address, vault_address, large_amount);
        assert!(ctrl_btc_token::balance(vault_address) == large_amount, 1);
        assert!(ctrl_btc_token::total_supply() == (large_amount as u128), 2);
    }

    #[test(admin = @btc_lending_platform, vault = @0x123)]
    public fun test_precision_handling(admin: &signer, vault: &signer) {
        account::create_account_for_test(signer::address_of(vault));
        
        let vault_address = signer::address_of(vault);
        ctrl_btc_token::initialize(admin, vault_address);
        
        // Test with 1 satoshi (smallest BTC unit)
        ctrl_btc_token::mint(vault_address, vault_address, 1);
        assert!(ctrl_btc_token::balance(vault_address) == 1, 1);
        
        // Test with fractional BTC amounts
        ctrl_btc_token::mint(vault_address, vault_address, 50000000); // 0.5 BTC
        assert!(ctrl_btc_token::balance(vault_address) == 50000001, 2);
    }

    #[test(admin = @btc_lending_platform, vault = @0x123, user1 = @0x456, user2 = @0x789)]
    public fun test_concurrent_operations(admin: &signer, vault: &signer, user1: &signer, user2: &signer) {
        // Setup accounts
        account::create_account_for_test(signer::address_of(vault));
        account::create_account_for_test(signer::address_of(user1));
        account::create_account_for_test(signer::address_of(user2));
        
        let vault_address = signer::address_of(vault);
        let user1_address = signer::address_of(user1);
        let user2_address = signer::address_of(user2);
        
        ctrl_btc_token::initialize(admin, vault_address);
        
        // Mint large amount to vault
        ctrl_btc_token::mint(vault_address, vault_address, 1000000);
        
        // Simulate concurrent transfers
        ctrl_btc_token::transfer(vault, user1_address, 300000);
        ctrl_btc_token::transfer(vault, user2_address, 200000);
        
        // Cross transfers
        ctrl_btc_token::transfer(user1, user2_address, 50000);
        ctrl_btc_token::transfer(user2, user1_address, 25000);
        
        // Verify final balances
        assert!(ctrl_btc_token::balance(vault_address) == 500000, 1);
        assert!(ctrl_btc_token::balance(user1_address) == 275000, 2); // 300000 - 50000 + 25000
        assert!(ctrl_btc_token::balance(user2_address) == 225000, 3); // 200000 + 50000 - 25000
        
        // Verify total supply is conserved
        assert!(ctrl_btc_token::total_supply() == 1000000, 4);
    }
}