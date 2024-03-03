// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/FunctionsClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/libraries/FunctionsRequest.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract StormBitCreditWizard is FunctionsClient {
    mapping(address => uint256) public finalScore;

    // ---- CHAINLINK ----
    using FunctionsRequest for FunctionsRequest.Request;

    string postRequestSrc;
    uint64 subscriptionId;

    bytes32 public latestRequestId;
    bytes public latestResponse;
    bytes public latestError;

    event OCRResponse(bytes32 indexed requestId, bytes result, bytes err);
    // ---- --------- ----

    uint256 distributionCount = 0;

    constructor(address _functionsRouter, uint64 _subscriptionId) FunctionsClient(_functionsRouter) {
        subscriptionId = _subscriptionId;
    }

    function setPostRequestSrc(string memory source) public {
        postRequestSrc = source;
    }

    function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
        latestResponse = response;
        latestError = err;
        emit OCRResponse(requestId, response, err);
    }

    function aggregateCreditScore(address borrower, uint256[] memory creditScores) public {
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(postRequestSrc);
        string[] memory args = new string[](2);
        string memory creditScoresString = _arrayToString(creditScores);
        string memory borrowerString = Strings.toHexString(uint256(uint160(borrower)), 20);

        args[0] = creditScoresString;
        args[1] = borrowerString;
        req.setArgs(args);
        latestRequestId = _sendRequest(req.encodeCBOR(), subscriptionId, 0, "");

        for (uint256 i = 0; i < creditScores.length; i++) {
            finalScore[borrower] += creditScores[i] / creditScores.length;
        }
    }

    // Helper function to convert uint256 array to a comma-separated string
    function _arrayToString(uint256[] memory arr) private pure returns (string memory) {
        if (arr.length == 0) {
            return "";
        }
        string memory str = Strings.toString(arr[0]);
        for (uint256 i = 1; i < arr.length; i++) {
            str = string(abi.encodePacked(str, ",", Strings.toString(arr[i])));
        }
        return str;
    }
}
