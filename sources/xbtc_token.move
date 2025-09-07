/// xBTC Token Contract - Mock BTC for Testing
/// This is a test token that can be minted unlimited amounts for testing purposes
/// It doesn't hold any real value and is only for development/testing
module btc_lending_platform::xbtc_token {
    use aptos_framework::fungible_asset::{Self, MintRef, TransferRef, BurnRef, FungibleAsset, Metadata};
    use aptos_framework::object::{Self, Object};
    use aptos_framework::primary_fungible_store;
    use aptos_framework::event;
    use std::error;
    use std::signer;
    use std::string::{Self, String};
    use std::option;

    /// Error codes
    const E_NOT_AUTHORIZED: u64 = 1;
    const E_INVALID_AMOUNT: u64 = 2;
    const E_ALREADY_INITIALIZED: u64 = 3;

    /// Token metadata and capabilities
    struct XBTCToken has key {
        mint_ref: MintRef,
        transfer_ref: TransferRef,
        burn_ref: BurnRef,
        admin: address,
    }

    /// Event emitted when xBTC tokens are minted
    #[event]
    struct MintEvent has drop, store {
        to: address,
        amount: u64,
    }

    /// Event emitted when xBTC tokens are burned
    #[event]
    struct BurnEvent has drop, store {
        from: address,
        amount: u64,
    }

    /// Event emitted when admin privileges are transferred
    #[event]
    struct AdminTransferEvent has drop, store {
        old_admin: address,
        new_admin: address,
    }

    /// Initialize the xBTC token
    /// Can only be called once during deployment
    public fun initialize(admin: &signer): Object<Metadata> {
        let admin_address = signer::address_of(admin);
        
        // Ensure this hasn't been initialized before
        assert!(!exists<XBTCToken>(admin_address), error::already_exists(E_ALREADY_INITIALIZED));

        // Create the fungible asset
        let constructor_ref = object::create_named_object(admin, b"X_BTC");
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            &constructor_ref,
            option::none(),
            string::utf8(b"Mock Bitcoin for Testing"), // name
            string::utf8(b"xBTC"), // symbol
            8, // decimals (same as BTC)
            string::utf8(b"https://example.com/xbtc-icon.png"), // icon_uri
            string::utf8(b"https://example.com/xbtc"), // project_uri
        );

        // Generate the mint, transfer, and burn refs
        let mint_ref = fungible_asset::generate_mint_ref(&constructor_ref);
        let transfer_ref = fungible_asset::generate_transfer_ref(&constructor_ref);
        let burn_ref = fungible_asset::generate_burn_ref(&constructor_ref);

        // Store the capabilities
        let token_data = XBTCToken {
            mint_ref,
            transfer_ref,
            burn_ref,
            admin: admin_address,
        };

        move_to(admin, token_data);

        object::object_from_constructor_ref<Metadata>(&constructor_ref)
    }

    /// Mint xBTC tokens to a specified address (admin only)
    public fun mint(admin: &signer, to: address, amount: u64) acquires XBTCToken {
        assert!(amount > 0, error::invalid_argument(E_INVALID_AMOUNT));
        
        let admin_address = signer::address_of(admin);
        let token_data = borrow_global<XBTCToken>(admin_address);
        assert!(admin_address == token_data.admin, error::permission_denied(E_NOT_AUTHORIZED));

        // Mint tokens
        let tokens = fungible_asset::mint(&token_data.mint_ref, amount);
        primary_fungible_store::deposit(to, tokens);

        // Emit mint event
        event::emit(MintEvent {
            to,
            amount,
        });
    }

    /// Burn xBTC tokens from a specified address (admin only)
    public fun burn(admin: &signer, tokens: FungibleAsset) acquires XBTCToken {
        let admin_address = signer::address_of(admin);
        let token_data = borrow_global<XBTCToken>(admin_address);
        assert!(admin_address == token_data.admin, error::permission_denied(E_NOT_AUTHORIZED));

        // Get amount before burning for event
        let amount = fungible_asset::amount(&tokens);

        // Burn tokens
        fungible_asset::burn(&token_data.burn_ref, tokens);

        // Emit burn event
        event::emit(BurnEvent {
            from: admin_address,
            amount,
        });
    }

    /// Transfer admin privileges to a new address
    public fun transfer_admin(admin: &signer, new_admin: address) acquires XBTCToken {
        let admin_address = signer::address_of(admin);
        let token_data = borrow_global_mut<XBTCToken>(admin_address);
        assert!(admin_address == token_data.admin, error::permission_denied(E_NOT_AUTHORIZED));

        let old_admin = token_data.admin;
        token_data.admin = new_admin;

        // Emit admin transfer event
        event::emit(AdminTransferEvent {
            old_admin,
            new_admin,
        });
    }

    /// Get the balance of xBTC tokens for a given address
    #[view]
    public fun balance_of(addr: address): u64 acquires XBTCToken {
        let admin_address = @btc_lending_platform;
        let token_data = borrow_global<XBTCToken>(admin_address);
        let metadata = fungible_asset::mint_ref_metadata(&token_data.mint_ref);
        primary_fungible_store::balance(addr, metadata)
    }

    /// Get the total supply of xBTC tokens
    #[view]
    public fun total_supply(): u128 acquires XBTCToken {
        let admin_address = @btc_lending_platform;
        let token_data = borrow_global<XBTCToken>(admin_address);
        let metadata = fungible_asset::mint_ref_metadata(&token_data.mint_ref);
        option::extract(&mut fungible_asset::supply(metadata))
    }

    /// Get the admin address
    #[view]
    public fun get_admin(): address acquires XBTCToken {
        let admin_address = @btc_lending_platform;
        let token_data = borrow_global<XBTCToken>(admin_address);
        token_data.admin
    }

    /// Get the metadata object for xBTC token
    #[view]
    public fun get_metadata(): Object<Metadata> acquires XBTCToken {
        let admin_address = @btc_lending_platform;
        let token_data = borrow_global<XBTCToken>(admin_address);
        fungible_asset::mint_ref_metadata(&token_data.mint_ref)
    }

    /// Check if xBTC token is initialized
    #[view]
    public fun is_initialized(): bool {
        exists<XBTCToken>(@btc_lending_platform)
    }

    /// Mint xBTC tokens to caller (convenience function for testing)
    public entry fun mint_to_self(admin: &signer, amount: u64) acquires XBTCToken {
        let admin_address = signer::address_of(admin);
        mint(admin, admin_address, amount);
    }

    /// Transfer xBTC tokens between addresses
    public entry fun transfer(from: &signer, to: address, amount: u64) acquires XBTCToken {
        assert!(amount > 0, error::invalid_argument(E_INVALID_AMOUNT));
        
        let admin_address = @btc_lending_platform;
        let token_data = borrow_global<XBTCToken>(admin_address);
        let metadata = fungible_asset::mint_ref_metadata(&token_data.mint_ref);
        
        primary_fungible_store::transfer(from, metadata, to, amount);
    }

    /// Withdraw xBTC tokens from primary store (helper function for burning)
    public fun withdraw(account: &signer, amount: u64): FungibleAsset acquires XBTCToken {
        assert!(amount > 0, error::invalid_argument(E_INVALID_AMOUNT));
        
        let admin_address = @btc_lending_platform;
        let token_data = borrow_global<XBTCToken>(admin_address);
        let metadata = fungible_asset::mint_ref_metadata(&token_data.mint_ref);
        
        primary_fungible_store::withdraw(account, metadata, amount)
    }

    /// Get xBTC token address (for integration)
    #[view]
    public fun get_token_address(): address {
        @btc_lending_platform
    }

    /// Get xBTC token symbol
    #[view]
    public fun get_symbol(): String {
        string::utf8(b"xBTC")
    }

    /// Get xBTC token name
    #[view]
    public fun get_name(): String {
        string::utf8(b"Mock Bitcoin for Testing")
    }

    /// Get xBTC token decimals
    #[view]
    public fun get_decimals(): u8 {
        8
    }

    /// Initialize xBTC token (entry function for easy deployment)
    public entry fun initialize_entry(admin: &signer) {
        let _metadata = initialize(admin);
    }

    /// Mint xBTC tokens to admin (entry function for easy testing)
    public entry fun mint_to_admin(admin: &signer, amount: u64) acquires XBTCToken {
        let admin_address = signer::address_of(admin);
        mint(admin, admin_address, amount);
    }
}
