// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.21;

// import "./interfaces/IStormBit.sol";

// // - StormBit Credit Aggregator : contract that will use chainlink functions to aggregate credit score data of users on chain.
// //     - a contract that uses many chainlink functions scripts to aggregate data from different APIs
// //     - this is called when the user submits a loan request. his aggregated credit scored gets stored in the contract and will be used when the loan is approve.

// import  "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/FunctionsClient.sol";
// import "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/libraries/FunctionsRequest.sol";
// import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

// contract CreditAggregatorFunctionsConsumer {

//      // ---- CHAINLINK ----
//     using FunctionsRequest for FunctionsRequest.Request;

//     string postRequestSrc;
//     uint64 subscriptionId;

//     bytes32 public latestRequestId;
//     bytes public latestResponse;
//     bytes public latestError;

//     event OCRResponse(bytes32 indexed requestId, bytes result, bytes err);
//     // ---- --------- ----

//     uint256 distributionCount = 0;

//      constructor(
//         address _functionsRouter,
//         uint64 _subscriptionId
//     ) FunctionsClient(_functionsRouter) {
//         subscriptionId = _subscriptionId;
//     }

//     function setPostRequestSrc(string memory source) public {
//         postRequestSrc = source;
//     }

//     function fulfillRequest(
//         bytes32 requestId,
//         bytes memory response,
//         bytes memory err
//     ) internal override {
//         latestResponse = response;
//         latestError = err;
//         emit OCRResponse(requestId, response, err);
//     }

//     function setExternalCreditScore(
//         address memory borrower,
//         uint256 score,
//         uint256 scoreProviderId
//     ) public {
//         FunctionsRequest.Request memory req;
//         req.initializeRequestForInlineJavaScript(postRequestSrc);
//         string[] args = new string[](4);
//         string memory borrowerString = "";

//         args[0] = borrowerString;
//         args[1] = Strings.toString(score);
//         args[2] = Strings.toString(scoreProviderId);
//         args[3] = Strings.toString(distributionCount);

//         req.setArgs(args);
//         latestRequestId = _sendRequest(
//             req.encodeCBOR(),
//             subscriptionId,
//             200_000,
//             "avalanche_v1"
//         );
//         distributionCount++;
//     }

// }
