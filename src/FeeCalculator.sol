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

    function setFee(uint fee_) public auth {
        fee = fee_;
    }
}
// TODO: write tests
