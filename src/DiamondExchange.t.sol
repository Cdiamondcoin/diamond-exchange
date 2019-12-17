pragma solidity ^0.5.11;

import "ds-test/test.sol";
import "ds-auth/auth.sol";
import "ds-math/math.sol";
import "ds-token/token.sol";
import "ds-guard/guard.sol";
import "cdc-token/Cdc.sol";
import "dpass/Dpass.sol";
import "./DiamondExchangeExtension.sol";
import "./Burner.sol";
import "./Wallet.sol";
import "./SimpleAssetManagement.sol";
import "./Redeemer.sol";
import "./Dcdc.sol";
import "./DiamondExchangeSetup.t.sol";

contract DiamondExchangeTest is DiamondExchangeSetup {
    // setUp() function you will find in src/DiamondExchangeSetup.t.sol

    function testCalculateFeeDex() public {
        uint valueV = 1 ether;

        uint expectedFeeV = add(fixFee, wmul(varFee, valueV));

        // By default fee should be equal to init value
        assertEq(DiamondExchange(exchange).calculateFee(
            address(this),
            valueV,
            address(0x0),
            0,
            address(0x0),
            0
        ), expectedFeeV);
    }

    function testSetFixFeeDex() public {
        uint fee = 0.1 ether;
        DiamondExchange(exchange).setConfig(b("fixFee"), b(fee), b(""));
        assertEq(DiamondExchange(exchange).calculateFee(
            address(this),
            0 ether,
            address(0x0),
            0,
            address(0x0),
            0
        ), fee);
    }

    function testSetVarFeeDex() public {
        uint fee = 0.5 ether;
        DiamondExchange(exchange).setConfig(b("varFee"), b(fee), b(""));
        assertEq(DiamondExchange(exchange).calculateFee(
            address(this),
            1 ether,
            address(0x0),
            0,
            address(0x0),
            0
        ), fee);
    }

    function testSetVarAndFixFeeDex() public {
        uint value = 1 ether;
        uint varFee1 = 0.5 ether;
        uint fixFee1 = uint(10) / uint(3) * 1 ether;
        DiamondExchange(exchange).setConfig(b("varFee"), b(varFee1), b(""));
        DiamondExchange(exchange).setConfig(b("fixFee"), b(fixFee1), b(""));
        assertEq(DiamondExchange(exchange).calculateFee(
            address(this),
            value,
            address(0x0),
            0,
            address(0x0),
            0
        ), add(fixFee1, wmul(varFee1, value)));
    }

    function testFailNonOwnerSetVarFeeDex() public {
        // error Revert ("ds-auth-unauthorized")
        uint newFee = 0.1 ether;
        DiamondExchangeTester(user).doSetConfig("varFee", newFee, "");
    }

    function testFailNonOwnerSetFixFeeDex() public {
        // error Revert ("ds-auth-unauthorized")
        uint newFee = 0.1 ether;
        DiamondExchangeTester(user).doSetConfig("fixFee", newFee, "");
    }

    function testSetEthPriceFeedDex() public {
        address token = eth;
        uint rate = 1 ether;
        DiamondExchange(exchange).setConfig(b("priceFeed"), b(token), b(feed[dai]));
        TestFeedLike(feed[dai]).setRate(rate);
        assertEq(DiamondExchange(exchange).getRate(token), rate);
    }

    function testSetDptPriceFeedDex() public {
        address token = dpt;
        uint rate = 2 ether;
        DiamondExchange(exchange).setConfig(b("priceFeed"), b(token), b(feed[dai]));
        TestFeedLike(feed[dai]).setRate(rate);
        assertEq(DiamondExchange(exchange).getRate(token), rate);
    }

    function testSetCdcPriceFeedDex() public {
        address token = cdc;
        uint rate = 4 ether;
        DiamondExchange(exchange).setConfig(b("priceFeed"), b(token), b(feed[dai]));
        TestFeedLike(feed[dai]).setRate(rate);
        assertEq(DiamondExchange(exchange).getRate(token), rate);
    }

    function testSetDaiPriceFeedDex() public {
        address token = dai;
        uint rate = 5 ether;
        DiamondExchange(exchange).setConfig(b("priceFeed"), b(token), b(feed[dai]));
        TestFeedLike(feed[dai]).setRate(rate);
        assertEq(DiamondExchange(exchange).getRate(token), rate);
    }

    function testFailWrongAddressSetPriceFeedDex() public {
        // error Revert ("dex-wrong-pricefeed-address")
        address token = eth;
        DiamondExchange(exchange).setConfig(b("priceFeed"), b(token), b(address(0)));
    }

    function testFailNonOwnerSetEthPriceFeedDex() public {
        // error Revert ("ds-auth-unauthorized")
        address token = eth;
        DiamondExchangeTester(user).doSetConfig("priceFeed", token, address(0));
    }

    function testFailWrongAddressSetDptPriceFeedDex() public {
        // error Revert ("dex-wrong-pricefeed-address")
        address token = dpt;
        DiamondExchange(exchange).setConfig(b("priceFeed"), b(token), b(address(0)));
    }

    function testFailWrongAddressSetCdcPriceFeedDex() public {
        // error Revert ("dex-wrong-pricefeed-address")
        address token = cdc;
        DiamondExchange(exchange).setConfig(b("priceFeed"), b(token), b(address(0)));
    }

    function testFailNonOwnerSetCdcPriceFeedDex() public {
        // error Revert ("dex-wrong-pricefeed-address")
        address token = cdc;
        DiamondExchangeTester(user).doSetConfig("priceFeed", token, address(0));
    }

    function testSetLiquidityContractDex() public {
        DSToken(dpt).transfer(user, 100 ether);
        DiamondExchange(exchange).setConfig(b("liq"), b(user), b(""));
        assertEq(DiamondExchange(exchange).liq(), user);
    }

    function testFailWrongAddressSetLiquidityContractDex() public {
        // error Revert ("dex-wrong-address")
        DiamondExchange(exchange).setConfig(b("liq"), b(address(0x0)), b(""));
    }

    function testFailNonOwnerSetLiquidityContractDex() public {
        // error Revert ("ds-auth-unauthorized")
        DSToken(dpt).transfer(user, 100 ether);
        DiamondExchangeTester(user).doSetConfig("liq", user, "");
    }

    function testFailWrongAddressSetWalletContractDex() public {
        // error Revert ("dex-wrong-address")
        DiamondExchange(exchange).setConfig(b("wal"), b(address(0x0)), b(""));
    }

    function testFailNonOwnerSetWalletContractDex() public {
        // error Revert ("ds-auth-unauthorized")
        DiamondExchangeTester(user).doSetConfig("wal", user, "");
    }

    function testSetManualDptRateDex() public {
        DiamondExchange(exchange).setConfig(b("manualRate"), b(dpt), b(true));
        assertTrue(DiamondExchange(exchange).manualRate(dpt));
        DiamondExchange(exchange).setConfig(b("manualRate"), b(dpt), b(false));
        assertTrue(!DiamondExchange(exchange).manualRate(dpt));
    }

    function testSetManualCdcRateDex() public {
        DiamondExchange(exchange).setConfig(b("manualRate"), b(cdc), b(true));
        assertTrue(DiamondExchange(exchange).manualRate(cdc));
        DiamondExchange(exchange).setConfig(b("manualRate"), b(cdc), b(false));
        assertTrue(!DiamondExchange(exchange).manualRate(cdc));
    }

    function testSetManualEthRateDex() public {
        DiamondExchange(exchange).setConfig(b("manualRate"), b(address(0xee)), b(true));
        assertTrue(DiamondExchange(exchange).manualRate(address(0xee)));
        DiamondExchange(exchange).setConfig(b("manualRate"), b(address(0xee)), b(false));
        assertTrue(!DiamondExchange(exchange).manualRate(address(0xee)));
    }

    function testSetManualDaiRateDex() public {
        DiamondExchange(exchange).setConfig(b("manualRate"), b(dai), b(true));
        assertTrue(DiamondExchange(exchange).manualRate(dai));
        DiamondExchange(exchange).setConfig(b("manualRate"), b(dai), b(false));
        assertTrue(!DiamondExchange(exchange).manualRate(dai));
    }

    function testFailNonOwnerSetManualDptRateDex() public {
        DiamondExchangeTester(user).doSetConfig("manualRate", dpt, false);
    }

    function testFailNonOwnerSetManualCdcRateDex() public {
        // error Revert ("ds-auth-unauthorized")
        DiamondExchangeTester(user).doSetConfig("manualRate", cdc, false);
    }

    function testFailNonOwnerSetManualEthRateDex() public {
        // error Revert ("ds-auth-unauthorized")
        DiamondExchangeTester(user).doSetConfig("manualRate", address(0xee), false);
    }

    function testFailNonOwnerSetManualDaiRateDex() public {
        // error Revert ("ds-auth-unauthorized")
        DiamondExchangeTester(user).doSetConfig("manualRate", dai, false);
    }

    function testSetFeeCalculatorContractDex() public {
        DiamondExchange(exchange).setConfig(b("fca"), b(address(fca)), b(""));
        assertEq(address(DiamondExchange(exchange).fca()), address(fca));
    }

    function testFailWrongAddressSetCfoDex() public {
        // error Revert ("dex-wrong-address")
        DiamondExchange(exchange).setConfig(b("fca"), b(address(0)), b(""));
    }

    function testFailNonOwnerSetCfoDex() public {
        // error Revert ("ds-auth-unauthorized")
        DiamondExchangeTester(user).doSetConfig("fca", user, "");
    }

    function testSetDptUsdRateDex() public {
        uint newRate = 5 ether;
        DiamondExchange(exchange).setConfig(b("rate"), b(dpt), b(newRate));
        assertEq(DiamondExchange(exchange).getLocalRate(dpt), newRate);
    }

    function testFailIncorectRateSetDptUsdRateDex() public {
        // error Revert ("dex-rate-must-be-greater-than-0")
        DiamondExchange(exchange).setConfig(b("rate"), b(dpt), b(uint(0)));
    }

    function testFailNonOwnerSetDptUsdRateDex() public {
        // error Revert ("ds-auth-unauthorized")
        uint newRate = 5 ether;
        DiamondExchangeTester(user).doSetConfig("rate", dpt, newRate);
    }

    function testSetCdcUsdRateDex() public {
        uint newRate = 5 ether;
        DiamondExchange(exchange).setConfig(b("rate"), b(cdc), b(newRate));
        assertEq(DiamondExchange(exchange).getLocalRate(cdc), newRate);
    }

    function testFailIncorectRateSetCdcUsdRateDex() public {
        // error Revert ("dex-rate-must-be-greater-than-0")
        DiamondExchange(exchange).setConfig(b("rate"), b(cdc), b(uint(0)));
    }

    function testFailNonOwnerSetCdcUsdRateDex() public {
        // error Revert ("ds-auth-unauthorized")
        uint newRate = 5 ether;
        DiamondExchangeTester(user).doSetConfig("rate", cdc, newRate);
    }

    function testSetEthUsdRateDex() public {
        uint newRate = 5 ether;
        DiamondExchange(exchange).setConfig(b("rate"), b(eth), b(newRate));
        assertEq(DiamondExchange(exchange).getLocalRate(eth), newRate);
    }

    function testFailIncorectRateSetEthUsdRateDex() public {
        // error Revert ("dex-rate-must-be-greater-than-0")
        DiamondExchange(exchange).setConfig(b("rate"), b(eth), b(uint(0)));
    }

    function testFailNonOwnerSetEthUsdRateDex() public {
        // error Revert ("ds-auth-unauthorized")
        uint newRate = 5 ether;
        DiamondExchangeTester(user).doSetConfig("rate", eth, newRate);
    }

    function testFailInvalidDptFeedAndManualDisabledBuyTokensWithFeeDex() public logs_gas {
        // error Revert ("dex-manual-rate-not-allowed")
        uint sentEth = 1 ether;

        DiamondExchange(exchange).setConfig(b("manualRate"), b(dpt), b(false));

        TestFeedLike(feed[dpt]).setValid(false);

        DiamondExchange(exchange).buyTokensWithFee(dpt, sentEth, cdc, uint(-1));
    }

    function testFailInvalidEthFeedAndManualDisabledBuyTokensWithFeeDex() public logs_gas {
        // error Revert ("dex-manual-rate-not-allowed")
        uint sentEth = 1 ether;

        DiamondExchange(exchange).setConfig(b("manualRate"), b(eth), b(false));

        TestFeedLike(feed[eth]).setValid(false);

        DiamondExchange(exchange).buyTokensWithFee.value(sentEth)(eth, sentEth, cdc, uint(-1));
    }

    function testFailInvalidCdcFeedAndManualDisabledBuyTokensWithFeeDex() public {
        // error Revert ("dex-feed-provides-invalid-data")
        uint sentEth = 1 ether;

        DiamondExchange(exchange).setConfig(b("manualRate"), b(cdc), b(false));

        TestFeedLike(feed[cdc]).setValid(false);

        DiamondExchange(exchange).buyTokensWithFee(cdc, sentEth, cdc, uint(-1));
    }

    function testForFixEthBuyAllCdcUserHasNoDptDex() public {
        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 41 ether;
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);

    }

    function testFailForFixEthBuyAllCdcUserDptNotZeroNotEnoughDex() public {
        // error Revert ("dex-token-not-allowed-to-be-bought")
        DiamondExchange(exchange).setConfig(b("canBuyErc20"), b(cdc), b(false));

        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);

    }

    function testForFixEthBuyAllCdcUserDptNotZeroNotEnoughDex() public {
        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);

    }

    function testForFixEthBuyAllCdcUserDptEnoughDex() public {
        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 27 ether;
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testForAllEthBuyAllCdcUserHasNoDptDex() public {
        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);

    }

    function testForAllEthBuyAllCdcUserDptNotZeroNotEnoughDex() public {
        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }
    function testForAllEthBuyAllCdcUserDptEnoughDex() public {
        userDpt = 3000 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }
    function testForAllEthBuyFixCdcUserHasNoDptDex() public {
        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = 17.79 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);

    }

    function testForAllEthBuyFixCdcUserDptNotZeroNotEnoughDex() public {
        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = 17.79 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testForAllEthBuyFixCdcUserDptEnoughDex() public {
        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = 17.79 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testForFixEthBuyFixCdcUserHasNoDptDex() public {
        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 17.79 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);

    }

    function testForFixEthBuyFixCdcUserDptNotZeroNotEnoughDex() public {
        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 17.79 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testForFixEthBuyFixCdcUserDptEnoughDex() public {
        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 17.79 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testFailForFixEthBuyFixCdcUserHasNoDptSellAmtTooMuchDex() public {
        // error Revert ("dex-sell-amount-exceeds-ether-value")
        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 1001 ether;  // has only 1000 eth balance
        address buyToken = cdc;
        uint buyAmtOrId = 17.79 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);

    }

    function testFailForFixEthBuyFixCdcUserHasNoDptBuyAmtTooMuchDex() public {
        // error Revert ("dex-buy-amount-exceeds-allowance")
        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address buyToken = cdc;

        doExchange(eth, 1000 ether, buyToken, 1001 ether);

    }

    function testFailForFixEthBuyFixCdcUserHasNoDptBothTooMuchDex() public {
        // error Revert ("dex-sell-amount-exceeds-ether-value")
        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 1001 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 1001 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testFailForFixDaiBuyEthUserHasNoDptBothTooMuchDex() public {
        // error Revert ("dex-we-do-not-sell-ether")
        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 11 ether;
        address buyToken = eth;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }


    function testFailSendEthIfNoEthIsSellTokenDex() public {
        // error Revert ("dex-do-not-send-ether")
        uint sentEth = 1 ether;

        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 11 ether;
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        DiamondExchange(exchange).buyTokensWithFee.value(sentEth)(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testFailForFixDaiBuyAllCdcUserHasEnoughDptCanNotSellTokenDex() public {
        // error Revert ("dex-token-not-allowed-to-be-sold")
        DiamondExchange(exchange).setConfig(b("canSellErc20"), b(dai), b(false));

        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 11 ether;
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        DiamondExchange(exchange).buyTokensWithFee(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testFailForFixDaiBuyAllCdcUserHasEnoughDptCanNotBuyTokenDex() public {
        // error Revert ("dex-token-not-allowed-to-be-sold")
        DiamondExchange(exchange).setConfig(b("canBuyErc20"), b(cdc), b(false));

        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 11 ether;
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        DiamondExchange(exchange).buyTokensWithFee(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testFailForFixDaiBuyAllCdcUserHasEnoughDptZeroTokenForSaleDex() public {
        // error Revert ("dex-0-token-is-for-sale")

        SimpleAssetManagement(asm).setConfig("setApproveForAll", b(dpass), b(address(this)), b(true));
        Dpass(dpass).transferFrom(asm, user,  dpassId[seller]);  // send the single collateral token away so that 0 CDC can be created.
        SimpleAssetManagement(asm).notifyTransferFrom(dpass, asm, user, dpassId[seller]);

        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 11 ether;
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        DiamondExchange(exchange).buyTokensWithFee(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testForFixDaiBuyAllCdcUserHasNoDptDex() public {
        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 41 ether;
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);

    }

    function testForFixDaiBuyAllCdcUserDptNotZeroNotEnoughDex() public {
        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);

    }

    function testForFixDaiBuyAllCdcUserDptEnoughDex() public {
        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 27 ether;
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testForAllDaiBuyAllCdcUserHasNoDptDex() public {
        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);

    }

    function testForAllDaiBuyAllCdcUserDptNotZeroNotEnoughDex() public {
        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testForAllDaiBuyAllCdcUserDptEnoughDex() public {
        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testForAllDaiBuyFixCdcUserHasNoDptDex() public {
        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = 17.79 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);

    }

    function testForAllDaiBuyFixCdcUserDptNotZeroNotEnoughDex() public {
        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = 17.79 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testForAllDaiBuyFixCdcUserDptEnoughDex() public {
        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = 17.79 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testForFixDaiBuyFixCdcUserHasNoDptDex() public {
        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 17.79 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);

    }

    function testForFixDaiBuyFixCdcUserDptNotZeroNotEnoughDex() public {
        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 17.79 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testForFixDaiBuyFixCdcUserDptEnoughDex() public {
        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 17.79 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testFailForFixDaiBuyFixCdcUserHasNoDptSellAmtTooMuchDex() public {
        // error Revert ("dex-sell-amount-exceeds-allowance")
        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 1001 ether;  // has only 1000 eth balance
        address buyToken = cdc;
        uint buyAmtOrId = 17.79 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);

    }

    function testFailForFixDaiBuyFixCdcUserHasNoDptBuyAmtTooMuchDex() public {
        // error Revert ("dex-sell-amount-exceeds-allowance")
        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 17 ether;  // has only 1000 eth balance
        address buyToken = cdc;
        uint buyAmtOrId = 1001 ether;   // has only 1000 cdc balance

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);

    }

    function testFailForFixDaiBuyFixCdcUserHasNoDptBothTooMuchDex() public {
        // error Revert ("dex-sell-amount-exceeds-allowance")
        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 1001 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 1001 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testForFixEthBuyAllCdcUserHasNoDptAllFeeInDptDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));

        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 41 ether;
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);

    }

    function testForFixEthBuyAllCdcUserDptNotZeroNotEnoughAllFeeInDptDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));

        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);

    }

    function testForFixEthBuyAllCdcUserDptEnoughAllFeeInDptDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));

        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 27 ether;
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testForAllEthBuyAllCdcUserHasNoDptAllFeeInDptDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));

        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);

    }

    function testForAllEthBuyAllCdcUserDptNotZeroNotEnoughAllFeeInDptDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));

        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testForAllEthBuyAllCdcUserDptEnoughAllFeeInDptDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));

        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testForAllEthBuyFixCdcUserHasNoDptAllFeeInDptDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));

        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = 17.79 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);

    }

    function testForAllEthBuyFixCdcUserDptNotZeroNotEnoughAllFeeInDptDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));

        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = 17.79 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testForAllEthBuyFixCdcUserDptEnoughAllFeeInDptDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));

        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = 17.79 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testForFixEthBuyFixCdcUserHasNoDptAllFeeInDptDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));

        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 17.79 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);

    }

    function testForFixEthBuyFixCdcUserDptNotZeroNotEnoughAllFeeInDptDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));

        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 17.79 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testForFixEthBuyFixCdcUserDptEnoughAllFeeInDptDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));

        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 17.79 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testFailForFixEthBuyFixCdcUserHasNoDptSellAmtTooMuchAllFeeInDptDex() public {
        // error Revert ("dex-sell-amount-exceeds-allowance")
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));

        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 1001 ether;  // has only 1000 eth balance
        address buyToken = cdc;
        uint buyAmtOrId = 17.79 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);

    }

    function testAssertForTestFailForFixEthBuyFixCdcUserHasNoDptBuyAmtTooMuchAllFeeInDptDex() public {

        // if this test fails, it is because in the test testFailForFixEthBuyFixCdcUserHasNoDptBuyAmtTooMuchAllFeeInDpt ...
        // ... we do not actually buy too much, or the next test fails before the feature could be tested

        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));

        uint buyAmtOrId = DSToken(cdc).balanceOf(custodian20[cdc]) + 1 ether; // more than available
        uint sellAmtOrId = wdivT(wmulV(buyAmtOrId, usdRate[cdc], cdc), usdRate[eth], eth);
        user.transfer(sellAmtOrId);
    }

    function testFailForFixEthBuyFixCdcUserHasNoDptBuyAmtTooMuchAllFeeInDptDex() public {
        // error Revert ("dex-buy-amount-exceeds-allowance")
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));

        uint buyAmtOrId = DSToken(cdc).balanceOf(custodian20[cdc]) + 1 ether; // more than available
        uint sellAmtOrId = wdivT(wmulV(buyAmtOrId, usdRate[cdc], cdc), usdRate[eth], eth);
        sendToken(eth, user, sellAmtOrId);

        doExchange(eth, sellAmtOrId, cdc, buyAmtOrId);
    }

    function testFailForFixEthBuyFixCdcUserHasNoDptBothTooMuchAllFeeInDptDex() public {
        // error Revert ("dex-sell-amount-exceeds-ether-value")
        userDpt = 123 ether; // this can be changed
        uint buyAmtOrId = 17.79 ether + 1 ether; // DO NOT CHANGE THIS!!!
        uint sellAmtOrId = user.balance + 1 ether; // DO NOT CHANGE THIS!!!

        if (wdivT(wmulV(buyAmtOrId, usdRate[cdc], cdc), usdRate[eth], eth) <= sellAmtOrId) {
            sendToken(dpt, user, userDpt);

            doExchange(eth, sellAmtOrId, cdc, buyAmtOrId);
        }
    }

    function testFailSendEthIfNoEthIsSellTokenAllFeeInDptDex() public {
        // error Revert ("dex-do-not-send-ether")
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));

        uint sentEth = 1 ether;

        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 11 ether;
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        DiamondExchange(exchange).buyTokensWithFee.value(sentEth)(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testForFixDptBuyAllCdcUserDptEnoughAllFeeInDptDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));

        userDpt = 1000 ether;
        sendToken(dpt, user, userDpt);
        uint sellDpt = 10 ether;

        address sellToken = dpt;
        uint sellAmtOrId = sellDpt;
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testForAllDptBuyAllCdcUserDptEnoughAllFeeInDptDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));

        userDpt = 1000 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dpt;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        // DiamondExchange(exchange).buyTokensWithFee(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }
    function testForAllDptBuyFixCdcUserDptEnoughAllFeeInDptDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));

        userDpt = 1000 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dpt;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = 17.79 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testForFixDptBuyFixCdcUserDptEnoughAllFeeInDptDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));

        userDpt = 1000 ether;
        sendToken(dpt, user, userDpt);
        uint sellDpt = 10 ether;

        address sellToken = dpt;
        uint sellAmtOrId = sellDpt;
        address buyToken = cdc;
        uint buyAmtOrId = 17.79 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testFailBuyTokensWithFeeLiquidityContractHasInsufficientDptDex() public {
        // error Revert ("ds-token-insufficient-balance")
        DiamondExchangeTester(liq).doTransfer(dpt, address(this), INITIAL_BALANCE);
        assertEq(DSToken(dpt).balanceOf(liq), 0);

        address sellToken = eth;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 17.79 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testBuyTokensWithFeeWithManualEthUsdRateDex() public {

        usdRate[eth] = 400 ether;
        DiamondExchange(exchange).setConfig(b("rate"), b(eth), b(usdRate[eth]));
        TestFeedLike(feed[eth]).setValid(false);

        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 17.79 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testBuyTokensWithFeeWithManualDptUsdRateDex() public {

        usdRate[dpt] = 400 ether;
        DiamondExchange(exchange).setConfig(b("rate"), b(dpt), b(usdRate[dpt]));
        TestFeedLike(feed[dpt]).setValid(false);

        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 17.79 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testBuyTokensWithFeeWithManualCdcUsdRateDex() public {

        usdRate[cdc] = 400 ether;
        DiamondExchange(exchange).setConfig(b("rate"), b(cdc), b(usdRate[cdc]));
        TestFeedLike(feed[cdc]).setValid(false);

        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 17.79 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testBuyTokensWithFeeWithManualDaiUsdRateDex() public {

        usdRate[dai] = 400 ether;
        DiamondExchange(exchange).setConfig(b("rate"), b(dai), b(usdRate[dai]));
        TestFeedLike(feed[dai]).setValid(false);

        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 17.79 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testFailBuyTokensWithFeeSendZeroEthDex() public {
        // error Revert ("dex-please-approve-us")
        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        address buyToken = cdc;
        uint buyAmtOrId = 17.79 ether;

        doExchange(sellToken, 0, buyToken, buyAmtOrId);
    }
    function testBuyTokensWithFeeWhenFeeIsZeroDex() public {

        DiamondExchange(exchange).setConfig(b("fixFee"), b(uint(0)), b(""));
        DiamondExchange(exchange).setConfig(b("varFee"), b(uint(0)), b(""));

        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 17.79 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }
    function testUpdateRatesDex() public {
        usdRate[cdc] = 40 ether;
        usdRate[dpt] = 12 ether;
        usdRate[eth] = 500 ether;
        usdRate[dai] = 500 ether;

        TestFeedLike(feed[cdc]).setRate(usdRate[cdc]);
        TestFeedLike(feed[dpt]).setRate(usdRate[dpt]);
        TestFeedLike(feed[eth]).setRate(usdRate[eth]);
        TestFeedLike(feed[dai]).setRate(usdRate[dai]);

        assertEq(DiamondExchange(exchange).getRate(cdc), usdRate[cdc]);
        assertEq(DiamondExchange(exchange).getRate(dpt), usdRate[dpt]);
        assertEq(DiamondExchange(exchange).getRate(eth), usdRate[eth]);
        assertEq(DiamondExchange(exchange).getRate(dai), usdRate[dai]);
    }

    function testForFixEthBuyDpassUserHasNoDptDex() public {

        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 16.5 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testFailForDpassBuyDpassUserHasNoDptDex() public {
        // error Revert ("dex-token-not-allowed-to-be-sold")
        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dpass;
        uint sellAmtOrId = dpassId[user];

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testFailForDpassBuyDpassUserHasEnoughDptDex() public {
        // error Revert ("dex-token-not-allowed-to-be-sold")
        userDpt = 1000 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dpass;
        uint sellAmtOrId = dpassId[user];

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testFailForDpassBuyDpassUserHasNoDptCanSellErc721Dex() public {
        // error Revert ("dex-one-of-tokens-must-be-erc20")
        DiamondExchange(exchange).setConfig(b("canSellErc721"), b(dpass), b(true));

        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dpass;
        uint sellAmtOrId = dpassId[user];

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testFailForDpassBuyDpassUserHasDptNotEnoughCanSellErc721Dex() public {
        // error Revert ("dex-one-of-tokens-must-be-erc20")

        DiamondExchange(exchange).setConfig(b("canSellErc721"), b(dpass), b(true));

        userDpt = 1.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dpass;
        uint sellAmtOrId = dpassId[user];

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testFailForDpassBuyDpassUserHasEnoughDptCanSellErc721Dex() public {
        // error Revert ("dex-one-of-tokens-must-be-erc20")
        DiamondExchange(exchange).setConfig(b("canSellErc721"), b(dpass), b(true));

        userDpt = 1000 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dpass;
        uint sellAmtOrId = dpassId[user];

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForFixEthBuyDpassUserDptNotEnoughDex() public {

        userDpt = 5 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 16.5 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForFixEthBuyDpassUserDptEnoughDex() public {

        userDpt = 1.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 15.65 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testFailForFixEthBuyDpassUserDptNotEnoughDex() public {
        // error Revert ("dex-token-not-for-sale")
        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 1 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testFailForFixEthBuyDpassUserEthNotEnoughDex() public {
        // error Revert ("dex-token-not-for-sale")
        userDpt = 1.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 10 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testFailForFixEthBuyDpassUserBothNotEnoughDex() public {
        // error Revert ("dex-token-not-for-sale")
        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 10 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForAllEthBuyDpassUserHasNoDptDex() public {

        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForAllEthBuyDpassDptNotEnoughDex() public {

        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForAllEthBuyDpassUserDptEnoughDex() public {

        userDpt = 1.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForFixDptBuyDpassDex() public {
        userDpt = 1000 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dpt;
        uint sellAmtOrId = 36.3 ether;                       //should be less than userDpt

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testFailForFixDptBuyDpassUserDptNotEnoughDex() public {
        // error Revert ("dex-not-enough-user-funds-to-sell")
        userDpt = 1000 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dpt;
        uint sellAmtOrId = 15.65 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForAllDptBuyDpassDex() public {

        userDpt = 500 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dpt;
        uint sellAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForFixCdcBuyDpassUserHasNoDptDex() public {

        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = 25.89 ether;
        sendSomeCdcToUser(sellAmtOrId);

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForFixCdcBuyDpassUserDptNotEnoughDex() public {

        userDpt = 5 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = 25.89 ether;
        sendSomeCdcToUser(sellAmtOrId);

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForFixCdcBuyDpassUserDptEnoughDex() public {

        userDpt = 1.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = 25.89 ether;
        sendSomeCdcToUser(sellAmtOrId);

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testFailForFixCdcBuyDpassUserDptNotEnoughEndDex() public {
        // error Revert ("dex-not-enough-user-funds-to-sell")
        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = 7 ether;
        sendSomeCdcToUser();

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testFailForFixCdcBuyDpassUserCdcNotEnoughDex() public {
        // error Revert ("dex-not-enough-user-funds-to-sell")
        userDpt = 1.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = 10 ether;
        sendSomeCdcToUser();

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testFailForFixCdcBuyDpassUserBothNotEnoughDex() public {
        // error Revert ("dex-not-enough-user-funds-to-sell")
        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = 10 ether;
        sendSomeCdcToUser();

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testFailForFixDpassBuyDpassDex() public {
        // error Revert ("dex-not-enough-user-funds-to-sell")
        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        doExchange(dpass, dpassId[user], dpass, dpassId[seller]);
    }
    function testForAllCdcBuyDpassUserHasNoDptDex() public {

        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);
        address sellToken = cdc;
        uint sellAmtOrId = uint(-1);
        sendSomeCdcToUser();

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }
    function testForAllCdcBuyDpassDptNotEnoughDex() public {

        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = uint(-1);
        sendSomeCdcToUser();

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }
    function testForAllCdcBuyDpassUserDptEnoughDex() public {

        userDpt = 1.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = uint(-1);
        sendSomeCdcToUser();

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }
    function testForFixDaiBuyDpassUserHasNoDptDex() public {

        userDpt = 0 ether;              // DO NOT CHANGE THIS
        sendToken(dpt, user, userDpt);  // DO NOT CHANGE THIS

        address sellToken = dai;
        uint sellAmtOrId = 13.94 ether;// the minimum value user has to pay // DO NOT CHANGE THIS

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForFixDaiBuyDpassUserDptNotEnoughDex() public {

        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 13.94 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForFixDaiBuyDpassUserDptEnoughDex() public {

        userDpt = 1.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 13.94 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }
    function testFailForFixDaiBuyDpassUserDptNotEnoughDex() public {
        // error Revert ("dex-not-enough-user-funds-to-sell")
        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 1 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }
    function testFailForFixDaiBuyDpassUserDaiNotEnoughDex() public {
        // error Revert ("dex-not-enough-user-funds-to-sell")
        userDpt = 1.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 10 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testFailForFixDaiBuyDpassUserBothNotEnoughDex() public {

        // error Revert ("dex-not-enough-user-funds-to-sell")
        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 10 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForAllDaiBuyDpassUserHasNoDptDex() public {

        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForAllDaiBuyDpassDptNotEnoughDex() public {

        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForAllDaiBuyDpassUserDptEnoughDex() public {

        userDpt = 1.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }
//-------------------new--------------------------------------------------

    function testForFixEthBuyDpassUserHasNoDptFullFeeDptDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));


        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 16.5 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }
    function testForFixEthBuyDpassUserDptNotEnoughFullFeeDptDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));

        userDpt = 5 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 14.2 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForFixEthBuyDpassUserDptEnoughFullFeeDptDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));


        userDpt = 6.4 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 13.73 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testFailForFixEthBuyDpassUserDptNotEnoughFullFeeDptDex() public {
        // error Revert ("dex-not-enough-user-funds-to-sell")

        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));


        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 13.73 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testFailForFixEthBuyDpassUserEthNotEnoughFullFeeDptDex() public {
        // error Revert ("dex-not-enough-user-funds-to-sell")
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));

        userDpt = 1.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 10 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testFailForFixEthBuyDpassUserBothNotEnoughFullFeeDptDex() public {
        // error Revert ("dex-not-enough-user-funds-to-sell")
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));


        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 13.72 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForAllEthBuyDpassUserHasNoDptFullFeeDptDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));


        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForAllEthBuyDpassDptNotEnoughFullFeeDptDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));


        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForAllEthBuyDpassUserDptEnoughFullFeeDptDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));


        userDpt = 1.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForFixDptBuyDpassFullFeeDptDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));

        userDpt = 1000 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dpt;
        uint sellAmtOrId = 36.3 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testFailForFixDptBuyDpassUserDptNotEnoughFullFeeDptDex() public {
        // error Revert ("dex-not-enough-user-funds-to-sell")
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));

        userDpt = 1000 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dpt;
        uint sellAmtOrId = 15.65 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }
    function testForAllDptBuyDpassFullFeeDptDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));

        userDpt = 500 ether;                                // should not change this value
        sendToken(dpt, user, userDpt);

        address sellToken = dpt;
        uint sellAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }
    function testForFixCdcBuyDpassUserHasNoDptFullFeeDptDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));


        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = 25.89 ether;
        sendSomeCdcToUser(sellAmtOrId);

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForFixCdcBuyDpassUserDptNotEnoughFullFeeDptDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));


        userDpt = 5 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = 25.89 ether;
        sendSomeCdcToUser(sellAmtOrId);

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForFixCdcBuyDpassUserDptEnoughFullFeeDptDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));


        userDpt = 1.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = 25.89 ether;
        sendSomeCdcToUser(sellAmtOrId);

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }


    function testFailForFixCdcBuyDpassUserDptNotEnoughFullFeeDptDex() public {
        // error Revert ("dex-not-enough-user-funds-to-sell")
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));


        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = 7 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testFailForFixCdcBuyDpassUserCdcNotEnoughFullFeeDptDex() public {
        // error Revert ("dex-not-enough-user-funds-to-sell")
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));


        userDpt = 1.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = 10 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testFailForFixCdcBuyDpassUserBothNotEnoughFullFeeDptDex() public {
        // error Revert ("dex-not-enough-user-funds-to-sell")
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));


        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = 10 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testFailForFixDpassBuyDpassFullFeeDptDex() public {
        // error Revert ("dex-token-not-allowed-to-be-sold")
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));

        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        doExchange(dpass, dpassId[user], dpass, dpassId[seller]);
    }

    function testForAllCdcBuyDpassUserHasNoDptFullFeeDptDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));

        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = uint(-1);
        sendSomeCdcToUser();
        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForAllCdcBuyDpassDptNotEnoughFullFeeDptDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));


        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = uint(-1);
        sendSomeCdcToUser();

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForAllCdcBuyDpassUserDptEnoughFullFeeDptDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));


        userDpt = 1.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = uint(-1);
        sendSomeCdcToUser();

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }
    function testForFixDaiBuyDpassUserHasNoDptFullFeeDptDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));


        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 13.94 ether;                                 // the minimum value user has to pay

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForFixDaiBuyDpassUserDptNotEnoughFullFeeDptDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));


        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 13.94 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForFixDaiBuyDpassUserDptEnoughFullFeeDptDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));


        userDpt = 1.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 13.94 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testFailForFixDaiBuyDpassUserDptNotEnoughFullFeeDptDex() public {
        // error Revert ("dex-not-enough-user-funds-to-sell")
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));

        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 1 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testFailForFixDaiBuyDpassUserDaiNotEnoughFullFeeDptDex() public {
        // error Revert ("dex-not-enough-user-funds-to-sell")
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));


        userDpt = 1.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 10 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testFailForFixDaiBuyDpassUserBothNotEnoughFullFeeDptDex() public {
        // error Revert ("dex-not-enough-user-funds-to-sell")
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));


        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 10 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForAllDaiBuyDpassUserHasNoDptFullFeeDptDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));


        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForAllDaiBuyDpassDptNotEnoughFullFeeDptDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));


        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForAllDaiBuyDpassUserDptEnoughFullFeeDptDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));

        userDpt = 1.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testFailForFixEthBuyDpassUserDptEnoughDex() public {
        // error Revert ("dex-not-enough-funds")
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b(false)), b(""));

        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 1 ether;
        address buyToken = dpass;
        uint buyAmtOrId = dpassId[seller];

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testFailForDpassBuyCdcUserDptEnoughDex() public {
        // error Revert ("dex-not-enough-tokens-to-buy")
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b(false)), b(""));
        DiamondExchange(exchange).setConfig(b("canSellErc721"), b(dpass), b(b(true)));

        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dpass;
        uint sellAmtOrId = dpassId[user];
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testGetBuyPriceAndSetBuyPriceDex() public {
        uint buyPrice = 43 ether;
        uint otherBuyPrice = 47 ether;

        DiamondExchangeTester(user)
            .doSetBuyPrice(dpass, dpassId[user], buyPrice);

        assertEqLog(
            "setBuyPrice() actually set",
            DiamondExchange(exchange).getBuyPrice(dpass, dpassId[user]),
            buyPrice);

        assertEqLog(
            "user buyPrice var ok",
            DiamondExchange(exchange).buyPrice(dpass, user, dpassId[user]),
            buyPrice);

        DiamondExchangeTester(seller)
            .doSetBuyPrice(dpass, dpassId[user], otherBuyPrice);            // anyone can set sell price, but it will only be effective, if they own the token

        DiamondExchangeTester(seller)
            .doSetBuyPrice(dpass, dpassId[seller], otherBuyPrice);            // anyone can set sell price, but it will only be effective, if they own the token

        assertEqLog(
            "cust set buy price",
            DiamondExchange(exchange).getBuyPrice(dpass, dpassId[seller]),
            otherBuyPrice);

        assertEqLog(
            "cust buyPrice var ok",
            DiamondExchange(exchange).buyPrice(dpass, asm, dpassId[seller]),
            otherBuyPrice);

        assertEqLog(
            "setBuyPrice() by oth don't apply",
            DiamondExchange(exchange).getBuyPrice(dpass, dpassId[user]),
            buyPrice);

        DiamondExchangeTester(user)
            .transferFrom721(dpass, user, seller, dpassId[user]);
        assertEqLog(
            "setBuyPrice() apply once new own",
            DiamondExchange(exchange).getBuyPrice(dpass, dpassId[user]),
            otherBuyPrice);
    }

    function testGetPriceDex() public {
        uint buyPrice = 43 ether;
        uint otherBuyPrice = 47 ether;
        assertEq(DiamondExchange(exchange).getPrice(dpass, dpassId[user]), dpassOwnerPrice[user]);

        DiamondExchangeTester(user)
            .doSetBuyPrice(dpass, dpassId[user], buyPrice);

        assertEqLog(
            "getPrice() is setBuyPrice()",
            DiamondExchange(exchange).getPrice(dpass, dpassId[user]),
            buyPrice
            );

        DiamondExchangeTester(seller)
            .doSetBuyPrice(dpass, dpassId[user], otherBuyPrice);            // if non-owner sets price price does not change

        assertEqLog(
            "non-owner set price dont change",
            DiamondExchange(exchange).getPrice(dpass, dpassId[user]),
            buyPrice);

        DiamondExchangeTester(user)
            .doSetBuyPrice(dpass, dpassId[user], 0 ether);                  // if user sets 0 price for dpass, the base price will be used

        assertEqLog(
            "0 set price base price used",
            DiamondExchange(exchange).getPrice(dpass, dpassId[user]),
            dpassOwnerPrice[user]);

        DiamondExchangeTester(user)
            .doSetBuyPrice(dpass, dpassId[user], uint(-1));                 // if user sets highest possible  price for dpass, the base price will be used

        assertEqLog(
            "uint(-1) price is base price",
            DiamondExchange(exchange).getPrice(dpass, dpassId[user]),
            dpassOwnerPrice[user]);

        DiamondExchangeTester(user)
            .transferFrom721(dpass, user, seller, dpassId[user]);

        assertEqLog(
            "prev set price is now valid",
            DiamondExchange(exchange).getBuyPrice(dpass, dpassId[user]),
            otherBuyPrice);

        DiamondExchangeTester(seller)
            .doSetBuyPrice(dpass, dpassId[user], 0 ether);                  // if there is no valid price set, then base price is used

        assertEqLog(
            "base price used when 0 set",
            DiamondExchange(exchange).getPrice(dpass, dpassId[user]),
            dpassOwnerPrice[user]);
    }

    function testFailGetPriceBothBasePriceAndSetBuyPriceZeroDex() public {
        // error Revert ("dex-zero-price-not-allowed")
        SimpleAssetManagement(asm).setBasePrice(dpass, dpassId[user], 0 ether);
        DiamondExchange(exchange).getPrice(dpass, dpassId[user]);
    }

    function testFailGetPriceTokenNotForSaleDex() public {
        // error Revert ("dex-token-not-for-sale")
        DiamondExchange(exchange).setConfig(b("canBuyErc721"), b(dpass), b(b(false)));
        DiamondExchange(exchange).getPrice(dpass, dpassId[user]);
    }

    function testFailSellDpassForFixCdcUserHasNoDptTakeProfitOnlyInDptDex() public {
        // error Revert ("dex-not-enough-tokens-to-buy")
        DiamondExchange(exchange).setConfig(b("canSellErc721"), b(dpass), b(b(true)));
        SimpleAssetManagement(asm).setConfig("payTokens",b(dpass),b(true),"");
        DiamondExchangeTester(user).doApprove721(dpass, exchange, dpassId[user]);

        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dpass;
        uint sellAmtOrId = dpassId[user];
        address buyToken = cdc;
        uint buyAmtOrId = 6.57 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testSellDpassForLimitedCdcUserHasNoDptTakeProfitOnlyInDptDex() public {
        DiamondExchange(exchange).setConfig(b("canSellErc721"), b(dpass), b(b(true)));
        SimpleAssetManagement(asm).setConfig("payTokens",b(dpass),b(true),"");
        DiamondExchangeTester(user).doApprove721(dpass, exchange, dpassId[user]);

        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dpass;
        uint sellAmtOrId = dpassId[user];
        address buyToken = cdc;
        uint buyAmtOrId = 17.79 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testSellDpassForUnlimitedCdcUserHasNoDptTakeProfitOnlyInDptDex() public {
        DiamondExchange(exchange).setConfig(b("canSellErc721"), b(dpass), b(b(true)));
        SimpleAssetManagement(asm).setConfig("payTokens",b(dpass),b(true),"");
        DiamondExchangeTester(user).doApprove721(dpass, exchange, dpassId[user]);

        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dpass;
        uint sellAmtOrId = dpassId[user];
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testFailSellDpassForFixCdcUserHasDptNotEnoughTakeProfitOnlyInDptDex() public {
        // error Revert ("dex-not-enough-tokens-to-buy")
        DiamondExchange(exchange).setConfig(b("canSellErc721"), b(dpass), b(b(true)));
        SimpleAssetManagement(asm).setConfig("payTokens",b(dpass),b(true),"");
        DiamondExchangeTester(user).doApprove721(dpass, exchange, dpassId[user]);

        userDpt = 1.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dpass;
        uint sellAmtOrId = dpassId[user];
        address buyToken = cdc;
        uint buyAmtOrId = 6.51 ether;
        require(buyAmtOrId < 6.511428571428571429 ether, "test-buyAmtOrId-too-high");

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testSellDpassForLimitedCdcUserHasDptNotEnoughTakeProfitOnlyInDptDex() public {

        DiamondExchange(exchange).setConfig(b("canSellErc721"), b(dpass), b(b(true)));
        SimpleAssetManagement(asm).setConfig("payTokens",b(dpass),b(true),"");
        DiamondExchangeTester(user).doApprove721(dpass, exchange, dpassId[user]);

        userDpt = 1.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dpass;
        uint sellAmtOrId = dpassId[user];
        address buyToken = cdc;
        uint buyAmtOrId = 17.79 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testSellDpassForUnlimitedCdcUserHasDptNotEnoughTakeProfitOnlyInDptDex() public {

        DiamondExchange(exchange).setConfig(b("canSellErc721"), b(dpass), b(b(true)));
        SimpleAssetManagement(asm).setConfig("payTokens",b(dpass),b(true),"");
        DiamondExchangeTester(user).doApprove721(dpass, exchange, dpassId[user]);

        userDpt = 1.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dpass;
        uint sellAmtOrId = dpassId[user];
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testFailSellDpassForFixCdcUserHasDptEnoughTakeProfitOnlyInDptDex() public {
        // error Revert ("dex-not-enough-tokens-to-buy")
        DiamondExchange(exchange).setConfig(b("canSellErc721"), b(dpass), b(b(true)));
        SimpleAssetManagement(asm).setConfig("payTokens",b(dpass),b(true),"");
        DiamondExchangeTester(user).doApprove721(dpass, exchange, dpassId[user]);

        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dpass;
        uint sellAmtOrId = dpassId[user];
        address buyToken = cdc;
        uint buyAmtOrId = 6.57 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testSellDpassForLimitedCdcUserHasDptEnoughTakeProfitOnlyInDptDex() public {

        DiamondExchange(exchange).setConfig(b("canSellErc721"), b(dpass), b(b(true)));
        SimpleAssetManagement(asm).setConfig("payTokens",b(dpass),b(true),"");
        DiamondExchangeTester(user).doApprove721(dpass, exchange, dpassId[user]);

        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dpass;
        uint sellAmtOrId = dpassId[user];
        address buyToken = cdc;
        uint buyAmtOrId = 17.79 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testSellDpassForUnlimitedCdcUserHasDptEnoughTakeProfitOnlyInDptDex() public {

        DiamondExchange(exchange).setConfig(b("canSellErc721"), b(dpass), b(b(true)));
        SimpleAssetManagement(asm).setConfig("payTokens",b(dpass),b(true),"");
        DiamondExchangeTester(user).doApprove721(dpass, exchange, dpassId[user]);

        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dpass;
        uint sellAmtOrId = dpassId[user];
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }
//--------------------------------

    function testFailSellDpassForFixCdcUserHasNoDptFullFeeInDptDex() public {
        // error Revert ("dex-not-enough-tokens-to-buy")
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b(false)), b(""));
        DiamondExchange(exchange).setConfig(b("canSellErc721"), b(dpass), b(b(true)));
        SimpleAssetManagement(asm).setConfig("payTokens",b(dpass),b(true),"");
        DiamondExchangeTester(user).doApprove721(dpass, exchange, dpassId[user]);

        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dpass;
        uint sellAmtOrId = dpassId[user];
        address buyToken = cdc;
        uint buyAmtOrId = 6.57 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testSellDpassForLimitedCdcUserHasNoDptFullFeeInDptDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b(false)), b(""));
        DiamondExchange(exchange).setConfig(b("canSellErc721"), b(dpass), b(b(true)));
        SimpleAssetManagement(asm).setConfig("payTokens",b(dpass),b(true),"");
        DiamondExchangeTester(user).doApprove721(dpass, exchange, dpassId[user]);

        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dpass;
        uint sellAmtOrId = dpassId[user];
        address buyToken = cdc;
        uint buyAmtOrId = 17.79 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testSellDpassForUnlimitedCdcUserHasNoDptFullFeeInDptDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b(false)), b(""));
        DiamondExchange(exchange).setConfig(b("canSellErc721"), b(dpass), b(b(true)));
        SimpleAssetManagement(asm).setConfig("payTokens",b(dpass),b(true),"");
        DiamondExchangeTester(user).doApprove721(dpass, exchange, dpassId[user]);

        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dpass;
        uint sellAmtOrId = dpassId[user];
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testFailSellDpassForFixCdcUserHasDptNotEnoughFullFeeInDptDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b(false)), b(""));
        // error Revert ("dex-not-enough-tokens-to-buy")
        DiamondExchange(exchange).setConfig(b("canSellErc721"), b(dpass), b(b(true)));
        SimpleAssetManagement(asm).setConfig("payTokens",b(dpass),b(true),"");
        DiamondExchangeTester(user).doApprove721(dpass, exchange, dpassId[user]);

        userDpt = 1.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dpass;
        uint sellAmtOrId = dpassId[user];
        address buyToken = cdc;
        uint buyAmtOrId = 6.51 ether;
        require(buyAmtOrId < 6.511428571428571429 ether, "test-buyAmtOrId-too-high");

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testSellDpassForLimitedCdcUserHasDptNotEnoughFullFeeInDptDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b(false)), b(""));

        DiamondExchange(exchange).setConfig(b("canSellErc721"), b(dpass), b(b(true)));
        SimpleAssetManagement(asm).setConfig("payTokens",b(dpass),b(true),"");
        DiamondExchangeTester(user).doApprove721(dpass, exchange, dpassId[user]);

        userDpt = 1.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dpass;
        uint sellAmtOrId = dpassId[user];
        address buyToken = cdc;
        uint buyAmtOrId = 17.79 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testSellDpassForUnlimitedCdcUserHasDptNotEnoughFullFeeInDptDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b(false)), b(""));

        DiamondExchange(exchange).setConfig(b("canSellErc721"), b(dpass), b(b(true)));
        SimpleAssetManagement(asm).setConfig("payTokens",b(dpass),b(true),"");
        DiamondExchangeTester(user).doApprove721(dpass, exchange, dpassId[user]);

        userDpt = 1.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dpass;
        uint sellAmtOrId = dpassId[user];
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testFailSellDpassForFixCdcUserHasDptEnoughFullFeeInDptDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b(false)), b(""));
        // error Revert ("dex-not-enough-tokens-to-buy")
        DiamondExchange(exchange).setConfig(b("canSellErc721"), b(dpass), b(b(true)));
        SimpleAssetManagement(asm).setConfig("payTokens",b(dpass),b(true),"");
        DiamondExchangeTester(user).doApprove721(dpass, exchange, dpassId[user]);

        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dpass;
        uint sellAmtOrId = dpassId[user];
        address buyToken = cdc;
        uint buyAmtOrId = 6.57 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testSellDpassForLimitedCdcUserHasDptEnoughFullFeeInDptDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b(false)), b(""));

        DiamondExchange(exchange).setConfig(b("canSellErc721"), b(dpass), b(b(true)));
        SimpleAssetManagement(asm).setConfig("payTokens",b(dpass),b(true),"");
        DiamondExchangeTester(user).doApprove721(dpass, exchange, dpassId[user]);

        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dpass;
        uint sellAmtOrId = dpassId[user];
        address buyToken = cdc;
        uint buyAmtOrId = 17.79 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testSellDpassForUnlimitedCdcUserHasDptEnoughFullFeeInDptDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b(false)), b(""));

        DiamondExchange(exchange).setConfig(b("canSellErc721"), b(dpass), b(b(true)));
        SimpleAssetManagement(asm).setConfig("payTokens",b(dpass),b(true),"");
        DiamondExchangeTester(user).doApprove721(dpass, exchange, dpassId[user]);

        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dpass;
        uint sellAmtOrId = dpassId[user];
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testSellDpassForLimitedDaiDex() public {

        DSToken(dai).transfer(asm, INITIAL_BALANCE);
        balance[asm][dai] = DSToken(dai).balanceOf(asm);
        DiamondExchange(exchange).setConfig(b("canBuyErc20"), b(dai), b(b(true)));
        SimpleAssetManagement(asm).setConfig("approve", b(dai), b(exchange), b(uint(-1)));
        DiamondExchange(exchange).setConfig(b("canSellErc721"), b(dpass), b(b(true)));
        SimpleAssetManagement(asm).setConfig("payTokens",b(dpass),b(true),"");
        DiamondExchangeTester(user).doApprove721(dpass, exchange, dpassId[user]);

        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dpass;
        uint sellAmtOrId = dpassId[user];
        address buyToken = dai;
        uint buyAmtOrId = 70 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testSellDpassForUnlimitedDaiDex() public {

        DSToken(dai).transfer(asm, INITIAL_BALANCE);
        balance[asm][dai] = DSToken(dai).balanceOf(asm);
        DiamondExchange(exchange).setConfig(b("canBuyErc20"), b(dai), b(b(true)));
        SimpleAssetManagement(asm).setConfig("approve", b(dai), b(exchange), b(uint(-1)));
        DiamondExchange(exchange).setConfig(b("canSellErc721"), b(dpass), b(b(true)));
        SimpleAssetManagement(asm).setConfig("payTokens",b(dpass),b(true),"");
        DiamondExchangeTester(user).doApprove721(dpass, exchange, dpassId[user]);

        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dpass;
        uint sellAmtOrId = dpassId[user];
        address buyToken = dai;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testFailSellDpassForLimitedEthDex() public pure {
        require(false, "approve-not-work-for-eth");          // we can't even test with eth, since it can not be approved, if you want to sell Ether, probably W-eth is your best option
    }

    function testFailSellDpassForUnlimitedEthDex() public pure {
        require(false, "approve-not-work-for-eth");          // we can't even test with eth, since it can not be approved, if you want to sell Ether, probably W-eth is your best option
    }

    function testForFixEthBuyUserDpassUserHasNoDptDex() public {

        DiamondExchangeTester(user)                                                 // address(this) is the seller the seller
            .transferFrom721(dpass, user, address(this), dpassId[user]);
        dpassOwnerPrice[address(this)] = 61 ether;
        SimpleAssetManagement(asm).setBasePrice(dpass, dpassId[user], dpassOwnerPrice[address(this)]);
        Dpass(dpass).approve(exchange, dpassId[user]);

        SimpleAssetManagement(asm).setConfig("payTokens", b(dpass), b(true), "");

        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 16.5 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[user]);
    }

    function testForFixCdcBuyUserDpassUserHasNoDptDex() public {

        DiamondExchangeTester(user)
            .transferFrom721(dpass, user, address(this), dpassId[user]);
        dpassOwnerPrice[address(this)] = 61 ether;
        SimpleAssetManagement(asm).setBasePrice(dpass, dpassId[user], dpassOwnerPrice[address(this)]);
        Dpass(dpass).approve(exchange, dpassId[user]);

        SimpleAssetManagement(asm).setConfig("payTokens", b(dpass), b(true), "");

        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = 25.89 ether;
        sendSomeCdcToUser(sellAmtOrId);

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[user]);
    }

    function testFailAuthCheckSetConfigDex() public {
        DiamondExchange(exchange).setOwner(user);
        DiamondExchange(exchange).setConfig(b("canSellErc721"), b(dpass), b(b(true)));
    }

    function testFailAuthCheck_getValuesDex() public {
        TrustedDiamondExchange(exchange)._getValues(eth, 1 ether, cdc, uint(-1));
    }

    function testFailAuthCheck_takeFeeDex() public {
        TrustedDiamondExchange(exchange)._takeFee(.2 ether, 1 ether, 1 ether, eth, 1 ether, cdc, 1 ether);
    }

    function testFailAuthCheck_transferTokensDex() public {
        TrustedDiamondExchange(exchange)._transferTokens(1 ether, 1 ether, eth, 1 ether, cdc, 1 ether, .2 ether);
    }

    function testFailAuthCheckGetLocalRateDex() public {
        DiamondExchange(exchange).setOwner(user);
        DiamondExchange(exchange).getLocalRate(cdc);
    }

    function testFailAuthCheckGetAllowedTokenDex() public {
        DiamondExchange(exchange).setOwner(user);
        DiamondExchange(exchange).getAllowedToken(cdc, true);
    }

    function testFailAuthCheckGetRateDex() public {
        DiamondExchange(exchange).setOwner(user);
        DiamondExchange(exchange).getRate(cdc);
    }

    function testFailAuthCheckSetKycDex() public {
        DiamondExchange(exchange).setOwner(user);
        DiamondExchange(exchange).setKyc(user, true);
    }

    function testFailAuthCheck_getNewRateDex() public view {
        TrustedDiamondExchange(exchange)._getNewRate(eth);
    }

    function testFailAuthCheck_updateRatesDex() public {
        TrustedDiamondExchange(exchange)._updateRates(dai, dpass);
    }

    function testFailAuthCheck_logTradeDex() public {
        TrustedDiamondExchange(exchange)._logTrade(eth, 1 ether, cdc, 1 ether, 1 ether, .2 ether);
    }

    function testFailAuthCheck_updateRateDex() public {
        TrustedDiamondExchange(exchange)._updateRate(dai);
    }

    function testFailAuthCheck_takeFeeInTokenDex() public {
        TrustedDiamondExchange(exchange)._takeFeeInToken(.2 ether, .03 ether, dai, address(this), 1 ether);
    }

    function testFailAuthCheck_takeFeeInDptFromUserDex() public {
        TrustedDiamondExchange(exchange)._takeFeeInDptFromUser(.2 ether);
    }

    function testFailAuthCheck_sendTokenDex() public {
        TrustedDiamondExchange(exchange)._sendToken(dpt, address(this), user, 1 ether);
    }

    function testKycDex() public {
        DiamondExchange(exchange).setKyc(user, true);
        DiamondExchange(exchange).setConfig("kycEnabled", b(true), "");
        testForFixEthBuyAllCdcUserHasNoDptDex();
    }

    function testFailKycDex() public {
        // error Revert ("dex-you-are-not-on-kyc-list")
        DiamondExchange(exchange).setKyc(user, false);
        DiamondExchange(exchange).setConfig("kycEnabled", b(true), "");
        testForFixEthBuyAllCdcUserHasNoDptDex();
    }

    function testFailDenyTokenDex() public {
        DiamondExchange(exchange).setDenyToken(cdc, true);
        testForFixCdcBuyUserDpassUserHasNoDptDex();
    }

    function testFailDenyTokenPairDex() public {
        DiamondExchange(exchange).setConfig("denyTokenPair", b(cdc), b(dpass));
        testForFixCdcBuyUserDpassUserHasNoDptDex();
    }

    function testAllowTokenlirDenyThenAllowDex() public {
        DiamondExchange(exchange).setConfig("denyTokenPair", b(cdc), b(dpass));
        DiamondExchange(exchange).setConfig("allowTokenPair", b(cdc), b(dpass));
        testForFixCdcBuyUserDpassUserHasNoDptDex();
    }

    function testDenyTokenDex() public {
        DiamondExchange(exchange).setDenyToken(cdc, true);
        DiamondExchange(exchange).setDenyToken(cdc, false);
        testForFixCdcBuyUserDpassUserHasNoDptDex();
    }

    function testIsHandledByAsm() public {
        assertTrue(DiamondExchange(exchange).handledByAsm(cdc));
        DiamondExchange(exchange).setConfig("handledByAsm", b(cdc), b(false));
        assertTrue(!DiamondExchange(exchange).handledByAsm(cdc));
    }

    function testSetPriceFeedDex() public {
        // error Revert ("dex-wrong-pricefeed-address")
        address token = eth;
        DiamondExchange(exchange).setConfig(b("priceFeed"), b(token), b(address(feed[token])));
        assertEqLog(
            "set-pricefeed-is-returned",
            address(DiamondExchange(exchange).priceFeed(token)),
            address(feed[token]));

        token = dai;
        DiamondExchange(exchange).setConfig(b("priceFeed"), b(token), b(address(feed[token])));
        assertEqLog(
            "set-pricefeed-is-returned",
            address(DiamondExchange(exchange).priceFeed(token)),
            address(feed[token]));

        token = cdc;
        DiamondExchange(exchange).setConfig(b("priceFeed"), b(token), b(address(feed[token])));
        assertEqLog(
            "set-pricefeed-is-returned",
            address(DiamondExchange(exchange).priceFeed(token)),
            address(feed[token]));
    }

    function testGetAllowedTokenDex() public {
        assertTrue(DiamondExchange(exchange).getAllowedToken(cdc, true));
        assertTrue(DiamondExchange(exchange).getAllowedToken(cdc, false));

        DiamondExchange(exchange).setConfig("canBuyErc20",b(cdc), b(false));
        DiamondExchange(exchange).setConfig("canSellErc20",b(cdc), b(false));

        assertTrue(!DiamondExchange(exchange).getAllowedToken(cdc, true));
        assertTrue(!DiamondExchange(exchange).getAllowedToken(cdc, false));
    }

    function testGetDecimalsSetDex() public {
        assertTrue(DiamondExchange(exchange).decimalsSet(cdc));
        address token1 = address(new DSToken("TEST"));
        assertTrue(!DiamondExchange(exchange).decimalsSet(token1));
        DiamondExchange(exchange).setConfig("decimals",b(token1), b(18));
        assertTrue(DiamondExchange(exchange).decimalsSet(token1));
    }

    function testGetCustodian20() public {
        assertEqLog(
            "default custodian is asm",
            DiamondExchange(exchange).custodian20(cdc),
            custodian20[cdc]
        );
        address token1 = address(new DSToken("TEST"));
        assertEqLog(
            "any token custodian is unset",
            DiamondExchange(exchange).custodian20(token1),
            address(0)
        );
    }

    function testAddrDex() public {
        address someAddress = address(0xee);
        assertEqLog(
            "address eq address",
            DiamondExchange(exchange).addr(b(someAddress)),
            someAddress
        );
    }

    function testGetCostsBuyDpassTakeProfitOnlyDptEnoughDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(true)), b(""));


        userDpt = 1.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = 25.89 ether;
        sendSomeCdcToUser(sellAmtOrId);
        (uint sellAmt_, uint feeDpt_, uint256 feeV_, uint256 feeSellT_) = DiamondExchangeExtension(dee).getCosts(user, cdc, 0, dpass, dpassId[seller]);

        assertEqDustLog("expected sell amount adds up",
            sellAmt_,
            22311428571428571429,
            cdc);

        assertEqDustLog("expected dpt fee adds up",
            feeDpt_,
            1644000000000000000,
            dpt);

        assertEqDustLog("expected fee value adds up",
            feeV_,
            27400000000000000000,
            dpt);

        assertEqDustLog("expected fee in sellTkns adds up",
            feeSellT_,
            2740000000000000000,
            dpt);

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testGetCostsBuyDpassTakeProfitOnlyDptNotEnoughDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(true)), b(""));


        userDpt = 0.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = 25.89 ether;
        sendSomeCdcToUser(sellAmtOrId);
        (uint sellAmt_, uint feeDpt_, uint256 feeV_, uint256 feeSellT_) = DiamondExchangeExtension(dee).getCosts(user, cdc, 0, dpass, dpassId[seller]);

        assertEqDustLog("expected sell amount adds up",
            sellAmt_,
            22905714285714285715,
            cdc);

        assertEqDustLog("expected dpt fee adds up",
            feeDpt_,
            812000000000000000,
            dpt);

        assertEqDustLog("expected fee value adds up",
            feeV_,
            27400000000000000000,
            dpt);

        assertEqDustLog("expected fee in sellTkns adds up",
            feeSellT_,
            3334285714285714286,
            dpt);

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testGetCostsBuyDpassTakeAllCostsInDptDptEnoughDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));


        userDpt = 5.49 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = 25.89 ether;
        sendSomeCdcToUser(sellAmtOrId);
        (uint sellAmt_, uint feeDpt_, uint256 feeV_, uint256 feeSellT_) = DiamondExchangeExtension(dee).getCosts(user, cdc, 0, dpass, dpassId[seller]);

        assertEqDustLog("expected sell amount adds up",
            sellAmt_,
            19571428571428571429,
            cdc);

        assertEqDustLog("expected dpt fee adds up",
            feeDpt_,
            5480000000000000000,
            dpt);

        assertEqDustLog("expected fee value adds up",
            feeV_,
            27400000000000000000,
            dpt);

        assertEqDustLog("expected fee in sellTkns adds up",
            feeSellT_,
            0,
            dpt);

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

//-------------------
    function testGetCostsBuyDpassTakeAllCostsInDptDptNotEnoughDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));


        userDpt = 5.3 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = 25.89 ether;
        sendSomeCdcToUser(sellAmtOrId);
        (uint sellAmt_, uint feeDpt_, uint256 feeV_, uint256 feeSellT_) = DiamondExchangeExtension(dee).getCosts(user, cdc, 0, dpass, dpassId[seller]);

        assertEqDustLog("expected sell amount adds up",
            sellAmt_,
            19700000000000000000,
            cdc);

        assertEqDustLog("expected dpt fee adds up",
            feeDpt_,
            5300000000000000000,
            dpt);

        assertEqDustLog("expected fee value adds up",
            feeV_,
            27400000000000000000,
            dpt);

        assertEqDustLog("expected fee in sellTkns adds up",
            feeSellT_,
            128571428571428571,
            dpt);

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testFailGetCostsUserZeroDex() public view{
        // error Revert ("dex-user-address-zero")
        (uint sellAmt_, uint feeDpt_, uint256 feeV_, uint256 feeSellT_) = DiamondExchangeExtension(dee).getCosts(address(0), cdc, 0, dpass, dpassId[seller]);
        sellAmt_ = sellAmt_ + feeDpt_ + feeV_ + feeSellT_; // this is just to suppress warning
    }

    function testFailGetCostsSellTokenInvalidDex() public view{
        // error Revert ("dex-selltoken-invalid")
        (uint sellAmt_, uint feeDpt_, uint256 feeV_, uint256 feeSellT_) = DiamondExchangeExtension(dee).getCosts(user, address(0xffffff), 0, dpass, dpassId[seller]);
        sellAmt_ = sellAmt_ + feeDpt_ + feeV_ + feeSellT_; // this is just to suppress warning
    }

    function testFailGetCostsBuyTokenInvalidDex() public view {
        // error Revert ("dex-buytoken-invalid")
        (uint sellAmt_, uint feeDpt_, uint256 feeV_, uint256 feeSellT_) = DiamondExchangeExtension(dee).getCosts(address(0), cdc, 0, address(0xffeeff), dpassId[seller]);
        sellAmt_ = sellAmt_ + feeDpt_ + feeV_ + feeSellT_; // this is just to suppress warning
    }

    function testFailGetCostsBothTokensDpassDex() public view {
        // error Revert ("dex-both-tokens-dpass")
        (uint sellAmt_, uint feeDpt_, uint256 feeV_, uint256 feeSellT_) = DiamondExchangeExtension(dee).getCosts(user, dpass, 0, dpass, dpassId[seller]);
        sellAmt_ = sellAmt_ + feeDpt_ + feeV_ + feeSellT_; // this is just to suppress warning
    }

    function testGetCostsBuyCdcTakeProfitOnlyDptEnoughDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(true)), b(""));


        userDpt = 1.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        (uint sellAmt_, uint feeDpt_, uint256 feeV_, uint256 feeSellT_) = DiamondExchangeExtension(dee).getCosts(user, dai, 0, cdc, uint(-1));

        assertEqDustLog("expected sell amount adds up",
            sellAmt_,
            69540839160839160840,
            cdc);

        assertEqDustLog("expected dpt fee adds up",
            feeDpt_,
            1812000000000000000,
            dpt);

        assertEqDustLog("expected fee value adds up",
            feeV_,
            152181818181818181819,
            dpt);

        assertEqDustLog("expected fee in sellTkns adds up",
            feeSellT_,
            11009370629370629371,
            dpt);

        doExchange(sellToken, uint(-1), cdc, uint(-1));
    }

    function testGetCostsBuyCdcTakeProfitOnlyDptNotEnoughDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(true)), b(""));


        userDpt = 0.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        (uint sellAmt_, uint feeDpt_, uint256 feeV_, uint256 feeSellT_) = DiamondExchangeExtension(dee).getCosts(user, dai, 0, cdc, uint(-1));

        assertEqDustLog("expected sell amount adds up",
            sellAmt_,
            69925454545454545455,
            cdc);

        assertEqDustLog("expected dpt fee adds up",
            feeDpt_,
            812000000000000000,
            dpt);

        assertEqDustLog("expected fee value adds up",
            feeV_,
            152181818181818181819,
            dpt);

        assertEqDustLog("expected fee in sellTkns adds up",
            feeSellT_,
            11393986013986013986,
            dpt);

        doExchange(sellToken, uint(-1), cdc, uint(-1));
    }

    function testGetCostsBuyCdcTakeAllCostsInDptDptEnoughDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));


        userDpt = 5.49 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        (uint sellAmt_, uint feeDpt_, uint256 feeV_, uint256 feeSellT_) = DiamondExchangeExtension(dee).getCosts(user, dai, 0, cdc, uint(-1));

        assertEqDustLog("expected sell amount adds up",
            sellAmt_,
            68126223776223776224,
            cdc);

        assertEqDustLog("expected dpt fee adds up",
            feeDpt_,
            5490000000000000000,
            dpt);

        assertEqDustLog("expected fee value adds up",
            feeV_,
            152181818181818181819,
            dpt);

        assertEqDustLog("expected fee in sellTkns adds up",
            feeSellT_,
            9594755244755244755,
            dpt);

        doExchange(sellToken, uint(-1), cdc, uint(-1));
    }

    function testGetCostsBuyCdcTakeAllCostsInDptDptNotEnoughDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));


        userDpt = 5.3 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        (uint sellAmt_, uint feeDpt_, uint256 feeV_, uint256 feeSellT_) = DiamondExchangeExtension(dee).getCosts(user, dai, 0, cdc, uint(-1));

        assertEqDustLog("expected sell amount adds up",
            sellAmt_,
            68199300699300699301,
            cdc);

        assertEqDustLog("expected dpt fee adds up",
            feeDpt_,
            5300000000000000000,
            dpt);

        assertEqDustLog("expected fee value adds up",
            feeV_,
            152181818181818181819,
            dpt);

        assertEqDustLog("expected fee in sellTkns adds up",
            feeSellT_,
            9667832167832167832,
            dpt);

        doExchange(sellToken, uint(-1), cdc, uint(-1));
    }

    function testGetCostsBuyFixCdcTakeProfitOnlyDptEnoughDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(true)), b(""));


        userDpt = 1.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint buyAmt = 10 ether;
        (uint sellAmt_, uint feeDpt_, uint256 feeV_, uint256 feeSellT_) = DiamondExchangeExtension(dee).getCosts(user, dai, 0, cdc, buyAmt);

        assertEqDustLog("expected sell amount adds up",
            sellAmt_,
            6138461538461538461,
            cdc);

        assertEqDustLog("expected dpt fee adds up",
            feeDpt_,
            840000000000000000,
            dpt);

        assertEqDustLog("expected fee value adds up",
            feeV_,
            14000000000000000000,
            dpt);

        assertEqDustLog("expected fee in sellTkns adds up",
            feeSellT_,
            753846153846153846,
            dpt);

        doExchange(sellToken, uint(-1), cdc, buyAmt);
    }

    function testGetCostsBuyFixCdcTakeProfitOnlyDptNotEnoughDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(true)), b(""));


        userDpt = 0.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint buyAmt = 10 ether;
        (uint sellAmt_, uint feeDpt_, uint256 feeV_, uint256 feeSellT_) = DiamondExchangeExtension(dee).getCosts(user, dai, 0, cdc, buyAmt);

        assertEqDustLog("expected sell amount adds up",
            sellAmt_,
            6149230769230769230,
            cdc);

        assertEqDustLog("expected dpt fee adds up",
            feeDpt_,
            812000000000000000,
            dpt);

        assertEqDustLog("expected fee value adds up",
            feeV_,
            14000000000000000000,
            dpt);

        assertEqDustLog("expected fee in sellTkns adds up",
            feeSellT_,
            764615384615384615,
            dpt);

        doExchange(sellToken, uint(-1), cdc, buyAmt);
    }

    function testGetCostsBuyFixCdcTakeAllCostsInDptDptEnoughDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));


        userDpt = 5.49 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint buyAmt = 10 ether;
        (uint sellAmt_, uint feeDpt_, uint256 feeV_, uint256 feeSellT_) = DiamondExchangeExtension(dee).getCosts(user, dai, 0, cdc, buyAmt);

        assertEqDustLog("expected sell amount adds up",
            sellAmt_,
            5384615384615384615,
            cdc);

        assertEqDustLog("expected dpt fee adds up",
            feeDpt_,
            2800000000000000000,
            dpt);

        assertEqDustLog("expected fee value adds up",
            feeV_,
            14000000000000000000,
            dpt);

        assertEqDustLog("expected fee in sellTkns adds up",
            feeSellT_,
            0,
            dpt);

        doExchange(sellToken, uint(-1), cdc, buyAmt);
    }

    function testGetCostsBuyFixCdcTakeAllCostsInDptDptNotEnoughDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));


        userDpt = 2.3 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint buyAmt = 10 ether;
        (uint sellAmt_, uint feeDpt_, uint256 feeV_, uint256 feeSellT_) = DiamondExchangeExtension(dee).getCosts(user, dai, 0, cdc, buyAmt);

        assertEqDustLog("expected sell amount adds up",
            sellAmt_,
            5576923076923076923,
            cdc);

        assertEqDustLog("expected dpt fee adds up",
            feeDpt_,
            2300000000000000000,
            dpt);

        assertEqDustLog("expected fee value adds up",
            feeV_,
            14000000000000000000,
            dpt);

        assertEqDustLog("expected fee in sellTkns adds up",
            feeSellT_,
            192307692307692308,
            dpt);

        doExchange(sellToken, uint(-1), cdc, buyAmt);
    }

    function testGetCostsSellDpassBuyFixCdcTakeAllCostsInDptDptNotEnoughDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));
        DiamondExchange(exchange).setConfig(b("canSellErc721"), b(dpass), b(true));
        SimpleAssetManagement(asm).setConfig("payTokens",b(dpass), b(true), "diamonds");
        DiamondExchangeTester(user).doApprove721(dpass, exchange, dpassId[user]);


        userDpt = 2.3 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dpass;
        uint buyAmt = 10 ether;
        (uint sellAmt_, uint feeDpt_, uint256 feeV_, uint256 feeSellT_) = DiamondExchangeExtension(dee).getCosts(user, sellToken, dpassId[user], cdc, buyAmt);

        assertEqLog("expected sell amount adds up",
            sellAmt_,
            1);

        assertEqDustLog("expected dpt fee adds up",
            feeDpt_,
            2300000000000000000,
            dpt);

        assertEqDustLog("expected fee value adds up",
            feeV_,
            14000000000000000000,
            dpt);

        assertEqDustLog("expected fee in sellTkns adds up",
            feeSellT_,
            0,
            dpt);

        doExchange(dpass, dpassId[user], cdc, buyAmt);
    }

    function testRedeemFeeTokenDex() public {
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

        DiamondExchange(exchange)
        .redeem
        .value(ethRedeem)
        (
            dpass,
            dpassId[seller],
            eth,
            ethRedeem,
            seller
        );

        // balances after redeem are tested in src/Redeemer.t.sol
    }

    function testFailRedeemFeeTokenDex() public {
        //error Revert ("dex-token-not-to-pay-redeem-fee")
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

        DiamondExchange(exchange)
        .redeem
        .value(ethRedeem)
        (
            dpass,
            dpassId[seller],
            eth,
            ethRedeem,
            seller
        );
    }

    function testFailForFixEthBuyFixCdcUserDptNotZeroNotEnoughSmallDex() public {
        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 17.79 ether;

        DiamondExchange(exchange).setConfig("small", b(eth), b(sellAmtOrId + 1));
        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testForFixEthBuyFixCdcUserDptNotZeroNotEnoughSmallDex() public {
        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 17.79 ether;

        DiamondExchange(exchange).setConfig("smallest", b(eth), b(sellAmtOrId));
        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }
}
