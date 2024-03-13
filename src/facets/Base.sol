//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {LibAppStorage, AppStorage} from "../libraries/LibAppStorage.sol";
import {Errors} from "../libraries/Common.sol";

/// @title Base contract for all facets
/// @author Quantum3 Labs <security@quantum3labs.com>
/// @notice This contract will host modifiers and custom errors

// TODO: Add reentrancy guard

contract Base {
    function _hasUsername(address _user) internal view returns (bool) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return keccak256(bytes(s.usernames[_user])) != keccak256(bytes(""));
    }

    modifier onlyGovernor() {
        AppStorage storage s = LibAppStorage.diamondStorage();
        if (msg.sender != s.governor) {
            revert Errors.CallerIsNotGovernor();
        }
        _;
    }

    modifier onlyRegisteredUser() {
        require(_hasUsername(msg.sender), "User is not registered");
        _;
    }
}
