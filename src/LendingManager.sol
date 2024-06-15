pragma solidity ^0.8.21;

import {ILendingTerms} from "./interfaces/managers/lending/ILendingTerms.sol";
import {ILenderRegistry} from "./interfaces/managers/lending/ILenderRegistry.sol";
import {ILoanExecute} from "./interfaces/managers/lending/ILoanExecute.sol";
import {IERC4626} from "./interfaces/token/IERC4626.sol";
import {IGovernable} from "./interfaces/utils/IGovernable.sol";
import {StormbitAssetManager} from "./AssetManager.sol";
import {StormbitLoanManager} from "./LoanManager.sol";

/// @author Quantum3 Labs
/// @title Stormbit Lending Manager
/// @notice entrypoint for all lender and lending terms operations

// todo: use custom error
contract StormbitLendingManager is
    IGovernable,
    ILendingTerms,
    ILenderRegistry,
    ILoanExecute
{
    // todo: move to interface
    struct Shares {
        uint256 disposableAmount;
        uint256 totalAmount;
    }

    address private _governor;
    StormbitAssetManager public assetManager;
    StormbitLoanManager public loanManager;

    mapping(address => bool) public registeredLenders;
    mapping(uint256 => LendingTerm) public lendingTerms;
    // total shares controlled by the term owner
    mapping(uint256 termId => mapping(address vaultToken => Shares shares))
        public termOwnerShares;
    // total shares controlled by the depositor on term
    mapping(uint256 termId => mapping(address user => mapping(address vaultToken => Shares Shares)))
        public termUserDelegatedShares;
    // track user total delegated shares
    mapping(address user => mapping(address vaultToken => uint256 delegatedShares))
        public userTotalDelegatedShares;
    // track who delegated to the term
    mapping(uint256 termId => mapping(address vaultToken => address[] user)) termDelegatedUsers;
    // locked shares, the shares want lent out
    mapping(address user => mapping(address vaultToken => uint256 sharesAmount)) userFreezedShares;

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

    modifier onlyRegisteredLender() {
        require(
            registeredLenders[msg.sender],
            "StormbitLendingManager: not registered lender"
        );
        _;
    }

    modifier onlyLoanManager() {
        require(
            msg.sender == address(loanManager),
            "StormbitLendingManager: not loan manager"
        );
        _;
    }

    // -----------------------------------------
    // -------- PUBLIC FUNCTIONS ---------------
    // -----------------------------------------

    // todo: use oz initializer
    // todo: move to interface
    function initialize(
        address assetManagerAddr,
        address loanManagerAddr
    ) public {
        assetManager = StormbitAssetManager(assetManagerAddr);
        loanManager = StormbitLoanManager(loanManagerAddr);
    }

    function register() public override {
        registeredLenders[msg.sender] = true;
    }

    /// @dev create a lending term
    /// @param comission comission rate
    /// @return id of the lending term
    function createLendingTerm(
        uint256 comission
    ) public override onlyRegisteredLender returns (uint256) {
        uint256 id = uint256(keccak256(abi.encode(msg.sender, comission)));
        require(
            !_validLendingTerm(id),
            "StormbitLendingManager: lending term already exists"
        );
        lendingTerms[id] = LendingTerm(msg.sender, comission, 0);
        emit LendingTermCreated(id, msg.sender, comission);
        return id;
    }

    /// @dev remove a lending term
    /// @param id id of the lending term
    function removeLendingTerm(
        uint256 id
    ) public override onlyRegisteredLender {
        require(
            _validLendingTerm(id),
            "StormbitLendingManager: lending term does not exist"
        );
        // if there are delegated shares, the term cannot be removed
        // get term
        LendingTerm memory term = lendingTerms[id];
        require(
            term.balances <= 0,
            "StormbitLendingManager: term has delegated shares"
        );

        delete lendingTerms[id];
        emit LendingTermRemoved(id);
    }

    // todo: what if user delegated token, but he spend the token outside stormbit but here is still recording old amount, it will make transaction fail when borrower is doing loan
    /// @dev allow depositor to delegate shares to a lending term
    /// @param termId id of the lending term
    /// @param token address of the token
    /// @param sharesAmount amount of shares to delegate
    function increaseDelegateToTerm(
        uint256 termId,
        address token,
        uint256 sharesAmount
    ) public {
        require(
            _validLendingTerm(termId),
            "StormbitLendingManager: lending term does not exist"
        );
        require(
            assetManager.isTokenSupported(token),
            "StormbitLendingManager: token not supported"
        );
        address vaultToken = assetManager.getTokenVault(token);
        // get current delegated shares to the term
        uint256 currentDelegatedShares = userTotalDelegatedShares[msg.sender][
            vaultToken
        ];
        // get user shares in the vault
        uint256 userShares = assetManager.getUserShares(token, msg.sender);
        uint256 userCurrentTotalDelegatedShares = currentDelegatedShares +
            sharesAmount;
        // check if the user has enough shares
        require(
            userShares >= userCurrentTotalDelegatedShares,
            "StormbitLendingManager: not enough shares"
        );
        // update user total delegated shares, prevent scenario delegate more than user has
        userTotalDelegatedShares[msg.sender][vaultToken] += sharesAmount;

        // update term total disposable shares (allowance)
        termOwnerShares[termId][vaultToken].disposableAmount += sharesAmount;
        termOwnerShares[termId][vaultToken].totalAmount += sharesAmount;

        if (
            termUserDelegatedShares[termId][msg.sender][vaultToken]
                .totalAmount <= 0
        ) {
            // this is the first time the user is delegating to the term
            // update the list of users who delegated to the term
            termDelegatedUsers[termId][vaultToken].push(msg.sender);
        }
        // update the amount of shares delegated to the term by the user
        termUserDelegatedShares[termId][msg.sender][vaultToken]
            .totalAmount += sharesAmount;
        termUserDelegatedShares[termId][msg.sender][vaultToken]
            .disposableAmount += sharesAmount;

        // update term balance
        lendingTerms[termId].balances += sharesAmount;

        // approve the asset manager to spend the shares
        assetManager.approve(
            msg.sender,
            vaultToken,
            userCurrentTotalDelegatedShares
        );

        emit IncreaseDelegateSharesToTerm(
            termId,
            msg.sender,
            vaultToken,
            sharesAmount
        );
    }

    /// @dev allow lender to decrease delegated shares to a lending term
    /// @param termId id of the lending term
    /// @param vaultToken address of the token
    /// @param requestedDecrease amount of shares to decrease
    function decreaseDelegateToTerm(
        uint256 termId,
        address vaultToken,
        uint256 requestedDecrease
    ) public {
        require(
            _validLendingTerm(termId),
            "StormbitLendingManager: lending term does not exist"
        );
        // get current delegated shares to the term
        uint256 currentDelegatedShares = termUserDelegatedShares[termId][
            msg.sender
        ][vaultToken].totalAmount;
        // currenly "disposable" shares
        uint256 disposableDelegatedShares = termUserDelegatedShares[termId][
            msg.sender
        ][vaultToken].disposableAmount;

        require(
            currentDelegatedShares >= requestedDecrease,
            "StormbitLendingManager: insufficient delegated shares"
        );
        // check if the user has enough unfreezed shares
        require(
            disposableDelegatedShares >= requestedDecrease,
            "StormbitLendingManager: insufficient unfreezed shares"
        );
        termUserDelegatedShares[termId][msg.sender][vaultToken]
            .disposableAmount -= requestedDecrease;
        termUserDelegatedShares[termId][msg.sender][vaultToken]
            .totalAmount -= requestedDecrease;
        userTotalDelegatedShares[msg.sender][vaultToken] -= requestedDecrease;

        termOwnerShares[termId][vaultToken].totalAmount -= requestedDecrease;
        termOwnerShares[termId][vaultToken]
            .disposableAmount -= requestedDecrease;

        // update term balance
        lendingTerms[termId].balances -= requestedDecrease;

        emit DecreaseDelegateSharesToTerm(
            termId,
            msg.sender,
            vaultToken,
            requestedDecrease
        );
    }

    function freezeSharesOnTerm(
        uint256 termId,
        address vaultToken,
        address depositor,
        uint256 freezeAmount
    ) public onlyLoanManager {
        require(
            _validLendingTerm(termId),
            "StormbitLendingManager: lending term does not exist"
        );
        require(
            termUserDelegatedShares[termId][depositor][vaultToken]
                .disposableAmount >= freezeAmount,
            "StormbitLendingManager: insufficient disposable shares"
        );
        termUserDelegatedShares[termId][depositor][vaultToken]
            .disposableAmount -= freezeAmount;
        userFreezedShares[depositor][vaultToken] += freezeAmount;
        // also reduce the term owner disposable shares
        termOwnerShares[termId][vaultToken].disposableAmount -= freezeAmount;
        // todo: emit event
    }

    function unfreezeSharesOnTerm(
        uint256 termId,
        address vaultToken,
        address depositor,
        uint256 unfreezeAmount
    ) public onlyLoanManager {
        require(
            _validLendingTerm(termId),
            "StormbitLendingManager: lending term does not exist"
        );
        require(
            userFreezedShares[depositor][vaultToken] >= unfreezeAmount,
            "StormbitLendingManager: insufficient freezed shares"
        );
        userFreezedShares[depositor][vaultToken] -= unfreezeAmount;
        termUserDelegatedShares[termId][depositor][vaultToken]
            .disposableAmount += unfreezeAmount;
        // also increase the term owner disposable shares
        termOwnerShares[termId][vaultToken].disposableAmount += unfreezeAmount;
    }

    // -----------------------------------------
    // ---------- INTERNAL FUNCTIONS -----------
    // -----------------------------------------

    /// @dev check if lending term exists
    /// @param id id of the lending term
    function _validLendingTerm(uint256 id) internal view returns (bool) {
        return lendingTerms[id].owner != address(0);
    }

    // -----------------------------------------
    // -------- PUBLIC GETTER FUNCTIONS --------
    // -----------------------------------------

    function governor() public view override returns (address) {
        return _governor;
    }

    /// @dev check a lenders is registered
    /// @param lender address of the lender
    function isRegistered(address lender) public view override returns (bool) {
        return registeredLenders[lender];
    }

    function getLendingTerm(
        uint256 id
    ) public view returns (LendingTerm memory) {
        return lendingTerms[id];
    }

    function getDisposableSharesOnTerm(
        uint256 termId,
        address vaultToken
    ) public view returns (uint256) {
        return termOwnerShares[termId][vaultToken].disposableAmount;
    }

    function getTermDepositors(
        uint256 termId,
        address vaultToken
    ) public view returns (address[] memory) {
        return termDelegatedUsers[termId][vaultToken];
    }

    function getUserDisposableSharesOnTerm(
        uint256 termId,
        address user,
        address vaultToken
    ) public view returns (uint256) {
        return
            termUserDelegatedShares[termId][user][vaultToken].disposableAmount;
    }

    function getUserFreezedShares(
        address user,
        address vaultToken
    ) public view returns (uint256) {
        return userFreezedShares[user][vaultToken];
    }
}
