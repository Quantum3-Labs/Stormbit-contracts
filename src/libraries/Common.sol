// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {LibAppStorage, AppStorage, PoolStorage} from "../libraries/LibAppStorage.sol";
import {PoolInitData} from "../interfaces/ICore.sol";

library Errors {
    error CallerIsNotGovernor();
    error OwnerCannotBeZeroAddress();
    error AlreadyInitialized();
    error UserAlreadyRegistered();
    error InvalidUsername();
    error TokenNotSupported(address token);
    error AgreementNotSupported(address agreement);
    error InsuficientBalance(uint256 amount);
    error InvalidLoan();
}

library Events {
    event UserRegistered(address user, string username);
    event NewGovernor(address newGovernor);
    event AddSupportedToken(address token);
    event RemoveSupportedToken(address token);
    event AddSuppportedAgreement(address agreement);
    event RemoveSupportedAgreement(address agreement);
    event PoolCreated(uint256 indexed poolId, address indexed creator, PoolInitData poolInitData);
    event PoolDeposit(uint256 indexed poolId, address indexed user, address token, uint256 amount);
    event PoolWithdraw(uint256 indexed poolId, address indexed user, address token, uint256 amount);
}
