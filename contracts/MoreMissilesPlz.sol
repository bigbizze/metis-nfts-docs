// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./MissileMaker.sol";
import "./UfoInvasion.sol";
import "./WorldLeader.sol";
import "./LeaderStore.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// main client interface for the project
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
contract MoreMissilesPlz is Ownable {
    MissileMaker internal _missileMaker;
    LeaderStore internal _leaderStore;
    UfoInvasion internal _ufoInvasion;

    constructor(
        LeaderStore leaderStore,
        MissileMaker missileMaker,
        UfoInvasion ufoInvasion
    ) {
        _leaderStore = leaderStore;
        _missileMaker = missileMaker;
        _ufoInvasion = ufoInvasion;
    }

    function getWorldLeaderMintContract(string memory leaderName) public view returns (address) {
        return _leaderStore.getLeaderContractAddressByName(leaderName);
    }

    function canUserRollAnyMissiles() public view returns (bool) {
        WorldLeader[] memory leaders = _leaderStore.getLeaders();
        for (uint i = 0; i < leaders.length; i++) {
            if (leaders[i].numMissilesReadyToRoll(msg.sender) > 0) {
                return true;
            }
        }
        return false;
    }

    function numMissilesReadyToRoll() public view returns (uint) {
        WorldLeader[] memory leaders = _leaderStore.getLeaders();
        uint numReady = 0;
        for (uint i = 0; i < leaders.length; i++) {
            numReady += leaders[i].numMissilesReadyToRoll(msg.sender);
        }
        return numReady;
    }

    // method for users to call when they want to roll for a chance at getting a missile
    //
    function maybeGetMissiles(uint randVal) public {
        WorldLeader[] memory leaders = _leaderStore.getLeaders();
        for (uint i = 0; i < leaders.length; i++) {
            if (leaders[i].doesUserOwnAnyOfThisWorldLeader(msg.sender)) {
                WorldLeader.MissileOdds memory missileOdds = leaders[i].maybeGetMissiles(msg.sender, randVal, _missileMaker.missileChancePerc());
                _missileMaker.createMissiles(msg.sender, randVal, missileOdds.leaderNftIds, missileOdds.numMissilesToMint);
            }
        }
    }

    // for adding a new world leader NFT collection to the game. for e.g., if you wanted to add a "Putin"
    //  collection later on you'd use this
    //
    function addLeaderContract(address contractAddress) public onlyOwner {
        _leaderStore.addLeaderContract(contractAddress);
    }

    // starts a new ufo invasion game match
    //
    function startNewUfoInvasionGame(uint randVal) public onlyOwner {
        _ufoInvasion.startNewUfoInvasionGame(randVal);
    }

    // the method for a user using their missile to attack a UFO
    //
    function attackUFO(uint[] memory missileIds, uint ufoId) public {
        for (uint i = 0; i < missileIds.length; i++) {
            bool ufoTargetDead = _ufoInvasion.attackUFO(msg.sender, missileIds[i], ufoId);
            _missileMaker.burnMissile(missileIds[i]);
            if (ufoTargetDead) {
                break;
            }
        }
    }

    function getUfoInvasionAddress() public view returns (address) {
        return address(_ufoInvasion);
    }

    function withdraw() public onlyOwner {
        WorldLeader[] memory leaders = _leaderStore.getLeaders();
        for (uint i = 0; i < leaders.length; i++) {
            leaders[i].withdraw();
        }
    }

    function getWorldLeaderBalance() public onlyOwner view returns (uint) {
        WorldLeader[] memory leaders = _leaderStore.getLeaders();
        uint totalBalance = 0;
        for (uint i = 0; i < leaders.length; i++) {
            totalBalance += leaders[i].getBalance();
        }
        return totalBalance;
    }

    function setRecipients(address payable[] memory recipients) public onlyOwner {
        WorldLeader[] memory leaders = _leaderStore.getLeaders();
        for (uint i = 0; i < leaders.length; i++) {
            for (uint j = 0; j < recipients.length; j++) {
                leaders[i].setRecipient(recipients[j]);
            }
        }
    }

    function isRecipient(address payable recipient) public view onlyOwner returns(bool) {
        WorldLeader[] memory leaders = _leaderStore.getLeaders();
        if (leaders.length == 0) {
            return false;
        }
        bool isRecip = true;
        for (uint i = 0; i < leaders.length; i++) {
            isRecip = leaders[i].isRecipient(recipient);
        }
        return isRecip;
    }

    function tokensOfOwner(address _owner) public view returns (uint[] memory) {
        WorldLeader[] memory leaders = _leaderStore.getLeaders();
        uint numOwned = 0;
        for (uint i = 0; i < leaders.length; i++) {
            numOwned += leaders[i].tokensOfOwner(_owner).length;
        }
        uint[] memory tokensOwned = new uint[](numOwned);
        for (uint i = 0; i < leaders.length; i++) {
            uint[] memory ownedTokens = leaders[i].tokensOfOwner(_owner);
            for (uint j = 0; j < ownedTokens.length; j++) {
                uint256 idx = ((i % leaders.length) * leaders.length) + j;
                tokensOwned[idx] = ownedTokens[j];
            }
        }
        return tokensOwned;
    }

    function getGameStartTime() public view returns (uint) {
        return _ufoInvasion.getGameStartTime();
    }

    function isGameActive() public view returns (bool) {
        return _ufoInvasion.isGameActive();
    }

    function getUserMissiles(address userAddr) public view returns (uint[] memory) {
        return _missileMaker.getUserMissiles(userAddr);
    }

    // ############################################################
    // functions for getting data about the ufo invasion game state
    //
    function getCurGameNumUFOs() public view returns (uint) {
        return _ufoInvasion.getCurGameNumUFOs();
    }

    function getUfoAtIdx(uint idx) public view returns (UfoInvasion.UfoState memory) {
        return _ufoInvasion.getUfoAtIdx(idx);
    }

    function getCurGameNumPlayers() public view returns (uint) {
        return _ufoInvasion.getCurGameNumPlayers();
    }

    function getCurGamePlayerAtIdx(uint idx) public view returns (UfoInvasion.CurGameScore memory) {
        return _ufoInvasion.getCurGamePlayerAtIdx(idx);
    }

    function getNumLeaderboardPlayers() public view returns (uint) {
        return _ufoInvasion.getNumLeaderboardPlayers();
    }

    function getLeaderboardPlayerAtIdx(uint idx) public view returns (UfoInvasion.AllTimeLeaderboard memory) {
        return _ufoInvasion.getLeaderboardPlayerAtIdx(idx);
    }

    function getTotalNumberOfGames() public view returns (uint) {
        return _ufoInvasion.getTotalNumberOfGames();
    }

    function getGameStatsByGameIdx(uint idx) public view returns (UfoInvasion.GameStats memory) {
        return _ufoInvasion.getGameStatsByGameIdx(idx);
    }

    // ############################################################
    // events
    //
    event MissileCreated(address owner, uint[] leaderNftIds, uint missileNftId, uint damage);
    event UfoDestroyed(uint ufoId, uint missileId, address locationAddress, address killerAddress);
    event GameOver(uint gameNumber, uint totalUfoHp, uint[] ufoIds, address winner, uint gameLengthinSeconds, uint gameStartTimeinSeconds);

    function emitMissileCreated(address sender, uint[] calldata leaderNftIds, uint missileNftId, uint dmg) external {
        require(msg.sender == address(_missileMaker), "you can't do that");
        emit MissileCreated(sender, leaderNftIds, missileNftId, dmg);
    }

    function emitUfoDestroyed(uint ufoId, uint missileId, address locationAddress, address killerAddress) external {
        require(msg.sender == address(_ufoInvasion), "you can't do that");
        emit UfoDestroyed(ufoId, missileId, locationAddress, killerAddress);
    }

    function emitGameOver(UfoInvasion.GameStats calldata gameStats) external {
        require(msg.sender == address(_ufoInvasion), "you can't do that");
        emit GameOver(gameStats.gameNumber, gameStats.totalUfoHp, gameStats.ufoIds, gameStats.winner, gameStats.gameLengthInSeconds, gameStats.gameStartTimeInSeconds);
    }

    // ############################################################
    // if you need to change contract for the game (make sure you've mapped the data from the existing one first)
    //
    function updateMissileMaker(address newMissileMaker) public onlyOwner {
        _missileMaker = MissileMaker(newMissileMaker);
        _ufoInvasion.updateMissileMaker(newMissileMaker);
        _leaderStore.updateMissileMakerForLeaders(newMissileMaker);
    }

    function updateUfoInvasion(address newUfoInvasion) public onlyOwner {
        _ufoInvasion = UfoInvasion(newUfoInvasion);
    }

    function updateLeaderStore(address newWorldLeaderStore) public onlyOwner {
        _leaderStore = LeaderStore(newWorldLeaderStore);
        _missileMaker.updateLeaderStore(newWorldLeaderStore);
        _ufoInvasion.updateLeaderStore(newWorldLeaderStore);
    }
}
