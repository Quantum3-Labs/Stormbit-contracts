pragma solidity ^0.8.21;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/IAgreement.sol";

abstract contract AgreementBedrock is IAgreement, Initializable {
    uint256 public _lateFee;
    address public _paymentToken;
    address public _deployer;
    uint256 public _paymentCount;
    bool public _hasPenalty;

    uint256[] public _amounts;
    uint256[] public _times;

    constructor() {
        _disableInitializers();
    }

    function initialize(bytes memory initData) external override initializer {
        (_lateFee, _paymentToken) = abi.decode(initData, (uint256, address));
        _deployer = msg.sender;
       
    }

    function encodeInitdata(uint256 lateFee, address paymentToken)
        public
        pure
        returns (bytes memory)
    {
        return abi.encode(lateFee, paymentToken);
    }

    function decodeInitdata(bytes memory data)
        public
        pure
        returns (uint256, address)
    {
        return abi.decode(data, (uint256, address));
    }

    function lateFee() public view virtual override returns (uint256) {
        return _lateFee;
    }

    function paymentToken() public view virtual override returns (address) {
        return _paymentToken;
    }

    function nextPayment() public view virtual override returns (uint256, uint256) {
        return (_amounts[_paymentCount], _times[_paymentCount]);
    }

    function pay(uint256 amount) public virtual override returns (bool);

    function beforeLoan(bytes memory) external virtual override returns (bool);

    function afterLoan(bytes memory) external virtual override returns (bool);

    function withdraw() external virtual override;

    function getPaymentDates() public view virtual override returns (uint256[] memory, uint256[] memory) {
        return (_amounts, _times);
    }

    function penalty() public view virtual override returns (bool, uint256);
}
