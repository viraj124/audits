# Audit Report for SuperBoardNFT
Link - https://gist.github.com/prakhar-su/f19f1bc43f659b3afa78c3d4ea7edc79

Auditor 
- https://twitter.com/supernovahs444
- https://twitter.com/Viraz04

# Findings

## High

### H-01  Wrong implementation of SoulBound token


## Summary
As per the team, they want to be able to create soulbound NFT if they want. Soulbound tokens have characteristic that they cannot be transferred and nor be able to burned. According to current implementation, all transfers are restricted and anyone can burn their token.

The current implementation neither follows the ERC1155 standard completely nor the soul bound token charactersticks. 


### Recommendation

If Admin wants ability to create soulbound and normal tokens both in the same contract, they should map this information in a mapping as to whether the token being created will be soulbound or not.

If its a soulbound token:-
- Owner should not be able to transfer and burn.

If not a soulbound token:-
- Owner should be able to transfer and burn.


Code Reference

https://gist.github.com/prakhar-su/f19f1bc43f659b3afa78c3d4ea7edc79#file-gistfile1-txt-L173-L191

### H-02 If a sender has approved someone else then transfer will fail

## Summary
There is a address check on `msg.sender` here https://gist.github.com/prakhar-su/f19f1bc43f659b3afa78c3d4ea7edc79#file-gistfile1-txt-L173 

### Recommendation
Remove the address check


## Low

### L-01 Event should be indexed

Please check the following code block with audit tags.

```!solidity
    // @audit tokenId, totalSupply should be indexed
    // Event declarations
    event SuperBoardNFTCreated(
        uint256 tokenId,
        uint256 totalSupply,
        bool isUnlimited,
        string uri
    );

    // @audit questId should be indexed
    event QuestCompletedAndRewardGiven(
        address indexed account,
        uint256 questId
    );

    // @audit tokenId should be indexed
    event URIUpdated(uint256 tokenId, string newUri);
```

### L-02  Use latest Solidity Version.
Instead of using `0.8.4` , use more latest version => `0.8.20``


## Gas 

### G-01 `_tokenURIs` can be used to check if tokenid exists.

Instead of using a completely new storage slot, `_tokenURIs` can be used to check if the given token exists. 
By checking 
```!solidity
require(_tokenURIs[_tokenId] != "");
```
But for this , code should not allow empty strings to be set as URIs 
https://gist.github.com/prakhar-su/f19f1bc43f659b3afa78c3d4ea7edc79#file-gistfile1-txt-L146

### G-02 Do not initialize to default value

https://gist.github.com/prakhar-su/f19f1bc43f659b3afa78c3d4ea7edc79#file-gistfile1-txt-L31

### G-03 UUPS_init() should only be called once
https://gist.github.com/prakhar-su/f19f1bc43f659b3afa78c3d4ea7edc79#file-gistfile1-txt-L49

### G-04 Set supply only when isUnlimited is false 
https://gist.github.com/prakhar-su/f19f1bc43f659b3afa78c3d4ea7edc79#file-gistfile1-txt-L105

### G-05 Remove the renundant balance check for gas savings
https://gist.github.com/prakhar-su/f19f1bc43f659b3afa78c3d4ea7edc79#file-gistfile1-txt-L175

##  Analysis Report

- When upgrading, append new storage slots at the end of the last slot otherwise it can lead to storage corruption.

- We highly recommend testing all contracts with foundry before deploying.

- Use latest version of openzeppelin packages only.
