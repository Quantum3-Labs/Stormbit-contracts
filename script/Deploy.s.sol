// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.21;

// import "forge-std/Script.sol";
// import {SimpleAgreement} from "../src/agreements/SimpleAgreement.sol";
// import {IAgreement} from "../src/interfaces/IAgreement.sol";
// import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
// import {MockToken} from "src/mocks/MockToken.sol";
// import {MockNFT} from "src/mocks/MockNFT.sol";

// contract BaseAgreementScript is Script {
//     SimpleAgreement public agreement;
//     MockToken public mockToken;
//     MockNFT public mockNFT;

//     function run() external {
//         uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
//         vm.startBroadcast(deployerPrivateKey);
//         console.log("trying with address", vm.addr(deployerPrivateKey));

//         // Deploy mockToken
//         mockToken = new MockToken();

//         uint256[] memory amounts = new uint256[](2);
//         amounts[0] = 200;
//         amounts[1] = 100;

//         uint256[] memory times = new uint256[](2);
//         times[0] = 2;
//         times[1] = 3;
//         bytes memory initData = abi.encode(
//             1000, // lateFee
//             "0x3",
//             "0x4",
//             address(mockToken), // PaymentToken address
//             amounts,
//             times
//         );

//         // Deploy BaseAgreement proxy
//         address agreementImpl = address(new SimpleAgreement());
//         bytes memory agreementData = abi.encodeWithSelector(IAgreement.initialize.selector, initData);
//         address agreementProxy = address(new ERC1967Proxy(agreementImpl, agreementData));
//         agreement = SimpleAgreement(payable(agreementProxy));

//         vm.stopBroadcast();
//     }
// }
