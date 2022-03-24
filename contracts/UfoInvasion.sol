// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./BaseNft.sol";
import "./MissileMaker.sol";
import "./WorldLeader.sol";
import "./Helpers.sol";
import "./MoreMissilesPlz.sol";
import "./LeaderStore.sol";
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// this handles the destroy UFO gameplay loop, including dynamically adjusting the difficulty of a match
// so that games approach taking the same amount of time regardless of the # of players playing.
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
contract UfoInvasion is BaseNft {
    using Helpers for uint;
    using SafeMath for uint;
    using Counters for Counters.Counter;

    LeaderStore internal _leaderStore;
    MissileMaker internal _missileMaker;

    struct UfoState {
        address locationAddress;
        uint ufoId;
        uint curHp;
        uint startingHp;
    }

    bool _gameActive = false;

    // mapping of ufoIds to their index in the _curUFOs array
    mapping(uint => uint) _ufoIdxLookup;
    UfoState[] _curUFOs;

    uint _totalNumGamesPlayed = 0;

    struct GameStats {
        uint gameNumber;
        uint totalUfoHp;
        uint[] ufoIds;
        address winner;
        uint gameLengthInSeconds;
        uint gameStartTimeInSeconds;
    }

    GameStats[] _gameStats;

    uint _totalUfoHp = 2500;

    uint _gameStartTime = 0;
    uint _gameEndTime;

    uint _minNumUFOs = 3;
    uint _maxNumUFOs = 8;

    uint _wantedGameLengthInHours = 48;

    uint _numUfosInGame;

    struct UniqueAirdrop {
        uint idx;
        bool seen;
    }

    // mapping of holder addresses to their index in the _airdropToAddresses array to ensure we get unique addresses
    mapping(address => bool) _airdropToIdx;
    address[] _airdropToAddresses;

    struct CurGameScore {
        address playerAddress;
        uint score;
        uint nukesUsed;
        bool active;
    }

    struct AllTimeLeaderboard {
        address playerAddress;
        uint score;
        uint wins;
        uint nukesUsed;
        bool exists;
    }

    uint _numPlayersWithScoreInGame = 0;
    mapping(address => CurGameScore) _curGamePlayerScoreLookup;
    address[] _curGameAddresses;

    constructor(
        MissileMaker missileMaker,
        LeaderStore leaderStore
    ) BaseNft("UFO Invasion", "UFO") {
        _missileMaker = missileMaker;
        _leaderStore = leaderStore;
    }

    uint _numPlayersOnLeaderboard;
    mapping(address => AllTimeLeaderboard) _allTimeLeaderboardLookup;
    address[] _allTimeLeaderboardAddresses;

    function getMissileMakerContract() public view returns (address) {
        return address(_missileMaker);
    }

    function attackUFO(address sender, uint missileId, uint ufoId) external onlyOwnerOrMain returns (bool) {
        require(_missileMaker.ownerOf(missileId) == sender, "you can't do that");
        require(!_missileMaker.isMissileConsumed(missileId), "this cannot be used again");
        require(_curUFOs[_ufoIdxLookup[ufoId]].curHp > 0, "this cannot be attacked anymore");
        uint missileDmg = _missileMaker.getMissileDmg(missileId);
        updatePlayerScore(sender, missileDmg);
        _curUFOs[_ufoIdxLookup[ufoId]].curHp = _curUFOs[_ufoIdxLookup[ufoId]].curHp.subSafe(missileDmg);
        if (_curUFOs[_ufoIdxLookup[ufoId]].curHp == 0) {
            _curGamePlayerScoreLookup[sender].score += _curUFOs[_ufoIdxLookup[ufoId]].startingHp;
            _allTimeLeaderboardLookup[sender].score += _curUFOs[_ufoIdxLookup[ufoId]].startingHp;
            _burn(ufoId);
            MoreMissilesPlz(mainContract()).emitUfoDestroyed(ufoId, missileId, _curUFOs[_ufoIdxLookup[ufoId]].locationAddress, sender);
            if (isGameOver()) {
                address winner = getWinner();
                GameStats memory gameStats = getGameStats(winner);
                MoreMissilesPlz(mainContract()).emitGameOver(gameStats);
            }
            return true;
        }
        return false;
    }

    function updatePlayerScore(address sender, uint missileDmg) internal {
        // updating player score
        if (!_curGamePlayerScoreLookup[sender].active) {
            _curGamePlayerScoreLookup[sender] = CurGameScore(sender, missileDmg, 1, true);
            if (_numPlayersWithScoreInGame >= _curGameAddresses.length) {
                _curGameAddresses.push(sender);
            } else {
                _curGameAddresses[_numPlayersWithScoreInGame] = sender;
            }
            _numPlayersWithScoreInGame++;
        } else {
            _curGamePlayerScoreLookup[sender].score += missileDmg;
            _curGamePlayerScoreLookup[sender].nukesUsed++;
        }

        if (!_allTimeLeaderboardLookup[sender].exists) {
            _allTimeLeaderboardLookup[sender] = AllTimeLeaderboard(sender, missileDmg, 0, 1, true);
            if (_numPlayersOnLeaderboard == _allTimeLeaderboardAddresses.length) {
                _allTimeLeaderboardAddresses.push(sender);
            } else {
                _allTimeLeaderboardAddresses[_numPlayersOnLeaderboard] = sender;
            }
            _numPlayersOnLeaderboard++;
        } else {
            _allTimeLeaderboardLookup[sender].score += missileDmg;
            _allTimeLeaderboardLookup[sender].nukesUsed++;
        }
    }

    function isGameOver() internal returns (bool) {
        for (uint i = 0; i < _numUfosInGame; i++) {
            if (_curUFOs[i].curHp != 0) {
                return false;
            }
        }
        setIsGameActive(false);
        return true;
    }

    function getWinner() internal returns (address) {
        address highestSeenAddr = address(0x0);
        uint highestSeenScore = 0;
        for (uint i = 0; i < _numPlayersWithScoreInGame; i++) {
            address playerAddr = _curGameAddresses[i];
            CurGameScore memory curGameScore = _curGamePlayerScoreLookup[playerAddr];
            if (
                curGameScore.score > highestSeenScore
                || ( // if there's a tie, take the player with more score all-time, if this is also a tie we take who's first
                    curGameScore.score == highestSeenScore
                    && _allTimeLeaderboardLookup[playerAddr].score > _allTimeLeaderboardLookup[highestSeenAddr].score
                )
                || highestSeenScore == 0
            ) {
                highestSeenScore = curGameScore.score;
                highestSeenAddr = playerAddr;
            }
        }
        _allTimeLeaderboardLookup[highestSeenAddr].wins++;
        return highestSeenAddr;
    }

    function getGameStats(address winner) internal returns (GameStats memory) {
        _gameEndTime = block.timestamp;
        uint gameDurationSeconds = _gameEndTime.sub(_gameStartTime);
        _totalNumGamesPlayed++;
        uint[] memory ufoIds = new uint[](_curUFOs.length);
        for (uint i = 0; i < _curUFOs.length; i++) {
            ufoIds[i] = _curUFOs[i].ufoId;
        }
        GameStats memory gameStats = GameStats(
            _totalNumGamesPlayed,
            _totalUfoHp,
            ufoIds,
            winner,
            gameDurationSeconds,
            _gameStartTime
        );
        _gameStats.push(gameStats);
        return gameStats;
    }

    function startNewUfoInvasionGame(uint randVal) external onlyOwnerOrMain {
        setIsGameActive(true);
        if (_gameStartTime != 0) { // use the default total UFO health when there has never been a game before
            _gameEndTime = _gameEndTime != 0 ? _gameEndTime : block.timestamp;
            _totalUfoHp = getNewTotalUfoHealth(_gameStartTime, _gameEndTime, _wantedGameLengthInHours, _totalUfoHp);
            for (uint i = 0; i < _curUFOs.length; i++) {
                delete _ufoIdxLookup[_curUFOs[i].ufoId];
            }
            for (uint i = 0; i < _numPlayersWithScoreInGame; i++) {
                delete _curGameAddresses[i];
            }
            _numPlayersWithScoreInGame = 0;
        }
        airdropNewUFOs(randVal);
        _gameStartTime = block.timestamp;
    }

    // roll new random number of UFOs
    //
    function airdropNewUFOs(uint randVal) internal  {
        uint newNumUFOs = uint(randVal.randomize(block.timestamp).modSafe(_maxNumUFOs.sub(_minNumUFOs)).add(_minNumUFOs));

        address[] memory ufoAirdropWinners = getHoldersToSendUFOs(randVal, newNumUFOs, findUniqueHolders());

        _numUfosInGame = ufoAirdropWinners.length;

        uint[] memory newUfoHps = rollHpForUFOs(block.timestamp, randVal, _numUfosInGame, _totalUfoHp);

        for (uint i = 0; i < ufoAirdropWinners.length; i++) {
            address locationAddress = ufoAirdropWinners[i];
            uint ufoId = _mintSingleNFT(locationAddress);
            UfoState memory ufoState = UfoState(locationAddress, ufoId, newUfoHps[i], newUfoHps[i]);
            if (_curUFOs.length == 0 || i > _curUFOs.length - 1) {
                _curUFOs.push(ufoState);
            } else {
                _curUFOs[i] = ufoState;
            }
            _ufoIdxLookup[ufoId] = i;
        }
    }

    function _mintSingleNFT(address to) public returns (uint) {
        uint newTokenID = tokenIdx.current();
        _safeMint(to, newTokenID);
        tokenIdx.increment();
        return newTokenID;
    }

    // in the case the last game was completed faster than the length wanted (given by _wantedGameLengthInHours),
    // make the next game's total UFO HP larger as a percentage of the gap and vice-versa
    //
    function getNewTotalUfoHealth(uint gameStartTime, uint gameEndTime, uint wantedGameLengthInHours, uint prevTotalUfoHp) internal pure returns (uint) {
        uint gameLengthHours = gameEndTime.sub(gameStartTime).div(60).div(60);
        uint diff;
        bool longerThanWanted = gameLengthHours > wantedGameLengthInHours;
        if (longerThanWanted) {
            diff = gameLengthHours.sub(wantedGameLengthInHours);
        } else {
            diff = wantedGameLengthInHours.sub(gameLengthHours);
        }
        uint percChange = diff.mul(100).div(wantedGameLengthInHours);
        uint adjustment = prevTotalUfoHp.div(100).mul(percChange);
        uint newTotalUfoHp;
        if (longerThanWanted) {
            newTotalUfoHp = prevTotalUfoHp.sub(adjustment);
        } else {
            newTotalUfoHp = prevTotalUfoHp.add(adjustment);
        }
        return newTotalUfoHp;
    }

    function rollHpForUFOs(uint blockTimestamp, uint randVal, uint numUFOs, uint totalUfoHp) internal pure returns (uint[] memory) {
        uint avgHpPerUfoNeeded;
        uint min;
        uint max;
        uint[] memory ufoHps = new uint[](numUFOs);
        for (uint i = 0; i < numUFOs; i++) {
            // setting hp values for individual UFOs to values within a range (so they're not all the same every
            // match, but ensuring that the total UFO hp ends up roughly around where we want it. this should
            // make the gameplay more varied between matches
            if (i == numUFOs - 1) {
                ufoHps[i] = totalUfoHp;
                break;
            }
            avgHpPerUfoNeeded = totalUfoHp.div(numUFOs.sub(i));
            min = avgHpPerUfoNeeded.subSafe(avgHpPerUfoNeeded.div(10));
            max = avgHpPerUfoNeeded.add(avgHpPerUfoNeeded.div(10));
            ufoHps[i] = uint(randVal.randomize(blockTimestamp, i).modSafe(max.sub(min)).add(min));
            totalUfoHp = totalUfoHp.subSafe(ufoHps[i]);
        }
        return ufoHps;
    }

    function findUniqueHolders() internal returns (address[] memory) {
        WorldLeader[] memory leaders = _leaderStore.getLeaders();
        uint totalUnique = 0;
        for (uint i = 0; i < leaders.length; i++) {
            uint numLeaderNfts = leaders[i].totalSupply();
            for (uint j = 0; j < numLeaderNfts; j++) {
                uint256 leaderNftId = leaders[i].tokenByIndex(j);
                address owner = leaders[i].ownerOf(leaderNftId);
                if (_airdropToIdx[owner]) {
                    continue;
                }
                totalUnique++;
                uint256 idx = ((i.modSafe(leaders.length)).mul(leaders.length)).add(j);
                _airdropToIdx[owner] = true;
                if (_airdropToAddresses.length == 0 || idx > _airdropToAddresses.length - 1) {
                    _airdropToAddresses.push(owner);
                } else {
                    _airdropToAddresses[idx] = owner;
                }
            }
        }
        address[] memory uniqueAddresses = new address[](totalUnique);
        for (uint i = 0; i < totalUnique; i++) {
            uniqueAddresses[i] = _airdropToAddresses[i];
        }

        for (uint i = 0; i < _airdropToAddresses.length; i++) {
            _airdropToIdx[_airdropToAddresses[i]] = false;
        }

        return uniqueAddresses;
    }

    // get a random subset of unique holders of World Leader tokens to send UFOs to
    //
    function getHoldersToSendUFOs(uint randVal, uint numUFOs, address[] memory uniqueHolders) internal view returns (address[] memory) {
        uniqueHolders = block.timestamp.shuffle(randVal, uniqueHolders);
        uint numWinners = uniqueHolders.length <= numUFOs ? uniqueHolders.length : numUFOs;

        address[] memory winners = new address[](numWinners);

        for (uint i = 0; i < numWinners; i++) {
            winners[i] = uniqueHolders[i];
        }

        return winners;
    }

    function setIsGameActive(bool to) public {
        _gameActive = to;
    }

    function isGameActive() external view returns (bool) {
        return _gameActive;
    }

    function getGameStartTime() external view returns (uint) {
        return _gameStartTime;
    }

    function getCurGameNumUFOs() external view returns (uint) {
        return _numUfosInGame;
    }

    function getUfoAtIdx(uint idx) external view returns (UfoState memory) {
        require(idx < _curUFOs.length, "there are not that many ufos in the current game!");
        return _curUFOs[idx];
    }

    function getCurGameNumPlayers() external view returns (uint) {
        return _numPlayersWithScoreInGame;
    }

    function getCurGamePlayerAtIdx(uint idx) external view returns (CurGameScore memory) {
        require(idx < _curGameAddresses.length, "there is no leaderboard entry at this index!");
        require(_curGamePlayerScoreLookup[_curGameAddresses[idx]].active, "this player has not yet played the current game!");
        return _curGamePlayerScoreLookup[_curGameAddresses[idx]];
    }

    function getNumLeaderboardPlayers() external view returns (uint) {
        return _numPlayersOnLeaderboard;
    }

    function getLeaderboardPlayerAtIdx(uint idx) external view returns (AllTimeLeaderboard memory) {
        require(idx < _allTimeLeaderboardAddresses.length, "there is no leaderboard entry at this index!");
        require(_allTimeLeaderboardLookup[_allTimeLeaderboardAddresses[idx]].exists, "this player has never scored any points before!");
        return _allTimeLeaderboardLookup[_allTimeLeaderboardAddresses[idx]];
    }

    function getTotalNumberOfGames() public view returns (uint) {
        return _totalNumGamesPlayed;
    }

    function getGameStatsByGameIdx(uint idx) public view returns (GameStats memory) {
        require(idx < _gameStats.length, "there have no been that many games yet!");
        return _gameStats[idx];
    }

    function getTotalHpForUFOs() public view returns (uint) {
        return _totalUfoHp;
    }

    // ############################################################
    // see MoreMissilesPlz.sol bottom section before using
    //
    function updateMissileMaker(address newMissileMaker) public onlyOwnerOrMain {
        _missileMaker = MissileMaker(newMissileMaker);
    }

    function updateLeaderStore(address newLeaderStore) public onlyOwnerOrMain {
        _leaderStore = LeaderStore(newLeaderStore);
    }

    function updateMinMaxUFOs(uint min, uint max) public onlyOwnerOrMain {
        _minNumUFOs = min;
        _maxNumUFOs = max;
    }

    function updateWantedGameLengthInHours(uint newWantedGameLength) public onlyOwnerOrMain {
        _wantedGameLengthInHours = newWantedGameLength;
    }
}


