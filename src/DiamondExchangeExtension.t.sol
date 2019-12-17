pragma solidity ^0.5.11;

import "ds-test/test.sol";
import "ds-auth/auth.sol";
import "ds-math/math.sol";
import "ds-token/token.sol";
import "ds-guard/guard.sol";
import "cdc-token/Cdc.sol";
import "dpass/Dpass.sol";
import "./DiamondExchange.sol";
import "./DiamondExchangeExtension.sol";
import "./Burner.sol";
import "./Wallet.sol";
import "./SimpleAssetManagement.sol";

contract DiamondExchangeExtensionTest is DSTest, DSMath, DiamondExchangeEvents, Wallet {
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
    address payable public dee;                                             // DiamondExchangeExtension()

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
        _setConfigDiamondExchangeExtension();
        _approveContracts();
        _mintDpasses();
        _transferToUserAndApproveExchange();
        _storeInitialBalances();
        _logContractAddresses();
    }

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
            DiamondExchange(exchange).handledByAsm(buyToken) ?
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
            origBuyer = DiamondExchange(exchange).handledByAsm(buyToken) ? asm : custodian20[buyToken];
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

            if(DiamondExchange(exchange).handledByAsm(buyToken) ) {
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
        eng = address(new DSToken("ENG"));
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
        dee = address(uint160(address(new DiamondExchangeExtension())));
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
        guard.permit(dee, exchange, ANY);

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
        SimpleAssetManagement(asm).setCapCustV(seller, 1000000 ether);
        SimpleAssetManagement(asm).setConfig("setApproveForAll", b(dpass), b(exchange), b(true));
    }

    function _setConfigExchange() internal {
        DiamondExchange(exchange).setConfig("decimals", b(dpt), b(18));
        DiamondExchange(exchange).setConfig("decimals", b(cdc), b(18));
        DiamondExchange(exchange).setConfig("decimals", b(eth), b(18));
        DiamondExchange(exchange).setConfig("canSellErc20", b(dpt), b(true));
        DiamondExchange(exchange).setConfig("canBuyErc20", b(dpt), b(true));
        DiamondExchange(exchange).setConfig("canSellErc20", b(cdc), b(true));
        DiamondExchange(exchange).setConfig("canBuyErc20", b(cdc), b(true));
        DiamondExchange(exchange).setConfig("canSellErc20", b(eth), b(true));
        DiamondExchange(exchange).setConfig("canBuyErc721", b(dpass), b(true));
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

        DiamondExchange(exchange).setConfig(b("decimals"), b(dai), b(18));
        DiamondExchange(exchange).setConfig(b("canSellErc20"), b(dai), b(true));
        DiamondExchange(exchange).setConfig(b("priceFeed"), b(dai), b(feed[dai]));
        DiamondExchange(exchange).setConfig(b("rate"), b(dai), b(usdRate[dai]));
        DiamondExchange(exchange).setConfig(b("manualRate"), b(dai), b(true));
        DiamondExchange(exchange).setConfig(b("custodian20"), b(dai), b(custodian20[dai]));
        // DiamondExchange(exchange).setConfig(b("handledByAsm"), b(dai), b(true));      // set true if token can be bougt by user and asm should handle it

        DiamondExchange(exchange).setConfig(b("decimals"), b(eth), b(18));
        DiamondExchange(exchange).setConfig(b("canSellErc20"), b(eth), b(true));
        DiamondExchange(exchange).setConfig(b("priceFeed"), b(eth), b(feed[eth]));
        DiamondExchange(exchange).setConfig(b("rate"), b(eth), b(usdRate[eth]));
        DiamondExchange(exchange).setConfig(b("manualRate"), b(eth), b(true));
        DiamondExchange(exchange).setConfig(b("custodian20"), b(eth), b(custodian20[eth]));
        // DiamondExchange(exchange).setConfig(b("handledByAsm"), b(eth), b(true));      // set true if token can be bougt by user and asm should handle it

        DiamondExchange(exchange).setConfig(b("decimals"), b(cdc), b(18));
        DiamondExchange(exchange).setConfig(b("canSellErc20"), b(cdc), b(true));
        DiamondExchange(exchange).setConfig(b("canBuyErc20"), b(cdc), b(true));
        DiamondExchange(exchange).setConfig(b("custodian20"), b(cdc), b(custodian20[cdc]));
        DiamondExchange(exchange).setConfig(b("priceFeed"), b(cdc), b(feed[cdc]));
        DiamondExchange(exchange).setConfig(b("rate"), b(cdc), b(usdRate[cdc]));
        DiamondExchange(exchange).setConfig(b("manualRate"), b(cdc), b(true));
        DiamondExchange(exchange).setConfig(b("handledByAsm"), b(cdc), b(true));

        DiamondExchange(exchange).setConfig(b("decimals"), b(dpt), b(18));
        DiamondExchange(exchange).setConfig(b("canSellErc20"), b(dpt), b(true));
        DiamondExchange(exchange).setConfig(b("custodian20"), b(dpt), b(asm));
        DiamondExchange(exchange).setConfig(b("priceFeed"), b(dpt), b(feed[dpt]));
        DiamondExchange(exchange).setConfig(b("rate"), b(dpt), b(usdRate[dpt]));
        DiamondExchange(exchange).setConfig(b("manualRate"), b(dpt), b(true));
        DiamondExchange(exchange).setConfig(b("custodian20"), b(dpt), b(custodian20[dpt]));
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(b32(takeProfitOnlyInDpt)), b(""));

        DiamondExchange(exchange).setConfig(b("decimals"), b(eng), b(8));
        DiamondExchange(exchange).setConfig(b("canSellErc20"), b(eng), b(true));
        DiamondExchange(exchange).setConfig(b("priceFeed"), b(eng), b(feed[eng]));
        DiamondExchange(exchange).setConfig(b("rate"), b(eng), b(usdRate[eng]));
        DiamondExchange(exchange).setConfig(b("manualRate"), b(eng), b(true));
        DiamondExchange(exchange).setConfig(b("custodian20"), b(eng), b(custodian20[eng]));

        DiamondExchange(exchange).setConfig(b("liq"), b(liq), b(""));
    }

    function _setConfigDiamondExchangeExtension() internal {
        DiamondExchangeExtension(dee).setConfig("asm", b(asm), "");
        DiamondExchangeExtension(dee).setConfig("dex", b(exchange), "");
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

    function doRedeem(
        address redeemToken_,
        uint256 redeemAmtOrId_,
        address feeToken_,
        uint256 feeAmt_,
        address payable custodian_
    ) public payable returns (uint) {
        if (feeToken_ == address(0xee)) {

            return  DiamondExchange(exchange)
                .redeem
                .value(feeAmt_ == uint(-1) ? address(this).balance : feeAmt_ > address(this).balance ? address(this).balance : feeAmt_)

                (redeemToken_,
                redeemAmtOrId_,
                feeToken_,
                feeAmt_,
                custodian_);
        } else {
            return  DiamondExchange(exchange).redeem(
                redeemToken_,
                redeemAmtOrId_,
                feeToken_,
                feeAmt_,
                custodian_);
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
