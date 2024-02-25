// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.21;

// import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
// import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
// import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

// import {ERC721Agreement} from "./agreements/ERC721Agreement.sol";
// import {ERC20Agreement} from "./agreements/ERC20Agreement.sol";
// import {SimpleAgreement} from "./agreements/SimpleAgreement.sol";
// import {IAgreement} from "./interfaces/IAgreement.sol";
// import {IStormBitVault} from "./interfaces/IStormBitVault.sol";

// contract StormBitVault is IStormBitVault, AccessManagedUpgradeable, ERC4626Upgradeable, UUPSUpgradeable {
//     IERC20 private _underlyingToken;
//     uint256 public totalDeposits;
//     uint256 public totalBorrowed;

//     // /**
//     // * @dev Agreement ERC20 strategy
//     // */
//     // ERC20Agreement public _ERC20_AGREEEMENT;

//     // /**
//     // * @dev Agreement ERC721 strategy
//     // */
//     // ERC721Agreement public _ERC721_AGREEEMENT;

//     // /**
//     // * @dev Agreement Simple strategy
//     // */
//     // SimpleAgreement public _SIMPLE_AGREEEMENT;

//     /**
//      * @dev StormBit strategy
//      */
//     IAgreement internal immutable _STORMBIT_AGREEEMENT;

//     constructor(IERC20 _underlyingToken, IAgreement stormbitAgreement) payable {
//         _underlyingToken = _underlyingToken;
//         _STORMBIT_AGREEEMENT = stormbitAgreement;
//         _disableInitializers();
//     }

//     function initialize(address accessManager) external initializer {
//         __AccessManaged_init(accessManager);
//         __ERC4626_init(_underlyingToken);
//         __ERC20_init("DAI", "DAI");
//     }

//     receive() external payable virtual {
//         // TO DO : security to be implemented // @audit - protect against creating withdrawal from attackers
//     }

//     /**
//      * @inheritdoc ERC4626Upgradeable
//      * @dev Restricted in this context is like `whenNotPaused` modifier from Pausable.sol
//      */
//     function deposit(uint256 assets, address receiver) public virtual override restricted returns (uint256) {
//         return super.deposit(assets, receiver);
//     }

//     /**
//      * @inheritdoc ERC4626Upgradeable
//      * @dev Restricted in this context is like `whenNotPaused` modifier from Pausable.sol
//      */
//     function mint(uint256 assets, address receiver) public override restricted returns (uint256) {
//         return super.mint(assets, receiver);
//     }

//     /**
//      * Not allowed
//      */
//     function redeem(uint256, address, address) public virtual override returns (bytes4) {
//         revert WithdrawalsAreDisabled();
//     }

//     /**
//      * @notice Not allowed
//      */
//     function withdraw(uint256, address, address) public virtual override returns (bytes4) {
//         revert WithdrawalsAreDisabled();
//     }

//     /**
//      * @dev See {IERC4626-totalAssets}.
//      */
//     function totalAssets() public view virtual override returns (uint256) {
//         return _underlyingToken.balanceOf(address(this));
//     }

//     /**
//      * @notice Returns the number of decimals used to get its user representation.
//      */
//     function decimals() public pure override(ERC20Upgradeable, ERC4626Upgradeable) returns (uint8) {
//         return 18;
//     }

//     /**
//      * @dev Authorizes an upgrade to a new implementation
//      * Restricted access
//      * @param newImplementation The address of the new implementation
//      */
//     // slither-disable-next-line dead-code
//     function _authorizeUpgrade(address newImplementation) internal virtual override restricted {}

//     // // Interest rate following Compound model
//     // // Lenders earn interest based on the liquidity they provide.
//     // // Borrowers pay interest on their loan.
//     // // How is the spread calculated ? => Interet earned by the protocol

//     // function deposit(uint256 _amount) external {
//     //     _underlyingToken.transferFrom(msg.sender, address(this), _amount);
//     //     totalDeposits += _amount;
//     // }

//     // function borrow(uint256 _amount) external {
//     //     require(_underlyingToken.balanceOf(address(this)) >= _amount, "Not enough liquidity");
//     //     _underlyingToken.transfer(msg.sender, _amount);
//     //     totalBorrowed += _amount;
//     // }

//     // /**
//     //  * @notice Returns the utilization of the pool
//     //  *     @dev utilization =  borrowed / total deposits
//     //  */
//     // function getUtilization() public view returns (uint256) {
//     //     uint256 utilization = totalBorrowed / totalDeposits;
//     //     return utilization;
//     // }

//     // /**
//     //  * @notice returns intereste rates
//     //  *     @dev  interest rates are calculated based on the utilization of the pool
//     //  */
//     // function getInterestRates() public view returns (uint256) {
//     //     return 1;
//     // }

//     // /**
//     //  * @notice returns the supply rate
//     //  *     @dev  supply rate is interest rate for lenders
//     //  */
//     // function getSupplyRate() public view returns (uint256) {
//     //     return getInterestRates() * getUtilization();
//     // }

//     // // --------------- Liquidition management -------------------------- //

//     // // TO DO : Protect Lenders from liquidation

//     // //
//     // struct Collateral {
//     //     uint256 collateralType;
//     // }

//     // function getCollateralValue(Collateral memory _collateral, uint256 _DAIAmount) public view returns (uint256) {
//     //     if (_collateral.collateralType == 1) {
//     //         return _DAIAmount;
//     //     }
//     //     // } else {
//     //     //     // TO DO : use API to price the NFT
//     //     // }

//     //     return _DAIAmount;
//     // }

//     // function getCollateralFactor(uint256 _loanValue) public view returns (uint256) {
//     //     Collateral memory _collateral = Collateral(1);
//     //     return _loanValue / getCollateralValue(_collateral, 20000);
//     // }

//     // /**
//     //  * @notice returns the liquidation factor
//     //  * @dev  liquidation factor is the ratio of the value of the collateral to the value of the loan
//     //  */
//     // function getLiquidationFactor() public view returns (uint256) {}
// }
