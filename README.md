# 🚩 Landplot Marketplace Design.


## **Marketplace** and **Landplot** contract 📋

- Marketplace Contract:  
  A blockchain-based marketplace enables crypto payments and intermediary-free exchange of goods between sellers and buyers. Buyers can view the origins and history of goods stored on the blockchain, which builds trust to sellers and makes the deals more transparent.

- Landplot Contract:
 The conceptual approach to registration of land plots as spatial objects using blockchain technology is proposed. The land plot should be considered as a combination of smart contracts between landowners, surveyors, appraisers, notaries and other persons.


## **All Function Table** 🖥️

| Contract    | Function name    | Note          |
| ----------- | ---------------- | ------------- |
| Marketplace | onERC721Received | `Main Action` |
| Marketplace | newAuction       | `Main Action` |
| Marketplace | cancelAuction    | `Main Action` |
| Marketplace | bidAuction       | `Main Action` |
| Marketplace | endAuction       | `Main Action` |
| Marketplace | getTokenId       | `Main Action` |
| Marketplace | getPurchaseInfo  | `Main Action` |
| Marketplace | newPurchase      | `Main Action` |
| Marketplace | cancelPurchase   | `Main Action` |
| Marketplace | acceptPurchase   | `Main Action` |


## LandPlot(NFT) contract improvements: 🔧
• Ensure that NFT with ID 0 and Coordinate 0,0 is minted to the contract owner. 

• Getting the coordinates for an NFT that has not yet been minted should be 0,0
  
• Getting the NFT for which there are no matching coordinates should fail

• minting function should be rewritten to ensure that duplicates cannot be written

• rename the stupid variables (for some reason _worldSize is the amount of minted nfts, i was crazy or something)

• Change the admin minting function and the user minting function such that they use the same underlying implementation, simply a different user

• Add a “multitransfer” function that allows the user to send more than 1 Plot to an address at once.

• Create ILandPlot.sol, and in general reformat/rewrite contract to fit common solidity standards
  
• Test should ensure that all rules for token minting is being followed (priced being paid, size within constraints)

## Simple LandPlot Auction House Contract: 🔧
• User looking to sell should be able to put any ERC721 compliant token up for auction. 

• User looking to sell should be able to put multiple ERC721 compliant tokens up for auction as a "bundle" for a single price

• User looking to sell can cancel their auction at any time, returning all eth to bidders.

• User looking to buy should be able to see the ids of tokens that are up for auction 

• User looking to buy should be able to see an array of ids of a token bundle that is up for auction

• User looking to buy should be able to see information about the auction (current price, blocks remaining, who the current highest bidder is)

• User looking to buy should be able to bid using with a payable function

• The ETH of the highest bid is locked up, but if another user outbids the previous highest bidder, the eth is automatically returned.

• Once the auction ends (period specified initially by the user selling), the eth is automatically sent to the sellers wallet and NFT to the winning bidder.

• Additionally, a user may put out a “bid” to purchase a specific ERC721 by inputting the ERC721 contract address, tokenId, and expiration time (max 1 week), along with sending some eth. The owner of that token may then, before the week expires, claim that “bid” and receive the eth, sending the ERC721 token off to the bidder.

• Create IMarketplace.sol, or whatever you call it all normal standards ofc
Test should ensure that funds and tokens are all sent as they should in multiple scenarios (auction closed, auction cancel, people bidding in the same block, etc)

## Both contracts should be Upgradable & behind proxies owned by the deployer
## Both contracts should also have a deployment & upgrade test scripts written, along with tests that test the basic functionality of every method at least once
