//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IBase} from "./IBase.sol";

/// @dev interface for Agreement facet

interface IAgreement is IBase {
    // withdraws funds through the agreement
    function withdraw(uint256 poolId, uint256 loanId) external returns (bool);

    // performs subsequent repayments of a loan in a pool
    function repay(uint256 poolId, uint256 loanId) external returns (bool);

    // TODO : add getter functions
}
