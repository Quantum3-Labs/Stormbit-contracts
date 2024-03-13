//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IBase} from "./IBase.sol";

/// @dev Admin interface for Config facet
interface IAdmin is IBase {
    function setNewGovernor(address _newGov) external;

    function addSupportedAsset(address _token) external;

    function removeSupportedAsset(address _token) external;

    function addSupportedAgreement(address _agreement) external;

    function removeSupportedAgreement(address _agreement) external;

    function governor() external view returns (address);
}
