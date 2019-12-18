pragma solidity ^0.5.11;

import "ds-auth/auth.sol";
import "ds-token/token.sol";


/**
 * @title DPT token burner
 * @dev The place where DPT are stored before being burned
 */
contract Burner is DSAuth {
    DSToken public token;
    bytes32 public name = "Burner";
    bytes32 public symbol = "Burner";

    constructor(DSToken token_) public {
        token = token_;
    }

    /**
    * @dev Burn sertain amount of token.
    * @param amount_ uint256 amount to be burnt.
    */
    function burn(uint amount_) public auth {
        token.burn(amount_);
    }

    /**
    * @dev Burn all tokens.
    */
    function burnAll() public auth {
        uint totalAmount = token.balanceOf(address(this));
        burn(totalAmount);
    }
}
