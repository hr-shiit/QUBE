# BTC Lending Platform - Frontend Integration Guide

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Setup](#setup)
3. [Smart Contract Integration](#smart-contract-integration)
4. [User Flows](#user-flows)
5. [UI Components](#ui-components)
6. [State Management](#state-management)
7. [Error Handling](#error-handling)
8. [Testing](#testing)
9. [Security](#security)
10. [Deployment](#deployment)
11. [Support](#support)

## Prerequisites

### Development Environment
- Node.js v16 or later
- npm or yarn package manager
- Git version control

### Required Accounts
- Aptos wallet (Petra or Pontem recommended)
- Testnet APT for testing (available from faucet)

## Setup

### Installation
```bash
# Clone the repository
git clone [repository-url]
cd [project-directory]

# Install dependencies
npm install

# Required packages
npm install @aptos-labs/wallet-adapter-react @aptos-labs/ts-sdk
npm install @chakra-ui/react @emotion/react @emotion/styled framer-motion
```

### Environment Configuration
Create a `.env` file in the root directory:
```env
REACT_APP_APTOS_NETWORK=mainnet  # or testnet/devnet
REACT_APP_MODULE_ADDRESS=0x1  # replace with your module address
```

## Smart Contract Integration

### Contract Addresses
```javascript
const CONTRACTS = {
  COLLATERAL_VAULT: `${MODULE_ADDRESS}::collateral_vault`,
  LOAN_MANAGER: `${MODULE_ADDRESS}::loan_manager`,
  INTEREST_RATE_MODEL: `${MODULE_ADDRESS}::interest_rate_model`,
  CTRL_BTC: `${MODULE_ADDRESS}::ctrl_btc_token::CtrlBtc`,
  LN_BTC: `${MODULE_ADDRESS}::ln_btc_token::LNBtc`
};
```

### Key Functions

#### Collateral Vault
- `deposit(amount: u64)`
- `withdraw(amount: u64)`
- `get_user_balance(address: address): u64`

#### Loan Manager
- `create_loan(amount: u64, ltv: u64)`
- `repay_loan(loan_id: u64, amount: u64)`
- `get_loan(loan_id: u64): Loan`
- `get_user_loans(borrower: address): vector<u64>`

#### Interest Rate Model
- `get_rate(ltv: u64): u64`
- `get_all_ltv_ratios(): vector<u64>`

## User Flows

### 1. Connect Wallet
- Implement wallet connection using `@aptos-labs/wallet-adapter-react`
- Display connected wallet address and balance
- Handle network changes and disconnections

### 2. Deposit Collateral
1. User inputs BTC amount
2. Show confirmation dialog with transaction details
3. Execute `collateral_vault::deposit(amount)`
4. Show transaction status and update UI on success

### 3. Borrow Funds
1. User selects LTV ratio (30%, 45%, or 60%)
2. Show maximum borrowable amount
3. User inputs loan amount
4. Execute `loan_manager::create_loan(amount, ltv)`
5. Show loan details and confirmation

### 4. Repay Loan
1. Display active loans
2. User selects loan and repayment amount
3. Execute `loan_manager::repay_loan(loan_id, amount)`
4. Update loan status and user balance

### 5. Withdraw Collateral
1. Check available collateral
2. User inputs withdrawal amount
3. Execute `collateral_vault::withdraw(amount)`
4. Update UI on success

## UI Components

### Required Components
1. **Wallet Connector**
   - Connect/Disconnect buttons
   - Network selector
   - Account information

2. **Dashboard**
   - Collateral overview
   - Borrowing power
   - Active loans summary
   - Transaction history

3. **Transaction Forms**
   - Deposit/Withdraw form
   - Borrow/Repay form
   - Confirmation dialogs
   - Transaction status indicators

4. **Loan Management**
   - Loan list with status indicators
   - Loan details view
   - Repayment schedule

## State Management

### Required State
```typescript
interface AppState {
  wallet: {
    connected: boolean;
    address: string | null;
    balance: number;
    network: string;
  };
  collateral: {
    deposited: number;
    locked: number;
    available: number;
  };
  loans: Array<Loan>;
  transactions: Array<Transaction>;
  loading: boolean;
  error: string | null;
}
```

## Error Handling

### Common Errors
- Insufficient balance
- Transaction rejected
- Network errors
- Contract errors

### Error Handling Pattern
```typescript
try {
  // Execute transaction
} catch (error) {
  if (error.message.includes('INSUFFICIENT_BALANCE')) {
    // Handle insufficient balance
  } else if (error.message.includes('USER_REJECTED')) {
    // Handle user rejection
  } else {
    // Handle other errors
  }
}
```

## Testing

### Test Cases
1. Wallet connection/disconnection
2. Deposit/Withdraw collateral
3. Create and repay loans
4. Error scenarios
5. Network switching

### Testing Tools
- Jest for unit tests
- React Testing Library for component tests
- Mock service worker for API mocking

## Security

### Best Practices
1. Never store private keys in the frontend
2. Use HTTPS in production
3. Implement proper CORS policies
4. Validate all user inputs
5. Use environment variables for sensitive data

## Deployment

### Build
```bash
npm run build
```

### Hosting Options
- IPFS (recommended for decentralization)
- Vercel
- Netlify
- AWS S3 + CloudFront

## Support

### Resources
- [Aptos Developer Documentation](https://aptos.dev/)
- [Wallet Adapter Documentation](https://github.com/aptos-labs/aptos-wallet-adapter)
- [Example Implementation](https://github.com/example/btc-lending-frontend)

### Contact
For support, please contact: support@btclending.io

## License
MIT License - See LICENSE for more information.
