// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./Helpers.sol";
import "./BaseNft.sol";
import "./WorldLeader.sol";
import "./MissileMaker.sol";

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// this handles the destroy UFO gameplay loop, including dynamically adjusting the difficulty of a match
// so that games approach taking the same amount of time regardless of the # of players playing.
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
contract UfoInvasion is BaseNft("UFO Invasion", "UFO") {
    using Helpers for uint;
    using Helpers for uint16;
    using SafeMath for uint8;
    using SafeMath for uint16;
    using SafeMath for uint32;
    using SafeMath for uint64;
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    struct UfoState {
        uint16 curHp;
        uint16 startingHp;
        uint32 gameNum;
        address locationAddress;
        uint ufoId;
    }

    bool _gameActive = false;
    mapping(uint => uint) _ufoIdxLookup;

    uint32 _totalNumGamesPlayed = 0;
    uint _maxMissilesAtOnce = 5;
    uint _minNumMintedBeforeYouCanAttack = 100;

    mapping(uint => UfoState) _ufoStateLookup;
    struct GameStats {
        bool isOver;
        uint16 totalUfoHp;
        uint32 gameNum;
        address winner;
        uint gameStartTimeInSeconds;
        uint elapsedSecs;
        uint[] ufoIds;
    }

    mapping(uint => GameStats) _gameStats;

    uint16 _totalUfoHp = 2500;

    uint16 _startGameScoreReward = 5;
    uint _gameStartTime = 0;
    uint _gameEndTime;

    uint16 private _minNumUfosToAttack = 3;

    uint8 _minNumUFOs = 7;
    uint8 _maxNumUFOs = 15;

    uint64 _gameWinnerTotalScoreMultiplier = 150; // 150%
    uint64 _ufoKillDmgScoreMultiplier = 150; // 150%
    uint16 _wantedGameLengthInHours = 48;

    // mapping of holder addresses to their index in the _airdropToAddresses array to ensure we get unique addresses
    mapping(address => bool) _airdropToIdx;
    address[] _airdropToAddresses;

    struct CurGameScore {
        bool active;
        uint16 nukesUsed;
        uint64 score;
        address playerAddress;
    }

    struct AllTimeLeaderboard {
        bool exists;
        uint32 wins;
        uint32 nukesUsed;
        uint64 score;
        address playerAddress;
    }

    uint16 _numPlayersWithScoreInGame = 0;
    mapping(address => CurGameScore) _curGamePlayerScoreLookup;
    address[] _curGameAddresses;

    uint _numPlayersOnLeaderboard;
    mapping(address => AllTimeLeaderboard) _allTimeLeaderboardLookup;
    address[] _allTimeLeaderboardAddresses;

    uint32 private _missileTxnId;
    struct MissileAttack {
        uint16 dmg;
        uint16 hpBefore;
        uint16 hpAfter;
        uint32 missileTxnId;
        uint32 gameNum;
        address attacker;
        address locationAddress;
        uint missileId;
        uint ufoId;
    }
    mapping(uint => MissileAttack) _missileAttackLookup;
    function getMissileAttackInfo(uint missileId) public view returns (MissileAttack memory) {
        require(_missileAttackLookup[missileId].dmg > 0
        , "this attack doesn't exist!"
        );
        return _missileAttackLookup[missileId];
    }

    event MissileAttackedUFO(uint32 gameNum, address attacker, uint missileTxnId, uint missileId);
    event GameStart(uint gameNum);
    event GameOver(uint gameNum);

    enum AttackUfoResult {
        OnlyDamageDealt,
        UfoDestroyed,
        UfoDestroyedAndGameOver
    }

    function findNumUfosStillAlive(uint[] memory ufos) private view returns (uint) {
        if (ufos.length == 0) {
            return 0;
        }
        uint stillAliveNum = 0;
        for (uint i = 0; i < ufos.length; i++) {
            if (ufoIsAlive(ufos[i])) {
                stillAliveNum++;
            }
        }
        return stillAliveNum;
    }

    function filterUfosAlive(uint stillAliveNum, uint[] memory ufos) private view returns (uint[] memory) {
        uint[] memory newUfos = new uint[](stillAliveNum);
        uint added = 0;
        for (uint i = 0; i < ufos.length; i++) {
            if (ufoIsAlive(ufos[i])) {
                newUfos[added] = ufos[i];
            }
        }
        return newUfos;
    }

    function verifyNumUfosToAttack(uint16 numUfos, uint16 numAliveUFOs) internal view {
        if (numAliveUFOs >= _minNumUfosToAttack) {
            require(numUfos >= _minNumUfosToAttack
            , "you must provide minNumUfosToAttack UFOs to attack when more than minNumUfosToAttack remain alive!"
            );
        } else {
            require(numUfos <= numAliveUFOs
            , "you cannot provide more ufoIds than there exists UFOs still alive!"
            );
        }
    }

    function attackUFOs(uint randVal, uint[] memory missileIds, uint[] memory ufoIds) external {
        bool allAlive = true;
        for (uint i = 0; i < ufoIds.length; i++) {
            allAlive = _ufoIsAlive(ufoIds[i]);
        }
        require(allAlive
        , "you cannot provide a UFO id for a UFO which is not alive!"
        );
        uint16 numAliveUFOs = uint16(getNumAliveUFOs());
        verifyNumUfosToAttack(uint16(ufoIds.length), numAliveUFOs);
        require(_gameActive
//        , "there is not game currently active!"
        );
        randVal = randVal.add(_totalNumGamesPlayed + 2);
        require(WorldLeader(_ownedContracts.leader).totalSupply() > _minNumMintedBeforeYouCanAttack
//        , "not enough world leader NFTs minted yet!"
        );
        require(_gameActive
//        , "the game is not active!"
        );
        require(missileIds.length < _maxMissilesAtOnce
//        , string(abi.encodePacked("you can only use ", _maxMissilesAtOnce.uint2str(), "at once!"))
        );
        _gameStats[_totalNumGamesPlayed].elapsedSecs = block.timestamp.subSafe(_gameStats[_totalNumGamesPlayed].gameStartTimeInSeconds);
//        uint[] memory randomUfoIds = getRandomUfoIds(randVal, amountUFOs > _gameStats[_totalNumGamesPlayed].ufoIds.length ? _gameStats[_totalNumGamesPlayed].ufoIds.length : amountUFOs);
        for (uint i = 0; i < missileIds.length; i++) {
            uint stillAliveNum = findNumUfosStillAlive(ufoIds);
            if (stillAliveNum != ufoIds.length) {
                ufoIds = filterUfosAlive(stillAliveNum, ufoIds);
            }
            if (ufoIds.length == 0) {
                break;
            }
            randVal = randVal + i;
            uint ufoId = ufoIds[uint(randVal.randomize(block.timestamp, i).modSafe(ufoIds.length))];
            if (!ufoIsAlive(ufoId)) {
                continue;
            }
            if (attackOneUFO(msg.sender, missileIds[i], ufoId) == AttackUfoResult.UfoDestroyedAndGameOver) {
                break;
            }
        }
        _missileTxnId++;
    }

    function attackRandomUFOs(uint randVal, uint[] memory missileIds) external  {
        uint16 numAliveUFOs = uint16(getNumAliveUFOs());
        uint16 amountUFOs = numAliveUFOs < _minNumUfosToAttack ? numAliveUFOs : _minNumUfosToAttack;
        verifyNumUfosToAttack(amountUFOs, numAliveUFOs);
        require(_gameActive
        , "there is not game currently active!"
        );
        randVal = randVal.add(_totalNumGamesPlayed + 2);
        require(WorldLeader(_ownedContracts.leader).totalSupply() > _minNumMintedBeforeYouCanAttack
        , "not enough world leader NFTs minted yet!"
        );
        require(_gameActive
        , "the game is not active!"
        );
        require(missileIds.length < _maxMissilesAtOnce
        , string(abi.encodePacked("you can only use ", _maxMissilesAtOnce.uint2str(), "at once!"))
        );
        _gameStats[_totalNumGamesPlayed].elapsedSecs = block.timestamp.subSafe(_gameStats[_totalNumGamesPlayed].gameStartTimeInSeconds);
        uint[] memory randomUfoIds = getRandomUfoIds(randVal, amountUFOs > _gameStats[_totalNumGamesPlayed].ufoIds.length ? _gameStats[_totalNumGamesPlayed].ufoIds.length : amountUFOs);
        for (uint i = 0; i < missileIds.length; i++) {
            uint stillAliveNum = findNumUfosStillAlive(randomUfoIds);
            if (stillAliveNum != randomUfoIds.length) {
                randomUfoIds = filterUfosAlive(stillAliveNum, randomUfoIds);
            }
            if (randomUfoIds.length == 0) {
                break;
            }
            randVal = randVal + i;
            uint ufoId = randomUfoIds[uint(randVal.randomize(block.timestamp, i).modSafe(randomUfoIds.length))];
            if (!ufoIsAlive(ufoId)) {
                continue;
            }
            if (attackOneUFO(msg.sender, missileIds[i], ufoId) == AttackUfoResult.UfoDestroyedAndGameOver) {
                break;
            }
        }
        _missileTxnId++;
    }

    function attackOneUFO(address sender, uint missileId, uint ufoId) private returns (AttackUfoResult) {
        require(_exists(ufoId)
        , "this cannot be attacked anymore"
        );
        uint64 missileDmg = MissileMaker(_ownedContracts.missileMaker)._getMissileDmg(sender, missileId);
        updatePlayerScore(sender, missileDmg);
        uint16 hpBefore = _ufoStateLookup[ufoId].curHp;
        _ufoStateLookup[ufoId].curHp = uint16(_ufoStateLookup[ufoId].curHp.subSafe(missileDmg));
        _curGamePlayerScoreLookup[sender].score += missileDmg;
        _allTimeLeaderboardLookup[sender].score += missileDmg;
        emit MissileAttackedUFO(_totalNumGamesPlayed, sender, _missileTxnId, missileId);
        _missileAttackLookup[missileId] = MissileAttack(uint16(missileDmg), hpBefore,  _ufoStateLookup[ufoId].curHp, _missileTxnId, _totalNumGamesPlayed, sender, ownerOf(ufoId), missileId, ufoId);
        if (_ufoStateLookup[ufoId].curHp == 0) {
            missileDmg = uint64(missileDmg.mul(_ufoKillDmgScoreMultiplier).div(100).subSafe(missileDmg));
            _curGamePlayerScoreLookup[sender].score += missileDmg;
            _allTimeLeaderboardLookup[sender].score += missileDmg;
            burn(ufoId);
            if (isGameOver()) {
                _gameStats[_totalNumGamesPlayed].winner = getWinner();
                missileDmg = uint64(_curGamePlayerScoreLookup[sender].score.mul(_gameWinnerTotalScoreMultiplier).div(100).subSafe(_curGamePlayerScoreLookup[sender].score));
                _curGamePlayerScoreLookup[_gameStats[_totalNumGamesPlayed].winner].score += missileDmg;
                _allTimeLeaderboardLookup[_gameStats[_totalNumGamesPlayed].winner].score += missileDmg;
                _gameStats[_totalNumGamesPlayed].isOver = true;
                _gameEndTime = block.timestamp;
                return AttackUfoResult.UfoDestroyedAndGameOver;
            }
            return AttackUfoResult.UfoDestroyed;
        }
        return AttackUfoResult.OnlyDamageDealt;
    }

    function updatePlayerScore(address sender, uint64 missileDmg) internal {
        if (!_curGamePlayerScoreLookup[sender].active) {
            _curGamePlayerScoreLookup[sender] = CurGameScore(true, 1, missileDmg, sender);
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
            _allTimeLeaderboardLookup[sender] = AllTimeLeaderboard(true, 0, 1, missileDmg, sender);
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
        for (uint i = 0; i < _gameStats[_totalNumGamesPlayed].ufoIds.length; i++) {
            if (_ufoStateLookup[_gameStats[_totalNumGamesPlayed].ufoIds[i]].curHp != 0) {
                return false;
            }
        }
        emit GameOver(_totalNumGamesPlayed);
        _totalNumGamesPlayed++;
        _setIsGameActive(false);
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
                || highestSeenAddr == address(0x0)
            ) {
                highestSeenScore = curGameScore.score;
                highestSeenAddr = playerAddr;
            }
        }
        _allTimeLeaderboardLookup[highestSeenAddr].wins++;
        return highestSeenAddr;
    }

    function startNewUfoInvasionGame(uint randVal) public {
        randVal = randVal.add(_totalNumGamesPlayed + 1);
        require(!_gameActive);
        _setIsGameActive(true);
        if (_gameStartTime != 0 && _gameEndTime != 0) { // use the default total UFO health when there has never been a game before
            _totalUfoHp = getNewTotalUfoHealth(_gameStartTime, _gameEndTime, uint(_wantedGameLengthInHours), uint(_totalUfoHp));
            for (uint i = 0; i < _numPlayersWithScoreInGame; i++) {
                delete _curGameAddresses[i];
            }
            _numPlayersWithScoreInGame = 0;
        }
        airdropNewUFOs(randVal);
        // reward players for paying to start new game
        _curGamePlayerScoreLookup[msg.sender].score += uint64(_totalUfoHp.mul(_startGameScoreReward).div(100));
        emit GameStart(_totalNumGamesPlayed);
    }

    // roll new random number of UFOs
    //
    function airdropNewUFOs(uint randVal) internal  {
        uint newNumUFOs = uint(randVal.randomize(block.timestamp).modSafe(_maxNumUFOs.sub(_minNumUFOs)).add(_minNumUFOs));

        address[] memory ufoAirdropWinners = getHoldersToSendUFOs(randVal, newNumUFOs, findUniqueHolders());

        uint16[] memory newUfoHps = rollHpForUFOs(block.timestamp, randVal, ufoAirdropWinners.length, _totalUfoHp);

        uint[] memory ufoIds = new uint[](ufoAirdropWinners.length);

        for (uint i = 0; i < ufoAirdropWinners.length; i++) {
            address locationAddress = ufoAirdropWinners[i];
            uint ufoId = _mintSingleNFT(locationAddress);
            _ufoIdxLookup[ufoId] = i;
            ufoIds[i] = ufoId;
            _ufoStateLookup[ufoId] = UfoState(newUfoHps[i], newUfoHps[i], _totalNumGamesPlayed, locationAddress, ufoId);
        }
        _gameStats[_totalNumGamesPlayed] = GameStats(
            false,
            _totalUfoHp,
            _totalNumGamesPlayed,
            address(0x0),
            _gameStartTime,
            0,
            ufoIds
        );
    }

    function _mintSingleNFT(address to) private returns (uint) {
        uint newTokenID = tokenIdx.current();
        _safeMint(to, newTokenID);
        tokenIdx.increment();
        return newTokenID;
    }

    // in the case the last game was completed faster than the length wanted (given by _wantedGameLengthInHours),
    // make the next game's total UFO HP larger as a percentage of the gap and vice-versa
    //
    function getNewTotalUfoHealth(uint gameStartTime, uint gameEndTime, uint wantedGameLengthInHours, uint prevTotalUfoHp) internal pure returns (uint16) {
        uint gameLengthHours = uint16(gameEndTime.sub(gameStartTime).div(60).div(60));
        uint diff = gameLengthHours > wantedGameLengthInHours
            ? gameLengthHours.sub(wantedGameLengthInHours)
            : wantedGameLengthInHours.sub(gameLengthHours);
        uint adjustment = prevTotalUfoHp.div(100).mul(diff.mul(100).div(wantedGameLengthInHours));
        uint newTotalUfoHp = gameLengthHours > wantedGameLengthInHours
            ? prevTotalUfoHp.sub(adjustment)
            : prevTotalUfoHp.add(adjustment);
        return uint16(newTotalUfoHp);
    }

    function rollHpForUFOs(uint blockTimestamp, uint randVal, uint numUFOs, uint16 totalUfoHp) internal pure returns (uint16[] memory) {
        uint avgHpPerUfoNeeded;
        uint min;
        uint max;
        uint16[] memory ufoHps = new uint16[](numUFOs);
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
            ufoHps[i] = uint16(randVal.randomize(blockTimestamp, i).modSafe(max.sub(min)).add(min));
            totalUfoHp = uint16(totalUfoHp.subSafe(ufoHps[i]));
        }
        return ufoHps;
    }

    function findUniqueHolders() internal returns (address[] memory) {
        uint totalUnique = 0;
        WorldLeader leader = WorldLeader(_ownedContracts.leader);
        uint numLeaderNfts = leader.totalSupply();

        for (uint i = 0; i < numLeaderNfts; i++) {
            uint256 leaderNftId = leader.tokenByIndex(i);
            address owner = leader.ownerOf(leaderNftId);
            if (_airdropToIdx[owner]) {
                continue;
            }
            totalUnique++;
            _airdropToIdx[owner] = true;
            if (i >= _airdropToAddresses.length) {
                _airdropToAddresses.push(owner);
            } else {
                _airdropToAddresses[i] = owner;
            }
        }
        address[] memory uniqueAddresses = new address[](totalUnique);
        for (uint i = 0; i < totalUnique; i++) {
            uniqueAddresses[i] = _airdropToAddresses[i];
        }

        for (uint i = 0; i < totalUnique; i++) {
            _airdropToIdx[_airdropToAddresses[i]] = false;
        }

        return uniqueAddresses;
    }

    // get a random subset of unique holders of World Leader tokens to send UFOs to
    //
    function getHoldersToSendUFOs(uint randVal, uint numUFOs, address[] memory uniqueHolders) internal view returns (address[] memory) {
        uniqueHolders = randVal.shuffle(block.timestamp, uniqueHolders);
        uint numWinners = uniqueHolders.length <= numUFOs ? uniqueHolders.length : numUFOs;

        address[] memory winners = new address[](numWinners);

        for (uint i = 0; i < numWinners; i++) {
            winners[i] = uniqueHolders[i];
        }

        return winners;
    }

    function getRandomUfoIds(uint randVal, uint amountUFOs) private view returns (uint[] memory) {
        uint numAliveUFOs = getNumAliveUFOs();
        uint[] memory ufoIds = new uint[](numAliveUFOs);
        uint foundAlive = 0;
        for (uint i = 0; i < _gameStats[_totalNumGamesPlayed].ufoIds.length; i++) {
            if (_ufoStateLookup[_gameStats[_totalNumGamesPlayed].ufoIds[i]].curHp != 0) {
                ufoIds[foundAlive] = _gameStats[_totalNumGamesPlayed].ufoIds[i];
                foundAlive++;
            }
        }
        ufoIds = randVal.shuffle(block.timestamp, ufoIds);
        uint numRandom = amountUFOs > numAliveUFOs ? numAliveUFOs : amountUFOs;
        uint[] memory randomUfos = new uint[](numRandom);
        for (uint i = 0; i < numRandom; i++) {
            randomUfos[i] = ufoIds[i];
        }
        return randomUfos;
    }

    function getNumAliveUFOs() internal view returns (uint) {
        uint numAliveUfos = 0;
        for (uint i = 0; i < _gameStats[_totalNumGamesPlayed].ufoIds.length; i++) {
            if (_ufoStateLookup[_gameStats[_totalNumGamesPlayed].ufoIds[i]].curHp != 0) {
                numAliveUfos++;
            }
        }
        return numAliveUfos;
    }

    function _ufoIsAlive(uint ufoId) internal view returns (bool) {
        return _ufoStateLookup[ufoId].curHp > 0;
    }

    function ufoIsAlive(uint ufoId) public view returns (bool) {
        return _ufoIsAlive(ufoId);
    }

    function _getUfoAtIdxByGameNum(uint ufoIdx, uint gameNum) internal view returns (UfoState memory) {
        GameStats memory gameStats = _getGameStatsByGameNum(gameNum);
        require(ufoIdx < gameStats.ufoIds.length
//        , "there are not that many ufos in the current game!"
        );
        require(_existsOrBurned(gameStats.ufoIds[ufoIdx])
//        , "ufo at this id does not exist!"
        );
        UfoState memory ufoState = _ufoStateLookup[gameStats.ufoIds[ufoIdx]];
        ufoState.locationAddress = _ownerOfSafe(gameStats.ufoIds[ufoIdx]);
        return ufoState;
    }

    function _getGameStatsByGameNum(uint gameNum) internal view returns (GameStats memory) {
        require(gameNum <= _totalNumGamesPlayed
//        , "there have not been that many games yet!"
        );
        GameStats memory gameStats = _gameStats[gameNum];
        if (!gameStats.isOver) {
            gameStats.elapsedSecs = block.timestamp.sub(gameStats.gameStartTimeInSeconds);
        }
        return gameStats;
    }

    function _setIsGameActive(bool to) internal {
        _gameActive = to;
    }

    // ********** PUBLIC DATA QUERY METHODS **********

    // returns whether there is currently a game active or not
    function isGameActive() external view returns (bool) {
        return _gameActive;
    }

    // returns the number of UFOs in the game index by `gameNum`
    function getNumUFOsInGameByGameNum(uint gameNum) external view returns (uint) {
        return _getGameStatsByGameNum(gameNum).ufoIds.length;
    }

    // calls getNumUFOsInGameByGameNum(_totalNumGamesPlayed)
    function getCurGameNumUFOs() external view returns (uint) {
        if (!_gameActive && _totalNumGamesPlayed == 0) {
            return 0;
        }
        return _getGameStatsByGameNum(_totalNumGamesPlayed).ufoIds.length;
    }

    // returns information about the UFO at the index `ufoIdx` for the game number `gameNum`
    function getUfoAtIdxByGameNum(uint ufoIdx, uint gameNum) external view returns (UfoState memory) {
        return _getUfoAtIdxByGameNum(ufoIdx, gameNum);
    }

    // calls getNumUFOsInGameByGameNum(_totalNumGamesPlayed)
    function getUfoAtIdxInCurrentGame(uint ufoIdx) external view returns (UfoState memory) {
        require(_totalNumGamesPlayed > 0 || _gameActive
//        , "there has never been a game before!"
        );
        uint32 curOrPrevGameNum = _gameActive ? _totalNumGamesPlayed : uint32(_totalNumGamesPlayed.sub(1));
        return _getUfoAtIdxByGameNum(ufoIdx, curOrPrevGameNum);
    }

    // returns the number of players in the current game's stats
    function getCurGameNumPlayers() external view returns (uint) {
        return _numPlayersWithScoreInGame;
    }

    // returns the stats for the player at the index `idx` for the current game
    function getCurGamePlayerAtIdx(uint idx) external view returns (CurGameScore memory) {
        require(idx < _curGameAddresses.length
//                , "there is no leaderboard entry at this index!"
        );
        require(_curGamePlayerScoreLookup[_curGameAddresses[idx]].active
//                , "this player has not yet played the current game!"
        );
        return _curGamePlayerScoreLookup[_curGameAddresses[idx]];
    }

    // returns the total number of players who have stats on the leaderboard
    function getNumLeaderboardPlayers() external view returns (uint) {
        return _numPlayersOnLeaderboard;
    }

    // returns the leaderboard information for the player at the index `idx`
    function getLeaderboardPlayerAtIdx(uint idx) external view returns (AllTimeLeaderboard memory) {
        require(idx < _allTimeLeaderboardAddresses.length
//                , "there is no leaderboard entry at this index!"
        );
        require(_allTimeLeaderboardLookup[_allTimeLeaderboardAddresses[idx]].exists
//                , "this player has never scored any points before!"
        );
        return _allTimeLeaderboardLookup[_allTimeLeaderboardAddresses[idx]];
    }

    // returns the total number of games played so far
    function getTotalNumberOfGames() public view returns (uint) {
        return _totalNumGamesPlayed;
    }

    // returns the game stats for the game with the idx `gameNum`
    function getGameStatsByGameNum(uint gameNum) public view returns (GameStats memory) {
        return _getGameStatsByGameNum(gameNum);
    }

    // returns the total hp for all UFOs in the current or last game
    function getTotalHpForUFOs() public view returns (uint) {
        return _totalUfoHp;
    }

    // ********** ONLY OWNER PARAMETER CHANGING **********
    function setIsGameActive(bool to) public onlyOwner {
        _setIsGameActive(to);
    }

    function updateMinMaxUFOs(uint8 min, uint8 max) public onlyOwner {
        _minNumUFOs = min;
        _maxNumUFOs = max;
    }

    function updateWantedGameLengthInHours(uint16 newWantedGameLength) public onlyOwner {
        _wantedGameLengthInHours = newWantedGameLength;
    }

    function setGameWinnerTotalScoreMultiplier(uint64 to) public onlyOwner {
        require(to >= 100
//        , "game winner score multiplier must be at least 100 (150x)!"
        );
        _gameWinnerTotalScoreMultiplier = to;
    }

    function setUfoKillDmgScoreMultiplier(uint64 to) public onlyOwner {
        require(to >= 100
//        , "ufo kill damage multiplier must be at least 100 (150x)!"
        );
        _ufoKillDmgScoreMultiplier = to;
    }

    function setStartGameScoreReward(uint16 to) public onlyOwner {
        require(to < 100
//        , "start game score reward must be less than 100 because it's a %!"
        );
        _startGameScoreReward = to;
    }

    function setMaxNumMissilesInOneTxn(uint newMax) public onlyOwner {
        _maxMissilesAtOnce = newMax;
    }

    function setMinNumMintedBeforeYouCanAttack(uint newMin) public onlyOwner {
        _minNumMintedBeforeYouCanAttack = newMin;
    }

    function setMinNumUfosToAttack(uint16 to) public onlyOwner {
        require(to > 0
        , "to value for setMinNumUfosToAttack must be greater than 0!"
        );
        _minNumUfosToAttack = to;
    }
}


