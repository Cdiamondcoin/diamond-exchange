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


contract DiamondExchangeTester is Wallet {
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

    function doBuyTokensWithFee(
        address sellToken,
        uint256 sellAmtOrId,
        address buyToken,
        uint256 buyAmtOrId
    ) public payable {
        if (sellToken == address(0xee)) {

            DiamondExchange(exchange)
            .buyTokensWithFee
            .value(sellAmtOrId == uint(-1) ? address(this).balance : sellAmtOrId)
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

    function doToDecimals(uint256 amt_, uint8 srcDec_, uint8 dstDec_) public view returns (uint256) {
        return DiamondExchange(exchange).toDecimals(amt_, srcDec_, dstDec_);
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


contract TrustedASMTester is DSAuth {
    bool public txEnabled = true;
    mapping(address => mapping( uint256 => uint256)) public price;
    mapping(address => mapping( uint256 => uint256)) public basePrice;
    mapping(address => uint256) public forSale;
    mapping(address => bool) public own;
    mapping(address => bool) public dpasses;
    mapping(address => bool) public cdcs;

    function setPrice(address payable exchange_, address erc721, uint256 id721, uint256 price_) public {
        DiamondExchange(exchange_).setSellPrice(erc721, id721, price_);
    }
    
    function setDpass(address dpass, bool enable) public {
        dpasses[dpass] = enable;
    }

    function setCdc(address cdc, bool enable) public {
        cdcs[cdc] = enable;
    }

    function setTxEnabled(bool enabled_) public {
        txEnabled = enabled_;
    }

    function setAmtForSale(address token, uint256 amtForSale) public {
        forSale[token] = amtForSale;
    }

    function setOwnerOf(address token, bool isOwner) public {
        own[token] = isOwner;
    }

    function sendToken(address token, address dst, uint256 value) public {
       DSToken tok = DSToken(token);
       tok.transfer(dst, value);
    }

    function notifyTransferFrom(address token, address src, address dst, uint256 amtOrId) public {
        require(txEnabled, "Transaction is not allowed");
        if (dpasses[token] && src == address(this)) {
        } else if (dst == address(this) && !dpasses[token]) {
            if (cdcs[token]) {                                              //
                Cdc(token).burn(amtOrId);
            }
        } else if(dpasses[token]) {
        } else {
            require(false, "asm-unsupported-tx");
        }
    }

    function getPrice(address payable exchange_, address erc721, uint256 id721) public view returns(uint256) {
        DiamondExchange(exchange_).getSellPrice(erc721, id721);
    }

    function getBasePrice(address erc721, uint256 id721) public view returns(uint256) {
        return basePrice[erc721][id721];
    }
    function setBasePrice(address erc721, uint256 id721, uint256 price_) public returns(uint256) {
        basePrice[erc721][id721] = price_;
    }

    function getAmtForSale(address token) public view returns (uint256){
        return forSale[token];
    }

    function isOwnerOf(address token) public view returns(bool) {
        return own[token];
    }

    function mint(address token, address dst, uint256 amt) public {
        require(cdcs[token], "Not a cdc token");
        Cdc(token).mint(dst, amt); 
    }

    function doApprove721(address token, address to, uint id_) public {
        require(token != address(0), "Can't approve token of 0x0");
        require(to != address(0), "Can't approve address of 0x0");
        Dpass(token).approve(to, id_);
    }

    function () external payable {
    }
}


contract DiamondExchangeTest is DSTest, DSMath, DiamondExchangeEvents {
    event LogUintIpartUintFpart(bytes32 key, uint val, uint val1);
    event LogTest(uint256 what);
    event LogTest(bool what);
    event LogTest(address what);
    event LogTest(bytes32 what);

    uint public constant SUPPLY = (10 ** 10) * (10 ** 18);
    uint public constant INITIAL_BALANCE = 1000 ether;

    address public cdc;             // Cdc()
    address public dpass;           // Dpass()
    address public dpass1;           // Dpass()
    address public dpt;                         // DSToken()
    address public dai;     // DSToken()
    address public eth;
    address public eng;
    address payable public exchange; // DiamondExchange()

    address payable public liquidityContract;   // DiamondExchangeTester()
    address payable public wal;                 // DptTester()
    address payable public asm;                 // TrustedASMTester()
    address payable public user;                // DiamondExchangeTester()
    address payable public seller;              // DiamondExchangeTester()

    address payable public burner;              // Burner()
    address payable public fca;                 // TestFeeCalculator()

    // test variables
    mapping(address => mapping(address => uint)) public balance;
    mapping(address => mapping(uint => uint)) public usdRateDpass;
    mapping(address => uint) public usdRate;
    mapping(address => address) feed;                           // address => TestFeedLike()
    mapping(address => address payable) custodian20;
    mapping(address => uint8) public decimals;
    mapping(address => bool) public decimalsSet;
    mapping(address => uint) public dpassId;
    mapping(address => bool) public erc20;                      // tells if token is ERC20 ( eth considered ERC20 here)
    mapping(address => uint) dust;
    mapping(address => bool) dustSet;

    uint public fixFee = 0 ether;
    uint public varFee = .2 ether;          // variable fee is 20% of value
    uint public profitRate = .3 ether;      // profit rate 30%
    bool public takeProfitOnlyInDpt = true; // take only profit or total fee (cost + profit) in DPT

    // variables for calculating expected behaviour --------------------------
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
    uint dpassOwnerPrice;
    DSGuard public guard;
    bytes32 constant public ANY = bytes32(uint(-1));

    function setUp() public {
        cdc = address(new Cdc());
        dpass = address(new Dpass());
        dpt = address(new DSToken("DPT"));
        dai = address(new DSToken("DAI"));
        eth = address(0xee);
        eng = address(new DSToken("ENG"));   // TODO: make sure it is 8 decimals

        erc20[cdc] = true;
        erc20[dpt] = true;
        erc20[dai] = true;
        erc20[eng] = true;
        erc20[eth] = true;

        DSToken(dpt).mint(SUPPLY);
        DSToken(dai).mint(SUPPLY);
        DSToken(eng).mint(SUPPLY);
        DSToken(cdc).mint(SUPPLY);

        usdRate[dpt] = 5 ether;
        usdRate[cdc] = 7 ether;
        usdRate[eth] = 11 ether;
        usdRate[dai] = 13 ether;
        usdRate[eng] = 59 ether;

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

        dust[dpt] = 10000;
        dust[cdc] = 10000;
        dust[eth] = 10000;
        dust[dai] = 10000;
        dust[eng] = 10;

        dustSet[dpt] = true;
        dustSet[cdc] = true;
        dustSet[eth] = true;
        dustSet[dai] = true;
        dustSet[eng] = true;

        feed[eth] = address(new TestFeedLike(usdRate[eth], true));
        feed[dpt] = address(new TestFeedLike(usdRate[dpt], true));
        feed[cdc] = address(new TestFeedLike(usdRate[cdc], true));
        feed[dai] = address(new TestFeedLike(usdRate[dai], true));
        feed[eng] = address(new TestFeedLike(usdRate[eng], true));

        burner = address(uint160(address(new Burner(DSToken(dpt))))); // Burner()


        wal = address(uint160(address(new DptTester(DSToken(dai))))); // DptTester()
        asm = address(uint160(address(new TrustedASMTester())));
        guard = new DSGuard();
        TrustedASMTester(asm).setAuthority(guard);
        guard.permit(address(this), address(asm), ANY);
        guard.permit(address(asm), cdc, ANY);
        guard.permit(address(asm), dpass, ANY);
        DSToken(cdc).setAuthority(guard);
        Dpass(dpass).setAuthority(guard);

        custodian20[dpt] = asm;
        custodian20[cdc] = asm;
        custodian20[eth] = asm;
        custodian20[dai] = asm;
        custodian20[eng] = asm;

        TrustedASMTester(asm).setOwnerOf(cdc, true);                             // asset management will handle this token
        TrustedASMTester(asm).setAmtForSale(cdc, INITIAL_BALANCE);
        TrustedASMTester(asm).setCdc(cdc, true);
        TrustedASMTester(asm).setDpass(dpass, true);
        Cdc(cdc).transfer(asm, INITIAL_BALANCE);

        TrustedASMTester(asm).setOwnerOf(dpass, true);

        liquidityContract = address(uint160(address(new DiamondExchangeTester(address(0xfa), dpt, cdc, dai)))); // FAKE DECLARATION, will overdeclare later
        DSToken(dpt).transfer(liquidityContract, INITIAL_BALANCE);

        exchange = address(uint160(address(new DiamondExchange(
            cdc,
            dpt,
            dpass,
            feed[eth],
            feed[dpt],
            feed[cdc],
            liquidityContract,
            burner,
            asm,
            fixFee,
            varFee,
            profitRate,
            wal
        ))));

        DiamondExchange(exchange).setConfig("canSellErc20", dai, true);
        DiamondExchange(exchange).setConfig("priceFeed", dai, feed[dai]);
        DiamondExchange(exchange).setConfig("rate", dai, usdRate[dai]);
        DiamondExchange(exchange).setConfig("manualRate", dai, true);
        DiamondExchange(exchange).setConfig("decimals", dai, 18);
        DiamondExchange(exchange).setConfig("custodian20", dai, custodian20[dai]);
        // DiamondExchange(exchange).setConfig("handledByAsm", dai, true);      // set true if token can be bougt by user and asm should handle it

        DiamondExchange(exchange).setConfig("canSellErc20", eth, true);
        DiamondExchange(exchange).setConfig("priceFeed", eth, feed[eth]);
        DiamondExchange(exchange).setConfig("rate", eth, usdRate[eth]);
        DiamondExchange(exchange).setConfig("manualRate", eth, true);
        DiamondExchange(exchange).setConfig("decimals", eth, 18);
        DiamondExchange(exchange).setConfig("custodian20", eth, custodian20[eth]);
        // DiamondExchange(exchange).setConfig("handledByAsm", eth, true);      // set true if token can be bougt by user and asm should handle it

        DiamondExchange(exchange).setConfig("canSellErc20", cdc, true);
        DiamondExchange(exchange).setConfig("canBuyErc20", cdc, true);
        DiamondExchange(exchange).setConfig("custodian20", cdc, custodian20[cdc]);
        DiamondExchange(exchange).setConfig("priceFeed", cdc, feed[cdc]);
        DiamondExchange(exchange).setConfig("rate", cdc, usdRate[cdc]);
        DiamondExchange(exchange).setConfig("manualRate", cdc, true);
        DiamondExchange(exchange).setConfig("decimals", cdc, 18);
        DiamondExchange(exchange).setConfig("handledByAsm", cdc, true);

        DiamondExchange(exchange).setConfig("canSellErc20", dpt, true);
        DiamondExchange(exchange).setConfig("custodian20", dpt, asm);
        DiamondExchange(exchange).setConfig("priceFeed", dpt, feed[dpt]);
        DiamondExchange(exchange).setConfig("rate", dpt, usdRate[dpt]);
        DiamondExchange(exchange).setConfig("manualRate", dpt, true);
        DiamondExchange(exchange).setConfig("decimals", dpt, 18);
        DiamondExchange(exchange).setConfig("custodian20", dpt, custodian20[dpt]);
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(takeProfitOnlyInDpt), "");

        DiamondExchange(exchange).setConfig("canSellErc20", eng, true);
        DiamondExchange(exchange).setConfig("priceFeed", eng, feed[eng]);
        DiamondExchange(exchange).setConfig("rate", eng, usdRate[eng]);
        DiamondExchange(exchange).setConfig("manualRate", eng, true);
        DiamondExchange(exchange).setConfig("decimals", eng, 18);
        DiamondExchange(exchange).setConfig("custodian20", eng, custodian20[eng]);

        liquidityContract = address(uint160(address(new DiamondExchangeTester(exchange, dpt, cdc, dai))));
        DSToken(dpt).transfer(liquidityContract, INITIAL_BALANCE);
        DiamondExchangeTester(liquidityContract).doApprove(dpt, exchange, uint(-1));
        DiamondExchange(exchange).setConfig("liq", liquidityContract, "");
        DiamondExchangeTester(liquidityContract).setOwner(exchange);

        user = address(uint160(address(new DiamondExchangeTester(exchange, dpt, cdc, dai))));
        seller = address(uint160(address(new DiamondExchangeTester(exchange, dpt, cdc, dai))));
        fca = address(uint160(address(new TestFeeCalculator())));

        Cdc(cdc).approve(exchange, uint(-1));
        DSToken(dpt).approve(exchange, uint(-1));
        DSToken(dai).approve(exchange, uint(-1));
        DSToken(eng).approve(exchange, uint(-1));

        // Prepare dpass tokens
        dpassOwnerPrice = 137 ether;
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
        TrustedASMTester(asm).setPrice(exchange, dpass, dpassId[user], dpassOwnerPrice);
        DiamondExchangeTester(user).doApprove721(dpass, exchange, dpassId[user]);

        bytes32[] memory attributes1 = new bytes32[](5);
        attributes1[0] = "round";
        attributes1[1] = "3.1";
        attributes1[2] = "F";
        attributes1[3] = "VVS1";
        attributes1[4] = "";


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

        TrustedASMTester(asm).setPrice(exchange, dpass, dpassId[seller], dpassOwnerPrice);
        TrustedASMTester(asm).doApprove721(dpass, exchange, dpassId[seller]);
        // Prepare seller of DPT fees

        user.transfer(INITIAL_BALANCE);
        Cdc(cdc).transfer(user, INITIAL_BALANCE);
        DSToken(dai).transfer(user, INITIAL_BALANCE);
        DSToken(eng).transfer(user, INITIAL_BALANCE);

        DiamondExchangeTester(user).doApprove(dpt, exchange, uint(-1));
        DiamondExchangeTester(user).doApprove(cdc, exchange, uint(-1));
        DiamondExchangeTester(user).doApprove(dai, exchange, uint(-1));

        balance[address(this)][eth] = address(this).balance;
        balance[user][eth] = user.balance;
        balance[user][cdc] = Cdc(cdc).balanceOf(user);
        balance[user][dpt] = DSToken(dpt).balanceOf(user);
        balance[user][dai] = DSToken(dai).balanceOf(user);

        balance[asm][eth] = asm.balance;
        balance[asm][cdc] = Cdc(cdc).balanceOf(asm);
        balance[asm][dpt] = DSToken(dpt).balanceOf(asm);
        balance[asm][dai] = DSToken(dai).balanceOf(asm);

        balance[liquidityContract][eth] = liquidityContract.balance;
        balance[wal][eth] = wal.balance;
        balance[custodian20[eth]][eth] = custodian20[eth].balance;
        balance[custodian20[cdc]][cdc] = Cdc(cdc).balanceOf(custodian20[cdc]);
        balance[custodian20[dpt]][dpt] = DSToken(dpt).balanceOf(custodian20[dpt]);
        balance[custodian20[dai]][dai] = DSToken(dai).balanceOf(custodian20[dai]);

        emit log_named_address("exchange", exchange);
        emit log_named_address("dpt", dpt);
        emit log_named_address("cdc", cdc);
        emit log_named_address("asm", asm);
        emit log_named_address("user", user);
        emit log_named_address("wal", wal);
        emit log_named_address("liq", liquidityContract);
        emit log_named_address("burner", burner);
    }

    function doExchange(address sellToken, uint256 sellAmtOrId, address buyToken, uint256 buyAmtOrId) public {
        uint origUserBalanceT;
        uint buyT;
        uint buyV;
        bool _takeProfitOnlyInDpt = DiamondExchange(exchange).takeProfitOnlyInDpt();

        if (sellToken == eth) {
            origUserBalanceT = user.balance;
        } else {
            origUserBalanceT = DSToken(sellToken).balanceOf(user);
        }

        sentV = sellAmtOrId == uint(-1) ?                                               // sent value in fiat currency
            wmulV(origUserBalanceT, usdRate[sellToken], sellToken) :
            erc20[sellToken] ?
                wmulV(min(sellAmtOrId, origUserBalanceT), usdRate[sellToken], sellToken) :
                dpassOwnerPrice;

        buyT = erc20[buyToken] ?                                                        // total amount of token available to buy (or tokenid)
            DiamondExchange(exchange).isHandledByAsm(buyToken) ?
                min(buyAmtOrId, TrustedASMTester(asm).getAmtForSale(buyToken)) :
                min(buyAmtOrId, DSToken(buyToken).balanceOf(custodian20[buyToken])) :
            buyAmtOrId;

        buyV = erc20[buyToken] ?                                                        // total value of tokens available to buy (or tokenid)
            wmulV(buyT, usdRate[buyToken], buyToken) :
            dpassOwnerPrice;

        buySellTokenT = erc20[sellToken] ?                                              // the amount of sellToken to pay for buy token
            wdivT(buyV, usdRate[sellToken], sellToken) :
            0;

        feeV = add(
            wmul(
                DiamondExchange(exchange).varFee(),
                min(sentV, buyV)),
            DiamondExchange(exchange).fixFee());                                        // fiat value in fiat

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
                0;                                                                      // amount of sellToken to pay for remaining fee
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
        DiamondExchangeTester(user).doBuyTokensWithFee(
            sellToken,
            sellAmtOrId,
            buyToken,
            buyAmtOrId
        );

        userDptV = wmulV(userDpt, usdRate[dpt], dpt);

        balanceUserIncreaseT = erc20[buyToken] ?
            sub(
                (buyToken == eth ?
                    user.balance :
                    DSToken(buyToken).balanceOf(user)),
                balance[user][buyToken]) :
            0;

        balanceUserIncreaseV = erc20[buyToken] ?
            wmulV(
                balanceUserIncreaseT,
                usdRate[buyToken],
                buyToken) :
            dpassOwnerPrice;
        emit LogTest("balance[user]");
        emit LogTest(balance[user][sellToken]);
        balanceUserDecreaseT = erc20[sellToken] ?
            sub(
                balance[user][sellToken],
                (sellToken == eth ?
                    user.balance :
                    DSToken(sellToken).balanceOf(user))) :
            0;

        balanceUserDecreaseV = erc20[sellToken] ?
            wmulV(
                balanceUserDecreaseT,
                usdRate[sellToken],
                sellToken) :
            dpassOwnerPrice;

        emit log_named_uint("---------takeProfitOnlyInDpt", takeProfitOnlyInDpt ? 1 : 0);
        emit log_named_bytes32("----------------sellToken", getName(sellToken));
        logUint("----------sellAmtOrId", sellAmtOrId, 18);
        emit log_named_bytes32("-----------------buyToken", getName(buyToken));
        logUint("-----------buyAmtOrId", buyAmtOrId, 18);
        emit log_bytes32(bytes32("------------------------------"));
        logUint("---------------sentV", sentV, 18);
        logUint("---------------buyV:", buyV, 18);
        logUint("------buySellTokenT:", buySellTokenT, 18);
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

        // DPT (eq fee in USD) must be sold from: liquidityContract balance
        emit log_bytes32("dpt from liq");
        emit LogTest("actual");
        emit LogTest(sub(INITIAL_BALANCE, DSToken(dpt).balanceOf(address(liquidityContract))));

        emit LogTest("expected");
        emit LogTest(sellToken == dpt ? 0 : sub(profitDpt, _takeProfitOnlyInDpt ? feeSpentDpt : wmul(feeSpentDpt, profitRate)));
        assertEqDust(
            sub(INITIAL_BALANCE, DSToken(dpt).balanceOf(address(liquidityContract))),
            sellToken == dpt ? 0 : sub(profitDpt, _takeProfitOnlyInDpt ? feeSpentDpt : wmul(feeSpentDpt, profitRate)),
            dpt);

        // ETH for DPT fee must be sent to wallet balance from user balance
        emit log_bytes32("sell token as fee to wal");
        emit LogTest("actual");
        emit LogTest(sellToken == eth ?
                address(wal).balance :
                DSToken(sellToken).balanceOf(wal));

        emit LogTest("expected");
        emit LogTest(add(balance[wal][sellToken], sub(restOfFeeT, sellToken == dpt ? profitSellTokenT : 0)));
        assertEqDust(
            sellToken == eth ?
                address(wal).balance :
                DSToken(sellToken).balanceOf(wal),
            add(balance[wal][sellToken], sub(restOfFeeT, sellToken == dpt ? profitSellTokenT : 0)),
            sellToken);

        // DPT fee have to be transfered to burner
        emit log_bytes32("dpt to burner");
        emit LogTest("actual");
        emit LogTest(DSToken(dpt).balanceOf(burner));

        emit LogTest("expected");
        emit LogTest(profitDpt);
        assertEqDust(DSToken(dpt).balanceOf(burner), profitDpt, dpt);

        // custodian balance of tokens sold by user must increase
        if (erc20[sellToken]) {

            emit log_bytes32("seller bal inc by ERC20 sold");
            if (DiamondExchange(exchange).isHandledByAsm(buyToken)) { 

                emit LogTest("actual");
                emit LogTest(sellToken == eth ? asm.balance : DSToken(sellToken).balanceOf(asm));

                emit LogTest("expected");
                emit LogTest(add(
                        balance[asm][sellToken],
                        sub(finalSellT, restOfFeeT)));
                assertEqDust(
                    sellToken == eth ? asm.balance : DSToken(sellToken).balanceOf(asm),
                    add(
                        balance[asm][sellToken],
                        sellToken == cdc ? 0 : sub(finalSellT, restOfFeeT)),
                    sellToken);
            } else { 
                assertEqDust(
                    sellToken == eth ? custodian20[sellToken].balance : DSToken(sellToken).balanceOf(custodian20[sellToken]),
                    add(
                        balance[custodian20[sellToken]][sellToken],
                        sub(finalSellT, restOfFeeT)),
                    sellToken);
            }
        } else {

           emit log_bytes32("seller bal inc by ERC721 sold");
            assertEq(
                TrustedErc721(sellToken).ownerOf(sellAmtOrId),
                Dpass(sellToken).ownerOf(sellAmtOrId));
        }

        // user balance of tokens sold must decrease
        if (erc20[sellToken]) {

            emit LogTest("actual");
            emit LogTest(sellToken == eth ? user.balance : DSToken(sellToken).balanceOf(user));

            emit LogTest("expected");
            emit LogTest(sub(
                    balance[user][sellToken],
                    finalSellT));
            emit log_bytes32("user bal dec by ERC20 sold");
            assertEqDust(
                sellToken == eth ? user.balance : DSToken(sellToken).balanceOf(user),
                sub(
                    balance[user][sellToken],
                    finalSellT),
                sellToken);

        } else {
        emit LogTest("actual");
        emit LogTest(Dpass(sellToken).ownerOf(sellAmtOrId));

        emit LogTest("expected should not equal");
        emit LogTest(user);

            emit log_bytes32("user bal dec by ERC721 sold");
            assertTrue(Dpass(sellToken).ownerOf(sellAmtOrId) != user);
        }

        // user balance of tokens bought must increase
        if (erc20[buyToken]) {

            emit log_bytes32("user bal inc by ERC20 bought");
            emit LogTest("balance");
            emit LogTest(buyToken == eth ? user.balance : DSToken(buyToken).balanceOf(user));
            emit LogTest("expected");
            emit LogTest(add(
                    balance[user][buyToken],
                    finalBuyT));
            assertEqDust(
                buyToken == eth ? user.balance : DSToken(buyToken).balanceOf(user),
                add(
                    balance[user][buyToken],
                    finalBuyT),
                buyToken);

        } else {

            emit log_bytes32("user bal inc by ERC721 bought");
            assertEq(
                Dpass(buyToken).ownerOf(buyAmtOrId),
                user);
        }

        // tokens bought by user must decrease custodian account
        if (erc20[buyToken]) {

            emit log_bytes32("seller bal dec by ERC20 bought");
            if(DiamondExchange(exchange).isHandledByAsm(buyToken) ) {
                assertEqDust(DSToken(buyToken).balanceOf(asm), balance[asm][buyToken], buyToken);
            } else {
                assertEqDust(
                    buyToken == eth ? custodian20[buyToken].balance : DSToken(buyToken).balanceOf(custodian20[buyToken]),
                    sub(
                        balance[custodian20[buyToken]][buyToken],
                        balanceUserIncreaseT),
                    buyToken);
            }
        } else {

            emit log_bytes32("seller bal dec by ERC721 bought");
            assertEq(
                Dpass(buyToken).ownerOf(buyAmtOrId),
                user);

        }

        // make sure fees and tokens sent and received add up
        emit log_bytes32("fees and tokens add up");
        emit LogTest("actual");
        emit LogTest(add(balanceUserIncreaseV, feeV));

        emit LogTest("expected");
        emit LogTest( add(balanceUserDecreaseV, feeSpentDptV));
        assertEqDust(
            add(balanceUserIncreaseV, feeV),
            add(balanceUserDecreaseV, feeSpentDptV));
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
        uint diff = a_ - b_;
        require(dustSet[token], "Dust limit must be set to token.");
        uint dustT = dust[token];
        assertTrue(diff < dustT || uint(-1) - diff < dustT);
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

    function testCalculateFee() public {
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

    function testSetFixFee() public {
        uint fee = 0.1 ether;
        DiamondExchange(exchange).setConfig("fixFee", fee, "");
        assertEq(DiamondExchange(exchange).calculateFee(
            address(this),
            0 ether,
            address(0x0),
            0,
            address(0x0),
            0
        ), fee);
    }

    function testSetVarFee() public {
        uint fee = 0.5 ether;
        DiamondExchange(exchange).setConfig("varFee", fee, "");
        assertEq(DiamondExchange(exchange).calculateFee(
            address(this),
            1 ether,
            address(0x0),
            0,
            address(0x0),
            0
        ), fee);
    }

    function testSetVarAndFixFee() public {
        uint value = 1 ether;
        uint varFee1 = 0.5 ether;
        uint fixFee1 = uint(10) / uint(3) * 1 ether;
        DiamondExchange(exchange).setConfig("varFee", varFee1, "");
        DiamondExchange(exchange).setConfig("fixFee", fixFee1, "");
        assertEq(DiamondExchange(exchange).calculateFee(
            address(this),
            value,
            address(0x0),
            0,
            address(0x0),
            0
        ), add(fixFee1, wmul(varFee1, value)));
    }

    function testFailNonOwnerSetVarFee() public {
        uint newFee = 0.1 ether;
        DiamondExchangeTester(user).doSetConfig("varFee", newFee, "");
    }

    function testFailNonOwnerSetFixFee() public {
        uint newFee = 0.1 ether;
        DiamondExchangeTester(user).doSetConfig("fixFee", newFee, "");
    }

    function testSetEthPriceFeed() public {
        address token = eth;
        uint rate = 1 ether;
        DiamondExchange(exchange).setConfig("priceFeed", token, feed[dai]);
        TestFeedLike(feed[dai]).setRate(rate);
        assertEq(DiamondExchange(exchange).getRate(token), rate);
    }

    function testSetDptPriceFeed() public {
        address token = dpt;
        uint rate = 2 ether;
        DiamondExchange(exchange).setConfig("priceFeed", token, feed[dai]);
        TestFeedLike(feed[dai]).setRate(rate);
        assertEq(DiamondExchange(exchange).getRate(token), rate);
    }

    function testSetCdcPriceFeed() public {
        address token = cdc;
        uint rate = 4 ether;
        DiamondExchange(exchange).setConfig("priceFeed", token, feed[dai]);
        TestFeedLike(feed[dai]).setRate(rate);
        assertEq(DiamondExchange(exchange).getRate(token), rate);
    }

    function testSetDaiPriceFeed() public {
        address token = dai;
        uint rate = 5 ether;
        DiamondExchange(exchange).setConfig("priceFeed", token, feed[dai]);
        TestFeedLike(feed[dai]).setRate(rate);
        assertEq(DiamondExchange(exchange).getRate(token), rate);
    }

    function testFailWrongAddressSetPriceFeed() public {
        address token = eth;
        DiamondExchange(exchange).setConfig("priceFeed", token, address(0));
    }

    function testFailNonOwnerSetEthPriceFeed() public {
        address token = eth;
        DiamondExchangeTester(user).doSetConfig("priceFeed", token, address(0));
    }

    function testFailWrongAddressSetDptPriceFeed() public {
        address token = dpt;
        DiamondExchange(exchange).setConfig("priceFeed", token, address(0));
    }

    function testFailWrongAddressSetCdcPriceFeed() public {
        address token = cdc;
        DiamondExchange(exchange).setConfig("priceFeed", token, address(0));
    }

    function testFailNonOwnerSetCdcPriceFeed() public {
        address token = cdc;
        DiamondExchangeTester(user).doSetConfig("priceFeed", token, address(0));
    }

    function testSetLiquidityContract() public {
        DSToken(dpt).transfer(user, 100 ether);
        DiamondExchange(exchange).setConfig("liq", user, "");
        assertEq(DiamondExchange(exchange).liq(), user);
    }

    function testFailWrongAddressSetLiquidityContract() public {
        DiamondExchange(exchange).setConfig("liq", address(0x0), "");
    }

    function testFailNonOwnerSetLiquidityContract() public {
        DSToken(dpt).transfer(user, 100 ether);
        DiamondExchangeTester(user).doSetConfig("liq", user, "");
    }

    function testFailWrongAddressSetWalletContract() public {
        DiamondExchange(exchange).setConfig("wal", address(0x0), "");
    }

    function testFailNonOwnerSetWalletContract() public {
        DiamondExchangeTester(user).doSetConfig("wal", user, "");
    }

    function testSetManualDptRate() public {
        DiamondExchange(exchange).setConfig("manualRate", dpt, true);
        assertTrue(DiamondExchange(exchange).getManualRate(dpt));
        DiamondExchange(exchange).setConfig("manualRate", dpt, false);
        assertTrue(!DiamondExchange(exchange).getManualRate(dpt));
    }

    function testSetManualCdcRate() public {
        DiamondExchange(exchange).setConfig("manualRate", cdc, true);
        assertTrue(DiamondExchange(exchange).getManualRate(cdc));
        DiamondExchange(exchange).setConfig("manualRate", cdc, false);
        assertTrue(!DiamondExchange(exchange).getManualRate(cdc));
    }

    function testSetManualEthRate() public {
        DiamondExchange(exchange).setConfig("manualRate", address(0xee), true);
        assertTrue(DiamondExchange(exchange).getManualRate(address(0xee)));
        DiamondExchange(exchange).setConfig("manualRate", address(0xee), false);
        assertTrue(!DiamondExchange(exchange).getManualRate(address(0xee)));
    }

    function testSetManualDaiRate() public {
        DiamondExchange(exchange).setConfig("manualRate", dai, true);
        assertTrue(DiamondExchange(exchange).getManualRate(dai));
        DiamondExchange(exchange).setConfig("manualRate", dai, false);
        assertTrue(!DiamondExchange(exchange).getManualRate(dai));
    }

    function testFailNonOwnerSetManualDptRate() public {
        DiamondExchangeTester(user).doSetConfig("manualRate", dpt, false);
    }

    function testFailNonOwnerSetManualCdcRate() public {
        DiamondExchangeTester(user).doSetConfig("manualRate", cdc, false);
    }

    function testFailNonOwnerSetManualEthRate() public {
        DiamondExchangeTester(user).doSetConfig("manualRate", address(0xee), false);
    }

    function testFailNonOwnerSetManualDaiRate() public {
        DiamondExchangeTester(user).doSetConfig("manualRate", dai, false);
    }

    function testSetFeeCalculatorContract() public {
        DiamondExchange(exchange).setConfig("fca", address(fca), "");
        assertEq(address(DiamondExchange(exchange).fca()), address(fca));
    }

    function testFailWrongAddressSetCfo() public {
        DiamondExchange(exchange).setConfig("fca", address(0), "");
    }

    function testFailNonOwnerSetCfo() public {
        DiamondExchangeTester(user).doSetConfig("fca", user, "");
    }

    function testSetDptUsdRate() public {
        uint newRate = 5 ether;
        DiamondExchange(exchange).setConfig("rate", dpt, newRate);
        assertEq(DiamondExchange(exchange).getLocalRate(dpt), newRate);
    }

    function testFailIncorectRateSetDptUsdRate() public {
        DiamondExchange(exchange).setConfig("rate", dpt, uint(0));
    }

    function testFailNonOwnerSetDptUsdRate() public {
        uint newRate = 5 ether;
        DiamondExchangeTester(user).doSetConfig("rate", dpt, newRate);
    }

    function testSetCdcUsdRate() public {
        uint newRate = 5 ether;
        DiamondExchange(exchange).setConfig("rate", cdc, newRate);
        assertEq(DiamondExchange(exchange).getLocalRate(cdc), newRate);
    }

    function testFailIncorectRateSetCdcUsdRate() public {
        DiamondExchange(exchange).setConfig("rate", cdc, uint(0));
    }

    function testFailNonOwnerSetCdcUsdRate() public {
        uint newRate = 5 ether;
        DiamondExchangeTester(user).doSetConfig("rate", cdc, newRate);
    }

    function testSetEthUsdRate() public {
        uint newRate = 5 ether;
        DiamondExchange(exchange).setConfig("rate", eth, newRate);
        assertEq(DiamondExchange(exchange).getLocalRate(eth), newRate);
    }

    function testFailIncorectRateSetEthUsdRate() public {
        DiamondExchange(exchange).setConfig("rate", eth, uint(0));
    }

    function testFailNonOwnerSetEthUsdRate() public {
        uint newRate = 5 ether;
        DiamondExchangeTester(user).doSetConfig("rate", eth, newRate);
    }

    function testFailInvalidDptFeedAndManualDisabledBuyTokensWithFee() public logs_gas {
        uint sentEth = 1 ether;

        DiamondExchange(exchange).setConfig("manualRate", dpt, false);

        TestFeedLike(feed[dpt]).setValid(false);

        DiamondExchange(exchange).buyTokensWithFee(dpt, sentEth, cdc, uint(-1));
    }

    function testFailInvalidEthFeedAndManualDisabledBuyTokensWithFee() public logs_gas {
        uint sentEth = 1 ether;

        DiamondExchange(exchange).setConfig("manualRate", eth, false);

        TestFeedLike(feed[eth]).setValid(false);

        DiamondExchange(exchange).buyTokensWithFee.value(sentEth)(eth, sentEth, cdc, uint(-1));
    }

    function testFailInvalidCdcFeedAndManualDisabledBuyTokensWithFee() public {
        uint sentEth = 1 ether;

        DiamondExchange(exchange).setConfig("manualRate", cdc, false);

        TestFeedLike(feed[cdc]).setValid(false);

        DiamondExchange(exchange).buyTokensWithFee(cdc, sentEth, cdc, uint(-1));
    }

    function testForFixEthBuyAllCdcUserHasNoDpt() public {
        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 41 ether;
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);

    }

    function testForFixEthBuyAllCdcUserDptNotZeroNotEnough() public {
        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);

    }

    function testForFixEthBuyAllCdcUserDptEnough() public {
        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 27 ether;
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testForAllEthBuyAllCdcUserHasNoDpt() public {
        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);

    }

    function testForAllEthBuyAllCdcUserDptNotZeroNotEnough() public {
        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }
    function testForAllEthBuyAllCdcUserDptEnough() public {
        userDpt = 3000 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }
    function testForAllEthBuyFixCdcUserHasNoDpt() public {
        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);

    }

    function testForAllEthBuyFixCdcUserDptNotZeroNotEnough() public {
        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testForAllEthBuyFixCdcUserDptEnough() public {
        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testForFixEthBuyFixCdcUserHasNoDpt() public {
        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);

    }

    function testForFixEthBuyFixCdcUserDptNotZeroNotEnough() public {
        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testForFixEthBuyFixCdcUserDptEnough() public {
        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testFailForFixEthBuyFixCdcUserHasNoDptSellAmtTooMuch() public {
        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 1001 ether;  // has only 1000 eth balance
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);

    }

    function testFailForFixEthBuyFixCdcUserHasNoDptBuyAmtTooMuch() public {
        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address buyToken = cdc;

        doExchange(eth, 1000 ether, buyToken, 1001 ether);

    }

    function testFailForFixEthBuyFixCdcUserHasNoDptBothTooMuch() public {
        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 1001 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 1001 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testFailSendEthIfNoEthIsSellToken() public {
        uint sentEth = 1 ether;

        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 11 ether;
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        DiamondExchange(exchange).buyTokensWithFee.value(sentEth)(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testForFixDaiBuyAllCdcUserHasNoDpt() public {
        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 41 ether;
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);

    }

    function testForFixDaiBuyAllCdcUserDptNotZeroNotEnough() public {
        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);

    }

    function testForFixDaiBuyAllCdcUserDptEnough() public {
        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 27 ether;
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testForAllDaiBuyAllCdcUserHasNoDpt() public {
        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);

    }

    function testForAllDaiBuyAllCdcUserDptNotZeroNotEnough() public {
        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testForAllDaiBuyAllCdcUserDptEnough() public {
        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testForAllDaiBuyFixCdcUserHasNoDpt() public {
        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);

    }

    function testForAllDaiBuyFixCdcUserDptNotZeroNotEnough() public {
        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testForAllDaiBuyFixCdcUserDptEnough() public {
        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testForFixDaiBuyFixCdcUserHasNoDpt() public {
        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);

    }

    function testForFixDaiBuyFixCdcUserDptNotZeroNotEnough() public {
        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testForFixDaiBuyFixCdcUserDptEnough() public {
        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testFailForFixDaiBuyFixCdcUserHasNoDptSellAmtTooMuch() public {
        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 1001 ether;  // has only 1000 eth balance
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);

    }

    function testFailForFixDaiBuyFixCdcUserHasNoDptBuyAmtTooMuch() public {
        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 17 ether;  // has only 1000 eth balance
        address buyToken = cdc;
        uint buyAmtOrId = 1001 ether;   // has only 1000 cdc balance

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);

    }

    function testFailForFixDaiBuyFixCdcUserHasNoDptBothTooMuch() public {
        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 1001 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 1001 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testForFixEthBuyAllCdcUserHasNoDptAllFeeInDpt() public {
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");

        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 41 ether;
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);

    }

    function testForFixEthBuyAllCdcUserDptNotZeroNotEnoughAllFeeInDpt() public {
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");

        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);

    }

    function testForFixEthBuyAllCdcUserDptEnoughAllFeeInDpt() public {
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");

        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 27 ether;
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testForAllEthBuyAllCdcUserHasNoDptAllFeeInDpt() public {
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");

        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);

    }

    function testForAllEthBuyAllCdcUserDptNotZeroNotEnoughAllFeeInDpt() public {
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");

        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testForAllEthBuyAllCdcUserDptEnoughAllFeeInDpt() public {
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");

        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testForAllEthBuyFixCdcUserHasNoDptAllFeeInDpt() public {
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");

        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);

    }

    function testForAllEthBuyFixCdcUserDptNotZeroNotEnoughAllFeeInDpt() public {
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");

        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testForAllEthBuyFixCdcUserDptEnoughAllFeeInDpt() public {
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");

        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testForFixEthBuyFixCdcUserHasNoDptAllFeeInDpt() public {
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");

        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);

    }

    function testForFixEthBuyFixCdcUserDptNotZeroNotEnoughAllFeeInDpt() public {
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");

        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testForFixEthBuyFixCdcUserDptEnoughAllFeeInDpt() public {
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");

        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testFailForFixEthBuyFixCdcUserHasNoDptSellAmtTooMuchAllFeeInDpt() public {
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");

        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 1001 ether;  // has only 1000 eth balance
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);

    }

    function testAssertForTestFailForFixEthBuyFixCdcUserHasNoDptBuyAmtTooMuchAllFeeInDpt() public {

        // if this test fails, it is because in the test testFailForFixEthBuyFixCdcUserHasNoDptBuyAmtTooMuchAllFeeInDpt ...
        // ... we do not actually buy too much, or the next test fails before the feature could be tested

        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");

        uint buyAmtOrId = DSToken(cdc).balanceOf(custodian20[cdc]) + 1 ether; // more than available
        uint sellAmtOrId = wdivT(wmulV(buyAmtOrId, usdRate[cdc], cdc), usdRate[eth], eth);
        user.transfer(sellAmtOrId);
    }

    function testFailForFixEthBuyFixCdcUserHasNoDptBuyAmtTooMuchAllFeeInDpt() public {
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");

        uint buyAmtOrId = DSToken(cdc).balanceOf(custodian20[cdc]) + 1 ether; // more than available
        uint sellAmtOrId = wdivT(wmulV(buyAmtOrId, usdRate[cdc], cdc), usdRate[eth], eth);
        DSToken(eth).transfer(user, sellAmtOrId);

        doExchange(eth, sellAmtOrId, cdc, buyAmtOrId);
    }

    function testFailForFixEthBuyFixCdcUserHasNoDptBothTooMuchAllFeeInDpt() public {

        userDpt = 123 ether; // this can be changed
        uint buyAmtOrId = INITIAL_BALANCE + 1 ether; // DO NOT CHANGE THIS!!!
        uint sellAmtOrId = DSToken(cdc).balanceOf(custodian20[cdc]) + 1 ether; // DO NOT CHANGE THIS!!!

        if (wdivT(wmulV(buyAmtOrId, usdRate[cdc], cdc), usdRate[eth], eth) <= sellAmtOrId) {
            sendToken(dpt, user, userDpt);

            doExchange(eth, sellAmtOrId, cdc, buyAmtOrId);
        }
    }

    function testFailSendEthIfNoEthIsSellTokenAllFeeInDpt() public {
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");

        uint sentEth = 1 ether;

        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 11 ether;
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        DiamondExchange(exchange).buyTokensWithFee.value(sentEth)(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testForFixDptBuyAllCdcUserDptEnoughAllFeeInDpt() public {
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");

        userDpt = 1000 ether;
        sendToken(dpt, user, userDpt);
        uint sellDpt = 10 ether;

        address sellToken = dpt;
        uint sellAmtOrId = sellDpt;
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testForAllDptBuyAllCdcUserDptEnoughAllFeeInDpt() public {
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");

        userDpt = 1000 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dpt;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        // DiamondExchange(exchange).buyTokensWithFee(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }
    function testForAllDptBuyFixCdcUserDptEnoughAllFeeInDpt() public {
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");

        userDpt = 1000 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dpt;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testForFixDptBuyFixCdcUserDptEnoughAllFeeInDpt() public {
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");

        userDpt = 1000 ether;
        sendToken(dpt, user, userDpt);
        uint sellDpt = 10 ether;

        address sellToken = dpt;
        uint sellAmtOrId = sellDpt;
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testFailBuyTokensWithFeeLiquidityContractHasInsufficientDpt() public {
        DiamondExchangeTester(liquidityContract).doTransfer(dpt, address(this), INITIAL_BALANCE);
        assertEq(DSToken(dpt).balanceOf(liquidityContract), 0);

        address sellToken = eth;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testBuyTokensWithFeeWithManualEthUsdRate() public {

        usdRate[eth] = 400 ether;
        DiamondExchange(exchange).setConfig("rate", eth, usdRate[eth]);
        TestFeedLike(feed[eth]).setValid(false);

        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testBuyTokensWithFeeWithManualDptUsdRate() public {

        usdRate[dpt] = 400 ether;
        DiamondExchange(exchange).setConfig("rate", dpt, usdRate[dpt]);
        TestFeedLike(feed[dpt]).setValid(false);

        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testBuyTokensWithFeeWithManualCdcUsdRate() public {

        usdRate[cdc] = 400 ether;
        DiamondExchange(exchange).setConfig("rate", cdc, usdRate[cdc]);
        TestFeedLike(feed[cdc]).setValid(false);

        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testBuyTokensWithFeeWithManualDaiUsdRate() public {

        usdRate[dai] = 400 ether;
        DiamondExchange(exchange).setConfig("rate", dai, usdRate[dai]);
        TestFeedLike(feed[dai]).setValid(false);

        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }

    function testFailBuyTokensWithFeeSendZeroEth() public {

        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, 0, buyToken, buyAmtOrId);
    }
    function testBuyTokensWithFeeWhenFeeIsZero() public {

        DiamondExchange(exchange).setConfig("fixFee", uint(0), "");
        DiamondExchange(exchange).setConfig("varFee", uint(0), "");

        userDpt = 123 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
    }
    function testUpdateRates() public {
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

    function testForFixEthBuyDpassUserHasNoDpt() public {

        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 16.5 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForFixEthBuyDpassUserDptNotEnough() public {

        userDpt = 5 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 16.5 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForFixEthBuyDpassUserDptEnough() public {

        userDpt = 1.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 15.65 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testFailForFixEthBuyDpassUserDptNotEnough() public {

        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 1 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testFailForFixEthBuyDpassUserEthNotEnough() public {

        userDpt = 1.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 10 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testFailForFixEthBuyDpassUserBothNotEnough() public {

        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 10 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForAllEthBuyDpassUserHasNoDpt() public {

        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForAllEthBuyDpassDptNotEnough() public {

        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForAllEthBuyDpassUserDptEnough() public {

        userDpt = 1.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }
    function testForFixDptBuyDpass() public {
        userDpt = 1000 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dpt;
        uint sellAmtOrId = 36.3 ether;                       //should be less than userDpt

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }
    function testFailForFixDptBuyDpassUserDptNotEnough() public {
        userDpt = 1000 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dpt;
        uint sellAmtOrId = 15.65 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForAllDptBuyDpass() public {

        userDpt = 500 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dpt;
        uint sellAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForFixCdcBuyDpassUserHasNoDpt() public {

        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = 25.89 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForFixCdcBuyDpassUserDptNotEnough() public {

        userDpt = 5 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = 25.89 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForFixCdcBuyDpassUserDptEnough() public {

        userDpt = 1.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = 25.89 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testFailForFixCdcBuyDpassUserDptNotEnoughEnd() public {

        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = 7 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testFailForFixCdcBuyDpassUserCdcNotEnough() public {

        userDpt = 1.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = 10 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testFailForFixCdcBuyDpassUserBothNotEnough() public {

        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = 10 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testFailForFixDpassBuyDpass() public {

        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        doExchange(dpass, dpassId[user], dpass, dpassId[seller]);
    }
    function testForAllCdcBuyDpassUserHasNoDpt() public {

        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }
    function testForAllCdcBuyDpassDptNotEnough() public {

        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }
    function testForAllCdcBuyDpassUserDptEnough() public {

        userDpt = 1.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }
    function testForFixDaiBuyDpassUserHasNoDpt() public {

        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 13.94 ether;                                 // the minimum value user has to pay

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForFixDaiBuyDpassUserDptNotEnough() public {

        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 13.94 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForFixDaiBuyDpassUserDptEnough() public {

        userDpt = 1.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 13.94 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }
    function testFailForFixDaiBuyDpassUserDptNotEnough() public {

        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 1 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }
    function testFailForFixDaiBuyDpassUserDaiNotEnough() public {

        userDpt = 1.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 10 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testFailForFixDaiBuyDpassUserBothNotEnough() public {

        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 10 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForAllDaiBuyDpassUserHasNoDpt() public {

        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForAllDaiBuyDpassDptNotEnough() public {

        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForAllDaiBuyDpassUserDptEnough() public {

        userDpt = 1.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }
//-------------------new--------------------------------------------------

    function testForFixEthBuyDpassUserHasNoDptFullFeeDpt() public {
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 16.5 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }
    function testForFixEthBuyDpassUserDptNotEnoughFullFeeDpt() public {
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");

        userDpt = 5 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 14.2 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForFixEthBuyDpassUserDptEnoughFullFeeDpt() public {
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 6.4 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 13.73 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testFailForFixEthBuyDpassUserDptNotEnoughFullFeeDpt() public {
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 13.73 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testFailForFixEthBuyDpassUserEthNotEnoughFullFeeDpt() public {
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 1.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 10 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testFailForFixEthBuyDpassUserBothNotEnoughFullFeeDpt() public {
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 13.72 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForAllEthBuyDpassUserHasNoDptFullFeeDpt() public {
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForAllEthBuyDpassDptNotEnoughFullFeeDpt() public {
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForAllEthBuyDpassUserDptEnoughFullFeeDpt() public {
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 1.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForFixDptBuyDpassFullFeeDpt() public {
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");

        userDpt = 1000 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dpt;
        uint sellAmtOrId = 36.3 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testFailForFixDptBuyDpassUserDptNotEnoughFullFeeDpt() public {
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");

        userDpt = 1000 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dpt;
        uint sellAmtOrId = 15.65 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }
    function testForAllDptBuyDpassFullFeeDpt() public {
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");

        userDpt = 500 ether;                                // should not change this value
        sendToken(dpt, user, userDpt);

        address sellToken = dpt;
        uint sellAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }
    function testForFixCdcBuyDpassUserHasNoDptFullFeeDpt() public {
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = 25.89 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForFixCdcBuyDpassUserDptNotEnoughFullFeeDpt() public {
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 5 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = 25.89 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForFixCdcBuyDpassUserDptEnoughFullFeeDpt() public {
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 1.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = 25.89 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testFailForFixCdcBuyDpassUserDptNotEnoughFullFeeDpt() public {
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = 7 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testFailForFixCdcBuyDpassUserCdcNotEnoughFullFeeDpt() public {
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 1.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = 10 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testFailForFixCdcBuyDpassUserBothNotEnoughFullFeeDpt() public {
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = 10 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testFailForFixDpassBuyDpassFullFeeDpt() public {
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);


        doExchange(dpass, dpassId[user], dpass, dpassId[seller]);
    }

    function testForAllCdcBuyDpassUserHasNoDptFullFeeDpt() public {
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForAllCdcBuyDpassDptNotEnoughFullFeeDpt() public {
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForAllCdcBuyDpassUserDptEnoughFullFeeDpt() public {
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 1.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }
    function testForFixDaiBuyDpassUserHasNoDptFullFeeDpt() public {
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 13.94 ether;                                 // the minimum value user has to pay

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForFixDaiBuyDpassUserDptNotEnoughFullFeeDpt() public {
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 13.94 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForFixDaiBuyDpassUserDptEnoughFullFeeDpt() public {
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 1.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 13.94 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testFailForFixDaiBuyDpassUserDptNotEnoughFullFeeDpt() public {
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");

        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 1 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testFailForFixDaiBuyDpassUserDaiNotEnoughFullFeeDpt() public {
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 1.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 10 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testFailForFixDaiBuyDpassUserBothNotEnoughFullFeeDpt() public {
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 10 ether;

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForAllDaiBuyDpassUserHasNoDptFullFeeDpt() public {
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 0 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForAllDaiBuyDpassDptNotEnoughFullFeeDpt() public {
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 1 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }

    function testForAllDaiBuyDpassUserDptEnoughFullFeeDpt() public {
        DiamondExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");

        userDpt = 1.812 ether;
        sendToken(dpt, user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]);
    }
}
