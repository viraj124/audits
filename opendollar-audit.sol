# Audit Report for OpenDollar
Link - https://github.com/code-423n4/2023-10-opendollar

Auditor 
- https://twitter.com/supernovahs444
- https://twitter.com/Viraz04

# Findings

## [H-01] surplusTransferPercentage will always be less than 1%

# Lines of code

https://github.com/open-dollar/od-contracts/blob/v1.5.5-audit/src/contracts/AccountingEngine.sol#L199


# Vulnerability details

## Impact
The protocol has a feature to auction the surplus amount and send some % out of that to `extraSurplusReceiver` but currently this % always less than 1% which limits the amount `extraSurplusReceiver` can get out of the surplus

## Proof of Concept
we believe this check is incorrect `if(_params.surplusTransferPercentage > WAD) revert AccEng_surplusTransferPercentOverLimit();` since this basically means that `surplusTransferPercentage` cannot be more than 1% thereby adding an unnecessary restriction in the protocol

## Tools Used
manual review
## Recommended Mitigation Steps
change this check `if(_params.surplusTransferPercentage > WAD) revert AccEng_surplusTransferPercentOverLimit();` to `if(_params.surplusTransferPercentage > ONE_HUNDRED_WAD) revert AccEng_surplusTransferPercentOverLimit();`


## Assessed type

Invalid Validation

## [M-01] SAFEHandler cannot call allowHandler & there is no access control in allowHandler

# Lines of code

https://github.com/open-dollar/od-contracts/blob/v1.5.5-audit/src/contracts/proxies/ODSafeManager.sol#L112
https://github.com/open-dollar/od-contracts/blob/v1.5.5-audit/src/contracts/proxies/SAFEHandler.sol#L11


# Vulnerability details

## Impact
The ODSafeManager has a mapping `handlerCan` where according to the docs the key is the `SAFEHandler` contract address but first of all, there is no access control check that `msg.sender` in `allowHandler` is an existing `SAFEHandler` contract and secondly `SAFEHandler` has no method to call `allowHandler` method in safe manager which means anyone can update the mapping and `handlerCan` is used in a modifier `handlerAllowed` which is used for access control in various methods involving safe related operations like `quitSystem` & `enterSystem` and hence this breaks the access control check in these functions

## Proof of Concept
there is no method to call `allowHandler` in `SAFEHandler` and secondly alice can call `allowHandler` and pass any arbitary address there even her own address as the `_usr` argument and break the handler access control

## Tools Used
manaual review
## Recommended Mitigation Steps
add a method `allowHandler` in `SAFEHandler` that can only be called by the owner of the safe and also add access control check in `allowHandler` that `msg.sender` is a valid safe by passing an extra `safeOwner` address in the method to verify that


## Assessed type

Access Control
