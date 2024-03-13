// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {LibAppStorage, AppStorage, PoolStorage} from "../libraries/LibAppStorage.sol";
import {Errors, Events} from "../libraries/Common.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// TODO : remove msg.sender from all functions here, pass as function argument
library LibLending {
    using Math for uint256;

    function _deposit(uint256 poolId, uint256 amount, address token) internal returns (bool) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        PoolStorage storage ps = s.pools[poolId];
        if (s.supportedAssets[token] == false) {
            revert Errors.TokenNotSupported(token);
        }
        // get shares
        uint256 shares = _convertToShares(poolId, amount, token, Math.Rounding.Floor);
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        s.balances[poolId][token] += amount;
        ps.balances[msg.sender][token] += shares;
        ps.totalShares += shares;

        emit Events.PoolDeposit(poolId, msg.sender, token, amount);
    }

    function _withdraw(uint256 poolId, uint256 shares, address token) internal returns (bool) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        PoolStorage storage ps = s.pools[poolId];
        uint256 requestedAssets = _convertToAssets(poolId, shares, token, Math.Rounding.Ceil);

        uint256 userAvailableAssets =
            convertToAvailableAssets(poolId, ps.balances[msg.sender][token], token, Math.Rounding.Ceil);

        if (s.supportedAssets[token] == false) {
            revert Errors.TokenNotSupported(token);
        }
        if (userAvailableAssets < requestedAssets) {
            revert Errors.InsuficientBalance(shares);
        }

        IERC20(token).transfer(msg.sender, requestedAssets);
        s.balances[poolId][token] -= requestedAssets;
        ps.balances[msg.sender][token] -= shares;
        ps.totalShares -= shares;

        emit Events.PoolWithdraw(poolId, msg.sender, token, requestedAssets);
    }

    function _totalShares(uint256 poolId) internal view returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        PoolStorage storage ps = s.pools[poolId];
        return ps.totalShares;
    }

    function _convertToShares(uint256 poolId, uint256 amount, address token, Math.Rounding rounding)
        internal
        view
        returns (uint256)
    {
        AppStorage storage s = LibAppStorage.diamondStorage();
        PoolStorage storage ps = s.pools[poolId];
        uint256 underlyingBalance = s.balances[poolId][token];
        return amount.mulDiv(ps.totalShares + 10 ** 18, underlyingBalance + 1, rounding);
    }

    function convertToAvailableAssets(uint256 poolId, uint256 shares, address token, Math.Rounding rounding)
        internal
        view
        returns (uint256)
    {
        AppStorage storage s = LibAppStorage.diamondStorage();
        PoolStorage storage ps = s.pools[poolId];
        uint256 availableUnderlyingBalance = s.balances[poolId][token] - s.usedBalances[poolId][token];
        return shares.mulDiv(availableUnderlyingBalance + 1, ps.totalShares + 10 ** _decimalOffset(), rounding);
    }

    function _convertToAssets(uint256 poolId, uint256 shares, address token, Math.Rounding rounding)
        internal
        view
        returns (uint256)
    {
        AppStorage storage s = LibAppStorage.diamondStorage();
        PoolStorage storage ps = s.pools[poolId];
        uint256 underlyingBalance = s.balances[poolId][token];
        return shares.mulDiv(underlyingBalance + 1, ps.totalShares + 10 ** _decimalOffset(), rounding);
    }

    // TODO: check if this is the correct decimal offset
    function _decimalOffset() internal pure returns (uint8) {
        return 18;
    }
}
