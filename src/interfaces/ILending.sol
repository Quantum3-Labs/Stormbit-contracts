//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IBase} from "./IBase.sol";

struct LoanRequestParams {
    uint256 amount;
    address token;
    address agreement;
    bytes agreementCalldata;
}

/// @dev core interface for Stormbit protocol
interface ILending is IBase {
    function requestLoan(uint256 poolId, LoanRequestParams memory loanParams) external returns (uint256);

    function deposit(uint256 poolId, uint256 amount, address token) external returns (bool);

    function withdraw(uint256 poolId, uint256 amount, address token) external returns (bool);

    function castVote(uint256 poolId, uint256 loanId, bool vote) external returns (bool);

    function initAgreement(
        uint256 poolId,
        uint256 loanId,
        uint256 amount,
        address token,
        address agreement,
        bytes memory agreementCalldata
    ) external returns (bool);

    // TODO : add getter functions
}
