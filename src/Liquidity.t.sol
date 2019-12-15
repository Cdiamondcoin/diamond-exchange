pragma solidity ^0.5.11;

import "ds-test/test.sol";
import "ds-token/token.sol";
import "./Liquidity.sol";
import "./Burner.sol";

contract TokenUser {
    DSToken token;

    constructor(DSToken token_) public {
        token = token_;
    }
}

contract LiquidityTest is DSTest {
    uint constant initialBalance = 1000;

    DSToken token;
    Liquidity liq;
    address self;
    Burner burner;

    function setUp() public {
        token = new DSToken("DPT");
        token.mint(initialBalance);
        liq = new Liquidity();
        burner = new Burner(token);
        token.setOwner(address(liq));
        self = address(this);
    }

    function testBalanceDecreasesLiquidity() public {
        uint sentAmount = 250;
        token.transfer(address(liq), sentAmount);
        liq.burn(address(token), address(burner), sentAmount);
        assertEq(token.balanceOf(address(liq)), uint(0 ether) );
    }

    function testBurnerBalanceIncreasesLiquidity() public {
        uint sentAmount = 250;
        token.transfer(address(liq), sentAmount);
        liq.burn(address(token), address(burner), sentAmount);
        assertEq(token.balanceOf(address(uint160(address(burner)))), sentAmount);
    }
}
