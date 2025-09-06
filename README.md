# BTC Lending Platform

A decentralized lending platform built on Aptos Move that enables users to deposit BTC as collateral and borrow against it using synthetic tokens.

## Architecture

The platform consists of five core modules:

1. **ctrlBTC Token**: Represents BTC deposited as collateral
2. **lnBTC Token**: Represents loan BTC issued to borrowers  
3. **CollateralVault**: Secure storage and management of collateral
4. **LoanManager**: Core business logic for loan lifecycle
5. **InterestRateModel**: Interest rate calculation based on LTV ratios

## Features

- Over-collateralized lending (up to 60% LTV)
- Fixed interest rates based on loan-to-value ratios
- Secure collateral management with atomic operations
- Modular architecture for maintainability and upgrades

## Interest Rate Structure

- 30% LTV → 5% interest rate
- 45% LTV → 8% interest rate  
- 60% LTV → 10% interest rate

## Development

### Prerequisites

- Aptos CLI installed
- Move development environment set up

### Building

```bash
aptos move compile
```

### Testing

```bash
aptos move test
```

### Deployment

```bash
aptos move publish
```

## License

MIT License