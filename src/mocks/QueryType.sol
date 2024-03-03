// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

/**
    @author Futaba Labs 
*/

contract QueryType {
    struct QueryRequest {
        uint256 dstChainId;
        address to;
        // block height
        uint256 height;
        // storage slot
        bytes32 slot;
    }

    struct QueryResponse {
        // Unique id to access query state
        bytes32 queryId;
        // Encoded data for verification
        bytes proof;
    }
}