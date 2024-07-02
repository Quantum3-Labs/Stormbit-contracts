// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {IGovernable} from "./interfaces/utils/IGovernable.sol";
import {IInitialize} from "./interfaces/utils/IInitialize.sol";
import {IERC4626} from "./interfaces/token/IERC4626.sol";
import {IAssetManager} from "./interfaces/managers/asset/IAssetManager.sol";
import {ILoanManager} from "./interfaces/managers/loan/ILoanManager.sol";
import {ILendingManager} from "./interfaces/managers/lending/ILendingManager.sol";

/// @author Quantum3 Labs
/// @title Stormbit Loan Manager
/// @notice entrypoint for loan related operations

contract LoanManager is Initializable, IGovernable, IInitialize, ILoanManager {
    uint16 public constant BASIS_POINTS = 10_000;

    address private _governor;

    mapping(address user => uint256 counter) public userLoanNonce;

    ILendingManager public lendingManager;
    IAssetManager public assetManager;

    mapping(uint256 loanId => Loan loan) public loans;
    mapping(uint256 loanId => mapping(uint256 termId => mapping(address vaultToken => uint256 shares))) public
        termAllocatedShares;
    mapping(uint256 loanId => mapping(uint256 termId => bool isAllocated)) public loanTermAllocated;
    // a counter use to track amount of loans a term was allocated to
    mapping(uint256 termId => uint256 loanAllocated) termLoanAllocatedCounter;
    mapping(uint256 termId => mapping(uint256 loanId => mapping(address vaultToken => bool))) public lenderClaimedProfit; // mapping to track lender claim profit

    constructor(address initialGovernor) {
        _governor = initialGovernor;
    }

    // -----------------------------------------
    // ------------- Modifiers -----------------
    // -----------------------------------------

    modifier onlyGovernor() {
        require(msg.sender == _governor, "StormbitAssetManager: not governor");
        _;
    }

    modifier onlyBorrower(uint256 loanId) {
        require(loans[loanId].borrower == msg.sender, "StormbitLoanManager: not borrower");
        _;
    }

    modifier onlyTermOwner(uint256 termId) {
        address owner = lendingManager.getLendingTerm(termId).owner;
        require(owner == msg.sender, "StormbitLendingManager: not term owner");
        _;
    }

    // -----------------------------------------
    // -------- PUBLIC FUNCTIONS ---------------
    // -----------------------------------------

    function initialize(address assetManagerAddr, address lendingManagerAddr) public override initializer {
        assetManager = IAssetManager(assetManagerAddr);
        lendingManager = ILendingManager(lendingManagerAddr);
    }

    /// @dev allow borrower to request loan
    /// @param token address of the token
    /// @param assets amount of token to borrow
    /// @param deadline deadline of the loan to be allocated
    /// @return loanId id of the loan
    function requestLoan(address token, uint256 assets, uint256 deadline) public override returns (uint256) {
        // todo: see which agreement to use

        // check if token is supported
        require(assetManager.isTokenSupported(token), "StormbitLoanManager: token not supported");

        uint256 loanNonce = userLoanNonce[msg.sender];
        uint256 loanId = uint256(keccak256(abi.encode(msg.sender, loanNonce)));
        loanNonce += 1;
        userLoanNonce[msg.sender] = loanNonce;

        // todo: change the fixed rate
        // 5% interest rate
        uint256 repayAssets = assets + (assets * 500) / BASIS_POINTS;

        loans[loanId] = Loan({
            borrower: msg.sender,
            token: token,
            repayAssets: repayAssets,
            assetsRequired: assets,
            assetsAllocated: 0,
            sharesAllocated: 0,
            deadlineAllocate: deadline,
            status: LoanStatus.Pending
        });

        emit LoanRequested(loanId, msg.sender, token, assets);
        return loanId;
    }

    /// @dev allow borrower to execute the loan and receive the fund
    /// @param loanId id of the loan
    function executeLoan(uint256 loanId) public override onlyBorrower(loanId) {
        Loan memory loan = loans[loanId];
        // require valid loan
        require(_validLoan(loanId), "StormbitLoanManager: invalid loan");
        require(loan.status == LoanStatus.Pending, "StormbitLoanManager: loan not pending");
        require(loan.assetsAllocated >= loan.assetsRequired, "StormbitLoanManager: insufficient allocation");
        // only if deadline is passed
        require(block.timestamp >= loan.deadlineAllocate, "StormbitLoanManager: deadline not passed");

        loans[loanId].status = LoanStatus.Active;
        lendingManager.borrowerWithdraw(
            // withdraw by asset manager
            loan.borrower,
            loan.token,
            loan.assetsRequired
        );
        emit LoanExecuted(loanId, loan.borrower, loan.token, loan.repayAssets);
    }

    /// @dev allow anyone to repay the loan, not restricted to borrower
    /// @param loanId id of the loan
    function repay(uint256 loanId) public override {
        // check if loan is valid
        require(_validLoan(loanId), "StormbitLoanManager: invalid loan");
        Loan memory loan = loans[loanId];
        require(loan.status == LoanStatus.Active, "StormbitLoanManager: loan not active");
        assetManager.depositFrom(loan.token, loan.repayAssets, msg.sender, address(lendingManager));
        loans[loanId].status = LoanStatus.Repaid;
        emit LoanRepaid(loanId, msg.sender);
    }

    /// @dev allow lender to allocate fund on the loan, but only when the term is already allocated
    /// @param loanId id of the loan
    /// @param termId id of the term
    /// @param assets amount of token to allocate
    function allocateTermAndFundOnLoan(uint256 loanId, uint256 termId, uint256 assets)
        public
        override
        onlyTermOwner(termId)
    {
        Loan memory loan = loans[loanId];
        // check is valid loan
        require(_validLoan(loanId), "StormbitLoanManager: invalid loan");
        require(block.timestamp < loan.deadlineAllocate, "StormbitLoanManager: deadline passed");
        // only if allocate deadline not passed
        require(block.timestamp < loans[loanId].deadlineAllocate, "StormbitLoanManager: deadline passed");

        // if first time allocate to the loan, update status
        if (!loanTermAllocated[loanId][termId]) {
            loanTermAllocated[loanId][termId] = true;
            termLoanAllocatedCounter[termId] += 1;
        }

        // get disposable shares on token of the term
        address token = loan.token;
        // get the corresponding vault token
        address vaultToken = assetManager.getVaultToken(token);
        // get term owner disposable shares
        (, uint256 termOwnerDisposableShares,) = lendingManager.getLendingTermBalances(termId, token);
        // convert assets to shares
        uint256 sharesRequired = assetManager.convertToShares(token, assets);
        require(
            termOwnerDisposableShares >= sharesRequired,
            "StormbitLoanManager: term owner insufficient disposable shares"
        );
        // fund shares should less than loan shares required
        require(
            loan.assetsAllocated + assets <= loan.assetsRequired, "StormbitLoanManager: loan assets required exceeded"
        );

        // freeze the term owner shares
        lendingManager.freezeTermShares(termId, sharesRequired, token);

        loans[loanId].sharesAllocated += sharesRequired;
        loans[loanId].assetsAllocated += assets;
        termAllocatedShares[loanId][termId][vaultToken] += sharesRequired;

        emit AllocatedTermAndFundOnLoan(loanId, termId, assets);
    }

    /// @dev allow lender to claim the profit for loan or claim the allocated fund to loan but loan deadline pass and not executed, then add the remaining profit to term profit
    function claimAllocation(uint256 termId, uint256 loanId) public override {
        Loan memory loan = loans[loanId];
        address vaultToken = assetManager.getVaultToken(loan.token);

        require(
            loan.status == ILoanManager.LoanStatus.Repaid || loan.status == ILoanManager.LoanStatus.Pending,
            "StormbitLendingManager: loan not repaid nor pending"
        );
        // term allocated on shares should > 0
        uint256 weight = termAllocatedShares[loanId][termId][vaultToken];
        require(weight > 0, "StormbitLendingManager: term not allocated on loan");

        if (loan.status == ILoanManager.LoanStatus.Repaid) {
            // check if the profit has been claimed
            if (lenderClaimedProfit[termId][loanId][vaultToken]) {
                revert("StormbitLendingManager: profit already claimed");
            }
            // get lending term
            ILendingManager.LendingTermMetadata memory term = lendingManager.getLendingTerm(termId);
            // convert repay assets to shares
            uint256 repayShares = assetManager.convertToShares(loan.token, loan.repayAssets);
            // calculate profit
            // calculate shares required, convert assets to shares
            uint256 sharesRequired = assetManager.convertToShares(loan.token, loan.assetsRequired);
            uint256 profitShares = repayShares - sharesRequired;
            // calculate weight of term in shares / loan required shares
            uint256 termFundedPercent = (weight * BASIS_POINTS) / sharesRequired;
            // term owner profit shares
            uint256 termProfitShares = (profitShares * termFundedPercent) / BASIS_POINTS;
            // from term profit shares, get commission for term owner
            uint256 termOwnerProfitShares = (termProfitShares * term.comission) / BASIS_POINTS;
            // calculate the remaining profit after term owner profit
            uint256 extraProfit = termProfitShares - termOwnerProfitShares;

            lendingManager.distributeProfit(termId, loan.token, extraProfit, weight, termOwnerProfitShares);

            // update claimed status
            lenderClaimedProfit[termId][loanId][vaultToken] = true;

            // decrement term allocated counter
            termLoanAllocatedCounter[termId] -= 1;

            emit ClaimAllocation(termId, loanId, loan.token, termOwnerProfitShares);
        } else if (loan.status == ILoanManager.LoanStatus.Pending) {
            // if block.timestamp not passed the deadline
            if (block.timestamp < loan.deadlineAllocate) {
                revert("StormbitLendingManager: loan not eligible for claiming");
            }
            // If the loan deadline has passed and was not executed, unfreeze the term shares
            lendingManager.unfreezeTermShares(termId, weight, loan.token);
            // update loan status to cancelled
            loans[loanId].status = ILoanManager.LoanStatus.Cancelled;

            emit ClaimAllocation(termId, loanId, loan.token, weight);
        }
    }

    // -----------------------------------------
    // ----------- PRIVATE FUNCTIONS -----------
    // -----------------------------------------
    function _validLoan(uint256 loanId) private view returns (bool) {
        return loans[loanId].borrower != address(0);
    }

    function _calculateSharesRequired(address token, uint256 assets) private view returns (uint256) {
        // get the vault token
        address vaultToken = assetManager.getVaultToken(token);
        // convert assets to shares
        uint256 sharesRequired = IERC4626(vaultToken).convertToShares(assets);
        return sharesRequired;
    }

    // -----------------------------------------
    // -------- PUBLIC GETTER FUNCTIONS --------
    // -----------------------------------------
    function governor() public view override returns (address) {
        return _governor;
    }

    /// @dev get the loan details
    function getLoan(uint256 loanId) public view override returns (Loan memory) {
        return loans[loanId];
    }

    /// @dev get the allocation status of a term on a loan
    function getLoanTermAllocated(uint256 loanId, uint256 termId) public view override returns (bool) {
        return loanTermAllocated[loanId][termId];
    }

    /// @dev get the amount of loans a term was allocated to
    function getTermLoanAllocatedCounter(uint256 termId) external view override returns (uint256) {
        return termLoanAllocatedCounter[termId];
    }

    /// @dev get the allocated shares on the loan
    function getTermAllocatedSharesOnLoan(uint256 loanId, uint256 termId, address token)
        public
        view
        override
        returns (uint256)
    {
        address vaultToken = assetManager.getVaultToken(token);
        return termAllocatedShares[loanId][termId][vaultToken];
    }
}
