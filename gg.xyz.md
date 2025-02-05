# Introduction

A security review of the **gg.xyz** smart contract was done by **Cipher Seluths** team, with a focus on the security aspects of the smart contracts implementation.

# Disclaimer

A smart contract security review can never verify the complete absence of vulnerabilities. This is a time, resource and expertise bound effort where we try to find as many vulnerabilities as possible. we can not guarantee 100% security after the review or even if the review will find any problems with your smart contracts. Subsequent security reviews, bug bounty programs and on-chain monitoring are strongly recommended.

# About **Cipher Seluths**

**Cipher Seluths** is team of security researchers [**Udsen**](https://code4rena.com/@Udsen) & [**Viraz**](https://twitter.com/Viraz04) who have a good experience participating in codearena contests both solo and as a team & have found multiple vulnerabilities in various protocols.

# About **gg.xyz**
gg.xyz is a guild launchpad, making crypto gaming multiplayer, it is a gaming passport to play web3 games in a cheats-free competitive environment.


# Severity classification

| Severity               | Impact: High | Impact: Medium | Impact: Low |
| ---------------------- | ------------ | -------------- | ----------- |
| **Likelihood: High**   | Critical     | High           | Medium      |
| **Likelihood: Medium** | High         | Medium         | Low         |
| **Likelihood: Low**    | Medium       | Low            | Low         |

**Impact** - the technical, economic and reputation damage of a successful attack

**Likelihood** - the chance that a particular vulnerability gets discovered and exploited

**Severity** - the overall criticality of the risk

# Security Assessment Summary

**_review commit hash_ - [25b7d6b448d0addc8c20c2069ef36bcafe71e482](https://github.com/ggQuest/core/tree/25b7d6b448d0addc8c20c2069ef36bcafe71e482)**

- only contracts under `guild` & `rewards` folder were part of the scope

# Detailed Findings

## High

## H-01 `IERC721Receiver.onERC721Received` is not implemented in the `ERC721RewardHolder.sol` contract

### Lines of code

https://github.com/ggQuest/core/blob/stable/contracts/rewards/holders/ERC721RewardHolder.sol#L61
https://github.com/ggQuest/core/blob/stable/contracts/rewards/holders/ERC1155RewardHolder.sol#L93

### Vulnerability details

The `ERC721RewardHolder` function uses the `createReward` function to create rewards. It calls the `safeTransferFrom` function to `transfer` the respective `ERC721` tokens to the `ERC721RewardsHolder (itself)` as shown below:

```solidity
        IERC721(token).safeTransferFrom(msg.sender, address(this), tokenId);
```

The `IERC721::safeTransferFrom` function has a callback function made to the `recipient` if the recipient is a smart contract as shown below:

```solidity
ERC721Utils.checkOnERC721Received(_msgSender(), from, to, tokenId, data);
```

If the `IERC721Receiver::onERC721Receive` is not implemented in the `recipient` contract the transaction will revert.

The `ERC721RewardHolder.sol` contract does not implement the `IERC721Receiver::onERC721Receive` and as a result the `ERC721RewardHolder::createReward` function is `DoS`.

Similarly the `ERC1155RewardHolder.sol` contract does not implement the `onERC1155Received`  function and as a result the `ERC1155RewardHolder::createReward` function is `DoS` 


### Tools Used
Manual review
### Recommended Mitigation Steps
Hence it is recommended to implement the `IERC721Receiver::onERC721Receive` function in the `ERC721RewardHolder.sol` contract and the `onERC721Receive` function should return the `IERC721Receiver.onERC721Received.selector` value.

Similarly the `IERC1155Receiver.onERC1155Received` function should be implemented in the `ERC1155RewardHolder.sol` contract.

## H-02 Non-Existence of slippage calculations can lead to DOS post migration

### Lines of code

https://github.com/ggQuest/core/blob/25b7d6b448d0addc8c20c2069ef36bcafe71e482/contracts/guilds/BondingCurve.sol#L331

https://github.com/ggQuest/core/blob/25b7d6b448d0addc8c20c2069ef36bcafe71e482/contracts/guilds/BondingCurve.sol#L345

https://github.com/ggQuest/core/blob/25b7d6b448d0addc8c20c2069ef36bcafe71e482/contracts/guilds/BondingCurve.sol#L361

https://github.com/ggQuest/core/blob/25b7d6b448d0addc8c20c2069ef36bcafe71e482/contracts/guilds/BondingCurve.sol#L377


## Vulnerability details

### Impact
The lack of slippage check when interacting with uniswap v2 contracts can either lead to DOS or execute a swap in favour of the protocol and not the user

### Proof of Concept
Once the migration process is completed and a lp position is created on uniswap v2, then post that all swaps happen through uniswap v2.

The issue is that `amountOutMin` & `amountInMax` which are slippage related variables, are a user input in `_swapWithUniswapV2ExactEthForTokens`, `_swapWithUniswapV2ExactTokensForEth`, `_swapWithUniswapV2EthForExactTokens` & `_swapWithUniswapV2TokensForExactEth` functions. 

Additionally there are no sanitization checks on these input values, which can either lead to DOS as the swap would revert inside the uniswap v2 contracts or the swap happens in favour of the protocol and not the user

### Tools Used
Manual review
### Recommended Mitigation Steps 
There can be two different approaches to resolve this issue:

- There should be a validation of the user provided values through the [quote method](https://github.com/Uniswap/v2-periphery/blob/master/contracts/UniswapV2Router02.sol#L403) in the uni v2 router contract, hence relying on the uni v2 oracle

- We remove the user input altogether and generate the  `amountOutMin` & `amountInMax` vars in the method itself using the quote method.

## H-03 The `BondingCurve::swapExactInput` does not transfer tokens to itself before callin UniswapV2

### Lines of code

https://github.com/ggQuest/core/blob/stable/contracts/guilds/BondingCurve.sol#L360-L366

### Vulnerability details

The `BondingCurve::swapExactInput` is called to swap `ExactInput` amounts of either the `token or ETH`.

Now let's consider the followign scenario:

1. The `target is reached` and the `BondingCurve` is migrated to the `UniswapV2` liquidity pool.
2. User calls the `BondingCurve::swapExactInput` to `sell tokens` and provides  token amount to sell as the`ExactInput` amount.
3. The transaction will call the `_swapWithUniswapV2ExactTokensForEth(params.amountIn, params.amountOutMin);`.
4. Inside the `_swapWithUniswapV2ExactTokensForEth` the ` _uniswapV2Router().swapExactTokensForETHSupportingFeeOnTransferTokens` is called.
5. In the `swapExactTokensForETHSupportingFeeOnTransferTokens` the `ExactInput` amount of tokens are transferred to the `Pair contract` as shown below:

```solidity
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amountIn
        );
```

Here the `msg.sender` is the `BondingCurve` contract. But the issue here is that `neither BondingCurve` contract has the `tokens` to transfer to the `UniswapV2 pair` contract nor the `neccesary approval` for the tokens are given.

### Tools Used
Manual review
### Recommended Mitigation Steps
Hence it is recommended to initally transfer the tokens to the `BondingCurve` contract and then approve that amount to the `UniswapV2Router02` contract before calling the `_swapWithUniswapV2ExactTokensForEth` function.

## H-04 Deadline set in the Uniswap `swap` functions are wrong and could lead to loss of funds

### Lines of code

https://github.com/ggQuest/core/blob/stable/contracts/guilds/BondingCurve.sol#L350
https://github.com/ggQuest/core/blob/stable/contracts/guilds/BondingCurve.sol#L365
https://github.com/ggQuest/core/blob/stable/contracts/guilds/BondingCurve.sol#L381
https://github.com/ggQuest/core/blob/stable/contracts/guilds/BondingCurve.sol#L397

### Vulnerability details

After the BondingCurve is `migrated` to the `Uniswap Pool` the subsequent swaps are performed via the `Uniswap liquidity pool`.

The functions `_swapWithUniswapV2ExactEthForTokens`, `_swapWithUniswapV2ExactTokensForEth`, `_swapWithUniswapV2EthForExactTokens` and `_swapWithUniswapV2TokensForExactEth` are called accordingly.

But the issue here is that each of these functions use teh `block.timestmap` as the `deadline` and this is wrong. Which means this `swap transaction` can be called at anytime the `transaction is picked from the mempool`. 

Which means it could be executed at a exchange rate unfavorable to the user and user will lose money as a result. The `slippage check is not sufficient in this scenario`, since provided slippage value could be stale at the time of the transaction execution.

### Tools Used
Manual review
### Recommended Mitigation Steps
Hence recommended to get the `deadline` as a user input.

## H-05 User is selling less tokens to get the exactAmountOut of ETH

### Lines of code

https://github.com/ggQuest/core/blob/stable/contracts/guilds/BondingCurve.sol#L251-L256

### Vulnerability details

The `BondingCurve::_swapExactOutput` has the following logic to calculate the amount of `tokens a user should sell` to the `exact amount of ETH`.


```solidity
        if (!params.isBuy) {
            fee = _applyFee(params.amountOut);
            exactOut -= fee.toUint128();
        }

        uint128 amountIn = (uint256(-int256(_swap(caller, params.isBuy, int256(uint256(exactOut)))))).toUint128();
```

When a user requires exact amount of eth for the amount of tokens he is selling then the amount to sell should be more since he is paying for the fee amount as well.

But based on the above calculation the fee amoutn is iniitally deducted from the `exactOut` amount which means the calculated `amountIn` will be less. This means the user is paying less `tokens` for the same amount of required eth amount which is loss of funds to the protocol.


### Tools Used
Manual review
### Recommended Mitigation Steps
The same logic applied in the `isBuy` scenario to calculate the fee and `amountIn` should apply here for the `sell` scenario as well.

```
        if (params.isBuy) {
            fee = _applyFee(amountIn);
            amountIn += fee.toUint128();
        }
```

This will ensure user is transfering more tokens to cover for the fee amount. Here the fee amount is calculated in `tokens`.

## H-06 DoS of `_swapExactInput` due to rounding error of `1 wei`

### Lines of code

https://github.com/ggQuest/core/blob/stable/contracts/guilds/BondingCurve.sol#L222-L225
https://github.com/ggQuest/core/blob/stable/contracts/guilds/libraries/BipsLibrary.sol#L9-L12
https://github.com/ggQuest/core/blob/stable/contracts/guilds/BondingCurve.sol#L237

### Vulnerability details

When the `BondingCurve::swapExactInput` is called or during the `initial token creation` the `msg.value` is sent in by the `msg.sender`.

In the execution flow the `_swapExactInput` gets called which performs the `fee calculation` as shown below:

```solidity
        if (params.isBuy) { 
            fee = _applyFee(params.amountIn); 
            exactIn -= fee.toUint128();
        }
```

In the `BondingCurve::_applyFee` function the fee is calculated by calling the `BipsLibrary::calculatePortion` function.

```solidity
    function calculatePortion(uint256 amount, uint64 bips) internal pure returns (uint256) {
        if (bips > BPS_DENOMINATOR) revert InvalidBips();
        return (amount * bips) / BPS_DENOMINATOR;
    }
```

The above `calculatePortion` can introduce rounding error.

In the `_swapExactInput` function the following logic is executed ensure enough `msg.value` is passed into the contract to cover for the `swap amount and fee` as shown below:

```solidity
        if (params.isBuy) {
            if (msg.value != exactIn + fee) revert InvalidAmount();
            token.transfer(caller, amountOut);
        }
```

But the issue here is that even though the user has provided the correct `amountIn` value and `msg.value` the transaction will `DoS` if the `calculated fee had a rounding error of atleast 1 wei`. This is due to the `exact equality check performed in the above logic`.

 ```solidity
msg.value != exactIn + fee
```

### Tools Used
Manual review
### Recommended Mitigation Steps

Hence it is recommended to update the above logic to ensure `msg.value > exactIn + fee` and retun any `excessive eth` back to the `msg.sender`.

## H-07 The UniswapV2Router02 does not define functions for `ExactOutput` swaps

### Lines of code

https://github.com/ggQuest/core/blob/stable/contracts/guilds/BondingCurve.sol#L371-L383
https://github.com/ggQuest/core/blob/stable/contracts/guilds/BondingCurve.sol#L387-L399

### Vulnerability details

The `UniswapV2Router02` does not implement functions for the `ExactOutput` swaps since it is difficult to ensure `ExactOutput` when working with `FeeOnTransfer` tokens.

This is why only `swapExactTokensForETHSupportingFeeOnTransferTokens` and `swapExactETHForTokensSupportingFeeOnTransferTokens` functions are defined in the `UniswapV2Router02` contract. And there aren't any functions implemented for the `ExactOutput` scenario.

But the `BondingCurve` contract impelments the `ExactOutput` functions for the swaps happening via `UniswapV2 pools` by calling the same `swapExactTokensForETHSupportingFeeOnTransferTokens` and `swapExactETHForTokensSupportingFeeOnTransferTokens`.

Here these functions consider the `amountInMax` as the `input amount of tokens` and proceed with the swap operation. The issue with this is since we are using `amountInMax` as the input amount and not as a slippage check parameter we can not gurantee hte `ExactOutput` amount. The `output amount can be >= ExactOutput`.

Another issue here is that in the `_swapWithUniswapV2EthForExactTokens` function if we are planning to send the `msg.value as the amountInMax` the logic (`if (amountInMax == msg.value) revert InvalidAmount();`) should be corrected as follows:

```solidity
      if (amountInMax != msg.value) revert InvalidAmount();
```

### Tools Used
Manual review
### Recommended Mitigation Steps
If this is the expected behavior (`output >= ExactOutput` is accepted) then this should be properly documented. Else should remove the functions for the `ExactOutput` when working with `fee on transfer` tokens using `UniswapV2Router02`.

# Medium

## M-01 `AMMFeeLayer` applies for the `GuildTokenTransfers` happening in BondingCurve

### Lines of code

https://github.com/ggQuest/core/blob/stable/contracts/guilds/BondingCurve.sol#L240
https://github.com/ggQuest/core/blob/stable/contracts/guilds/BondingCurve.sol#L270

### Vulnerability details

The `UniswapV2` functions enable `fee on token transfers`. The `GuildTokens` also has a fee on token transfer mechanism defined in the `GuildToken::_applyFees` and `GuildToken::_applyAmmFee`.

The design of the logic seems to charge fee for transfers happening in the `UniswapV2 liquidity pool` via the `AMMFeeLayer`. But the issue here is for token transfers happening in the `bonding curve` the `transfer fee also applies`.

Hence for the `ExactOut` swap happening for `token buying` (when calling the `BondingCurve::_swapExactOutput` with `params.isBuy == true`) less than `ExactOut` will be transferred to the user since during the `transfer fee will be charged`. 

Furthermore when the `ExactIn` amount of tokens are being sold by calling the `_swapExactInput` with `params.isBuy == false` the `ETH amountOut` is calculated based on the `exactIn` amount but the transfer of tokens from the msg.sender happens after `amountOut` calculation. This means less than `exactIn` will be transferred to the protocol after accounting for the transfer fee. But since `transferFee` is also paid to the protocol this might not be a loss of funds to the protocol. But the better approach would be to initally transfer the tokens `exactIn` from the user and then calculate before (before the token transfer) and after balances of the token in the contract and use the `differnce` to calculate the `amountOut` value of `ETH`.

### Tools Used
Manual review
### Recommended Mitigation Steps
This behaviour of recieving less than `ExactOut` amount of `tokens` when calling the `BondingCurve::_swapExactOutput` with `params.isBuy == true`, should be properly be documented and users should be informed of this behaviour. So the user should input the `ExactOut` amount after accounting for the `transfer fee`.

## M-02 BondingCurve contract initialization can fail due to inconsistent token reserve check

### Lines of code

https://github.com/ggQuest/core/blob/25b7d6b448d0addc8c20c2069ef36bcafe71e482/contracts/guilds/BondingCurve.sol#L62

https://github.com/ggQuest/core/blob/25b7d6b448d0addc8c20c2069ef36bcafe71e482/contracts/guilds/TokenManager.sol#L145


## Vulnerability details

### Impact
Inconsistency in virtual token reserve checks can lead to deployment failure of BondingCurve thereby causing a DOS situation in the protocol

### Proof of Concept
During the bonding curve contract initialization there is this check

```
        if (params_.ethReserveVirtual == 0 || params_.tokenReserveVirtual < params_.initialSupply) {
            revert InvalidReserves();
        }

```
 where `initialSupply` is determined by the `bondingBips`
 
```
uint256 bondingCurveSupply = initialTokenSupply.calculatePortion(bondingBips);
```


A similar check exists, when the token manager is initialized where `bondingSaleBips` is also involved  in addition to the `bondingBips`

```
        uint256 saleSupply = initialTokenSupply.calculatePortion(bondingBips).calculatePortion(bondingSaleBips);
        if (newEthReserveVirtual == 0 || newTokenReserveVirtual == 0 || newTokenReserveVirtual <= saleSupply) {
            revert InvalidReserveVirtual();
        }
```

The issue here is when initializing the bonding curve contract `bondingSaleBips` is not used, so the probablity of `bondingCurveSupply` being more than the  `params_.tokenReserveVirtual` increases which can cause the bonding curve initialization to fail.

### Tools Used
Manual review
### Recommended Mitigation Steps 
Either in the TokenManager initialization only `bondingBips` should be used for the virtual token supply check or in BondingCurve initialization, both `bondingSaleBips` & `bondingBips` should be used forthe virtual token supply check, in order to have consistency


## M-03 Signature validation would fail if the owner is a multisig

### Lines of code

https://github.com/ggQuest/core/blob/25b7d6b448d0addc8c20c2069ef36bcafe71e482/contracts/rewards/RewardClaimer.sol#L57


## Vulnerability details

### Impact
Failure of signature validation in the protocol will not allow any user to claim rewards thereby causing DOS

### Proof of Concept
The claim method in the RewardClaimer contract is used to claim nft rewards and it involves a signature validation with the `_verifySignature` method which uses EIP712 for signature verification.

There is no restrction on the `owner` being a multisig and EIP712 does not support signature verification for non-EOA accounts.

so this check will always fail
```
        address signer = ECDSA.recover(hash, signature);
        if (signer != owner()) revert InvalidSignature();
```

### Tools Used
Manual review
### Recommended Mitigation Steps 
If the owner is a multisig, [EIP1271](https://eips.ethereum.org/EIPS/eip-1271) should be used for signature validation, so the `isValidSignature` method can be utilised for validating the multisig signatures.

So while recovering a valid message signed by the owner, the return value will be the `bytes4(0)` because contracts that sign messages sticking to the EIP1271 standard use the `EIP1271_MAGIC_VALUE` as the successful return for a properly recovered signature.

## M-04 Guild token transfer can fail due to missing checks when setting fee rates 

### Lines of code


https://github.com/ggQuest/core/blob/25b7d6b448d0addc8c20c2069ef36bcafe71e482/contracts/guilds/GuildToken.sol#L71

https://github.com/ggQuest/core/blob/25b7d6b448d0addc8c20c2069ef36bcafe71e482/contracts/guilds/GuildToken.sol#L74


## Vulnerability details

### Impact
No checks on combined fee rate values during setting them can lead to transfer failures

### Proof of Concept
When the guild token is transferred, there is fee sent to 3 fee layers 
```
        uint256 totalFee = _applyAmmFee(keccak256("feeLayer.amm.protocol"), from, to, amount) +
            _applyAmmFee(keccak256("feeLayer.amm.guildBank"), from, to, amount) +
            _applyAmmFee(keccak256("feeLayer.amm.holdersShare"), from, to, amount);
        return amount - totalFee;
```

When adding fee layers there is no check that the sum of all fee layer rates combined should be `< BipsLibrary.BPS_DENOMINATOR`

Now for example, let's say the user wants to transfer 100 tokens and the fee rates of all the fee layers is 40 % then the fee transfer for the last fee layer will fail due to underflow.


### Tools Used
Manual review
### Recommended Mitigation Steps 
There should be more strict input checks when setting fee rates in terms of the combined fee rate values so all of them combined are `< BipsLibrary.BPS_DENOMINATOR` 

## Low

## L-01 When changing the `initialSupply`, it could invalidate the virtual token checks

### Lines of code

https://github.com/ggQuest/core/blob/stable/contracts/guilds/TokenManager.sol#L152-L155
https://github.com/ggQuest/core/blob/stable/contracts/guilds/TokenManager.sol#L64-L66
https://github.com/ggQuest/core/blob/stable/contracts/guilds/TokenManager.sol#L96-L98

### Vulnerability details

The `TokenManager::initialize` function set the initial state. The `initialSupply`, `SupplyPropotions` and `InitialReserveVirtual` are set in the following order.

```solidity
        _setSupplyProportions(proportions_);
        _setInitialSupply(initialSupply_);
        _setInitialReserveVirtual(initialEthReserveVirtual_, initialTokenReserveVirtual_);
```

And the contract is `paused` at the end of the `initialize` function execution.

While the contract is paused the `admin` can still call the `setInitialSupply` to change the `initialSupply` and `setSupplyProportions` to change the `supply proportions`. But the issue here is that when those values are changed it does not check if the following `virtualToken checks` are complemented. 

```solidity
        uint256 saleSupply = initialTokenSupply.calculatePortion(bondingBips).calculatePortion(bondingSaleBips);
        if (newEthReserveVirtual == 0 || newTokenReserveVirtual == 0 || newTokenReserveVirtual <= saleSupply) {
            revert InvalidReserveVirtual();
        }
```

Hence this could break the price calculaitons of the bonding curve. Since the `virtual token amounts` are expected to be more than the `real token amounts`

### Tools Used
Manual review
### Recommended Mitigation Steps
Hence recommended to always check whether the `virtual token amount checks` are complemented when the `initialSupply` or `supplyPropotions` are changed when the contract is `paused`. If not respective `transactions for the change`, should be reverted.

## L-02 The protocol always calculates both portions of the initialSupply seperately

### Lines of code

https://github.com/ggQuest/core/blob/stable/contracts/guilds/TokenManager.sol#L83
https://github.com/ggQuest/core/blob/stable/contracts/guilds/TokenManager.sol#L89

### Vulnerability details

The `initialSupply` can be changed after initialization by calling the `setInitialSupply`. If `setInitialSupply` is changed to a non-round number later this could lead to stucked token amount (Dust) in the `tokenManager`contract. (Currently this is not an issue since we are using 1 Billion tokens as the initial supply)

This is due to the nature at which the `poritons` are calculated in the `TokenManager`. (Same behaviour is seen in the `BondingCurve` contract as well.)

```solidity
        uint256 bondingCurveSupply = initialTokenSupply.calculatePortion(bondingBips);

        uint256 leftoverSupply = initialTokenSupply.calculatePortion(leftoverBips);
```

Because ` bondingBips + leftoverBips == 10,000` the assumption is calculating them seperately will always add upto the `initialTokenSupply`. But if there is rounding error in the `calculatePoriton` calculation this will result in dust amount being stuck in the `tokenManager` contract.

### Tools Used
Manual review
### Recommended Mitigation Steps
Hence recommended to calculate the `leftOverSupply` amount as follows:

```solidity
        uint256 leftoverSupply = initialTokenSupply - bondingCurveSupply
```

## L-03 Recommended to have an `address(0)` check in the `BaseFeeLayer::_setFeeReceiver` function

### Lines of code

https://github.com/ggQuest/core/blob/stable/contracts/guilds/fees/BaseFeeLayer.sol#L68-L71
https://github.com/ggQuest/core/blob/stable/contracts/guilds/types/Currency.sol#L20

### Vulnerability details

In the smartcontracts of the `Guild` repo for configuration changes of the `addresses` performed by the `admin` role `address(0)` check is performed.

```solidity
    function _setFeeReceiver(address newReceiver) internal {
        BaseFeeLayerStorage storage $ = _getBaseFeeLayerStorage();
        $._feeReceiver = newReceiver; //@audit-issue - recommended to have an address(0) check here
    } 
```

But same can not be seen in the above `BaseFeeLayer::_setFeeReceiver` function when a `newReceiver` address is being set. Since `feeReceiver` is an address which is receiving funds it is recommended to have an `address(0)` check as a precaution (Even though it is an admin controlled function).

This check is even more important since the actual fund transfer happens in the `Currency.sol::transfer` as shown below:

```solidity
    function transfer(Currency currency, address to, uint256 amount) internal {
        bool success;
        if (currency.isAddressZero()) { //@audit-info - if the currency is address(0)
            // solhint-disable-next-line avoid-low-level-calls
            (success, ) = to.call{value: amount}("");
            if (!success) revert NativeTransferFailed();
        } else {
            // solhint-disable-next-line avoid-low-level-calls
            (success, ) = Currency.unwrap(currency).call(abi.encodeWithSelector(IERC20.transfer.selector, to, amount));
            if (!success) revert ERC20TransferFailed();
        }
    }
```

When the `currency.isAddressZero()` for the fee paid as`ETH` the `to.call{value: amount}("")` will always return `true` if the `to address is address(0)`. Hence this will be loss of funds to the protocol.

### Tools Used
Manual review
### Recommended Mitigation Steps
It is recommended to implement an `address(0)` check for the `to address` in this `Currency.sol::transfer` as well before the `ETH fees` are transferred to the `to address`.

## L-04 Return value of `IERC20.approve` function is not checked

### Lines of code

https://github.com/ggQuest/core/blob/stable/contracts/guilds/BondingCurve.sol#L143
https://github.com/ggQuest/core/blob/stable/contracts/guilds/BondingCurve.sol#L152

### Vulnerability details

In the `BondingCurve::migrate` function the `liquidityReserve` amount of the `rawToken` is approved to the `_uniswapV2Router` contract before the `_uniswapV2Router().addLiquidityETH` is called to apply allowance of the `rawToken` amount to be transferred to the liquidity pool.

But the issue is the return boolean value is not checked.

The transaction will revert without necessary approval during `addLiquidityETH` call if  `the approve` function returned `false`.

Hence as a best practice it is recommended to check the boolean return value of the `approve` fucntion for `true` before proceeding with the `_uniswapV2Router().addLiquidityETH` call

Similarly during the `LPToken` burn making the transfer to `address(0)`, the return boolean value is not checked as shown below:

```solidity
        IERC20(pairAddress).transfer(address(0), lpTokens);
```

### Tools Used
Manual review
### Recommended Mitigation Steps
Hence it is recommeded to check the Boolean return value for the above operation as well.

## L-05 Redundant check in the `GuildToken::_checkValidTransfer`

### Lines of code

https://github.com/ggQuest/core/blob/stable/contracts/guilds/GuildToken.sol#L51

### Vulnerability details

In the `GuildToken::_checkValidTransfer` function the following check is given :

```solidity
        if (from == address(0) || to == address(0)) return;
```

This check skips the remainder of the funciton if `either from == address(0)` or `to == address(0)`. This is done to ensure `it is possible to transfer tokens` during minting and burning as per the natspec comments:

> // if minting/burning

But there is no `transfer` transaction happening during `minting and burning` as per the `ERC20Upgradeable` contract.

```solidity
    function _mint(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(address(0), account, value);
    }
```

```solidity
    function _burn(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        _update(account, address(0), value);
    }
```

Furthermore `from == to == address(0)` is restricted in the `ERC20Upgradeable` as shown below:

```solidity
    function _transfer(address from, address to, uint256 value) internal {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(from, to, value);
    }
```

Hence should not be allowed to transfer to `to == from == address(0)` in the `GuildToken::_checkValidTransfer` since anyway it is going to revert in the parent contract.

### Tools Used
Manual review
### Recommended Mitigation Steps
Hence it is recommended to remove the above redundant conditional check (`if (from == address(0) || to == address(0)) return`).

## L-06 Should use `Ownable2StepUpgradeable.sol` inplace of `OwnableUpgradeable.sol`

### Lines of code

https://github.com/ggQuest/core/blob/stable/contracts/rewards/holders/RewardHolder.sol#L29
https://github.com/ggQuest/core/blob/stable/contracts/rewards/holders/RewardHolder.sol#L33

### Vulnerability details

The `RewardHolder::setQuestFactory` and `RewardHolder::setRewardClaimer` functions can only be called by the `owner` since they are access controlled by the `onlyOwner` modifier.

The `onlyOwner` modifier is inherited from the `OperatableUpgradeable` which inherits it from the `OwnableUpgradeable` contract.

But in the event of an ownership transfer `OwnableUpgradeable` uses a single step ownership transfer which is not the best practice. 

### Tools Used
Manual review
### Recommended Mitigation Steps
Hence it is recommended to use `Ownable2StepUpgradeable.sol` inplace of `OwnableUpgradeable.sol`. The `Ownable2StepUpgradeable.sol` uses two step ownership transfer process which allows the `proposed owner` to be set as the `pending owner` and the `pending owner` should call the `Ownable2StepUpgradeable::acceptOwnership` to accept his ownership of the contract.

## L-07 Discrepancy in how the `markecap for BondingCurve` is calculated

### Lines of code

https://github.com/ggQuest/core/blob/stable/contracts/guilds/BondingCurve.sol#L468

### Vulnerability details

In the `BondingCurve::_getMarketCapUniswapV2` function the marketcap for UniswapV2 is calculated as follows:

```solidity
        uint256 price = _getTokenPriceUniswapV2();
        return (totalSupply * price) / PRICE_SCALING_FACTOR; 
```

Here the `totalSupply` is multiplied by the `scaledUp price` and then divided by the `PRICE_SCALING_FACTOR` to scale down. This will ensure the `rounding error` is minimal or non-existent.

But now let's consider how the `marketcap for the BondingCurve` is calculated.

```solidity
        return (ethReserveVirtual * IERC20Metadata(Currency.unwrap(token)).totalSupply()) / tokenReserveVirtual;
```

As you could it merely calculates the `marketCap` without proper scaling and as a result if the `totalSupply` is small could result in rounding error. Hence the returned `marketcap for the BondingCurve` will not be precise.

### Tools Used
Manual review
### Recommended Mitigation Steps
The `BondingCurve token price` is calculated as follows:

```solidity
    function _getTokenPriceCurve() internal view returns (uint256) {
        return (ethReserveVirtual * 10 ** PRICE_SCALING_FACTOR) / tokenReserveVirtual;
    } 
```

Hence during the `BondingCruve market cap` calculation this `token price can be used` instead as shown below:

```solidity
    function _getTokenPriceCurve() internal view returns (uint256) {
  (IERC20Metadata(Currency.unwrap(token)).totalSupply()) * _getTokenPriceCurve) / PRICE_SCALING_FACTOR
}
```

This will ensure `consistency` during `market cap calculation` for both the `BondingCurve` and `UniswapV2`.

# Gas Optimisations

## G-01 _update function can be removed to reduce codesize and the deployment cost

In `GuildToken` contract we have the `_update` method  which calls the `_update` method in the `ERC20Upgradeable` contract without any custom logic, so that method can be removed thereby removing code size and deployment cost.
