//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IAdmin} from "../interfaces/IAdmin.sol";
import {LibAppStorage, AppStorage} from "../libraries/LibAppStorage.sol";
import {Errors, Events} from "../libraries/Common.sol";
import {Base} from "./Base.sol";

contract AdminFacet is IAdmin, Base {
    string public constant override name = "Admin";

    function setNewGovernor(address _newGov) external override onlyGovernor {
        AppStorage storage s = LibAppStorage.diamondStorage();
        if (_newGov == address(0)) {
            revert Errors.OwnerCannotBeZeroAddress();
        }
        s.governor = _newGov;
        emit Events.NewGovernor(_newGov);
    }

    function addSupportedAsset(address _token) external override onlyGovernor {
        AppStorage storage s = LibAppStorage.diamondStorage();
        s.supportedAssets[_token] = true;

        emit Events.AddSupportedToken(_token);
    }

    function removeSupportedAsset(address _token) external override onlyGovernor {
        AppStorage storage s = LibAppStorage.diamondStorage();
        s.supportedAssets[_token] = false;

        emit Events.RemoveSupportedToken(_token);
    }

    function addSupportedAgreement(address _agreement) external override onlyGovernor {
        AppStorage storage s = LibAppStorage.diamondStorage();
        s.supportedAgreements[_agreement] = true;
        emit Events.AddSuppportedAgreement(_agreement);
    }

    function removeSupportedAgreement(address _agreement) external override {
        AppStorage storage s = LibAppStorage.diamondStorage();
        s.supportedAgreements[_agreement] = false;
        emit Events.RemoveSupportedAgreement(_agreement);
    }

    function governor() external view override returns (address) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.governor;
    }
}
