// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @title Custom Diamond Init Contract (EIP-2535)
/// @author Quantum3 Labs <security@quantum3labs.com>

import {LibAppStorage, AppStorage} from "../libraries/LibAppStorage.sol";
import {Errors} from "../libraries/Common.sol";
import {Base} from "../facets/Base.sol";

struct InitParams {
    address initialGovernor;
}

contract DiamondInit {
    function initialize(InitParams memory _params) external {
        AppStorage storage s = LibAppStorage.diamondStorage();
        if (s.initialized) {
            revert Errors.AlreadyInitialized();
        }
        if (_params.initialGovernor == address(0)) {
            revert Errors.OwnerCannotBeZeroAddress();
        }
        s.initialized = true;
        s.governor = _params.initialGovernor;
    }
}
