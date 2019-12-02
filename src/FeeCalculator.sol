pragma solidity ^0.5.11;

import "ds-auth/auth.sol";
import "ds-math/math.sol";

contract FeeCalculator is DSMath, DSAuth {
    uint public fee;

    function calculateFee(
        address sender,
        uint256 value,
        address sellToken,
        uint256 sellAmtOrId,
        address buyToken,
        uint256 buyAmtOrId
    ) public view returns (uint256 feeV) {
        // add fee calculations logic here
    }

    /**
    * @dev calculates how much of a certain token user must spend in order to buy certain amount of token with fees
    */
    function getCosts(
        address user,                                                           // user for whom we want to check the costs for 
        address sellToken_,
        uint256 sellId_,
        address buyToken_,
        uint256 buyAmtOrId_
    ) public view returns (uint256 sellAmtOrId_, uint256 feeDpt_) {
        // calculate expected sell amount when user wants to buy something anc only knows how much he wants to buy from a token and whishes to know how much it will cost.
    }

    function setFee(uint fee_) public auth {
        fee = fee_;
    }
}
// TODO: write tests
