//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IBase} from "./IBase.sol";

struct PoolInitData {
    string name;
    uint256 creditScore;
    uint256 maxAmountOfStakers;
    uint256 votingQuorum;
    uint256 maxPoolUsage;
    uint256 votingPowerCoolDown;
    uint256 initAmount;
    address initToken;
}

/// @dev core interface for Stormbit protocol
interface ICore is IBase {
    function createPool(PoolInitData memory poolInitData) external returns (uint256);
}
