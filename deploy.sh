#!/bin/bash

# BTC Lending Platform Deployment Script
# This script deploys the BTC lending platform contracts to Aptos

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 BTC Lending Platform Deployment Script${NC}"
echo "================================================"

# Check if wallet address and private key are provided
if [ -z "$1" ] || [ -z "$2" ]; then
    echo -e "${RED}❌ Error: Please provide wallet address and private key${NC}"
    echo "Usage: ./deploy.sh <WALLET_ADDRESS> <PRIVATE_KEY>"
    echo "Example: ./deploy.sh 0x1234...abcd 0x5678...efgh"
    exit 1
fi

WALLET_ADDRESS=$1
PRIVATE_KEY=$2

echo -e "${YELLOW}📋 Deployment Configuration:${NC}"
echo "Wallet Address: $WALLET_ADDRESS"
echo "Private Key: ${PRIVATE_KEY:0:10}..."
echo ""

# Check if aptos CLI is installed
if ! command -v aptos &> /dev/null; then
    echo -e "${RED}❌ Error: aptos CLI is not installed${NC}"
    echo "Please install aptos CLI: https://aptos.dev/cli-tools/aptos-cli-tool/install-aptos-cli/"
    exit 1
fi

# Check if build directory exists
if [ ! -d "build/btc_lending_platform" ]; then
    echo -e "${RED}❌ Error: Build directory not found${NC}"
    echo "Please run 'aptos move compile --save-metadata' first"
    exit 1
fi

echo -e "${YELLOW}🔧 Setting up Aptos profile...${NC}"

# Create or update aptos profile
aptos init --profile btc_lending --private-key $PRIVATE_KEY --rest-url https://fullnode.mainnet.aptoslabs.com/v1

echo -e "${YELLOW}📦 Publishing package...${NC}"

# Publish the package
aptos move publish --profile btc_lending --package-dir . --named-addresses btc_lending_platform=$WALLET_ADDRESS

echo -e "${YELLOW}🚀 Running deployment script...${NC}"

# Run the deployment script
aptos move run --profile btc_lending --function-id $WALLET_ADDRESS::deploy::deploy

echo ""
echo -e "${GREEN}✅ Deployment completed successfully!${NC}"
echo ""
echo -e "${YELLOW}📋 Contract Addresses:${NC}"
echo "InterestRateModel: $WALLET_ADDRESS::interest_rate_model"
echo "CollateralVault: $WALLET_ADDRESS::collateral_vault"
echo "LoanManager: $WALLET_ADDRESS::loan_manager"
echo "ctrlBTC Token: $WALLET_ADDRESS::ctrl_btc_token"
echo "lnBTC Token: $WALLET_ADDRESS::ln_btc_token"
echo ""
echo -e "${GREEN}🎉 Your BTC Lending Platform is now live!${NC}"
echo ""
echo -e "${YELLOW}📖 Next Steps:${NC}"
echo "1. Verify contract deployment on Aptos Explorer"
echo "2. Test the platform with small amounts first"
echo "3. Set up monitoring and alerts"
echo "4. Configure frontend integration"
echo ""
echo -e "${YELLOW}📚 Documentation:${NC}"
echo "See DEPLOYMENT_INFO.md for detailed contract ABIs and integration guide"
