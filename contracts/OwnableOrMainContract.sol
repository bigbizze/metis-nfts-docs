// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";


abstract contract OwnableOrMainContract is Ownable {
    address private _mainContract;

    function mainContract() public view virtual returns (address) {
        return _mainContract;
    }

    function setMainContract(address to) public virtual onlyOwner {
        _mainContract = to;
    }


    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwnerOrMain() {
        require(owner() == _msgSender() || mainContract() == _msgSender(), "not owner or main contract");
        _;
    }
    function addressToString(address _addr) public pure returns(string memory) {
        bytes32 value = bytes32(uint256(uint160(_addr)));
        bytes memory alphabet = "0123456789abcdef";

        bytes memory str = new bytes(51);
        str[0] = "0";
        str[1] = "x";
        for (uint i = 0; i < 20; i++) {
            str[2+i*2] = alphabet[uint(uint8(value[i + 12] >> 4))];
            str[3+i*2] = alphabet[uint(uint8(value[i + 12] & 0x0f))];
        }
        return string(str);
    }
}
