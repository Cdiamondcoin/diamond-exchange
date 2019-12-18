pragma solidity ^0.5.11;

import "ds-token/token.sol";


/**
 * @title Dcdc token
 * @dev This token represents diamonds assets of diamonds whose cut, clarity, color, and carat (and quality) is exactly the
 * same, and have no id's that would differentiate them. This is useful as custodians can mint a lot of diamonds in 
 * one transaction for small amount of gas.
 */
contract Dcdc is DSToken {

    bytes32 public cccc;
    bool public stopTransfers = true;
    bool public isInteger;
    bytes32 public name;

    /**
    * @dev Constructor.
    * @param cccc_ bytes32 cut, clarity, color, and carat of diamonds that are represented with this token
    * @param symbol_ bytes32 name of token
    * @param isInteger_ bool if true only integer amounts can be printed and transfered.
    */
    constructor(bytes32 cccc_, bytes32 symbol_, bool isInteger_) DSToken(symbol_) public {
        cccc = cccc_;
        isInteger = isInteger_;
        name = symbol_;
    }

    modifier integerOnly(uint256 num) {
        if(isInteger)
            require(num % 10 ** decimals == 0, "dcdc-only-integer-value-allowed");
        _;
    }

    /**
    * @dev Get cut, clarity, color, and carat of this token.
    */
    function getDiamondType() public view returns (bytes32) {
        return cccc;
    }

    /**
    * @dev send token or ether to destination
    */
    function transferFrom(address src, address dst, uint wad)
    public
    stoppable
    integerOnly(wad)
    returns (bool) {
        if(!stopTransfers) {
            return super.transferFrom(src, dst, wad);
        }
    }

    /**
    * @dev Disables/enables transfering tokens.
    */
    function setStopTransfers(bool stopTransfers_) public auth {
        stopTransfers = stopTransfers_;
    }

    /**
    * @dev Mint (integer amount of) diamonds.
    */
    function mint(address guy, uint256 wad) public integerOnly(wad) {
        super.mint(guy, wad);
    }

    /**
    * @dev Burn (integer amount of) diamonds.
    */
    function burn(address guy, uint256 wad) public integerOnly(wad) {
        super.burn(guy, wad);
    }
}
