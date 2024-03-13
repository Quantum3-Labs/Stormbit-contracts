//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IRegistry} from "../interfaces/IRegistry.sol";
import {LibAppStorage, AppStorage} from "../libraries/LibAppStorage.sol";
import {Errors, Events} from "../libraries/Common.sol";
import {Base} from "./Base.sol";

contract RegistryFacet is IRegistry, Base {
    string public constant override name = "Registry";

    function register(string memory username) external override {
        AppStorage storage s = LibAppStorage.diamondStorage();
        // perform some logic here to register the user
        if (_hasUsername(msg.sender)) {
            revert Errors.UserAlreadyRegistered();
        }
        // check length of username
        if (bytes(username).length > 32 || s.usedUsernames[keccak256(bytes(username))]) {
            revert Errors.InvalidUsername();
        }

        s.usernames[msg.sender] = username;
        s.usedUsernames[keccak256(bytes(username))] = true;

        emit Events.UserRegistered(msg.sender, username);
    }

    function isRegistered(address user) external view override returns (bool) {
        return _hasUsername(user);
    }

    function isUsernameUsed(string memory username) external view override returns (bool) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.usedUsernames[keccak256(bytes(username))];
    }
}
