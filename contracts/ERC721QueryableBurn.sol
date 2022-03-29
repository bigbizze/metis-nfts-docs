// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

/**
 * @dev This implements a mapping which tracks whether an NFT was burned or not, so that we can call "_existsOrBurned"
 * instead of "_exists" to determine if it has existed but was burned, or hasn't ever existed.
 */

abstract contract ERC721QueryableBurn is ERC721Enumerable {

    mapping(uint => bool) _isBurnedLookup;

    function existsOrBurned(uint tokenId) public view returns (bool) {
        return _existsOrBurned(tokenId);
    }

    function _existsOrBurned(uint tokenId) internal view returns (bool) {
        return _isBurnedLookup[tokenId] || _exists(tokenId);
    }

    function isBurned(uint tokenId) public view returns (bool) {
        return _isBurned(tokenId);
    }

    function _isBurned(uint tokenId) internal view returns (bool) {
        return _isBurnedLookup[tokenId];
    }

    function burn(uint tokenId) internal virtual {
        _isBurnedLookup[tokenId] = true;
        _burn(tokenId);
    }
}

