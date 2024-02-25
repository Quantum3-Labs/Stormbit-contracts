// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/**
 * @title StormBitVault
 * @author Q3Labs
 * @custom:security-contact security@Q3Labs
 */
interface IStormBitVault {
    /**
     * @dev Thrown when withdrawals are disabled and a withdrawal attempt is made
     */
    error WithdrawalsAreDisabled();
}
