// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Script} from "forge-std/Script.sol";
import {MockToken} from "src/mocks/MockToken.sol";
import {AssetManager} from "../src/AssetManager.sol";
import {LendingManager} from "../src/LendingManager.sol";
import {LoanManager} from "../src/LoanManager.sol";
import {DeployHelpers} from "script/DeployHelpers.s.sol";
import {StormbitRegistry} from "src/StormbitRegistry.sol";

contract Deploy is DeployHelpers {
    function run() public {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        address deployer = vm.addr(pk);

        // deploy registry
        StormbitRegistry registry = new StormbitRegistry(deployer);

        // TODO add checks when on anvil or testnet should be diff to mainnet
        MockToken mockUsdt = new MockToken("USD Tether", "USDT");
        MockToken mockDai = new MockToken("Dai Stablecoin", "DAI");
        MockToken mockUsdc = new MockToken("USD Coin ", "USDC");

        AssetManager assetManager = new AssetManager(deployer);
        LendingManager lendingManager = new LendingManager(deployer);
        LoanManager loanManager = new LoanManager(deployer);

        assetManager.initialize(address(loanManager), address(lendingManager));
        lendingManager.initialize(address(assetManager), address(loanManager));
        loanManager.initialize(address(assetManager), address(lendingManager));

        // add supported tokens
        assetManager.addToken(address(mockUsdt));
        assetManager.addToken(address(mockDai));
        assetManager.addToken(address(mockUsdc));

        deployments.push(Deployment("StormbitRegistry", address(registry)));
        deployments.push(Deployment("AssetManager", address(assetManager)));
        deployments.push(Deployment("LendingManager", address(lendingManager)));
        deployments.push(Deployment("LoanManager", address(loanManager)));
        deployments.push(Deployment("MockUsdt", address(mockUsdt)));
        deployments.push(Deployment("MockDai", address(mockDai)));
        deployments.push(Deployment("MockUsdc", address(mockUsdc)));

        vm.stopBroadcast();
        exportDeployments();
    }
}
