// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

// this is (mostly) not my code

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
//import "./ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";

import "./OwnableOrOwned.sol";
import "./Helpers.sol";

contract WorldLeader is ERC721Enumerable, PaymentSplitter, OwnableOrOwned {
    using SafeMath for uint;
    using Counters for Counters.Counter;
    using Helpers for uint;
    Counters.Counter private _tokenIdx;

    bool private _autoWithdraw = false;
    uint public constant MAX_SUPPLY = 5800;
    uint public constant PRICE = 0.13 ether;
    uint public constant MAX_PER_MINT = 21;

    enum ReleaseStatus {
        Unreleased,
        Released
    }

    ReleaseStatus public _releaseStatus = ReleaseStatus.Unreleased;

    string public baseTokenURI;
    uint private _numPayees;

    mapping(address => bool) _freeMintLookup;

    constructor(
        address[] memory _payees,
        uint256[] memory _shares
    ) ERC721("BidensRocket", "BIDEN") PaymentSplitter(_payees, _shares) payable {
        _numPayees = _payees.length;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    function setBaseURI(string memory _baseTokenURI) public onlyOwner {
        baseTokenURI = _baseTokenURI;
    }

    function mintNFTs(uint _numToPayForCount) external payable {
        require(_releaseStatus != ReleaseStatus.Unreleased, "this is not yet released!");

        uint totalMinted = _tokenIdx.current();

        uint numToMintCount = _numToPayForCount;

        if (_numToPayForCount >= 10 && _numToPayForCount < 17) {
            numToMintCount += 2;
        } else if (_numToPayForCount >= 17) {
            numToMintCount += 3;
        }

        require(totalMinted.add(numToMintCount) <= MAX_SUPPLY, "Not enough NFTs left!");
        require(_numToPayForCount > 0 && _numToPayForCount <= MAX_PER_MINT, "count is empty!");

        uint priceNeeded = _freeMintLookup[msg.sender] ? PRICE.mul(_numToPayForCount.sub(1)) : PRICE.mul(_numToPayForCount);
        _freeMintLookup[msg.sender] = false;

        require(msg.value >= priceNeeded, "Need more Metis");

        for (uint i = 0; i < numToMintCount; i++) {
            _mintSingleNFT();
        }
        if (_autoWithdraw) {
            withdrawAuto();
        }
    }

    function exists(uint nftId) public view returns (bool) {
        return _exists(nftId);
    }

    function _mintSingleNFT() private {
        uint newTokenID = _tokenIdx.current();
        _safeMint(msg.sender, newTokenID);
        _tokenIdx.increment();
    }

    function tokensOfOwner(address _owner) public view returns (uint[] memory) {
        uint tokenCount = balanceOf(_owner);
        uint[] memory tokensId = new uint[](tokenCount);

        for (uint i = 0; i < tokenCount; i++) {
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }

        return tokensId;
    }

    function withdrawAuto() private {
        for (uint i = 0; i < _numPayees; i++) {
            release(payable(payee(i)));
        }
    }

    function hasFreeMint(address addr) public view returns (bool) {
        return _freeMintLookup[addr];
    }

    function addAddressesForFreeMint(address[] memory addresses) public onlyOwner {
        for (uint i = 0; i < addresses.length; i++) {
            _freeMintLookup[addresses[i]] = true;
        }
    }

    function getReleaseStatus() public view returns (ReleaseStatus) {
        return _releaseStatus;
    }

    function releaseMint() public onlyOwner {
        require(_releaseStatus == ReleaseStatus.Unreleased, "this mint is already released!");
        _releaseStatus = ReleaseStatus.Released;
    }

    function setAutoWithdraw(bool to) public onlyOwner {
        _autoWithdraw = to;
    }

    function getAutoWithdraw() public view onlyOwner returns (bool) {
        return _autoWithdraw;
    }

    function getPrice() public view onlyOwner returns (uint) {
        return PRICE;
    }

    function getMaxSupply() public view onlyOwner returns (uint) {
        return MAX_SUPPLY;
    }

    function getNumPayees() public view onlyOwner returns (uint) {
        return _numPayees;
    }
}
