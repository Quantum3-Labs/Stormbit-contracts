// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

// import "./interfaces/IStormBitLending.sol";
import {IStormBit, IStormBitLending} from "./interfaces/IStormBit.sol";
import {IAgreement} from "./interfaces/IAgreement.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {IStormBitLendingVotes} from "./interfaces/IStormBitLendingVotes.sol";

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {GovernorUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/GovernorUpgradeable.sol";
import {GovernorVotesUpgradeable, IVotes} from "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorVotesUpgradeable.sol";
import {GovernorVotesQuorumFractionUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorVotesQuorumFractionUpgradeable.sol";

import {GovernorCountingSimpleUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorCountingSimpleUpgradeable.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// - StormBitLending: implementation contract to be used when creating new lending pools.
//     - has a bunch of setters and getters that are only owner.
//     - has a approve loan function that is only available for people with voting power. ( can use a tweaked governance here )

contract StormBitLending is
    IStormBitLending,
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuard,
    GovernorUpgradeable,
    GovernorCountingSimpleUpgradeable,
    GovernorVotesUpgradeable,
    GovernorVotesQuorumFractionUpgradeable
{
    // ---------- CONFIG VARS ----------
    IStormBit internal _stormBit;

    string public poolName;
    uint256 public creditScore;
    uint256 public maxAmountOfStakers;
    uint256 public votingQuorum;
    uint256 public maxPoolUsage;
    uint256 public votingPowerCoolDown;
    address public lendingVotes;

    mapping(address => bool) public isSupportedAsset;
    mapping(bytes4 => bool) public isSupportedAction;
    mapping(address => bool) public isSupportedAgreement;

    mapping(address => address) public userAgreement;

    constructor() {
        _disableInitializers();
    }

    modifier onlySelf() {
        require(msg.sender == address(this), "StormBitLending: not self");
        _;
    }

    modifier onlyStormBit() {
        require(
            msg.sender == address(_stormBit),
            "StormBitLending: not StormBit"
        );
        _;
    }

    function initializeLending(
        InitParams memory params,
        address _firstOwner,
        address stormBitLendingVotes
    ) external override initializer {
        poolName = params.name;
        _stormBit = IStormBit(msg.sender);
        creditScore = params.creditScore;
        maxAmountOfStakers = params.maxAmountOfStakers;
        votingQuorum = params.votingQuorum;
        maxPoolUsage = params.maxPoolUsage;
        votingPowerCoolDown = params.votingPowerCoolDown;
        lendingVotes = stormBitLendingVotes;

        __Ownable_init(_firstOwner);
        __Governor_init(poolName);
        __GovernorVotes_init(IVotes(stormBitLendingVotes));
        __GovernorVotesQuorumFraction_init(votingQuorum);

        (
            address initToken,
            uint256 initAmount,
            address[] memory supportedAssets
        ) = (params.initToken, params.initAmount, params.supportedAssets);

        // setup supported calls
        isSupportedAction[this.changeVotingQuorum.selector] = true;
        isSupportedAction[this.changeMaxPoolUsage.selector] = true;
        isSupportedAction[this.changeVotingPowerCoolDown.selector] = true;
        isSupportedAction[this.changeMaxAmountOfStakers.selector] = true;

        // setup supported assets
        for (uint256 i = 0; i < supportedAssets.length; i++) {
            isSupportedAsset[supportedAssets[i]] = true;
        }

        // check if init token is supported
        require(
            isSupportedAsset[initToken],
            "StormBitLending: init token not supported"
        );
        for (uint256 i = 0; i < params.supportedAgreements.length; i++) {
            isSupportedAgreement[params.supportedAgreements[i]] = true;
        }
        // check if this pool already has the amount of assets of the token in the ERC4626 of the main contract
        // setup with first deposit @notice Transfer is done from core.
        // IERC20(initToken).transferFrom(_firstOwner, address(this), initAmount);
        _stake(initAmount, _firstOwner);
    }

    function stake(address token, uint256 amount) external {
        // transfer the assets from the user into the ERC4626 of the main contract
        // stake the amount of shares in the pool
        require(
            isSupportedAsset[token],
            "StormBitLending: asset not supported"
        );
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        _stake(amount, msg.sender);
    }

    function requestLoan(
        LoanRequestParams memory params
    ) external virtual returns (uint256 proposalId) {
        // TODO perform checks on the amounts that are requested on the agreement contract
        require(
            isSupportedAgreement[params.agreement],
            "StormBitLending: agreement not supported"
        );
        require(
            isSupportedAsset[params.token],
            "StormBitLending: asset not supported"
        );
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        string memory description = "Loan Request";
        targets[0] = address(this);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSelector(
            this.executeLoan.selector,
            params.token,
            msg.sender,
            params.amount,
            params.agreement,
            params.agreementCalldata
        );
        uint256 loanRequestId = _propose(
            targets,
            values,
            calldatas,
            description,
            msg.sender
        );
        return loanRequestId;
    }

    // ---------- STORMBIT CALLS ----------------
    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    )
        public
        payable
        override(GovernorUpgradeable)
        returns (
            // onlyStormBit - for demo purposes we wont be using this
            uint256
        )
    {
        return super.execute(targets, values, calldatas, descriptionHash);
    }

    // ---------- SELF CALLABLE - GOV FUNCTIONS ----------------

    function executeLoan(
        address token,
        address to,
        uint256 amount,
        address agreement,
        bytes calldata agreementCalldata
    ) external onlySelf {
        require(
            userAgreement[to] == address(0),
            "StormBitLending: user has loan"
        );
        address newAgreement = Clones.clone(agreement);
        IAgreement(newAgreement).initialize(agreementCalldata);
        IERC20(token).transfer(newAgreement, amount);
        userAgreement[to] = newAgreement;
    }

    function changeAgreementStatus(
        address agreement,
        bool status
    ) external onlySelf {
        _changeAgreementStatus(agreement, status);
    }

    function changeVotingQuorum(uint256 newQuorum) external onlySelf {
        votingQuorum = newQuorum;
    }

    function changeMaxPoolUsage(uint256 newMaxPoolUsage) external onlySelf {
        maxPoolUsage = newMaxPoolUsage;
    }

    function changeVotingPowerCoolDown(uint256 newCoolDown) external onlySelf {
        votingPowerCoolDown = newCoolDown;
    }

    function changeMaxAmountOfStakers(
        uint256 newMaxAmountOfStakers
    ) external onlySelf {
        maxAmountOfStakers = newMaxAmountOfStakers;
    }

    // ---------- INTERNALS ----------------

    function _changeAgreementStatus(address agreement, bool status) internal {
        isSupportedAgreement[agreement] = status;
    }

    function _stake(uint256 amount, address staker) internal {
        // calculate the shares of the pool that belong to this amount
        // we can consider all tokens to have same weight first

        // TODO : change this
        uint256 sharesInPool = amount;
        IStormBitLendingVotes(lendingVotes).mint(staker, sharesInPool);
        IStormBitLendingVotes(lendingVotes).delegate(staker, staker); // self delegate
    }

    // TODO: change this to a fixed voting delay
    // ---------- OVERRIDES ---------------------------
    function votingDelay() public pure override returns (uint256) {
        return 0;
    }

    // TODO : change this back to 7 days of voting period
    function votingPeriod() public pure override returns (uint256) {
        // return 7 days; // 1 week
        // for demo purposes we will use 5 minutes
        return 5 * 60;
    }

    function name()
        public
        view
        override(GovernorUpgradeable)
        returns (string memory)
    {
        return poolName;
    }

    function clock()
        public
        view
        override(GovernorUpgradeable, GovernorVotesUpgradeable)
        returns (uint48)
    {
        return SafeCast.toUint48(block.timestamp);
    }

    function getValidVotes(address account) public view returns (uint256) {
        if (block.timestamp < votingPowerCoolDown) return 0;
        return
            IVotes(lendingVotes).getPastVotes(
                account,
                block.timestamp - votingPowerCoolDown
            );
    }

    // TODO : remove this and use a way to call it on the UI
    function getVotingPower(address staker) public view returns (uint256) {
        uint256 tokenSupply = IERC20(lendingVotes).totalSupply();
        uint256 stakerValidVotes = getValidVotes(staker);
        return (stakerValidVotes * 100) / tokenSupply;
    }

    function _getVotes(
        address account,
        uint256 timepoint,
        bytes memory /*params*/
    )
        internal
        view
        override(GovernorUpgradeable, GovernorVotesUpgradeable)
        returns (uint256)
    {
        if (timepoint < votingPowerCoolDown) return 0;
        return super._getVotes(account, timepoint - votingPowerCoolDown, "");
    }

    function CLOCK_MODE()
        public
        view
        virtual
        override(GovernorUpgradeable, GovernorVotesUpgradeable)
        returns (string memory)
    {
        return "mode=blocktimestamp&from=default";
    }
}
