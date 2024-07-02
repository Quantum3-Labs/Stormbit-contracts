//SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IAssetManager} from "../interfaces/managers/asset/IAssetManager.sol";

contract BaseVault is ERC4626 {
    error OnlyAssetManager();

    IAssetManager private assetManager;

    constructor(IERC20 _token, address assetManagerAddr, string memory _name, string memory _symbol)
        ERC4626(_token)
        ERC20(_name, _symbol)
    {
        assetManager = IAssetManager(assetManagerAddr);
    }

    modifier onlyAssetManager() {
        if (msg.sender != address(assetManager)) revert OnlyAssetManager();
        _;
    }

    function deposit(uint256 assets, address receiver) public override onlyAssetManager returns (uint256) {
        return super.deposit(assets, receiver);
    }

    function mint(uint256 shares, address receiver) public override onlyAssetManager returns (uint256) {
        return super.mint(shares, receiver);
    }

    function withdraw(uint256 assets, address receiver, address owner)
        public
        override
        onlyAssetManager
        returns (uint256)
    {
        return super.withdraw(assets, receiver, owner);
    }

    function redeem(uint256 shares, address receiver, address owner)
        public
        override
        onlyAssetManager
        returns (uint256)
    {
        return super.redeem(shares, receiver, owner);
    }

    function depositToStrategy() external onlyAssetManager {
        // some logic
    }

    function withdrawFromStrategy() external onlyAssetManager {
        // some logic
    }

    function _decimalsOffset() internal view override returns (uint8) {
        return 8;
    }
}
