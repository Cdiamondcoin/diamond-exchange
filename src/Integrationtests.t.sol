pragma solidity ^0.5.11;

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
import "./Redeemer.sol";

/**
 * @title Integrations Tests contract
 * @dev This contract we simulate basic use cases of system. The purpose of it is to show how different components
 * cooperate. Also upgrade of main contracts are simulated here to demonstrate feasibility.
 */
contract IntegrationsTest is DSTest, DSMath {

    event LogTest(uint256 what);
    event LogTest(bool what);
    event LogTest(address what);
    event LogTest(bytes32 what);
    event LogUintIpartUintFpart(bytes32 key, uint val, uint val1);

    address burner;
    address payable wal;
    address payable asm;
    address payable asmUpgrade;
    address payable dex;
    address payable dexUpgrade;
    address payable liq;
    address fca;
    address payable red;

    address payable user;
    address payable user1;
    address payable custodian;
    address payable custodian1;
    address payable custodian2;
    address auditor;

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
        _setupContracts();
    }

    function test1MintCdcInt() public returns (uint id) {             // use-case 1. Mint Cdc

        Dpass(dpass).setCccc("BR,IF,D,5.00", true); // enable a cccc value diamonds can have only cccc values that are enabled first

        id = TesterActor(custodian).doMintDpass(    // custodian must mint dpass first to create collateral for CDC
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

    function testFail1MintCdcInt() public {         // use-case 1. Mint CDC - failure if there is no collateral

        SimpleAssetManagement(asm)
            .mint(cdc, user, 1 ether);              // mint 1 CDC token to user
                                                    // usually we do not directly mint CDC to user, but use asm.notiryTransferFrom() function from dex to mint to user
    }

    function test2MintDpassInt() public returns(uint id) {              // use-case 2. Mint Dpass

        Dpass(dpass).setCccc("BR,IF,D,5.00", true); // enable a cccc value diamonds can have only cccc values that are enabled first

        id = TesterActor(custodian)
            .doMintDpass(
            dpass,                                  // token to mint (system can handle any number of different dpass tokens)
            custodian,                              // custodian of diamond, custodians can only set themselves no others
            "GIA",                                  // the issuer of following ID, currently GIA" is the only supported
            "2134567891",                           // GIA number (ID)
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
 
    function test22MintDcdcInt() public {
        TesterActor(custodian).doMintDcdc(dcdc, custodian, 5 ether);
        assertEqLog("dcdc-is-at-custodian", DSToken(dcdc).balanceOf(custodian), 5 ether);
        assertEqLog("dcdc-total-value", SimpleAssetManagement(asm).totalDcdcV(), wmul(cdcUsdRate, 5 ether));
    }

    function test3CdcPurchaseInt() public {

        uint daiPaid = 100 ether;

        DSToken(dai).transfer(user, daiPaid);       // send 10 DAI to user, so he can use it to buy CDC

        TesterActor(user)
            .doApprove(dai, dex, uint(-1));         // user must approve dex in order to trade

        Dpass(dpass).setCccc("BR,IF,D,5.00", true); // enable a cccc value diamonds can have only cccc values that are enabled first

        TesterActor(custodian)                      // **Mint some dpass diamond so that we can print cdc
            .doMintDpass(
            dpass,
            custodian,
            "GIA",
            "2134567893",
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

        logUint("fixFee", DiamondExchange(dex).fixFee(), 18);
        logUint("varFee", DiamondExchange(dex).varFee(), 18);
        logUint("user-cdc-balance", DSToken(cdc).balanceOf(user), 18);
        logUint("user-dai-balance", DSToken(dai).balanceOf(user), 18);
        logUint("asm-dai-balance", DSToken(dai).balanceOf(asm), 18);
        logUint("asm-cdc-balance", DSToken(cdc).balanceOf(asm), 18);
        logUint("wallet-dai-balance", DSToken(dai).balanceOf(wal), 18);
        logUint("liq-dpt-balance", DSToken(dpt).balanceOf(liq), 18);
        logUint("burner-dpt-balance", DSToken(dpt).balanceOf(burner), 18);
    }

    function test4DpassPurchaseInt() public returns(uint id) {       // use-case 4. Dpass purchase

        uint daiPaid = 4000 ether;

        DSToken(dai).transfer(user, daiPaid);       // send 4000 DAI to user, so he can use it to buy CDC

        TesterActor(user)
            .doApprove(dai, dex, uint(-1));         // user must approve dex in order to trade

        Dpass(dpass).setCccc("BR,IF,D,5.00", true); // enable a cccc value diamonds can have only cccc values that are enabled first

        DiamondExchange(dex).setConfig(             // before any token can be sold on dex, we must tell ...
            "canBuyErc721",                         // ... dex that users are allowed to buy it. ...
            b(dpass),                               // .... This must be done only once at configuration time.
            b(true));

        id = TesterActor(custodian)                 // **Mint some dpass diamond so that we can sell it
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
            daiPaid,                                                    // note that diamond costs less than user wants to pay, so only the price is subtracted from the user not the total value
            dpass,
            id
        );

        logUint("fixFee", DiamondExchange(dex).fixFee(), 18);
        logUint("varFee", DiamondExchange(dex).varFee(), 18);
        logUint("user-dai-balance", DSToken(dai).balanceOf(user), 18);
        logUint("asm-dai-balance", DSToken(dai).balanceOf(asm), 18);
        logUint("wallet-dai-balance", DSToken(dai).balanceOf(wal), 18);
        logUint("liq-dpt-balance", DSToken(dpt).balanceOf(liq), 18);
        logUint("burner-dpt-balance", DSToken(dpt).balanceOf(burner), 18);
        assertEqLog("user-is-owner", Dpass(dpass).ownerOf(id), user);
    }


    function testFail4DpassPurchaseInt() public {       // use-case 4. Dpass purchase failure - because single dpass is a collateral to cdc minted.

        uint daiPaid = 4000 ether;

        DSToken(dai).transfer(user, daiPaid);       // send 4000 DAI to user, so he can use it to buy CDC

        TesterActor(user)
            .doApprove(dai, dex, uint(-1));         // user must approve dex in order to trade

        Dpass(dpass).setCccc("BR,IF,D,5.00", true); // enable a cccc value diamonds can have only cccc values that are enabled first

        DiamondExchange(dex).setConfig(             // before any token can be sold on dex, we must tell ...
            "canBuyErc721",                         // ... dex that users are allowed to buy it. ...
            b(dpass),                               // .... This must be done only once at configuration time.
            b(true));

        uint id = TesterActor(custodian)            // **Mint some dpass diamond so that we can sell it
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
       //-this-is-the-difference-form-previous-test----------------------------------------

        TesterActor(user).doBuyTokensWithFee(       // user buys one single CDC whose only collateral is the one printed before.
            dai,
            1 ether,
            cdc,
            uint(-1)
        );
       //-this-is-the-difference-form-previous-test----------------------------------------

        TesterActor(user).doBuyTokensWithFee(       // THIS WILL FAIL!! Because if the only dpass is sold, there would be nothing ...
                                                    // ... to back the value of CDC sold in previous step.
            dai,
            daiPaid,                                // note that diamond costs less than user wants to pay, so only the price is subtracted from the user not the total value
            dpass,
            id
        );                                          // error Revert ("dex-sell-amount-exceeds-allowance")

        logUint("fixFee", DiamondExchange(dex).fixFee(), 18);
        logUint("varFee", DiamondExchange(dex).varFee(), 18);
        logUint("user-dai-balance", DSToken(dai).balanceOf(user), 18);
        logUint("asm-dai-balance", DSToken(dai).balanceOf(asm), 18);
        logUint("wallet-dai-balance", DSToken(dai).balanceOf(wal), 18);
        logUint("liq-dpt-balance", DSToken(dpt).balanceOf(liq), 18);
        logUint("burner-dpt-balance", DSToken(dpt).balanceOf(burner), 18);
    }

    function test5RedeemCdcInt() public {

        uint daiPaid = 4000 ether;
        require(daiPaid > 500 ether, "daiPaid should cover the costs of redeem");
        TesterActor(custodian).doMintDcdc(dcdc, custodian, 1000 ether);             // custodian mints 1000 dcdc token, meaning he has 1000 actual physical cdc diamonds on its stock

        DSToken(dai).transfer(user, daiPaid);                                       // send 4000 DAI to user, so he can use it to buy CDC

        TesterActor(user)
            .doApprove(dai, dex, uint(-1));                                         // user must approve dex in order to trade

        TesterActor(user)
            .doApprove(cdc, dex, uint(-1));                                         // user must approve dex in order to trade

        TesterActor(user).doBuyTokensWithFee(                                       // user buys cdc that he will redeem later
            dai, daiPaid - 500 ether, cdc, uint(-1));

        logUint("user-dai-balance", DSToken(dai).balanceOf(user), 18);
        logUint("wallet-dai-balance", DSToken(dai).balanceOf(wal), 18);
        logUint("liq-dpt-balance", DSToken(dpt).balanceOf(liq), 18);
        logUint("burner-dpt-balance", DSToken(dpt).balanceOf(burner), 18);
        logUint("user-cdc-balance-before-red", DSToken(cdc).balanceOf(user), 18);
        logUint("user-cdc-balance-before-red", DSToken(cdc).balanceOf(user), 18);

        uint redeemId =  TesterActor(user).doRedeem(                                // user redeems cdc token
                                   cdc,                                             // cdc is the token user wants to redeem
                                   uint(DSToken(cdc).balanceOf(user) / 10 ** 18 * 10 ** 18),              // user sends all cdc he has got
                                   dai,                                             // user pays redeem fee in dai
                                   uint(500 ether),                                 // the amount is determined by frontend and must cover shipping cost of ...
                                                                                    // ... custodian and 3% of redeem cost for Cdiamondcoin
                                   custodian);                                      // the custodian user gets diamonds from. This is also set by frontend.

        logUint("redeemer fixFee 0.03:",                                            // DISPLAYS 0.03 wrong, this is a bug!
                Redeemer(red).fixFee(), 18);
        logUint("redeemer varFee", Redeemer(red).varFee(), 18);
        logUint("user-cdc-balance-after-red", DSToken(cdc).balanceOf(user), 18);
        logUint("user-redeem-id", redeemId, 18);
        logUint("user-dai-balance", DSToken(dai).balanceOf(user), 18);
        logUint("asm-dai-balance", DSToken(dai).balanceOf(asm), 18);
        logUint("custodian-dai-balance", DSToken(dai).balanceOf(custodian), 18);
        logUint("wallet-dai-balance", DSToken(dai).balanceOf(wal), 18);
        logUint("liq-dpt-balance", DSToken(dpt).balanceOf(liq), 18);
        logUint("burner-dpt-balance", DSToken(dpt).balanceOf(burner), 18);
    }

    function test6RedeemDpassInt() public {
        uint daiPaid = 400 ether;

        DSToken(dai).transfer(user, daiPaid);                                       // send 4000 DAI to user, so he can use it to buy CDC

        TesterActor(user)
            .doApprove(dai, dex, uint(-1));                                         // user must approve dex in order to trade

        uint id = test4DpassPurchaseInt();                                          // first purchase dpass token

        TesterActor(user).doApprove721(dpass, dex, id);

        uint gas = gasleft();
        uint redeemId = TesterActor(user).doRedeem(                                 // redeem dpass
            dpass,
            id,
            dai,
            daiPaid,
            address(uint160(address(Dpass(dpass).getCustodian(id)))));

        logUint("redeem-gas-used", gas - gasleft(), 18);                            // gas used by redeeming dpass otken

        assertEqLog("diamond-state-is-redeemed",
                 Dpass(dpass).getState(id), b("redeemed"));
        logUint("redeemer fixFee (0.03):",                                          // DISPLAYS 0.03 wrong, this is a bug!
                Redeemer(red).fixFee(), 18);
        logUint("redeemer varFee", Redeemer(red).varFee(), 18);
        logUint("user-redeem-id", redeemId, 18);
        logUint("user-dai-balance", DSToken(dai).balanceOf(user), 18);
        logUint("asm-dai-balance", DSToken(dai).balanceOf(asm), 18);
        logUint("custodian-dai-balance", DSToken(dai).balanceOf(custodian), 18);
        logUint("wallet-dai-balance", DSToken(dai).balanceOf(wal), 18);
        logUint("liq-dpt-balance", DSToken(dpt).balanceOf(liq), 18);
        logUint("burner-dpt-balance", DSToken(dpt).balanceOf(burner), 18);
    }

    function test7CreateNewSetOfParametersForDpass() public {
        Dpass(dpass).setCccc("BR,IF,D,5.00", true);

        uint id = TesterActor(custodian).doMintDpass(
            dpass,
            custodian,
            "GIA",
            "2134567890",
            "sale",
            "BR,IF,D,5.00",
            511,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,

            "20191107",                                                             // here is a hashing algorithm
            2928.03 ether
        );

        TesterActor(custodian).doMintDpass(
            dpass,
            custodian,
            "GIA",
            "2222222222",
            "sale",
            "BR,IF,D,5.00",
            511,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,

            "20200101",                                                             // here is a new hashing algorithm
            2928.03 ether
        );

        Dpass(dpass).updateAttributesHash(                                          // we update old diamond algo
            id,
            0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee,
            "20200101");

        (,
         bytes32[6] memory attrs,
         ) = Dpass(dpass).getDiamondInfo(id);

         assertEqLog("attribute-has-changed",                                       // hash did change
            attrs[4],
            0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee);

        assertEqLog("hashing-algo-has-changed", attrs[5], "20200101");              // hashing algo did change

    }

    function test8SellDpassToOtherUser() public {
        uint id = test4DpassPurchaseInt();                      // First user buys dpass token
        uint daiPaid = 4000 ether;

        DSToken(dai).transfer(user1, daiPaid);                  // send 4000 DAI to the buyer user, so he can use it to buy CDC

        TesterActor(user1)
            .doApprove(dai, dex, uint(-1));                // buyer user must approve dex in order to trade

        TesterActor(user).doApprove721(dpass, dex, id);    // seller user must approve the dex
        TesterActor(user).doSetState(dpass, "sale", id);        // set state to "sale" is also needed in order to work on dex
        assertEqLog("user1-has-dai", DSToken(dai).balanceOf(user1), daiPaid);
        TesterActor(user1).doBuyTokensWithFee(
            dai,                                                // buyer user wants to pay with dai
            uint(-1),                                           // buyer user does not set an upper limit for payment, if he has enough token to sell, then the transaction goes through if not then not.
            dpass,
            id
        );

        logUint("user-dai-balance", DSToken(dai).balanceOf(user), 18);
        logUint("user1-dai-balance", DSToken(dai).balanceOf(user1), 18);
        assertEqLog("user-dpass-balance", Dpass(dpass).balanceOf(user), 0);
        assertEqLog("user1-dpass-balance", Dpass(dpass).balanceOf(user1), 1);

        logUint("fixFee", DiamondExchange(dex).fixFee(), 18);
        logUint("varFee", DiamondExchange(dex).varFee(), 18);
        logUint("user-dai-balance", DSToken(dai).balanceOf(user), 18);
        logUint("asm-dai-balance", DSToken(dai).balanceOf(asm), 18);
        logUint("wallet-dai-balance", DSToken(dai).balanceOf(wal), 18);
        logUint("liq-dpt-balance", DSToken(dpt).balanceOf(liq), 18);
        logUint("burner-dpt-balance", DSToken(dpt).balanceOf(burner), 18);
        assertEqLog("buyer-user-is-now-owner", Dpass(dpass).ownerOf(id), user1);

    }

    function testUpgradeAsmInt() public {               // testing of upgrading of exchange contract (dex)
        //------------------simulate-actions-prior-to-upgrade------------------------------
        uint id1 = test1MintCdcInt();                   // mint dpass (and returns its id) and cdc tokens
        uint id2 = test2MintDpassInt();                 // mint another dpass and returns tokens
        test22MintDcdcInt();                            // mint some dcdc tokens too

        //------------------upgrade-starts-HERE--------------------------------------------
        DiamondExchange(dex).stop();                    // stop exchange

        asmUpgrade = address(uint160(                   // deploy new asset managemet contract
            address(new SimpleAssetManagement())));

        _disableEveryoneUsingCurrentAsm();              // make sure no one has access to current asm while upgrade
        _upgradeAsmGuard();                             // setup guard first
        _configAsmForAsmUpgrade(id1, id2);              // configure exchange
        _configDexForAsmUpgrade();                      // config asm to handle upgraded exchange
        _configRedForAsmUpgrade();                      // config asm to handle upgraded exchange

        DiamondExchange(dex).start();                   // enable trade and redeem functionality

        //------------------upgrade-ends-HERE---------------------------------------------

        //------------------test-succsessful-upgrade---------------------------------------

        assertEqLog("dcdc-total-value", SimpleAssetManagement(asmUpgrade).totalDcdcV(), wmul(cdcUsdRate, 5 ether));
        assertEqLog("cdc-total-value", SimpleAssetManagement(asmUpgrade).totalCdcV(), wmul(cdcUsdRate, 1 ether));
        assertEqLog("dpass-total-value", SimpleAssetManagement(asmUpgrade).totalDpassV(), 2928.03 * 2 ether);
        assertEqLog("dpass-total-value-cust", SimpleAssetManagement(asmUpgrade).totalDpassCustV(custodian), 2928.03 * 2 ether);
        _configTest3CdcPurchaseAsmUpgradeInt();         // config test below to run with new dex
        test3CdcPurchaseInt();                          // let's check if we can exchange some tokens with upgraded exchange
    }

    function testUpgradeDexInt() public {               // testing of upgrading of exchange contract (dex)
        DiamondExchange(dex).stop();                    // make sure no one trades or redeems anything on dex
        dexUpgrade = address(uint160(                   // deploy new exchange contract
            address(new DiamondExchange())));

        DiamondExchange(dexUpgrade).stop();             // disable trade and redeem functionality

        _upgradeDexGuard();                             // setup guard first
        _configDexForDexUpgrade();                            // configure exchange
        _configAsmForDexUpgrade();                      // config asm to handle upgraded exchange
        _configRedeemerForDexUpgrade();                 // setup redeemer for new dex

        DiamondExchange(dexUpgrade).start();            // enable trade and redeem functionality

        _configTest3CdcPurchaseInt();                   // config test below to run with new dex
        test3CdcPurchaseInt();                          // let's check if we can exchange some tokens with upgraded exchange
    }
//---------------------------end-of-tests-------------------------------------------------------------------

    function _disableEveryoneUsingCurrentAsm() internal {
        // if something was permitted with ANY, it must be forbidden with ANY, and if it was with bytes4(keccak()) then with bytes4(keccak(), if you try to forbid permitted bytes4(keccak()) with ANY it will not work!!!!!!!

        // DO NOT DISABLE YOUSELF!!!!

        guard.forbid(dex, asm, ANY);
        guard.forbid(red, asm, ANY);

        guard.forbid(custodian, address(asm), bytes4(keccak256("getRateNewest(address)")));
        guard.forbid(custodian, address(asm), bytes4(keccak256("getRate(address)")));
        guard.forbid(custodian, address(asm), bytes4(keccak256("burn(address,address,uint256)")));
        guard.forbid(custodian, address(asm), bytes4(keccak256("mint(address,address,uint256)")));
        guard.forbid(custodian, address(asm), bytes4(keccak256("burnDcdc(address,address,uint256)")));
        guard.forbid(custodian, address(asm), bytes4(keccak256("mintDpass(address,address,bytes3,bytes16,bytes8,bytes20,uint24,bytes32,bytes8,uint256)")));
        guard.forbid(custodian, address(asm), bytes4(keccak256("mintDcdc(address,address,uint256)")));
        guard.forbid(custodian, address(asm), bytes4(keccak256("withdraw(address,uint256)")));

        guard.forbid(custodian1, address(asm), bytes4(keccak256("getRateNewest(address)")));
        guard.forbid(custodian1, address(asm), bytes4(keccak256("getRate(address)")));
        guard.forbid(custodian1, address(asm), bytes4(keccak256("burn(address,address,uint256)")));
        guard.forbid(custodian1, address(asm), bytes4(keccak256("mint(address,address,uint256)")));
        guard.forbid(custodian1, address(asm), bytes4(keccak256("burnDcdc(address,address,uint256)")));
        guard.forbid(custodian1, address(asm), bytes4(keccak256("mintDpass(address,address,bytes32,bytes32,bytes32,bytes32,uint24,bytes32,bytes8,uint256)")));
        guard.forbid(custodian1, address(asm), bytes4(keccak256("mintDcdc(address,address,uint256)")));
        guard.forbid(custodian1, address(asm), bytes4(keccak256("withdraw(address,uint256)")));

        guard.forbid(custodian2, address(asm), bytes4(keccak256("getRateNewest(address)")));
        guard.forbid(custodian2, address(asm), bytes4(keccak256("getRate(address)")));
        guard.forbid(custodian2, address(asm), bytes4(keccak256("burn(address,address,uint256)")));
        guard.forbid(custodian2, address(asm), bytes4(keccak256("mint(address,address,uint256)")));
        guard.forbid(custodian2, address(asm), bytes4(keccak256("burnDcdc(address,address,uint256)")));
        guard.forbid(custodian2, address(asm), bytes4(keccak256("mintDpass(address,address,bytes32,bytes32,bytes32,bytes32,uint24,bytes32,bytes8,uint256)")));
        guard.forbid(custodian2, address(asm), bytes4(keccak256("mintDcdc(address,address,uint256)")));
        guard.forbid(custodian2, address(asm), bytes4(keccak256("withdraw(address,uint256)")));

        guard.forbid(auditor, asm, bytes4(keccak256("setAudit(address,uint256,bytes32,bytes32,uint32)")));
    }

    function _upgradeAsmGuard() internal {
        SimpleAssetManagement(asmUpgrade).setAuthority(guard);
        guard.permit(address(this), asmUpgrade, ANY);
        guard.permit(asmUpgrade, cdc, ANY);
        guard.permit(asmUpgrade, cdc1, ANY);
        guard.permit(asmUpgrade, cdc2, ANY);
        guard.permit(asmUpgrade, dcdc, ANY);
        guard.permit(asmUpgrade, dcdc1, ANY);
        guard.permit(asmUpgrade, dcdc2, ANY);
        guard.permit(asmUpgrade, dpass, ANY);
        guard.permit(asmUpgrade, dpass1, ANY);
        guard.permit(asmUpgrade, dpass2, ANY);
        guard.permit(dex, asmUpgrade, ANY);
        guard.permit(red, asmUpgrade, ANY);
        guard.permit(custodian, asmUpgrade, bytes4(keccak256("getRateNewest(address)")));
        guard.permit(custodian, asmUpgrade, bytes4(keccak256("getRate(address)")));
        guard.permit(custodian, asmUpgrade, bytes4(keccak256("burn(address,address,uint256)")));
        guard.permit(custodian, asmUpgrade, bytes4(keccak256("mint(address,address,uint256)")));
        guard.permit(custodian, asmUpgrade, bytes4(keccak256("burnDcdc(address,address,uint256)")));
        guard.permit(custodian, asmUpgrade, bytes4(keccak256("mintDpass(address,address,bytes3,bytes16,bytes8,bytes20,uint24,bytes32,bytes8,uint256)")));
        guard.permit(custodian, asmUpgrade, bytes4(keccak256("setBasePrice(address,uint256,uint256)")));

        guard.permit(custodian, asmUpgrade, bytes4(keccak256("mintDcdc(address,address,uint256)")));
        guard.permit(custodian, asmUpgrade, bytes4(keccak256("withdraw(address,uint256)")));
        guard.permit(custodian1, asmUpgrade, bytes4(keccak256("getRateNewest(address)")));
        guard.permit(custodian1, asmUpgrade, bytes4(keccak256("getRate(address)")));
        guard.permit(custodian1, asmUpgrade, bytes4(keccak256("burn(address,address,uint256)")));
        guard.permit(custodian1, asmUpgrade, bytes4(keccak256("mint(address,address,uint256)")));
        guard.permit(custodian1, asmUpgrade, bytes4(keccak256("burnDcdc(address,address,uint256)")));
        guard.permit(custodian1, asmUpgrade, bytes4(keccak256("mintDpass(address,address,bytes32,bytes32,bytes32,bytes32,uint24,bytes32,bytes8,uint256)")));
        guard.permit(custodian1, asmUpgrade, bytes4(keccak256("mintDcdc(address,address,uint256)")));
        guard.permit(custodian1, asmUpgrade, bytes4(keccak256("withdraw(address,uint256)")));

        guard.permit(custodian1, asmUpgrade, bytes4(keccak256("setBasePrice(address,uint256,uint256)")));
        guard.permit(custodian2, asmUpgrade, bytes4(keccak256("getRateNewest(address)")));
        guard.permit(custodian2, asmUpgrade, bytes4(keccak256("getRate(address)")));
        guard.permit(custodian2, asmUpgrade, bytes4(keccak256("burn(address,address,uint256)")));
        guard.permit(custodian2, asmUpgrade, bytes4(keccak256("mint(address,address,uint256)")));
        guard.permit(custodian2, asmUpgrade, bytes4(keccak256("burnDcdc(address,address,uint256)")));
        guard.permit(custodian2, asmUpgrade, bytes4(keccak256("mintDpass(address,address,bytes32,bytes32,bytes32,bytes32,uint24,bytes32,bytes8,uint256)")));
        guard.permit(custodian2, asmUpgrade, bytes4(keccak256("mintDcdc(address,address,uint256)")));
        guard.permit(custodian2, asmUpgrade, bytes4(keccak256("withdraw(address,uint256)")));
        guard.permit(custodian2, asmUpgrade, bytes4(keccak256("setBasePrice(address,uint256,uint256)")));
        guard.permit(auditor, asmUpgrade, bytes4(keccak256("setAudit(address,uint256,bytes32,bytes32,uint32)")));
    }

    function _configAsmForAsmUpgrade(uint256 id1, uint256 id2) internal {

       //-------------setup-asmUpgrade------------------------------------------------------------
        SimpleAssetManagement(asmUpgrade).setConfig("priceFeed", b(cdc), b(address(cdcFeed)), "diamonds"); // set price feed (sam as for dex)
        SimpleAssetManagement(asmUpgrade).setConfig("manualRate", b(cdc), b(true), "diamonds");            // enable to use rate that is not coming from feed
        SimpleAssetManagement(asmUpgrade).setConfig("decimals", b(cdc), b(18), "diamonds");                // set precision of token to 18
        SimpleAssetManagement(asmUpgrade).setConfig("payTokens", b(cdc), b(true), "diamonds");             // allow cdc to be used as means of payment for services



        //----LINE-BELOW-IS-IMPORTANT!!!!!!!!!----------------------------------------------------
        SimpleAssetManagement(asmUpgrade).setConfig(
            "cdcPurchaseV",                                                                                // set the total value of all cdc in the system in PURCHASE TIME PRICE
            b(cdc),                                                                                        // the cdc token address  (if we have more than one cdc token this process must be done for all 
            b(SimpleAssetManagement(asm).cdcPurchaseV(cdc)),                                               // get the purchase price form the old contract
            b(uint(0))                                                                                     // at upgrade this should be always zero.
        ); 


        SimpleAssetManagement(asmUpgrade).setConfig("cdcs", b(cdc), b(true), "diamonds");                  // tell asmUpgrade that cdc is indeed a cdc token
        SimpleAssetManagement(asmUpgrade).setConfig("rate", b(cdc), b(cdcUsdRate), "diamonds");            // set rate for token
        SimpleAssetManagement(asmUpgrade).setConfig("priceFeed", b(eth), b(address(ethFeed)), "diamonds"); // set pricefeed for eth
        SimpleAssetManagement(asmUpgrade).setConfig("payTokens", b(eth), b(true), "diamonds");             // enable eth to pay with
        SimpleAssetManagement(asmUpgrade).setConfig("manualRate", b(eth), b(true), "diamonds");            // enable to set rate of eth manually if feed is dowh (as is current situations)
        SimpleAssetManagement(asmUpgrade).setConfig("decimals", b(eth), b(18), "diamonds");                // set precision for eth token
        SimpleAssetManagement(asmUpgrade).setConfig("rate", b(eth), b(ethUsdRate), "diamonds");            // set USD(base currency) rate of token ( this is the price of token in USD)
        SimpleAssetManagement(asmUpgrade).setConfig("priceFeed", b(dai), b(address(daiFeed)), "diamonds"); // set pricefeed for dai
        SimpleAssetManagement(asmUpgrade).setConfig("payTokens", b(dai), b(true), "diamonds");             // enable dai to pay with
        SimpleAssetManagement(asmUpgrade).setConfig("manualRate", b(dai), b(true), "diamonds");            // enable to set rate of dai manually if feed is dowh (as is current situations)
        SimpleAssetManagement(asmUpgrade).setConfig("decimals", b(dai), b(18), "diamonds");                // set precision for dai token
        SimpleAssetManagement(asmUpgrade).setConfig("rate", b(dai), b(daiUsdRate), "diamonds");            // set USD(base currency) rate of token ( this is the price of token in USD)
        SimpleAssetManagement(asmUpgrade).setConfig("dpasses", b(dpass), b(true), "diamonds");             // enable the dpass tokens of asmUpgrade to be handled by dex
        SimpleAssetManagement(asmUpgrade).setConfig("setApproveForAll", b(dpass), b(dex), b(true));        // enable the dpass tokens of asmUpgrade to be handled by dex
        SimpleAssetManagement(asmUpgrade).setConfig("custodians", b(custodian), b(true), "diamonds");      // setup the custodian set all custodians this way
        SimpleAssetManagement(asmUpgrade).setConfig("custodians", b(custodian1), b(true), "diamonds");     // setup the custodian set all custodians this way
        SimpleAssetManagement(asmUpgrade).setConfig("custodians", b(custodian2), b(true), "diamonds");     // setup the custodian set all custodians this way

        // setting follosing makes sure that custodians in new contract do not get overpaid

        SimpleAssetManagement(asmUpgrade).setConfig(
            "totalPaidCustV",
            b(custodian),
            b(
                SimpleAssetManagement(asm).totalPaidCustV(custodian) - 
                SimpleAssetManagement(asm).dpassSoldCustV(custodian)),
            "diamonds");     // setup the custodian set all custodians this way

        SimpleAssetManagement(asmUpgrade).setConfig(
            "totalPaidCustV",
            b(custodian1),
            b(
                SimpleAssetManagement(asm).totalPaidCustV(custodian1) - 
                SimpleAssetManagement(asm).dpassSoldCustV(custodian1)),
            "diamonds");     // setup the custodian set all custodians this way

        SimpleAssetManagement(asmUpgrade).setConfig(
            "totalPaidCustV",
            b(custodian2),
            b(
                SimpleAssetManagement(asm).totalPaidCustV(custodian2) - 
                SimpleAssetManagement(asm).dpassSoldCustV(custodian2)),
            "diamonds");     // setup the custodian set all custodians this way

        SimpleAssetManagement(asmUpgrade).setCapCustV(custodian, 1000000000 ether);                        // set 1 billion total value cap. If custodian total value of dcdc and dpass minted value reaches this value, then custodian can no longer mint neither dcdc nor dpass. In production never let the custodians have capCustV more than 20% of their current value.
        SimpleAssetManagement(asmUpgrade).setConfig("priceFeed", b(dcdc), b(address(cdcFeed)), "diamonds"); // set price feed (asmUpgrade as for dex)
        SimpleAssetManagement(asmUpgrade).setConfig("manualRate", b(dcdc), b(true), "diamonds");            // enable to use rate that is not coming from feed
        SimpleAssetManagement(asmUpgrade).setConfig("decimals", b(dcdc), b(18), "diamonds");                // set precision of token to 18
        SimpleAssetManagement(asmUpgrade).setConfig("dcdcs", b(dcdc), b(true), "diamonds");                 // tell asmUpgrade that dcdc is indeed a dcdc token
        SimpleAssetManagement(asmUpgrade).setConfig("rate", b(dcdc), b(cdcUsdRate), "diamonds");            // set rate for token

        //----------------------send-all-unsold-dpass-tokens-to-new-asm----------------------------------
        SimpleAssetManagement(asm).setConfig("setApproveForAll", b(dpass), b(address(this)), b(true));      // enable us to transfer unsold dpass tokens.
        Dpass(dpass).transferFrom(asm, asmUpgrade, id1);                                                    // if there are more diamonds you send them all
        Dpass(dpass).transferFrom(asm, asmUpgrade, id2);                                                    // if there are more diamonds you send them all
        TesterActor(custodian).setAsm(asmUpgrade);                                                          // set custodian to handle upgraded asm
        TesterActor(custodian).doSetBasePrice(                                                              // set base price on new asm, must be done for all dpass tokens
            dpass, 
            id1,
            SimpleAssetManagement(asm).basePrice(dpass, id1));                                              // get base price (optionally) from old asm
        TesterActor(custodian).doSetBasePrice(                                                              // set base price on new asm, must be done for all dpass tokens
            dpass, 
            id2,
            SimpleAssetManagement(asm).basePrice(dpass, id2));                                              // get base price (optionally) from old asm
        //----------------------set-info-of-dcdc-tokens-at-upgraded-asm----------------------------------
        SimpleAssetManagement(asmUpgrade).setDcdcV(dcdc, custodian);                                        // update dcdc value for all custodians
        //----------------------setting-overCollRatio-MUST COME AFTER ADDING ALL DPASS, and DCDC contract otherwise system reverts with "asm-system-undercollaterized" 
        SimpleAssetManagement(asmUpgrade).setConfig("overCollRatio", b(uint(1.1 ether)), "", "diamonds");   // make sure that the value of dpass + dcdc tokens is at least 1.1 times the value of cdc tokens.
        SimpleAssetManagement(asmUpgrade).setConfig("overCollRemoveRatio", b(uint(1.05 ether)), "", "diamonds");  // make sure that the value of dpass + dcdc tokens is at least 1.1 times the value of cdc tokens.
    }

    function _configDexForAsmUpgrade() internal {
        DiamondExchange(dex).setConfig("asm", b(asmUpgrade), b(""));                                       // set asset management contract
    }

    function _configRedForAsmUpgrade() internal {
        Redeemer(red).setConfig("asm", b(asmUpgrade), "", "");                                              // tell redeemer the address of asset management
    }

    function _configTest3CdcPurchaseAsmUpgradeInt() internal {
        asm = asmUpgrade;                               // now asm points to the upgraded exchanges address(in order to run next test)
        TesterActor(user).setAsm(asm);                  // test user uses new asm
        TesterActor(custodian).setAsm(asm);             // custodian uses new asm
    }


    function _configTest3CdcPurchaseInt() internal {
        dex = dexUpgrade;                               // now dex points to the upgraded exchanges address(in order to run next test)
        TesterActor(user).setDex(dex);                  // test user uses new dex
        TesterActor(custodian).setDex(dex);             // custodian uses new dex
    }

    function _upgradeDexGuard() internal {
        DiamondExchange(dexUpgrade).setAuthority(guard);
        guard.permit(dexUpgrade, asm, ANY);
        guard.permit(dexUpgrade, liq, ANY);
    }

    function _configDexForDexUpgrade() internal {
        Liquidity(liq).approve(dpt, dexUpgrade, uint(-1));
        DiamondExchange(dexUpgrade).setConfig("decimals", b(cdc), b(18));                 // decimal precision of cdc tokens is 18
        DiamondExchange(dexUpgrade).setConfig("canSellErc20", b(cdc), b(true));           // user can sell cdc tokens
        DiamondExchange(dexUpgrade).setConfig("canBuyErc20", b(cdc), b(true));            // user can buy cdc tokens
        DiamondExchange(dexUpgrade).setConfig("priceFeed", b(cdc), b(address(cdcFeed)));  // priceFeed address is set
        DiamondExchange(dexUpgrade).setConfig("handledByAsm", b(cdc), b(true));           // make sure that cdc is minted by asset management
        DiamondExchange(dexUpgrade).setConfig(b("rate"), b(cdc), b(uint(cdcUsdRate)));    // rate of token in base currency (since Medianizer will return false, this value will be used)
        DiamondExchange(dexUpgrade).setConfig(b("manualRate"), b(cdc), b(true));          // allow using manually set prices on cdc token

        DiamondExchange(dexUpgrade).setConfig("decimals", b(eth), b(18));                 // decimal precision of eth tokens is 18
        DiamondExchange(dexUpgrade).setConfig("canSellErc20", b(eth), b(true));           // user can sell eth tokens
        // DiamondExchange(dexUpgrade).setConfig("canBuyErc20", b(eth), b(true));         // user CAN NOT BUY ETH ON THIS EXCHANAGE
        DiamondExchange(dexUpgrade).setConfig("priceFeed", b(eth), b(address(ethFeed)));  // priceFeed address is set
        // DiamondExchange(dexUpgrade).setConfig("handledByAsm", b(eth), b(true));        // eth SHOULD NEVER BE DECLARED AS handledByAsm, because it can not be minted
        DiamondExchange(dexUpgrade).setConfig(b("rate"), b(eth), b(uint(ethUsdRate)));    // rate of token in base currency (since Medianizer will return false, this value will be used)
        DiamondExchange(dexUpgrade).setConfig(b("manualRate"), b(eth), b(true));          // allow using manually set prices on eth token
        DiamondExchange(dexUpgrade).setConfig("redeemFeeToken", b(eth), b(true));         // set eth as a token with which redeem fee can be paid

        DiamondExchange(dexUpgrade).setConfig("decimals", b(dai), b(18));                 // decimal precision of dai tokens is 18
        DiamondExchange(dexUpgrade).setConfig("canSellErc20", b(dai), b(true));           // user can sell dai tokens
        DiamondExchange(dexUpgrade).setConfig("priceFeed", b(dai), b(address(daiFeed)));  // priceFeed address is set
        DiamondExchange(dexUpgrade).setConfig(b("rate"), b(dai), b(uint(daiUsdRate)));    // rate of token in base currency (since Medianizer will return false, this value will be used)
        DiamondExchange(dexUpgrade).setConfig(b("manualRate"), b(dai), b(true));          // allow using manually set prices on dai token
        DiamondExchange(dexUpgrade).setConfig("redeemFeeToken", b(dai), b(true));         // set dai as a token with which redeem fee can be paid

        DiamondExchange(dexUpgrade).setConfig("decimals", b(dpt), b(18));                 // decimal precision of dpt tokens is 18
        DiamondExchange(dexUpgrade).setConfig("canSellErc20", b(dpt), b(true));           // user can sell dpt tokens
        DiamondExchange(dexUpgrade).setConfig("priceFeed", b(dpt), b(address(dptFeed)));  // priceFeed address is set
        DiamondExchange(dexUpgrade).setConfig(b("rate"), b(dpt), b(uint(dptUsdRate)));    // rate of token in base currency (since Medianizer will return false, this value will be used)
        DiamondExchange(dexUpgrade).setConfig(b("manualRate"), b(dpt), b(true));          // allow using manually set prices on dpt token
        DiamondExchange(dexUpgrade).setConfig("redeemFeeToken", b(dpt), b(true));         // set dpt as a token with which redeem fee can be paid

        DiamondExchange(dexUpgrade).setConfig("dpt", b(dpt), "");                         // tell exhcange which one is the DPT token
        DiamondExchange(dexUpgrade).setConfig("liq", b(liq), "");                         // set liquidity contract
        DiamondExchange(dexUpgrade).setConfig("burner", b(burner), b(""));                // set burner contract to burn profit of dpt owners
        DiamondExchange(dexUpgrade).setConfig("asm", b(asm), b(""));                      // set asset management contract
        DiamondExchange(dexUpgrade).setConfig("wal", b(wal), b(""));                      // set wallet to store cost part of fee received from users

        DiamondExchange(dexUpgrade).setConfig("fixFee", b(uint(0 ether)), b(""));         // fixed part of fee that is independent of purchase value
        DiamondExchange(dexUpgrade).setConfig("varFee", b(uint(0.03 ether)), b(""));      // percentage value defining how much of purchase value if paid as fee value between 0 - 1 ether
        DiamondExchange(dexUpgrade).setConfig("profitRate", b(uint(0.1 ether)), b(""));   // percentage value telling how much of total fee goes to profit of DPT owners
        DiamondExchange(dexUpgrade).setConfig(b("takeProfitOnlyInDpt"), b(true), b(""));  // if set true only profit part of fee is withdrawn from user in DPT, if false the total fee will be taken from user in DPT
        DiamondExchange(dexUpgrade).setConfig("redeemer", b(red), b(""));                 // set wallet to store cost part of fee received from users
    }

    function _configAsmForDexUpgrade() internal {
        SimpleAssetManagement(asm).setConfig("setApproveForAll", b(dpass), b(dexUpgrade), b(true));        // enable the dpass tokens of asm to be handled by dexUpgrade
    }

    function _configRedeemerForDexUpgrade() internal {
        Redeemer(red).setConfig("dex", b(dexUpgrade), "", "");                             // tell redeemer the address of dexUpgrade
        Redeemer(red).setConfig(
            "profitRate",
            b(DiamondExchange(dexUpgrade).profitRate()), "", "");                          // tell redeemer the profitRate (should be same as we set in dexUpgrade), the rate of profit belonging to dpt owners
    }

    function logUint(bytes32 what, uint256 num, uint256 dec) public {
        emit LogUintIpartUintFpart( what, num / 10 ** dec, num % 10 ** dec);
    }

    function _prepareDai() public {
        daiUsdRate = 1 ether;

        daiFeed = new Medianizer();                    // create medianizer that calculates single price from multiple price sources

        daiPriceOracle0 = new PriceFeed();             // oracle is a single price source that receives price data from several sources
        daiPriceOracle1 = new PriceFeed();             // dai price is updated every once a week
        daiPriceOracle2 = new PriceFeed();

        daiFeed.set(address(daiPriceOracle0));         // add oracle to medianizer to get price data from
        daiFeed.set(address(daiPriceOracle1));
        daiFeed.set(address(daiPriceOracle2));

        //--------------------oracles-update-price-data--------------------------------begin
        daiPriceOracle0.poke(                          // oracle update dai price every once a week
            uint128(daiUsdRate),
            60 * 60 * 24 * 8                           // the data is valid for 8 days
        );

        daiPriceOracle1.poke(                          // oracle update dai price every once a week
            uint128(daiUsdRate),
            60 * 60 * 24 * 8                           // the data is valid for 8 days
        );

        daiPriceOracle1.poke(                          // oracle update dai price every once a week
            uint128(daiUsdRate),
            60 * 60 * 24 * 8                           // the data is valid for 8 days
        );
        daiFeed.poke();

        //--------------------oracles-update-price-data--------------------------------end
    }

    function _setupContracts() internal {
        cdcUsdRate = 80 ether;
        dptUsdRate = 100 ether;
        ethUsdRate = 150 ether;

        _prepareDai();

        cdcFeed = new Medianizer();                    // create medianizer that calculates single price from multiple price sources

        cdcPriceOracle0 = new PriceFeed();             // oracle is a single price source that receives price data from several sources
        cdcPriceOracle1 = new PriceFeed();             // cdc price is updated every once a week
        cdcPriceOracle2 = new PriceFeed();

        cdcFeed.set(address(cdcPriceOracle0));         // add oracle to medianizer to get price data from
        cdcFeed.set(address(cdcPriceOracle1));
        cdcFeed.set(address(cdcPriceOracle2));

        //--------------------oracles-update-price-data--------------------------------begin
        cdcPriceOracle0.poke(                          // oracle update cdc price every once a week
            uint128(cdcUsdRate),
            60 * 60 * 24 * 8                           // the data is valid for 8 days
        );

        cdcPriceOracle1.poke(                          // oracle update cdc price every once a week
            uint128(cdcUsdRate),
            60 * 60 * 24 * 8                           // the data is valid for 8 days
        );

        cdcPriceOracle1.poke(                          // oracle update cdc price every once a week
            uint128(cdcUsdRate),
            60 * 60 * 24 * 8                           // the data is valid for 8 days
        );
        cdcFeed.poke();

        //--------------------oracles-update-price-data--------------------------------end
        dptFeed = new Medianizer();                    // create medianizer that calculates single price from multiple price sources

        dptPriceOracle0 = new PriceFeed();             // oracle is a single price source that receives price data from several sources
        dptPriceOracle1 = new PriceFeed();             // dpt price is updated every once a week
        dptPriceOracle2 = new PriceFeed();

        dptFeed.set(address(dptPriceOracle0));         // add oracle to medianizer to get price data from
        dptFeed.set(address(dptPriceOracle1));
        dptFeed.set(address(dptPriceOracle2));
        //--------------------oracles-update-price-data--------------------------------begin
        dptPriceOracle0.poke(                          // oracle update dpt price every once a week
            uint128(dptUsdRate),
            60 * 60 * 12                               // the data is valid for 12 hours
        );

        dptPriceOracle1.poke(                          // oracle update dpt price every once a week
            uint128(dptUsdRate),
            60 * 60 * 24 * 8                           // the data is valid for 8 days
        );

        dptPriceOracle1.poke(                          // oracle update dpt price every once a week
            uint128(dptUsdRate),
            60 * 60 * 24 * 8                           // the data is valid for 8 days
        );
        dptFeed.poke();
        //--------------------oracles-update-price-data--------------------------------end

        ethFeed = new Medianizer();

        ethPriceOracle0 = new PriceFeed();             // oracle is a single price source that receives price data from several sources
        ethPriceOracle1 = new PriceFeed();             // eth price is updated every time the price changes more than 2%
        ethPriceOracle2 = new PriceFeed();

        ethFeed.set(address(ethPriceOracle0));         // add oracle to medianizer to get price data from
        ethFeed.set(address(ethPriceOracle1));
        ethFeed.set(address(ethPriceOracle2));

        //--------------------oracles-update-price-data--------------------------------begin
        ethPriceOracle0.poke(                          // oracle update eth price every once a week
            uint128(ethUsdRate),
            60 * 60 * 24 * 8                           // the data is valid for 8 days
        );

        ethPriceOracle1.poke(                          // oracle update eth price every once a week
            uint128(ethUsdRate),
            60 * 60 * 24 * 8                           // the data is valid for 8 days
        );

        ethPriceOracle1.poke(                          // oracle update eth price every once a week
            uint128(ethUsdRate),
            60 * 60 * 24 * 8                           // the data is valid for 8 days
        );

        ethFeed.poke();
        //--------------------oracles-update-price-data--------------------------------end
//--------------setup-liq------------------------------------------------------------

        DSToken(dpt).transfer(liq, INITIAL_BALANCE);
        Liquidity(liq).approve(dpt, dex, uint(-1));
        Liquidity(liq).approve(dpt, red, uint(-1));

//--------------setup-dex------------------------------------------------------------

        DiamondExchange(dex).setConfig("decimals", b(cdc), b(18));                 // decimal precision of cdc tokens is 18
        DiamondExchange(dex).setConfig("canSellErc20", b(cdc), b(true));           // user can sell cdc tokens
        DiamondExchange(dex).setConfig("canBuyErc20", b(cdc), b(true));            // user can buy cdc tokens
        DiamondExchange(dex).setConfig("priceFeed", b(cdc), b(address(cdcFeed)));  // priceFeed address is set
        DiamondExchange(dex).setConfig("handledByAsm", b(cdc), b(true));           // make sure that cdc is minted by asset management
        DiamondExchange(dex).setConfig(b("rate"), b(cdc), b(uint(cdcUsdRate)));    // rate of token in base currency (since Medianizer will return false, this value will be used)
        DiamondExchange(dex).setConfig(b("manualRate"), b(cdc), b(true));          // allow using manually set prices on cdc token

        DiamondExchange(dex).setConfig("decimals", b(eth), b(18));                 // decimal precision of eth tokens is 18
        DiamondExchange(dex).setConfig("canSellErc20", b(eth), b(true));           // user can sell eth tokens
        // DiamondExchange(dex).setConfig("canBuyErc20", b(eth), b(true));         // user CAN NOT BUY ETH ON THIS EXCHANAGE
        DiamondExchange(dex).setConfig("priceFeed", b(eth), b(address(ethFeed)));  // priceFeed address is set
        // DiamondExchange(dex).setConfig("handledByAsm", b(eth), b(true));        // eth SHOULD NEVER BE DECLARED AS handledByAsm, because it can not be minted
        DiamondExchange(dex).setConfig(b("rate"), b(eth), b(uint(ethUsdRate)));    // rate of token in base currency (since Medianizer will return false, this value will be used)
        DiamondExchange(dex).setConfig(b("manualRate"), b(eth), b(true));          // allow using manually set prices on eth token
        DiamondExchange(dex).setConfig("redeemFeeToken", b(eth), b(true));         // set eth as a token with which redeem fee can be paid

        DiamondExchange(dex).setConfig("decimals", b(dai), b(18));                 // decimal precision of dai tokens is 18
        DiamondExchange(dex).setConfig("canSellErc20", b(dai), b(true));           // user can sell dai tokens
        DiamondExchange(dex).setConfig("priceFeed", b(dai), b(address(daiFeed)));  // priceFeed address is set
        DiamondExchange(dex).setConfig(b("rate"), b(dai), b(uint(daiUsdRate)));    // rate of token in base currency (since Medianizer will return false, this value will be used)
        DiamondExchange(dex).setConfig(b("manualRate"), b(dai), b(true));          // allow using manually set prices on dai token
        DiamondExchange(dex).setConfig("redeemFeeToken", b(dai), b(true));         // set dai as a token with which redeem fee can be paid

        DiamondExchange(dex).setConfig("decimals", b(dpt), b(18));                 // decimal precision of dpt tokens is 18
        DiamondExchange(dex).setConfig("canSellErc20", b(dpt), b(true));           // user can sell dpt tokens
        DiamondExchange(dex).setConfig("priceFeed", b(dpt), b(address(dptFeed)));  // priceFeed address is set
        DiamondExchange(dex).setConfig(b("rate"), b(dpt), b(uint(dptUsdRate)));    // rate of token in base currency (since Medianizer will return false, this value will be used)
        DiamondExchange(dex).setConfig(b("manualRate"), b(dpt), b(true));          // allow using manually set prices on dpt token
        DiamondExchange(dex).setConfig("redeemFeeToken", b(dpt), b(true));         // set dpt as a token with which redeem fee can be paid

        DiamondExchange(dex).setConfig("dpt", b(dpt), "");                         // tell exhcange which one is the DPT token
        DiamondExchange(dex).setConfig("liq", b(liq), "");                         // set liquidity contract
        DiamondExchange(dex).setConfig("burner", b(burner), b(""));                // set burner contract to burn profit of dpt owners
        DiamondExchange(dex).setConfig("asm", b(asm), b(""));                      // set asset management contract
        DiamondExchange(dex).setConfig("wal", b(wal), b(""));                      // set wallet to store cost part of fee received from users

        DiamondExchange(dex).setConfig("fixFee", b(uint(0 ether)), b(""));         // fixed part of fee that is independent of purchase value
        DiamondExchange(dex).setConfig("varFee", b(uint(0.03 ether)), b(""));      // percentage value defining how much of purchase value if paid as fee value between 0 - 1 ether
        DiamondExchange(dex).setConfig("profitRate", b(uint(0.1 ether)), b(""));   // percentage value telling how much of total fee goes to profit of DPT owners
        DiamondExchange(dex).setConfig(b("takeProfitOnlyInDpt"), b(true), b(""));  // if set true only profit part of fee is withdrawn from user in DPT, if false the total fee will be taken from user in DPT
       //-------------setup-asm------------------------------------------------------------

        SimpleAssetManagement(asm).setConfig("dex", b(dex), "", "diamonds");                        // set price feed (sam as for dex)
        SimpleAssetManagement(asm).setConfig("priceFeed", b(cdc), b(address(cdcFeed)), "diamonds"); // set price feed (sam as for dex)
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
        SimpleAssetManagement(asm).setConfig("overCollRemoveRatio", b(uint(1.05 ether)), "", "diamonds");  // make sure that the value of dpass + dcdc tokens is at least 1.1 times the value of cdc tokens.
        SimpleAssetManagement(asm).setConfig("dpasses", b(dpass), b(true), "diamonds");             // enable the dpass tokens of asm to be handled by dex
        SimpleAssetManagement(asm).setConfig("setApproveForAll", b(dpass), b(dex), b(true));        // enable the dpass tokens of asm to be handled by dex
        SimpleAssetManagement(asm).setConfig("custodians", b(custodian), b(true), "diamonds");      // setup the custodian
        SimpleAssetManagement(asm).setCapCustV(custodian, uint(-1));                                // set unlimited total value. If custodian total value of dcdc and dpass minted value reaches this value, then custodian can no longer mint neither dcdc nor dpass

        SimpleAssetManagement(asm).setConfig("priceFeed", b(dcdc), b(address(cdcFeed)), "diamonds"); // set price feed (asm as for dex)
        SimpleAssetManagement(asm).setConfig("manualRate", b(dcdc), b(true), "diamonds");            // enable to use rate that is not coming from feed
        SimpleAssetManagement(asm).setConfig("decimals", b(dcdc), b(18), "diamonds");                // set precision of token to 18
        SimpleAssetManagement(asm).setConfig("dcdcs", b(dcdc), b(true), "diamonds");                 // tell asm that dcdc is indeed a dcdc token
        SimpleAssetManagement(asm).setConfig("rate", b(dcdc), b(cdcUsdRate), "diamonds");            // set rate for token


//--------------setup-redeemer-------------------------------------------------------
        Redeemer(red).setConfig("asm", b(asm), "", "");                             // tell redeemer the address of asset management
        Redeemer(red).setConfig("dex", b(dex), "", "");                             // tell redeemer the address of dex
        Redeemer(red).setConfig("burner", b(burner), "", "");                       // tell redeemer the address of burner
        Redeemer(red).setConfig("wal", b(wal), "", "");                             // tell redeemer the address of burner
        Redeemer(red).setConfig("fixFee", b(uint(0 ether)), "", "");                      // tell redeemer the fixed fee in base currency that is taken from total redeem fee is 0

        Redeemer(red).setConfig("varFee", b(0.03 ether), "", "");                   // tell redeemer the variable fee, or fee percent

        Redeemer(red).setConfig(
            "profitRate",
            b(DiamondExchange(dex).profitRate()), "", "");                          // tell redeemer the profitRate (should be same as we set in dex), the rate of profit belonging to dpt owners

        Redeemer(red).setConfig("dcdcOfCdc", b(cdc), b(dcdc), "");                  // do a match between cdc and matching dcdc token
        Redeemer(red).setConfig("dpt", b(dpt), "", "");                             // set dpt token address for redeemer
        Redeemer(red).setConfig("liq", b(liq), "", "");                             // set liquidity contract address for redeemer
        Redeemer(red).setConfig("liqBuysDpt", b(false), "", "");                    // set if liquidity contract should buy dpt on the fly for sending as fee
        // Redeemer(red).setConfig("dust", b(uint(1000)), "", "");                  // it is optional to set dust, its default value is 1000
        DiamondExchange(dex).setConfig("redeemer", b(red), b(""));                  // set wallet to store cost part of fee received from users

    }

    function _createTokens() internal {
        dpt = address(new DSToken("DPT"));
        dai = address(new DSToken("DAI"));
        eth = address(0xee);
        eng = address(new DSToken("ENG"));

        cdc = address(new Cdc("BR,VS,G,0.05", "CDC"));
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
        dex = address(uint160(address(new DiamondExchange())));
        emit LogTest(ourGas - gasleft());
        red = address(uint160(address(new Redeemer())));

        liq = address(uint160(address(new Liquidity())));                           // DPT liquidity pprovider contract
        fca = address(uint160(address(new FeeCalculator())));                       // fee calculation contract
    }

    function _createActors() internal {
        user = address(new TesterActor(address(dex), address(asm)));
        user1 = address(new TesterActor(address(dex), address(asm)));
        custodian = address(new TesterActor(address(dex), address(asm)));
        custodian1 = address(new TesterActor(address(dex), address(asm)));
        custodian2 = address(new TesterActor(address(dex), address(asm)));
        auditor = address(new TesterActor(address(dex), address(asm)));
    }

    function _setupGuard() internal {
        guard = new DSGuard();
        Burner(burner).setAuthority(guard);
        Wallet(wal).setAuthority(guard);
        SimpleAssetManagement(asm).setAuthority(guard);
        DiamondExchange(dex).setAuthority(guard);
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
        guard.permit(address(asm), dcdc, ANY);
        guard.permit(address(asm), dcdc1, ANY);
        guard.permit(address(asm), dcdc2, ANY);
        guard.permit(address(this), dpass, ANY);
        guard.permit(address(this), dpass1, ANY);
        guard.permit(address(this), dpass2, ANY);
        guard.permit(address(asm), dpass, ANY);
        guard.permit(address(asm), dpass1, ANY);
        guard.permit(address(asm), dpass2, ANY);
        guard.permit(dex, asm, ANY);
        guard.permit(dex, liq, ANY);
        guard.permit(red, liq, ANY);
        guard.permit(red, asm, ANY);
        guard.permit(red, dex, ANY);

        guard.permit(custodian, asm, bytes4(keccak256("getRateNewest(address)")));
        guard.permit(custodian, asm, bytes4(keccak256("getRate(address)")));
        guard.permit(custodian, asm, bytes4(keccak256("burn(address,address,uint256)")));
        guard.permit(custodian, asm, bytes4(keccak256("mint(address,address,uint256)")));

        guard.permit(custodian, asm, bytes4(keccak256("burnDcdc(address,address,uint256)")));
        guard.permit(custodian, asm, bytes4(keccak256("mintDpass(address,address,bytes3,bytes16,bytes8,bytes20,uint24,bytes32,bytes8,uint256)")));
        guard.permit(custodian, asm, bytes4(keccak256("mintDcdc(address,address,uint256)")));
        guard.permit(custodian, asm, bytes4(keccak256("withdraw(address,uint256)")));
        guard.permit(custodian, asm, bytes4(keccak256("setBasePrice(address,uint256,uint256)")));
        guard.permit(custodian, dpass, bytes4(keccak256("linkOldToNewToken(uint256,uint256)")));
        guard.permit(custodian, dpass1, bytes4(keccak256("linkOldToNewToken(uint256,uint256)")));
        guard.permit(custodian, dpass2, bytes4(keccak256("linkOldToNewToken(uint256,uint256)")));

        guard.permit(custodian1, asm, bytes4(keccak256("getRateNewest(address)")));
        guard.permit(custodian1, asm, bytes4(keccak256("getRate(address)")));
        guard.permit(custodian1, asm, bytes4(keccak256("burn(address,address,uint256)")));
        guard.permit(custodian1, asm, bytes4(keccak256("mint(address,address,uint256)")));

        guard.permit(custodian1, asm, bytes4(keccak256("burnDcdc(address,address,uint256)")));
        guard.permit(custodian1, asm, bytes4(keccak256("mintDpass(address,address,bytes32,bytes32,bytes32,bytes32,uint24,bytes32,bytes8,uint256)")));
        guard.permit(custodian1, asm, bytes4(keccak256("mintDcdc(address,address,uint256)")));
        guard.permit(custodian1, asm, bytes4(keccak256("withdraw(address,uint256)")));
        guard.permit(custodian1, asm, bytes4(keccak256("setBasePrice(address,uint256,uint256)")));
        guard.permit(custodian1, dpass, bytes4(keccak256("linkOldToNewToken(uint256,uint256)")));
        guard.permit(custodian1, dpass1, bytes4(keccak256("linkOldToNewToken(uint256,uint256)")));
        guard.permit(custodian1, dpass2, bytes4(keccak256("linkOldToNewToken(uint256,uint256)")));

        guard.permit(custodian2, asm, bytes4(keccak256("getRateNewest(address)")));
        guard.permit(custodian2, asm, bytes4(keccak256("getRate(address)")));
        guard.permit(custodian2, asm, bytes4(keccak256("burn(address,address,uint256)")));
        guard.permit(custodian2, asm, bytes4(keccak256("mint(address,address,uint256)")));
        guard.permit(custodian2, asm, bytes4(keccak256("burnDcdc(address,address,uint256)")));
        guard.permit(custodian2, asm, bytes4(keccak256("mintDpass(address,address,bytes32,bytes32,bytes32,bytes32,uint24,bytes32,bytes8,uint256)")));
        guard.permit(custodian2, asm, bytes4(keccak256("mintDcdc(address,address,uint256)")));
        guard.permit(custodian2, asm, bytes4(keccak256("withdraw(address,uint256)")));
        guard.permit(custodian2, asm, bytes4(keccak256("setBasePrice(address,uint256,uint256)")));
        guard.permit(custodian2, dpass, bytes4(keccak256("linkOldToNewToken(uint256,uint256)")));
        guard.permit(custodian2, dpass1, bytes4(keccak256("linkOldToNewToken(uint256,uint256)")));
        guard.permit(custodian2, dpass2, bytes4(keccak256("linkOldToNewToken(uint256,uint256)")));

//----------------setup-auditor---------------------------------------------------------------------
        guard.permit(auditor, asm, bytes4(keccak256("setAudit(address,uint256,bytes32,bytes32,uint32)")));
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

    function doSetAudit(
        address custodian_,
        uint256 status_,
        bytes32 descriptionHash_,
        bytes32 descriptionUrl_,
        uint32 auditInterval_
    ) public {
        asm.setAudit(
            custodian_,
            status_,
            descriptionHash_,
            descriptionUrl_,
            auditInterval_
        );
    }

    function doSetBasePrice(address token, uint256 tokenId, uint256 price) public {
        asm.setBasePrice(token, tokenId, price);
    }

    function doSetCdcV(address cdc) public {
        asm.setCdcV(cdc);
    }

    function doUpdateTotalDcdcV(address dcdc) public {
        asm.setTotalDcdcV(dcdc);
    }

    function doSetDcdcV(address dcdc, address custodian) public {
        asm.setDcdcV(dcdc, custodian);
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
        bytes3 issuer_,
        bytes16 report_,
        bytes8 state_,
        bytes20 cccc_,
        uint24 carat_,
        bytes32 attributesHash_,
        bytes8 currentHashingAlgorithm_,
        uint256 price_
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
        asm.setCollateralDpass(positiveV, negativeV, custodian);
    }

    function doUpdateCollateralDcdc(uint positiveV, uint negativeV, address custodian) public {
        asm.setCollateralDcdc(positiveV, negativeV, custodian);
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

    function doUpdateAttributesHash(address token, uint _tokenId, bytes32 _attributesHash, bytes8 _currentHashingAlgorithm) public {
        require(asm.dpasses(token), "test-token-is-not-dpass");
        Dpass(token).updateAttributesHash(_tokenId, _attributesHash, _currentHashingAlgorithm);
    }

    function doSetState(address token_, bytes8 newState_, uint tokenId_) public {
        require(asm.dpasses(token_), "test-token-is-not-dpass");
        Dpass(token_).setState(newState_, tokenId_);
    }

    function setAsm(address payable asm_) public {
        asm = SimpleAssetManagement(asm_);
    }

    function () external payable {
    }
}



contract DiamondExchangeTester is Wallet, DSTest {
    event LogTest(uint256 what);
    event LogTest(bool what);
    event LogTest(address what);
    event LogTest(bytes32 what);

    address payable public dex;


    constructor(address payable exchange_) public {
        require(exchange_ != address(0), "CET: dex 0x0 invalid");
        dex = exchange_;
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
        DiamondExchange(dex).setBuyPrice(token, tokenId, price);
    }

    function doGetBuyPrice(address token, uint256 tokenId) public view returns(uint256) {
        return DiamondExchange(dex).getBuyPrice(token, tokenId);
    }

    function doBuyTokensWithFee(
        address sellToken,
        uint256 sellAmtOrId,
        address buyToken,
        uint256 buyAmtOrId
    ) public payable logs_gas {
        if (sellToken == address(0xee)) {

            DiamondExchange(dex)
            .buyTokensWithFee
            .value(sellAmtOrId == uint(-1) ? address(this).balance : sellAmtOrId > address(this).balance ? address(this).balance : sellAmtOrId)
            (sellToken, sellAmtOrId, buyToken, buyAmtOrId);

        } else {

            DiamondExchange(dex).buyTokensWithFee(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
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

            return  DiamondExchange(dex)
                .redeem
                .value(feeAmt_ == uint(-1) ? address(this).balance : feeAmt_ > address(this).balance ? address(this).balance : feeAmt_)

                (redeemToken_,
                redeemAmtOrId_,
                feeToken_,
                feeAmt_,
                custodian_);
        } else {
            return  DiamondExchange(dex).redeem(
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
        DiamondExchange(dex).setConfig(what_, value_, value1_);
    }

    function doGetDecimals(address token_) public view returns(uint8) {
        return DiamondExchange(dex).getDecimals(token_);
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
        return DiamondExchange(dex).calculateFee(sender_, value_, sellToken_, sellAmtOrId_, buyToken_, buyAmtOrId_);
    }

    function doGetRate(address token_) public view returns (uint rate_) {
        return DiamondExchange(dex).getRate(token_);
    }

    function doGetLocalRate(address token_) public view returns (uint rate_) {
        return DiamondExchange(dex).getRate(token_);
    }

    function setDex(address payable dex_) public {
        require(dex_ != address(0), "test-setdex-dex-zero");
        dex = dex_;
    }
}


contract TesterActor is TrustedSASMTester, DiamondExchangeTester {
    constructor(
        address payable exchange_,
        address payable asm_
    ) public TrustedSASMTester(asm_) DiamondExchangeTester(exchange_) {}
}
