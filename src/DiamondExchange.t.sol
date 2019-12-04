pragma solidity ^0.5.11;

import "ds-test/test.sol";
import "ds-auth/auth.sol";
import "ds-math/math.sol";
import "ds-token/token.sol";
import "ds-guard/guard.sol";
import "cdc-token/Cdc.sol";
import "dpass/Dpass.sol";
import "./DiamondExchange.sol";
import "./Burner.sol";
import "./Wallet.sol";
import "./SimpleAssetManagement.sol";

contract DiamondExchangeTest is DSTest, DSMath, DiamondExchangeEvents, Wallet {
    event LogUintIpartUintFpart(bytes32 key, uint val, uint val1);
    event LogTest(uint256 what);
    event LogTest(bool what);
    event LogTest(address what);
    event LogTest(bytes32 what);

    uint public constant SUPPLY = (10 ** 10) * (10 ** 18);
    uint public constant INITIAL_BALANCE = 1000 ether;

    address public cdc;                                                     // Cdc()
    address public dpass;                                                   // Dpass()
    address public dpass1;                                                  // Dpass()
    address public dpt;                                                     // DSToken()
    address public dai;                                                     // DSToken()
    address public eth;
    address public eng;
    address payable public exchange;                                        // DiamondExchange()

    address payable public liq;                                             // DiamondExchangeTester()
    address payable public wal;                                             // DptTester()
    address payable public asm;                                             // SimpleAssetManagement()
    address payable public user;                                            // DiamondExchangeTester()
    address payable public seller;                                          // DiamondExchangeTester()

    address payable public burner;                                          // Burner()
    address payable public fca;                                             // TestFeeCalculator()

    // test variables
    mapping(address => mapping(address => uint)) public balance;
    mapping(address => mapping(uint => uint)) public usdRateDpass;
    mapping(address => uint) public usdRate;
    mapping(address => address) feed;                                       // address => TestFeedLike()
    mapping(address => address payable) custodian20;
    mapping(address => uint8) public decimals;
    mapping(address => bool) public decimalsSet;
    mapping(address => uint) public dpassId;
    mapping(address => bool) public erc20;                                  // tells if token is ERC20 ( eth considered ERC20 here)
    mapping(address => uint) dust;
    mapping(address => bool) dustSet;
    mapping(address => uint) public dpassOwnerPrice;

    uint public fixFee = 0 ether;
    uint public varFee = .2 ether;                                          // variable fee is 20% of value
    uint public profitRate = .3 ether;                                      // profit rate 30%
    bool public takeProfitOnlyInDpt = true;                                 // take only profit or total fee (cost + profit) in DPT

    // variables for calculating expected behaviour --------------------------
    address origBuyer;
    uint userDpt;
    uint feeDpt;
    uint feeSellTokenT;
    uint restOfFeeT;
    uint restOfFeeV;
    uint restOfFeeDpt;
    uint feeV;
    uint buySellTokenT;
    uint sentV;
    uint profitV;
    uint profitDpt;
    uint feeSpentDpt;
    uint profitSellTokenT;
    uint expectedBalance;
    uint feeSpentDptV;
    uint finalSellV;
    uint finalBuyV;
    uint finalSellT;
    uint finalBuyT;
    uint userDptV;
    uint balanceUserIncreaseT;
    uint balanceUserIncreaseV;
    uint balanceUserDecreaseT;
    uint balanceUserDecreaseV;
    uint actual;
    uint expected;
    address actualA;
    address expectedA;
    bool showActualExpected;
    DSGuard public guard;
    bytes32 constant public ANY = bytes32(uint(-1));
    address origSellerBuyToken;
    address origSellerSellToken;

    function setUp() public {
        _createTokens();
        _setErc20Tokens();
        _mintInitialSupply();
        _setUsdRates();
        _setDecimals();
        _setDust();
        _setFeeds();
        _createContracts();
        _createActors();
        _setupGuard();
        _setupCustodian20();
        _setConfigAsm();
        _setConfigExchange();
        _approveContracts();
        _mintDpasses();
        _transferToUserAndApproveExchange();
        _storeInitialBalances();
        _logContractAddresses();
    }

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
        assertTrue(DiamondExchange(exchange).getManualRate(dpt));
        DiamondExchange(exchange).setConfig(b("manualRate"), b(dpt), b(false));
        assertTrue(!DiamondExchange(exchange).getManualRate(dpt));
    }

    function testSetManualCdcRateDex() public {
        DiamondExchange(exchange).setConfig(b("manualRate"), b(cdc), b(true));
        assertTrue(DiamondExchange(exchange).getManualRate(cdc));
        DiamondExchange(exchange).setConfig(b("manualRate"), b(cdc), b(false));
        assertTrue(!DiamondExchange(exchange).getManualRate(cdc));
    }

    function testSetManualEthRateDex() public {
        DiamondExchange(exchange).setConfig(b("manualRate"), b(address(0xee)), b(true));
        assertTrue(DiamondExchange(exchange).getManualRate(address(0xee)));
        DiamondExchange(exchange).setConfig(b("manualRate"), b(address(0xee)), b(false));
        assertTrue(!DiamondExchange(exchange).getManualRate(address(0xee)));
    }

    function testSetManualDaiRateDex() public {
        DiamondExchange(exchange).setConfig(b("manualRate"), b(dai), b(true));
        assertTrue(DiamondExchange(exchange).getManualRate(dai));
        DiamondExchange(exchange).setConfig(b("manualRate"), b(dai), b(false));
        assertTrue(!DiamondExchange(exchange).getManualRate(dai));
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

        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 13.94 ether;                                 // the minimum value user has to pay

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

    function testGetDiamondInfoDex() public {
        address[2] memory ownerCustodian;
        bytes32[6] memory attrs;
        uint24 carat;
        uint price;
        (ownerCustodian, attrs, carat, price) = DiamondExchange(exchange).getDiamondInfo(dpass, dpassId[user]);

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

        (ownerCustodian, attrs, carat, price) = DiamondExchange(exchange).getDiamondInfo(dpass, dpassId[seller]);

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

    function testGetBuyPriceAndSetBuyPriceDex() public {
        uint buyPrice = 43 ether;
        uint otherBuyPrice = 47 ether;

        DiamondExchangeTester(user)
            .doSetBuyPrice(dpass, dpassId[user], buyPrice);

        assertEqLog(
            "setBuyPrice() actually set",
            DiamondExchange(exchange).getBuyPrice(dpass, dpassId[user]),
            buyPrice);

        DiamondExchangeTester(seller)
            .doSetBuyPrice(dpass, dpassId[user], otherBuyPrice);            // anyone can set sell price, but it will only be effective, if they own the token

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

    function testDenyTokenDex() public {
        DiamondExchange(exchange).setDenyToken(cdc, true);
        DiamondExchange(exchange).setDenyToken(cdc, false);

        testForFixCdcBuyUserDpassUserHasNoDptDex();
    }

    function testSellerAcceptsToken() public {
        DiamondExchange(exchange).setDenyToken(cdc, true);
        assertTrue(
            !DiamondExchange(exchange).sellerAcceptsToken(cdc, address(this)));
        DiamondExchange(exchange).setDenyToken(cdc, false);
        assertTrue(
            DiamondExchange(exchange).sellerAcceptsToken(cdc, address(this)));
    }

    function testIsHandledByAsm() public {
        assertTrue(DiamondExchange(exchange).isHandledByAsm(cdc));
        DiamondExchange(exchange).setConfig("handledByAsm", b(cdc), b(false));
        assertTrue(!DiamondExchange(exchange).isHandledByAsm(cdc));
    }

    function testSetPriceFeedDex() public {
        // error Revert ("dex-wrong-pricefeed-address")
        address token = eth;
        DiamondExchange(exchange).setConfig(b("priceFeed"), b(token), b(address(feed[token])));
        assertEqLog(
            "set-pricefeed-is-returned",
            address(DiamondExchange(exchange).getPriceFeed(token)),
            address(feed[token]));

        token = dai;
        DiamondExchange(exchange).setConfig(b("priceFeed"), b(token), b(address(feed[token])));
        assertEqLog(
            "set-pricefeed-is-returned",
            address(DiamondExchange(exchange).getPriceFeed(token)),
            address(feed[token]));

        token = cdc;
        DiamondExchange(exchange).setConfig(b("priceFeed"), b(token), b(address(feed[token])));
        assertEqLog(
            "set-pricefeed-is-returned",
            address(DiamondExchange(exchange).getPriceFeed(token)),
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
        assertTrue(DiamondExchange(exchange).getDecimalsSet(cdc));
        address token1 = address(new DSToken("TEST"));
        assertTrue(!DiamondExchange(exchange).getDecimalsSet(token1));
        DiamondExchange(exchange).setConfig("decimals",b(token1), b(18));
        assertTrue(DiamondExchange(exchange).getDecimalsSet(token1));
    }

    function testGetCustodian20() public {
        assertEqLog(
            "default custodian is asm",
            DiamondExchange(exchange).getCustodian20(cdc),
            custodian20[cdc]
        );
        address token1 = address(new DSToken("TEST"));
        assertEqLog(
            "any token custodian is unset",
            DiamondExchange(exchange).getCustodian20(token1),
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
        (uint sellAmt_, uint feeDpt_) = DiamondExchange(exchange).getCosts(user, cdc, 0, dpass, dpassId[seller]);

        assertEqDustLog("expected sell amount adds up",
            sellAmt_,
            22311428571428571429,
            cdc);

        assertEqDustLog("expected dpt fee adds up",
            feeDpt_,
            1644000000000000000,
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
        (uint sellAmt_, uint feeDpt_) = DiamondExchange(exchange).getCosts(user, cdc, 0, dpass, dpassId[seller]);

        assertEqDustLog("expected sell amount adds up",
            sellAmt_,
            22905714285714285715,
            cdc);

        assertEqDustLog("expected dpt fee adds up",
            feeDpt_,
            812000000000000000,
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
        (uint sellAmt_, uint feeDpt_) = DiamondExchange(exchange).getCosts(user, cdc, 0, dpass, dpassId[seller]);

        assertEqDustLog("expected sell amount adds up",
            sellAmt_,
            19571428571428571429,
            cdc);

        assertEqDustLog("expected dpt fee adds up",
            feeDpt_,
            5480000000000000000,
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
        (uint sellAmt_, uint feeDpt_) = DiamondExchange(exchange).getCosts(user, cdc, 0, dpass, dpassId[seller]);

        assertEqDustLog("expected sell amount adds up",
            sellAmt_,
            19700000000000000000,
            cdc);

        assertEqDustLog("expected dpt fee adds up",
            feeDpt_,
            5300000000000000000,
            dpt);

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }
 
    function testFailGetCostsUserZeroDex() public view{
        // error Revert ("dex-user-address-zero")
        (uint sellAmt_, uint feeDpt_) = DiamondExchange(exchange).getCosts(address(0), cdc, 0, dpass, dpassId[seller]);
        sellAmt_ = sellAmt_ + feeDpt_; // this is just to suppress warning
    }

    function testFailGetCostsSellTokenInvalidDex() public view{
        // error Revert ("dex-selltoken-invalid")
        (uint sellAmt_, uint feeDpt_) = DiamondExchange(exchange).getCosts(user, address(0xffffff), 0, dpass, dpassId[seller]);
        sellAmt_ = sellAmt_ + feeDpt_; // this is just to suppress warning
    }

    function testFailGetCostsBuyTokenInvalidDex() public view {
        // error Revert ("dex-buytoken-invalid")
        (uint sellAmt_, uint feeDpt_) = DiamondExchange(exchange).getCosts(address(0), cdc, 0, address(0xffeeff), dpassId[seller]);
        sellAmt_ = sellAmt_ + feeDpt_; // this is just to suppress warning
    }

    function testFailGetCostsBothTokensDpassDex() public view {
        // error Revert ("dex-both-tokens-dpass")
        (uint sellAmt_, uint feeDpt_) = DiamondExchange(exchange).getCosts(user, dpass, 0, dpass, dpassId[seller]);
        sellAmt_ = sellAmt_ + feeDpt_; // this is just to suppress warning
    }

    function testGetCostsBuyCdcTakeProfitOnlyDptEnoughDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(true)), b(""));


        userDpt = 1.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        (uint sellAmt_, uint feeDpt_) = DiamondExchange(exchange).getCosts(user, dai, 0, cdc, uint(-1));

        assertEqDustLog("expected sell amount adds up",
            sellAmt_,
            10921678321678321679,
            cdc);

        assertEqDustLog("expected dpt fee adds up",
            feeDpt_,
            1494545454545454545,
            dpt);

        doExchange(sellToken, uint(-1), cdc, uint(-1));
    }

    function testGetCostsBuyCdcTakeProfitOnlyDptNotEnoughDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(true)), b(""));


        userDpt = 0.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        (uint sellAmt_, uint feeDpt_) = DiamondExchange(exchange).getCosts(user, dai, 0, cdc, uint(-1));

        assertEqDustLog("expected sell amount adds up",
            sellAmt_,
            11184195804195804196,
            cdc);

        assertEqDustLog("expected dpt fee adds up",
            feeDpt_,
            812000000000000000,
            dpt);

        doExchange(sellToken, uint(-1), cdc, uint(-1));
    }

    function testGetCostsBuyCdcTakeAllCostsInDptDptEnoughDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));


        userDpt = 5.49 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        (uint sellAmt_, uint feeDpt_) = DiamondExchange(exchange).getCosts(user, dai, 0, cdc, uint(-1));

        assertEqDustLog("expected sell amount adds up",
            sellAmt_,
            9580419580419580420,
            cdc);

        assertEqDustLog("expected dpt fee adds up",
            feeDpt_,
            4981818181818181818,
            dpt);

        doExchange(sellToken, uint(-1), cdc, uint(-1));
    }

    function testGetCostsBuyCdcTakeAllCostsInDptDptNotEnoughDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));


        userDpt = 5.3 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        (uint sellAmt_, uint feeDpt_) = DiamondExchange(exchange).getCosts(user, dai, 0, cdc, uint(-1));

        assertEqDustLog("expected sell amount adds up",
            sellAmt_,
            9580419580419580420,
            cdc);

        assertEqDustLog("expected dpt fee adds up",
            feeDpt_,
            4981818181818181818,
            dpt);

        doExchange(sellToken, uint(-1), cdc, uint(-1));
    }

    function testGetCostsBuyFixCdcTakeProfitOnlyDptEnoughDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(true)), b(""));


        userDpt = 1.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint buyAmt = 10 ether;
        (uint sellAmt_, uint feeDpt_) = DiamondExchange(exchange).getCosts(user, dai, 0, cdc, buyAmt);

        assertEqDustLog("expected sell amount adds up",
            sellAmt_,
            6138461538461538461,
            cdc);

        assertEqDustLog("expected dpt fee adds up",
            feeDpt_,
            840000000000000000,
            dpt);

        doExchange(sellToken, uint(-1), cdc, buyAmt);
    }

    function testGetCostsBuyFixCdcTakeProfitOnlyDptNotEnoughDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(true)), b(""));


        userDpt = 0.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint buyAmt = 10 ether;
        (uint sellAmt_, uint feeDpt_) = DiamondExchange(exchange).getCosts(user, dai, 0, cdc, buyAmt);

        assertEqDustLog("expected sell amount adds up",
            sellAmt_,
            6149230769230769230,
            cdc);

        assertEqDustLog("expected dpt fee adds up",
            feeDpt_,
            812000000000000000,
            dpt);

        doExchange(sellToken, uint(-1), cdc, buyAmt);
    }

    function testGetCostsBuyFixCdcTakeAllCostsInDptDptEnoughDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));


        userDpt = 5.49 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint buyAmt = 10 ether;
        (uint sellAmt_, uint feeDpt_) = DiamondExchange(exchange).getCosts(user, dai, 0, cdc, buyAmt);

        assertEqDustLog("expected sell amount adds up",
            sellAmt_,
            5384615384615384615,
            cdc);

        assertEqDustLog("expected dpt fee adds up",
            feeDpt_,
            2800000000000000000,
            dpt);

        doExchange(sellToken, uint(-1), cdc, buyAmt);
    }

    function testGetCostsBuyFixCdcTakeAllCostsInDptDptNotEnoughDex() public {
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(false)), b(""));


        userDpt = 2.3 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint buyAmt = 10 ether;
        (uint sellAmt_, uint feeDpt_) = DiamondExchange(exchange).getCosts(user, dai, 0, cdc, buyAmt);

        assertEqDustLog("expected sell amount adds up",
            sellAmt_,
            5576923076923076923,
            cdc);

        assertEqDustLog("expected dpt fee adds up",
            feeDpt_,
            2300000000000000000,
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
        (uint sellAmt_, uint feeDpt_) = DiamondExchange(exchange).getCosts(user, sellToken, dpassId[user], cdc, buyAmt);

        assertEqLog("expected sell amount adds up",
            sellAmt_,
            1);

        assertEqDustLog("expected dpt fee adds up",
            feeDpt_,
            2120000000000000000,
            dpt);

        doExchange(sellToken, dpassId[user], cdc, buyAmt);
    }
//------------------end-of-tests------------------------------------

    function createDiamond(uint price_) public {
        uint id_;
        Dpass(dpass).setCccc("BR,VVS1,G,10.00", true);
        id_ = Dpass(dpass).mintDiamondTo(
            asm,                                                                // address _to,
            seller,                                                             // address _custodian,
            "gia",                                                              // bytes32 _issuer,
            "44444444",                                                         // bytes32 _report,
            "sale",                                                             // bytes32 _state,
            "BR,VVS1,G,10.00",
            10.1 * 100,
            bytes32(0xac5c1daab5131326b23d7f3a4b79bba9f236d227338c5b0fb17494defc319886), // bytes32 _attributesHash
            "20191101"
        );

        SimpleAssetManagement(asm).setBasePrice(dpass, id_, price_);
    }

    function sendSomeCdcToUser() public {
        createDiamond(500000 ether);
        SimpleAssetManagement(asm).mint(cdc, user, wdiv(
            add(
                wdiv(
                    dpassOwnerPrice[asm],
                    sub(1 ether, varFee)),
                fixFee),
            usdRate[cdc]));
        balance[user][cdc] = DSToken(cdc).balanceOf(user);
    }

    function sendSomeCdcToUser(uint256 amt) public {
        createDiamond(500000 ether);
        require(amt <= SimpleAssetManagement(asm).getAmtForSale(cdc), "test-can-not-mint-that-much");
        SimpleAssetManagement(asm).mint(cdc, user, amt);
        balance[user][cdc] = DSToken(cdc).balanceOf(user);
    }

    function balanceOf(address token, address holder) public view returns (uint256) {
        return token == eth ? holder.balance :  DSToken(token).balanceOf(holder);
    }

    function doExchange(address sellToken, uint256 sellAmtOrId, address buyToken, uint256 buyAmtOrId) public {
        uint origUserBalanceT;
        uint buyT;
        uint buyV;
        bool _takeProfitOnlyInDpt = DiamondExchange(exchange).takeProfitOnlyInDpt();
        uint fixFee_;
        uint varFee_;
        origSellerBuyToken = erc20[buyToken] ? address(0) : Dpass(buyToken).ownerOf(buyAmtOrId);
        origSellerSellToken = erc20[sellToken] ? address(0) : Dpass(sellToken).ownerOf(sellAmtOrId);

        origUserBalanceT = balanceOf(sellToken, user);

        sentV = sellAmtOrId == uint(-1) ?                                               // sent value in fiat currency
            wmulV(origUserBalanceT, usdRate[sellToken], sellToken) :
            erc20[sellToken] ?
                wmulV(min(sellAmtOrId, origUserBalanceT), usdRate[sellToken], sellToken) :
                dpassOwnerPrice[origSellerSellToken];

        buyT = erc20[buyToken] ?                                                        // total amount of token available to buy (or tokenid)
            DiamondExchange(exchange).isHandledByAsm(buyToken) ?
                min(buyAmtOrId, SimpleAssetManagement(asm).getAmtForSale(buyToken)) :
                min(
                    buyAmtOrId,
                    balanceOf(buyToken, custodian20[buyToken])) :
            buyAmtOrId;

        buyV = erc20[buyToken] ?                                                        // total value of tokens available to buy (or tokenid)
            wmulV(buyT, usdRate[buyToken], buyToken) :
            DiamondExchange(exchange).getPrice(buyToken, buyAmtOrId);

        buySellTokenT = erc20[sellToken] ?                                              // the amount of sellToken to pay for buy token
            wdivT(buyV, usdRate[sellToken], sellToken) :
            0;

        fixFee_ = DiamondExchange(exchange).fixFee();
        varFee_ = DiamondExchange(exchange).varFee();

        feeV = add(
            wmul(
                varFee_,
                min(sentV, buyV)),
            fixFee_);                                        // fiat value in fiat

        feeDpt = wdivT(feeV, usdRate[dpt], dpt);                                        // the amount of DPT tokens to pay for fee

        feeSellTokenT = erc20[sellToken] ?                                              // amount of sell token to pay for fee
            wdivT(feeV, usdRate[sellToken], sellToken) :
            0;

        profitV = wmul(feeV, profitRate);                                               // value of total profit in fiat

        profitDpt = wdivT(profitV, usdRate[dpt], dpt);                                  // total amount of DPT to pay for profit

        feeSpentDpt = sellToken == dpt ?
            0 :
            _takeProfitOnlyInDpt ?
                min(userDpt, wdivT(profitV, usdRate[dpt], dpt)) :
                min(userDpt, wdivT(feeV, usdRate[dpt], dpt));

        feeSpentDptV = wmulV(feeSpentDpt, usdRate[dpt], dpt);

        profitSellTokenT = erc20[sellToken] ?                                           // total amount of sellToken to pay for profit
            wdivT(profitV, usdRate[sellToken], sellToken) :
            0;

        if (feeSpentDpt < feeDpt) {

            restOfFeeV = wmulV(sub(feeDpt, feeSpentDpt), usdRate[dpt], dpt);            // fee that remains after paying (part of) it with user DPT

            restOfFeeDpt = sub(feeDpt, feeSpentDpt);                                    // fee in DPT that remains after paying (part of) with DPT

            restOfFeeT = erc20[sellToken] ?
                wdivT(restOfFeeV, usdRate[sellToken], sellToken) :
                wdivT(restOfFeeV, usdRate[buyToken], buyToken) ;                                                                      // amount of sellToken or buyToken to pay for remaining fee
        }

        finalSellV = sentV;
        finalBuyV = buyV;

        if (sentV - restOfFeeV >= buyV) {

            finalSellV = add(buyV, restOfFeeV);

        } else {

            finalBuyV = sub(sentV, restOfFeeV);
        }

        finalSellT = erc20[sellToken] ?
            wdivT(finalSellV, usdRate[sellToken], sellToken) :
            0;

        finalBuyT = erc20[buyToken] ?
            wdivT(finalBuyV, usdRate[buyToken], buyToken) :
            0;

            emit LogTest("user.balance");
            emit LogTest(user.balance);

        if(erc20[buyToken]) {
            origBuyer = DiamondExchange(exchange).isHandledByAsm(buyToken) ? asm : custodian20[buyToken];
        } else {
            origBuyer = Dpass(buyToken).ownerOf(buyAmtOrId);
        }

        DiamondExchangeTester(user).doBuyTokensWithFee(
            sellToken,
            sellAmtOrId,
            buyToken,
            buyAmtOrId
        );

        userDptV = wmulV(userDpt, usdRate[dpt], dpt);

        balanceUserIncreaseT = erc20[buyToken] ?
            sub(
                balanceOf(buyToken, user) ,
                balance[user][buyToken]) :
            1;

        balanceUserIncreaseV = erc20[buyToken] ?
            wmulV(
                balanceUserIncreaseT,
                usdRate[buyToken],
                buyToken) :
            dpassOwnerPrice[origSellerBuyToken];

        balanceUserDecreaseT = erc20[sellToken] ?
            sub(
                balance[user][sellToken],
                balanceOf(sellToken, user)) :
            1;

        balanceUserDecreaseV = erc20[sellToken] ?
            wmulV(
                balanceUserDecreaseT,
                usdRate[sellToken],
                sellToken) :
            dpassOwnerPrice[origSellerSellToken];

        emit log_named_uint("---------takeProfitOnlyInDpt", takeProfitOnlyInDpt ? 1 : 0);
        emit log_named_bytes32("----------------sellToken", getName(sellToken));
        logUint("----------sellAmtOrId", sellAmtOrId, 18);
        emit log_named_bytes32("-----------------buyToken", getName(buyToken));
        logUint("-----------buyAmtOrId", buyAmtOrId, 18);
        emit log_bytes32(bytes32("------------------------------"));
        logUint("---------------sentV", sentV, 18);
        logUint("---------------buyV:", buyV, 18);
        logUint("------buySellTokenT:", buySellTokenT, 18);
        logUint("-----feeFixV(fixFee)", fixFee_, 18);
        logUint("-----feeRate(varFee)", varFee_, 18);
        logUint("---------feeV(total)", feeV, 18);
        logUint("-------feeDpt(total)", feeDpt, 18);
        logUint("----------feeT(tot.)", feeSellTokenT, 18);
        logUint("-------------userDpt", userDpt, 18);
        logUint("------------userDptV", userDptV, 18);
        emit log_bytes32(bytes32("------------------------------"));
        logUint("----------profitRate", profitRate, 18);
        logUint("-------------profitV", profitV, 18);
        logUint("-----------profitDpt", profitDpt, 18);
        logUint("-------------profitT", profitSellTokenT, 18);
        logUint("---------feeSpentDpt", feeSpentDpt, 18);
        logUint("--------feeSpentDptV", feeSpentDptV, 18);
        logUint("----------restOfFeeV", restOfFeeV, 18);
        logUint("--------restOfFeeDpt", restOfFeeDpt, 18);
        logUint("----------restOfFeeT", restOfFeeT, 18);
        logUint("balanceUserIncreaseT", balanceUserIncreaseT, 18);
        logUint("balanceUserIncreaseV", balanceUserIncreaseV, 18);
        logUint("balanceUserDecreaseT", balanceUserDecreaseT, 18);
        logUint("balanceUserDecreaseV", balanceUserDecreaseV, 18);

        // DPT (eq fee in USD) must be sold from: liq balance
        actual = sub(INITIAL_BALANCE, DSToken(dpt).balanceOf(address(liq)));
        expected = sellToken == dpt ? 0 : sub(profitDpt, _takeProfitOnlyInDpt ? feeSpentDpt : wmul(feeSpentDpt, profitRate));

        assertEqDustLog("dpt from liq", actual, expected, dpt);

        // ETH for DPT fee must be sent to wallet balance from user balance
        if(erc20[sellToken]) {
            actual = balanceOf(sellToken, address(wal));
            expected = add(balance[wal][sellToken], sub(restOfFeeT, sellToken == dpt ? profitSellTokenT : 0));
        } else {
            actual = balanceOf(buyToken, address(wal));
            expected = add(balance[wal][buyToken], sub(restOfFeeT, buyToken == dpt ? profitSellTokenT : 0));
        }
        assertEqDustLog("sell/buy token as fee to wal", actual, expected, sellToken);

        // DPT fee have to be transfered to burner
        actual = DSToken(dpt).balanceOf(burner);
        expected = profitDpt;

        assertEqDustLog("dpt to burner", actual, expected, dpt);

        // custodian balance of tokens sold by user must increase
        if (erc20[sellToken]) {

            actual = balanceOf(sellToken, origBuyer);

            expected = add(
                balance[origBuyer][sellToken],
                sellToken == cdc && origBuyer == asm ? 0 : sub(finalSellT, restOfFeeT));

            assertEqDustLog("seller bal inc by ERC20 sold", actual, expected, sellToken);
        } else {

            actualA = TrustedErc721(sellToken).ownerOf(sellAmtOrId);

            expectedA = Dpass(sellToken).ownerOf(sellAmtOrId);

            assertEqLog("seller bal inc by ERC721 sold", actualA, expectedA);
        }

        // user balance of tokens sold must decrease
        if (erc20[sellToken]) {

            actual = balanceOf(sellToken, user);

            expected = sub( balance[user][sellToken], finalSellT);

            assertEqDustLog("user bal dec by ERC20 sold", actual, expected, sellToken);

        } else {

            actualA = Dpass(sellToken).ownerOf(sellAmtOrId);

            expectedA = user;

            assertNotEqualLog("user not owner of ERC721 sold", actualA, expectedA);
        }

        // user balance of tokens bought must increase
        if (erc20[buyToken]) {

            actual = balanceOf(buyToken, user);

            expected = add(balance[user][buyToken], finalBuyT);

            assertEqDustLog("user bal inc by ERC20 bought", actual, expected, buyToken);

        } else {
            actualA = Dpass(buyToken).ownerOf(buyAmtOrId);
            expectedA = user;
            assertEqLog("user has the ERC721 bought", actualA, expectedA);
        }

        // tokens bought by user must decrease custodian account
        if (erc20[buyToken]) {

            if(DiamondExchange(exchange).isHandledByAsm(buyToken) ) {
                actual = DSToken(buyToken).balanceOf(asm);
                expected = balance[asm][buyToken];

                assertEqDustLog("seller bal dec by ERC20 bought", actual, expected, buyToken);
            } else {

                actual = balanceOf(buyToken, custodian20[buyToken]);

                expected = sub(
                    balance[custodian20[buyToken]][buyToken],
                    add(balanceUserIncreaseT, !erc20[sellToken] ? restOfFeeT : 0));

                assertEqDustLog("seller bal dec by ERC20 bought", actual, expected, buyToken);
            }
        } else {

            actualA = Dpass(buyToken).ownerOf(buyAmtOrId);
            expectedA = user;

            assertEqLog("seller bal dec by ERC721 bought", actualA, expectedA);

        }

        // make sure fees and tokens sent and received add up
        actual = add(balanceUserIncreaseV, feeV);
        expected = add(balanceUserDecreaseV, feeSpentDptV);

        assertEqDustLog("fees and tokens add up", actual, expected);
    }

    function logMsgActualExpected(bytes32 logMsg, uint256 actual_, uint256 expected_, bool showActualExpected_) public {
        emit log_bytes32(logMsg);
        if(showActualExpected_ || showActualExpected) {
            emit log_bytes32("actual");
            emit LogTest(actual_);
            emit log_bytes32("expected");
            emit LogTest(expected_);
        }
    }

    function logMsgActualExpected(bytes32 logMsg, address actual_, address expected_, bool showActualExpected_) public {
        emit log_bytes32(logMsg);
        if(showActualExpected_ || showActualExpected) {
            emit log_bytes32("actual");
            emit LogTest(actual_);
            emit log_bytes32("expected");
            emit LogTest(expected_);
        }
    }

    function assertEqDustLog(bytes32 logMsg, uint256 actual_, uint256 expected_, address decimalToken) public {
        logMsgActualExpected(logMsg, actual_, expected_, !isEqualDust(actual_, expected_, decimalToken));
        assertEqDust(actual_, expected_, decimalToken);
    }

    function assertEqDustLog(bytes32 logMsg, uint256 actual_, uint256 expected_) public {
        logMsgActualExpected(logMsg, actual_, expected_, !isEqualDust(actual_, expected_));
        assertEqDust(actual_, expected_);
    }

    function assertEqLog(bytes32 logMsg, uint actual_, uint expected_) public {
        logMsgActualExpected(logMsg, actual_, expected_, false);
        assertEq(actual_, expected_);
    }
    function assertEqLog(bytes32 logMsg, address actual_, address expected_) public {
        logMsgActualExpected(logMsg, actual_, expected_, false);
        assertEq(actual_, expected_);
    }

    function assertNotEqualLog(bytes32 logMsg, address actual_, address expected_) public {
        logMsgActualExpected(logMsg, actual_, expected_, actual_ == expected_);
        assertTrue(actual_ != expected_);
    }

    function b(bytes32 a) public pure returns(bytes32) {
        return a;
    }

    function b(address a) public pure returns(bytes32) {
        return bytes32(uint(a));
    }

    function b(uint a) public pure returns(bytes32) {
        return bytes32(a);
    }

    function b(bool a_) public pure returns(bytes32) {
        return a_ ? bytes32(uint(1)) : bytes32(uint(0));
    }

    /*
    * @dev Compare two numbers with round-off errors considered.
    * Assume that the numbers are 18 decimals precision.
    */
    function assertEqDust(uint a_, uint b_) public {
        assertEqDust(a_, b_, eth);
    }

    /*
    * @dev Compare two numbers with round-off errors considered.
    * Assume that the numbers have the decimals of token.
    */
    function assertEqDust(uint a_, uint b_, address token) public {
        assertTrue(isEqualDust(a_, b_, token));
    }

    function isEqualDust(uint a_, uint b_) public view returns (bool) {
        return isEqualDust(a_, b_, eth);
    }

    function isEqualDust(uint a_, uint b_, address token) public view returns (bool) {
        uint diff = a_ - b_;
        require(dustSet[token], "Dust limit must be set to token.");
        uint dustT = dust[token];
        return diff < dustT || uint(-1) - diff < dustT;
    }

    function getName(address token) public view returns (bytes32 name) {
        if (token == eth) {
            name = "eth";
        } else if (token == dpt) {
            name = "dpt";
        } else if (token == cdc) {
            name = "cdc";
        } else if (token == dai) {
            name = "dai";
        }  else if (token == eng) {
            name = "dai";
        } else if (token == dpass) {
            name = "dpass";
        } else if (token == dpass1) {
            name = "dpass1";
        }

    }

    function logUint(bytes32 what, uint256 num, uint256 dec) public {
        emit LogUintIpartUintFpart( what, num / 10 ** dec, num % 10 ** dec);
    }

    /*
    * @dev calculates multiple with decimals adjusted to match to 18 decimal precision to express base
    *      token Value
    */
    function wmulV(uint256 a_, uint256 b_, address token_) public view returns(uint256) {
        return wmul(toDecimals(a_, getDecimals(token_), 18), b_);
    }

    /*
    * @dev calculates division with decimals adjusted to match to tokens precision
    */
    function wdivT(uint256 a_, uint256 b_, address token_) public view returns(uint256) {
        return wdiv(a_, toDecimals(b_, 18, getDecimals(token_)));
    }

    /**
    * @dev Retrieve the decimals of a token
    */
    function getDecimals(address token_) public view returns (uint8) {
        require(decimalsSet[token_], "Token with unset decimals");
        return decimals[token_];
    }

    /**
    * @dev Adjusts a number from one precision to another
    */
    function toDecimals(uint256 amt_, uint8 srcDec_, uint8 dstDec_) public pure returns (uint256) {
        if (srcDec_ == dstDec_) return amt_;                                        // no change
        if (srcDec_ < dstDec_) return mul(amt_, 10 ** uint256(dstDec_ - srcDec_));  // add zeros to the right
        return amt_ / 10 ** uint256(srcDec_ - dstDec_);                             // remove digits
    }

    /**
    * @dev Convert address to bytes32
    * @param a address that is converted to bytes32
    * @return bytes32 conversion of address
    */
    function b32(address a) public pure returns (bytes32) {
        return bytes32(uint256(a) << 96);
    }

    /**
    * @dev Convert uint256 to bytes32
    * @param a uint value to be converted
    * @return bytes32 converted value
    */
    function b32(uint a) public pure returns (bytes32) {
        return bytes32(a);
    }

    /**
    * @dev Convert uint256 to bytes32
    * @param a_ bool value to be converted
    * @return bytes32 converted value
    */
    function b32(bool a_) public pure returns (bytes32) {
        return bytes32(uint256(a_ ? 1 : 0));
    }

    function sendToken(address token, address to, uint256 amt) public {
        DSToken(token).transfer(to, amt);
        balance[to][token] = DSToken(token).balanceOf(to);
    }

    function () external payable {
    }

    function _createTokens() internal {
        cdc = address(new Cdc("BR,VS,G,0.05", "CDC"));
        emit log_named_uint("cdc supply", Cdc(cdc).totalSupply());
        dpass = address(new Dpass());
        dpt = address(new DSToken("DPT"));
        dai = address(new DSToken("DAI"));
        eth = address(0xee);
        eng = address(new DSToken("ENG"));   // TODO: make sure it is 8 decimals
    }

    function _setErc20Tokens() internal {
        erc20[cdc] = true;
        erc20[dpt] = true;
        erc20[dai] = true;
        erc20[eng] = true;
        erc20[eth] = true;
    }
    
    function _mintInitialSupply() internal {
        DSToken(dpt).mint(SUPPLY);
        DSToken(dai).mint(SUPPLY);
        DSToken(eng).mint(SUPPLY);
    }
    
    function _setUsdRates() internal {
        usdRate[dpt] = 5 ether;
        usdRate[cdc] = 7 ether;
        usdRate[eth] = 11 ether;
        usdRate[dai] = 13 ether;
        usdRate[eng] = 59 ether;
    }

    function _setDecimals() internal {
        decimals[dpt] = 18;
        decimals[cdc] = 18;
        decimals[eth] = 18;
        decimals[dai] = 18;
        decimals[eng] = 8;

        decimalsSet[dpt] = true;
        decimalsSet[cdc] = true;
        decimalsSet[eth] = true;
        decimalsSet[dai] = true;
        decimalsSet[eng] = true;
    }
   
    function _setDust() internal {
        dust[dpt] = 10000;
        dust[cdc] = 10000;
        dust[eth] = 10000;
        dust[dai] = 10000;
        dust[eng] = 10;
        dust[dpass] = 10000;

        dustSet[dpt] = true;
        dustSet[cdc] = true;
        dustSet[eth] = true;
        dustSet[dai] = true;
        dustSet[eng] = true;
        dustSet[dpass] = true;

    }
    
    function _setFeeds() internal {
        feed[eth] = address(new TestFeedLike(usdRate[eth], true));
        feed[dpt] = address(new TestFeedLike(usdRate[dpt], true));
        feed[cdc] = address(new TestFeedLike(usdRate[cdc], true));
        feed[dai] = address(new TestFeedLike(usdRate[dai], true));
        feed[eng] = address(new TestFeedLike(usdRate[eng], true));
    }
    
    function _createContracts() internal {
        burner = address(uint160(address(new Burner(DSToken(dpt))))); // Burner()
        wal = address(uint160(address(new DptTester(DSToken(dai))))); // DptTester()
        asm = address(uint160(address(new SimpleAssetManagement())));
        
        uint ourGas = gasleft();
        emit LogTest("cerate DiamondExchange");
        exchange = address(uint160(address(new DiamondExchange())));
        emit LogTest(ourGas - gasleft());

        liq = address(uint160(address(new DiamondExchangeTester(exchange, dpt, cdc, dai))));
        DSToken(dpt).transfer(liq, INITIAL_BALANCE);
        DiamondExchangeTester(liq).doApprove(dpt, exchange, uint(-1));

        fca = address(uint160(address(new TestFeeCalculator())));
    }
    
    function _setupGuard() internal {
        guard = new DSGuard();
        SimpleAssetManagement(asm).setAuthority(guard);
        DSToken(cdc).setAuthority(guard);
        Dpass(dpass).setAuthority(guard);
        guard.permit(address(this), address(asm), ANY);
        guard.permit(address(asm), cdc, ANY);
        guard.permit(address(asm), dpass, ANY);
        guard.permit(exchange, asm, ANY);

        DiamondExchangeTester(liq).setAuthority(guard);
        guard.permit(exchange, liq, ANY);
        DiamondExchangeTester(liq).setOwner(exchange);
    } 

    function _setupCustodian20() internal {
        custodian20[dpt] = asm;
        custodian20[cdc] = asm;
        custodian20[eth] = asm;
        custodian20[dai] = asm;
        custodian20[eng] = asm;
    }

    function _setConfigAsm() internal {
    
        SimpleAssetManagement(asm).setConfig("overCollRatio", b(1.1 ether), "", "diamonds");
        SimpleAssetManagement(asm).setConfig("priceFeed", b(cdc), b(feed[cdc]), "diamonds");
        SimpleAssetManagement(asm).setConfig("priceFeed", b(dai), b(feed[dai]), "diamonds");
        SimpleAssetManagement(asm).setConfig("priceFeed", b(eth), b(feed[eth]), "diamonds");
        SimpleAssetManagement(asm).setConfig("priceFeed", b(dpt), b(feed[dpt]), "diamonds");
        SimpleAssetManagement(asm).setConfig("priceFeed", b(eng), b(feed[eng]), "diamonds");

        SimpleAssetManagement(asm).setConfig("manualRate", b(cdc), b(true), "diamonds");
        SimpleAssetManagement(asm).setConfig("manualRate", b(dai), b(true), "diamonds");
        SimpleAssetManagement(asm).setConfig("manualRate", b(eth), b(true), "diamonds");
        SimpleAssetManagement(asm).setConfig("manualRate", b(dpt), b(true), "diamonds");
        SimpleAssetManagement(asm).setConfig("manualRate", b(eng), b(true), "diamonds");

        SimpleAssetManagement(asm).setConfig("decimals", b(cdc), b(decimals[cdc]), "diamonds");
        SimpleAssetManagement(asm).setConfig("decimals", b(dai), b(decimals[dai]), "diamonds");
        SimpleAssetManagement(asm).setConfig("decimals", b(eth), b(decimals[eth]), "diamonds");
        SimpleAssetManagement(asm).setConfig("decimals", b(dpt), b(decimals[dpt]), "diamonds");
        SimpleAssetManagement(asm).setConfig("decimals", b(eng), b(decimals[eng]), "diamonds");

        SimpleAssetManagement(asm).setConfig("cdcs", b(cdc), b(true), "diamonds");
        SimpleAssetManagement(asm).setConfig("dpasses", b(dpass), b(true), "diamonds");
        SimpleAssetManagement(asm).setConfig("payTokens", b(cdc), b(true), "diamonds");
        SimpleAssetManagement(asm).setConfig("payTokens", b(dai), b(true), "diamonds");
        SimpleAssetManagement(asm).setConfig("payTokens", b(eth), b(true), "diamonds");
        SimpleAssetManagement(asm).setConfig("payTokens", b(dpt), b(true), "diamonds");
        SimpleAssetManagement(asm).setConfig("payTokens", b(eng), b(true), "diamonds");

        SimpleAssetManagement(asm).setConfig("rate", b(cdc), b(usdRate[cdc]), "diamonds");
        SimpleAssetManagement(asm).setConfig("rate", b(dai), b(usdRate[dai]), "diamonds");
        SimpleAssetManagement(asm).setConfig("rate", b(eth), b(usdRate[eth]), "diamonds");
        SimpleAssetManagement(asm).setConfig("rate", b(dpt), b(usdRate[dpt]), "diamonds");
        SimpleAssetManagement(asm).setConfig("rate", b(eng), b(usdRate[eng]), "diamonds");

        SimpleAssetManagement(asm).setConfig("custodians", b(seller), b(true), "diamonds");
        SimpleAssetManagement(asm).setConfig("setApproveForAll", b(dpass), b(exchange), b(true));
    }

    function _setConfigExchange() internal {
        DiamondExchange(exchange).setConfig("canSellErc20", b(dpt), b(true));
        DiamondExchange(exchange).setConfig("canBuyErc20", b(dpt), b(true));
        DiamondExchange(exchange).setConfig("canSellErc20", b(cdc), b(true));
        DiamondExchange(exchange).setConfig("canBuyErc20", b(cdc), b(true));
        DiamondExchange(exchange).setConfig("canSellErc20", b(eth), b(true));
        DiamondExchange(exchange).setConfig("canBuyErc721", b(dpass), b(true));
        DiamondExchange(exchange).setConfig("decimals", b(dpt), b(18));
        DiamondExchange(exchange).setConfig("decimals", b(cdc), b(18));
        DiamondExchange(exchange).setConfig("decimals", b(eth), b(18));
        DiamondExchange(exchange).setConfig("dpt", b(dpt), b(""));
        DiamondExchange(exchange).setConfig("cdc", b(cdc), b(""));
        DiamondExchange(exchange).setConfig("handledByAsm", b(cdc), b(true));
        DiamondExchange(exchange).setConfig("handledByAsm", b(dpass), b(true));
        DiamondExchange(exchange).setConfig("priceFeed", b(dpt), b(feed[dpt]));
        DiamondExchange(exchange).setConfig("priceFeed", b(eth), b(feed[eth]));
        DiamondExchange(exchange).setConfig("priceFeed", b(cdc), b(feed[cdc]));
        DiamondExchange(exchange).setConfig("liq", b(liq), b(""));
        DiamondExchange(exchange).setConfig("burner", b(burner), b(""));
        DiamondExchange(exchange).setConfig("asm", b(asm), b(""));
        DiamondExchange(exchange).setConfig("fixFee", b(fixFee), b(""));
        DiamondExchange(exchange).setConfig("varFee", b(varFee), b(""));
        DiamondExchange(exchange).setConfig("profitRate", b(profitRate), b(""));
        DiamondExchange(exchange).setConfig("wal", b(wal), b(""));

        DiamondExchange(exchange).setConfig(b("canSellErc20"), b(dai), b(true));
        DiamondExchange(exchange).setConfig(b("priceFeed"), b(dai), b(feed[dai]));
        DiamondExchange(exchange).setConfig(b("rate"), b(dai), b(usdRate[dai]));
        DiamondExchange(exchange).setConfig(b("manualRate"), b(dai), b(true));
        DiamondExchange(exchange).setConfig(b("decimals"), b(dai), b(18));
        DiamondExchange(exchange).setConfig(b("custodian20"), b(dai), b(custodian20[dai]));
        // DiamondExchange(exchange).setConfig(b("handledByAsm"), b(dai), b(true));      // set true if token can be bougt by user and asm should handle it

        DiamondExchange(exchange).setConfig(b("canSellErc20"), b(eth), b(true));
        DiamondExchange(exchange).setConfig(b("priceFeed"), b(eth), b(feed[eth]));
        DiamondExchange(exchange).setConfig(b("rate"), b(eth), b(usdRate[eth]));
        DiamondExchange(exchange).setConfig(b("manualRate"), b(eth), b(true));
        DiamondExchange(exchange).setConfig(b("decimals"), b(eth), b(18));
        DiamondExchange(exchange).setConfig(b("custodian20"), b(eth), b(custodian20[eth]));
        // DiamondExchange(exchange).setConfig(b("handledByAsm"), b(eth), b(true));      // set true if token can be bougt by user and asm should handle it

        DiamondExchange(exchange).setConfig(b("canSellErc20"), b(cdc), b(true));
        DiamondExchange(exchange).setConfig(b("canBuyErc20"), b(cdc), b(true));
        DiamondExchange(exchange).setConfig(b("custodian20"), b(cdc), b(custodian20[cdc]));
        DiamondExchange(exchange).setConfig(b("priceFeed"), b(cdc), b(feed[cdc]));
        DiamondExchange(exchange).setConfig(b("rate"), b(cdc), b(usdRate[cdc]));
        DiamondExchange(exchange).setConfig(b("manualRate"), b(cdc), b(true));
        DiamondExchange(exchange).setConfig(b("decimals"), b(cdc), b(18));
        DiamondExchange(exchange).setConfig(b("handledByAsm"), b(cdc), b(true));

        DiamondExchange(exchange).setConfig(b("canSellErc20"), b(dpt), b(true));
        DiamondExchange(exchange).setConfig(b("custodian20"), b(dpt), b(asm));
        DiamondExchange(exchange).setConfig(b("priceFeed"), b(dpt), b(feed[dpt]));
        DiamondExchange(exchange).setConfig(b("rate"), b(dpt), b(usdRate[dpt]));
        DiamondExchange(exchange).setConfig(b("manualRate"), b(dpt), b(true));
        DiamondExchange(exchange).setConfig(b("decimals"), b(dpt), b(18));
        DiamondExchange(exchange).setConfig(b("custodian20"), b(dpt), b(custodian20[dpt]));
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(takeProfitOnlyInDpt)), b(""));

        DiamondExchange(exchange).setConfig(b("canSellErc20"), b(eng), b(true));
        DiamondExchange(exchange).setConfig(b("priceFeed"), b(eng), b(feed[eng]));
        DiamondExchange(exchange).setConfig(b("rate"), b(eng), b(usdRate[eng]));
        DiamondExchange(exchange).setConfig(b("manualRate"), b(eng), b(true));
        DiamondExchange(exchange).setConfig(b("decimals"), b(eng), b(8));
        DiamondExchange(exchange).setConfig(b("custodian20"), b(eng), b(custodian20[eng]));

        DiamondExchange(exchange).setConfig(b("liq"), b(liq), b(""));
    }

    function _createActors() internal {
    
        user = address(uint160(address(new DiamondExchangeTester(exchange, dpt, cdc, dai))));
        seller = address(uint160(address(new DiamondExchangeTester(exchange, dpt, cdc, dai))));
    }
    
    function _approveContracts()  internal {
        Cdc(cdc).approve(exchange, uint(-1));
        DSToken(dpt).approve(exchange, uint(-1));
        DSToken(dai).approve(exchange, uint(-1));
        DSToken(eng).approve(exchange, uint(-1));
    }
    
    function _mintDpasses() internal {
        // Prepare dpass tokens
        dpassOwnerPrice[user] = 53 ether;
        Dpass(dpass).setCccc("BR,IF,F,0.01", true);
        dpassId[user] = Dpass(dpass).mintDiamondTo(
            user,                                                               // address _to,
            seller,                                                             // address _custodian
            "gia",                                                              // bytes32 _issuer,
            "2141438167",                                                       // bytes32 _report,
            "sale",                                                             // bytes32 _state,
            "BR,IF,F,0.01",
            0.2 * 100,
            bytes32(uint(0xc0a5d062e13f99c8f70d19dc7993c2f34020a7031c17f29ce2550315879006d7)), // bytes32 _attributesHash
            "20191101"
        );
        SimpleAssetManagement(asm).setBasePrice(dpass, dpassId[user], dpassOwnerPrice[user]);

        dpassOwnerPrice[asm] = 137 ether;
        Dpass(dpass).setCccc("BR,VVS1,F,3.00", true);
        dpassId[seller] = Dpass(dpass).mintDiamondTo(
            asm,                                                                // address _to,
            seller,                                                             // address _custodian,
            "gia",                                                              // bytes32 _issuer,
            "2141438168",                                                       // bytes32 _report,
            "sale",                                                             // bytes32 _state,
            "BR,VVS1,F,3.00",
            3.1 * 100,
            bytes32(0xac5c1daab5131326b23d7f3a4b79bba9f236d227338c5b0fb17494defc319886), // bytes32 _attributesHash
            "20191101"
        );

        SimpleAssetManagement(asm).setBasePrice(dpass, dpassId[seller], dpassOwnerPrice[asm]);
    }
    
    function _transferToUserAndApproveExchange() internal {
        user.transfer(INITIAL_BALANCE);
        DSToken(dai).transfer(user, INITIAL_BALANCE);
        DSToken(eng).transfer(user, INITIAL_BALANCE);

        DiamondExchangeTester(user).doApprove(dpt, exchange, uint(-1));
        DiamondExchangeTester(user).doApprove(cdc, exchange, uint(-1));
        DiamondExchangeTester(user).doApprove(dai, exchange, uint(-1));

    } 
    
    function _storeInitialBalances() internal {
        balance[address(this)][eth] = address(this).balance;
        balance[user][eth] = user.balance;
        balance[user][cdc] = Cdc(cdc).balanceOf(user);
        balance[user][dpt] = DSToken(dpt).balanceOf(user);
        balance[user][dai] = DSToken(dai).balanceOf(user);

        balance[asm][eth] = asm.balance;
        balance[asm][cdc] = Cdc(cdc).balanceOf(asm);
        balance[asm][dpt] = DSToken(dpt).balanceOf(asm);
        balance[asm][dai] = DSToken(dai).balanceOf(asm);

        balance[liq][eth] = liq.balance;
        balance[wal][eth] = wal.balance;
        balance[custodian20[eth]][eth] = custodian20[eth].balance;
        balance[custodian20[cdc]][cdc] = Cdc(cdc).balanceOf(custodian20[cdc]);
        balance[custodian20[dpt]][dpt] = DSToken(dpt).balanceOf(custodian20[dpt]);
        balance[custodian20[dai]][dai] = DSToken(dai).balanceOf(custodian20[dai]);

    } 

    function _logContractAddresses() internal {
        emit log_named_address("exchange", exchange);
        emit log_named_address("dpt", dpt);
        emit log_named_address("cdc", cdc);
        emit log_named_address("asm", asm);
        emit log_named_address("user", user);
        emit log_named_address("seller", seller);
        emit log_named_address("wal", wal);
        emit log_named_address("liq", liq);
        emit log_named_address("burner", burner);
        emit log_named_address("this", address(this));
    } 

}
//------------------end-of-DiamondExchangeTest------------------------------------



contract TestFeeCalculator is DSMath {
    uint public fee;

    function calculateFee(
        address sender,
        uint256 value,
        address sellToken,
        uint256 sellAmtOrId,
        address buyToken,
        uint256 buyAmtOrId
    ) external view returns (uint256) {
        if (sender == address(0x0)) {return 0;}
        if (sellToken == address(0x0)) {return 0;}
        if (buyToken == address(0x0)) {return 0;}
        return add(add(add(value, sellAmtOrId), buyAmtOrId), fee);
    }

    function setFee(uint fee_) public {
        fee = fee_;
    }
}


contract TestFeedLike {
    bytes32 public rate;
    bool public feedValid;

    constructor(uint rate_, bool feedValid_) public {
        require(rate_ > 0, "TestFeedLike: Rate must be > 0");
        rate = bytes32(rate_);
        feedValid = feedValid_;
    }

    function peek() external view returns (bytes32, bool) {
        return (rate, feedValid);
    }

    function setRate(uint rate_) public {
        rate = bytes32(rate_);
    }

    function setValid(bool feedValid_) public {
        feedValid = feedValid_;
    }
}


contract DptTester {
    DSToken public _dpt;

    constructor(DSToken dpt) public {
        require(address(dpt) != address(0), "CET: dpt 0x0 invalid");
        _dpt = dpt;
    }

    function doApprove(address to, uint amount) public {
        DSToken(_dpt).approve(to, amount);
    }

    function doTransfer(address to, uint amount) public {
        DSToken(_dpt).transfer(to, amount);
    }

    function () external payable {
    }
}


contract DiamondExchangeTester is Wallet, DSTest {
    // TODO: remove all following LogTest()
    event LogTest(uint256 what);
    event LogTest(bool what);
    event LogTest(address what);
    event LogTest(bytes32 what);

    DiamondExchange public exchange;

    DSToken public _dpt;
    DSToken public _cdc;
    DSToken public _dai;

    constructor(address payable exchange_, address dpt, address cdc, address dai) public {
        require(exchange_ != address(0), "CET: exchange 0x0 invalid");
        require(dpt != address(0), "CET: dpt 0x0 invalid");
        require(cdc != address(0), "CET: cdc 0x0 invalid");
        require(dai != address(0), "CET: dai 0x0 invalid");
        exchange = DiamondExchange(exchange_);
        _dpt = DSToken(dpt);
        _cdc = DSToken(cdc);
        _dai = DSToken(dai);
    }

    function () external payable {
    }

    function doApprove(address token, address to, uint amount) public {
        require(token != address(0), "Can't approve token of 0x0");
        require(to != address(0), "Can't approve address of 0x0");
        DSToken(token).approve(to, amount);
    }

    function doApprove721(address token, address to, uint amount) public {
        require(token != address(0), "Can't approve token of 0x0");
        require(to != address(0), "Can't approve address of 0x0");
        Dpass(token).approve(to, amount);
    }

    function doTransfer(address token, address to, uint amount) public {
        DSToken(token).transfer(to, amount);
    }

    function doTransferFrom(address token, address from, address to, uint amount) public {
        DSToken(token).transferFrom(from, to, amount);
    }

    function doTransfer721(address token, address to, uint id) public {
        Dpass(token).transferFrom(address(this), to, id);
    }

    function doTransferFrom721(address token, address from, address to, uint amount) public {
        Dpass(token).transferFrom(from, to, amount);
    }
 
    function doSetState(address token, uint256 tokenId, bytes8 state) public {
        Dpass(token).setState(state, tokenId);
    }
 
    function doSetBuyPrice(address token, uint256 tokenId, uint256 price) public {
        DiamondExchange(exchange).setBuyPrice(token, tokenId, price);
    }

    function doGetBuyPrice(address token, uint256 tokenId) public view returns(uint256) {
        return DiamondExchange(exchange).getBuyPrice(token, tokenId);
    }

    function doBuyTokensWithFee(
        address sellToken,
        uint256 sellAmtOrId,
        address buyToken,
        uint256 buyAmtOrId
    ) public payable logs_gas {
        if (sellToken == address(0xee)) {

            DiamondExchange(exchange)
            .buyTokensWithFee
            .value(sellAmtOrId == uint(-1) ? address(this).balance : sellAmtOrId > address(this).balance ? address(this).balance : sellAmtOrId)
            (sellToken, sellAmtOrId, buyToken, buyAmtOrId);

        } else {

            DiamondExchange(exchange).buyTokensWithFee(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
        }
    }

    function doSetConfig(bytes32 what, address value_, address value1_) public { doSetConfig(what, b32(value_), b32(value1_)); }
    function doSetConfig(bytes32 what, address value_, bytes32 value1_) public { doSetConfig(what, b32(value_), value1_); }
    function doSetConfig(bytes32 what, address value_, uint256 value1_) public { doSetConfig(what, b32(value_), b32(value1_)); }
    function doSetConfig(bytes32 what, address value_, bool value1_) public { doSetConfig(what, b32(value_), b32(value1_)); }
    function doSetConfig(bytes32 what, uint256 value_, address value1_) public { doSetConfig(what, b32(value_), b32(value1_)); }
    function doSetConfig(bytes32 what, uint256 value_, bytes32 value1_) public { doSetConfig(what, b32(value_), value1_); }
    function doSetConfig(bytes32 what, uint256 value_, uint256 value1_) public { doSetConfig(what, b32(value_), b32(value1_)); }
    function doSetConfig(bytes32 what, uint256 value_, bool value1_) public { doSetConfig(what, b32(value_), b32(value1_)); }

    function doSetConfig(bytes32 what_, bytes32 value_, bytes32 value1_) public {
        DiamondExchange(exchange).setConfig(what_, value_, value1_);
    }

    function doGetDecimals(address token_) public view returns(uint8) {
        return DiamondExchange(exchange).getDecimals(token_);
    }

    /**
    * @dev Convert address to bytes32
    * @param a address that is converted to bytes32
    * @return bytes32 conversion of address
    */
    function b32(address a) public pure returns (bytes32) {
        return bytes32(uint256(a));
    }

    /**
    * @dev Convert uint256 to bytes32
    * @param a uint value to be converted
    * @return bytes32 converted value
    */
    function b32(uint a) public pure returns (bytes32) {
        return bytes32(a);
    }

    /**
    * @dev Convert uint256 to bytes32
    * @param a_ bool value to be converted
    * @return bytes32 converted value
    */
    function b32(bool a_) public pure returns (bytes32) {
        return bytes32(uint256(a_ ? 1 : 0));
    }

    /**
    * @dev Convert address to bytes32
    */
    function addr(bytes32 b) public pure returns (address) {
        return address(uint160(uint256(b)));
    }

    function doCalculateFee(
        address sender_,
        uint256 value_,
        address sellToken_,
        uint256 sellAmtOrId_,
        address buyToken_,
        uint256 buyAmtOrId_
    ) public view returns (uint256) {
        return DiamondExchange(exchange).calculateFee(sender_, value_, sellToken_, sellAmtOrId_, buyToken_, buyAmtOrId_);
    }

    function doGetRate(address token_) public view returns (uint rate_) {
        return DiamondExchange(exchange).getRate(token_);
    }

    function doGetLocalRate(address token_) public view returns (uint rate_) {
        return DiamondExchange(exchange).getRate(token_);
    }

}




contract TrustedDiamondExchange {

    function _getValues(
        address sellToken,
        uint256 sellAmtOrId,
        address buyToken,
        uint256 buyAmtOrId
    ) external returns (uint256 buyV, uint256 sellV);

    function _takeFee(
        uint256 fee,
        uint256 sellV,
        uint256 buyV,
        address sellToken,
        uint256 sellAmtOrId,
        address buyToken,
        uint256 buyAmtOrId
    )
    external
    returns(uint256 sellT, uint256 buyT);

    function _transferTokens(
        uint256 sellT,                                                  // sell token amount
        uint256 buyT,                                                   // buy token amount
        address sellToken,                                              // token sold by user
        uint256 sellAmtOrId,                                            // sell amount or sell token id
        address buyToken,                                               // token bought by user
        uint256 buyAmtOrId,                                             // buy amount or buy id
        uint256 feeV                                                    // value of total fees in base currency
    ) external;

    function _getNewRate(address token_) external view returns (uint rate_);
    function _updateRates(address sellToken, address buyToken) external;

    function _logTrade(
        address sellToken,
        uint256 sellT,
        address buyToken,
        uint256 buyT,
        uint256 buyAmtOrId,
        uint256 fee
    ) external;

    function _updateRate(address token) external returns (uint256 rate_);

    function _takeFeeInToken(
        uint256 fee,                                                // fee that user still owes to CDiamondCoin after paying fee in DPT
        uint256 feeTaken,                                           // fee already taken from user in DPT
        address token,                                              // token that must be sent as fee
        address src,                                                // source of token sent
        uint256 amountToken                                         // total amount of tokens the user wanted to pay initially
    ) external;

    function _takeFeeInDptFromUser(
        uint256 fee                                                 // total fee to be paid
    ) external returns(uint256 feeTaken);

    function _sendToken(
        address token,
        address src,
        address payable dst,
        uint256 amount
    ) external returns(bool);
}
// TODO: tasts for liqBuysDpt where liwuidity contract buys dpt for us and sends to burner



