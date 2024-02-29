# Audit Report for Renft
Link - https://github.com/code-423n4/2024-01-renft

Auditor 
- https://twitter.com/Udsen3
- https://twitter.com/Viraz04

# Findings

## M-01 _deriveOrderMetadataHash does not use all encoded values defined in orderMetadataTypeString 

# Lines of code

https://github.com/re-nft/smart-contracts/blob/3ddd32455a849c3c6dc3c3aad7a33a6c9b44c291/src/policies/Stop.sol#L265
https://github.com/re-nft/smart-contracts/blob/3ddd32455a849c3c6dc3c3aad7a33a6c9b44c291/src/modules/PaymentEscrow.sol#L100


# Vulnerability details

## Impact
if an order involves erc777 token for a pay order then in the `tokensReceived` callback the renter can create DOS situation resulting in the lender's assets being stuck in the rental safe

## Proof of Concept
[ERC777 token standard](https://eips.ethereum.org/EIPS/eip-777) which is backward compatible with `erc20` implies that on the transfer of the tokens the recipient can implement a `tokensReceived` hook to notify of any increment of the balance.

Now suppose a pay order is created with an erc 777 consideration asset as there is no restriction on that and also the eip specifies that
```
The difference for new contracts implementing ERC-20 is that tokensToSend and tokensReceived hooks take precedence over ERC-20. Even with an ERC-20 transfer and transferFrom call, the token contract MUST check via ERC-1820 if the from and the to address implement tokensToSend and tokensReceived hook respectively. If any hook is implemented, it MUST be called. Note that when calling ERC-20 transfer on a contract, if the contract does not implement tokensReceived, the transfer call SHOULD still be accepted even if this means the tokens will probably be locked.
```
so the `tokensReceived` hook is optional for a `transfer/transferFrom` call. Hence sending the assets from the lender's wallet to the escrow contract shouldn't be an issue.

Now when the rental period is over or in/between, the `stopRent` method in stop policy is called, which calls `settlePayment` in escrow module. Now on the token transfer
```
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, value)
        );
```
the `tokensReceived` hook if implemented by the renter, would be called and they could just `revert the tx` inside the `tokensReceived` hook which would mean that the assets lent by the lender are locked forever.

## Tools Used
manual review

## Recommended Mitigation Steps
It is recommended to prohibit erc777 tokens from being used as consideration items.

## M-02 The rentPayloadTypeHash calculation in the Signer._deriveRentalTypehashes does not follow the EIP712 standard thus leading to unintended behaviour with off-chain tools

# Lines of code

https://github.com/re-nft/smart-contracts/blob/3ddd32455a849c3c6dc3c3aad7a33a6c9b44c291/src/packages/Signer.sol#L394-L400
https://github.com/re-nft/smart-contracts/blob/3ddd32455a849c3c6dc3c3aad7a33a6c9b44c291/src/packages/Signer.sol#L389-L391


# Vulnerability details

## Impact

In the `Signer._deriveRentalTypehashes` function the `rentPayloadTypeHash` hash is derived as follows:

      rentPayloadTypeHash = keccak256(
          abi.encodePacked(
              rentPayloadTypeString,
              orderMetadataTypeString,
              orderFulfillmentTypeString
          )
      );

The `RentPayload` struct has two referenced structs namely `OrderFulfillment` and `OrderMetadata`.

The EIP712 states the below with respect to referenced structs inside a main struct when it comes to deriving the `typeHash`.

**If the struct type references other struct types (and these in turn reference even more struct types), then the set of referenced struct types is collected, sorted by name and appended to the encoding. An example encoding is Transaction(Person from,Person to,Asset tx)Asset(address token,uint256 amount)Person(address wallet,string name).**

As the EIP712 states the `reference structs` must be sorted by name and appended to the encoding.
But in the `rentPayloadTypeHash` computation, the reference structs seem to be not sorted before concatenating to hash.

Hence the `rentPayloadTypeHash` typeHash computation does not follow the EIP 712 correctly. This could be problematic if an off-chain tool uses a particular `rentPayload` struct for hash calculation using the correct `EIP712 format` thus creating a discrepancy between the `reNFT` calculated `rentPayloadTypeHash` and off-chain calculated `rentPayloadTypeHash`. Hence this could lead to numerous unintended behavior in the future when `reNFT` protocol expands and used by other off-chain tools.

## Proof of Concept

```solidity
      rentPayloadTypeHash = keccak256(
          abi.encodePacked(
              rentPayloadTypeString,
              orderMetadataTypeString,
              orderFulfillmentTypeString
          )
      );
```

https://github.com/re-nft/smart-contracts/blob/3ddd32455a849c3c6dc3c3aad7a33a6c9b44c291/src/packages/Signer.sol#L394-L400

```solidity
      bytes memory rentPayloadTypeString = abi.encodePacked(
          "RentPayload(OrderFulfillment fulfillment,OrderMetadata metadata,uint256 expiration,address intendedFulfiller)"
      );
```

https://github.com/re-nft/smart-contracts/blob/3ddd32455a849c3c6dc3c3aad7a33a6c9b44c291/src/packages/Signer.sol#L389-L391

## Tools Used
Manual Review and VSCode

## Recommended Mitigation Steps

Hence it is recommended to correct the typeHash calculation of the `rentPayloadTypeHash` according to the `EIP712` standard as follows:

      rentPayloadTypeHash = keccak256(
          abi.encodePacked(
              rentPayloadTypeString,
              orderFulfillmentTypeString,
              orderMetadataTypeString
           )
      );

Here the `reference struct types` are sorted correctly and then appended for encoding and `keccak256 hashing`.

## M-03 DOS possible while stopping a rental with erc777 tokens
# Lines of code

https://github.com/re-nft/smart-contracts/blob/3ddd32455a849c3c6dc3c3aad7a33a6c9b44c291/src/policies/Stop.sol#L265
https://github.com/re-nft/smart-contracts/blob/3ddd32455a849c3c6dc3c3aad7a33a6c9b44c291/src/modules/PaymentEscrow.sol#L100


# Vulnerability details

## Impact
if an order involves erc777 token for a pay order then in the `tokensReceived` callback the renter can create DOS situation resulting in the lender's assets being stuck in the rental safe

## Proof of Concept
[ERC777 token standard](https://eips.ethereum.org/EIPS/eip-777) which is backward compatible with `erc20` implies that on the transfer of the tokens the recipient in case not an eoa has to implement a `tokensReceived` hook

Now suppose a pay order is created with an erc 777 consideration asset as there is no restriction on that and also the eip specifies that
```
The difference for new contracts implementing ERC-20 is that tokensToSend and tokensReceived hooks take precedence over ERC-20. Even with an ERC-20 transfer and transferFrom call, the token contract MUST check via ERC-1820 if the from and the to address implement tokensToSend and tokensReceived hook respectively. If any hook is implemented, it MUST be called. Note that when calling ERC-20 transfer on a contract, if the contract does not implement tokensReceived, the transfer call SHOULD still be accepted even if this means the tokens will probably be locked.
```
so the `tokensReceived` hook is optional for a `transfer/transferFrom` call so it so sending the assets from the lenders wallet to the escrow contract shouldn't be an issue

Now when the rental period is over or in/between the `stopRent` method in stop policy is called, which calls `settlePayment` in escrow module now on the token transfer
```
  (bool success, bytes memory data) = token.call(
      abi.encodeWithSelector(IERC20.transfer.selector, to, value)
  );
```
the `tokensReceived` if implemented by the renter would be called and they could just revert the tx which would mean that the assets lent by the lender are locked forever

## Tools Used
manual review
## Recommended Mitigation Steps
either have a check that the renter should only be an eoa or restrict an erc777 tokens as consideration items

## M-04 The _order_metadata_typehash does not include the referenced struct hook during its type hash calculation thus leading to unintended behaviour

# Lines of code

https://github.com/re-nft/smart-contracts/blob/3ddd32455a849c3c6dc3c3aad7a33a6c9b44c291/src/packages/Signer.sol#L406
https://github.com/re-nft/smart-contracts/blob/3ddd32455a849c3c6dc3c3aad7a33a6c9b44c291/src/packages/Signer.sol#L384-L386
https://github.com/re-nft/smart-contracts/blob/3ddd32455a849c3c6dc3c3aad7a33a6c9b44c291/src/packages/Signer.sol#L357-L359


# Vulnerability details

## Impact

The `_ORDER_METADATA_TYPEHASH` is calculated in the `Signer._deriveRentalTypehashes` as shown below:

```solidity
      bytes memory orderMetadataTypeString = abi.encodePacked(
          "OrderMetadata(uint8 orderType,uint256 rentDuration,Hook[] hooks,bytes emittedExtraData)"
      );
```

As it is seen the `type` includes the `Hook struct` as a reference and it should be `concatenated` before calculating the typeHash as stated by the EIP712 standard shown below:

**If the struct type references other struct types (and these in turn reference even more struct types), then the set of referenced struct types is collected, sorted by name and appended to the encoding.**

But above EIP712 definition is not followed while computing the `orderMetadataTypeHash` as shown below:

```solidity
      // Derive the OrderMetadata type hash using the corresponding type string.
      orderMetadataTypeHash = keccak256(orderMetadataTypeString);
```

The `referenced struct type` (Hook - "Hook(address target,uint256 itemIndex,bytes extraData)") is not appended in the encoding of the `orderMetadataTypeHash`. Hence the `orderMetadataTypeHash` does not follow the `EIP712` standard while computing the `typeHash`.

This could be problematic if an off-chain tool uses a particular `OrderMetadata` struct for hash calculation using the correct `EIP712 format` thus creating a discrepancy between the `reNFT` calculated `orderMetadataTypeHash` and off-chain calculated `orderMetadataTypeHash`. Hence this could lead to numerous unintended behavior in the future when `reNFT` protocol expands and used by other off-chain tools.

## Proof of Concept

```solidity
      orderMetadataTypeHash = keccak256(orderMetadataTypeString);
```

https://github.com/re-nft/smart-contracts/blob/3ddd32455a849c3c6dc3c3aad7a33a6c9b44c291/src/packages/Signer.sol#L406

```solidity
      bytes memory orderMetadataTypeString = abi.encodePacked(
          "OrderMetadata(uint8 orderType,uint256 rentDuration,Hook[] hooks,bytes emittedExtraData)"
      );
```

https://github.com/re-nft/smart-contracts/blob/3ddd32455a849c3c6dc3c3aad7a33a6c9b44c291/src/packages/Signer.sol#L384-L386

```solidity
  bytes memory hookTypeString = abi.encodePacked(
      "Hook(address target,uint256 itemIndex,bytes extraData)"
  );
```

https://github.com/re-nft/smart-contracts/blob/3ddd32455a849c3c6dc3c3aad7a33a6c9b44c291/src/packages/Signer.sol#L357-L359

## Tools Used
Manual Review and VSCode

## Recommended Mitigation Steps

The `orderMetadataTypeHash` computation should be corrected to follow the EIP712 standard as shown below:

```solidity
      orderMetadataTypeHash = keccak256(abi.encodePacked( orderMetadataTypeString, hookTypeString));
```

Here the hookTypeString which is a `referenced struct type` is appended to the `orderMetadataTypeString` thus correctly following the EIP712 standard.

# M-05 A single malicous lender can revert the `stop.stoprentbatch` transaction inside the `onerc721received` hook while receiving the `erc721` tokens back

# Lines of code

https://github.com/re-nft/smart-contracts/blob/3ddd32455a849c3c6dc3c3aad7a33a6c9b44c291/src/policies/Stop.sol#L353
https://github.com/re-nft/smart-contracts/blob/3ddd32455a849c3c6dc3c3aad7a33a6c9b44c291/src/packages/Reclaimer.sol#L90-L100
https://github.com/re-nft/smart-contracts/blob/3ddd32455a849c3c6dc3c3aad7a33a6c9b44c291/src/packages/Reclaimer.sol#L32-L34


# Vulnerability details

## Impact

The `Stop.stopRentBatch` function is used to `stop` a batch of rentals by providing an array of `RentalOrder` structs to the function.

For each of the `RentalOrders` in the struct the `Stop._reclaimRentedItems` function is called as shown below:

```solidity
        _reclaimRentedItems(orders[i]);
```

The `_reclaimRentedItems` function calls the `Stop.reclaimRentalOrder` function via a `delegateCall` from the `Gnosis safe`. In the `reclaimRentalOrder` function the `ERC721` or `ERC1155` is transferred to the `lender` for each of the `Items` as shown below:

```solidity
    // Transfer each item if it is a rented asset.
    for (uint256 i = 0; i < itemCount; ++i) { //@audit-info - struct Item { ItemType itemType; SettleTo settleTo; address token; uint256 amount; uint256 identifier; }
        Item memory item = rentalOrder.items[i]; //@audit-info - cache each item

        // Check if the item is an ERC721.
        if (item.itemType == ItemType.ERC721) //@audit-info - enum ItemType { ERC721, ERC1155, ERC20 }
            _transferERC721(item, rentalOrder.lender); //@audit-info - transfer the ERC721 to the lender

        // check if the item is an ERC1155.
        if (item.itemType == ItemType.ERC1155)
            _transferERC1155(item, rentalOrder.lender); //@audit-info - transfer the ERC1155
    }
```

Let's consider the case of `ERC721`. Here the `_transferERC721` function call is as follows:

```solidity
function _transferERC721(Item memory item, address recipient) private {
    IERC721(item.token).safeTransferFrom(address(this), recipient, item.identifier);
}
```

The `safeTransferFrom` is called on the ERC721 contract to transfer the token to the `lender`. Since the `ERC721.safeTransferFrom` calls the `onERC721Received` hook on the `lender`, a malicious lender can revert this transaction by calling `revert` inside the `onERC721Received` hook. This will revert the entire `Stop.stopRentBatch` batch transaction thus not allowing other `lenders` to receive their respective `ERC721` and `ERC1155` tokens.

As a result each of the `rentalOrders` will have to be `stopped` by calling them individually via the `Stop.stopRent` function. Hence there will be delay in `lenders` getting their `NFTs` back since each order has to be `stopped` individually. This could incur monetary loss to the `lender` since he could have used the `NFTs` for another purpose (`such as gaming`) if he received the NFT earlier. And this is not good for the user experience as well. The users might lose the trust on the `reNFT` if they are unable to use the `stopRentBatch` feature and having to go through the cumbersome process of having to stop one rentalOrder at a time.

## Proof of Concept

```solidity
        _reclaimRentedItems(orders[i]);
```

https://github.com/re-nft/smart-contracts/blob/3ddd32455a849c3c6dc3c3aad7a33a6c9b44c291/src/policies/Stop.sol#L353

```solidity
    for (uint256 i = 0; i < itemCount; ++i) {
        Item memory item = rentalOrder.items[i];

        // Check if the item is an ERC721.
        if (item.itemType == ItemType.ERC721)
            _transferERC721(item, rentalOrder.lender);

        // check if the item is an ERC1155.
        if (item.itemType == ItemType.ERC1155)
            _transferERC1155(item, rentalOrder.lender);
    }
```

https://github.com/re-nft/smart-contracts/blob/3ddd32455a849c3c6dc3c3aad7a33a6c9b44c291/src/packages/Reclaimer.sol#L90-L100

```solidity
function _transferERC721(Item memory item, address recipient) private {
    IERC721(item.token).safeTransferFrom(address(this), recipient, item.identifier);
}
```

https://github.com/re-nft/smart-contracts/blob/3ddd32455a849c3c6dc3c3aad7a33a6c9b44c291/src/packages/Reclaimer.sol#L32-L34

## Tools Used
Manual Review and VSCode

## Recommended Mitigation Steps

Hence it is recommended to execute the `_reclaimRentedItems(orders[i])` function call inside a `try-catch` block and handle the single `rentalOrder` reverts via a `fallback` appropriately. This will ensure a single `malicious` lender is unable to deprive other lenders getting their `ERC721 and ERC1155` tokens on time and also unable to deprive `renters` getting their `ERC20 tokens` (In the event of a `PAY` order) when the `Stop.stopRentBatch` is called.

# L-01 Missing salt paramter in EIP 712 `eip712DomainTypehash` calculation

## Lines of code

https://github.com/re-nft/smart-contracts/blob/3ddd32455a849c3c6dc3c3aad7a33a6c9b44c291/src/packages/Signer.sol#L279

## Impact
 [EIP 712](https://eips.ethereum.org/EIPS/eip-712) specifies that a `salt` param can be used for the domain type has calculation to fully adhere to the specification whereas in this case it is not the case

## Tools Used
manual review
## Recommended Mitigation Steps
Consider `salt` when calculating `eip712DomainTypehash`

# L-02 hook item index can be out of bounds with the offer & rental item array

## Lines of code

https://github.com/re-nft/smart-contracts/blob/3ddd32455a849c3c6dc3c3aad7a33a6c9b44c291/src/policies/Create.sol#L488

https://github.com/re-nft/smart-contracts/blob/3ddd32455a849c3c6dc3c3aad7a33a6c9b44c291/src/policies/Stop.sol#L218

## Impact
There is no check that the item index in the hook array is valid when adding or removing hooks which might result in tx revert when creating/stopping a rental

## Tools Used
manual review
## Recommended Mitigation Steps
add a validation check to make sure that `itemIndex <= offer.length/rental.length`

# L-03 No check for contract bytecode size during create2 deployment

## Lines of code
https://github.com/re-nft/smart-contracts/blob/3ddd32455a849c3c6dc3c3aad7a33a6c9b44c291/src/Create2Deployer.sol#L54

## Impact
deploying a contract without any bytecode will be a waste of execution overhead & gas

## Tools Used
manual review
## Recommended Mitigation Steps
add a check `if(iszero(extcodesize(deploymentAddress))) revert();`

# L-04 Avoid reacasting the `Module` instance again 

## Lines of code
https://github.com/re-nft/smart-contracts/blob/3ddd32455a849c3c6dc3c3aad7a33a6c9b44c291/src/Kernel.sol#L514

## Impact
The `getModuleForKeycode` mapping returns the module instance after casting so we can avoid re-casting to save gas

## Tools Used
manual review
## Recommended Mitigation Steps
remove re-casting of the module instance

# L-05 Use `abi.encodePacked` for computing eip 712 typehashes

## Lines of code

https://github.com/re-nft/smart-contracts/blob/3ddd32455a849c3c6dc3c3aad7a33a6c9b44c291/src/packages/Signer.sol#L373

## Impact
To completely adhere to the  [EIP 712 standard](https://eips.ethereum.org/EIPS/eip-712) `abi.encodePacked` should be used instead of `abi.encode` when comoputing `rentalOrderTypeHash`

## Tools Used
manual review
## Recommended Mitigation Steps
use `abi.encodePacked` instead of `abi.encode` when comoputing `rentalOrderTypeHash`

# L-06 Remove extra hook validation check in guard policy

## Lines of code

https://github.com/re-nft/smart-contracts/blob/3ddd32455a849c3c6dc3c3aad7a33a6c9b44c291/src/policies/Guard.sol#L338

## Impact
`STORE.hookOnTransaction` returns whether a hook is valid or not but there is an extra check(`hook != address(0)`) to determine hook validity when a tx is triggered which is not necessary and costs extra gas


## Tools Used
manual review
## Recommended Mitigation Steps
update the if statement to `if(isActive)`

## L-07 Admin policy contract unintentionally can be used to withdraw all funds in escrow module using skim

# Lines of code

https://github.com/re-nft/smart-contracts/blob/3ddd32455a849c3c6dc3c3aad7a33a6c9b44c291/src/modules/PaymentEscrow.sol#L397
https://github.com/re-nft/smart-contracts/blob/3ddd32455a849c3c6dc3c3aad7a33a6c9b44c291/src/policies/Admin.sol#L164


# Vulnerability details

## Impact
[proxied tokens](https://github.com/d-xo/weird-erc20/tree/main?tab=readme-ov-file#multiple-token-addresses) have multiple token addresses so it can result in a mismatch of the `balanceOf` mapping and actual token balance sent to escrow due to a different address

## Proof of Concept
Let's consider the scenario where a particular proxied token with multiple addresses is used as a token in this protocol.

For example, if the token has Address A and Address B

When the fungible tokens are transferred to the payment escrow contract either directly or through the existence of an active rental, token address A is used,
so the balanceOf[token] mapping is updated for Address A.

Then the Policy contract decides to collect the fees for the above token and calls the skim function with address B.

Now the balanceOf[address B] will be zero, but the IERC20(address B).balanceOf(address(this)) will provide the total balance of the token stored in the PaymentEscrow contract.

As a result, the skimmedBalance = trueBalance - syncedBalance will result in the skimmedBalance = trueBalance.

Hence the Policy contract will be able to withdraw all the funds in the contract to the recipient address and this includes the funds reserved to be distributed to the lenders and renters as well.

## Tools Used
foundry
## Recommended Mitigation Steps
Add a check in `skim` method
```
if (balanceOf[token] == 0 && IERC20(token).balanceOf(address(this)) > 0) revert();
```


## L-08 _emitRentalOrderStopped emits wrong seaport order hashes for stopping multiple rentals 

 # Lines of code

https://github.com/re-nft/smart-contracts/blob/3ddd32455a849c3c6dc3c3aad7a33a6c9b44c291/src/policies/Stop.sol#L356


# Vulnerability details

## Impact
When stopping multiple orders, the `_emitRentalOrderStopped` is emitted with rental order hash instead of `seaportOrderHash` which will lead to invalid order hashes being emitted and affecting off-chain rendering and processing

## Proof of Concept
When multiple orders are stopped `_emitRentalOrderStopped` is emitted multiple times with rental order hash instead of the `seaportOrderHash` which will lead to processing and rendering of invalid data off-chain

```
        // Add the order hash to an array.
        orderHashes[i] = _deriveRentalOrderHash(orders[i]);

        // Interaction: Process hooks so they no longer exist for the renter.
        if (orders[i].hooks.length > 0) {
            _removeHooks(orders[i].hooks, orders[i].items, orders[i].rentalWallet);
        }

        // Interaction: Transfer rental assets from the renter back to lender.
        _reclaimRentedItems(orders[i]);

        // Emit rental order stopped.
        _emitRentalOrderStopped(orderHashes[i], msg.sender);
```

whereas when a single rental is stopped the correct `seaportOrderHash` is emitted
```
function stopRent(RentalOrder calldata order) external {

_emitRentalOrderStopped(order.seaportOrderHash, msg.sender);
```

this can lead to unexpected issues ux wise, processing data off-chain etc

## Tools Used
manual review
## Recommended Mitigation Steps
emit `_emitRentalOrderStopped` with the correct order hash
```
_emitRentalOrderStopped(order[i].seaportOrderHash , msg.sender);
