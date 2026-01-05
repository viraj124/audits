## C-01 - No oracle differentiation check bricks borrowing and liquidation
**Severity**: Critical
**Location**: `market.rs:6`, `borrow.rs:10`

**Description**: In market creation and borrowing functions there is no check to ensure the supply/borrow and collateral oracle are different.

So this means the users essentially can borrow more than they should be allowed to without getting liquidated which completely defeats the purpose of a lending protocol.

**Impact**: The impact is high as it leads to allowing users to borrow more than they should without getting liquidated

**Proof of Concept**:
POC here `meta-lend.ts:154` (poc not copied here to keep the report size brief and avoid renundancy)
```
it(No oracle differentiation check bricks borrowing and liquidation", async () => {
...
}
```
Output
```
Testing dual-asset market with same supply and collateral oracle...
Market Created....
User Accounts Initialised....
1 ETH supplied....
Borrow 0.1 ETH with 150 USDC as collateral....
Liquidating 0.04 ETH($60 worth of ETH) results in a error despite the position being unhealthy....
AnchorError: AnchorError thrown in programs/capstone/src/instructions/liquidate.rs:36. Error Code: PositionHealthy. Error Number: 6005. Error Message: Position is healthy - cannot liquidate.
    at AnchorError.parse (/Users/virazmalhotra/rektoffbootcamp/capstone/node_modules/@coral-xyz/anchor/src/error.ts:152:14)
    at translateError (/Users/virazmalhotra/rektoffbootcamp/capstone/node_modules/@coral-xyz/anchor/src/error.ts:277:35)
    at MethodsBuilder.rpc [as _rpcFn] (/Users/virazmalhotra/rektoffbootcamp/capstone/node_modules/@coral-xyz/anchor/src/program/namespace/rpc.ts:35:29)
    at processTicksAndRejections (node:internal/process/task_queues:105:5) {
  errorLogs: [
    'Program log: AnchorError thrown in programs/capstone/src/instructions/liquidate.rs:36. Error Code: PositionHealthy. Error Number: 6005. Error Message: Position is healthy - cannot liquidate.'
  ],
  logs: [
    'Program BsXpJ5jJHTSbAVKqSL3QmNzXWt2rYcknMW7awr8i3YBe invoke [1]',
    'Program log: Instruction: Liquidate',
    'Program log: AnchorError thrown in programs/capstone/src/instructions/liquidate.rs:36. Error Code: PositionHealthy. Error Number: 6005. Error Message: Position is healthy - cannot liquidate.',
    'Program BsXpJ5jJHTSbAVKqSL3QmNzXWt2rYcknMW7awr8i3YBe consumed 20059 of 200000 compute units',
    'Program BsXpJ5jJHTSbAVKqSL3QmNzXWt2rYcknMW7awr8i3YBe failed: custom program error: 0x1775'
  ],
  error: {
    errorCode: { code: 'PositionHealthy', number: 6005 },
    errorMessage: 'Position is healthy - cannot liquidate',
    comparedValues: undefined,
    origin: {
      file: 'programs/capstone/src/instructions/liquidate.rs',
      line: 36
    }
  },
  _programErrorStack: ProgramErrorStack {
    stack: [
      [PublicKey [PublicKey(BsXpJ5jJHTSbAVKqSL3QmNzXWt2rYcknMW7awr8i3YBe)]]
    ]
  }
}

✔ No oracle differentiation check bricks borrowing and liquidation (7057ms)

```
**Recommendation**
Add oracle differentiation check in `market.rs` & `borrow.rs`

```typescript!
Add this check in `create_market` function inside market.rs

require!(ctx.accounts.supply_oracle.key !=         ctx.accounts.collateral_oracle.key,
        LendingError::DuplicateOracle
    );

Add this check in `borrow` function inside borrow.rs
require!(ctx.accounts.borrow_oracle.key !=         ctx.accounts.collateral_oracle.key,
        LendingError::DuplicateOracle
    );

```

## C-02 - No token diffrentiation check causes DOS in liquidation
**Severity**: Critical
**Location**: `market.rs:6`

**Description**: In market creation there is no check about the supply and the collateral token being different, so anyone can create a market without having a 2nd token.

So this means after users borrow, if a any price change happen, liquidation can't happen as the asset prices will always move proportionally.


**Impact**: The impact is high as it leads to a denial of service when executing liquidations and bricking it.

**Proof of Concept**:
POC here `meta-lend.ts:412` (poc not copied here to keep the report size brief and avoid renundancy)
```
it("No token diffrentiation check bricks the protocol functionality", async () => {
...
}
```

Output
```
Testing dual-asset market with same supply and collateral token...
Market Created....
User Accounts Initialised....
1 ETH supplied....
Borrow 0.1 ETH as collateral and 0.08 ETH as borrow amount as the tokens are the same...

🔧 Using TEST-ONLY oracle manipulation to trigger liquidation
Liquidating 0.04 ETH($72 worth of ETH) results in a error despite the position being unhealthy....
AnchorError: AnchorError thrown in programs/capstone/src/instructions/liquidate.rs:36. Error Code: PositionHealthy. Error Number: 6005. Error Message: Position is healthy - cannot liquidate.
    at AnchorError.parse (/Users/virazmalhotra/rektoffbootcamp/capstone/node_modules/@coral-xyz/anchor/src/error.ts:152:14)
    at translateError (/Users/virazmalhotra/rektoffbootcamp/capstone/node_modules/@coral-xyz/anchor/src/error.ts:277:35)
    at MethodsBuilder.rpc [as _rpcFn] (/Users/virazmalhotra/rektoffbootcamp/capstone/node_modules/@coral-xyz/anchor/src/program/namespace/rpc.ts:35:29)
    at processTicksAndRejections (node:internal/process/task_queues:105:5) {
  errorLogs: [
    'Program log: AnchorError thrown in programs/capstone/src/instructions/liquidate.rs:36. Error Code: PositionHealthy. Error Number: 6005. Error Message: Position is healthy - cannot liquidate.'
  ],
  logs: [
    'Program BsXpJ5jJHTSbAVKqSL3QmNzXWt2rYcknMW7awr8i3YBe invoke [1]',
    'Program log: Instruction: Liquidate',
    'Program log: AnchorError thrown in programs/capstone/src/instructions/liquidate.rs:36. Error Code: PositionHealthy. Error Number: 6005. Error Message: Position is healthy - cannot liquidate.',
    'Program BsXpJ5jJHTSbAVKqSL3QmNzXWt2rYcknMW7awr8i3YBe consumed 18544 of 200000 compute units',
    'Program BsXpJ5jJHTSbAVKqSL3QmNzXWt2rYcknMW7awr8i3YBe failed: custom program error: 0x1775'
  ],
  error: {
    errorCode: { code: 'PositionHealthy', number: 6005 },
    errorMessage: 'Position is healthy - cannot liquidate',
    comparedValues: undefined,
    origin: {
      file: 'programs/capstone/src/instructions/liquidate.rs',
      line: 36
    }
  },
  _programErrorStack: ProgramErrorStack {
    stack: [
      [PublicKey [PublicKey(BsXpJ5jJHTSbAVKqSL3QmNzXWt2rYcknMW7awr8i3YBe)]]
    ]
  }
}
    ✔ No token diffrentiation check bricks the protocol functionality (7698ms)

```
**Recommendation**
Add token differentiation check in `market.rs`

```typescript!
Add this check in `create_market` function inside market.rs

require!(ctx.accounts.supply_mint.key !=         ctx.accounts.collateral_mint.key,
        LendingError::DuplicateToken
    );

```

## C-03 - The flash loan functionality is broken due to multiple issues
**Severity**: Critical
**Location**: `flash_loan.rs:8`

**Description**: The `flash_loan` function allows users to get funds from the `supply_vault` and then at the end send funds back with a fee, the initial and final balances are recorded and checked with
```
    require!(
        final_balance >= required_balance,
        LendingError::FlashLoanNotRepaid
    );
```

But the issue is `final_balance` uses a stale value as the cpi call modifies the vault balance at the end as it sends the tokens back but `reload()` is not called before `final_balance` is set so this will always cause the tx to revert and cause DOS.

Another issues is the lack of reentrancy protection in the `flash_loan` function, a user can provide a malicious callback function which can make n number of calls back to the `flash_loan` function and drain the `supply_vault` and payback the `amount + fee` for only the first call.

So if total `(1 + n)` calls are made to the `flash_loan` function the user pays the amount and fee for only the first call making a lot of profit

lastly anchor provides no protections for `ctx.remaining_accounts` and it is provided by the user so it can lead to unexpected error causing DOS especially when combined with ` unsafe { mem::transmute(...}}` even though the transfer happens from the `supply_vault` which is linked with the `supply_mint` token.

``` 
     // @audit the tokens are sent before the external call but there is no way to enforce reentracy protection
    token_interface::transfer(cpi_ctx, amount)?;

    // Use remaining accounts to call external program
    let callback_program = &ctx.remaining_accounts[0];

    // Create accounts list for the callback - all remaining accounts except the first (callback program)
    let callback_accounts = &ctx.remaining_accounts[1..];

    // Build instruction for external callback using our generic CallbackInstruction
    let callback_ix = Instruction {
        program_id: callback_program.key(),
        accounts: callback_accounts
            .iter()
            .map(|acc| AccountMeta {
                pubkey: acc.key(),
                is_signer: acc.is_signer,
                is_writable: acc.is_writable,
            })
            .collect(),
        data: callback_data, // Pass the raw callback_data to external program
    };

    // Execute the callback CPI to external program
    // @audit the malicious cpi call happens here
    invoke(&callback_ix, callback_accounts)?;
```

**Impact**: The impact is high as it leads to the supply vault being drained

**Recommendation**
- Reload the vault balance before the balance comparision check
``` 
        ctx.accounts.supply_vault.reload()?;
```
- Add a reentrancy lock check in the `flash_loan` function
```typescript!
add pub locked: bool in Market struct, with the default value as false

pub fn flash_loan(
    ctx: Context<FlashLoan>,
    market_id: u64,
    amount: u64,
    callback_data: Vec<u8>, // User-provided data for callback
) -> Result<()> {

    ...
    require!(!market.locked, LendingError::Reentrancy);
     
    market.flash_loan_in_progress = true;

    ...
    market.locked = false;
    msg!("Flash loan repaid with fee");
    Ok(())
}

```

- Remove the `unsafe` use just to avoid having any unexepcted issues

## H-01 - The global protocol invariants are broken during liquidation
**Severity**: High
**Location**: `liquidate.rs:46, liquidate.rs:87`

**Description**: During liquidation there are two state updates that don't happen

- `marketAccount.totalCollateralDeposits` & ` marketAccount.totalBorrows` are not reduced so sum of all users providing collateral and borrowing does not match the global state vars

- interest is not added to the `borrower_deposit.borrowed_amount` var like it is in the `borrow` function which makes the `PositionHealthy` check incorrect and leads to invalid accounting too

**Impact**: The impact is high as it invalid accounting in the protocol.

**Proof of Concept**:
POC here `meta-lend.ts:708` (poc not copied here to keep the report size brief and avoid renundancy)
```
it("protocol invariants are broken during liquidation", async () => {
...
}
```

Output
```
Testing liquidation with the protocol invariants being broken...
Market Created....
User Accounts Initialised....
USDC supplied....
Borrow 200 USDC with 0.1 ETH as collateral...

🔧 Using TEST-ONLY oracle manipulation to trigger liquidation
The total collateral and borrowed amount don't match with the borrowers collateral and borrowed amount which breaks the protcol invariant
    ✔ protocol invariants are broken during liquidation (8272ms)
```
**Recommendation**
- add interest to `borrower_deposit.borrowed_amount` before the `PositionHealthy` check 

```typescript!
    if user_deposit.borrowed_amount > 0 {
        let current_slot = Clock::get()?.slot;
        let slots_elapsed = current_slot.saturating_sub(user_deposit.last_update_slot);
        let interest_rate_per_slot = 25u128; // ~2% annual / 800,000 slots
        let slots_elapsed_u128 = slots_elapsed as u128;
        let interest_increment = user_deposit
            .borrowed_amount
            .saturating_mul(interest_rate_per_slot)
            .saturating_mul(slots_elapsed_u128)
            / SCALING_FACTOR; // Scale down

        user_deposit.borrowed_amount = user_deposit
            .borrowed_amount
            .saturating_add(interest_increment);
        user_deposit.last_update_slot = current_slot;
    }
```

- update `marketAccount.totalCollateralDeposits` & ` marketAccount.totalBorrows` too 

```typescript!
marketAccount.totalCollateralDeposits -= collateral_to_seize
marketAccount.totalBorrows -= liquidation_amount
```

## H-02 - No decimal handling for supply and collateral tokens bricks the borrow and withdraw function
**Severity**: High
**Location**: `borrow.rs:66, withdraw.rs:42`

**Description**: The protocol involves having dual asset markets and the tokens in these markets can have different decimals i.e a USDC-ETH market where the token decimals are not the same

But in `borrow` & `withdraw` function this does not happen which leads to borrowing more than you can given the deposited collateral & withdrawing your supplied tokens even if the borrow position is unhealthy

**Impact**: The impact is high as this bricks the borrowing and withdrawing supply functionality

**Proof of Concept**:
POC here `meta-lend.ts:1005` (poc not copied here to keep the report size brief and avoid renundancy)
```
  it("the withdrawal and borrow functions are broken due to not handling decimals precision & not using the supplied tokens when checking for a healthy borrow position", async () => {
  ...
}
```

Output
```
Testing decimals precision being broken & supplied tokens not considered when checking for a healthy borrow position...
Market Created....
User Accounts Initialised....
USDC supplied by both users....
Borrow 300 USDC with 0.1 ETH as collateral...
decimal precision issue with borrowValue: 300000000000000 & maxBorrowValue: 144000000000000000
The transaction is not reverted but that is due to not handling the different decimal tokens of the market correctly, ideally it should not be reverted as the withdraw function should handle the decimal precision correctly & taking the supplied tokens by the user into account as in this case the user borrowed 200 USDC but also supplied 500 USDC
    ✔ the withdrawal and borrow functions are broken due to not handling decimals precision & not using the supplied tokens when checking for a healthy borrow position (8332ms)
```
**Recommendation**
Add decimal normalizing logic in borrow and withdraw functions to fix this

## H-03 - Anyone can call the update market function and make the borrow functionality unusable causing DOS
**Severity**: High
**Location**: `market_admin.rs:5`

**Description**: The protocol has a `update_market_params` function which allows to update `collateral_factor` & `liquidation_threshold` values by anyone.

So a attacker can just set both values to 100% percent making borrowing highly risky for liquidations without any buffer for collateral price changes.

**Impact**: The impact is high as this makes borrowing unusable

**Proof of Concept**:
POC here `meta-lend.ts:1299` (poc not copied here to keep the report size brief and avoid renundancy)
```
  it("anyone can call the update market function and make the borrow functionality unusable causing DOS", async () => {
  ...
}
```

Output
```
Testing lack of access control in update market function...
Market Created....
Market Updated by a arbitary user which is not the market admin....
    ✔ anyone can call the update market function and make the borrow functionality unusable causing DOS (1924ms)
```
**Recommendation**
Add access control check to ensure only market creator can update the market params
```
    require!(
        ctx.accounts.authority.key = ctx.accounts.market.market_admin.key(),
        LendingError::Unauthorized
    );
```

## M-01 - Using a token 2022 compilant token with transfer fee extension can break the accounting
**Severity**: Medium
**Location**: `market.rs:6`

**Description**: The `Market` context allows either a SPL or Token 2022 compiliant token to be used for creating markets, token 2022 introduced the concepts of hooks/extensions called during different functions like transfer mint.

In case of token 2022 standard the `transfer` function has been deprecated and replaced by `transfer_checked` & `transfer_checked_with_fee` so in case a fee on transfer token is used in a market then the transfers in the protocol will revert as it still relies on `transfer`

**Impact**: The impact is high this can lead to the protocol unsuable for markets with fee on transfer tokens

**Recommendation**
Allow the protocol admin to whitelist tokens without the fee on transfer extension in case a token 2022 compliant token is used to maintain backward compatibility with spl standard support which still uses `transfer`

## QA-01 - Remove manual transfer of lamports when closing user deposit accounts
**Severity**: QA
**Location**: `user_deposit.rs:104`

**Description**: The `CloseUserDeposit` context already has the `close` constraint
```
    #[account(
        mut,
        close = user,
    )]
    pub user_deposit: Account<'info, UserDeposit>,
```

so in the `close_user_deposit` function the manual transfer of lamports is not needed to avoid renundancy and any unexpected behaviour with future upgrades etc as it is handled automatically by anchor with the close contraint

**Recommendation**
Remove manual lamport transfer

## QA-02 - No protocol pausing or market inactive functionality
**Severity**: QA
**Location**: `protocol.rs:1`, `market.rs:1`

**Description**: The `ProtocolState` has `is_paused` flag to be used to pause the protocol in case of any issues but it is not used

Same goes for the `Market` struct which has a `is_active` flag to deactive a market in case of any issue but again that is not used either

**Recommendation**
have functions to pause the protocol and make the market inactive
