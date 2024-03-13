//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ILending, LoanRequestParams} from "../interfaces/ILending.sol";
import {Errors} from "../libraries/Common.sol";
import {LibAppStorage, AppStorage, PoolStorage, Loan} from "../libraries/LibAppStorage.sol";
import {LibLending} from "../libraries/LibLending.sol";
import {Base} from "./Base.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LendingFacet is ILending, Base {
    string public constant override name = "Lending";

    function requestLoan(uint256 poolId, LoanRequestParams memory loanParams) external returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        PoolStorage storage ps = s.pools[poolId];

        //TODO : perform a safer hashing
        uint256 loanHash = uint256(keccak256(abi.encode(msg.sender, poolId, loanParams)));

        if (ps.loans[loanHash].loanId != 0) {
            revert Errors.InvalidLoan();
        }
        Loan storage psl = ps.loans[loanHash];
        psl.loanId = loanHash;
        psl.support = 0;

        return loanHash;
    }

    function deposit(uint256 poolId, uint256 amount, address token)
        external
        override
        onlyRegisteredUser
        returns (bool)
    {
        LibLending._deposit(poolId, amount, token);
    }

    function withdraw(uint256 poolId, uint256 shares, address token)
        external
        override
        onlyRegisteredUser
        returns (bool)
    {
        LibLending._withdraw(poolId, shares, token);
    }

    function castVote(uint256 poolId, uint256 loanId, uint256 power)
        external
        override
        onlyRegisteredUser
        returns (bool)
    {
        AppStorage storage s = LibAppStorage.diamondStorage();
        PoolStorage storage ps = s.pools[poolId];
        uint256 _loanId = ps.loans[loanId].loanId;
        if (_loanId == 0) {
            revert Errors.InvalidLoan();
        }

        ps.loans[_loanId].support += power;
    }

    function getTotalShares(uint256 poolId) external view returns (uint256) {
        return LibLending._totalShares(poolId);
    }

    function initAgreement(
        uint256 poolId,
        uint256 loanId,
        uint256 amount,
        address token,
        address agreement,
        bytes memory agreementCalldata
    ) external returns (bool) {}
}
