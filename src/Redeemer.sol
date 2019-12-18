pragma solidity ^0.5.11;

import "ds-math/math.sol";
import "ds-auth/auth.sol";
import "ds-token/token.sol";
import "ds-stop/stop.sol";
import "ds-note/note.sol";
import "./SimpleAssetManagement.sol";
import "./DiamondExchange.sol";
import "dpass/Dpass.sol";
import "./Liquidity.sol";

contract Redeemer is DSAuth, DSStop, DSMath {
    event LogRedeem(uint256 redeemId, address sender, address redeemToken_,uint256 redeemAmtOrId_, address feeToken_, uint256 feeAmt_, address payable custodian);
    address public eth = address(0xee);
    event LogTransferEth(address src, address dst, uint256 amount);
    event LogConfigChange(bytes32 what, bytes32 value, bytes32 value1, bytes32 value2);
    mapping(address => address) public dcdc;                 // dcdc[cdc] returns the dcdc token associated (having the same values) as cdc token
    uint256 public fixFee;                                  // Fixed part of fee charged by Cdiamondcoin from redeemToken_ in base currency
    uint256 public varFee;                                  // Variable part of fee charged by Cdiamondcoin from redeemToken_
    address public dpt;                                     // dpt token address
    SimpleAssetManagement public asm;                       // asset management contract
    DiamondExchange public dex;
    address payable public liq;                             // liquidity providing contract address
    bool public liqBuysDpt;                                 // true if liquidity contract buys dpt on the fly, false otherwise
    address payable public burner;                          // burner contract to take dpt owners' profit
    address payable wal;                                    // wallet to receive the operational costs
    uint public profitRate;                                 // profit that is sent from fees to dpt owners
    bool locked;                                            // variable to avoid reentrancy attacks against this contract
    uint redeemId;                                          // id of the redeem transaction user can refer to
    uint dust = 1000;                                       // dust value to handle round-off errors

    bytes32 public name = "Red";                            // set human readable name for contract
    bytes32 public symbol = "Red";                          // set human readable name for contract
    bool kycEnabled;                                        // if true then user must be on the kyc list in order to use the system
    mapping(address => bool) public kyc;                    // kyc list of users that are allowed to exchange tokens

    modifier nonReentrant {
        require(!locked, "red-reentrancy-detected");
        locked = true;
        _;
        locked = false;
    }

    modifier kycCheck(address sender) {
        require(!kycEnabled || kyc[sender], "red-you-are-not-on-kyc-list");
        _;
    }

    function () external payable {
    }

    function setConfig(bytes32 what_, bytes32 value_, bytes32 value1_, bytes32 value2_) public nonReentrant auth {
        if (what_ == "asm") {

            require(addr(value_) != address(0x0), "red-zero-asm-address");

            asm = SimpleAssetManagement(address(uint160(addr(value_))));

        } else if (what_ == "fixFee") {

            fixFee = uint256(value_);

        } else if (what_ == "varFee") {

            varFee = uint256(value_);
            require(varFee <= 1 ether, "red-var-fee-too-high");

        } else if (what_ == "kyc") {

            address user_ = addr(value_);

            require(user_ != address(0x0), "red-wrong-address");

            kyc[user_] = uint(value1_) > 0;
        } else if (what_ == "dex") {

            require(addr(value_) != address(0x0), "red-zero-red-address");

            dex = DiamondExchange(address(uint160(addr(value_))));

        } else if (what_ == "burner") {

            require(addr(value_) != address(0x0), "red-wrong-address");

            burner = address(uint160(addr(value_)));

        } else if (what_ == "wal") {

            require(addr(value_) != address(0x0), "red-wrong-address");

            wal = address(uint160(addr(value_)));

        } else if (what_ == "profitRate") {

            profitRate = uint256(value_);

            require(profitRate <= 1 ether, "red-profit-rate-out-of-range");

        } else if (what_ == "dcdcOfCdc") {

            require(address(asm) != address(0), "red-setup-asm-first");

            address cdc_ = addr(value_);
            address dcdc_ = addr(value1_);

            require(asm.cdcs(cdc_), "red-setup-cdc-in-asm-first");
            require(asm.dcdcs(dcdc_), "red-setup-dcdc-in-asm-first");

            dcdc[cdc_] = dcdc_;
        } else if (what_ == "dpt") {

            dpt = addr(value_);

            require(dpt != address(0x0), "red-wrong-address");

        } else if (what_ == "liqBuysDpt") {

            require(liq != address(0x0), "red-wrong-address");

            Liquidity(address(uint160(liq))).burn(dpt, address(uint160(burner)), 0);                // check if liq does have the proper burn function

            liqBuysDpt = uint256(value_) > 0;

        } else if (what_ == "liq") {

            liq = address(uint160(addr(value_)));

            require(liq != address(0x0), "red-wrong-address");

            require(dpt != address(0), "red-add-dpt-token-first");

            require(
                TrustedDSToken(dpt).balanceOf(liq) > 0,
                "red-insufficient-funds-of-dpt");

            if(liqBuysDpt) {

                Liquidity(liq).burn(dpt, burner, 0);            // check if liq does have the proper burn function
            }

        } else if (what_ == "kycEnabled") {

            kycEnabled = uint(value_) > 0;

        } else if (what_ == "dust") {
            dust = uint256(value_);
            require(dust <= 1 ether, "red-pls-decrease-dust");
        } else {
            require(false, "red-invalid-option");
        }
        emit LogConfigChange(what_, value_, value1_, value2_);
    }

    /*
    * @dev Convert address to bytes32
    */
    function addr(bytes32 b_) public pure returns (address) {
        return address(uint256(b_));
    }

    /*
    * @dev Pay redeem costs and redeem for diamond. Using this funcitn is non-reversible.
    * @param sender_ address ethereum account of user who wants to redeem
    * @param redeemToken_ address token address that user wants to redeem token can be both 
    * dpass and cdc tokens
    * @param redeemAmtOrId_ uint256 if token is cdc then represents amount, and if dpass then id of diamond
    * @param feeToken_ address token to pay fee with. This token can only be erc20.
    * @param feeAmt_ uint256 amount of token to be paid as redeem fee.
    * @param custodian_ address custodian to get diamond from. If token is dpass, then custodian must match 
    * the custodian of dpass token id, if cdc then any custodian can be who has enough matching dcdc tokens.
    */
    function redeem(
        address sender,
        address redeemToken_,
        uint256 redeemAmtOrId_,
        address feeToken_,
        uint256 feeAmt_,
        address payable custodian_
    ) public payable stoppable nonReentrant kycCheck(sender) returns (uint256) {

        require(feeToken_ != eth || feeAmt_ == msg.value, "red-eth-not-equal-feeamt");
        if( asm.dpasses(redeemToken_) ) {

            Dpass(redeemToken_).redeem(redeemAmtOrId_);
            require(custodian_ == address(uint160(Dpass(redeemToken_).getCustodian(redeemAmtOrId_))), "red-wrong-custodian-provided");

        } else if ( asm.cdcs(redeemToken_) ) {

            require(
                DSToken(dcdc[redeemToken_])
                    .balanceOf(custodian_) >
                redeemAmtOrId_,
                "red-custodian-has-not-enough-cdc");

            require(redeemAmtOrId_ % 10 ** DSToken(redeemToken_).decimals() == 0, "red-cdc-integer-value-pls");

            DSToken(redeemToken_).transfer(address(asm), redeemAmtOrId_);     // cdc token sent to asm to be burned

            asm.notifyTransferFrom(                         // burn cdc token at asm
                redeemToken_,
                address(this),
                address(asm),
                redeemAmtOrId_);

        } else {
            require(false, "red-token-nor-cdc-nor-dpass");
        }

        uint feeToCustodian_ = _sendFeeToCdiamondCoin(redeemToken_, redeemAmtOrId_, feeToken_, feeAmt_);

        _sendToken(feeToken_, address(this), custodian_, feeToCustodian_);

        emit LogRedeem(++redeemId, sender, redeemToken_, redeemAmtOrId_, feeToken_, feeAmt_, custodian_);

        return redeemId;
    }

    /**
    * @dev Put user on whitelist to redeem diamonds.
    * @param user_ address the ethereum account to enable
    * @param enable_ bool if true enables, otherwise disables user to use redeem
    */
    function setKyc(address user_, bool enable_) public auth {
        setConfig(
            "kyc",
            bytes32(uint(user_)), 
            enable_ ? bytes32(uint(1)) : bytes32(uint(0)),
            "");
    }

    /**
    * @dev send token or ether to destination
    */
    function _sendFeeToCdiamondCoin(
        address redeemToken_,
        uint256 redeemAmtOrId_,
        address feeToken_,
        uint256 feeAmt_
    ) internal returns (uint feeToCustodianT_){

        uint profitV_;
        uint redeemTokenV_ = _calcRedeemTokenV(redeemToken_, redeemAmtOrId_);

        uint feeT_ = _getFeeT(feeToken_, redeemTokenV_);

        uint profitT_ = wmul(profitRate, feeT_);

        if( feeToken_ == dpt) {

            DSToken(feeToken_).transfer(burner, profitT_);
            DSToken(feeToken_).transfer(wal, sub(feeT_, profitT_));

        } else {

            profitV_ = dex.wmulV(profitT_, dex.getLocalRate(feeToken_), feeToken_);

            if(liqBuysDpt) {
                Liquidity(liq).burn(dpt, burner, profitV_);
            } else {
                DSToken(dpt).transferFrom(
                    liq,
                    burner,
                    dex.wdivT(profitV_, dex.getLocalRate(dpt), dpt));
            }
            _sendToken(feeToken_, address(this), wal, feeT_);
        }

        require(add(feeAmt_,dust) >= feeT_, "red-not-enough-fee-sent");
        feeToCustodianT_ = sub(feeAmt_, feeT_);
    }

    /**
    * @dev Calculate costs for redeem. These are only concerning the fees the system charges.
    * Delivery costs charged by custodians are additional to these and must be added to the i
    * cost returned here.
    * @param redeemToken_ address token that will be redeemed. Cdc or dpass token address required.
    * @param redeemAmtOrId_ uint256 amount of token to be redeemed
    * @param feeToken_ address token that will be used to pay fee.
    * @return amount of fee token that must be sent as fee to system. Above this value users must 
    * add the handling fee of custodians to have a successfull redeem.
    */
    function getRedeemCosts(address redeemToken_, uint256 redeemAmtOrId_, address feeToken_) public view returns(uint feeT_) {
            require(asm.dpasses(redeemToken_) || redeemAmtOrId_ % 10 ** DSToken(redeemToken_).decimals() == 0, "red-cdc-integer-value-pls");
        uint redeemTokenV_ = _calcRedeemTokenV(redeemToken_, redeemAmtOrId_);
        feeT_ = _getFeeT(feeToken_, redeemTokenV_);
    }

    /**
    * @dev Calculdate the base currency value of redeem token if it is an erc20 or if it is an erc721 token.
    */
    function _calcRedeemTokenV(address redeemToken_, uint256 redeemAmtOrId_) internal view returns(uint redeemTokenV_) {
        if(asm.dpasses(redeemToken_)) {
            redeemTokenV_ = asm.basePrice(redeemToken_, redeemAmtOrId_);
        } else {
            redeemTokenV_ = dex.wmulV(
                redeemAmtOrId_,
                dex.getLocalRate(redeemToken_),
                redeemToken_);
        }
    }

    /**
    * @dev Calculate  amount of feeTokens to be paid as fee.
    */
    function _getFeeT(address feeToken_, uint256 redeemTokenV_) internal view returns (uint) {
        return 
            dex.wdivT(
                add(
                    wmul(
                        varFee,
                        redeemTokenV_),
                    fixFee),
                dex.getLocalRate(feeToken_),
                feeToken_);
    }

    /**
    * @dev send token or ether to destination.
    */
    function _sendToken(
        address token,
        address src,
        address payable dst,
        uint256 amount
    ) internal returns (bool){
        if (token == eth && amount > 0) {
            require(src == address(this), "wal-ether-transfer-invalid-src");
            dst.transfer(amount);
            emit LogTransferEth(src, dst, amount);
        } else {
            if (amount > 0) DSToken(token).transferFrom(src, dst, amount);   // transfer all of token to dst
        }
        return true;
    }
}
