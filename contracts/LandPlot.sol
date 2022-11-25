//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./_external/openzeppelin-upgradable/token/ERC721/ERC721Upgradeable.sol";
import "./_external/openzeppelin-upgradable/access/OwnableUpgradeable.sol";
import "./_external/openzeppelin-upgradable/proxy/utils/Initializable.sol";

// @title Upgradable Minecraft LandPlot NFT
// @author elee
contract LandPlot is ERC721Upgradeable, OwnableUpgradeable {
    // mapping from token id to enabled state
    mapping(uint256 => bool) private enabled;
    // mapping from tokenid to x chunk coordinate;
    mapping(uint256 => int128) public chunk_x;
    // mapping from tokenid to z chunk coordinate;
    mapping(uint256 => int128) public chunk_z;
    // mapping from x to y to bool to see if it is owned already;
    mapping(int128 => mapping(int128 => uint256)) public _owned;
    // prices for plots based on distance - curve is calculated off chain
    uint256[] public _plotPrices;
    uint256[] public _plotPriceDistances;
    // This is the amount of chunks currently claimed
    uint256 public _nftCnt;
    // This is the max chunk coordinate of any claimable chunk
    // e.g. if the limit is 10, the user can mint nfts from -9,-9 to 9,9
    uint128 public _chunkLimit;
    bool public _claimAvailable;

    modifier onlyUnmintedNft(int128 x, int128 z) {
        require(_owned[x][z] == 0, "LandPlot: already minted");
        _;
    }

    /**
     * @notice Initializer function
     * @dev Initilize variables and call the parents' initializer functions
     * @param name the name of token
     * @param symbol the symbol of token
     */
    function initialize(string memory name, string memory symbol)
        public
        initializer
    {
        ERC721Upgradeable.__ERC721_init(name, symbol);
        OwnableUpgradeable.__Ownable_init();
        ERC721Upgradeable._safeMint(msg.sender, 1); // mint the 1 id NFT to the contract owner
        chunk_x[1] = 0;
        chunk_z[1] = 0;
        _owned[0][0] = 1;
        _nftCnt = 1; // NFT id=0 is a reference to an unbought chunk
        _chunkLimit = 2000; //the world is 4000x4000 chunks, or 64000x64000 blocks
        _claimAvailable = false; // purchases are not initially available
    }

    /**
     * @notice claim chunks
     * @dev you must send enough wei to pay for all chunks
     * @dev the length of xs and zs must match
     * @param xs array of x chunk coordinates to match with zs
     * @param zs array of z chunk coordinates to match with xs
     */
    function claimLands(int128[] memory xs, int128[] memory zs)
        external
        payable
    {
        require(_claimAvailable, "LandPlot: claiming disabled");
        require(xs.length <= 128, "LandPlot: invalid param");
        require(xs.length == zs.length, "LandPlot: invalid param");
        uint256 total_cost;
        for (uint256 i = 0; i < xs.length; i++) {
            genesisMint(msg.sender, xs[i], zs[i]);
            total_cost = total_cost + calculateLandCost(xs[i], zs[i]);
        }
        require(msg.value >= total_cost, "LandPlot: not enough eth");
        if (msg.value > total_cost) {
            payable(msg.sender).transfer(msg.value - total_cost);
        } else {}
    }

    /**
     * @notice Contract owner sets the plot prices and plot price distances
     * @dev the price length and distance length should be same
     * @param prices An array of prices in wei which correspond to a matching distance, eg [10000000,1000,10,1,...]
     * @param distances An array of distances in chunks which correspond to a matching price, eg [10,100,700,800,...]
     */
    function admin_set_plot_costs(
        uint256[] memory prices,
        uint256[] memory distances
    ) external onlyOwner {
        require(
            prices.length == distances.length,
            "LandPlot: prices length and distances should be same"
        );
        _plotPrices = prices;
        _plotPriceDistances = distances;
    }

    /**
     * @notice Contract owner sets the chunk limit
     * @dev chunk_limit must be greater than 0
     * @param chunk_limit as an uint128
     */
    function admin_set_chunk_limit(uint128 chunk_limit) external onlyOwner {
        require(chunk_limit > 0, "LandPlot: invalid chunk limit");
        _chunkLimit = chunk_limit;
    }

    /**
     * @notice Contract owner sets the claim status
     * @dev _claimAvailable is false out of the box
     * @param available Boolean flag on whether or not people can claim land
     */
    function admin_set_claim_status(bool available) external onlyOwner {
        _claimAvailable = available;
    }

    /**
     * @notice the contract owner may mint any nft for anybody
     * @dev xs length and zs length should be same
     * @param recv address which will receive the nft
     * @param xs array of x chunk coordinate that the nfts will correspond to
     * @param zs array of z chunk coordinate that the nfts will correspond to
     */
    function mintMany(
        address recv,
        int128[] memory xs,
        int128[] memory zs
    ) external onlyOwner {
        require(xs.length == zs.length, "LandPlot: invalid param");
        for (uint256 i = 0; i < xs.length; i++) {
            mintOne(recv, xs[i], zs[i]);
        }
    }

    /**
     * @notice the contract owner may mint any nft for anybody
     * @dev only mint unminted NFT
     * @param recv address which will receive the nft
     * @param x x chunk coordinate that the nft will correspond to
     * @param z z chunk coordinate that the nft will correspond to
     */
    function mintOne(
        address recv,
        int128 x,
        int128 z
    ) public onlyOwner {
        genesisMint(recv, x, z);
    }

    /**
     * @notice get the chunk coordinates of which nft with id tokenId has jusrisdiction over
     * @dev if tokenID is the id of unminted NFT, returns (0, 0)
     * @param tokenId id of the nft
     * @return (int128,int128) corresponding to the chunk with chunk coordinates (x,z);
     */
    function getTokenInfo(uint256 tokenId)
        public
        view
        returns (int128, int128)
    {
        require(tokenId > 0, "LandPlot: invalid tokenId");
        if (tokenId > _nftCnt) {
            return (0, 0);
        }
        return (chunk_x[tokenId], chunk_z[tokenId]);
    }

    /**
     * @notice get the tokenId that has jusrisdiction over chunk x,z
     * @dev if x and z are equal to 0, then it should fail
     * @param x x chunk coordinate
     * @param z z chunk coordinate
     * @return uint256 id of nft. if nft id == 0, then the land is unclaimed;
     */
    function getTokenIdByChunk(int128 x, int128 z)
        public
        view
        returns (uint256)
    {
        require(
            x != 0 && z != 0,
            "LandPlot: cann't get token id of chunk [0, 0]"
        );
        return _owned[x][z];
    }

    /**
     * @notice Calculate the land cost based on x, z chunk coordinate
     * @param x x chunk coordinate of the plot
     * @param z z chunk coordinate of the plot
     * @return price in wei as uin256
     */
    function calculateLandCost(int128 x, int128 z)
        public
        view
        returns (uint256 price)
    {
        uint128 xA = uint128(x >= 0 ? x : -x);
        uint128 zA = uint128(z >= 0 ? z : -z);
        uint128 min = (xA < zA ? xA : zA);
        for (uint256 i = 0; i < _plotPrices.length; i++) {
            if (min > _plotPriceDistances[i]) {
                price = _plotPrices[i];
            }
        }
    }

    /**
     * @notice Mint the nft
     * @dev this is the function that actually mints the nft
     * @param recv address which will receive the nft
     * @param x x chunk coordinate that the nft will correspond to
     * @param z z chunk coordinate that the nft will correspond to
     */
    function genesisMint(
        address recv,
        int128 x,
        int128 z
    ) private onlyUnmintedNft(x, z) {
        uint128 xA = uint128(x >= 0 ? x : -x);
        uint128 zA = uint128(z >= 0 ? z : -z);
        require(
            (_chunkLimit > xA) && (_chunkLimit > zA),
            "LandPlot: invalid coordinate"
        );
        _nftCnt = _nftCnt + 1;
        ERC721Upgradeable._safeMint(recv, _nftCnt);
        chunk_x[_nftCnt] = x;
        chunk_z[_nftCnt] = z;
        _owned[x][z] = _nftCnt;
    }

    /**
     * @notice Send NFTs
     * @dev this is the function that actually send the nfts
     * @param to address which will receive the nft
     * @param tokenIds the ids of nfts
     */
    function multitransfer(address to, uint256[] memory tokenIds) public {
        require(to != address(0), "LandPlot: invalid address");
        require(tokenIds.length > 0, "LandPlot: invalid tokenIds");
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(
                tokenIds[i] > 0 && tokenIds[i] <= _nftCnt,
                "LandPlot: invalid tokenId"
            );
            ERC721Upgradeable._transfer(msg.sender, to, tokenIds[i]);
        }
    }
}
