# LoanManager Contract Requirements

## Introduction

The LoanManager contract is the central orchestrator of the BTC lending platform, managing the complete loan lifecycle from creation to repayment. It coordinates with the CollateralVault for collateral management, InterestRateModel for rate determination, and both token contracts (ctrlBTC and lnBTC) for loan operations. This contract implements the core business logic that ensures secure, over-collateralized lending with proper risk management.

## Requirements

### Requirement 1: Loan Creation and Validation

**User Story:** As a user, I want to create a loan against my deposited collateral, so that I can access liquidity while maintaining ownership of my BTC.

#### Acceptance Criteria

1. WHEN a user requests a loan THEN the system SHALL validate the requested LTV ratio does not exceed 60%
2. WHEN creating a loan THEN the system SHALL verify sufficient unlocked collateral exists in the CollateralVault
3. WHEN a loan is created THEN the system SHALL lock the required collateral amount in the CollateralVault
4. WHEN a loan is approved THEN the system SHALL mint lnBTC tokens equal to the loan amount to the borrower
5. WHEN a loan is created THEN the system SHALL query the InterestRateModel for the appropriate interest rate based on LTV

### Requirement 2: Loan State Management and Tracking

**User Story:** As the system, I want to track all loan details and states, so that I can manage loan lifecycles and enforce business rules.

#### Acceptance Criteria

1. WHEN a loan is created THEN the system SHALL assign a unique loan ID and store all loan details
2. WHEN storing loan data THEN the system SHALL record borrower address, collateral amount, loan amount, interest rate, and creation timestamp
3. WHEN a loan exists THEN the system SHALL maintain the loan state (Active, Repaid, or Defaulted)
4. WHEN queried THEN the system SHALL provide loan details including current outstanding balance with accrued interest
5. WHEN calculating interest THEN the system SHALL use the original interest rate and time elapsed since loan creation

### Requirement 3: Loan Repayment Processing

**User Story:** As a borrower, I want to repay my loan with interest, so that I can unlock my collateral and close the loan.

#### Acceptance Criteria

1. WHEN a borrower repays a loan THEN the system SHALL calculate the total amount due including principal and accrued interest
2. WHEN processing repayment THEN the system SHALL burn the lnBTC tokens provided by the borrower
3. WHEN repayment is complete THEN the system SHALL unlock the collateral in the CollateralVault
4. WHEN a loan is fully repaid THEN the system SHALL update the loan state to Repaid
5. WHEN repayment occurs THEN the system SHALL emit events with loan ID, repayment amount, and interest paid

### Requirement 4: Partial Repayment Support

**User Story:** As a borrower, I want to make partial repayments on my loan, so that I can reduce my interest burden and potentially unlock some collateral.

#### Acceptance Criteria

1. WHEN a borrower makes a partial repayment THEN the system SHALL reduce the outstanding loan balance accordingly
2. WHEN processing partial repayment THEN the system SHALL burn the lnBTC tokens provided proportionally
3. WHEN partial repayment occurs THEN the system SHALL recalculate the required collateral based on the new loan balance
4. WHEN excess collateral exists after partial repayment THEN the system SHALL unlock the excess collateral
5. WHEN partial repayment is processed THEN the system SHALL maintain the original interest rate and loan terms

### Requirement 5: Interest Calculation and Accrual

**User Story:** As the system, I want to accurately calculate interest on loans, so that borrowers pay fair rates and the platform maintains profitability.

#### Acceptance Criteria

1. WHEN calculating interest THEN the system SHALL use simple interest based on the original loan amount and rate
2. WHEN determining interest owed THEN the system SHALL calculate based on time elapsed since loan creation
3. WHEN a loan has been active THEN the system SHALL provide functions to query current interest owed
4. WHEN repayment occurs THEN the system SHALL separate principal and interest components for accounting
5. WHEN interest is calculated THEN the system SHALL use precise time-based calculations to avoid rounding errors

### Requirement 6: Collateral Management Integration

**User Story:** As the LoanManager, I want to coordinate with the CollateralVault, so that collateral is properly locked and unlocked during loan operations.

#### Acceptance Criteria

1. WHEN creating a loan THEN the system SHALL call CollateralVault to lock the required collateral amount
2. WHEN repaying a loan THEN the system SHALL call CollateralVault to unlock the collateral
3. WHEN partial repayment reduces required collateral THEN the system SHALL unlock excess collateral
4. WHEN collateral operations fail THEN the system SHALL revert the entire loan transaction
5. WHEN coordinating with CollateralVault THEN the system SHALL ensure atomic operations to maintain consistency

### Requirement 7: Token Integration and Management

**User Story:** As the LoanManager, I want to coordinate with token contracts, so that lnBTC tokens are properly minted and burned during loan operations.

#### Acceptance Criteria

1. WHEN a loan is created THEN the system SHALL mint lnBTC tokens equal to the loan amount to the borrower
2. WHEN a loan is repaid THEN the system SHALL burn lnBTC tokens from the borrower's account
3. WHEN token operations fail THEN the system SHALL revert the entire transaction to maintain consistency
4. WHEN minting tokens THEN the system SHALL verify the mint operation succeeds before completing loan creation
5. WHEN burning tokens THEN the system SHALL verify sufficient lnBTC balance exists before processing repayment

### Requirement 8: Access Control and Security

**User Story:** As a system administrator, I want strict access controls on loan operations, so that only authorized entities can perform sensitive operations.

#### Acceptance Criteria

1. WHEN administrative functions are called THEN the system SHALL verify admin permissions
2. WHEN updating contract addresses THEN the system SHALL require admin authorization
3. WHEN emergency pause is activated THEN the system SHALL prevent new loan creation and modifications
4. WHEN the system is paused THEN the system SHALL still allow loan repayments to protect borrowers
5. WHEN transferring admin privileges THEN the system SHALL verify current admin permissions

### Requirement 9: Loan Querying and Analytics

**User Story:** As a user or external system, I want to query loan information, so that I can track loan status and make informed decisions.

#### Acceptance Criteria

1. WHEN queried THEN the system SHALL return complete loan details for any valid loan ID
2. WHEN calculating outstanding balance THEN the system SHALL include both principal and accrued interest
3. WHEN queried THEN the system SHALL return all active loans for a specific borrower
4. WHEN providing loan data THEN the system SHALL include current LTV ratio based on outstanding balance
5. WHEN queried THEN the system SHALL return system-wide statistics like total loans and total outstanding debt

### Requirement 10: Event Emission and Transparency

**User Story:** As an external observer or integration, I want comprehensive event logging, so that I can track all loan operations and maintain external records.

#### Acceptance Criteria

1. WHEN loans are created THEN the system SHALL emit events with loan ID, borrower, amounts, and terms
2. WHEN repayments occur THEN the system SHALL emit events with loan ID, payment amount, and remaining balance
3. WHEN loan states change THEN the system SHALL emit events with loan ID, old state, and new state
4. WHEN administrative changes occur THEN the system SHALL emit events with old and new values
5. WHEN errors occur THEN the system SHALL provide clear error messages for debugging and user feedback

### Requirement 11: Risk Management and Validation

**User Story:** As the system, I want comprehensive risk management, so that the platform remains solvent and secure.

#### Acceptance Criteria

1. WHEN validating loan requests THEN the system SHALL enforce maximum LTV ratios to prevent over-leveraging
2. WHEN processing operations THEN the system SHALL validate all amounts are positive and within reasonable limits
3. WHEN coordinating with external contracts THEN the system SHALL handle failures gracefully
4. WHEN calculating ratios THEN the system SHALL prevent division by zero and handle edge cases
5. WHEN managing state THEN the system SHALL maintain data consistency across all operations

### Requirement 12: Emergency Controls and Upgrades

**User Story:** As a system administrator, I want emergency controls and upgrade capabilities, so that I can respond to issues and maintain the platform.

#### Acceptance Criteria

1. WHEN emergency situations arise THEN the system SHALL provide pause functionality to halt new operations
2. WHEN the system is paused THEN the system SHALL still allow critical operations like loan repayments
3. WHEN updating contract addresses THEN the system SHALL provide functions to update CollateralVault and token contract references
4. WHEN performing upgrades THEN the system SHALL maintain existing loan data and state
5. WHEN emergency controls are used THEN the system SHALL emit events for transparency and auditability