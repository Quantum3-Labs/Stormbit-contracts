// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

interface IStormBitLending {
    struct InitParams {
        string name;
        uint256 creditScore;
        uint256 maxAmountOfStakers;
        uint256 votingQuorum; //  denominated in 100
        uint256 maxPoolUsage;
        uint256 votingPowerCoolDown;
        uint256 initAmount;
        address initToken; //  initToken has to be in supportedAssets
        address[] supportedAssets;
        address[] supportedAgreements;
    }

    struct LoanRequestParams {
        uint256 amount;
        address token;
        address agreement;
        bytes agreementCalldata;
    }

    function initializeLending(
        InitParams memory params,
        address _firstOwner,
        address stormBitLendingVotes
    ) external;

    function stake(address token, uint256 amount) external;

    function requestLoan(
        LoanRequestParams memory params
    ) external returns (uint256);

    function executeLoan(
        address token,
        address to,
        uint256 amount,
        address strategy,
        bytes calldata agreementCalldata
    ) external;
}
