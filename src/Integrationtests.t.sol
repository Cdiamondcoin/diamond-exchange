pragma solidity ^0.5.11;

// user sells diamonds
// setup scenario
// invalid diamond who does what
// TODO: simple setup scenario
// TODO: custodian adds diamond wrong this is how we correnct ir
// TODO: upgrade asm or dex functionality
// TODO: scenario, when theft is at custodian, how to recover from it, make a testcase of how to zero his collateral, and what to do with dpass tokens, dcdc tokens of him
// TODO: test for each basic use-case to demonstrate usability

// TODO: quickly growing new custodian gets too much CDC value and others no money for their purchase

// TODO: user puts his dpass for sale.
// TODO: oracle update CDC price must set cdc values as well
// DODO: lazy custodian looses money because prices went up and has less cdc from sale

import "ds-test/test.sol";
import "ds-auth/auth.sol";
import "ds-math/math.sol";
import "ds-token/token.sol";
import "ds-guard/guard.sol";
import "cdc-token/Cdc.sol";
import "dpass/Dpass.sol";
import "price-feed/price-feed.sol";
import "medianizer/medianizer.sol";
import "./DiamondExchange.sol";
import "./Burner.sol";
import "./Wallet.sol";
import "./SimpleAssetManagement.sol";
import "./Liquidity.sol";
import "./Dcdc.sol";
import "./FeeCalculator.sol";

contract IntegrationsTest is DSTest {

    event LogTest(uint256 what);
    event LogTest(bool what);
    event LogTest(address what);
    event LogTest(bytes32 what);
    event LogUintIpartUintFpart(bytes32 key, uint val, uint val1);

    address burner;
    address payable wal;
    address payable asm;
    address payable exchange;
    address payable liq;
    address fca;

    address payable user;
    address payable user1;
    address payable custodian;
    address payable custodian1;
    address payable custodian2;

    address dpt;
    address dai;
    address eth;
    address eng;
    address cdc;
    address cdc1;
    address cdc2;
    address dcdc;
    address dcdc1;
    address dcdc2;
    address dpass;
    address dpass1;
    address dpass2;

    mapping(address => uint) dust;
    mapping(address => bool) dustSet;

    bytes32 constant public ANY = bytes32(uint(-1));
    DSGuard guard;
    uint public constant INITIAL_BALANCE = 1000 ether;
    uint public constant SUPPLY = (10 ** 10) * (10 ** 18);
    bool showActualExpected;

    uint cdcUsdRate;
    uint dptUsdRate;
    uint daiUsdRate;
    uint ethUsdRate;

    Medianizer cdcFeed;                             // create medianizer that calculates single price from multiple price sources

    PriceFeed cdcPriceOracle0;                      // oracle is a single price source that receives price data from several sources
    PriceFeed cdcPriceOracle1;                      // cdc price is updated every once a week
    PriceFeed cdcPriceOracle2;

    Medianizer dptFeed;                             // create medianizer that calculates single price from multiple price sources
    PriceFeed dptPriceOracle0;                      // oracle is a single price source that receives price data from several sources
    PriceFeed dptPriceOracle1;                      // dpt price is updated every once a week
    PriceFeed dptPriceOracle2;

    Medianizer ethFeed;
    PriceFeed ethPriceOracle0;                      // oracle is a single price source that receives price data from several sources
    PriceFeed ethPriceOracle1;                      // eth price is updated every time the price changes more than 2%
    PriceFeed ethPriceOracle2;

    Medianizer daiFeed;
    PriceFeed daiPriceOracle0;                      // oracle is a single price source that receives price data from several sources
    PriceFeed daiPriceOracle1;                      // dai price is updated every time the price changes more than 2%
    PriceFeed daiPriceOracle2;

    function setUp() public {
        _createTokens();
        _setDust();
        _mintInitialSupply();
        _createContracts();
        _createActors();
        _setupGuard();
        _prepareTestMintCdcInt();
    }

    function test1MintCdcInt() public {             // use-case 1. Mint Cdc

        Dpass(dpass).setCccc("BR,IF,D,5.00", true); // enable a cccc value diamonds can have only cccc values that are enabled first

        TesterActor(custodian).doMintDpass(         // custodian must mint dpass first to create collateral for CDC
            dpass,                                  // token to mint (system can handle any number of different dpass tokens)
            custodian,                              // custodian of diamond, custodians can only set themselves no others
            "GIA",                                  // the issuer of following ID, currently GIA" is the only supported
            "2134567890",                           // GIA number (ID)
            "sale",                                 // if wants to have it for sale, if not then "valid"
            "BR,IF,D,5.00",                         // cut, clarity, color, weight range(start) of diamond
            511,                                    // carat is decimal 2 precision, so this diamond is 5.11 carats
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
                                                    // attribute hasn of all the attributes we stori
            "20191107",
            2928.03 ether                           // the price is 2928.03 USD for the diamond (not per carat!!!!)
                                        );
        SimpleAssetManagement(asm)
            .mint(cdc, user, 1 ether);              // mint 1 CDC token to user
                                                    // usually we do not directly mint CDC to user, but use notiryTransferFrom() function from dex to mint to user
        assertEqLog("cdc-minted-to-user", DSToken(cdc).balanceOf(user), 1 ether);
    }

    function testFail1MintCdcInt() public {         // use-case 1. Mint CDC - failure if tehere is no collateral

        SimpleAssetManagement(asm)
            .mint(cdc, user, 1 ether);              // mint 1 CDC token to user
                                                    // usually we do not directly mint CDC to user, but use notiryTransferFrom() function from dex to mint to user
    }

    function test2MintDpassInt() public {              // use-case 2. Mint Dpass

        Dpass(dpass).setCccc("BR,IF,D,5.00", true); // enable a cccc value diamonds can have only cccc values that are enabled first

        uint id = TesterActor(custodian)
            .doMintDpass(
            dpass,                                  // token to mint (system can handle any number of different dpass tokens)
            custodian,                              // custodian of diamond, custodians can only set themselves no others
            "GIA",                                  // the issuer of following ID, currently GIA" is the only supported
            "2134567890",                           // GIA number (ID)
            "sale",                                 // if wants to have it for sale, if not then "valid"
            "BR,IF,D,5.00",                         // cut, clarity, color, weight range(start) of diamond
            511,                                    // carat is decimal 2 precision, so this diamond is 5.11 carats
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
                                                    // attribute hasn of all the attributes we stori
            "20191107",
            2928.03 ether                           // the price is 2928.03 USD for the diamond (not per carat!!!!)
                                          );
        assertEqLog("dpass-minted-to-asm",Dpass(dpass).ownerOf(id), asm);

    }

    function test3CdcPurchaseInt() public {

        uint daiPaid = 100 ether; 

        DSToken(dai).transfer(user, daiPaid);      // send 10 DAI to user, so he can use it to buy CDC

        TesterActor(user)
            .doApprove(dai, exchange, uint(-1));    // user must approve exchange in order to trade

        Dpass(dpass).setCccc("BR,IF,D,5.00", true); // enable a cccc value diamonds can have only cccc values that are enabled first

        uint id = TesterActor(custodian)            // **Mint some dpass diamond so that we can print cdc
            .doMintDpass(
            dpass,
            custodian,
            "GIA",
            "2134567890",
            "sale",
            "BR,IF,D,5.00",
            511,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,

            "20191107",
            2928.03 ether
        );

        TesterActor(user).doBuyTokensWithFee(
            dai,
            daiPaid,
            cdc,
            uint(-1)
        );

        logUint("fixFee", DiamondExchange(exchange).fixFee(), 18);
        logUint("varFee", DiamondExchange(exchange).varFee(), 18);
        logUint("user-cdc-balance", DSToken(cdc).balanceOf(user), 18);
        logUint("user-dai-balance", DSToken(dai).balanceOf(user), 18);
        logUint("asm-dai-balance", DSToken(dai).balanceOf(asm), 18);
        logUint("asm-cdc-balance", DSToken(cdc).balanceOf(asm), 18);
        logUint("wallet-dai-balance", DSToken(dai).balanceOf(wal), 18);
        logUint("liq-dpt-balance", DSToken(dpt).balanceOf(liq), 18);
        logUint("burner-dpt-balance", DSToken(dpt).balanceOf(burner), 18);
    }

    function logUint(bytes32 what, uint256 num, uint256 dec) public {
        emit LogUintIpartUintFpart( what, num / 10 ** dec, num % 10 ** dec);
    }
    
    function _prepareDai() public {
       daiUsdRate = 1 ether;

        daiFeed = new Medianizer();                                          // create medianizer that calculates single price from multiple price sources

        daiPriceOracle0 = new PriceFeed();                                    // oracle is a single price source that receives price data from several sources
        daiPriceOracle1 = new PriceFeed();                                    // dai price is updated every once a week
        daiPriceOracle2 = new PriceFeed();

        daiFeed.set(address(daiPriceOracle0));                                                   // add oracle to medianizer to get price data from
        daiFeed.set(address(daiPriceOracle1));
        daiFeed.set(address(daiPriceOracle2));

        //--------------------oracles-update-price-data--------------------------------begin
        daiPriceOracle0.poke(                                                           // oracle update dai price every once a week
            uint128(daiUsdRate),
            60 * 60 * 24 * 8                                                            // the data is valid for 8 days
        );

        daiPriceOracle1.poke(                                                           // oracle update dai price every once a week
            uint128(daiUsdRate),
            60 * 60 * 24 * 8                                                            // the data is valid for 8 days
        );

        daiPriceOracle1.poke(                                                           // oracle update dai price every once a week
            uint128(daiUsdRate),
            60 * 60 * 24 * 8                                                            // the data is valid for 8 days
        );
        daiFeed.poke();

        //--------------------oracles-update-price-data--------------------------------end
    }

    function _prepareTestMintCdcInt() internal {
        cdcUsdRate = 80 ether;
        dptUsdRate = 100 ether;
        ethUsdRate = 150 ether;
        
        _prepareDai();

        cdcFeed = new Medianizer();                                          // create medianizer that calculates single price from multiple price sources

        cdcPriceOracle0 = new PriceFeed();                                    // oracle is a single price source that receives price data from several sources
        cdcPriceOracle1 = new PriceFeed();                                    // cdc price is updated every once a week
        cdcPriceOracle2 = new PriceFeed();

        cdcFeed.set(address(cdcPriceOracle0));                                                   // add oracle to medianizer to get price data from
        cdcFeed.set(address(cdcPriceOracle1));
        cdcFeed.set(address(cdcPriceOracle2));

        //--------------------oracles-update-price-data--------------------------------begin
        cdcPriceOracle0.poke(                                                           // oracle update cdc price every once a week
            uint128(cdcUsdRate),
            60 * 60 * 24 * 8                                                            // the data is valid for 8 days
        );

        cdcPriceOracle1.poke(                                                           // oracle update cdc price every once a week
            uint128(cdcUsdRate),
            60 * 60 * 24 * 8                                                            // the data is valid for 8 days
        );

        cdcPriceOracle1.poke(                                                           // oracle update cdc price every once a week
            uint128(cdcUsdRate),
            60 * 60 * 24 * 8                                                            // the data is valid for 8 days
        );
        cdcFeed.poke();

        //--------------------oracles-update-price-data--------------------------------end
        dptFeed = new Medianizer();                                          // create medianizer that calculates single price from multiple price sources

        dptPriceOracle0 = new PriceFeed();                                    // oracle is a single price source that receives price data from several sources
        dptPriceOracle1 = new PriceFeed();                                    // dpt price is updated every once a week
        dptPriceOracle2 = new PriceFeed();

        dptFeed.set(address(dptPriceOracle0));                                          // add oracle to medianizer to get price data from
        dptFeed.set(address(dptPriceOracle1));
        dptFeed.set(address(dptPriceOracle2));
        //--------------------oracles-update-price-data--------------------------------begin
        dptPriceOracle0.poke(                                                           // oracle update dpt price every once a week
            uint128(dptUsdRate),
            60 * 60 * 12                                                                // the data is valid for 12 hours
        );

        dptPriceOracle1.poke(                                                           // oracle update dpt price every once a week
            uint128(dptUsdRate),
            60 * 60 * 24 * 8                                                            // the data is valid for 8 days
        );

        dptPriceOracle1.poke(                                                           // oracle update dpt price every once a week
            uint128(dptUsdRate),
            60 * 60 * 24 * 8                                                            // the data is valid for 8 days
        );
        dptFeed.poke();
        //--------------------oracles-update-price-data--------------------------------end

        ethFeed = new Medianizer();

        ethPriceOracle0 = new PriceFeed();                                              // oracle is a single price source that receives price data from several sources
        ethPriceOracle1 = new PriceFeed();                                              // eth price is updated every time the price changes more than 2%
        ethPriceOracle2 = new PriceFeed();

        ethFeed.set(address(ethPriceOracle0));                                          // add oracle to medianizer to get price data from
        ethFeed.set(address(ethPriceOracle1));
        ethFeed.set(address(ethPriceOracle2));

        //--------------------oracles-update-price-data--------------------------------begin
        ethPriceOracle0.poke(                                                           // oracle update eth price every once a week
            uint128(ethUsdRate),
            60 * 60 * 24 * 8                                                            // the data is valid for 8 days
        );

        ethPriceOracle1.poke(                                                           // oracle update eth price every once a week
            uint128(ethUsdRate),
            60 * 60 * 24 * 8                                                            // the data is valid for 8 days
        );

        ethPriceOracle1.poke(                                                           // oracle update eth price every once a week
            uint128(ethUsdRate),
            60 * 60 * 24 * 8                                                            // the data is valid for 8 days
        );

        ethFeed.poke();
        //--------------------oracles-update-price-data--------------------------------end

        DiamondExchange(exchange).setConfig("canSellErc20", b(cdc), b(true));           // user can sell cdc tokens
        DiamondExchange(exchange).setConfig("canBuyErc20", b(cdc), b(true));            // user can buy cdc tokens
        DiamondExchange(exchange).setConfig("decimals", b(cdc), b(18));                 // decimal precision of cdc tokens is 18
        DiamondExchange(exchange).setConfig("priceFeed", b(cdc), b(address(cdcFeed)));  // priceFeed address is set
        DiamondExchange(exchange).setConfig("handledByAsm", b(cdc), b(true));           // make sure that cdc is minted by asset management
        DiamondExchange(exchange).setConfig(b("rate"), b(cdc), b(uint(cdcUsdRate)));    // rate of token in base currency (since Medianizer will return false, this value will be used)
        DiamondExchange(exchange).setConfig(b("manualRate"), b(cdc), b(true));          // allow using manually set prices on cdc token

        DiamondExchange(exchange).setConfig("canSellErc20", b(eth), b(true));           // user can sell eth tokens
        // DiamondExchange(exchange).setConfig("canBuyErc20", b(eth), b(true));         // user CAN NOT BUY ETH ON THIS EXCHANAGE
        DiamondExchange(exchange).setConfig("decimals", b(eth), b(18));                 // decimal precision of eth tokens is 18
        DiamondExchange(exchange).setConfig("priceFeed", b(eth), b(address(ethFeed)));  // priceFeed address is set
        // DiamondExchange(exchange).setConfig("handledByAsm", b(eth), b(true));        // eth SHOULD NEVER BE DECLARED AS handledByAsm, because it can not be minted
        DiamondExchange(exchange).setConfig(b("rate"), b(eth), b(uint(ethUsdRate)));    // rate of token in base currency (since Medianizer will return false, this value will be used)
        DiamondExchange(exchange).setConfig(b("manualRate"), b(eth), b(true));          // allow using manually set prices on eth token

        DiamondExchange(exchange).setConfig("canSellErc20", b(dai), b(true));           // user can sell dai tokens
        DiamondExchange(exchange).setConfig("decimals", b(dai), b(18));                 // decimal precision of dai tokens is 18
        DiamondExchange(exchange).setConfig("priceFeed", b(dai), b(address(daiFeed)));  // priceFeed address is set
        DiamondExchange(exchange).setConfig(b("rate"), b(dai), b(uint(daiUsdRate)));    // rate of token in base currency (since Medianizer will return false, this value will be used)
        DiamondExchange(exchange).setConfig(b("manualRate"), b(dai), b(true));          // allow using manually set prices on dai token

        DiamondExchange(exchange).setConfig("canSellErc20", b(dpt), b(true));           // user can sell dpt tokens
        DiamondExchange(exchange).setConfig("decimals", b(dpt), b(18));                 // decimal precision of dpt tokens is 18
        DiamondExchange(exchange).setConfig("priceFeed", b(dpt), b(address(dptFeed)));  // priceFeed address is set
        DiamondExchange(exchange).setConfig(b("rate"), b(dpt), b(uint(dptUsdRate)));    // rate of token in base currency (since Medianizer will return false, this value will be used)
        DiamondExchange(exchange).setConfig(b("manualRate"), b(dpt), b(true));          // allow using manually set prices on dpt token

        DiamondExchange(exchange).setConfig("dpt", b(dpt), "");                         // tell exhcange which one is the DPT token
        DiamondExchange(exchange).setConfig("liq", b(liq), "");                         // set liquidity contract
        DiamondExchange(exchange).setConfig("burner", b(burner), b(""));                // set burner contract to burn profit of dpt owners
        DiamondExchange(exchange).setConfig("asm", b(asm), b(""));                      // set asset management contract
        DiamondExchange(exchange).setConfig("wal", b(wal), b(""));                      // set wallet to store cost part of fee received from users

        DiamondExchange(exchange).setConfig("fixFee", b(uint(0 ether)), b(""));         // fixed part of fee that is independent of purchase value
        DiamondExchange(exchange).setConfig("varFee", b(uint(0.04 ether)), b(""));      // percentage value defining how much of purchase value if paid as fee value between 0 - 1 ether
        DiamondExchange(exchange).setConfig("profitRate", b(uint(0.1 ether)), b(""));   // percentage value telling how much of total fee goes to profit of DPT owners
        DiamondExchange(exchange).setConfig(b("takeProfitOnlyInDpt"), b(true), b(""));  // if set true only profit part of fee is withdrawn from user in DPT, if false the total fee will be taken from user in DPT

        //-------------setup-asm------------------------------------------------------------

        SimpleAssetManagement(asm).setConfig("priceFeed", b(cdc), b(address(cdcFeed)), "diamonds"); // set price feed (sam as for exchange)
        SimpleAssetManagement(asm).setConfig("manualRate", b(cdc), b(true), "diamonds");            // enable to use rate that is not coming from feed
        SimpleAssetManagement(asm).setConfig("decimals", b(cdc), b(18), "diamonds");                // set precision of token to 18
        SimpleAssetManagement(asm).setConfig("payTokens", b(cdc), b(true), "diamonds");             // allow cdc to be used as means of payment for services
        SimpleAssetManagement(asm).setConfig("cdcs", b(cdc), b(true), "diamonds");                  // tell asm that cdc is indeed a cdc token
        SimpleAssetManagement(asm).setConfig("rate", b(cdc), b(cdcUsdRate), "diamonds");            // set rate for token

        SimpleAssetManagement(asm).setConfig("priceFeed", b(eth), b(address(ethFeed)), "diamonds"); // set pricefeed for eth
        SimpleAssetManagement(asm).setConfig("payTokens", b(eth), b(true), "diamonds");             // enable eth to pay with
        SimpleAssetManagement(asm).setConfig("manualRate", b(eth), b(true), "diamonds");            // enable to set rate of eth manually if feed is dowh (as is current situations)
        SimpleAssetManagement(asm).setConfig("decimals", b(eth), b(18), "diamonds");                // set precision for eth token
        SimpleAssetManagement(asm).setConfig("rate", b(eth), b(ethUsdRate), "diamonds");            // set USD(base currency) rate of token ( this is the price of token in USD)

        SimpleAssetManagement(asm).setConfig("priceFeed", b(dai), b(address(daiFeed)), "diamonds"); // set pricefeed for dai
        SimpleAssetManagement(asm).setConfig("payTokens", b(dai), b(true), "diamonds");             // enable dai to pay with
        SimpleAssetManagement(asm).setConfig("manualRate", b(dai), b(true), "diamonds");            // enable to set rate of dai manually if feed is dowh (as is current situations)
        SimpleAssetManagement(asm).setConfig("decimals", b(dai), b(18), "diamonds");                // set precision for dai token
        SimpleAssetManagement(asm).setConfig("rate", b(dai), b(daiUsdRate), "diamonds");            // set USD(base currency) rate of token ( this is the price of token in USD)

        SimpleAssetManagement(asm).setConfig("overCollRatio", b(uint(1.1 ether)), "", "diamonds");  // make sure that the value of dpass + dcdc tokens is at least 1.1 times the value of cdc tokens.
        SimpleAssetManagement(asm).setConfig("dpasses", b(dpass), b(true), "diamonds");             // enable the dpass tokens of asm to be handled by dex
        SimpleAssetManagement(asm).setConfig("setApproveForAll", b(dpass), b(exchange), b(true));   // enable the dpass tokens of asm to be handled by dex
        SimpleAssetManagement(asm).setConfig("custodians", b(custodian), b(true), "diamonds");      // setup the custodian
    }

    function _createTokens() internal {
        dpt = address(new DSToken("DPT"));
        dai = address(new DSToken("DAI"));
        eth = address(0xee);
        eng = address(new DSToken("ENG"));   // TODO: make sure it is 8 decimals

        cdc = address(new Cdc("BR,VS,G,0.05", "CDC"));
        // TODO: change to Cdc() from DSToken() below
        cdc1 = address(new Cdc("BR,VS,F,1.00", "CDC1"));
        cdc2 = address(new Cdc("BR,VS,E,2.00", "CDC2"));

        dcdc = address(new Dcdc("BR,VS,G,0.05", "DCDC", true));
        dcdc1 = address(new Dcdc("BR,SI3,E,0.04", "DCDC1", true));
        dcdc2 = address(new Dcdc("BR,SI1,F,1.50", "DCDC2", true));

        dpass = address(new Dpass());
        dpass1 = address(new Dpass());
        dpass2 = address(new Dpass());
    }

    function _setDust() internal {
        dust[dpt] = 10000;
        dust[cdc] = 10000;
        dust[cdc1] = 10000;
        dust[cdc2] = 10000;
        dust[eth] = 10000;
        dust[dai] = 10000;
        dust[eng] = 10;
        dust[dpass] = 10000;
        dust[dpass1] = 10000;
        dust[dpass2] = 10000;

        dustSet[dpt] = true;
        dustSet[cdc] = true;
        dustSet[cdc1] = true;
        dustSet[cdc2] = true;
        dustSet[eth] = true;
        dustSet[dai] = true;
        dustSet[eng] = true;
        dustSet[dpass] = true;
        dustSet[dpass1] = true;
        dustSet[dpass2] = true;
    }

    function _mintInitialSupply() internal {
        DSToken(dpt).mint(SUPPLY);
        DSToken(dai).mint(SUPPLY);
        DSToken(eng).mint(SUPPLY);
    }

    function _createContracts() internal {
        burner = address(uint160(address(new Burner(DSToken(dpt))))); // Burner()   // burner contract
        wal = address(uint160(address(new Wallet()))); // DptTester()               // wallet contract
        uint ourGas = gasleft();
        asm = address(uint160(address(new SimpleAssetManagement())));               // asset management contract
        emit LogTest("cerate SimpleAssetManagement");
        emit LogTest(ourGas - gasleft());

        ourGas = gasleft();
        emit LogTest("cerate DiamondExchange");
        exchange = address(uint160(address(new DiamondExchange())));
        emit LogTest(ourGas - gasleft());

        liq = address(uint160(address(new Liquidity())));                           // DPT liquidity pprovider contract
        DSToken(dpt).transfer(liq, INITIAL_BALANCE);
        Liquidity(liq).approve(dpt, exchange, uint(-1));

        fca = address(uint160(address(new FeeCalculator())));                       // fee calculation contract
    }

    function _createActors() internal {
        user = address(new TesterActor(address(exchange), address(asm)));
        user1 = address(new TesterActor(address(exchange), address(asm)));
        custodian = address(new TesterActor(address(exchange), address(asm)));
        custodian1 = address(new TesterActor(address(exchange), address(asm)));
        custodian2 = address(new TesterActor(address(exchange), address(asm)));
    }

    function _setupGuard() internal {
        guard = new DSGuard();
        Burner(burner).setAuthority(guard);
        Wallet(wal).setAuthority(guard);
        SimpleAssetManagement(asm).setAuthority(guard);
        DiamondExchange(exchange).setAuthority(guard);
        Liquidity(liq).setAuthority(guard);
        FeeCalculator(fca).setAuthority(guard);
        DSToken(dpt).setAuthority(guard);
        DSToken(dai).setAuthority(guard);
        DSToken(eng).setAuthority(guard);
        DSToken(cdc).setAuthority(guard);
        DSToken(cdc1).setAuthority(guard);
        DSToken(cdc2).setAuthority(guard);
        DSToken(dcdc).setAuthority(guard);
        DSToken(dcdc1).setAuthority(guard);
        DSToken(dcdc2).setAuthority(guard);
        Dpass(dpass).setAuthority(guard);
        Dpass(dpass1).setAuthority(guard);
        Dpass(dpass2).setAuthority(guard);
        guard.permit(address(this), address(asm), ANY);
        guard.permit(address(asm), cdc, ANY);
        guard.permit(address(asm), cdc1, ANY);
        guard.permit(address(asm), cdc2, ANY);
        guard.permit(address(asm), dpass, ANY);
        guard.permit(address(asm), dpass1, ANY);
        guard.permit(address(asm), dpass2, ANY);
        guard.permit(exchange, asm, ANY);
        guard.permit(exchange, liq, ANY);

        guard.permit(custodian, address(asm), bytes4(keccak256("getRateNewest(address)")));
        guard.permit(custodian, address(asm), bytes4(keccak256("getRate(address)")));
        guard.permit(custodian, address(asm), bytes4(keccak256("burn(address,address,uint256)")));
        guard.permit(custodian, address(asm), bytes4(keccak256("mint(address,address,uint256)")));

        guard.permit(custodian, address(asm), bytes4(keccak256("burnDcdc(address,address,uint256)")));
        guard.permit(custodian, address(asm), bytes4(keccak256("mintDpass(address,address,bytes32,bytes32,bytes32,bytes32,uint24,bytes32,bytes8,uint256)")));
        guard.permit(custodian, address(asm), bytes4(keccak256("mintDcdc(address,address,uint256)")));
        guard.permit(custodian, address(asm), bytes4(keccak256("withdraw(address,uint256)")));
        guard.permit(custodian, dpass, bytes4(keccak256("linkOldToNewToken(uint256,uint256)")));
        guard.permit(custodian, dpass1, bytes4(keccak256("linkOldToNewToken(uint256,uint256)")));
        guard.permit(custodian, dpass2, bytes4(keccak256("linkOldToNewToken(uint256,uint256)")));

        guard.permit(custodian1, address(asm), bytes4(keccak256("getRateNewest(address)")));
        guard.permit(custodian1, address(asm), bytes4(keccak256("getRate(address)")));
        guard.permit(custodian1, address(asm), bytes4(keccak256("burn(address,address,uint256)")));
        guard.permit(custodian1, address(asm), bytes4(keccak256("mint(address,address,uint256)")));

        guard.permit(custodian1, address(asm), bytes4(keccak256("burnDcdc(address,address,uint256)")));
        guard.permit(custodian1, address(asm), bytes4(keccak256("mintDpass(address,address,bytes32,bytes32,bytes32,bytes32,uint24,bytes32,bytes8,uint256)")));
        guard.permit(custodian1, address(asm), bytes4(keccak256("mintDcdc(address,address,uint256)")));
        guard.permit(custodian1, address(asm), bytes4(keccak256("withdraw(address,uint256)")));
        guard.permit(custodian1, dpass, bytes4(keccak256("linkOldToNewToken(uint256,uint256)")));
        guard.permit(custodian1, dpass1, bytes4(keccak256("linkOldToNewToken(uint256,uint256)")));
        guard.permit(custodian1, dpass2, bytes4(keccak256("linkOldToNewToken(uint256,uint256)")));

        guard.permit(custodian2, address(asm), bytes4(keccak256("getRateNewest(address)")));
        guard.permit(custodian2, address(asm), bytes4(keccak256("getRate(address)")));
        guard.permit(custodian2, address(asm), bytes4(keccak256("burn(address,address,uint256)")));
        guard.permit(custodian2, address(asm), bytes4(keccak256("mint(address,address,uint256)")));
        guard.permit(custodian2, address(asm), bytes4(keccak256("burnDcdc(address,address,uint256)")));
        guard.permit(custodian2, address(asm), bytes4(keccak256("mintDpass(address,address,bytes32,bytes32,bytes32,bytes32,uint24,bytes32,bytes8,uint256)")));
        guard.permit(custodian2, address(asm), bytes4(keccak256("mintDcdc(address,address,uint256)")));
        guard.permit(custodian2, address(asm), bytes4(keccak256("withdraw(address,uint256)")));
        guard.permit(custodian2, dpass, bytes4(keccak256("linkOldToNewToken(uint256,uint256)")));
        guard.permit(custodian2, dpass1, bytes4(keccak256("linkOldToNewToken(uint256,uint256)")));
        guard.permit(custodian2, dpass2, bytes4(keccak256("linkOldToNewToken(uint256,uint256)")));
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

    function logMsgActualExpected(bytes32 logMsg, bytes32 actual_, bytes32 expected_, bool showActualExpected_) public {
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

    function assertEqLog(bytes32 logMsg, address actual_, address expected_) public {
        logMsgActualExpected(logMsg, actual_, expected_, false);
        assertEq(actual_, expected_);
    }

    function assertEqLog(bytes32 logMsg, bytes32 actual_, bytes32 expected_) public {
        logMsgActualExpected(logMsg, actual_, expected_, false);
        assertEq(actual_, expected_);
    }

    function assertEqLog(bytes32 logMsg, uint256 actual_, uint256 expected_) public {
        logMsgActualExpected(logMsg, actual_, expected_, false);
        assertEq(actual_, expected_);
    }

    function assertNotEqualLog(bytes32 logMsg, address actual_, address expected_) public {
        logMsgActualExpected(logMsg, actual_, expected_, actual_ == expected_);
        assertTrue(actual_ != expected_);
    }
}
//----------------end-of-IntegrationsTest--------------------------------------------
contract TrustedSASMTester is Wallet {
    SimpleAssetManagement asm;

    constructor(address payable asm_) public {
        asm = SimpleAssetManagement(asm_);
    }

    function doSetConfig(bytes32 what_, bytes32 value_, bytes32 value1_, bytes32 value2_) public {
        asm.setConfig(what_, value_, value1_, value2_);
    }

    function doSetBasePrice(address token, uint256 tokenId, uint256 price) public {
        asm.setBasePrice(token, tokenId, price);
    }

    function doUpdateCdcValue(address cdc) public {
        asm.updateCdcValue(cdc);
    }

    function doUpdateTotalDcdcValue(address dcdc) public {
        asm.updateTotalDcdcValue(dcdc);
    }

    function doUpdateDcdcValue(address dcdc, address custodian) public {
        asm.updateDcdcValue(dcdc, custodian);
    }

    function doNotifyTransferFrom(address token, address src, address dst, uint256 amtOrId) public {
        asm.notifyTransferFrom(token, src, dst, amtOrId);
    }

    function doBurn(address token, uint256 amt) public {
        asm.burn(token, amt);
    }

    function doMint(address token, address dst, uint256 amt) public {
        asm.mint(token, dst, amt);
    }

    function doMintDpass(
        address token_,
        address custodian_,
        bytes32 issuer_,
        bytes32 report_,
        bytes32 state_,
        bytes32 cccc_,
        uint24 carat_,
        bytes32 attributesHash_,
        bytes8 currentHashingAlgorithm_,
        uint price_
    ) public returns (uint) {

        return asm.mintDpass(
            token_,
            custodian_,
            issuer_,
            report_,
            state_,
            cccc_,
            carat_,
            attributesHash_,
            currentHashingAlgorithm_,
            price_);
    }

    function doMintDcdc(address token, address dst, uint256 amt) public {
        asm.mintDcdc(token, dst, amt);
    }

    function doBurnDcdc(address token, address dst, uint256 amt) public {
        asm.burnDcdc(token, dst, amt);
    }

    function doWithdraw(address token, uint256 amt) public {
        asm.withdraw(token, amt);
    }

    function doUpdateCollateralDpass(uint positiveV, uint negativeV, address custodian) public {
        asm.updateCollateralDpass(positiveV, negativeV, custodian);
    }

    function doUpdateCollateralDcdc(uint positiveV, uint negativeV, address custodian) public {
        asm.updateCollateralDcdc(positiveV, negativeV, custodian);
    }

    function doApprove(address token, address dst, uint256 amt) public {
        DSToken(token).approve(dst, amt);
    }

    function doSendToken(address token, address src, address payable dst, uint256 amt) public {
        sendToken(token, src, dst, amt);
    }

    function doSendDpassToken(address token, address src, address payable dst, uint256 id_) public {
        Dpass(token).transferFrom(src, dst, id_);
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


    constructor(address payable exchange_) public {
        require(exchange_ != address(0), "CET: exchange 0x0 invalid");
        exchange = DiamondExchange(exchange_);
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


contract TesterActor is TrustedSASMTester, DiamondExchangeTester {
    constructor(
        address payable exchange_,
        address payable asm_
    ) public TrustedSASMTester(asm_) DiamondExchangeTester(exchange_) {}
}
