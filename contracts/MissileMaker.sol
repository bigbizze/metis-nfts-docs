// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./BaseNft.sol";
import "./LeaderStore.sol";
import "./Helpers.sol";
import "./MoreMissilesPlz.sol";

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// handles creating new missiles & the RNG for doing so, their damage, & the intervals for how often players can
// try to roll more missiles again
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
contract MissileMaker is BaseNft {
    using Helpers for uint;
    using SafeMath for uint;
    using Counters for Counters.Counter;
    uint public _creationTime;

    address internal _moreMissilesPlzAddress;

    // how many hours make up one interval (within which a leader NFT can only attempt to roll for a missile once)
    //
    uint public _hoursBetweenCutoffs = 24;
    uint public missileChancePerc = 25;

    uint _maxDmgPerRoll = 99;
    uint _minDmgPerRoll = 43;
    uint _numDmgRolls = 5;

    LeaderStore internal _worldLeaderStore;
    MoreMissilesPlz internal _moreMissilesPlz;

    mapping(uint => uint[]) _leadersByMissileIdLookup;

    mapping(uint => uint) _missileDmgLookup;

    constructor(LeaderStore worldLeaderStore) BaseNft("Missile Maker", "U235") {
        _worldLeaderStore = worldLeaderStore;
        _creationTime = block.timestamp;
    }

    function createMissiles(address sender, uint randVal, uint[] calldata leaderNftIds, uint numMissilesToMint) external onlyOwnerOrMain {
        for (uint i = 0; i < numMissilesToMint; i++) {
            uint missileNftId = _mintSingleNFT(leaderNftIds, sender);
            uint dmg = rollMissileDmg(randVal, i);
            _missileDmgLookup[missileNftId] = dmg;
            MoreMissilesPlz(mainContract()).emitMissileCreated(sender, leaderNftIds, missileNftId, dmg);

        }
    }

    function _mintSingleNFT(uint[] memory leaderIds, address to) internal returns (uint) {
        uint newTokenID = tokenIdx.current();
        _safeMint(to, newTokenID);
        tokenIdx.increment();
        for (uint i = 0; i < leaderIds.length; i++) {
            _leadersByMissileIdLookup[newTokenID].push(leaderIds[i]);
        }
        return newTokenID;
    }

    function burnMissile(uint missileId) public onlyOwnerOrMain {
        _burn(missileId);
    }

    function getMissileDmg(uint256 missileId) public view returns (uint) {
        require(_exists(missileId), "this does not exist!");
        return _missileDmgLookup[missileId];
    }

    function isMissileConsumed(uint missileId) public view returns (bool) {
        return ownerOf(missileId) == address(0x0);
    }

    function getParentLeadersByMissileId(uint missileId) public view returns (uint[] memory) {
        require(_exists(missileId), "this missile nft does not exist!");
        return _leadersByMissileIdLookup[missileId];
    }

    function getNextCutoffInSecondsSinceEpoch() public view returns (uint) {
        uint timeSinceCreationInDays = block.timestamp.sub(_creationTime).secsToDays();
        uint startOfThisStepInSecs = _creationTime.add(timeSinceCreationInDays.daysToSecs());
        uint nextCutoffHours = startOfThisStepInSecs.secsToHours().add(_hoursBetweenCutoffs);
        return nextCutoffHours.hoursToSecs();
    }

    function isRollForMissileReady(uint lastRun) public view returns (bool) {
        uint nextCutoff = getNextCutoffInSecondsSinceEpoch();
        return lastRun == 0 || nextCutoff.sub(lastRun) > _hoursBetweenCutoffs.mul(60).mul(60);
    }

    function rollMissileDmg(uint randVal, uint idx) internal view returns (uint){
        uint dmg = 0;
        for (uint i = 0; i < _numDmgRolls; i++) {
            dmg += uint(randVal.randomize(block.timestamp, idx).modSafe(_maxDmgPerRoll.sub(_minDmgPerRoll)).add(_minDmgPerRoll));
        }
        return dmg;
    }

    function setMissilePercChance(uint newChancePerc) public onlyOwnerOrMain {
        missileChancePerc = newChancePerc;
    }

    function getMissilePercChance() public view returns (uint) {
        return missileChancePerc;
    }

    function setHoursBetweenCutoffs(uint newDaysBetweenCutoff) public onlyOwnerOrMain {
        _hoursBetweenCutoffs = newDaysBetweenCutoff;
    }

    function setMoreMissilesPlzAddress(address to) public onlyOwnerOrMain {
        _moreMissilesPlzAddress = to;
    }

    function getUserMissiles(address userAddr) external view returns (uint[] memory) {
        return tokensOfOwner(userAddr);
    }

    // ############################################################
    // see MoreMissilesPlz.sol bottom section before using
    //
    function updateLeaderStore(address newWorldLeaderStore) public onlyOwnerOrMain {
        _worldLeaderStore = LeaderStore(newWorldLeaderStore);
    }
}
