pragma solidity ^0.5.11;

import "ds-test/test.sol";
import "ds-token/token.sol";
import "./FeeCalculator.sol";

contract FeeCalculatorTest is DSTest {

    FeeCalculator public fca;

    function setUp() public {
        fca = new FeeCalculator();
    }

    function testPresenceOfCalculateFee() public view {
        fca.calculateFee(address(0), 0, address(0), 0, address(0), 0);
    }

    function testPresenceOfgetCosts() public view {
        fca.getCosts(address(0), address(0), 0, address(0), 0);
    }
}
