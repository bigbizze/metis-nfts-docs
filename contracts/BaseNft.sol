// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./OwnableOrOwned.sol";
//import "./ERC721EnumerableWithQueryableBurn.sol";
import "./ERC721QueryableBurn.sol";

contract BaseNft is ERC721QueryableBurn, OwnableOrOwned {
    using SafeMath for uint;
    using Counters for Counters.Counter;

    Counters.Counter public tokenIdx;

    string public baseTokenURI;

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {}

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    function setBaseURI(string memory _baseTokenURI) public onlyOwner {
        baseTokenURI = _baseTokenURI;
    }

    function tokensOfOwner(address _owner) public view returns (uint[] memory) {
        uint tokenCount = balanceOf(_owner);
        uint[] memory tokensId = new uint[](tokenCount);

        for (uint i = 0; i < tokenCount; i++) {
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokensId;
    }
}
