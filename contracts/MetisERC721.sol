// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

// this is (mostly) not my code

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./OwnableOrMainContract.sol";

contract MetisERC721 is ERC721Enumerable, OwnableOrMainContract {
    using SafeMath for uint;
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdx;

    uint public constant MAX_SUPPLY = 10000;
    uint public constant PRICE = 0.00001 ether;
    uint public constant MAX_PER_MINT = 21;
    uint public constant WHITELIST_MAX_AMOUNT = 5;

    enum ReleaseStatus {
        Unreleased,
        Whitelist,
        Released
    }

    ReleaseStatus public _releaseStatus = ReleaseStatus.Unreleased;

    address payable[] private _recipients;

    event SetRecipient(address payable recipient);

    string public baseTokenURI;

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {}

    mapping(address => bool) _freeMintLookup;
    mapping(address => uint) _whitelistRemaining;

    function reserveNFTs() public onlyOwner {
        uint totalMinted = _tokenIdx.current();

        require(
            totalMinted.add(100) < MAX_SUPPLY,
            "Not enough NFTs left to reserve"
        );

        for (uint i = 0; i < 100; i++) {
            _mintSingleNFT();
        }
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    function setBaseURI(string memory _baseTokenURI) public onlyOwner {
        baseTokenURI = _baseTokenURI;
    }

    function _mintNFTs(uint _count) public payable {
        require(_releaseStatus != ReleaseStatus.Unreleased, "this is not yet released!");
        if (_releaseStatus == ReleaseStatus.Whitelist) {
            require(_whitelistRemaining[msg.sender] != 0, "you have no whitelisted mints remaining!");
            // while the whitelist period is still active, if they try to request more than their allowed amount
            // whitelist amount, set the amount to the remainder of their whitelist instead
            if (_count > _whitelistRemaining[msg.sender]) {
                _count = _whitelistRemaining[msg.sender];
            }
            _whitelistRemaining[msg.sender] = _whitelistRemaining[msg.sender].sub(_count);
        }

        uint totalMinted = _tokenIdx.current();

        uint counter;

        if (_count == 10) {
            counter = 12;
        } else if (_count == 17) {
            counter = 21;
        } else {
            counter = _count;
        }

        require(totalMinted.add(counter) <= MAX_SUPPLY, "Not enough NFTs left!");
        require(_count > 0 && _count <= MAX_PER_MINT, "count is empty!");

        uint priceNeeded = _freeMintLookup[msg.sender] ? PRICE.mul(_count - 1) : PRICE.mul(_count);
        _freeMintLookup[msg.sender] = false;

        require(msg.value >= priceNeeded, "Need more Metis");

        for (uint i = 0; i < counter; i++) {
            _mintSingleNFT();
        }
        withdrawAuto(msg.value);
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

    function withdrawAuto(uint amount) public {
        require(_recipients.length > 0, "no recipients have been added to withdraw to!");
        require(amount > 0, "No ether left to auto withdraw");
        uint amountPerRecipient = amount.div(_recipients.length);
        for (uint i = 0; i < _recipients.length; i++) {
            (bool success, ) = (_recipients[i]).call{ value: amountPerRecipient }("");
            require(success, "Transfer failed.");
        }
    }

    function withdraw() public onlyOwnerOrMain {
        require(_recipients.length > 0, "no recipients have been added to withdraw to!");
        uint balance = address(this).balance;
        require(balance > 0, "No ether left to withdraw");

        uint amountPerRecipient = balance.div(_recipients.length);

        for (uint i = 0; i < _recipients.length; i++) {
            (bool success, ) = (_recipients[i]).call{ value: amountPerRecipient }("");
            require(success, "Transfer failed.");
        }
    }

    function isRecipient(address payable recipient) public onlyOwnerOrMain view returns (bool) {
        for (uint i = 0; i < _recipients.length; i++) {
            if (recipient == _recipients[i]) {
                return true;
            }
        }
        return false;
    }

    function setRecipient(address payable recipient) public onlyOwnerOrMain {
        if (isRecipient(recipient)) {
            revert("this recipient already exists");
        }
        _recipients.push(recipient);
        emit SetRecipient(recipient);
    }

    function hasFreeMint(address addr) public view returns (bool) {
        return _freeMintLookup[addr];
    }

    function addAddressesForFreeMint(address[] memory addresses) public onlyOwnerOrMain {
        for (uint i = 0; i < addresses.length; i++) {
            _freeMintLookup[addresses[i]] = true;
        }
    }

    function numWhitelistMintsRemaining(address addr) public view returns (uint) {
        return _whitelistRemaining[addr];
    }

    function addAddressesForWhitelist(address[] memory addresses) public onlyOwnerOrMain {
        for (uint i = 0; i < addresses.length; i++) {
            _whitelistRemaining[addresses[i]] = WHITELIST_MAX_AMOUNT;
        }
    }

    function getReleaseStatus() public view returns (ReleaseStatus) {
        return _releaseStatus;
    }

    function setReleaseStatus(ReleaseStatus releaseStatus) public onlyOwnerOrMain {
        _releaseStatus = releaseStatus;
    }
}
