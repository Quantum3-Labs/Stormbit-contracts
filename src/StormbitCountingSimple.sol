// SPDX-License-Identifier : MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./mocks/QueryType.sol";

/**
 * @title CrossChain Voting using Futaba
 * @dev Provides counting and vote system for a cross-chain voting system using Futaba mechanism for cross-chain data acquisition
 */


abstract contract StormBitCountingSimple is Governor, Ownable {
    struct FutabaDA {
        QueryType.QueryRequest request;
        uint256 proposalId;
    }
}
