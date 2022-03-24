// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

library Helpers {
    using SafeMath for uint;
    function shuffle(uint blockTimestamp, uint randVal, address[] memory uniqueHolders) internal pure returns (address[] memory) {
        for (uint256 i = 0; i < uniqueHolders.length; i++) {
            uint256 n = i.add(uint256(keccak256(abi.encodePacked(blockTimestamp, randVal, i))).mod(uniqueHolders.length.sub(i)));
            address temp = uniqueHolders[n];
            uniqueHolders[n] = uniqueHolders[i];
            uniqueHolders[i] = temp;
        }
        return uniqueHolders;
    }

    function uint2str(uint256 _i) internal pure returns (string memory str) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 length;
        while (j != 0) {
            length++;
            j /= 10;
        }
        bytes memory bstr = new bytes(length);
        uint256 k = length;
        j = _i;
        while (j != 0) {
            bstr[--k] = bytes1(uint8(48 + j % 10));
            j /= 10;
        }
        str = string(bstr);
    }

    function secsToDays(uint secs) internal pure returns (uint) {
        return secs.div(60).div(60).div(24);
    }

    function daysToSecs(uint numDays) internal pure returns (uint) {
        return numDays.mul(60).mul(60).mul(24);
    }

    function secsToHours(uint numSecs) internal pure returns (uint) {
        return numSecs.div(60).div(60);
    }

    function hoursToSecs(uint numHours) internal pure returns (uint) {
        return numHours.mul(60).mul(60);
    }

    function randomize(uint randVal, uint blockTimestamp, uint idx) internal pure returns (uint) {
        return uint256(keccak256(abi.encodePacked(blockTimestamp, randVal.add(idx.add(1)))));
    }

    function randomize(uint randVal, uint blockTimestamp) internal pure returns (uint) {
        return uint256(keccak256(abi.encodePacked(blockTimestamp, randVal)));
    }

    function modSafe(uint this_, uint by) internal pure returns (uint) {
        uint byThisSafe = by > 0 ? by : 1;
        return this_.mod(byThisSafe);
    }

    function subSafe(uint this_, uint by) internal pure returns (uint) {
        if (by > this_) {
            return 0;
        }
        return this_.sub(by);
    }
}

