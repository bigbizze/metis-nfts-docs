// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./Helpers.sol";
import "./BaseNft.sol";
import "./WorldLeader.sol";

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// handles creating new missiles & the RNG for doing so, their damage, & the intervals for how often players can
// try to roll more missiles again
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
contract MissileMaker is BaseNft {
    using Helpers for uint;
    using SafeMath for uint;
    using Counters for Counters.Counter;
    uint private _creationTime;

    // how many hours make up one interval (within which a leader NFT can only attempt to roll for a missile once)
    //
    uint public _hoursBetweenCutoffs = 24;
    uint public _missileChancePerc = 30;

    mapping(uint => uint) _lastRunLookup;
    uint _maxDmgPerRoll = 99;
    uint _minDmgPerRoll = 43;
    uint _numDmgRolls = 5;

    struct MissileOdds {
        uint numMissilesToMint;
        bool isOkay;
    }
    mapping(uint => uint64) _missileDmgLookup;

    uint32 _missileCreatedEventId;
    struct MissileCreatedState {
        uint16 dmg;
        uint32 missileCreatedEventId;
        address owner;
        uint missileNftId;
    }

    mapping(uint => MissileCreatedState) _missileCreatedLookup;

    function getMissileCreatedInfo(uint missileNftId) public view returns (MissileCreatedState memory) {
        require(_missileCreatedLookup[missileNftId].dmg > 0, "this missile created event doesn't exist!");
        return _missileCreatedLookup[missileNftId];
    }

    event MissilesCreated(uint missileCreatedEventId, address createdForAddress);

    constructor() BaseNft("Missile Maker", "U235") {
        _creationTime = block.timestamp;
    }

    function _getNextCutoffInSecondsSinceEpoch() private view returns (uint) {
        uint timeSinceCreationInDays = block.timestamp.sub(_creationTime).secsToDays();
        uint startOfThisStepInSecs = _creationTime.add(timeSinceCreationInDays.daysToSecs());
        uint nextCutoffHours = startOfThisStepInSecs.secsToHours().add(_hoursBetweenCutoffs);
        return nextCutoffHours.hoursToSecs();
    }
    function isRollForMissileReady(uint lastRun) private view returns (bool) {
        uint nextCutoff = getNextCutoffInSecondsSinceEpoch();
        return lastRun == 0 || nextCutoff.sub(lastRun) > _hoursBetweenCutoffs.mul(60).mul(60);
    }

    function _maybeGetMissiles(address sender, uint randVal, uint missilePercChance) private returns (uint) {
        WorldLeader thisWorldLeader = WorldLeader(_ownedContracts.leader);
        if (thisWorldLeader.balanceOf(sender) == 0) {
            return 0;
        }
        uint[] memory leaderNftIds = thisWorldLeader.tokensOfOwner(sender);
        uint currentPercentage = 0;
        uint numMissilesToMint = 0;

        bool anyReady = false;
        //
        // increment the % chance of rolling a missile according to the missilePercChance depending on number of NFTs owned.
        // when this reaches or exceeds 100%, consider this a guaranteed missile for the user and start back at 0 again
        // for their chance of rolling another one. repeat this for the amount of NFTs they own until you have an
        // amount of guaranteed missiles, and a % chance of getting one more.
        //
        // each unique world leader collection calculates these odds separately.
        //
        for (uint i = 0; i < leaderNftIds.length; i++) {
            uint leaderNftId = leaderNftIds[i];
            if (isRollForMissileReady(_lastRunLookup[leaderNftId])) {
                anyReady = true;
                _lastRunLookup[leaderNftId] = block.timestamp;
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

        return numMissilesToMint;
    }

    function userDidRollMissile(uint randVal, uint thisMissilePercChance) internal view returns (bool){
        uint num = uint(randVal.randomize(block.timestamp).modSafe(100));
        return num <= thisMissilePercChance;
    }

    function maybeGetMissiles(uint randVal) external {
        randVal = randVal.randomize(block.timestamp, _creationTime);
        uint numMissilesToMint = _maybeGetMissiles(msg.sender, randVal, _missileChancePerc);
        createMissiles(msg.sender, randVal, numMissilesToMint);
    }

    function createMissiles(address sender, uint randVal, uint numMissilesToMint) private {
        for (uint i = 0; i < numMissilesToMint; i++) {
            uint missileNftId = _mintSingleNFT(sender);
            uint16 dmg = rollMissileDmg(randVal, i);
            _missileDmgLookup[missileNftId] = dmg;
            _missileCreatedLookup[missileNftId] = MissileCreatedState(dmg, _missileCreatedEventId, sender, missileNftId);
        }
        emit MissilesCreated(_missileCreatedEventId, sender);
        _missileCreatedEventId++;
    }

    function _mintSingleNFT(address to) internal returns (uint) {
        uint newTokenID = tokenIdx.current();
        _safeMint(to, newTokenID);
        tokenIdx.increment();
        return newTokenID;
    }

    function _getMissileDmg(address sender, uint256 missileId) external returns (uint64) {
        require(msg.sender == _ownedContracts.ufoInvasion || msg.sender == owner());
        require(ownerOf(missileId) == sender, "getMissileDmg :: you can't do that");
        uint64 missileDmg = getMissileDmg(missileId);
        burn(missileId);
        return missileDmg;
    }

    function rollMissileDmg(uint randVal, uint idx) internal view returns (uint16){
        uint16 dmg = 0;
        for (uint i = 0; i < _numDmgRolls; i++) {
            dmg += uint16(randVal.randomize(block.timestamp, idx).modSafe(_maxDmgPerRoll.sub(_minDmgPerRoll)).add(_minDmgPerRoll));
        }
        return dmg;
    }

    // ********** PUBLIC DATA QUERY METHODS **********

    function getNextCutoffInSecondsSinceEpoch() public view returns (uint) {
        return _getNextCutoffInSecondsSinceEpoch();
    }

    // returns the percentage chance each World Leader NFT has at rolling a missile
    function getMissilePercChance() public view returns (uint) {
        return _missileChancePerc;
    }

    // returns the missile ids of the missiles owned by the user
    function getUserMissiles(address userAddr) external view returns (uint[] memory) {
        return tokensOfOwner(userAddr);
    }

    // returns the amount of damage the missile with the id `missileId` does
    function getMissileDmg(uint256 missileId) public view returns (uint64) {
        require(!_isBurned(missileId), "this missile has already been used!");
        require(_exists(missileId), "this does not exist!");
        return _missileDmgLookup[missileId];
    }

    // returns the number of missiles rolling attempts the message sender has available currently
    function numMissilesReadyToRoll() public view returns (uint) {
        WorldLeader leader = WorldLeader(_ownedContracts.leader);
        if (leader.balanceOf(msg.sender) == 0) {
            return 0;
        }
        uint[] memory leaderNftIds = leader.tokensOfOwner(msg.sender);
        uint numReady = 0;
        for (uint i = 0; i < leaderNftIds.length; i++) {
            if (isRollForMissileReady(_lastRunLookup[leaderNftIds[i]])) {
                numReady++;
            }
        }
        return numReady;
    }

    // ********** ONLY OWNER PARAMETER CHANGING **********

    function setHoursBetweenCutoffs(uint newDaysBetweenCutoff) public onlyOwner {
        _hoursBetweenCutoffs = newDaysBetweenCutoff;
    }

    function setMissilePercChance(uint newChancePerc) public onlyOwner {
        _missileChancePerc = newChancePerc;
    }
}
