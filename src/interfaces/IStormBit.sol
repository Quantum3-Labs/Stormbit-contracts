// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "./IStormBitLending.sol";

interface IStormBit {
    event PoolCreated(address indexed pool, address creator);

    function createPool(IStormBitLending.InitParams memory params) external;
}
