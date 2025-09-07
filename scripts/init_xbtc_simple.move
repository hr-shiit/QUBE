script {
    use btc_lending_platform::xbtc_token;

    fun init_xbtc_simple(admin: &signer) {
        // Initialize xBTC token
        let _metadata = xbtc_token::initialize(admin);
        
        // Mint some initial xBTC to admin for testing
        xbtc_token::mint_to_self(admin, 100000000000); // 1000 xBTC (8 decimals)
    }
}
