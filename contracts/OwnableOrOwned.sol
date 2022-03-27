// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";


abstract contract OwnableOrOwned is Ownable {
    struct OwnedContracts {
        address leader;
        address missileMaker;
        address ufoInvasion;
    }
    OwnedContracts internal _ownedContracts;

    function ownedContracts() private view returns (OwnedContracts memory) {
        return _ownedContracts;
    }

    function _setUfoInvasion(address to) internal {
        _ownedContracts.ufoInvasion = to;
    }

    function _setOwnedContracts(
        address leader,
        address missileMaker,
        address ufoInvasion
    ) public virtual onlyOwner {
        _ownedContracts = OwnedContracts(leader, missileMaker, ufoInvasion);
    }
}
