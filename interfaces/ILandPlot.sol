// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ILandPlot {
    /**
     * @dev User minting function
     * @param xs The array of x-chunk
     * @param zs The array of z-chunk
     */
    function claimLands(int128[] memory xs, int128[] memory zs) external;

    /**
     * @dev Admin set plot cost function
     * @param prices An array of prices in wei which correspond to a matching distance, eg [10000000000000,1000000,10000,100,...]
     * @param distances An array of distances in chunks which correspond to a matching price, eg [10,100,700,800,...]
     */
    function admin_set_plot_costs(
        uint256[] memory prices,
        uint256[] memory distances
    ) external;

    /**
     * @dev Admin set chunk limit function
     * @param chunk_limit as an uint128
     */
    function admin_set_chunk_limit(uint128 chunk_limit) external;

    /**
     * @dev Admin set claim available function
     * @param available Boolean flag on whether or not people can claim land
     */
    function admin_set_claim_status(bool available) external;

    /**
     * @dev the contract owner may mint any nft for anybody
     * @param recv address which will receive the nft
     * @param xs array of x chunk coordinate that the nfts will correspond to
     * @param zs array of z chunk coordinate that the nfts will correspond to
     */
    function mintMany(
        address recv,
        int128[] memory xs,
        int128[] memory zs
    ) external;

    /**
     * @dev get the chunk coordinates of which nft with id tokenId has jusrisdiction over
     * @param tokenId id of the nft
     */
    function getTokenInfo(uint256 tokenId) external view returns (int128, int128);

    /**
     * @dev get the claim that has jusrisdiction over chunk x,z
     * @param x x chunk coordinate
     * @param z z chunk coordinate
     */
    function getTokenIdByChunk(int128 x, int128 z) external view returns (uint256);

    /**
     * @dev multitransfer nfts
     * @param to destination
     * @param tokenIds the array of token ids
     */
    function multitransfer(address to, uint[] memory tokenIds) external;
}
