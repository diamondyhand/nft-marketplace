//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "hardhat/console.sol";

import "./_external/openzeppelin-upgradable/token/ERC721/ERC721Upgradeable.sol";
import "./_external/openzeppelin-upgradable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "./_external/openzeppelin-upgradable/security/ReentrancyGuardUpgradeable.sol";
import "./_external/openzeppelin-upgradable/utils/structs/EnumerableSetUpgradeable.sol";

// @title Upgradable Marketplace
// @author diamondyhand
contract Marketplace is ReentrancyGuardUpgradeable, IERC721ReceiverUpgradeable {
    uint256 constant RESTZERO = 2 ** 96;
    enum Status {
        STARTED,
        CANCELLED,
        EXPIRED,
        FINISHED
    }

    struct Auction {
        address creator;
        uint256 topPrice;
        address topBidder;
        uint256 endTime;
        uint256 tokenIdCnt;
        Status oStatus;
    }
    mapping(uint256 => Auction) public auctionInfos;
    uint256 public auctionInfoCnt;
    struct AuctionToken {
        address tokenAddress;
        uint256 tokenId;
    }
    mapping(uint256 => mapping(uint256 => AuctionToken)) public auctionTokens;
    EnumerableSetUpgradeable.UintSet private availableTokens;

    struct Purchase {
        address purchaser;
        address tokenAddress;
        uint256 price;
        uint256 endTime;
        uint256 tokenId;
        Status oStatus;
    }
    mapping(uint256 => Purchase) public purchaseInfos;
    uint256 public purchaseInfoCnt;

    modifier onlyValidAuction(uint256 auctionInfoId) {
        require(
            auctionInfoId >= 0 && auctionInfoId < auctionInfoCnt,
            "Invalid auctionInfoId"
        );
        require(
            auctionInfos[auctionInfoId].oStatus == Status.STARTED,
            "Unavailable auction"
        );
        require(
            block.timestamp <= auctionInfos[auctionInfoId].endTime,
            "Time is up"
        );
        _;
    }
    modifier onlyValidPurchase(uint256 purchaseInfoId) {
        require(
            purchaseInfoId >= 0 && purchaseInfoId < purchaseInfoCnt,
            "Invalid purchaseInfoId"
        );
        require(
            purchaseInfos[purchaseInfoId].oStatus == Status.STARTED,
            "Unavailable purchase"
        );
        require(
            purchaseInfos[purchaseInfoId].endTime >= block.timestamp,
            "Time is up"
        );
        _;
    }
    modifier onlyAuctionCreator(uint256 auctionInfoId) {
        require(
            auctionInfos[auctionInfoId].creator == msg.sender,
            "Access is forbidden"
        );
        _;
    }
    modifier onlyPurchaseCreator(uint256 purchaseInfoId) {
        require(
            purchaseInfos[purchaseInfoId].purchaser == msg.sender,
            "Access is forbidden"
        );
        _;
    }

    /**
     * @notice Remove token from availableTokens when auction has been canceled or ended
     * @param token the token that has to be removed
     */
    function popFromAvailableTokens(AuctionToken memory token) internal {
        EnumerableSetUpgradeable.remove(
            availableTokens,
            uint256(uint160(token.tokenAddress)) * (RESTZERO) + token.tokenId
        );
    }

    /**
     * @notice Use initialize instead of constructor in upgradable contracts
     */
    function initialize() public initializer {
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
    }

    /**
     * @notice Must inherite IERC721ReceiverUpgradeable and override onERC721Received if the contract wanna receive ERC721 tokens
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /**
     * @notice Create auction to sell multiple token
     * @param tAddress NFT address
     * @param tokenIds the ids of token
     * @param period auction time
     */
    function newAuction(
        address tAddress,
        uint256[] memory tokenIds,
        uint256 period
    ) external nonReentrant {
        Auction storage newAuctionInfo = auctionInfos[auctionInfoCnt];
        newAuctionInfo.creator = msg.sender;
        newAuctionInfo.endTime = block.timestamp + period;
        newAuctionInfo.oStatus = Status.STARTED;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(
                tokenIds[i] < RESTZERO,
                "TokenIds must be less than 2 ^ 96"
            );
            IERC721Upgradeable(tAddress).safeTransferFrom(
                msg.sender,
                address(this),
                tokenIds[i]
            );
            auctionTokens[auctionInfoCnt][i].tokenAddress = tAddress;
            auctionTokens[auctionInfoCnt][i].tokenId = tokenIds[i];
            EnumerableSetUpgradeable.add(
                availableTokens,
                uint256(uint160(tAddress)) * (RESTZERO) + tokenIds[i]
            );
        }
        auctionInfoCnt++;
        newAuctionInfo.tokenIdCnt = tokenIds.length;
    }

    /**
     * @notice Cancel auction
     * @param auctionInfoId the id of auction house
     */
    function cancelAuction(
        uint256 auctionInfoId
    )
        external
        onlyValidAuction(auctionInfoId)
        onlyAuctionCreator(auctionInfoId)
        nonReentrant
    {
        Auction storage auctionInfo = auctionInfos[auctionInfoId];
        auctionInfo.oStatus = Status.CANCELLED;
        if (auctionInfo.topBidder != address(0)) {
            payable(auctionInfo.topBidder).transfer(auctionInfo.topPrice);
        }
        for (uint256 i = 0; i < auctionInfo.tokenIdCnt; i++) {
            IERC721Upgradeable(auctionTokens[auctionInfoId][i].tokenAddress)
                .safeTransferFrom(
                    address(this),
                    msg.sender,
                    auctionTokens[auctionInfoId][i].tokenId
                );
            popFromAvailableTokens(auctionTokens[auctionInfoId][i]);
        }
    }

    /**
     * @notice Bid to auction
     * @dev Bid to auction house created by sellTokenAuction or sellMultipleTokenAuction
     * @param auctionInfoId the id of auction house
     */
    function bidAuction(
        uint256 auctionInfoId
    ) external payable onlyValidAuction(auctionInfoId) nonReentrant {
        require(
            msg.value > auctionInfos[auctionInfoId].topPrice,
            "Need more money"
        );
        require(
            msg.sender != auctionInfos[auctionInfoId].topBidder,
            "Can't bid continuously"
        );
        if (auctionInfos[auctionInfoId].topBidder != address(0)) {
            payable(auctionInfos[auctionInfoId].topBidder).transfer(
                auctionInfos[auctionInfoId].topPrice
            );
        }
        auctionInfos[auctionInfoId].topPrice = msg.value;
        auctionInfos[auctionInfoId].topBidder = msg.sender;
    }

    /**
     * @notice Finish auction
     * @dev Finish auction house created by sellTokenAuction or sellMultipleTokenAuction
     * @param auctionInfoId the id of auction house
     */
    function endAuction(
        uint256 auctionInfoId
    ) external onlyAuctionCreator(auctionInfoId) nonReentrant {
        Auction storage auctionInfo = auctionInfos[auctionInfoId];
        require(auctionInfo.oStatus == Status.STARTED, "Unavailable auction");
        require(
            block.timestamp > auctionInfo.endTime,
            "Auction is still ongoing"
        );
        if (auctionInfo.topBidder != address(0)) {
            auctionInfo.oStatus = Status.FINISHED;
            payable(auctionInfo.creator).transfer(auctionInfo.topPrice);
            for (uint256 i = 0; i < auctionInfo.tokenIdCnt; i++) {
                popFromAvailableTokens(auctionTokens[auctionInfoId][i]);
                IERC721Upgradeable(auctionTokens[auctionInfoId][i].tokenAddress)
                    .safeTransferFrom(
                        address(this),
                        auctionInfo.topBidder,
                        auctionTokens[auctionInfoId][i].tokenId
                    );
            }
        } else {
            auctionInfo.oStatus = Status.EXPIRED;
            for (uint256 i = 0; i < auctionInfo.tokenIdCnt; i++) {
                popFromAvailableTokens(auctionTokens[auctionInfoId][i]);
                IERC721Upgradeable(auctionTokens[auctionInfoId][i].tokenAddress)
                    .safeTransferFrom(
                        address(this),
                        auctionInfo.creator,
                        auctionTokens[auctionInfoId][i].tokenId
                    );
            }
        }
    }

    /**
     * @notice Get all available token ids count
     * @dev Get all available token ids count of all auction houses
     * @return count
     */
    function getTotalTokenCnt() external view returns (uint256 count) {
        count = EnumerableSetUpgradeable.length(availableTokens);
    }

    /**
     * @notice Get available token id
     * @dev Get available token id by index
     * @param index the index of availableTokens
     * @return tokenAddress
     * @return tokenId
     */
    function getTokenId(
        uint256 index
    ) external view returns (address tokenAddress, uint256 tokenId) {
        require(
            index >= 0 &&
                index < EnumerableSetUpgradeable.length(availableTokens),
            "Invalid index"
        );
        uint256 token = EnumerableSetUpgradeable.at(availableTokens, index);
        tokenAddress = address(uint160(token / (RESTZERO)));
        tokenId = token % (RESTZERO);
    }

    /**
     * @notice Get auction house info
     * @param auctionInfoId the id of auction house
     * @return (address, AuctionToken[], uint, address, uint, Status)
     */
    function getAuctionInfo(
        uint256 auctionInfoId
    )
        external
        view
        returns (
            address,
            AuctionToken[] memory,
            uint256,
            address,
            uint256,
            Status
        )
    {
        require(
            auctionInfoId >= 0 && auctionInfoId < auctionInfoCnt,
            "Invalid auctionInfoId"
        );
        Auction memory auctionInfo = auctionInfos[auctionInfoId];
        if (
            auctionInfo.oStatus == Status.STARTED &&
            block.timestamp > auctionInfo.endTime
        ) {
            auctionInfo.oStatus = Status.EXPIRED;
        }
        AuctionToken[] memory tokens = new AuctionToken[](
            auctionInfo.tokenIdCnt
        );
        for (uint256 i = 0; i < auctionInfo.tokenIdCnt; i++) {
            tokens[i] = auctionTokens[auctionInfoId][i];
        }
        return (
            auctionInfo.creator,
            tokens,
            auctionInfo.endTime,
            auctionInfo.topBidder,
            auctionInfo.topPrice,
            auctionInfo.oStatus
        );
    }

    /**
     * @notice Get purchase info
     * @param purchaseInfoId the id of purchase
     * @return (address, address, uint, uint, uint, Status)
     */
    function getPurchaseInfo(
        uint256 purchaseInfoId
    )
        external
        view
        returns (address, address, uint256, uint256, uint256, Status)
    {
        require(
            purchaseInfoId >= 0 && purchaseInfoId < purchaseInfoCnt,
            "Invalid purchaseInfoId"
        );
        Purchase memory purchaseInfo = purchaseInfos[purchaseInfoId];
        if (
            purchaseInfo.oStatus == Status.STARTED &&
            block.timestamp > purchaseInfo.endTime
        ) {
            purchaseInfo.oStatus = Status.EXPIRED;
        }
        return (
            purchaseInfo.purchaser,
            purchaseInfo.tokenAddress,
            purchaseInfo.tokenId,
            purchaseInfo.price,
            purchaseInfo.endTime,
            purchaseInfo.oStatus
        );
    }

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
    ) external payable {
        require(period <= 7 days, "Limit is a week");
        Purchase storage newPurchaseInfo = purchaseInfos[purchaseInfoCnt++];
        newPurchaseInfo.tokenAddress = tAddress;
        newPurchaseInfo.purchaser = msg.sender;
        newPurchaseInfo.endTime = block.timestamp + period;
        newPurchaseInfo.oStatus = Status.STARTED;
        newPurchaseInfo.tokenId = tokenId;
        newPurchaseInfo.price = msg.value;
    }

    /**
     * @dev Cancel purchase
     * @param purchaseInfoId the id of purchaseInfos
     */
    function cancelPurchase(
        uint256 purchaseInfoId
    )
        external
        onlyValidPurchase(purchaseInfoId)
        onlyPurchaseCreator(purchaseInfoId)
        nonReentrant
    {
        Purchase storage purchaseInfo = purchaseInfos[purchaseInfoId];
        purchaseInfo.oStatus = Status.CANCELLED;
        payable(purchaseInfo.purchaser).transfer(purchaseInfo.price);
    }

    /**
     * @dev Accept purchase
     * @param purchaseInfoId the id of purchaseInfos
     */
    function acceptPurchase(
        uint256 purchaseInfoId
    ) external onlyValidPurchase(purchaseInfoId) nonReentrant {
        Purchase storage purchaseInfo = purchaseInfos[purchaseInfoId];
        purchaseInfo.oStatus = Status.FINISHED;
        IERC721Upgradeable(purchaseInfo.tokenAddress).safeTransferFrom(
            msg.sender,
            purchaseInfo.purchaser,
            purchaseInfo.tokenId
        );
        payable(msg.sender).transfer(purchaseInfo.price);
    }
}
