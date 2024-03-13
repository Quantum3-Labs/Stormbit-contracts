//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IBase} from "./IBase.sol";

/// @dev Registry interface for Registry facet
interface IRegistry is IBase {
    function register(string memory username) external;

    function isRegistered(address user) external view returns (bool);

    function isUsernameUsed(string memory username) external view returns (bool);
}
