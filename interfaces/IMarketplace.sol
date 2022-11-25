// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IMarketplace {
    struct AuctionToken {
        address tokenAddress;
        uint256 tokenId;
    }

    enum Status {
        STARTED,
        CANCELLED,
        EXPIRED,
        FINISHED
    }

    /**
     * @dev Create auction to sell multiple token
     * @param tAddress NFT address
     * @param tokenIds the ids of token
     * @param period auction time
     */
    function newAuction(
        address tAddress,
        uint256[] memory tokenIds,
        uint256 period
    ) external;

    /**
     * @dev Cancel auction
     * @param auctionInfoId the id of auction house
     */
    function cancelAuction(uint256 auctionInfoId) external;

    /**
     * @dev Bid to action house created by sellTokenAuction or sellMultipleTokenAuction
     * @param auctionInfoId the id of auction house
     */
    function bidAuction(uint256 auctionInfoId) external;

    /**
     * @dev Finish auction house created by sellTokenAuction or sellMultipleTokenAuction
     * @param auctionInfoId the id of auction house
     */
    function endAuction(uint256 auctionInfoId) external;

    /**
     * @dev Get all available token ids count of all auction houses
     */
    function getTotalTokenCnt() external view returns (uint256 count);

    /**
     * @dev Get available token id
     * @param index the index of availableTokens
     */
    function getTokenId(uint256 index)
        external
        view
        returns (address tokenAddress, uint256 tokenId);

    /**
     * @dev Get auction house info
     * @param auctionInfoId the id of auction house
     */
    function getAuctionInfo(uint256 auctionInfoId)
        external
        returns (
            address,
            AuctionToken[] memory,
            uint256,
            address,
            uint256,
            Status
        );

    /**
     * @dev Get purchase house info
     * @param purchaseInfoId the id of purchase house
     */
    function getPurchaseInfo(uint256 purchaseInfoId)
        external
        returns (
            address,
            address,
            uint256,
            uint256,
            uint256,
            Status
        );

    /**
     * @dev Create purchase to buy a token
     * @param tAddress NFT address
     * @param tokenId the id of token
     * @param period purchase time
     */
    function newPurchase(
        address tAddress,
        uint256 tokenId,
        uint256 period
    ) external payable;

    /**
     * @dev Cancel purchase
     * @param purchaseInfoId the id of purchaseInfos
     */
    function cancelPurchase(uint256 purchaseInfoId) external;

    /**
     * @dev Accept purchase
     * @param purchaseInfoId the id of purchaseInfos
     */
    function acceptPurchase(uint256 purchaseInfoId) external;
}
