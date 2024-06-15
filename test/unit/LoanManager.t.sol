pragma solidity ^0.8.21;

import {console} from "forge-std/Script.sol";
import {SetupTest} from "../Setup.t.sol";
import {ILoanRequest} from "../../src/interfaces/managers/loan/ILoanRequest.sol";

contract LoanManagerTest is SetupTest {
    uint256 borrowAmount;

    function setUp() public {
        SetupTest.setUpEnvironment();

        borrowAmount = 500 * (10 ** token1.decimals());
    }

    function testRequestLoan() public {
        vm.startPrank(borrower1);
        // should revert when the vault is empty
        uint256 loanId = loanManager.requestLoan(
            address(token1),
            borrowAmount,
            block.timestamp + 1 days
        );
        ILoanRequest.Loan memory loan = loanManager.getLoan(loanId);
        vm.stopPrank();
        assert(loan.borrower == borrower1);
        assert(loan.amount == borrowAmount);
        assert(loan.token == address(token1));
        assert(loan.status == ILoanRequest.LoanStatus.Pending);
        assert(loan.currentSharesAllocated == 0);
        assert(
            loan.sharesAmount ==
                assetManager.convertToShares(address(token1), borrowAmount)
        );
    }

    function testAllocateTermInsufficientFundRevert() public {
        vm.startPrank(borrower1);
        // should revert when the vault is empty
        uint256 loanId = loanManager.requestLoan(
            address(token1),
            borrowAmount,
            block.timestamp + 1 days
        );
        vm.stopPrank();

        vm.startPrank(lender1);
        // register as lender and create lending term
        lendingManager.register();
        uint256 termId = lendingManager.createLendingTerm(5);
        // allocate term, but no shares on term
        vm.expectRevert();
        loanManager.allocateTerm(loanId, termId);
        vm.stopPrank();
    }

    function testAllocateTerm() public {
        vm.startPrank(borrower1);
        // should revert when the vault is empty
        uint256 loanId = loanManager.requestLoan(
            address(token1),
            borrowAmount,
            block.timestamp + 1 days
        );
        vm.stopPrank();

        vm.startPrank(lender1);
        // register as lender and create lending term
        lendingManager.register();
        uint256 termId = lendingManager.createLendingTerm(5);
        vm.stopPrank();

        vm.startPrank(depositor1);
        // deposit some token to vault by asset manager
        uint256 depositAmount = 1000 * (10 ** token1.decimals());
        token1.approve(address(assetManager), depositAmount);
        assetManager.deposit(address(token1), depositAmount);
        // delegate shares to lender1
        lendingManager.increaseDelegateToTerm(
            termId,
            address(token1),
            depositAmount
        );
        vm.stopPrank();

        vm.startPrank(lender1);
        // allocate term
        loanManager.allocateTerm(loanId, termId);
        vm.stopPrank();

        bool isAllocated = loanManager.getLoanTermAllocated(loanId, termId);
        assert(isAllocated);
    }

    function testAllocateFundOnLoan() public returns (uint256, uint256) {
        vm.startPrank(borrower1);
        uint256 loanId = loanManager.requestLoan(
            address(token1),
            borrowAmount,
            block.timestamp + 1 days
        );
        vm.stopPrank();

        vm.startPrank(lender1);
        // register as lender and create lending term
        lendingManager.register();
        uint256 termId = lendingManager.createLendingTerm(5);
        vm.stopPrank();

        vm.startPrank(depositor1);
        // deposit some token to vault by asset manager
        uint256 depositAmount = 1000 * (10 ** token1.decimals());
        token1.approve(address(assetManager), depositAmount);
        assetManager.deposit(address(token1), depositAmount);
        // delegate shares to lender1
        uint256 delegateAmount = 500 * (10 ** vaultToken1.decimals());

        lendingManager.increaseDelegateToTerm(
            termId,
            address(token1),
            delegateAmount
        );
        vm.stopPrank();

        vm.startPrank(lender1);
        // allocate term
        loanManager.allocateTerm(loanId, termId);
        uint256 allocateFundOnTermAmount = 500 * (10 ** vaultToken1.decimals());
        loanManager.allocateFundOnLoan(
            loanId,
            termId,
            allocateFundOnTermAmount
        );
        vm.stopPrank();

        ILoanRequest.Loan memory loan = loanManager.getLoan(loanId);
        uint256 depositor1FreezedShares = lendingManager.getUserFreezedShares(
            depositor1,
            address(vaultToken1)
        );
        uint256 depositor1DisposableShares = lendingManager
            .getUserDisposableSharesOnTerm(
                termId,
                depositor1,
                address(vaultToken1)
            );

        assert(loan.currentSharesAllocated == allocateFundOnTermAmount);
        assert(depositor1FreezedShares == allocateFundOnTermAmount);
        assert(depositor1DisposableShares == 0);

        return (loanId, termId);
    }

    function testExecuteLoan() public returns (uint256, uint256) {
        (uint256 loanId, uint256 termId) = testAllocateFundOnLoan();
        vm.startPrank(borrower1);
        loanManager.executeLoan(loanId);
        vm.stopPrank();

        ILoanRequest.Loan memory loan = loanManager.getLoan(loanId);
        uint256 depositor1Shares = assetManager.getUserShares(
            address(token1),
            depositor1
        );
        uint256 expectedDepositor1Shares = 1000 *
            (10 ** vaultToken1.decimals()) -
            500 *
            (10 ** vaultToken1.decimals());
        uint256 borrowerTokenBalance = token1.balanceOf(borrower1);

        assert(loan.status == ILoanRequest.LoanStatus.Active);
        assert(depositor1Shares == expectedDepositor1Shares);
        assert(borrowerTokenBalance == loan.amount);
        return (loanId, termId);
    }

    function testRepayLoan() public {
        (uint256 loanId, uint256 termId) = testExecuteLoan();
        vm.startPrank(borrower1);
        ILoanRequest.Loan memory loan = loanManager.getLoan(loanId);
        token1.approve(address(assetManager), loan.amount);
        loanManager.repay(loanId);
        vm.stopPrank();

        // get borrower balance
        uint256 borrowerBalance = token1.balanceOf(borrower1);
        // get depositor1 shares
        uint256 depositor1Shares = assetManager.getUserShares(
            address(token1),
            depositor1
        );
        // get user freezed shares
        uint256 depositor1FreezedShares = lendingManager.getUserFreezedShares(
            depositor1,
            address(vaultToken1)
        );
        // get user disposable shares
        uint256 depositor1DisposableShares = lendingManager
            .getUserDisposableSharesOnTerm(
                termId,
                depositor1,
                address(vaultToken1)
            );

        assert(borrowerBalance == 0);
        assert(depositor1Shares == 1000 * (10 ** vaultToken1.decimals()));
        assert(depositor1FreezedShares == 0);
        assert(
            depositor1DisposableShares == 500 * (10 ** vaultToken1.decimals())
        );
    }
}