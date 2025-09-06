# CollateralVault Contract Requirements

## Introduction

The CollateralVault contract is a critical component of the BTC lending platform that manages the secure storage and handling of user collateral. It serves as the bridge between user BTC deposits and the ctrlBTC token representation, while also coordinating with the LoanManager for collateral locking/unlocking operations during loan lifecycles.

## Requirements

### Requirement 1: Collateral Deposit and Token Minting

**User Story:** As a user, I want to deposit BTC as collateral and receive ctrlBTC tokens, so that I can use my BTC as backing for loans while maintaining a liquid token representation.

#### Acceptance Criteria

1. WHEN a user deposits BTC THEN the system SHALL mint an equivalent amount of ctrlBTC tokens to the user's account
2. WHEN BTC is deposited THEN the system SHALL store the collateral securely in the vault
3. WHEN minting ctrlBTC THEN the system SHALL maintain a 1:1 ratio between deposited BTC and minted ctrlBTC
4. IF the deposit amount is zero or negative THEN the system SHALL reject the transaction with an appropriate error
5. WHEN a deposit is successful THEN the system SHALL emit a deposit event with user address and amount

### Requirement 2: Collateral Withdrawal and Token Burning

**User Story:** As a user, I want to withdraw my BTC collateral by burning ctrlBTC tokens, so that I can reclaim my original BTC when I no longer need it as collateral.

#### Acceptance Criteria

1. WHEN a user burns ctrlBTC tokens THEN the system SHALL release an equivalent amount of BTC collateral to the user
2. WHEN burning ctrlBTC THEN the system SHALL verify the user has sufficient ctrlBTC balance
3. WHEN withdrawing collateral THEN the system SHALL verify sufficient unlocked collateral exists in the vault
4. IF the withdrawal amount exceeds available unlocked collateral THEN the system SHALL reject the transaction
5. WHEN a withdrawal is successful THEN the system SHALL emit a withdrawal event with user address and amount

### Requirement 3: Collateral Locking for Loans

**User Story:** As the LoanManager contract, I want to lock user collateral when loans are created, so that the collateral cannot be withdrawn while securing active loans.

#### Acceptance Criteria

1. WHEN the LoanManager requests collateral locking THEN the system SHALL lock the specified amount for the specified user
2. WHEN locking collateral THEN the system SHALL verify sufficient unlocked collateral exists
3. WHEN collateral is locked THEN the system SHALL update the user's locked collateral balance
4. IF insufficient unlocked collateral exists THEN the system SHALL reject the lock request
5. WHEN collateral is successfully locked THEN the system SHALL emit a collateral locked event

### Requirement 4: Collateral Unlocking After Loan Repayment

**User Story:** As the LoanManager contract, I want to unlock user collateral when loans are repaid, so that users can withdraw their collateral after fulfilling loan obligations.

#### Acceptance Criteria

1. WHEN the LoanManager requests collateral unlocking THEN the system SHALL unlock the specified amount for the specified user
2. WHEN unlocking collateral THEN the system SHALL verify sufficient locked collateral exists for the user
3. WHEN collateral is unlocked THEN the system SHALL update the user's locked collateral balance
4. IF insufficient locked collateral exists THEN the system SHALL reject the unlock request
5. WHEN collateral is successfully unlocked THEN the system SHALL emit a collateral unlocked event

### Requirement 5: Access Control and Security

**User Story:** As a system administrator, I want strict access controls on collateral operations, so that only authorized contracts can perform sensitive operations like locking/unlocking collateral.

#### Acceptance Criteria

1. WHEN any function is called THEN the system SHALL verify the caller has appropriate permissions
2. WHEN the LoanManager calls lock/unlock functions THEN the system SHALL allow the operation
3. WHEN unauthorized addresses call lock/unlock functions THEN the system SHALL reject with permission denied error
4. WHEN the vault admin updates the LoanManager address THEN the system SHALL verify admin permissions
5. WHEN non-admin addresses attempt admin operations THEN the system SHALL reject with unauthorized error

### Requirement 6: Balance Tracking and Queries

**User Story:** As a user or external contract, I want to query collateral balances and status, so that I can understand the current state of collateral holdings.

#### Acceptance Criteria

1. WHEN queried THEN the system SHALL return the total collateral balance for any user
2. WHEN queried THEN the system SHALL return the locked collateral balance for any user
3. WHEN queried THEN the system SHALL return the available (unlocked) collateral balance for any user
4. WHEN queried THEN the system SHALL return the total vault collateral across all users
5. WHEN balance queries are made THEN the system SHALL ensure locked + unlocked = total balance for each user

### Requirement 7: Integration with ctrlBTC Token

**User Story:** As the CollateralVault contract, I want to mint and burn ctrlBTC tokens during deposit/withdrawal operations, so that users have a liquid representation of their collateral.

#### Acceptance Criteria

1. WHEN deposits occur THEN the system SHALL call the ctrlBTC mint function with the user address and amount
2. WHEN withdrawals occur THEN the system SHALL call the ctrlBTC burn function to remove tokens from circulation
3. WHEN minting ctrlBTC THEN the system SHALL verify the mint operation succeeds before completing the deposit
4. WHEN burning ctrlBTC THEN the system SHALL verify the burn operation succeeds before releasing collateral
5. WHEN token operations fail THEN the system SHALL revert the entire transaction to maintain consistency

### Requirement 8: Error Handling and Validation

**User Story:** As a developer, I want comprehensive error handling and validation, so that the system fails gracefully and provides clear feedback for debugging and user experience.

#### Acceptance Criteria

1. WHEN invalid amounts are provided THEN the system SHALL return specific error codes for zero/negative amounts
2. WHEN insufficient balances exist THEN the system SHALL return specific error codes for insufficient collateral
3. WHEN unauthorized access occurs THEN the system SHALL return specific error codes for permission denied
4. WHEN invalid state transitions are attempted THEN the system SHALL return appropriate error codes
5. WHEN errors occur THEN the system SHALL provide clear error messages that aid in debugging

### Requirement 9: Administrative Functions

**User Story:** As a system administrator, I want to manage vault configuration and emergency controls, so that I can maintain system security and update contract integrations.

#### Acceptance Criteria

1. WHEN the admin updates the LoanManager address THEN the system SHALL update the authorized contract address
2. WHEN the admin transfers admin privileges THEN the system SHALL update the admin address
3. WHEN admin functions are called THEN the system SHALL verify current admin permissions
4. WHEN emergency pause is activated THEN the system SHALL prevent new deposits and withdrawals
5. WHEN the system is unpaused THEN the system SHALL resume normal operations

### Requirement 10: Event Emission and Transparency

**User Story:** As an external observer or integration, I want comprehensive event logging, so that I can track all collateral operations and maintain external records.

#### Acceptance Criteria

1. WHEN deposits occur THEN the system SHALL emit events with user address, amount, and timestamp
2. WHEN withdrawals occur THEN the system SHALL emit events with user address, amount, and timestamp
3. WHEN collateral is locked THEN the system SHALL emit events with user address, amount, and loan reference
4. WHEN collateral is unlocked THEN the system SHALL emit events with user address, amount, and loan reference
5. WHEN administrative changes occur THEN the system SHALL emit events with old and new values