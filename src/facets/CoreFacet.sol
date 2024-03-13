//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ICore, PoolInitData} from "../interfaces/ICore.sol";
import {Events} from "../libraries/Common.sol";
import {LibAppStorage, AppStorage, PoolStorage} from "../libraries/LibAppStorage.sol";
import {LibLending} from "../libraries/LibLending.sol";
import {Base} from "./Base.sol";

contract CoreFacet is ICore, Base {
    string public constant override name = "Core";

    function createPool(PoolInitData memory poolInitData) public override onlyRegisteredUser returns (uint256 poolId) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        s.poolCount++;
        poolId = s.poolCount;

        // perform some checks on pool init data

        // create and setup the pool
        PoolStorage storage ps = s.pools[poolId];
        ps.name = poolInitData.name;
        ps.owner = msg.sender;
        ps.creditScore = poolInitData.creditScore;
        ps.maxAmountOfStakers = poolInitData.maxAmountOfStakers;
        ps.votingQuorum = poolInitData.votingQuorum;
        ps.maxPoolUsage = poolInitData.maxPoolUsage;
        ps.votingPowerCoolDown = poolInitData.votingPowerCoolDown;

        emit Events.PoolCreated(poolId, msg.sender, poolInitData);

        LibLending._deposit(poolId, poolInitData.initAmount, poolInitData.initToken);
    }
}
