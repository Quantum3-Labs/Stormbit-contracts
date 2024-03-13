// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {LibDiamond} from "./libraries/LibDiamond.sol";

/// @title Custom Diamond Proxy Contract (EIP-2535)
/// @author Quantum3 Labs <security@quantum3labs.com>
/// @notice  This Diamond doesnt allow for adding new facets after deployment

/// @dev Error message for function selector not found
error FunctionNotFound(bytes4 _functionSelector);

contract DiamondProxy {
    constructor(LibDiamond.FacetCut[] memory _diamondCut, address _diamontInit, bytes memory _initCalldata) {
        LibDiamond.diamondCut(_diamondCut, _diamontInit, _initCalldata);
    }

    fallback() external payable {
        LibDiamond.DiamondStorage storage ds;
        bytes32 position = LibDiamond.DIAMOND_STORAGE_POSITION;
        // get diamond storage
        assembly {
            ds.slot := position
        }
        // get facet from function selector
        address facet = ds.selectorToFacetAndPosition[msg.sig].facetAddress;
        if (facet == address(0)) {
            revert FunctionNotFound(msg.sig);
        }
        // Execute external function from facet using delegatecall and return any value.
        assembly {
            // copy function selector and any arguments
            calldatacopy(0, 0, calldatasize())
            // execute function call using the facet
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            // get any return value
            returndatacopy(0, 0, returndatasize())
            // return any return value or error back to the caller
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}
