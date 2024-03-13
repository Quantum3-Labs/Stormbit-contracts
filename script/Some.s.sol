pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";

import {IAdmin} from "../src/interfaces/IAdmin.sol";
import {BaseVault} from "../src/vaults/BaseVault.sol";
import {MockToken} from "../src/mocks/MockToken.sol";
import {ILending} from "../src/interfaces/ILending.sol";
import {IRegistry} from "../src/interfaces/IRegistry.sol";

contract SomeScript is Script {
    address public stormbit = 0x29c3Ebf46731c08fD4481110b06Ae41b7A52A85A;
    uint256 public poolId = 1;
    MockToken usdt = MockToken(0xA63184B6e04EF4f9D516feaF6Df65dF602B07a13);
    BaseVault usdtVault = BaseVault(0xf0A206DCAF5668Fa5C824A01a2039D4cf07b771c);

    function run() public {
        uint256 pk = vm.envUint("PRIVATE_KEY_2");
        address staker = vm.addr(pk);
        vm.startBroadcast(pk);
        IRegistry(stormbit).register("staker");
        usdt.mint(staker, 1000 * 10 ** 18);
        usdt.approve(address(usdtVault), 100 * 10 ** 18);
        usdtVault.deposit(100 * 10 ** 18, staker);
        usdtVault.approve(address(stormbit), 100 * 10 ** 18);
        ILending(stormbit).deposit(poolId, 100 * 10 ** 18, address(usdtVault));
        vm.stopBroadcast;
    }

    function _changeGovernor(address newGovernor) public {
        IAdmin(stormbit).setNewGovernor(newGovernor);
    }
}
