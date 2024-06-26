pragma solidity ^0.8.21;

import {IHooks} from "../interfaces/hooks/IHooks.sol";

library Hooks {
    using Hooks for IHooks;

    struct Permissions {
        bool beforeDepositToTerm;
    }

    /**
     * Custom errors *
     */
    error HookAddressNotValid(address hooks);

    function validateHookPermissions(IHooks self, Permissions memory permissions) internal pure {
        // the hook contract must implement at least one hook
        if (!permissions.beforeDepositToTerm) {
            revert HookAddressNotValid(address(self));
        }
    }
}
