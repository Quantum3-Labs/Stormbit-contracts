//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IBase {
    /// @dev returns the contract name ( used mainly in facets )
    function name() external view returns (string memory);
}
