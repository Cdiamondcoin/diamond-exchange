pragma solidity ^0.5.11;

import "ds-auth/auth.sol";
import "ds-math/math.sol";

/**
 * @title Fee calculator contract.
 * @dev This contract can be used by Diamond Exchange to calculate fee if fee to enable a flexible fee structure.
 */
contract FeeCalculator is DSMath, DSAuth {
    uint public fee;
    bytes32 public name = "Fca";                       // set human readable name for contract

    /**
    * @dev Calculates how much of a certain token user must spend in order to buy certain amount of token with fees.
    */
    function calculateFee(
        address sender,
        uint256 value,
        address sellToken,
        uint256 sellAmtOrId,
        address buyToken,
        uint256 buyAmtOrId
    ) public pure returns (uint256 feeV) {
        // add fee calculations logic here
        sender;
        value;
        sellToken;
        sellAmtOrId;
        buyToken;
        buyAmtOrId;
        feeV;
    }

    /**
    * @dev Returns how much user must sell of his tokens to buy the desired amount of tokens he wants to buy.
    */
    function getCosts(
        address user_,                                                           // user for whom we want to check the costs for
        address sellToken_,
        uint256 sellId_,
        address buyToken_,
        uint256 buyAmtOrId_
    ) public pure returns (uint256 sellAmtOrId_, uint256 feeDpt_, uint256 feeV_, uint256 feeSellT_) {
        user_;
        sellToken_;
        sellId_;
        buyToken_;
        buyAmtOrId_;
        sellAmtOrId_;
        feeDpt_;
        feeV_;
        feeSellT_;
        // calculate expected sell amount when user wants to buy something and only knows how much he wants to buy from a token and whishes to know how much it will cost.
    }
    
    /**
     * @dev Set fixed fee.
     */
    function setFee(uint fee_) public auth {
        fee = fee_;
    }
}
