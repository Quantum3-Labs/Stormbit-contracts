// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {console} from "forge-std/Script.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {SetupTest} from "../Setup.t.sol";
import {BaseVault} from "../../src/vaults/BaseVault.sol";
import {IHooks} from "../../src/interfaces/hooks/IHooks.sol";
import {IAssetManager} from "../../src/interfaces/managers/asset/IAssetManager.sol";
import {ILoanManager} from "../../src/interfaces/managers/loan/ILoanManager.sol";
import {ILendingManager} from "../../src/interfaces/managers/lending/ILendingManager.sol";

contract IntegrationTest is SetupTest {
    // todo: think some better name
    /// @dev this is the integrtion test case for
    /// 1 depositors, 1 term, 1 lender, 1 borrower
    /// borrower borrow 1000 token1
    /// lender create a term with 10% commission
    /// depositor1 deposit 1000 token1 and delegate 1000 to term
    /// lender allocate term with 10% commission to loan
    /// lender allocate 1000 shares on term to loan
    /// borrower execute loan
    /// borrower repay loan
    function testIntegration1() public {
        uint256 borrowAssets = 1000 * (10 ** token1.decimals());
        uint256 loanId = _requestLoan(borrower1, address(token1), borrowAssets, 1 days);
        // 5% interest rate
        ILoanManager.Loan memory loan = loanManager.getLoan(loanId);
        uint256 expectedRepayAssets = borrowAssets + (borrowAssets * 500) / BASIS_POINTS;
        assert(loan.borrower == borrower1);
        assert(loan.token == address(token1));
        assert(loan.repayAssets == expectedRepayAssets);

        // lender take 10% commission on profit
        uint256 termId = _createTerm(lender1, 1000, address(0));

        IERC4626 vaultTokenInterface = IERC4626(assetManager.getVaultToken(address(token1)));
        _depositAndDelegate(depositor1, 1000, 1000, address(token1), termId);
        // check balance of depositor1 and lending manager
        uint256 depositor1SharesBalanceReal = vaultTokenInterface.balanceOf(depositor1);
        uint256 depositor1SharesBalanceBeforeDeposit = 1000 * (10 ** vaultTokenInterface.decimals());
        uint256 depositedShares = 1000 * (10 ** vaultTokenInterface.decimals());

        uint256 lendingManagerSharesBalance = vaultTokenInterface.balanceOf(address(lendingManager));

        assert(lendingManagerSharesBalance == depositedShares);
        assert(depositor1SharesBalanceReal == depositor1SharesBalanceBeforeDeposit - depositedShares);

        // check user total delegated shares on lending manager
        uint256 depositor1TotalDelegatedShares = lendingManager.getUserTotalDelegatedShares(depositor1, address(token1));
        assert(depositor1TotalDelegatedShares == depositedShares);
        // check delegated shares on term
        (, uint256 termDelegatedShares,) = lendingManager.getLendingTermBalances(termId, address(token1));
        assert(termDelegatedShares == depositedShares);
        // check term total and disposable shares
        (uint256 termTotalShares,,) = lendingManager.getLendingTermBalances(termId, address(token1));
        assert(termTotalShares == depositedShares);

        _allocateTermAndFundOnLoan(lender1, address(token1), loanId, termId, 1000);

        // check term allocated counter
        uint256 termAllocatedCounter = loanManager.getTermLoanAllocatedCounter(termId);
        assert(termAllocatedCounter == 1);

        // check if term allocated to loan
        bool termAllocatedToLoan = loanManager.getLoanTermAllocated(loanId, termId);
        assert(termAllocatedToLoan == true);

        // check freezed shares on term
        uint256 termFreezedShares = lendingManager.getTermFreezedShares(termId, address(token1));
        uint256 expectedTermFreezedShares = 1000 * (10 ** vaultTokenInterface.decimals());
        assert(termFreezedShares == expectedTermFreezedShares);

        // check loan allocated shares
        // get loan
        loan = loanManager.getLoan(loanId);
        uint256 expectedLoanAllocatedShares = 1000 * (10 ** vaultTokenInterface.decimals());
        assert(loan.sharesAllocated == expectedLoanAllocatedShares);

        // borrower1 asset balance beofre loan
        uint256 borrower1BalanceBeforeLoan = token1.balanceOf(borrower1);
        // borrower execute loan
        vm.startPrank(borrower1);
        // pass time
        skip(1 days);
        loanManager.executeLoan(loanId);
        vm.stopPrank();

        // check loan status
        loan = loanManager.getLoan(loanId);
        assert(loan.status == ILoanManager.LoanStatus.Active);

        // check borrower asset balance
        uint256 borrower1Balance = token1.balanceOf(borrower1);
        assert(borrower1BalanceBeforeLoan == 0);
        assert(borrower1Balance == borrowAssets);

        // check lending manager shares balance
        uint256 lendingManagerBalance = vaultTokenInterface.balanceOf(address(lendingManager));
        assert(lendingManagerBalance == 0);

        // repay loan
        // mint 5% interest to borrower to pay extra
        uint256 interest = (borrowAssets * 500) / BASIS_POINTS;
        token1.mint(borrower1, interest);
        // borrower repay loan
        vm.startPrank(borrower1);
        token1.approve(address(assetManager), borrowAssets + interest);
        loanManager.repay(loanId);
        vm.stopPrank();

        // check loan status
        loan = loanManager.getLoan(loanId);
        assert(loan.status == ILoanManager.LoanStatus.Repaid);

        // check borrower balance
        borrower1Balance = token1.balanceOf(borrower1);
        assert(borrower1Balance == 0);

        // check lending manager shares balance
        lendingManagerBalance = vaultTokenInterface.balanceOf(address(lendingManager));
        // convert repay amount to shares
        uint256 expectedLendingManagerShares = assetManager.convertToShares(address(token1), borrowAssets + interest);
        assert(lendingManagerBalance == expectedLendingManagerShares);

        // term owner claim loan profit
        vm.startPrank(lender1);
        loanManager.claimAllocation(termId, loanId);
        vm.stopPrank();

        // check term owner balance
        // calculate repay amount in shares
        uint256 repayAssetsInShares = assetManager.convertToShares(address(token1), loan.repayAssets);
        // calculate shares required
        uint256 sharesRequired = assetManager.convertToShares(address(token1), loan.assetsRequired);
        uint256 profitShares = repayAssetsInShares - sharesRequired;
        uint256 lender1Balance = vaultTokenInterface.balanceOf(lender1);
        // 10% commission on profit
        uint256 expectedLender1Balance = (profitShares * 1000) / BASIS_POINTS;
        assert(lender1Balance == expectedLender1Balance);

        // calculate remaining profit shares
        uint256 remainingProfitShares = profitShares - expectedLender1Balance;
        // check term profit
        (uint256 total,, uint256 assets) = lendingManager.getLendingTermBalances(termId, address(token1));
        uint256 termProfit = total - assets;
        assert(termProfit == remainingProfitShares);

        // check disposable amount is equal to initial deposit amount

        (, uint256 disposableAmount,) = lendingManager.getLendingTermBalances(termId, address(token1));
        uint256 expectedDisposableAmount = 1000 * (10 ** vaultTokenInterface.decimals());
        assert(disposableAmount == expectedDisposableAmount);

        // check term freezed shares
        termFreezedShares = lendingManager.getTermFreezedShares(termId, address(token1));
        assert(termFreezedShares == 0);

        // depositor withdraw from term
        uint256 depositor1BalanceBeforeWithdraw = vaultTokenInterface.balanceOf(depositor1);
        vm.startPrank(depositor1);
        lendingManager.withdrawFromTerm(termId, address(token1), depositedShares);
        vm.stopPrank();

        // check term total and disposable shares
        (termTotalShares,,) = lendingManager.getLendingTermBalances(termId, address(token1));
        assert(termTotalShares == 0);
        (, uint256 termDisposableShares,) = lendingManager.getLendingTermBalances(termId, address(token1));
        assert(termDisposableShares == 0);

        // check depositor1 total delegated shares and total delegated shares on term
        depositor1TotalDelegatedShares = lendingManager.getUserTotalDelegatedShares(depositor1, address(token1));
        assert(depositor1TotalDelegatedShares == 0);

        // check user shares balance, should be equal to initial balance + profit
        uint256 depositor1SharesBalance = vaultTokenInterface.balanceOf(depositor1);
        uint256 expectedDepositor1SharesBalance =
            depositor1BalanceBeforeWithdraw + depositedShares + remainingProfitShares;
        assert(depositor1SharesBalance == expectedDepositor1SharesBalance);
    }

    /// @dev this is the integrtion test case for
    /// 2 depositors, 1 term, 1 lender, 1 borrower
    /// borrower borrow 1000 token1
    /// lender create a term with 10% commission
    /// depositor1 deposit 500 token1 and delegate 500 to term
    /// depositor2 deposit 500 token1 and delegate 500 to term
    /// lender allocate term with 10% commission to loan
    /// lender allocate 1000 shares on term to loan
    /// borrower execute loan
    /// borrower repay loan
    function testIntegration2() public {
        uint256 borrowAssets = 1000 * (10 ** token1.decimals());
        uint256 loanId = _requestLoan(borrower1, address(token1), borrowAssets, 1 days);
        // 5% interest rate
        ILoanManager.Loan memory loan = loanManager.getLoan(loanId);
        uint256 expectedRepayAssets = borrowAssets + (borrowAssets * 500) / BASIS_POINTS;
        assert(loan.borrower == borrower1);
        assert(loan.token == address(token1));
        assert(loan.repayAssets == expectedRepayAssets);

        // lender take 10% commission on profit
        uint256 termId = _createTerm(lender1, 1000, address(0));

        IERC4626 vaultTokenInterface = IERC4626(assetManager.getVaultToken(address(token1)));
        _depositAndDelegate(depositor1, 500, 500, address(token1), termId);
        _depositAndDelegate(depositor2, 500, 500, address(token1), termId);

        // check balance of depositor1 and lending manager
        uint256 depositor1SharesBalanceReal = vaultTokenInterface.balanceOf(depositor1);
        uint256 depositor2SharesBalanceReal = vaultTokenInterface.balanceOf(depositor2);
        uint256 depositor1SharesBalanceBeforeDeposit = 500 * (10 ** vaultTokenInterface.decimals());
        uint256 depositedShares = 500 * (10 ** vaultTokenInterface.decimals());
        uint256 expectedTotalDepositedShares = depositedShares + depositedShares;
        uint256 lendingManagerSharesBalance = vaultTokenInterface.balanceOf(address(lendingManager));

        assert(lendingManagerSharesBalance == expectedTotalDepositedShares);
        assert(depositor1SharesBalanceReal == depositor1SharesBalanceBeforeDeposit - depositedShares);
        assert(depositor2SharesBalanceReal == depositor1SharesBalanceBeforeDeposit - depositedShares);

        // check user total delegated shares on lending manager
        uint256 depositor1TotalDelegatedShares = lendingManager.getUserTotalDelegatedShares(depositor1, address(token1));
        uint256 depositor2TotalDelegatedShares = lendingManager.getUserTotalDelegatedShares(depositor2, address(token1));
        assert(depositor1TotalDelegatedShares == depositedShares);
        assert(depositor2TotalDelegatedShares == depositedShares);

        // check delegated shares on term
        (, uint256 termDelegatedShares,) = lendingManager.getLendingTermBalances(termId, address(token1));
        assert(termDelegatedShares == expectedTotalDepositedShares);
        // check term total and disposable shares
        (uint256 termTotalShares,,) = lendingManager.getLendingTermBalances(termId, address(token1));
        assert(termTotalShares == expectedTotalDepositedShares);

        _allocateTermAndFundOnLoan(lender1, address(token1), loanId, termId, 1000);

        // check term allocated counter
        uint256 termAllocatedCounter = loanManager.getTermLoanAllocatedCounter(termId);
        assert(termAllocatedCounter == 1);

        // check if term allocated to loan
        bool termAllocatedToLoan = loanManager.getLoanTermAllocated(loanId, termId);
        assert(termAllocatedToLoan == true);

        // check freezed shares on term
        uint256 termFreezedShares = lendingManager.getTermFreezedShares(termId, address(token1));
        uint256 expectedTermFreezedShares = 1000 * (10 ** vaultTokenInterface.decimals());
        assert(termFreezedShares == expectedTermFreezedShares);

        // check loan allocated shares
        // get loan
        loan = loanManager.getLoan(loanId);
        uint256 expectedLoanAllocatedShares = 1000 * (10 ** vaultTokenInterface.decimals());
        assert(loan.sharesAllocated == expectedLoanAllocatedShares);

        // borrower1 asset balance beofre loan
        uint256 borrowerBalanceBeforeLoan = token1.balanceOf(borrower1);
        // borrower execute loan
        vm.startPrank(borrower1);
        // pass time
        skip(1 days);
        loanManager.executeLoan(loanId);
        vm.stopPrank();

        // check loan status
        loan = loanManager.getLoan(loanId);
        assert(loan.status == ILoanManager.LoanStatus.Active);

        // check borrower asset balance
        uint256 borrower1Balance = token1.balanceOf(borrower1);
        assert(borrowerBalanceBeforeLoan == 0);
        assert(borrower1Balance == borrowAssets);

        // check lending manager shares balance
        uint256 lendingManagerBalance = vaultTokenInterface.balanceOf(address(lendingManager));
        assert(lendingManagerBalance == 0);

        // repay loan
        // mint 5% interest to borrower to pay extra
        uint256 interest = (borrowAssets * 500) / BASIS_POINTS;
        token1.mint(borrower1, interest);
        // borrower repay loan
        vm.startPrank(borrower1);
        token1.approve(address(assetManager), borrowAssets + interest);
        loanManager.repay(loanId);
        vm.stopPrank();

        // check loan status
        loan = loanManager.getLoan(loanId);
        assert(loan.status == ILoanManager.LoanStatus.Repaid);

        // check borrower balance
        borrower1Balance = token1.balanceOf(borrower1);
        assert(borrower1Balance == 0);

        // check lending manager shares balance
        lendingManagerBalance = vaultTokenInterface.balanceOf(address(lendingManager));
        // convert repay amount to shares
        uint256 expectedLendingManagerShares = assetManager.convertToShares(address(token1), borrowAssets + interest);
        assert(lendingManagerBalance == expectedLendingManagerShares);

        // term owner claim loan profit
        vm.startPrank(lender1);
        loanManager.claimAllocation(termId, loanId);
        vm.stopPrank();

        // check term owner balance
        // calculate repay amount in shares
        uint256 repayAssetsInShares = assetManager.convertToShares(address(token1), loan.repayAssets);
        // calculate shares required
        uint256 sharesRequired = assetManager.convertToShares(address(token1), loan.assetsRequired);
        uint256 profitShares = repayAssetsInShares - sharesRequired;
        uint256 lender1Balance = vaultTokenInterface.balanceOf(lender1);
        // 10% commission on profit
        uint256 expectedLender1Balance = (profitShares * 1000) / BASIS_POINTS;
        assert(lender1Balance == expectedLender1Balance);

        // calculate remaining profit shares
        uint256 remainingProfitShares = profitShares - expectedLender1Balance;
        // check term profit
        (uint256 total,, uint256 assets) = lendingManager.getLendingTermBalances(termId, address(token1));
        uint256 termProfit = total - assets;
        assert(termProfit == remainingProfitShares);

        // check disposable amount is equal to initial deposit amount
        (, uint256 disposableAmount,) = lendingManager.getLendingTermBalances(termId, address(token1));
        uint256 expectedDisposableAmount = 1000 * (10 ** vaultTokenInterface.decimals());
        assert(disposableAmount == expectedDisposableAmount);

        // check term freezed shares
        termFreezedShares = lendingManager.getTermFreezedShares(termId, address(token1));
        assert(termFreezedShares == 0);

        // depositor withdraw from term
        uint256 depositor1BalanceBeforeWithdraw = vaultTokenInterface.balanceOf(depositor1);
        vm.startPrank(depositor1);
        lendingManager.withdrawFromTerm(termId, address(token1), depositedShares);
        vm.stopPrank();
        vm.startPrank(depositor2);
        lendingManager.withdrawFromTerm(termId, address(token1), depositedShares);
        vm.stopPrank();

        // check term total and disposable shares
        (termTotalShares,,) = lendingManager.getLendingTermBalances(termId, address(token1));

        assert(termTotalShares == 0);
        (, uint256 termDisposableShares,) = lendingManager.getLendingTermBalances(termId, address(token1));
        assert(termDisposableShares == 0);

        // check depositor1 total delegated shares and total delegated shares on term
        depositor1TotalDelegatedShares = lendingManager.getUserTotalDelegatedShares(depositor1, address(token1));
        depositor2TotalDelegatedShares = lendingManager.getUserTotalDelegatedShares(depositor2, address(token1));
        assert(depositor1TotalDelegatedShares == 0);
        assert(depositor2TotalDelegatedShares == 0);

        // check user shares balance, should be equal to initial balance + profit
        uint256 depositor1SharesBalance = vaultTokenInterface.balanceOf(depositor1);
        uint256 depositor2SharesBalance = vaultTokenInterface.balanceOf(depositor2);
        uint256 expectedDepositor1SharesBalance =
            depositor1BalanceBeforeWithdraw + depositedShares + (remainingProfitShares / 2);
        assert(depositor1SharesBalance == expectedDepositor1SharesBalance);
        assert(depositor2SharesBalance == expectedDepositor1SharesBalance);
    }

    /// @dev this is the integrtion test case for
    /// 2 depositors, 2 term, 1 lender, 1 borrower
    /// borrower borrow 1000 token1
    /// lender create a term1 with 10% commission
    /// lender create a term2 with 5% commission
    /// depositor1 deposit 500 token1 and delegate 500 to term1
    /// depositor1 deposit 500 token1 and delegate 500 to term2
    /// depositor2 deposit 500 token1 and delegate 500 to term2
    /// lender allocate term with 10% commission to loan
    /// lender allocate term with 5% commission to loan
    /// lender allocate 500 shares on term1 to loan
    /// lender allocate 500 shares on term2 to loan
    /// borrower execute loan
    /// borrower repay loan

    /// depositor1 should get profit shares from both term1 and term2
    function testIntegration3() public {
        uint256 borrowAssets = 1000 * (10 ** token1.decimals());
        uint256 loanId = _requestLoan(borrower1, address(token1), borrowAssets, 1 days);
        // 5% interest rate
        ILoanManager.Loan memory loan = loanManager.getLoan(loanId);
        uint256 expectedRepayAssets = borrowAssets + (borrowAssets * 500) / BASIS_POINTS;
        assert(loan.borrower == borrower1);
        assert(loan.token == address(token1));
        assert(loan.repayAssets == expectedRepayAssets);

        // lender take 10% commission on profit
        uint256 termId1 = _createTerm(lender1, 1000, address(0));
        uint256 termId2 = _createTerm(lender1, 500, address(1));

        IERC4626 vaultTokenInterface = IERC4626(assetManager.getVaultToken(address(token1)));
        _depositAndDelegate(depositor1, 500, 500, address(token1), termId1);
        _depositAndDelegate(depositor1, 500, 500, address(token1), termId2);
        _depositAndDelegate(depositor2, 500, 500, address(token1), termId2);
        // 500 shares on term1, 1000 shares on term2

        // check balance of depositor1 and lending manager
        uint256 depositor1SharesBalanceReal = vaultTokenInterface.balanceOf(depositor1);
        uint256 depositor2SharesBalanceReal = vaultTokenInterface.balanceOf(depositor2);

        uint256 depositedShares = 500 * (10 ** vaultTokenInterface.decimals());
        uint256 expectedTotalDepositedShares = depositedShares + depositedShares + depositedShares;
        uint256 lendingManagerSharesBalance = vaultTokenInterface.balanceOf(address(lendingManager));

        assert(lendingManagerSharesBalance == expectedTotalDepositedShares);
        assert(depositor1SharesBalanceReal == 0);
        assert(depositor2SharesBalanceReal == 0);

        // check user total delegated shares on lending manager
        uint256 depositor1TotalDelegatedShares = lendingManager.getUserTotalDelegatedShares(depositor1, address(token1));
        uint256 depositor2TotalDelegatedShares = lendingManager.getUserTotalDelegatedShares(depositor2, address(token1));
        uint256 expectedDepositor1TotalDelegatedShares = depositedShares + depositedShares;
        assert(depositor1TotalDelegatedShares == expectedDepositor1TotalDelegatedShares);
        assert(depositor2TotalDelegatedShares == depositedShares);

        // check delegated shares on term
        (, uint256 term1DelegatedShares,) = lendingManager.getLendingTermBalances(termId1, address(token1));
        uint256 expectedTerm1DelegatedShares = depositedShares;
        assert(term1DelegatedShares == expectedTerm1DelegatedShares);

        (, uint256 term2DelegatedShares,) = lendingManager.getLendingTermBalances(termId2, address(token1));
        uint256 expectedTerm2DelegatedShares = depositedShares + depositedShares;
        assert(term2DelegatedShares == expectedTerm2DelegatedShares);

        _allocateTermAndFundOnLoan(lender1, address(token1), loanId, termId1, 500);
        _allocateTermAndFundOnLoan(lender1, address(token1), loanId, termId2, 500);

        // check term allocated counter
        uint256 term1AllocatedCounter = loanManager.getTermLoanAllocatedCounter(termId1);
        assert(term1AllocatedCounter == 1);
        uint256 term2AllocatedCounter = loanManager.getTermLoanAllocatedCounter(termId2);
        assert(term2AllocatedCounter == 1);

        // check if term1 allocated to loan
        bool term1AllocatedToLoan = loanManager.getLoanTermAllocated(loanId, termId1);
        assert(term1AllocatedToLoan == true);

        // check if term2 allocated to loan
        bool term2AllocatedToLoan = loanManager.getLoanTermAllocated(loanId, termId2);
        assert(term2AllocatedToLoan == true);

        // check freezed shares on term1
        uint256 term1FreezedShares = lendingManager.getTermFreezedShares(termId1, address(token1));
        uint256 term2FreezedShares = lendingManager.getTermFreezedShares(termId1, address(token1));
        uint256 expectedTermFreezedShares = 500 * (10 ** vaultTokenInterface.decimals());
        assert(term1FreezedShares == expectedTermFreezedShares);
        assert(term2FreezedShares == expectedTermFreezedShares);

        loan = loanManager.getLoan(loanId);
        uint256 expectedLoanAllocatedShares = 1000 * (10 ** vaultTokenInterface.decimals());
        assert(loan.sharesAllocated == expectedLoanAllocatedShares);

        // try to withdraw from term2 as depositor 1, since depositor1 deposited 500 in term2, term2 has 1000 shares, allocated 500 shares, should freezed
        // 250 on depositor1, 250 on depositor2
        // so depositor1 should beable to withdraw 250, but not more than that
        // uint256 depositor1BalanceBeforTryWithdraw = vaultTokenInterface
        //     .balanceOf(depositor1);
        // vm.startPrank(depositor1);
        // lendingManager.withdrawFromTerm(
        //     termId2,
        //     address(token1),
        //     260 * (10 ** vaultTokenInterface.decimals()) // ! 260 should fail, 250 should pass
        // );
        // vm.stopPrank();

        // borrower1 asset balance beofre loan
        uint256 borrowerBalanceBeforeLoan = token1.balanceOf(borrower1);
        // borrower execute loan
        vm.startPrank(borrower1);
        // pass time
        skip(1 days);
        loanManager.executeLoan(loanId);
        vm.stopPrank();

        // check loan status
        loan = loanManager.getLoan(loanId);
        assert(loan.status == ILoanManager.LoanStatus.Active);

        // check borrower asset balance
        uint256 borrower1Balance = token1.balanceOf(borrower1);
        assert(borrowerBalanceBeforeLoan == 0);
        assert(borrower1Balance == borrowAssets);

        // check lending manager shares balance
        uint256 lendingManagerBalance = vaultTokenInterface.balanceOf(address(lendingManager));
        uint256 expectedLendingManagerShares = 500 * (10 ** vaultTokenInterface.decimals());
        assert(lendingManagerBalance == expectedLendingManagerShares);

        // repay loan
        // mint 5% interest to borrower to pay extra
        uint256 interest = (borrowAssets * 500) / BASIS_POINTS;
        token1.mint(borrower1, interest);
        // borrower repay loan
        vm.startPrank(borrower1);
        token1.approve(address(assetManager), borrowAssets + interest);
        loanManager.repay(loanId);
        vm.stopPrank();

        // check loan status
        loan = loanManager.getLoan(loanId);
        assert(loan.status == ILoanManager.LoanStatus.Repaid);

        // check borrower balance
        borrower1Balance = token1.balanceOf(borrower1);
        assert(borrower1Balance == 0);

        // check lending manager shares balance
        lendingManagerBalance = vaultTokenInterface.balanceOf(address(lendingManager));
        // convert repay amount to shares
        expectedLendingManagerShares = assetManager.convertToShares(address(token1), borrowAssets + interest)
            + 500 * (10 ** vaultTokenInterface.decimals());
        assert(lendingManagerBalance == expectedLendingManagerShares);

        // term owner claim loan profit for term1
        vm.startPrank(lender1);
        loanManager.claimAllocation(termId1, loanId);
        vm.stopPrank();

        // check term owner balance
        // calculate repay amount in shares
        uint256 repayAssetsInShares = assetManager.convertToShares(address(token1), loan.repayAssets);
        // calculate shares required
        uint256 sharesRequired = assetManager.convertToShares(address(token1), loan.assetsRequired);
        uint256 profitShares = repayAssetsInShares - sharesRequired;
        // get term weight on loan
        uint256 term1Weight = (
            loanManager.getTermAllocatedSharesOnLoan(loanId, termId1, address(token1)) * BASIS_POINTS
        ) / loan.sharesAllocated;
        // calculate profit for term1
        uint256 term1Profit = (profitShares * term1Weight) / BASIS_POINTS;
        // from term1 profit calculate lender profit
        uint256 lender1ProfitTerm1 = (term1Profit * 1000) / BASIS_POINTS;
        uint256 lender1Balance = vaultTokenInterface.balanceOf(lender1);
        assert(lender1Balance == lender1ProfitTerm1);
        // check term1 profit
        uint256 term1ProfitBalance = term1Profit - lender1ProfitTerm1;
        (uint256 total,, uint256 assets) = lendingManager.getLendingTermBalances(termId1, address(token1));
        uint256 term1ProfitBalanceOnLendingManager = total - assets;
        assert(term1ProfitBalance == term1ProfitBalanceOnLendingManager);

        // term owner claim loan profit for term2
        vm.startPrank(lender1);
        loanManager.claimAllocation(termId2, loanId);
        vm.stopPrank();

        // check term owner balance
        // calculate repay amount in shares
        repayAssetsInShares = assetManager.convertToShares(address(token1), loan.repayAssets);
        // calculate shares required
        sharesRequired = assetManager.convertToShares(address(token1), loan.assetsRequired);
        profitShares = repayAssetsInShares - sharesRequired;
        // get term weight on loan
        uint256 term2Weight = (
            loanManager.getTermAllocatedSharesOnLoan(loanId, termId2, address(token1)) * BASIS_POINTS
        ) / loan.sharesAllocated;
        // calculate profit for term1
        uint256 term2Profit = (profitShares * term2Weight) / BASIS_POINTS;
        // from term1 profit calculate lender profit
        uint256 lender1ProfitTerm2 = (term2Profit * 500) / BASIS_POINTS;
        lender1Balance = vaultTokenInterface.balanceOf(lender1);
        assert(lender1Balance == lender1ProfitTerm1 + lender1ProfitTerm2);
        // check term1 profit
        uint256 term2ProfitBalance = term2Profit - lender1ProfitTerm2;
        (total,, assets) = lendingManager.getLendingTermBalances(termId2, address(token1));
        uint256 term2ProfitBalanceOnLendingManager = total - assets;
        assert(term2ProfitBalance == term2ProfitBalanceOnLendingManager);

        // check disposable amount is equal to initial deposit amount
        (, uint256 disposableAmountTerm1,) = lendingManager.getLendingTermBalances(termId1, address(token1));

        uint256 expectedDisposableAmountTerm1 = 500 * (10 ** vaultTokenInterface.decimals());
        assert(disposableAmountTerm1 == expectedDisposableAmountTerm1);

        (, uint256 disposableAmountTerm2,) = lendingManager.getLendingTermBalances(termId2, address(token1));
        uint256 expectedDisposableAmountTerm2 = 1000 * (10 ** vaultTokenInterface.decimals());
        assert(disposableAmountTerm2 == expectedDisposableAmountTerm2);

        // check term freezed shares
        term1FreezedShares = lendingManager.getTermFreezedShares(termId1, address(token1));
        assert(term1FreezedShares == 0);

        term2FreezedShares = lendingManager.getTermFreezedShares(termId2, address(token1));
        assert(term2FreezedShares == 0);

        // depositor1 withdraw from term1
        uint256 depositor1BalanceBeforeWithdraw = vaultTokenInterface.balanceOf(depositor1);
        vm.startPrank(depositor1);
        lendingManager.withdrawFromTerm(termId1, address(token1), depositedShares);
        vm.stopPrank();
        // check depositor1 balance
        uint256 depositor1SharesBalance = vaultTokenInterface.balanceOf(depositor1);
        uint256 expectedDepositor1SharesBalance = depositor1BalanceBeforeWithdraw + depositedShares + term1ProfitBalance;
        assert(depositor1SharesBalance == expectedDepositor1SharesBalance);

        // depositor1 withdraw from term2
        vm.startPrank(depositor1);
        lendingManager.withdrawFromTerm(termId2, address(token1), depositedShares);
        vm.stopPrank();
        expectedDepositor1SharesBalance = expectedDepositor1SharesBalance + depositedShares + (term2ProfitBalance / 2);
        depositor1SharesBalance = vaultTokenInterface.balanceOf(depositor1);
        assert(depositor1SharesBalance == expectedDepositor1SharesBalance);

        // depositor2 withdraw from term2
        uint256 depositor2BalanceBeforeWithdraw = vaultTokenInterface.balanceOf(depositor2);
        vm.startPrank(depositor2);
        lendingManager.withdrawFromTerm(termId2, address(token1), depositedShares);
        vm.stopPrank();
        // check depositor2 balance
        uint256 depositor2SharesBalance = vaultTokenInterface.balanceOf(depositor2);
        uint256 expectedDepositor2SharesBalance =
            depositor2BalanceBeforeWithdraw + depositedShares + (term2ProfitBalance / 2);
        assert(depositor2SharesBalance == expectedDepositor2SharesBalance);
    }

    // todo: move to utils file
    // -----------------------------------------
    // ----------- UTILS FUNCTIONS -------------
    // -----------------------------------------
    function _requestLoan(address borrower, address token, uint256 borrowAssets, uint256 delay)
        private
        returns (uint256)
    {
        vm.startPrank(borrower);
        uint256 loanId = loanManager.requestLoan(address(token), borrowAssets, block.timestamp + delay);
        vm.stopPrank();
        return loanId;
    }

    function _createTerm(address lender, uint96 commission, address hook) private returns (uint256) {
        vm.startPrank(lender);
        uint256 termId = lendingManager.createLendingTerm(commission, IHooks(hook));
        vm.stopPrank();
        return termId;
    }

    function _depositAndDelegate(
        address depositor,
        uint256 depositAssets,
        uint256 delegateShares,
        address token,
        uint256 termId
    ) private {
        ERC20Mock mockToken = ERC20Mock(token);
        vm.startPrank(depositor);
        // deposit some token to vault by asset manager
        uint256 depositAssetsWithDecimals = depositAssets * (10 ** mockToken.decimals());
        mockToken.approve(address(assetManager), depositAssetsWithDecimals);
        assetManager.deposit(address(token), depositAssetsWithDecimals);

        address vaultToken = assetManager.getVaultToken(token);
        IERC4626 vaultTokenInterface = IERC4626(vaultToken);
        uint256 delegateSharesWithDecimals = delegateShares * (10 ** vaultTokenInterface.decimals());

        // approve lending manager to transfer depositor delegate amount from depisitor to lending manager
        vaultTokenInterface.approve(address(lendingManager), delegateSharesWithDecimals);

        // delegate shares to lender1
        lendingManager.depositToTerm(termId, address(token), delegateSharesWithDecimals);
        vm.stopPrank();
    }

    function _allocateTermAndFundOnLoan(
        address lender,
        address token,
        uint256 loanId,
        uint256 termId,
        uint256 allocateAssets
    ) private {
        vm.startPrank(lender);
        // allocate term
        ERC20Mock mockToken = ERC20Mock(token);
        uint256 allocateFundOnTermAssets = allocateAssets * (10 ** mockToken.decimals());
        loanManager.allocateTermAndFundOnLoan(loanId, termId, allocateFundOnTermAssets);
        vm.stopPrank();
    }
}
