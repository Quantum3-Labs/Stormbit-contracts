pragma solidity ^0.8.21;

import "../AgreementBase.sol";
import "../interfaces/IStormBitLending.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract NFTAgreement is AgreementBase {
    mapping(address => NFTAggreement) public nftAgreements;
    mapping(address => bool) public hasNFTLocked;
    address borrower;
    mapping(address => uint256) public borrowerAllocation;

    struct NFTAggreement {
        address nftContract; // contract of the nft to transfer
        uint256[] paymentDeadlines;
        uint256[] paymentAmounts;
        uint256 borrowedAmount;
        uint256 penalty; // increments by timestamp, late payers.
    }

    function paymentToken() public view override returns (address) {
        return _paymentToken;
    }

    function beforeLoan(bytes memory) external override returns (bool) {}

    function afterLoan(bytes memory) external override returns (bool) {}

    function withdraw(uint256 amount) public {
        payable(msg.sender).transfer(amount);
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

    function _withdraw() internal {
        IERC20(_paymentToken).transfer(borrower, borrowerAllocation[msg.sender]);
    }

    // You have to lock the NFT to submit a request for a loan.
    function lockNFT(uint256 tokenId) public {
        require(!hasNFTLocked[msg.sender], "NFT already locked");
        IERC721(_paymentToken).safeTransferFrom(msg.sender, address(this), tokenId); // transfer NFT to this contract
        (bool succes,) = address(this).call(
            abi.encodeWithSignature(
                "onERC721Received(address,address,uint256,bytes)", msg.sender, address(this), tokenId, ""
            )
        );
    }

    function sendRequest(uint256 loanAmount, address token, bytes calldata agreementCalldata) internal {
        require(hasNFTLocked[msg.sender], "NFTAgreement: NFT not locked");
        // request loan
        IStormBitLending.LoanRequestParams memory params = IStormBitLending.LoanRequestParams({
            amount: loanAmount,
            token: token,
            agreement: address(this), // @note - this contract is the strategy used
            agreementCalldata: agreementCalldata
        });
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        returns (bytes4)
    {
        return this.onERC721Received.selector;
    }

    receive() external payable {}
}
