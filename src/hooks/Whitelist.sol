// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Hooks} from "../libraries/Hooks.sol";
import {BaseHook} from "./BaseHook.sol";
import {ILendingManager} from "../interfaces/managers/lending/ILendingManager.sol";

contract WhiteList is BaseHook {
    mapping(address user => bool isWhiteListed) private whitelist;

    constructor(ILendingManager _manager, address[] memory whiteListedAddrs) BaseHook(_manager) {
        for (uint256 i = 0; i < whiteListedAddrs.length; i++) {
            whitelist[whiteListedAddrs[i]] = true;
        }
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({beforeDepositToTerm: true});
    }

    function beforeDepositToTerm(address from, address token, uint256 termId, uint256 shares)
        external
        override
        onlyByManager
        returns (bool)
    {
        require(whitelist[from], "WhiteList: not whitelisted");
        return true;
    }

    function addWhiteList(address user) external {
        whitelist[user] = true;
    }
}
