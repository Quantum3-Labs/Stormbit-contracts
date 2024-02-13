pragma solidity ^0.8.21;

import "../StrategyBase.sol";

contract SimpleStrategy is StrategyBase {
    function beforeLoan(bytes memory) external override returns (bool) {
        return true;
    }

    function afterLoan(bytes memory) external override returns (bool) {
        return true;
    }

    function penalty() public view override returns (bool, uint256) {
        (uint256 amount, uint256 time) = nextPayment();
        return (_hasPenalty || time < block.timestamp, _lateFee);
    }

    function pay(uint256 amount) public override returns (bool) {
        (uint256 _amount, uint256 _time) = nextPayment();
        if (_amount == amount && _time < block.timestamp) {
            _hasPenalty = true;
        }
        _paymentCount++;
        return true;
    }
}