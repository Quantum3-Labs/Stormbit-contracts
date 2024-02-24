pragma solidity 0.8.21;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IStormBitLendingVotes} from "./interfaces/IStormBitLendingVotes.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

contract StormBitLendingVotes is
    Initializable,
    OwnableUpgradeable,
    ERC20Upgradeable,
    ERC20PermitUpgradeable,
    ERC20VotesUpgradeable
{
    // ---------- OVERRIDES ---------------------------

    constructor() {
        _disableInitializers();
    }

    function initialize(address stormBitLending) external initializer {
        __Ownable_init(stormBitLending);
        __ERC20_init("StormBit", "SBL");
        __ERC20Permit_init("StormBit");
    }

    function _update(address from, address to, uint256 value)
        internal
        virtual
        override(ERC20Upgradeable, ERC20VotesUpgradeable)
    {
        super._update(from, to, value);
    }

    function nonces(address owner) public view override(NoncesUpgradeable, ERC20PermitUpgradeable) returns (uint256) {
        return super.nonces(owner);
    }

    function delegate(address from, address to) external onlyOwner {
        _delegate(from, to);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function clock() public view override returns (uint48) {
        return SafeCast.toUint48(block.timestamp);
    }

    function CLOCK_MODE() public view virtual override returns (string memory) {
        return "mode=blocktimestamp&from=default";
    }
}
