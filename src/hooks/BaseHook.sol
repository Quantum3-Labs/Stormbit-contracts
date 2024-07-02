// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {IHooks} from "../interfaces/hooks/IHooks.sol";
import {Hooks} from "../libraries/Hooks.sol";
import {ILendingManager} from "../interfaces/managers/lending/ILendingManager.sol";

abstract contract BaseHook is IHooks {
    error NotManager();

    ILendingManager public immutable manager;

    constructor(ILendingManager _manager) {
        manager = _manager;
        validateHookAddress(this);
    }

    modifier onlyByManager() {
        if (msg.sender != address(manager)) revert NotManager();
        _;
    }

    function getHookPermissions() public pure virtual returns (Hooks.Permissions memory);

    function validateHookAddress(BaseHook _this) internal pure virtual {
        Hooks.validateHookPermissions(_this, getHookPermissions());
    }
}
