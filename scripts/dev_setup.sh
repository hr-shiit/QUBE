#!/bin/bash

# Development setup script for BTC Lending Platform

echo "🚀 Setting up BTC Lending Platform development environment..."

# Check if Aptos CLI is installed
if ! command -v aptos &> /dev/null; then
    echo "❌ Aptos CLI is not installed. Please install it first:"
    echo "   curl -fsSL https://aptos.dev/scripts/install_cli.py | python3"
    exit 1
fi

echo "✅ Aptos CLI found"

# Compile the project
echo "📦 Compiling Move contracts..."
aptos move compile --named-addresses btc_lending_platform=0x42

if [ $? -eq 0 ]; then
    echo "✅ Compilation successful"
else
    echo "❌ Compilation failed"
    exit 1
fi

# Run tests
echo "🧪 Running tests..."
aptos move test --named-addresses btc_lending_platform=0x42

if [ $? -eq 0 ]; then
    echo "✅ All tests passed"
else
    echo "❌ Tests failed"
    exit 1
fi

echo "🎉 Development environment setup complete!"
echo ""
echo "Next steps:"
echo "1. Implement token contracts (ctrlBTC and lnBTC)"
echo "2. Create CollateralVault contract"
echo "3. Implement LoanManager contract"
echo "4. Add InterestRateModel contract"
echo ""
echo "Use 'aptos move compile --named-addresses btc_lending_platform=0x42' to compile"
echo "Use 'aptos move test --named-addresses btc_lending_platform=0x42' to run tests"