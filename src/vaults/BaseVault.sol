//SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BaseVault is ERC4626 {
    error OnlyGovernor();

    address public governor;

    constructor(IERC20 _token, address _governor, string memory _name, string memory _symbol)
        ERC4626(_token)
        ERC20(_name, _symbol)
    {
        governor = _governor;
    }

    modifier onlyGovernor() {
        if (msg.sender != governor) revert OnlyGovernor();
        _;
    }

    function depositToStrategy() external onlyGovernor {
        // some logic
    }

    function withdrawFromStrategy() external onlyGovernor {
        // some logic
    }
}
