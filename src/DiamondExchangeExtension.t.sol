pragma solidity ^0.5.11;

import "./DiamondExchangeSetup.t.sol";

contract DiamondExchangeExtensionTest is DiamondExchangeSetup {

    function testSellerAcceptsTokenDee() public {
        DiamondExchange(exchange).setDenyToken(cdc, true);
        assertTrue(
            !DiamondExchangeExtension(dee).sellerAcceptsToken(cdc, address(this)));
        DiamondExchange(exchange).setDenyToken(cdc, false);
        assertTrue(
            DiamondExchangeExtension(dee).sellerAcceptsToken(cdc, address(this)));
    }

    function testGetDiamondInfoDee() public {
        address[2] memory ownerCustodian;
        bytes32[6] memory attrs;
        uint24 carat;
        uint price;
        (ownerCustodian, attrs, carat, price) = DiamondExchangeExtension(dee).getDiamondInfo(dpass, dpassId[user]);

        assertEq(ownerCustodian[0], user);
        assertEq(ownerCustodian[1], seller);
        assertEq(attrs[0], "gia");
        assertEq(attrs[1], "2141438167");
        assertEq(attrs[2], "sale");
        assertEq(attrs[3], "BR,IF,F,0.01");
        assertEq(attrs[4], bytes32(uint(0xc0a5d062e13f99c8f70d19dc7993c2f34020a7031c17f29ce2550315879006d7)));
        assertEq(attrs[5], "20191101");
        assertEq(carat, uint(0.2 * 100));
        assertEq(price, dpassOwnerPrice[user]);

        (ownerCustodian, attrs, carat, price) = DiamondExchangeExtension(dee).getDiamondInfo(dpass, dpassId[seller]);

        assertEq(ownerCustodian[0], asm);
        assertEq(ownerCustodian[1], seller);
        assertEq(attrs[0], "gia");
        assertEq(attrs[1], "2141438168");
        assertEq(attrs[2], "sale");
        assertEq(attrs[3], "BR,VVS1,F,3.00");
        assertEq(attrs[4], bytes32(uint(0xac5c1daab5131326b23d7f3a4b79bba9f236d227338c5b0fb17494defc319886)));
        assertEq(attrs[5], "20191101");
        assertEq(carat, uint(3.1 * 100));
        assertEq(price, dpassOwnerPrice[asm]);
    }
}
