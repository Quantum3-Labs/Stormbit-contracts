// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {AssetManager} from "../src/AssetManager.sol";
import {LendingManager} from "../src/LendingManager.sol";
import {LoanManager} from "../src/LoanManager.sol";
import {TestUtils} from "./Utils.t.sol";
import {BaseVault} from "../src/vaults/BaseVault.sol";

contract SetupTest is TestUtils {
    ERC20Mock token1;
    ERC20Mock token2;
    ERC20Mock token3;

    AssetManager assetManager;
    LendingManager lendingManager;
    LoanManager loanManager;

    BaseVault vaultToken1;
    BaseVault vaultToken2;
    BaseVault vaultToken3;

    address[] supportedTokens;

    function setUp() public virtual {
        token1 = new ERC20Mock();
        token2 = new ERC20Mock();
        token3 = new ERC20Mock();

        supportedTokens = [address(token1), address(token2), address(token3)];
        assetManager = new AssetManager(governor);
        lendingManager = new LendingManager(governor);
        loanManager = new LoanManager(governor);

        assetManager.initialize(address(loanManager), address(lendingManager));
        lendingManager.initialize(address(assetManager), address(loanManager));
        loanManager.initialize(address(assetManager), address(lendingManager));

        _addSupportedTokens();
        _mintAllTokens();
        _setUpTokenVaults();
    }

    function _addSupportedTokens() private {
        vm.startPrank(governor);
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            assetManager.addToken(supportedTokens[i]);
        }
        vm.stopPrank();
    }

    function _setUpTokenVaults() private {
        vaultToken1 = BaseVault(assetManager.getVaultToken(address(token1)));
        vaultToken2 = BaseVault(assetManager.getVaultToken(address(token2)));
        vaultToken3 = BaseVault(assetManager.getVaultToken(address(token3)));
    }

    function _mintAllTokens() private {
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            ERC20Mock token = ERC20Mock(supportedTokens[i]);
            token.mint(depositor1, initialTokenBalance * (10 ** token.decimals()));
            token.mint(depositor2, initialTokenBalance * (10 ** token.decimals()));
            token.mint(depositor3, initialTokenBalance * (10 ** token.decimals()));
        }
    }

    function _fundVault() internal {
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            vm.startPrank(funder);
            // deposit some token to vault by asset manager
            ERC20Mock token = ERC20Mock(supportedTokens[i]);
            uint256 depositAmount = initialFundBalance * (10 ** token.decimals());
            token.approve(address(assetManager), depositAmount);
            assetManager.deposit(supportedTokens[i], depositAmount);
            vm.stopPrank();
        }
    }
}
