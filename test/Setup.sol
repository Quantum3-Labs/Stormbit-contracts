pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DiamondProxy, LibDiamond} from "../src/DiamondProxy.sol";
import {DiamondInit, InitParams} from "../src/initializers/DiamondInit.sol";
import {AdminFacet} from "../src/facets/AdminFacet.sol";
import {CoreFacet} from "../src/facets/CoreFacet.sol";
import {LendingFacet} from "../src/facets/LendingFacet.sol";
import {RegistryFacet} from "../src/facets/RegistryFacet.sol";
import {BaseVault} from "../src/vaults/BaseVault.sol";
import {MockToken} from "../src/mocks/MockToken.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Setup is Test {
    DiamondProxy public stormbit;
    DiamondInit public diamondInit;
    AdminFacet public adminFacet;
    CoreFacet public coreFacet;
    LendingFacet public lendingFacet;
    RegistryFacet public registryFacet;

    /// @dev vaults
    BaseVault public usdtVault;
    MockToken usdt;
    /// @dev initial config params
    address governor = makeAddr("governor");

    /// @dev constants
    uint256 constant DECIMALS = 10 ** 18;

    function setUp() public virtual {
        // ------- MOCKS --------
        usdt = new MockToken("US Dollar", "USDT");
        // ------- VAULTS --------
        usdtVault = new BaseVault(IERC20(usdt), governor, "USDT Vault", "sUSDT");

        // ------- FACETS --------
        adminFacet = new AdminFacet();
        coreFacet = new CoreFacet();
        lendingFacet = new LendingFacet();
        registryFacet = new RegistryFacet();
        diamondInit = new DiamondInit();

        // ------- ADMIN FACET SELECTORS -----------
        bytes4[] memory adminFacetFunctionSelectors = new bytes4[](3);
        adminFacetFunctionSelectors[0] = adminFacet.setNewGovernor.selector;
        adminFacetFunctionSelectors[1] = adminFacet.governor.selector;
        adminFacetFunctionSelectors[2] = adminFacet.addSupportedAsset.selector;

        // ------- REGISTRY FACET SELECTORS -----------
        bytes4[] memory registryFacetFunctionSelectors = new bytes4[](1);
        registryFacetFunctionSelectors[0] = registryFacet.register.selector;

        // ------- CORE FACET SELECTORS -----------
        bytes4[] memory coreFacetFunctionSelectors = new bytes4[](1);
        coreFacetFunctionSelectors[0] = coreFacet.createPool.selector;

        // ------- LENDING FACET SELECTORS -----------
        bytes4[] memory lendingFacetFunctionSelectors = new bytes4[](3);
        lendingFacetFunctionSelectors[0] = lendingFacet.deposit.selector;
        lendingFacetFunctionSelectors[1] = lendingFacet.withdraw.selector;
        lendingFacetFunctionSelectors[2] = lendingFacet.getTotalShares.selector;

        // ------- DIAMOND CUTS --------
        LibDiamond.FacetCut[] memory _diamondCut = new LibDiamond.FacetCut[](4);

        _diamondCut[0] = LibDiamond.FacetCut({
            facetAddress: address(adminFacet),
            action: LibDiamond.FacetCutAction.Add,
            functionSelectors: adminFacetFunctionSelectors
        });

        _diamondCut[1] = LibDiamond.FacetCut({
            facetAddress: address(coreFacet),
            action: LibDiamond.FacetCutAction.Add,
            functionSelectors: coreFacetFunctionSelectors
        });

        _diamondCut[2] = LibDiamond.FacetCut({
            facetAddress: address(lendingFacet),
            action: LibDiamond.FacetCutAction.Add,
            functionSelectors: lendingFacetFunctionSelectors
        });

        _diamondCut[3] = LibDiamond.FacetCut({
            facetAddress: address(registryFacet),
            action: LibDiamond.FacetCutAction.Add,
            functionSelectors: registryFacetFunctionSelectors
        });

        // ------- DIAMOND INIT PARAMS --------
        InitParams memory _initParams = InitParams({initialGovernor: governor});
        stormbit = new DiamondProxy(
            _diamondCut, address(diamondInit), abi.encodeWithSelector(DiamondInit.initialize.selector, _initParams)
        );

        // ------- Aditional Setup --------
        vm.startPrank(governor);
        AdminFacet(address(stormbit)).addSupportedAsset(address(usdtVault));
        vm.stopPrank();
    }
}
