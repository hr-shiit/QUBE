/// lnBTC Token Contract
/// Represents loan BTC issued to borrowers in the lending system
/// Only the LoanManager module can mint/burn these tokens
module btc_lending_platform::ln_btc_token {
    use aptos_framework::fungible_asset::{Self, MintRef, TransferRef, BurnRef, FungibleAsset, Metadata};
    use aptos_framework::object::{Self, Object};
    use aptos_framework::primary_fungible_store;
    use std::error;
    use std::signer;
    use std::string::utf8;
    use std::option;

    /// Error codes
    const E_NOT_AUTHORIZED: u64 = 1;
    const E_INVALID_AMOUNT: u64 = 2;
    const E_ALREADY_INITIALIZED: u64 = 3;

    /// Token metadata and capabilities
    struct LnBTCToken has key {
        mint_ref: MintRef,
        transfer_ref: TransferRef,
        burn_ref: BurnRef,
        loan_manager_address: address,
    }

    /// Initialize the lnBTC token
    /// Can only be called once during deployment
    public fun initialize(admin: &signer, loan_manager_address: address): Object<Metadata> {
        // Ensure this hasn't been initialized before
        assert!(!exists<LnBTCToken>(signer::address_of(admin)), error::already_exists(E_ALREADY_INITIALIZED));

        // Create the fungible asset
        let constructor_ref = object::create_named_object(admin, b"LN_BTC");
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            &constructor_ref,
            option::none(),
            utf8(b"Loan BTC"), // name
            utf8(b"lnBTC"), // symbol
            8, // decimals (same as BTC)
            utf8(b"https://example.com/ln-btc-icon.png"), // icon_uri
            utf8(b"https://example.com/ln-btc"), // project_uri
        );

        // Generate the mint, transfer, and burn refs
        let mint_ref = fungible_asset::generate_mint_ref(&constructor_ref);
        let transfer_ref = fungible_asset::generate_transfer_ref(&constructor_ref);
        let burn_ref = fungible_asset::generate_burn_ref(&constructor_ref);

        // Store the capabilities
        let token_data = LnBTCToken {
            mint_ref,
            transfer_ref,
            burn_ref,
            loan_manager_address,
        };

        move_to(admin, token_data);

        object::object_from_constructor_ref<Metadata>(&constructor_ref)
    }

    /// Mint lnBTC tokens and deposit to recipient
    /// Can only be called by the LoanManager module
    public fun mint(caller: address, to: address, amount: u64) acquires LnBTCToken {
        assert!(amount > 0, error::invalid_argument(E_INVALID_AMOUNT));
        
        let token_data = borrow_global<LnBTCToken>(@btc_lending_platform);
        assert!(caller == token_data.loan_manager_address, error::permission_denied(E_NOT_AUTHORIZED));

        let tokens = fungible_asset::mint(&token_data.mint_ref, amount);
        primary_fungible_store::deposit(to, tokens);
    }

    /// Burn lnBTC tokens
    /// Can only be called by the LoanManager module
    public fun burn(caller: address, tokens: FungibleAsset) acquires LnBTCToken {
        let token_data = borrow_global<LnBTCToken>(@btc_lending_platform);
        assert!(caller == token_data.loan_manager_address, error::permission_denied(E_NOT_AUTHORIZED));

        fungible_asset::burn(&token_data.burn_ref, tokens);
    }

    /// Transfer lnBTC tokens (standard transfer)
    public fun transfer(from: &signer, to: address, amount: u64) acquires LnBTCToken {
        assert!(amount > 0, error::invalid_argument(E_INVALID_AMOUNT));
        
        let token_data = borrow_global<LnBTCToken>(@btc_lending_platform);
        let metadata = fungible_asset::mint_ref_metadata(&token_data.mint_ref);
        
        primary_fungible_store::transfer(from, metadata, to, amount);
    }

    /// Get balance of lnBTC tokens for an address
    public fun balance(account: address): u64 acquires LnBTCToken {
        let token_data = borrow_global<LnBTCToken>(@btc_lending_platform);
        let metadata = fungible_asset::mint_ref_metadata(&token_data.mint_ref);
        primary_fungible_store::balance(account, metadata)
    }

    /// Get the metadata object for lnBTC token
    public fun get_metadata(): Object<Metadata> acquires LnBTCToken {
        let token_data = borrow_global<LnBTCToken>(@btc_lending_platform);
        fungible_asset::mint_ref_metadata(&token_data.mint_ref)
    }

    /// Get total supply of lnBTC tokens
    public fun total_supply(): u128 acquires LnBTCToken {
        let token_data = borrow_global<LnBTCToken>(@btc_lending_platform);
        let metadata = fungible_asset::mint_ref_metadata(&token_data.mint_ref);
        option::extract(&mut fungible_asset::supply(metadata))
    }

    /// Update the authorized LoanManager address (admin only)
    public fun update_loan_manager_address(admin: &signer, new_loan_manager_address: address) acquires LnBTCToken {
        assert!(signer::address_of(admin) == @btc_lending_platform, error::permission_denied(E_NOT_AUTHORIZED));
        
        let token_data = borrow_global_mut<LnBTCToken>(@btc_lending_platform);
        token_data.loan_manager_address = new_loan_manager_address;
    }

    /// Withdraw lnBTC tokens from primary store (helper function for burning)
    public fun withdraw(account: &signer, amount: u64): FungibleAsset acquires LnBTCToken {
        assert!(amount > 0, error::invalid_argument(E_INVALID_AMOUNT));
        
        let token_data = borrow_global<LnBTCToken>(@btc_lending_platform);
        let metadata = fungible_asset::mint_ref_metadata(&token_data.mint_ref);
        
        primary_fungible_store::withdraw(account, metadata, amount)
    }

    #[test_only]
    use aptos_framework::account;

    #[test(admin = @btc_lending_platform)]
    public fun test_initialize(admin: &signer) {
        let loan_manager_address = @0x123;
        let metadata = initialize(admin, loan_manager_address);
        
        // Verify token was created
        assert!(exists<LnBTCToken>(signer::address_of(admin)), 1);
        
        // Verify metadata
        let name = fungible_asset::name(metadata);
        assert!(name == utf8(b"Loan BTC"), 2);
        
        let symbol = fungible_asset::symbol(metadata);
        assert!(symbol == utf8(b"lnBTC"), 3);
    }

    #[test(admin = @btc_lending_platform)]
    #[expected_failure(abort_code = 0x80003, location = Self)]
    public fun test_initialize_twice_fails(admin: &signer) {
        let loan_manager_address = @0x123;
        initialize(admin, loan_manager_address);
        initialize(admin, loan_manager_address); // Should fail
    }

    #[test(admin = @btc_lending_platform, loan_manager = @0x123)]
    public fun test_mint_authorized(admin: &signer, loan_manager: &signer) acquires LnBTCToken {
        account::create_account_for_test(signer::address_of(loan_manager));
        
        let loan_manager_address = signer::address_of(loan_manager);
        initialize(admin, loan_manager_address);
        
        mint(loan_manager_address, loan_manager_address, 1000);
        assert!(balance(loan_manager_address) == 1000, 1);
    }

    #[test(admin = @btc_lending_platform, unauthorized = @0x456)]
    #[expected_failure(abort_code = 0x50001, location = Self)]
    public fun test_mint_unauthorized_fails(admin: &signer, unauthorized: &signer) acquires LnBTCToken {
        let loan_manager_address = @0x123;
        initialize(admin, loan_manager_address);
        
        mint(signer::address_of(unauthorized), signer::address_of(unauthorized), 1000);
    }

    #[test(admin = @btc_lending_platform, loan_manager = @0x123)]
    #[expected_failure(abort_code = 0x10002, location = Self)]
    public fun test_mint_zero_amount_fails(admin: &signer, loan_manager: &signer) acquires LnBTCToken {
        let loan_manager_address = signer::address_of(loan_manager);
        initialize(admin, loan_manager_address);
        
        mint(loan_manager_address, loan_manager_address, 0);
    }

    #[test(admin = @btc_lending_platform, loan_manager = @0x123, borrower = @0x789)]
    public fun test_transfer(admin: &signer, loan_manager: &signer, borrower: &signer) acquires LnBTCToken {
        account::create_account_for_test(signer::address_of(loan_manager));
        account::create_account_for_test(signer::address_of(borrower));
        
        let loan_manager_address = signer::address_of(loan_manager);
        let borrower_address = signer::address_of(borrower);
        
        initialize(admin, loan_manager_address);
        
        // Mint tokens to loan manager
        mint(loan_manager_address, loan_manager_address, 1000);
        
        // Transfer from loan manager to borrower
        transfer(loan_manager, borrower_address, 500);
        
        // Verify balances
        assert!(balance(loan_manager_address) == 500, 1);
        assert!(balance(borrower_address) == 500, 2);
    }

    #[test(admin = @btc_lending_platform, loan_manager = @0x123)]
    public fun test_burn(admin: &signer, loan_manager: &signer) acquires LnBTCToken {
        account::create_account_for_test(signer::address_of(loan_manager));
        
        let loan_manager_address = signer::address_of(loan_manager);
        initialize(admin, loan_manager_address);
        
        // Mint tokens
        mint(loan_manager_address, loan_manager_address, 1000);
        let initial_supply = total_supply();
        
        // Withdraw and burn tokens
        let tokens = withdraw(loan_manager, 500);
        burn(loan_manager_address, tokens);
        
        // Verify supply decreased
        let final_supply = total_supply();
        assert!(final_supply == initial_supply - 500, 1);
        assert!(balance(loan_manager_address) == 500, 2);
    }

    #[test(admin = @btc_lending_platform, loan_manager = @0x123, borrower = @0x789)]
    public fun test_withdraw_and_burn_by_loan_manager(admin: &signer, loan_manager: &signer, borrower: &signer) acquires LnBTCToken {
        account::create_account_for_test(signer::address_of(loan_manager));
        account::create_account_for_test(signer::address_of(borrower));
        
        let loan_manager_address = signer::address_of(loan_manager);
        let borrower_address = signer::address_of(borrower);
        
        initialize(admin, loan_manager_address);
        
        // Mint tokens to borrower (simulating loan issuance)
        mint(loan_manager_address, borrower_address, 1000);
        assert!(balance(borrower_address) == 1000, 1);
        
        // Borrower withdraws tokens for repayment
        let repayment_tokens = withdraw(borrower, 600);
        
        // LoanManager burns the repayment tokens
        burn(loan_manager_address, repayment_tokens);
        
        // Verify final state
        assert!(balance(borrower_address) == 400, 2);
        assert!(total_supply() == 400, 3);
    }
}