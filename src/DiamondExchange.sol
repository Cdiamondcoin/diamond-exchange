pragma solidity ^0.5.11;

import "ds-math/math.sol";
import "ds-auth/auth.sol";
import "ds-token/token.sol";
import "ds-stop/stop.sol";
import "ds-note/note.sol";
import "./Liquidity.sol";
import "dpass/Dpass.sol";
import "./Redeemer.sol";
/**
* @dev Contract to get ETH/USD price
*/
contract TrustedFeedLikeDex {
    function peek() external view returns (bytes32, bool);
}



/**
* @dev Contract to calculate user fee based on amount
*/
contract TrustedFeeCalculator {

    function calculateFee(
        address sender,
        uint256 value,
        address sellToken,
        uint256 sellAmtOrId,
        address buyToken,
        uint256 buyAmtOrId
    ) external view returns (uint);

    function getCosts(
        address user,                                                           // user for whom we want to check the costs for
        address sellToken_,
        uint256 sellId_,
        address buyToken_,
        uint256 buyAmtOrId_
    ) public view returns (uint256 sellAmtOrId_, uint256 feeDpt_, uint256 feeV_, uint256 feeSellT_) {
        // calculate expected sell amount when user wants to buy something anc only knows how much he wants to buy from a token and whishes to know how much it will cost.
    }
}


contract TrustedAsm {
    function notifyTransferFrom(address token, address src, address dst, uint256 id721) external;
    function basePrice(address erc721, uint256 id721) external view returns(uint256);
    function getAmtForSale(address token) external view returns(uint256);
    function mint(address token, address dst, uint256 amt) external;
}


contract TrustedErc721 {
    function transferFrom(address src, address to, uint256 amt) external;
    function ownerOf(uint256 tokenId) external view returns (address);
}


contract TrustedDSToken {
    function transferFrom(address src, address dst, uint wad) external returns (bool);
    function totalSupply() external view returns (uint);
    function balanceOf(address src) external view returns (uint);
    function allowance(address src, address guy) external view returns (uint);
}


/**
 * @title Cdc
 * @dev Cdc Exchange contract.
 */
contract DiamondExchangeEvents {

    event LogBuyTokenWithFee(
        uint256 indexed txId,
        address indexed sender,
        address custodian20,
        address sellToken,
        uint256 sellAmountT,
        address buyToken,
        uint256 buyAmountT,
        uint256 feeValue
    );

    event LogConfigChange(bytes32 what, bytes32 value, bytes32 value1);

    event LogTransferEth(address src, address dst, uint256 val);
    // TODO: remove all following LogTest()
    event LogTest(uint256 what);
    event LogTest(bool what);
    event LogTest(address what);
    event LogTest(bytes32 what);
}

contract DiamondExchange is DSAuth, DSStop, DiamondExchangeEvents {
    TrustedDSToken public cdc;                              // CDC token contract
    address public dpt;                                     // DPT token contract

    mapping(address => uint256) private rate;               // exchange rate for a token
    mapping(address => bool) public manualRate;             // manualRate is allowed for a token (if feed invalid)

    mapping(address => TrustedFeedLikeDex)
    public priceFeed;                                       // price feed address for token

    mapping(address => bool) public canBuyErc20;            // stores allowed ERC20 tokens to buy
    mapping(address => bool) public canSellErc20;           // stores allowed ERC20 tokens to sell
    mapping(address => bool) public canBuyErc721;           // stores allowed ERC20 tokens to buy
    mapping(address => bool) public canSellErc721;          // stores allowed ERC20 tokens to sell
    mapping(address => mapping(address => bool))            // stores tokens that seller does not accept, ...
        public denyToken;                                   // ... and also token pairs that can not be traded
    mapping(address => uint) public decimals;               // stores decimals for each ERC20 token
    mapping(address => bool) public decimalsSet;            // stores if decimals were set for ERC20 token
    mapping(address => address payable) public custodian20; // custodian that holds an ERC20 token for Exchange
    mapping(address => bool) public handledByAsm;           // defines if token is managed by Asset Management
    mapping(
        address => mapping(
            address => mapping(
                uint => uint))) public buyPrice;            // buyPrice[token][owner][tokenId] price of dpass token ...
                                                            // ... defined by owner of dpass token
    mapping(address => bool) redeemFeeToken;                // tokens allowed to pay redeem fee with
    TrustedFeeCalculator public fca;                        // fee calculator contract

    address payable public liq;                             // contract providing DPT liquidity to pay for fee
    address payable public wal;                             // wallet address, where we keep all the tokens we received as fee
    address payable public burner;                          // contract where accured fee of DPT is stored before being burned
    TrustedAsm public asm;                                  // Asset Management contract
    uint256 public fixFee;                                  // Fixed part of fee charged for buying 18 decimals precision in base currency
    uint256 public varFee;                                  // Variable part of fee charged for buying 18 decimals precision in base currency
    uint256 public profitRate;                              // the percentage of profit that is burned on all fees received. ...
                                                            // ... 18 decimals precision
    uint256 public callGas = 2500;                          // using this much gas when Ether is transferred
    uint256 public txId;                                    // Unique id of each transaction.
    bool public takeProfitOnlyInDpt = true;                 // If true, it takes cost + profit in DPT, if false only profit in DPT

    uint256 public dust = 10000;                            // Numbers below this amount are considered 0. Can only be used ...
                                                            // ... along with 18 decimal precisions numbers.

    bool liqBuysDpt;                                        // if true then liq contract is called directly to buy necessary dpt, otherwise we...
                                                            // ... just send DPT from liq contracts address to burner.

    bool locked;                                            // protect against reentrancy attacks
    address eth = address(0xee);                            // to handle ether the same way as tokens we associate a fake address to it
    bool kycEnabled;                                        // if true then user must be on the kyc list in order to use the system
    mapping(address => bool) public kyc;                    // kyc list of users that are allowed to exchange tokens
    address payable public redeemer;                        // redeemer contract to handle physical diamond delivery to users

//-----------included-from-ds-math---------------------------------begin
    uint constant WAD = 1 ether;

    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, "ds-math-add-overflow");
    }
    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x, "ds-math-sub-underflow");
    }
    function min(uint x, uint y) internal pure returns (uint z) {
        return x <= y ? x : y;
    }
    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, "ds-math-mul-overflow");
    }
    function wmul(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, y), WAD / 2) / WAD;
    }
    function wdiv(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, WAD), y / 2) / y;
    }
//-----------included-from-ds-math---------------------------------end

    modifier nonReentrant {
        require(!locked, "dex-reentrancy-detected");
        locked = true;
        _;
        locked = false;
    }

    modifier kycCheck {
        require(!kycEnabled || kyc[msg.sender], "dex-you-are-not-on-kyc-list");
        _;
    }

    /**
    * @dev Fallback function to buy tokens.
    */
    function () external payable {
        buyTokensWithFee(eth, msg.value, address(cdc), uint(-1));
    }

    /**
    * @dev Set configuration values for contract
    */
    function setConfig(bytes32 what_, bytes32 value_, bytes32 value1_) public auth {
        if (what_ == "profitRate") {

            profitRate = uint256(value_);

            require(profitRate <= 1 ether, "dex-profit-rate-out-of-range");

        } else if (what_ == "rate") {
            address token = addr(value_);
            uint256 value = uint256(value1_);

            require(
                canSellErc20[token] ||
                canBuyErc20[token],
                "dex-token-not-allowed-rate");

            require(value > 0, "dex-rate-must-be-greater-than-0");

            rate[token] = value;

        } else if (what_ == "kyc") {

            address user_ = addr(value_);

            require(user_ != address(0x0), "dex-wrong-address");

            kyc[user_] = uint(value1_) > 0;
        } else if (what_ == "allowTokenPair") {         // TODO: test

            address sellToken_ = addr(value_);
            address buyToken_ = addr(value1_);

            require(canSellErc20[sellToken_] || canSellErc721[sellToken_],
                "dex-selltoken-not-listed");
            require(canBuyErc20[buyToken_] || canBuyErc721[buyToken_],
                "dex-buytoken-not-listed");

            denyToken[sellToken_][buyToken_] = false;
        } else if (what_ == "denyTokenPair") {          // TODO: test

            address sellToken_ = addr(value_);
            address buyToken_ = addr(value1_);

            require(canSellErc20[sellToken_] || canSellErc721[sellToken_],
                "dex-selltoken-not-listed");
            require(canBuyErc20[buyToken_] || canBuyErc721[buyToken_],
                "dex-buytoken-not-listed");

            denyToken[sellToken_][buyToken_] = true;
        } else if (what_ == "fixFee") {

            fixFee = uint256(value_);

        } else if (what_ == "varFee") {

            varFee = uint256(value_);

            require(varFee <= 1 ether, "dex-var-fee-too-high");

        } else if (what_ == "redeemFeeToken") {         // TODO: test

            address token = addr(value_);
            require(token != address(0), "dex-zero-address-redeemfee-token");
            redeemFeeToken[token] = uint256(value1_) > 0;

        } else if (what_ == "manualRate") {

            address token = addr(value_);

            require(
                canSellErc20[token] ||
                canBuyErc20[token],
                "dex-token-not-allowed-manualrate");

            manualRate[token] = uint256(value1_) > 0;

        } else if (what_ == "priceFeed") {

            require(canSellErc20[addr(value_)] || canBuyErc20[addr(value_)],
                "dex-token-not-allowed-pricefeed");

            require(addr(value1_) != address(address(0x0)),
                "dex-wrong-pricefeed-address");

            priceFeed[addr(value_)] = TrustedFeedLikeDex(addr(value1_));

        } else if (what_ == "takeProfitOnlyInDpt") {

            takeProfitOnlyInDpt = uint256(value_) > 0;

        } else if (what_ == "liqBuysDpt") {

            require(liq != address(0x0), "dex-wrong-address");

            Liquidity(liq).burn(dpt, burner, 0);                // check if liq does have the proper burn function

            liqBuysDpt = uint256(value_) > 0;

        } else if (what_ == "liq") {

            liq = address(uint160(addr(value_)));

            require(liq != address(0x0), "dex-wrong-address");

            require(dpt != address(0), "dex-add-dpt-token-first");

            require(
                TrustedDSToken(dpt).balanceOf(liq) > 0,
                "dex-insufficient-funds-of-dpt");

            if(liqBuysDpt) {

                Liquidity(liq).burn(dpt, burner, 0);            // check if liq does have the proper burn function
            }

        } else if (what_ == "handledByAsm") {

            address token = addr(value_);

            require(canBuyErc20[token] || canBuyErc721[token],
                    "dex-token-not-allowed-handledbyasm");

            handledByAsm[token] = uint256(value1_) > 0;

        } else if (what_ == "asm") {

            require(addr(value_) != address(0x0), "dex-wrong-address");

            asm = TrustedAsm(addr(value_));

        } else if (what_ == "burner") {

            require(addr(value_) != address(0x0), "dex-wrong-address");

            burner = address(uint160(addr(value_)));

        } else if (what_ == "cdc") {

            require(addr(value_) != address(0x0), "dex-wrong-address");

            cdc = TrustedDSToken(addr(value_));

        } else if (what_ == "fca") {

            require(addr(value_) != address(0x0), "dex-wrong-address");

            fca = TrustedFeeCalculator(addr(value_));

        } else if (what_ == "custodian20") {

            require(addr(value_) != address(0x0), "dex-wrong-address");

            custodian20[addr(value_)] = address(uint160(addr(value1_)));

        } else if (what_ == "decimals") {

            require(addr(value_) != address(0x0), "dex-wrong-address");

            uint decimal = uint256(value1_);

            decimals[addr(value_)] = 10 ** decimal;

            decimalsSet[addr(value_)] = true;

        } else if (what_ == "wal") {

            require(addr(value_) != address(0x0), "dex-wrong-address");

            wal = address(uint160(addr(value_)));

        } else if (what_ == "callGas") {

            callGas = uint256(value_);

        } else if (what_ == "dust") {

            dust = uint256(value_);

        } else if (what_ == "canBuyErc20") {

            require(addr(value_) != address(0x0), "dex-wrong-address");

            canBuyErc20[addr(value_)] = uint(value1_) > 0;

        } else if (what_ == "canSellErc20") {

            require(addr(value_) != address(0x0), "dex-wrong-address");

            canSellErc20[addr(value_)] = uint(value1_) > 0;

        } else if (what_ == "canBuyErc721") {

            require(addr(value_) != address(0x0), "dex-wrong-address");

            canBuyErc721[addr(value_)] = uint(value1_) > 0;

        } else if (what_ == "canSellErc721") {

            require(addr(value_) != address(0x0), "dex-wrong-address");

            canSellErc721[addr(value_)] = uint(value1_) > 0;

        } else if (what_ == "kycEnabled") {

            kycEnabled = uint(value_) > 0;

        } else if (what_ == "dpt") {

            require(addr(value_) != address(0x0), "dex-wrong-address");

            dpt = addr(value_);

        } else if (what_ == "redeemer") {

            require(addr(value_) != address(0x0), "dex-wrong-redeemer-address");

            redeemer = address(uint160(addr(value_)));

        } else {

            require(false, "dex-no-such-option");
        }

        emit LogConfigChange(what_, value_, value1_);
    }
    
    /**
    * @dev Redeem token and pay fee for redeem.
    */
    //TODO: test
    function redeem(
        address redeemToken_,
        uint256 redeemAmtOrId_,
        address feeToken_,
        uint256 feeAmt_,
        address payable custodian_
    ) public payable stoppable nonReentrant returns(uint redeemId) { // kyc check will thake place on redeem contract.

        require(redeemFeeToken[feeToken_] || feeToken_ == dpt, "dex-token-not-to-pay-redeem-fee");
        
        if(canBuyErc721[redeemToken_] || canSellErc721[redeemToken_]) {

            Dpass(redeemToken_)                                // transfer token to redeemer
            .transferFrom(
                msg.sender,
                redeemer,
                redeemAmtOrId_);

        } else if (canBuyErc20[redeemToken_] || canSellErc20[redeemToken_]) {

            _sendToken(redeemToken_, msg.sender, redeemer, redeemAmtOrId_);

        } else {
            require(false, "dex-token-can-not-be-redeemed");
        }
        
        _sendToken(feeToken_, msg.sender, redeemer, feeAmt_);

        return Redeemer(redeemer).redeem(msg.sender, redeemToken_, redeemAmtOrId_, feeToken_, feeAmt_, custodian_);
    }

    /**
    * @dev Тoken purchase with fee. (If user has DPT he must approve this contract,
    * otherwise transaction will fail.)
    */
    function buyTokensWithFee (
        address sellToken_,
        uint256 sellAmtOrId_,
        address buyToken_,
        uint256 buyAmtOrId_
    ) public payable stoppable nonReentrant kycCheck {
        uint buyV_;
        uint sellV_;
        uint feeV_;
        uint sellT_;
        uint buyT_;
        
        require(!denyToken[sellToken_][buyToken_], "dex-cant-use-this-token-to-buy");

        _updateRates(sellToken_, buyToken_);    // update currency rates

        (buyV_, sellV_) = _getValues(           // calculate highest possible buy and sell values (here they might not match)
            sellToken_,
            sellAmtOrId_,
            buyToken_,
            buyAmtOrId_);

        feeV_ = calculateFee(                   // calculate fee user has to pay for exchange
            msg.sender,
            min(buyV_, sellV_),
            sellToken_,
            sellAmtOrId_,
            buyToken_,
            buyAmtOrId_);

        (sellT_, buyT_) = _takeFee(             // takes the calculated fee from user in DPT or sellToken_ ...
            feeV_,                              // ... calculates final sell and buy values (in base currency)
            sellV_,
            buyV_,
            sellToken_,
            sellAmtOrId_,
            buyToken_,
            buyAmtOrId_);

        _transferTokens(                        // transfers tokens to user and seller
            sellT_,
            buyT_,
            sellToken_,
            sellAmtOrId_,
            buyToken_,
            buyAmtOrId_,
            feeV_);
    }

    /**
    * @dev Get sell and buy token values in base currency
    */
    function _getValues(
        address sellToken_,
        uint256 sellAmtOrId_,
        address buyToken_,
        uint256 buyAmtOrId_
    ) internal returns (uint256 buyV, uint256 sellV) {
        uint sellAmtT_ = sellAmtOrId_;
        uint buyAmtT_ = buyAmtOrId_;
        uint maxT_;

        require(buyToken_ != eth, "dex-we-do-not-sell-ether");          // we can not sell Ether with this smart contract currently
        require(sellToken_ == eth || msg.value == 0,                    // we don't accept ETH if user wants to sell other token
                "dex-do-not-send-ether");

        if (canSellErc20[sellToken_]) {                                 // if sellToken_ is a valid ERC20 token

            maxT_ = sellToken_ == eth ?
                msg.value :
                min(
                    TrustedDSToken(sellToken_).balanceOf(msg.sender),
                    TrustedDSToken(sellToken_).allowance(
                        msg.sender, address(this)));

            require(maxT_ > 0, "dex-please-approve-us");

            require(
                sellToken_ == eth ||                                    // disregard Ether
                sellAmtOrId_ == uint(-1) ||                             // disregard uint(-1) as it has a special meaning
                sellAmtOrId_ <= maxT_,                                  // sellAmtOrId_ should be less then sellToken_ available to this contract
                "dex-sell-amount-exceeds-allowance");

            require(
                sellToken_ != eth ||                                    // regard Ether only
                sellAmtOrId_ == uint(-1) ||                             // disregard uint(-1) as it has a special meaning
                sellAmtOrId_ <= msg.value,                              // sellAmtOrId_ sold should be less than the Ether we received from user
                "dex-sell-amount-exceeds-ether-value");

            if (sellAmtT_ > maxT_ ) {                                   // if user wants to sell maxTimum possible

                sellAmtT_ = maxT_;
            }

            sellV = wmulV(sellAmtT_, rate[sellToken_], sellToken_);     // sell value in base currency

        } else if (canSellErc721[sellToken_]) {                         // if sellToken_ is a valid ERC721 token

            sellV = getPrice(sellToken_, sellAmtOrId_);                 // get price from Asset Management

        } else {

            require(false, "dex-token-not-allowed-to-be-sold");

        }

        if (canBuyErc20[buyToken_]) {                                   // if buyToken_ is a valid ERC20 token

            maxT_ = handledByAsm[buyToken_] ?                           // set buy amount to maxT_ possible
                asm.getAmtForSale(buyToken_) :                          // if managed by asset management get available
                min(                                                    // if not managed by asset management get maxT_ available
                    TrustedDSToken(buyToken_).balanceOf(
                        custodian20[buyToken_]),
                    TrustedDSToken(buyToken_).allowance(
                        custodian20[buyToken_], address(this)));

            require(maxT_ > 0, "dex-0-token-is-for-sale");

            require(                                                    // require token's buy amount to be less or equal than available to us
                buyToken_ == eth ||                                     // disregard Ether
                buyAmtOrId_ == uint(-1) ||                              // disregard uint(-1) as it has a special meaning
                buyAmtOrId_ <= maxT_,                                   // amount must be less or equal that maxT_ available
                "dex-buy-amount-exceeds-allowance");

            if (buyAmtOrId_ > maxT_) {                                  // user wants to buy the maxTimum possible

                buyAmtT_ = maxT_;
            }

            buyV = wmulV(buyAmtT_, rate[buyToken_], buyToken_);         // final buy value in base currency

        } else if (canBuyErc721[buyToken_]) {                           // if buyToken_ is a valid ERC721 token

            require(canSellErc20[sellToken_],                           // require that at least one of sell and buy token is ERC20
                    "dex-one-of-tokens-must-be-erc20");

            buyV = getPrice(                                            // calculate price with Asset Management contract
                buyToken_,
                buyAmtOrId_);

        } else {
            require(false, "dex-token-not-allowed-to-be-bought");       // token can not be bought here
        }
    }

    /**
    * @dev Calculate fee locally or using an external smart contract
    * @return the fee amount in USD
    */
    function calculateFee(
        address sender_,
        uint256 value_,
        address sellToken_,
        uint256 sellAmtOrId_,
        address buyToken_,
        uint256 buyAmtOrId_
    ) public view returns (uint256) {

        if (fca == TrustedFeeCalculator(0)) {

            return fixFee + wmul(varFee, value_);                       // calculate proportional fee locally

        } else {

            return fca.calculateFee(                                    // calculate fee using external smart contract
                sender_,
                value_,
                sellToken_,
                sellAmtOrId_,
                buyToken_,
                buyAmtOrId_);
        }
    }

    /**
    * @dev Taking feeV_ from user. If user has DPT takes it, if there is none buys it for user.
    * @return the amount of remaining ETH after buying feeV_ if it was required
    */
    function _takeFee(
        uint256 feeV_,
        uint256 sellV_,
        uint256 buyV_,
        address sellToken_,
        uint256 sellAmtOrId_,
        address buyToken_,
        uint256 buyAmtOrId_
    )
    internal
    returns(uint256 sellT, uint256 buyT) {
        uint feeTakenV_;
        uint amtT_;
        address token_;
        address src_;
        uint restFeeV_;

        feeTakenV_ = sellToken_ != dpt ?                            // if sellToken_ is not dpt then try to take feeV_ in DPT
            min(_takeFeeInDptFromUser(feeV_), feeV_) :
            0;

        restFeeV_ = sub(feeV_, feeTakenV_);

        if (feeV_ - feeTakenV_ > dust                               // if we could not take all fees from user in ...
            && feeV_ - feeTakenV_ <= feeV_) {                       // ... DPT (with round-off errors considered)

            if (canSellErc20[sellToken_]) {

                require(
                    canBuyErc20[buyToken_] ||                       // apply rule below to ERC721 buyTokens only
                    sellV_ + dust >=                                // for erc721 buy tokens the sellValue must be buyValue plus restFeeV_
                        buyV_ + restFeeV_,
                    "dex-not-enough-user-funds-to-sell");

                token_ = sellToken_;                                // fees are sent in this token_
                src_ = msg.sender;                                  // owner of token_ is sender
                amtT_ = sellAmtOrId_;                               // max amount user wants to sell

                if (add(sellV_, dust) <                             // if buy value is too big
                    add(buyV_, restFeeV_)) {

                    buyV_ = sub(sellV_, restFeeV_);                 // buyValue is adjusted
                }

                sellV_ = buyV_;                                     // reduce sellValue to buyValue plus restFeeV_

            } else if (canBuyErc20[buyToken_]) {                    // if sellToken_ is an ERC721 token_ and buyToken_ is an ERC20 token_
                require(
                    sellV_ <= buyV_ + dust,                         // check if user can be supplied with enough buy tokens
                    "dex-not-enough-tokens-to-buy");


                token_ = buyToken_;                                 // fees are paid in buy token_

                src_ = custodian20[token_];                         // source of funds is custodian

                amtT_ = buyAmtOrId_;                                // max amount the user intended to buy

                if (sellV_ <= add(add(buyV_, restFeeV_), dust))

                    buyV_ = sub(sellV_, restFeeV_);

            } else {

                require(false,                                      // not allowed to have both buy and sell tokens to be ERC721. ...
                    "dex-no-token-to-get-fee-from");                // ... We should never end up here since dex-one-of-tokens-must-be-erc20 ...
                                                                    // ... will be fired first. It is here for precaution.


            }

            assert(                                                 // buy value must be less or equal to sell value
                token_ != buyToken_ ||
                sub(buyV_, restFeeV_) <= add(sellV_, dust));

            assert(                                                 // buy value must be less or equal to sell value
                token_ != sellToken_ ||
                buyV_ <= add(sellV_, dust));

            _takeFeeInToken(                                        // send profit and costs in sellToken_
                restFeeV_,
                feeTakenV_,
                token_,
                src_,
                amtT_);

        } else {                                                    // no feeV_ must be payed with sellToken_
            require(buyV_ <= sellV_ || canBuyErc20[buyToken_],
                "dex-not-enough-funds");

            require(buyV_ >= sellV_ || canSellErc20[sellToken_],
                "dex-not-enough-tokens-to-buy");

            sellV_ = min(buyV_, sellV_);

            buyV_ = sellV_;
        }

        sellT = canSellErc20[sellToken_] ?                          // calculate token_ amount to be sold
            wdivT(sellV_, rate[sellToken_], sellToken_) :
            sellAmtOrId_;

        buyT = canBuyErc20[buyToken_] ?
            wdivT(buyV_, rate[buyToken_], buyToken_) :
            buyAmtOrId_;

        if (sellToken_ == eth) {                                    // send unused Ether back to user

            amtT_ = wdivT(
                restFeeV_,
                rate[sellToken_],
                sellToken_);

            _sendToken(
                eth,
                address(this),
                msg.sender,
                sub(msg.value, add(sellT, amtT_)));
        }
    }

    /**
    * @dev Transfer sellToken from user and buyToken to user
    */
    function _transferTokens(
        uint256 sellT_,                                                 // sell token amount
        uint256 buyT_,                                                  // buy token amount
        address sellToken_,                                             // token sold by user
        uint256 sellAmtOrId_,                                           // sell amount or sell token id
        address buyToken_,                                              // token bought by user
        uint256 buyAmtOrId_,                                            // buy amount or buy id
        uint256 feeV_                                                   // value of total fees in base currency
    ) internal {
        address payable payTo_;

        if (canBuyErc20[buyToken_]) {

            payTo_ = handledByAsm[buyToken_] ?
                address(uint160(address(asm))):
                custodian20[buyToken_];                                 // we pay not to custodian but to asm

            _sendToken(buyToken_, payTo_, msg.sender, buyT_);           // send buyToken_ from custodian to user
        }

        if (canSellErc20[sellToken_]) {                                 // if sellToken_ is a valid ERC20 token

            if (canBuyErc721[buyToken_]) {                              // if buyToken_ is a valid ERC721 token

                payTo_ = address(uint160(address(                       // we pay to owner
                    Dpass(buyToken_).ownerOf(buyAmtOrId_))));

                asm.notifyTransferFrom(                                 // notify Asset management about the transfer
                    buyToken_,
                    payTo_,
                    msg.sender,
                    buyAmtOrId_);

                TrustedErc721(buyToken_)                                // transfer buyToken_ from custodian to user
                .transferFrom(
                    payTo_,
                    msg.sender,
                    buyAmtOrId_);


            }

            _sendToken(sellToken_, msg.sender, payTo_, sellT_);         // send token or Ether from user to custodian

        } else {                                                        // if sellToken_ is a valid ERC721 token

            TrustedErc721(sellToken_)                                   // transfer ERC721 token from user to custodian
            .transferFrom(
                msg.sender,
                payTo_,
                sellAmtOrId_);

            sellT_ = sellAmtOrId_;
        }

        require(!denyToken[sellToken_][payTo_],
            "dex-token-denied-by-seller");

        if (payTo_ == address(asm) ||
            (canSellErc721[sellToken_] && handledByAsm[buyToken_]))

            asm.notifyTransferFrom(                                     // notify Asset Management contract about transfer
                               sellToken_,
                               msg.sender,
                               payTo_,
                               sellT_);

        _logTrade(sellToken_, sellT_, buyToken_, buyT_, buyAmtOrId_, feeV_);
    }

    /*
    * @dev Token sellers can deny accepting any token_
    */
    function setDenyToken(address token_, bool denyOrAccept_) public {
        require(canSellErc20[token_] || canSellErc721[token_], "dex-can-not-use-anyway");
        denyToken[token_][msg.sender] = denyOrAccept_;
    }

    /*
    * @dev Whitelist of users being able to convert tokens.
    */
    function setKyc(address user_, bool allowed_) public auth {
        require(user_ != address(0), "asm-kyc-user-can-not-be-zero");
        kyc[user_] = allowed_;
    }

    /*
    * @dev Returns true if seller accepts token as payment
    */
    function sellerAcceptsToken(address token_, address seller_)
    public view returns (bool) {

        return (canSellErc20[token_] ||
                canSellErc721[token_]) &&
                !denyToken[token_][seller_];
    }


    /*
    * @dev Returns true if token is handled by Asset Management
    *
    * When a token is an erc20 token and handled by asm it implies that
    * asm will mint and burn the token upon request.
    *
    * When a token is an erc721 token and handled by asm it implies that
    * token is used for collateral for CDC token.
    */
    function isHandledByAsm(address token_) public view returns (bool) {
        return handledByAsm[token_];
    }

    /**
    * @dev Collect all available info about a diamond
    * Returns diamond data with following arguments
    *
    * ownerCustodian_[0]    = owner
    * ownerCustodian_[1]    = custodian
    * attrs_[0]             = issuer
    * attrs_[1]             = report
    * attrs_[2]             = state eg.: "valid" "invalid" "sale"
    * attrs_[3]             = cccc ( cut, clarity, color, carat)
    * attrs_[4]             = attributeHash
    * attrs_[5]             = currentHashingAlgorithm
    * carat_                = weight in carats
    * priceV_               = current effective sale price in base currency
    */
    function getDiamondInfo(address token_, uint256 tokenId_)
    public view returns(
        address[2] memory ownerCustodian_,
        bytes32[6] memory attrs_,
        uint24 carat_,
        uint priceV_
    ) {
        require(canBuyErc721[token_] || canSellErc721[token_], "dex-token-not-a-dpass-token");
        (ownerCustodian_, attrs_, carat_) = Dpass(token_).getDiamondInfo(tokenId_);
        priceV_ = getPrice(token_, tokenId_);
    }


    /**
    * @dev Get sell price of dpass token
    */
    function getBuyPrice(address token_, uint256 tokenId_) public view returns(uint256) {
        // require(canBuyErc721[token_], "dex-token-not-for-sale");
        return buyPrice[token_][TrustedErc721(token_).ownerOf(tokenId_)][tokenId_];
    }

    /**
    * @dev Get sell price of dpass token if price 0 return
    */
    function setBuyPrice(address token_, uint256 tokenId_, uint256 price_) public {
        address seller_ = msg.sender;
        require(canBuyErc721[token_], "dex-token-not-for-sale");

        if (                                                                //TODO: test
            msg.sender == Dpass(token_).getCustodian(tokenId_) &&
            address(asm) == Dpass(token_).ownerOf(tokenId_)
        ) seller_ = address(asm);

        buyPrice[token_][seller_][tokenId_] = price_;
    }

    /**
    * @dev Get price of dpass token
    */
    function getPrice(address token_, uint256 tokenId_) public view returns(uint256) {
        uint basePrice_;
        address owner_ = TrustedErc721(token_).ownerOf(tokenId_);
        uint buyPrice_ = buyPrice[token_][owner_][tokenId_];
        require(canBuyErc721[token_], "dex-token-not-for-sale");
        if( buyPrice_ == 0 || buyPrice_ == uint(-1)) {
            basePrice_ = asc.basePrice(token_, tokenId_);
            require(basePrice_ != 0, "dex-zero-price-not-allowed");
            return basePrice_;
        } else {
            return buyPrice_;
        }
    }

    /**
    * @dev calculates how much of a certain token user must spend in order to buy certain amount of token with fees.
    * @return the sellAmount or if sellToken is dpass 1 if sell can be made and 0 if not, and the amount of additional dpt fee,
    */
    function getCosts(
        address user,                                                           // user for whom we want to check the costs for
        address sellToken_,                                                     // token we want to know how much we must pay of
        uint256 sellId_,                                                        // if sellToken_ is dpass then this is the tokenId otherwise ignored
        address buyToken_,                                                      // the token user wants to buy
        uint256 buyAmtOrId_                                                     // the amount user wants to buy
    ) public view 
    returns (
        uint256 sellAmtOrId_,                                                   // the calculated amount of tokens needed to be solc to get buyToken_
        uint256 feeDpt_,                                                        // the fee paid in DPT if user has DPT ...
                                                                                // ... (if you dont want to calculate with user DPT set user address to 0x0
        uint256 feeV_,                                                          // total fee to be paid in base currency 
        uint256 feeSellT_                                                       // fee to be paid in sellTokens (this amount will be subtracted as fee from user)
    ) {
        uint buyV_;
        uint dptBalance_;
        uint feeDptV_;

        if(fca == TrustedFeeCalculator(0)) {

            require(user != address(0),
                "dex-user-address-zero");

            require(
                canSellErc20[sellToken_] ||
                canSellErc721[sellToken_],
                "dex-selltoken-invalid");

            require(
                canBuyErc20[buyToken_] ||
                canBuyErc721[buyToken_],
                "dex-buytoken-invalid");

            require(
                !(canBuyErc721[buyToken_] &&
                canSellErc721[sellToken_]),
                "dex-both-tokens-dpass");

            require(dpt != address(0), "dex-dpt-address-zero");

            if(canBuyErc20[buyToken_]) {

                buyV_ = handledByAsm[buyToken_] ?                               // set buy amount to max possible
                        asm.getAmtForSale(buyToken_) :                          // if managed by asset management get available
                        min(                                                    // if not managed by asset management get buyV_ available
                            TrustedDSToken(buyToken_).balanceOf(
                                custodian20[buyToken_]),
                            TrustedDSToken(buyToken_).allowance(
                                custodian20[buyToken_], address(this)));

                buyV_ = min(buyV_, buyAmtOrId_);

                buyV_ = wmulV(buyV_, _getNewRate(buyToken_), buyToken_);

            } else {

                buyV_ = getPrice(buyToken_, buyAmtOrId_);
            }

            dptBalance_ = TrustedDSToken(dpt).balanceOf(user);

            feeV_ = add(
                wmul(buyV_, varFee),
                fixFee);

            feeDpt_ = wmul(
                wdivT(
                    feeV_,
                    _getNewRate(dpt),
                    dpt),
                takeProfitOnlyInDpt ? profitRate : 1 ether);

            if(canSellErc20[sellToken_]) {

                if(dptBalance_ <= add(feeDpt_, dust)) {

                    feeDptV_ = wmulV(dptBalance_, _getNewRate(dpt), dpt);

                    feeDpt_ = dptBalance_;

                } else {

                    feeDptV_ = wmulV(feeDpt_, _getNewRate(dpt), dpt);

                }

                feeSellT_ = wdivT(sub(feeV_, min(feeV_, feeDptV_)), _getNewRate(sellToken_), sellToken_);

                sellAmtOrId_ = add(
                    wdivT(
                        buyV_,
                        _getNewRate(sellToken_),
                        sellToken_),
                    feeSellT_);

            } else {

                sellAmtOrId_ = add(buyV_, dust) >= getPrice(sellToken_, sellId_) ? 1 : 0;
                feeDpt_ = min(feeDpt_, dptBalance_);
            }
        } else {

            return fca.getCosts(user, sellToken_, sellId_, buyToken_, buyAmtOrId_);
        }
    }
    /**
    * @dev Get exchange rate in base currency
    */
    function getLocalRate(address token_) public view auth returns(uint256) {
        return rate[token_];
    }

    /**
    * @dev Get manual rate. If manual rate for token is set to true then if rate
    * feed returns invalid data, still a manually set rate can be used.
    */
    function getManualRate(address token_) public view returns(bool) {
        return manualRate[token_];
    }

    /**
    * @dev Get price feed address for token.
    */
    function getPriceFeed(address token_) public view returns(TrustedFeedLikeDex) {
        return priceFeed[token_];
    }

    /**
    * @dev Return true if token is allowed to exchange.
    * @param token_ the token_ addres in question
    * @param buy_ if true we ask if user can buy_ the token_ from exchange,
    * otherwise if user can sell to exchange.
    */
    function getAllowedToken(address token_, bool buy_) public view auth returns(bool) {
        if (buy_) {
            return canBuyErc20[token_] || canBuyErc721[token_];
        } else {
            return canSellErc20[token_] || canSellErc721[token_];
        }
    }

    /**
    * @dev Return true if the decimals for token has been set by contract owner.
    */
    function getDecimalsSet(address token_) public view returns(bool) {
        return decimalsSet[token_];
    }

    /**
    * @dev Get the custodian of ERC20 token.
    */
    function getCustodian20(address token_) public view returns(address) {
        return custodian20[token_];
    }


    /**
    * @dev Convert address to bytes32
    */
    function addr(bytes32 b_) public pure returns (address) {
        return address(uint256(b_));
    }

    /**
    * @dev Retrieve the decimals of a token
    */
    function getDecimals(address token_) public view returns (uint8) {
        require(decimalsSet[token_], "dex-token-with-unset-decimals");
        uint dec = 0;
        while(dec <= 77 && decimals[token_] % uint(10) ** dec == 0){
            dec++;
        }
        dec--;
        return uint8(dec);
    }

    /**
    * @dev Get token_ / quote_currency rate from priceFeed
    * Revert transaction if not valid feed and manual value not allowed
    */
    function getRate(address token_) public view auth returns (uint) {
        return _getNewRate(token_);
    }

    /**
    * @dev Get token_ / quote_currency rate from priceFeed
    * Revert transaction if not valid feed and manual value not allowed
    */
    function _getNewRate(address token_) internal view returns (uint rate_) {
        bool feedValid_;
        bytes32 baseRateBytes_;

        require(
            TrustedFeedLikeDex(address(0x0)) != priceFeed[token_],          // require token to have a price feed
            "dex-no-price-feed-for-token");

        (baseRateBytes_, feedValid_) = priceFeed[token_].peek();            // receive DPT/USD price

        if (feedValid_) {                                                   // if feed is valid, load DPT/USD rate from it

            rate_ = uint(baseRateBytes_);

        } else {

            require(manualRate[token_], "dex-feed-provides-invalid-data");  // if feed invalid revert if manualEthRate is NOT allowed

            rate_ = rate[token_];
        }
    }

    /*
    * @dev calculates multiple with decimals adjusted to match to 18 decimal precision to express base
    *      token Value
    */
    function wmulV(uint256 a_, uint256 b_, address token_) public view returns(uint256) {
        return wdiv(wmul(a_, b_), decimals[token_]);
    }

    /*
    * @dev calculates division with decimals adjusted to match to tokens precision
    */
    function wdivT(uint256 a_, uint256 b_, address token_) public view returns(uint256) {
        return wmul(wdiv(a_,b_), decimals[token_]);
    }

    //
    // internal functions
    //

    /*
    * @dev updates locally stored rates of tokens from feeds
    */
    function _updateRates(address sellToken_, address buyToken_) internal {
        if (canSellErc20[sellToken_]) {
            require(decimalsSet[sellToken_], "dex-selltoken-decimals-not-set");
            _updateRate(sellToken_);
        }

        if (canBuyErc20[buyToken_]){
            require(decimalsSet[buyToken_], "dex-buytoken-decimals-not-set");
            _updateRate(buyToken_);
        }

        require(decimalsSet[dpt], "dex-dpt-decimals-not-set");
        _updateRate(dpt);
    }

    /*
    * @dev log the trade event
    */
    function _logTrade(
        address sellToken_,
        uint256 sellT_,
        address buyToken_,
        uint256 buyT_,
        uint256 buyAmtOrId_,
        uint256 feeV_
    ) internal {

        address custodian_ = canBuyErc20[buyToken_] ?
            custodian20[buyToken_] :
            Dpass(buyToken_).getCustodian(buyAmtOrId_);

        txId++;

        emit LogBuyTokenWithFee(
            txId,
            msg.sender,
            custodian_,
            sellToken_,
            sellT_,
            buyToken_,
            buyT_,
            feeV_);
    }

    /**
    * @dev Get exchange rate for a token
    */
    function _updateRate(address token) internal returns (uint256 rate_) {
        require((rate_ = _getNewRate(token)) > 0, "dex-rate-must-be-greater-than-0");
        rate[token] = rate_;
    }

    /**
    * @dev Calculate and send profit and cost
    */
    function _takeFeeInToken(
        uint256 feeV_,                                              // feeV_ that user still owes to CDiamondCoin after paying feeV_ in DPT
        uint256 feeTakenV_,                                         // feeV_ already taken from user in DPT
        address token_,                                             // token_ that must be sent as feeV_
        address src_,                                               // source of token_ sent
        uint256 amountT_                                            // total amount of tokens the user wanted to pay initially
    ) internal {
        uint profitV_;
        uint profitDpt_;
        uint feeT_;
        uint profitPaidV_;
        uint totalProfitV_;

        totalProfitV_ = wmul(add(feeV_, feeTakenV_), profitRate);

        profitPaidV_ = takeProfitOnlyInDpt ?                        // profit value paid already in base currency
            feeTakenV_ :
            wmul(feeTakenV_, profitRate);

        profitV_ = profitPaidV_ < totalProfitV_ ?                   // profit value still to be paid in base currency
            sub(totalProfitV_, profitPaidV_) :
            0;

        profitDpt_ = wdivT(profitV_, rate[dpt], dpt);               // profit in DPT still to be paid

        feeT_ = wdivT(feeV_, rate[token_], token_);                 // convert feeV_ from base currency to token amount

        require(
            feeT_ < amountT_,                                       // require that the cost we pay is less than user intended to pay
            "dex-not-enough-token-to-pay-fee");

        if (token_ == dpt) {
            _sendToken(dpt, src_, burner, profitDpt_);

            _sendToken(dpt, src_, wal, sub(feeT_, profitDpt_));

        } else {

            if (liqBuysDpt) {

                Liquidity(liq).burn(dpt, burner, profitV_);         // if liq contract buys DPT on the fly

            } else {

                _sendToken(dpt, liq, burner, profitDpt_);           // if liq contract stores DPT that can be sent to burner by us
            }

            _sendToken(token_, src_, wal, feeT_);                   // send user token_ to wallet
        }
    }

    /**
    * @dev Take fee in DPT from user if it has any
    * @param feeV_ the fee amount in base currency
    * @return the remaining fee amount in DPT
    */
    function _takeFeeInDptFromUser(
        uint256 feeV_                                               // total feeV_ to be paid
    ) internal returns(uint256 feeTakenV_) {
        TrustedDSToken dpt20_ = TrustedDSToken(dpt);
        uint profitDpt_;
        uint costDpt_;
        uint feeTakenDpt_;

        uint dptUser = min(
            dpt20_.balanceOf(msg.sender),
            dpt20_.allowance(msg.sender, address(this))
        );

        if (dptUser == 0) return 0;

        uint feeDpt = wdivT(feeV_, rate[dpt], dpt);                 // feeV_ in DPT

        uint minDpt = min(feeDpt, dptUser);                         // get the maximum possible feeV_ amount


        if (minDpt > 0) {

            if (takeProfitOnlyInDpt) {                              // only profit is paid in dpt

                profitDpt_ = min(wmul(feeDpt, profitRate), minDpt);

                _sendToken(dpt, msg.sender, burner, profitDpt_);    // only profit is put to the burner

            } else {

                profitDpt_ = wmul(minDpt, profitRate);

                _sendToken(dpt, msg.sender, burner, profitDpt_);    // send profit to burner

                costDpt_ = sub(minDpt, profitDpt_);

                _sendToken(dpt, msg.sender, wal, costDpt_);         // send cost
            }

            feeTakenDpt_ = add(profitDpt_, costDpt_);               // total feeV_ taken in DPT

            feeTakenV_ = wmulV(feeTakenDpt_, rate[dpt], dpt);       // total feeV_ taken in base currency value
        }

    }

    /**
    * &dev send token or ether to destination
    */
    function _sendToken(
        address token_,
        address src_,
        address payable dst_,
        uint256 amount_
    ) internal returns(bool) {

        if (token_ == eth && amount_ > dust) {                          // if token_ is Ether and amount_ is higher than dust limit
            require(src_ == msg.sender || src_ == address(this),
                    "dex-wrong-src-address-provided");
            dst_.transfer(amount_);

            emit LogTransferEth(src_, dst_, amount_);

        } else {

            if (amount_ > 0) {
                if( handledByAsm[token_] && src_ == address(asm)) {     // if token_ is handled by asm (so it is minted and burnt) and we have to mint it
                    asm.mint(token_, dst_, amount_);
                } else {
                    TrustedDSToken(token_).transferFrom(src_, dst_, amount_);           // transfer all of token_ to dst_
                }
            }
        }
        return true;
    }
}
