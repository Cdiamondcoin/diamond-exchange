pragma solidity ^0.5.11;
import "./DiamondExchangeSetup.t.sol";

contract RedeemerTest is DiamondExchangeSetup {

    uint walDaiBalance;
    uint walEthBalance;
    uint liqDptBalance;
    uint burnerDptBalance;
    uint userCdcBalance;
    uint userDaiBalance;
    uint userEthBalance;

    function testRedeemCdcRed() public {
        uint daiRedeem = 61 ether;
        uint daiPaid = 101 ether;
        uint mintDcdc = 997 ether;
        DiamondExchangeTester(custodian).doMintDcdc(asm, dcdc, custodian, mintDcdc);
        DiamondExchangeTester(user).doBuyTokensWithFee(
            dai,
            daiPaid,
            cdc,
            uint(-1)
        );

        walDaiBalance = DSToken(dai).balanceOf(wal);
        liqDptBalance = DSToken(dpt).balanceOf(liq);
        burnerDptBalance = DSToken(dpt).balanceOf(burner);
        userCdcBalance = DSToken(cdc).balanceOf(user);
        userDaiBalance = DSToken(dai).balanceOf(user);

        DiamondExchangeTester(user).doRedeem(
            cdc,
            uint(DSToken(cdc).balanceOf(user) / 10 ** 18 * 10 ** 18),
            dai,
            daiRedeem,
            custodian
        );

        assertEqLog(
            "user-dai-balance",
            DSToken(dai).balanceOf(user),
            userDaiBalance - daiRedeem);

        uint daiFee = wdivT(
            wmul(varFeeRedeem, wmulV(uint(userCdcBalance / 10 ** 18 * 10 ** 18), usdRate[cdc], cdc)) + fixFeeRedeem,
            usdRate[dai],
            dai);

        assertEqLog(
            "wal-dai-balance",
            DSToken(dai).balanceOf(wal),
            walDaiBalance + daiFee);

        uint dptFee = takeProfitOnlyInDpt ? wdivT(
            wmul(wmulV(daiFee, usdRate[dai], dai), profitRateRedeem),
                usdRate[dpt],
                dpt):
            wdivT(
                wmulV(daiFee, usdRate[dai], dai), 
                usdRate[dpt],
                dpt);

        assertEqDustLog(
            "liq-dpt-balance",
            DSToken(dpt).balanceOf(liq),
            liqDptBalance - dptFee);

        assertEqDustLog(
            "burner-dpt-balance",
            DSToken(dpt).balanceOf(burner),
            burnerDptBalance + dptFee);

        assertEqDustLog(
            "user-cdc-balance",
            DSToken(cdc).balanceOf(user),
            userCdcBalance - uint(userCdcBalance / 10 ** 18 * 10 ** 18));
    }

    function testRedeemCdcUsingEthRed() public {
        DiamondExchange(exchange).setConfig("redeemFeeToken", b(eth), b(true));
        uint ethRedeem = 61 ether;
        uint ethPaid = 101 ether;
        uint mintDcdc = 997 ether;
        DiamondExchangeTester(custodian).doMintDcdc(asm, dcdc, custodian, mintDcdc);
        DiamondExchangeTester(user).doBuyTokensWithFee(
            eth,
            ethPaid,
            cdc,
            uint(-1)
        );

        walEthBalance = wal.balance;
        liqDptBalance = DSToken(dpt).balanceOf(liq);
        burnerDptBalance = DSToken(dpt).balanceOf(burner);
        userCdcBalance = DSToken(cdc).balanceOf(user);
        userEthBalance = user.balance;

        DiamondExchangeTester(user).doRedeem(
            cdc,
            uint(DSToken(cdc).balanceOf(user) / 10 ** 18 * 10 ** 18),
            eth,
            ethRedeem,
            custodian
        );

        assertEqLog(
            "user-eth-balance",
            user.balance,
            userEthBalance - ethRedeem);

        uint ethFee = wdivT(
                wmul(varFeeRedeem, wmulV(userCdcBalance / 10 ** 18 * 10 ** 18, usdRate[cdc], cdc)) + fixFeeRedeem,
                usdRate[eth],
                eth);

        assertEqDustLog(
            "wal-eth-balance",
            wal.balance,
            walEthBalance + ethFee);

        uint dptFee = takeProfitOnlyInDpt ? wdivT(
            wmul(wmulV(ethFee, usdRate[eth], eth), profitRateRedeem),
                usdRate[dpt],
                dpt):
            wdivT(
                wmulV(ethFee, usdRate[eth], eth), 
                usdRate[dpt],
                dpt);

        assertEqDustLog(
            "liq-dpt-balance",
            DSToken(dpt).balanceOf(liq),
            liqDptBalance - dptFee);

        assertEqDustLog(
            "burner-dpt-balance",
            DSToken(dpt).balanceOf(burner),
            burnerDptBalance + dptFee);

        assertEqDustLog(
            "user-cdc-balance",
            DSToken(cdc).balanceOf(user),
            userCdcBalance - uint(userCdcBalance / 10 ** 18 * 10 ** 18));
    }

    function testRedeemDpassRed() public {
        
        uint daiRedeem = 11 ether;
        address sellToken = eth;
        uint sellAmtOrId = 16.5 ether;

        DiamondExchange(exchange)
            .buyTokensWithFee
            .value(sellAmtOrId)
            (sellToken, sellAmtOrId, dpass, dpassId[seller]);

        approve721(dpass, exchange, dpassId[seller]);        

        walDaiBalance = DSToken(dai).balanceOf(wal);
        liqDptBalance = DSToken(dpt).balanceOf(liq);
        burnerDptBalance = DSToken(dpt).balanceOf(burner);
        userCdcBalance = DSToken(cdc).balanceOf(address(this));
        userDaiBalance = DSToken(dai).balanceOf(address(this));

        uint redeemId = DiamondExchange(exchange).redeem(
            dpass,
            dpassId[seller],
            dai,
            daiRedeem,
            seller
        );

        assertEq(
            Dpass(dpass).getState(dpassId[seller]),
            b("redeemed"));

        assertEqLog(
            "redeem-id-1",
            redeemId,
            1);

        assertEqDustLog(
            "user-dai-balance",
            DSToken(dai).balanceOf(address(this)),
            userDaiBalance - daiRedeem);

        uint daiFee = wdivT(
                wmul(varFeeRedeem, dpassOwnerPrice[asm]) + fixFeeRedeem,
                usdRate[dai],
                dai);

        assertEqDustLog(
            "wal-dai-balance",
            DSToken(dai).balanceOf(wal),
            walDaiBalance + daiFee);

        uint dptFee = takeProfitOnlyInDpt ? wdivT(
            wmul(wmulV(daiFee, usdRate[dai], dai), profitRateRedeem),
                usdRate[dpt],
                dpt):
            wdivT(
                wmulV(daiFee, usdRate[dai], dai), 
                usdRate[dpt],
                dpt);

        assertEqDustLog(
            "liq-dpt-balance",
            DSToken(dpt).balanceOf(liq),
            liqDptBalance - dptFee);

        assertEqDustLog(
            "burner-dpt-balance",
            DSToken(dpt).balanceOf(burner),
            burnerDptBalance + dptFee);

        assertEqDustLog(
            "user-dpass-balance",
            Dpass(dpass).balanceOf(address(this)),
            0);
    }

    function testRedeemDpassUsingEthRed() public {
        DiamondExchange(exchange).setConfig("redeemFeeToken", b(eth), b(true));

        uint ethRedeem = 11 ether;
        address sellToken = eth;
        uint sellAmtOrId = 16.5 ether;

        DiamondExchange(exchange)
            .buyTokensWithFee
            .value(sellAmtOrId)
            (sellToken, sellAmtOrId, dpass, dpassId[seller]);

        approve721(dpass, exchange, dpassId[seller]);        

        walEthBalance = wal.balance;
        liqDptBalance = DSToken(dpt).balanceOf(liq);
        burnerDptBalance = DSToken(dpt).balanceOf(burner);
        userCdcBalance = DSToken(cdc).balanceOf(address(this));
        userEthBalance = address(this).balance;

        uint redeemId = DiamondExchange(exchange)
        .redeem
        .value(ethRedeem)
        (
            dpass,
            dpassId[seller],
            eth,
            ethRedeem,
            seller
        );

        assertEq(
            Dpass(dpass).getState(dpassId[seller]),
            b("redeemed"));

        assertEqLog(
            "redeem-id-1",
            redeemId,
            1);

        assertEqDustLog(
            "user-eth-balance",
            address(this).balance,
            userEthBalance - ethRedeem);

        uint ethFee = wdivT(
                wmul(varFeeRedeem, dpassOwnerPrice[asm]) + fixFeeRedeem,
                usdRate[eth],
                eth);

        assertEqDustLog(
            "wal-eth-balance",
            wal.balance,
            walEthBalance + ethFee);

        uint dptFee = takeProfitOnlyInDpt ? wdivT(
            wmul(wmulV(ethFee, usdRate[eth], eth), profitRateRedeem),
                usdRate[dpt],
                dpt):
            wdivT(
                wmulV(ethFee, usdRate[eth], eth), 
                usdRate[dpt],
                dpt);

        assertEqDustLog(
            "liq-dpt-balance",
            DSToken(dpt).balanceOf(liq),
            liqDptBalance - dptFee);

        assertEqDustLog(
            "burner-dpt-balance",
            DSToken(dpt).balanceOf(burner),
            burnerDptBalance + dptFee);

        assertEqDustLog(
            "user-dpass-balance",
            Dpass(dpass).balanceOf(address(this)),
            0);
    }

    function testFailRedeemDpassUsingEthReimburseExcessEthRed() public {
        DiamondExchange(exchange).setConfig("redeemFeeToken", b(eth), b(true));

        uint origEthRedeem = 12 ether;
        uint ethRedeem = 11 ether;
        require(origEthRedeem > ethRedeem, "test-red-orig-should-gt-curr");
        address sellToken = eth;
        uint sellAmtOrId = 16.5 ether;

        DiamondExchange(exchange)
            .buyTokensWithFee
            .value(sellAmtOrId)
            (sellToken, sellAmtOrId, dpass, dpassId[seller]);

        approve721(dpass, exchange, dpassId[seller]);        

        walEthBalance = wal.balance;
        liqDptBalance = DSToken(dpt).balanceOf(liq);
        burnerDptBalance = DSToken(dpt).balanceOf(burner);
        userCdcBalance = DSToken(cdc).balanceOf(address(this));
        userEthBalance = address(this).balance;

        DiamondExchange(exchange)
        .redeem
        .value(ethRedeem)
        (
            dpass,
            dpassId[seller],
            eth,
            origEthRedeem,
            seller
        );
    }

    function testRedeemDpassDptCostRed() public {
        uint sendDpt = 300 ether;
        forFixDaiBuyDpassUserHasNoDpt();
        DSToken(dpt).transfer(user, sendDpt);

        DiamondExchangeTester(user).doApprove721(dpass, exchange, dpassId[seller]);

        uint userDptBalance = DSToken(dpt).balanceOf(user);
        uint walDptBalance = DSToken(dpt).balanceOf(wal);
        liqDptBalance =  DSToken(dpt).balanceOf(liq);
        burnerDptBalance = DSToken(dpt).balanceOf(burner);
        DiamondExchangeTester(user).doRedeem(
            dpass,
            dpassId[seller],
            dpt,
            sendDpt,
            seller);

        assertEqLog("owner-of-dpas-is-redeem",
                    Dpass(dpass).ownerOf(dpassId[seller]),
                    red);

        assertEqDustLog("user-balance-decreased", 
                    DSToken(dpt).balanceOf(user),
                    userDptBalance - sendDpt);

        assertEqDustLog("wal-balance-increased", 
                    DSToken(dpt).balanceOf(wal),
                    walDptBalance + wdivT(fixFeeRedeem + wmul(varFeeRedeem, dpassOwnerPrice[asm]), usdRate[dpt], dpt) - 
                    wdivT(wmul(fixFeeRedeem + wmul(varFeeRedeem, dpassOwnerPrice[asm]), profitRateRedeem), usdRate[dpt], dpt));

        assertEqDustLog("liq-balance-decreased", 
                    DSToken(dpt).balanceOf(liq),
                    liqDptBalance );

        assertEqDustLog("burner-balance-increased", 
                    DSToken(dpt).balanceOf(burner),
                    burnerDptBalance + wdivT(wmul(fixFeeRedeem + wmul(varFeeRedeem, dpassOwnerPrice[asm]), profitRateRedeem), usdRate[dpt], dpt));
    }

    function testRedeemDpassDaiCostRed() public {
        uint sendDai = 300 ether;
        forFixDaiBuyDpassUserHasNoDpt();     // get dpass for user

        DiamondExchangeTester(user).doApprove721(dpass, exchange, dpassId[seller]);

        userDaiBalance = DSToken(dai).balanceOf(user);
        walDaiBalance = DSToken(dai).balanceOf(wal);
        liqDptBalance =  DSToken(dpt).balanceOf(liq);
        burnerDptBalance = DSToken(dpt).balanceOf(burner);
        DiamondExchangeTester(user).doRedeem(
            dpass,
            dpassId[seller],
            dai,
            sendDai,
            seller);

        assertEqLog("owner-of-dpas-is-redeem",
                    Dpass(dpass).ownerOf(dpassId[seller]),
                    red);

        assertEqDustLog("user-balance-decreased", 
                    DSToken(dai).balanceOf(user),
                    userDaiBalance - sendDai);

        assertEqDustLog("wal-balance-increased", 
                    DSToken(dai).balanceOf(wal),
                    walDaiBalance + wdivT(fixFeeRedeem + wmul(varFeeRedeem, dpassOwnerPrice[asm]), usdRate[dai], dai));

        assertEqDustLog("liq-balance-decreased", 
                    DSToken(dpt).balanceOf(liq),
                    liqDptBalance - wdivT(wmul(fixFeeRedeem + wmul(varFeeRedeem, dpassOwnerPrice[asm]), profitRateRedeem), usdRate[dpt], dpt));

        assertEqDustLog("burner-balance-increased", 
                    DSToken(dpt).balanceOf(burner),
                    burnerDptBalance + wdivT(wmul(fixFeeRedeem + wmul(varFeeRedeem, dpassOwnerPrice[asm]), profitRateRedeem), usdRate[dpt], dpt));
    }

    function testFailRedeemCdcDptCostRed() public {
        //  error Revert ("red-cdc-integer-value-pls") 
        uint sendDpt = 300 ether;
        forFixDaiBuyFixCdcUserHasNoDpt();
        DSToken(dpt).transfer(user, sendDpt);

        DiamondExchangeTester(user).doRedeem(
            cdc,
            17.1 ether,
            dpt,
            sendDpt,
            custodian);
    }

    function testRedeemCdcDaiCostRed() public {
        uint sendDai = 300 ether;
        forFixDaiBuyFixCdcUserHasNoDpt();     // get dpass for user


        userDaiBalance = DSToken(dai).balanceOf(user);
        walDaiBalance = DSToken(dai).balanceOf(wal);
        userCdcBalance = DSToken(cdc).balanceOf(user);
        liqDptBalance =  DSToken(dpt).balanceOf(liq);
        burnerDptBalance = DSToken(dpt).balanceOf(burner);
        DiamondExchangeTester(user).doRedeem(
            cdc,
            17 ether,
            dai,
            sendDai,
            custodian);

        assertEqDustLog("user-cdc-balance-decreased",
                    DSToken(cdc).balanceOf(user),
                    userCdcBalance - 17 ether);

        assertEqDustLog("user-balance-decreased", 
                    DSToken(dai).balanceOf(user),
                    userDaiBalance - sendDai);

        assertEqDustLog("wal-balance-increased", 
                    DSToken(dai).balanceOf(wal),
                    walDaiBalance + wdivT(fixFeeRedeem + wmul(varFeeRedeem, wmul(usdRate[cdc], 17 ether)), usdRate[dai], dai));

        assertEqDustLog("liq-balance-decreased", 
                    DSToken(dpt).balanceOf(liq),
                    liqDptBalance - wdivT(wmul(fixFeeRedeem + wmul(varFeeRedeem, wmul(usdRate[cdc], 17 ether)), profitRateRedeem), usdRate[dpt], dpt));

        assertEqDustLog("burner-balance-increased", 
                    DSToken(dpt).balanceOf(burner),
                    burnerDptBalance + wdivT(wmul(fixFeeRedeem + wmul(varFeeRedeem, wmul(usdRate[cdc], 17 ether)), profitRateRedeem), usdRate[dpt], dpt));
    }

    function testKycRed() public {
        Redeemer(red).setKyc(user, true);
        Redeemer(red).setConfig("kycEnabled", b(true), "", "");
        testRedeemCdcDaiCostRed();
    }

    function testFailKycRed() public {
        // error Revert ("dex-you-are-not-on-kyc-list")
        Redeemer(red).setKyc(user, false);
        Redeemer(red).setConfig("kycEnabled", b(true), "", "");
        testRedeemCdcDaiCostRed();
    }

    function testGetRedeemCostsCdcRed() public {
        address redeemToken_ = cdc;
        uint redeemAmtOrId_ = 2 ether;
        address feeToken_ = eth;
        uint cost = Redeemer(red).getRedeemCosts(redeemToken_, redeemAmtOrId_, feeToken_);

        assertEqDustLog(
            "user-redeem-cost",
            cost,
            wdivT(
                add(wmul(wmulV(redeemAmtOrId_, usdRate[redeemToken_], redeemToken_), varFeeRedeem), fixFeeRedeem),
                usdRate[feeToken_],
                feeToken_)
        );
    }

    function testFailGetRedeemCostsCdcNotIntegerRed() public {
        // error Revert ("red-cdc-integer-value-pls")
        address redeemToken_ = cdc;
        uint redeemAmtOrId_ = 2.1 ether;
        address feeToken_ = eth;
        uint cost = Redeemer(red).getRedeemCosts(redeemToken_, redeemAmtOrId_, feeToken_);

        assertEqDustLog(
            "user-redeem-cost",
            cost,
            wdivT(
                add(wmul(wmulV(redeemAmtOrId_, usdRate[redeemToken_], redeemToken_), varFeeRedeem), fixFeeRedeem),
                usdRate[feeToken_],
                feeToken_)
        );
    }

    function testGetRedeemCostsDpassRed() public {
        forFixDaiBuyDpassUserHasNoDpt();     // get dpass for user. id = dpassId[seller], price = dpassOwnerPrice[asm]

        address feeToken_ = eth;
        uint cost = Redeemer(red).getRedeemCosts(dpass, dpassId[seller], feeToken_);

        assertEqDustLog(
            "user-redeem-cost",
            cost,
            wdivT(
                add(wmul(dpassOwnerPrice[asm], varFeeRedeem), fixFeeRedeem),
                usdRate[feeToken_],
                feeToken_)
        );
    }
//-------------------------------end-of-tests----------------------

    function forFixDaiBuyDpassUserHasNoDpt() public {

        userDpt = 0 ether;              // DO NOT CHANGE THIS
        sendToken(dpt, user, userDpt);  // DO NOT CHANGE THIS

        address sellToken = dai;
        uint sellAmtOrId = 13.94 ether;// the minimum value user has to pay // DO NOT CHANGE THIS

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function forFixDaiBuyFixCdcUserHasNoDpt() public {
        userDpt = 0 ether;              // DO NOT CHANGE THIS
        sendToken(dpt, user, userDpt);

        address sellToken = dai;        // DO NOT CHANGE THIS
        uint sellAmtOrId = 17 ether;    // DO NOT CHANGE THIS
        address buyToken = cdc;         // DO NOT CHANGE THIS
        uint buyAmtOrId = 17.79 ether;  // DO NOT CHANGE THIS

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);

    }
}
