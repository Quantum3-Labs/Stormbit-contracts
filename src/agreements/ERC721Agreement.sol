pragma solidity ^0.8.21;

import "../AgreementBedrock.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract ERC721Agreement is AgreementBedrock, IERC721Receiver {
    ERC721 public _nft;
    mapping(address => mapping(uint256 => bool)) public stakedNFT;
    mapping(address => uint256) public nftId;

    function initialize(bytes memory initData) public override initializer {
        (
            uint256 lateFee,
            address borrower,
            address PaymentToken,
            uint256[] memory amounts,
            uint256[] memory times,
            address nft
        ) = abi.decode(initData, (uint256, address, address, uint256[], uint256[], address));
        _lateFee = lateFee;
        _lender = msg.sender; // lender deploys this, aka lending pool
        _borrower = borrower;
        _paymentToken = PaymentToken;
        _amounts = amounts;
        _times = times;
        _nft = ERC721(nft);
    }

    function lateFee() public view override returns (uint256) {
        return _lateFee;
    }

    function paymentToken() public view override returns (address) {
        return _paymentToken;
    }

    function lender() public view override returns (address) {
        return _lender;
    }

    function borrower() public view override returns (address) {
        return _borrower;
    }

    function nextPayment() public view override returns (uint256, uint256) {
        return (_amounts[_paymentCount], _times[_paymentCount]);
    }

    function getPaymentDates() public view override returns (uint256[] memory, uint256[] memory) {
        return (_amounts, _times);
    }

    function totalLoanAmount() public view override returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < _amounts.length; ++i) {
            total += _amounts[i];
        }
        return total;
    }

    function isLoanFinished() public view override returns (bool) {
        return _paymentCount == _amounts.length;
    }

    function withdraw() external override onlyBorrower {
        require(_paymentCount == 0, "Withdrawal can only occur before repayments");
        _beforeLoan();
        IERC20(_paymentToken).transfer(_borrower, IERC20(_paymentToken).balanceOf(address(this)));
    }

    function _beforeLoan() internal override {
        require(_nft.balanceOf(address(this)) > 0, "NFT not minted to borrower");
    }

    /**
     * @dev Transfer NFT back to borrower
     */
    function _afterLoan() internal override onlyBorrower {
        require(isLoanFinished(), "Loan must be finished");
        _nft.safeTransferFrom(address(this), _borrower, nftId[_borrower]);
    }

    /**
     * @dev Contract should be able to receive NFT
     */
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        override
        returns (bytes4)
    {
        require(from == _borrower, "NFT: Sender must be borrower");
        stakedNFT[msg.sender][tokenId] = true;
        nftId[_borrower] = tokenId;
        return this.onERC721Received.selector;
    }
}
