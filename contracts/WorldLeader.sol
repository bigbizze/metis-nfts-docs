// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./MetisERC721.sol";
import "./MissileMaker.sol";
import "./Helpers.sol";
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// a world leader MoreMissilesPlz NFT collection
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
contract WorldLeader is MetisERC721 {
    using SafeMath for uint;
    using Helpers for uint;

    string public leaderName;
    address internal _moreMissilesPlzAddress;

    mapping(uint => uint) _lastRunLookup;

    MissileMaker internal _missileMaker;
    address internal _leaderStoreAddress;

    struct MissileOdds {
        uint numMissilesToMint;
        uint[] leaderNftIds;
    }

    constructor(
        string memory name,
        address leaderStoreAddress,
        MissileMaker missileMaker
    ) MetisERC721(string(abi.encodePacked("World Leader ", name)), "LEADER") {
        leaderName = name;
        _leaderStoreAddress = leaderStoreAddress;
        _missileMaker = missileMaker;
    }

    function mintNFTs(uint count) public payable {
        _mintNFTs(count);
    }

    function doesUserOwnAnyOfThisWorldLeader(address addr) external view returns (bool) {
        return balanceOf(addr) > 0;
    }

    function numMissilesReadyToRoll(address sender) public view returns (uint) {
        if (balanceOf(sender) == 0) {
            return 0;
        }
        uint[] memory leaderNftIds = tokensOfOwner(sender);
        uint numReady = 0;
        for (uint i = 0; i < leaderNftIds.length; i++) {
            if (_missileMaker.isRollForMissileReady(_lastRunLookup[leaderNftIds[i]])) {
                numReady++;
            }
        }
        return numReady;
    }

    function maybeGetMissiles(address sender, uint randVal, uint missilePercChance) public onlyOwnerOrMain returns (MissileOdds memory) {
        uint[] memory leaderNftIds = tokensOfOwner(sender);
        uint currentPercentage = 0;
        uint numMissilesToMint = 0;

        //
        // increment the % chance of rolling a missile according to the missilePercChance depending on number of NFTs owned.
        // when this reaches or exceeds 100%, consider this a guaranteed missile for the user and start back at 0 again
        // for their chance of rolling another one. repeat this for the amount of NFTs they own until you have an
        // amount of guaranteed missiles, and a % chance of getting one more.
        //
        // each unique world leader collection calculates these odds separately.
        //
        for (uint i = 0; i < leaderNftIds.length; i++) {
            require(_exists(leaderNftIds[i]), "this nft does not exist!");
            require(ownerOf(leaderNftIds[i]) == sender, "you don't own this!");
            if (_missileMaker.isRollForMissileReady(_lastRunLookup[leaderNftIds[i]])) {
                _lastRunLookup[leaderNftIds[i]] = block.timestamp;
                currentPercentage = currentPercentage.add(missilePercChance);
                if (currentPercentage >= 100) {
                    numMissilesToMint++;
                    currentPercentage = currentPercentage.sub(100);
                }
            }
        }

        if (userDidRollMissile(randVal, currentPercentage)) {
            numMissilesToMint++;
        }

        return MissileOdds(numMissilesToMint, leaderNftIds);
    }

    function userDidRollMissile(uint randVal, uint thisMissilePercChance) internal view returns (bool){
        uint num = uint(randVal.randomize(block.timestamp).modSafe(100));
        return num <= thisMissilePercChance;
    }

    function getBalance() external view onlyOwnerOrMain returns (uint) {
        return address(this).balance;
    }

    // see MoreMissilesPlz.sol bottom section before using
    //
    function updateMissileMaker(address newMissileMaker) public {
        require(msg.sender == _leaderStoreAddress || msg.sender == mainContract() || msg.sender == owner(), "you are not allowed to do that!");
        _missileMaker = MissileMaker(newMissileMaker);
    }

    function setMoreMissilesPlzAddress(address to) public onlyOwnerOrMain {
        _moreMissilesPlzAddress = to;
    }
}


