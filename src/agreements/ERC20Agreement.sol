pragma solidity ^0.8.21;

import "../AgreementBedrock.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ERC20Agreement is AgreementBedrock {
    uint256 internal _collateral;

    function initialize(bytes memory initData) public override initializer {
        (
            uint256 lateFee,
            address borrower,
            address PaymentToken,
            uint256[] memory amounts,
            uint256[] memory times,
            uint256 collateral
        ) = abi.decode(initData, (uint256, address, address, uint256[], uint256[], uint256));
        _lateFee = lateFee;
        _lender = msg.sender; // lender deploys this, aka lending pool
        _borrower = borrower;
        _paymentToken = PaymentToken;
        _amounts = amounts;
        _times = times;
        _collateral = collateral;

        uint256 total = 0;
        for (uint256 i = 0; i < _amounts.length; ++i) {
            total += _amounts[i];
        }

        require(_collateral >= total, "Collateral must be greater than loan amount");
    }

    function lateFee() public view override returns (uint256) {
        return _lateFee;
    }

    function paymentToken() public view override returns (address) {
        return _paymentToken;
    }

    function lender() public view override returns (address) {
        return _lender;
    }

    function borrower() public view override returns (address) {
        return _borrower;
    }

    function nextPayment() public view override returns (uint256, uint256) {
        return (_amounts[_paymentCount], _times[_paymentCount]);
    }

    function getPaymentDates() public view override returns (uint256[] memory, uint256[] memory) {
        return (_amounts, _times);
    }

    function totalLoanAmount() public view override returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < _amounts.length; ++i) {
            total += _amounts[i];
        }
        return total;
    }

    function isLoanFinished() public view override returns (bool) {
        return _paymentCount == _amounts.length;
    }

    function withdraw() external override onlyBorrower {
        require(_paymentCount == 0, "Withdrawal can only occur before repayments");
        _beforeLoan(); // transfer collateral to agreement contract
        uint256 totalAllocation = totalLoanAmount();
        uint256 balanceBefore = IERC20(_paymentToken).balanceOf(address(this));
        IERC20(_paymentToken).transfer(_borrower, totalAllocation);
        uint256 balanceAfter = IERC20(_paymentToken).balanceOf(address(this));
        require(balanceBefore - balanceAfter >= _collateral, "Transfer failed");
    }

    function _beforeLoan() internal override onlyBorrower {
        IERC20(_paymentToken).transfer(address(this), _collateral);
    }

    function _afterLoan() internal override onlyBorrower {
        require(isLoanFinished(), "Loan is not finished yet.");
        uint256 collateralAmount = _collateral;
        require(
            IERC20(_paymentToken).balanceOf(address(this)) >= collateralAmount,
            "Insufficient tokens in contract for collateral return."
        );
        IERC20(_paymentToken).transfer(_borrower, collateralAmount);
    }
}
