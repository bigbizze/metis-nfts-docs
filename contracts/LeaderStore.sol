// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./WorldLeader.sol";
import "./OwnableOrMainContract.sol";

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// because there are N leader NFT collections (for e.g. Biden, Putin, Xi etc. etc.), this contract manages
// the state of them for other contracts to work with
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
contract LeaderStore is OwnableOrMainContract {

    WorldLeader[] public leaders;
    address _moreMissilesPlzAddress;

    function getLeaderContractAddressByName(string memory name) public view returns (address) {
        bytes32 namePacked = keccak256(abi.encodePacked(name));
        for (uint i = 0; i < leaders.length; i++) {
            if (keccak256(abi.encodePacked(leaders[i].leaderName())) == namePacked) {
                return address(leaders[i]);
            }
        }
        revert(string(abi.encodePacked("couldn't find a world leader with the name ", name)));
    }

    function addLeaderContract(address contractAddress) public onlyOwnerOrMain {
        WorldLeader leader = WorldLeader(contractAddress);
        require(owner() == leader.owner(), "only the owner can do that!");
        require(!isAddressLeader(contractAddress), "a leader with this address already exists!");
        leaders.push(leader);
    }

    function getAddedLeaderAddresses() public view returns (address[] memory) {
        address[] memory leadersOut = new address[](leaders.length);
        for (uint i = 0; i < leaders.length; i++) {
            leadersOut[i] = address(leaders[i]);
        }
        return leadersOut;
    }

    function isAddressLeader(address addr) internal view returns (bool) {
        for (uint i = 0; i < leaders.length; i++) {
            if (address(leaders[i]) == addr) {
                return true;
            }
        }
        return false;
    }

    function getLeader(address addr) public view returns (WorldLeader) {
        for (uint i = 0; i < leaders.length; i++) {
            if (address(leaders[i]) == addr) {
                return WorldLeader(leaders[i]);
            }
        }
        revert("didn't find this world leader!");
    }

    function getLeaders() public view returns (WorldLeader[] memory) {
        WorldLeader[] memory leadersOut = new WorldLeader[](leaders.length);
        for (uint i = 0; i < leaders.length; i++) {
            leadersOut[i] = leaders[i];
        }
        return leadersOut;
    }

    // ############################################################
    // see MoreMissilesPlz.sol bottom section before using
    //
    function updateMissileMakerForLeaders(address newMissileMaker) public onlyOwnerOrMain {
        for (uint i = 0; i < leaders.length; i++) {
            leaders[i].updateMissileMaker(newMissileMaker);
        }
    }

    function setMoreMissilesPlzAddress(address to) public onlyOwnerOrMain {
        _moreMissilesPlzAddress = to;
    }
}
