# 🧪 xBTC Token - Testing Guide

## 📋 **Overview**

**xBTC** is a mock Bitcoin token designed specifically for testing your BTC Lending Platform. It has no real value and can be minted unlimited amounts for development and testing purposes.

## 🎯 **Key Features**

- ✅ **Unlimited Minting**: Admin can mint as many xBTC as needed
- ✅ **No Real Value**: Purely for testing purposes
- ✅ **ERC-20 Compatible**: Works with standard fungible asset interfaces
- ✅ **8 Decimals**: Same precision as real Bitcoin
- ✅ **Event System**: Comprehensive event logging
- ✅ **Admin Controls**: Full control over minting and burning

## 📍 **Contract Address**

**xBTC Token**: `0x5e25225f13c79a741fa58f8db5c6c8aa4da5f5113553592c797a8d1588ddf01b::xbtc_token`

## 🚀 **Deployment & Initialization**

### 1. **Compile and Publish**
```bash
aptos move compile --save-metadata
aptos move publish --private-key YOUR_PRIVATE_KEY --url https://fullnode.testnet.aptoslabs.com/v1 --package-dir .
```

### 2. **Initialize xBTC Token**
```bash
aptos move run --private-key YOUR_PRIVATE_KEY --url https://fullnode.testnet.aptoslabs.com/v1 --function-id 0x5e25225f13c79a741fa58f8db5c6c8aa4da5f5113553592c797a8d1588ddf01b::init_xbtc::init_xbtc
```

## 🔧 **Available Functions**

### **Admin Functions**

#### **Mint xBTC Tokens**
```bash
# Mint to specific address
aptos move run --private-key YOUR_PRIVATE_KEY --url https://fullnode.testnet.aptoslabs.com/v1 \
  --function-id 0x5e25225f13c79a741fa58f8db5c6c8aa4da5f5113553592c797a8d1588ddf01b::xbtc_token::mint \
  --args address:RECIPIENT_ADDRESS u64:AMOUNT

# Mint to self (convenience function)
aptos move run --private-key YOUR_PRIVATE_KEY --url https://fullnode.testnet.aptoslabs.com/v1 \
  --function-id 0x5e25225f13c79a741fa58f8db5c6c8aa4da5f5113553592c797a8d1588ddf01b::xbtc_token::mint_to_self \
  --args u64:AMOUNT
```

#### **Burn xBTC Tokens**
```bash
aptos move run --private-key YOUR_PRIVATE_KEY --url https://fullnode.testnet.aptoslabs.com/v1 \
  --function-id 0x5e25225f13c79a741fa58f8db5c6c8aa4da5f5113553592c797a8d1588ddf01b::xbtc_token::burn \
  --args address:FROM_ADDRESS u64:AMOUNT
```

#### **Batch Mint (Multiple Recipients)**
```bash
aptos move run --private-key YOUR_PRIVATE_KEY --url https://fullnode.testnet.aptoslabs.com/v1 \
  --function-id 0x5e25225f13c79a741fa58f8db5c6c8aa4da5f5113553592c797a8d1588ddf01b::xbtc_token::batch_mint \
  --args "address:[ADDR1,ADDR2,ADDR3]" "u64:[AMOUNT1,AMOUNT2,AMOUNT3]"
```

#### **Transfer Admin**
```bash
aptos move run --private-key YOUR_PRIVATE_KEY --url https://fullnode.testnet.aptoslabs.com/v1 \
  --function-id 0x5e25225f13c79a741fa58f8db5c6c8aa4da5f5113553592c797a8d1588ddf01b::xbtc_token::transfer_admin \
  --args address:NEW_ADMIN_ADDRESS
```

### **View Functions**

#### **Check Balance**
```bash
aptos move view --url https://fullnode.testnet.aptoslabs.com/v1 \
  --function-id 0x5e25225f13c79a741fa58f8db5c6c8aa4da5f5113553592c797a8d1588ddf01b::xbtc_token::balance_of \
  --args address:CHECK_ADDRESS
```

#### **Get Total Supply**
```bash
aptos move view --url https://fullnode.testnet.aptoslabs.com/v1 \
  --function-id 0x5e25225f13c79a741fa58f8db5c6c8aa4da5f5113553592c797a8d1588ddf01b::xbtc_token::total_supply
```

#### **Get Token Info**
```bash
# Get admin address
aptos move view --url https://fullnode.testnet.aptoslabs.com/v1 \
  --function-id 0x5e25225f13c79a741fa58f8db5c6c8aa4da5f5113553592c797a8d1588ddf01b::xbtc_token::get_admin

# Get token address
aptos move view --url https://fullnode.testnet.aptoslabs.com/v1 \
  --function-id 0x5e25225f13c79a741fa58f8db5c6c8aa4da5f5113553592c797a8d1588ddf01b::xbtc_token::get_token_address

# Get symbol
aptos move view --url https://fullnode.testnet.aptoslabs.com/v1 \
  --function-id 0x5e25225f13c79a741fa58f8db5c6c8aa4da5f5113553592c797a8d1588ddf01b::xbtc_token::get_symbol

# Get name
aptos move view --url https://fullnode.testnet.aptoslabs.com/v1 \
  --function-id 0x5e25225f13c79a741fa58f8db5c6c8aa4da5f5113553592c797a8d1588ddf01b::xbtc_token::get_name

# Get decimals
aptos move view --url https://fullnode.testnet.aptoslabs.com/v1 \
  --function-id 0x5e25225f13c79a741fa58f8db5c6c8aa4da5f5113553592c797a8d1588ddf01b::xbtc_token::get_decimals
```

## 💡 **Testing Examples**

### **Example 1: Mint 1000 xBTC to Admin**
```bash
aptos move run --private-key YOUR_PRIVATE_KEY --url https://fullnode.testnet.aptoslabs.com/v1 \
  --function-id 0x5e25225f13c79a741fa58f8db5c6c8aa4da5f5113553592c797a8d1588ddf01b::xbtc_token::mint_to_self \
  --args u64:100000000000
```

### **Example 2: Mint 500 xBTC to Test User**
```bash
aptos move run --private-key YOUR_PRIVATE_KEY --url https://fullnode.testnet.aptoslabs.com/v1 \
  --function-id 0x5e25225f13c79a741fa58f8db5c6c8aa4da5f5113553592c797a8d1588ddf01b::xbtc_token::mint \
  --args address:0x1234567890abcdef1234567890abcdef12345678 u64:50000000000
```

### **Example 3: Check Balance**
```bash
aptos move view --url https://fullnode.testnet.aptoslabs.com/v1 \
  --function-id 0x5e25225f13c79a741fa58f8db5c6c8aa4da5f5113553592c797a8d1588ddf01b::xbtc_token::balance_of \
  --args address:0x5e25225f13c79a741fa58f8db5c6c8aa4da5f5113553592c797a8d1588ddf01b
```

## 🔗 **Integration with BTC Lending Platform**

### **Frontend Integration**
```javascript
// Example: Mint xBTC for testing
const mintXBTC = async (amount) => {
  const payload = {
    type: "entry_function_payload",
    function: "0x5e25225f13c79a741fa58f8db5c6c8aa4da5f5113553592c797a8d1588ddf01b::xbtc_token::mint_to_self",
    arguments: [amount.toString()],
    type_arguments: []
  };
  
  return await window.aptos.signAndSubmitTransaction(payload);
};

// Example: Check xBTC balance
const getXBTCBalance = async (address) => {
  const response = await fetch('https://fullnode.testnet.aptoslabs.com/v1/view', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      function: "0x5e25225f13c79a741fa58f8db5c6c8aa4da5f5113553592c797a8d1588ddf01b::xbtc_token::balance_of",
      arguments: [address],
      type_arguments: []
    })
  });
  
  return await response.json();
};
```

### **Backend Integration**
```python
# Example: Mint xBTC using Python
import requests

def mint_xbtc(amount, recipient_address):
    payload = {
        "type": "entry_function_payload",
        "function": "0x5e25225f13c79a741fa58f8db5c6c8aa4da5f5113553592c797a8d1588ddf01b::xbtc_token::mint",
        "arguments": [recipient_address, str(amount)],
        "type_arguments": []
    }
    
    # Submit transaction using your preferred Aptos SDK
    return submit_transaction(payload)

def get_xbtc_balance(address):
    response = requests.post('https://fullnode.testnet.aptoslabs.com/v1/view', json={
        "function": "0x5e25225f13c79a741fa58f8db5c6c8aa4da5f5113553592c797a8d1588ddf01b::xbtc_token::balance_of",
        "arguments": [address],
        "type_arguments": []
    })
    
    return response.json()
```

## 📊 **Token Specifications**

- **Symbol**: xBTC
- **Name**: Mock Bitcoin for Testing
- **Decimals**: 8
- **Total Supply**: Unlimited (mintable)
- **Network**: Aptos Testnet
- **Standard**: Aptos Fungible Asset

## ⚠️ **Important Notes**

1. **Testing Only**: xBTC has no real value and should never be used in production
2. **Admin Control**: Only the admin can mint/burn tokens
3. **Unlimited Supply**: Can mint as many tokens as needed for testing
4. **Event Logging**: All mint/burn operations emit events for tracking
5. **Integration Ready**: Compatible with standard fungible asset interfaces

## 🎯 **Use Cases**

- **Frontend Testing**: Mint tokens for UI testing
- **Backend Testing**: Test integration with lending platform
- **Load Testing**: Mint large amounts for stress testing
- **User Testing**: Provide test users with xBTC for platform testing
- **Development**: Use during development without real funds

---

**🧪 Happy Testing with xBTC!**
