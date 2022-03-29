// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

/**
 * @dev This implements a mapping which tracks whether an NFT was burned or not, so that we can both call
 * "_existsOrBurned" instead of "_exists" to determine if it has existed but was burned, or hasn't ever existed,
 * and "_ownerOfSafe" instead of "ownerOf" which returns the burn address if it has been burned before.
 */

abstract contract ERC721QueryableBurn is ERC721Enumerable {

    mapping(uint => bool) _isBurnedLookup;

    function _existsOrBurned(uint tokenId) internal view returns (bool) {
        return _isBurnedLookup[tokenId] || _exists(tokenId);
    }

    function existsOrBurned(uint tokenId) public view returns (bool) {
        return _existsOrBurned(tokenId);
    }

    function _isBurned(uint tokenId) internal view returns (bool) {
        return _isBurnedLookup[tokenId];
    }

    function isBurned(uint tokenId) public view returns (bool) {
        return _isBurned(tokenId);
    }

    function _ownerOfSafe(uint tokenId) internal view returns (address) {
        return !_isBurned(tokenId)
            ? ownerOf(tokenId)
            : address(0x0);
    }

    function ownerOfSafe(uint tokenId) public view returns (address) {
        return _ownerOfSafe(tokenId);
    }

    function burn(uint tokenId) internal virtual {
        _isBurnedLookup[tokenId] = true;
        _burn(tokenId);
    }
}

