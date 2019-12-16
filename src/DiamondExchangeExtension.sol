pragma solidity ^0.5.11;

import "./DiamondExchange.sol";
import "dpass/Dpass.sol";
import "ds-auth/auth.sol";
import "./Redeemer.sol";

contract TrustedAsmExt {
    function getAmtForSale(address token) external view returns(uint256);
}

/**
* @dev Contract to calculate user fee based on amount
*/
contract TrustedFeeCalculatorExt {

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

contract DiamondExchangeExtension is DSAuth {

    uint public dust = 1000;
    bytes32 public name = "Dee";                          // set human readable name for contract
    TrustedAsmExt public asm;
    DiamondExchange public dex;
    Redeemer public red;
    TrustedFeeCalculatorExt public fca;

    uint private buyV;
    uint private dptBalance;
    uint private feeDptV;
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

    function setConfig(bytes32 what_, bytes32 value_, bytes32 value1_) public auth {
        if (what_ == "asm") {

            require(addr(value_) != address(0x0), "dee-wrong-address");

            asm = TrustedAsmExt(addr(value_));

        } else if (what_ == "dex") {

            require(addr(value_) != address(0x0), "dee-wrong-address");

            dex = DiamondExchange(address(uint160(addr(value_))));

        } else if (what_ == "red") {

            require(addr(value_) != address(0x0), "dee-wrong-address");

            red = Redeemer(address(uint160(addr(value_))));

        } else if (what_ == "dust") {

            dust = uint256(value_);

        } else {
            value1_; // disable warning of unused variable
            require(false, "dee-no-such-option");
        }
    }

    /**
    * @dev Convert address to bytes32
    */
    function addr(bytes32 b_) public pure returns (address) {
        return address(uint256(b_));
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
        require(dex.canBuyErc721(token_) || dex.canSellErc721(token_), "dee-token-not-a-dpass-token");
        (ownerCustodian_, attrs_, carat_) = Dpass(token_).getDiamondInfo(tokenId_);
        priceV_ = dex.getPrice(token_, tokenId_);
    }

    /*
    * @dev Returns true if seller accepts token as payment
    */
    function sellerAcceptsToken(address token_, address seller_)
    public view returns (bool) {

        return (dex.canSellErc20(token_) ||
                dex.canSellErc721(token_)) &&
                !dex.denyToken(token_, seller_);
    }

    /**
    * @dev calculates how much of a certain token user must spend in order to buy certain amount of token with fees.
    * @param user_ address this is the address that will initiate buy transaction
    * @param sellToken_ address token user wants to pay with 
    * @param sellId_ uint256 if sellToken_ is dpass then this is the tokenId otherwise ignored
    * @param buyToken_ address token user wants to buy
    * @param buyAmtOrId_ uint256 amount or id of buyToken_
    * @return the sellAmount or if sellToken is dpass 1 if sell can be made and 0 if not, and the amount of additional dpt fee,
    */
    function getCosts(
        address user_,                                                           // user for whom we want to check the costs for
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
        uint feeDptV_;

        if(fca == TrustedFeeCalculatorExt(0)) {

            require(user_ != address(0),
                "dee-user_-address-zero");

            require(
                dex.canSellErc20(sellToken_) ||
                dex.canSellErc721(sellToken_),
                "dee-selltoken-invalid");

            require(
                dex.canBuyErc20(buyToken_) ||
                dex.canBuyErc721(buyToken_),
                "dee-buytoken-invalid");

            require(
                !(dex.canBuyErc721(buyToken_) &&
                dex.canSellErc721(sellToken_)),
                "dee-both-tokens-dpass");

            require(dex.dpt() != address(0), "dee-dpt-address-zero");

            if(dex.canBuyErc20(buyToken_)) {

                buyV_ = _getBuyV(buyToken_, buyAmtOrId_);

            } else {

                buyV_ = dex.getPrice(buyToken_, buyAmtOrId_);
            }

            feeV_ = add(
                wmul(buyV_, dex.varFee()),
                dex.fixFee());

            feeDpt_ = wmul(
                dex.wdivT(
                    feeV_,
                    dex.getRate(dex.dpt()),
                    dex.dpt()),
                dex.takeProfitOnlyInDpt() ? dex.profitRate() : 1 ether);

            sellAmtOrId_ = min(
                DSToken(dex.dpt()).balanceOf(user_), 
                DSToken(dex.dpt()).allowance(user_, address(dex)));

            if(dex.canSellErc20(sellToken_)) {

                if(sellAmtOrId_ <= add(feeDpt_, dust)) {

                    feeDptV_ = dex.wmulV(
                        sellAmtOrId_,
                        dex.getRate(dex.dpt()),
                        dex.dpt());

                    feeDpt_ = sellAmtOrId_;

                } else {

                    feeDptV_ = dex.wmulV(feeDpt_, dex.getRate(dex.dpt()), dex.dpt());

                    feeDpt_ = feeDpt_;

                }

                feeSellT_ = dex.wdivT(sub(feeV_, min(feeV_, feeDptV_)), dex.getRate(sellToken_), sellToken_);

                sellAmtOrId_ = add(
                    dex.wdivT(
                        buyV_,
                        dex.getRate(sellToken_),
                        sellToken_),
                    feeSellT_);

            } else {

                sellAmtOrId_ = add(buyV_, dust) >= dex.getPrice(sellToken_, sellId_) ? 1 : 0;
                feeDpt_ = min(feeDpt_, Dpass(dex.dpt()).balanceOf(user_));
            }

        } else {
            return fca.getCosts(user_, sellToken_, sellId_, buyToken_, buyAmtOrId_);
        }
    }

    // TODO: test
    function getRedeemCosts(
        address redeemToken_,
        uint256 redeemAmtOrId_,
        address feeToken_
    ) public view returns(uint) {
        return red.getRedeemCosts(redeemToken_, redeemAmtOrId_, feeToken_);
    }

    function _getBuyV(address buyToken_, uint256 buyAmtOrId_) internal view returns (uint buyV_) {
        uint buyT_;

        buyT_ = dex.handledByAsm(buyToken_) ?                       // set buy amount to max possible
            asm.getAmtForSale(buyToken_) :                          // if managed by asset management get available
            min(                                                    // if not managed by asset management get buyV_ available
                DSToken(buyToken_).balanceOf(
                    dex.custodian20(buyToken_)),
                DSToken(buyToken_).allowance(
                    dex.custodian20(buyToken_), address(dex)));

        buyT_ = min(buyT_, buyAmtOrId_);

        buyV_ = dex.wmulV(buyT_, dex.getRate(buyToken_), buyToken_);
    }
}
