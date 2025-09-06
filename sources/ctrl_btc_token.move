/// ctrlBTC Token Contract
/// Represents BTC deposited as collateral in the lending system
/// Only the CollateralVault module can mint/burn these tokens
module btc_lending_platform::ctrl_btc_token {
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
    struct CtrlBTCToken has key {
        mint_ref: MintRef,
        transfer_ref: TransferRef,
        burn_ref: BurnRef,
        collateral_vault_address: address,
    }

    /// Initialize the ctrlBTC token
    /// Can only be called once during deployment
    public fun initialize(admin: &signer, collateral_vault_address: address): Object<Metadata> {
        // Ensure this hasn't been initialized before
        assert!(!exists<CtrlBTCToken>(signer::address_of(admin)), error::already_exists(E_ALREADY_INITIALIZED));

        // Create the fungible asset
        let constructor_ref = object::create_named_object(admin, b"CTRL_BTC");
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            &constructor_ref,
            option::none(),
            utf8(b"Collateral BTC"), // name
            utf8(b"ctrlBTC"), // symbol
            8, // decimals (same as BTC)
            utf8(b"https://example.com/ctrl-btc-icon.png"), // icon_uri
            utf8(b"https://example.com/ctrl-btc"), // project_uri
        );

        // Generate the mint, transfer, and burn refs
        let mint_ref = fungible_asset::generate_mint_ref(&constructor_ref);
        let transfer_ref = fungible_asset::generate_transfer_ref(&constructor_ref);
        let burn_ref = fungible_asset::generate_burn_ref(&constructor_ref);

        // Store the capabilities
        let token_data = CtrlBTCToken {
            mint_ref,
            transfer_ref,
            burn_ref,
            collateral_vault_address,
        };

        move_to(admin, token_data);

        object::object_from_constructor_ref<Metadata>(&constructor_ref)
    }

    /// Mint ctrlBTC tokens and deposit to recipient
    /// Can only be called by the CollateralVault module
    public fun mint(caller: address, to: address, amount: u64) acquires CtrlBTCToken {
        assert!(amount > 0, error::invalid_argument(E_INVALID_AMOUNT));
        
        let token_data = borrow_global<CtrlBTCToken>(@btc_lending_platform);
        assert!(caller == token_data.collateral_vault_address, error::permission_denied(E_NOT_AUTHORIZED));

        let tokens = fungible_asset::mint(&token_data.mint_ref, amount);
        primary_fungible_store::deposit(to, tokens);
    }

    /// Burn ctrlBTC tokens
    /// Can only be called by the CollateralVault module
    public fun burn(caller: address, tokens: FungibleAsset) acquires CtrlBTCToken {
        let token_data = borrow_global<CtrlBTCToken>(@btc_lending_platform);
        assert!(caller == token_data.collateral_vault_address, error::permission_denied(E_NOT_AUTHORIZED));

        fungible_asset::burn(&token_data.burn_ref, tokens);
    }

    /// Transfer ctrlBTC tokens (standard transfer)
    public fun transfer(from: &signer, to: address, amount: u64) acquires CtrlBTCToken {
        assert!(amount > 0, error::invalid_argument(E_INVALID_AMOUNT));
        
        let token_data = borrow_global<CtrlBTCToken>(@btc_lending_platform);
        let metadata = fungible_asset::mint_ref_metadata(&token_data.mint_ref);
        
        primary_fungible_store::transfer(from, metadata, to, amount);
    }

    /// Get balance of ctrlBTC tokens for an address
    public fun balance(account: address): u64 acquires CtrlBTCToken {
        let token_data = borrow_global<CtrlBTCToken>(@btc_lending_platform);
        let metadata = fungible_asset::mint_ref_metadata(&token_data.mint_ref);
        primary_fungible_store::balance(account, metadata)
    }

    /// Get the metadata object for ctrlBTC token
    public fun get_metadata(): Object<Metadata> acquires CtrlBTCToken {
        let token_data = borrow_global<CtrlBTCToken>(@btc_lending_platform);
        fungible_asset::mint_ref_metadata(&token_data.mint_ref)
    }

    /// Get total supply of ctrlBTC tokens
    public fun total_supply(): u128 acquires CtrlBTCToken {
        let token_data = borrow_global<CtrlBTCToken>(@btc_lending_platform);
        let metadata = fungible_asset::mint_ref_metadata(&token_data.mint_ref);
        option::extract(&mut fungible_asset::supply(metadata))
    }

    /// Update the authorized CollateralVault address (admin only)
    public fun update_vault_address(admin: &signer, new_vault_address: address) acquires CtrlBTCToken {
        assert!(signer::address_of(admin) == @btc_lending_platform, error::permission_denied(E_NOT_AUTHORIZED));
        
        let token_data = borrow_global_mut<CtrlBTCToken>(@btc_lending_platform);
        token_data.collateral_vault_address = new_vault_address;
    }

    #[test_only]
    use aptos_framework::account;

    #[test(admin = @btc_lending_platform)]
    public fun test_initialize(admin: &signer) {
        let vault_address = @0x123;
        let metadata = initialize(admin, vault_address);
        
        // Verify token was created
        assert!(exists<CtrlBTCToken>(signer::address_of(admin)), 1);
        
        // Verify metadata
        let name = fungible_asset::name(metadata);
        assert!(name == utf8(b"Collateral BTC"), 2);
        
        let symbol = fungible_asset::symbol(metadata);
        assert!(symbol == utf8(b"ctrlBTC"), 3);
    }

    #[test(admin = @btc_lending_platform)]
    #[expected_failure(abort_code = 0x80003, location = Self)]
    public fun test_initialize_twice_fails(admin: &signer) {
        let vault_address = @0x123;
        initialize(admin, vault_address);
        initialize(admin, vault_address); // Should fail
    }

    #[test(admin = @btc_lending_platform, vault = @0x123)]
    public fun test_mint_authorized(admin: &signer, vault: &signer) acquires CtrlBTCToken {
        account::create_account_for_test(signer::address_of(vault));
        
        let vault_address = signer::address_of(vault);
        initialize(admin, vault_address);
        
        mint(vault_address, vault_address, 1000);
        assert!(balance(vault_address) == 1000, 1);
    }

    #[test(admin = @btc_lending_platform, unauthorized = @0x456)]
    #[expected_failure(abort_code = 0x50001, location = Self)]
    public fun test_mint_unauthorized_fails(admin: &signer, unauthorized: &signer) acquires CtrlBTCToken {
        let vault_address = @0x123;
        initialize(admin, vault_address);
        
        mint(signer::address_of(unauthorized), signer::address_of(unauthorized), 1000);
    }

    #[test(admin = @btc_lending_platform, vault = @0x123)]
    #[expected_failure(abort_code = 0x10002, location = Self)]
    public fun test_mint_zero_amount_fails(admin: &signer, vault: &signer) acquires CtrlBTCToken {
        let vault_address = signer::address_of(vault);
        initialize(admin, vault_address);
        
        mint(vault_address, vault_address, 0);
    }

    #[test(admin = @btc_lending_platform, vault = @0x123, user = @0x789)]
    public fun test_transfer(admin: &signer, vault: &signer, user: &signer) acquires CtrlBTCToken {
        account::create_account_for_test(signer::address_of(vault));
        account::create_account_for_test(signer::address_of(user));
        
        let vault_address = signer::address_of(vault);
        let user_address = signer::address_of(user);
        
        initialize(admin, vault_address);
        
        // Mint tokens to vault
        mint(vault_address, vault_address, 1000);
        
        // Transfer from vault to user
        transfer(vault, user_address, 500);
        
        // Verify balances
        assert!(balance(vault_address) == 500, 1);
        assert!(balance(user_address) == 500, 2);
    }

    #[test(admin = @btc_lending_platform, vault = @0x123)]
    public fun test_burn(admin: &signer, vault: &signer) acquires CtrlBTCToken {
        account::create_account_for_test(signer::address_of(vault));
        
        let vault_address = signer::address_of(vault);
        initialize(admin, vault_address);
        
        // Mint tokens
        mint(vault_address, vault_address, 1000);
        let initial_supply = total_supply();
        
        // Withdraw and burn tokens
        let metadata = get_metadata();
        let tokens = primary_fungible_store::withdraw(vault, metadata, 500);
        burn(vault_address, tokens);
        
        // Verify supply decreased
        let final_supply = total_supply();
        assert!(final_supply == initial_supply - 500, 1);
        assert!(balance(vault_address) == 500, 2);
    }
}