pragma solidity ^0.5.11;

import "ds-math/math.sol";
import "ds-auth/auth.sol";
import "ds-token/token.sol";
import "ds-stop/stop.sol";
import "ds-note/note.sol";
import "./AssetManagement.sol";
import "./AssetManagementCore.sol";
import "./DiamondExchange.sol";
import "dpass/Dpass.sol";
import "./Liquidity.sol";

contract Redeemer is DSAuth, DSStop, DSMath {
    // TODO: remove all following LogTest()
    event LogTest(uint256 what);
    event LogTest(bool what);
    event LogTest(address what);
    event LogTest(bytes32 what);

    event LogRedeem(uint256 redeemId, address sender, address redeemToken_,uint256 redeemAmtOrId_, address feeToken_, uint256 feeAmt_, address payable custodian);
    address public eth = address(0xee);
    event LogTransferEth(address src, address dst, uint256 amount);

    mapping(address => address) public dcdc;                // dcdc[cdc] returns the dcdc token associated (having the same values) as cdc token
    uint256 public fixFee;                                  // Fixed part of fee charged by Cdiamondcoin from redeemToken_ in base currency
    uint256 public varFee;                                  // Variable part of fee charged by Cdiamondcoin from redeemToken_
    address public dpt;                                     // dpt token address
    AssetManagement public asm;                       // asset management contract
    AssetManagementCore public asc;                   // asset management contract
    DiamondExchange public dex;
    address payable public liq;                             // liquidity providing contract address
    bool public liqBuysDpt;                                 // true if liquidity contract buys dpt on the fly, false otherwise
    address payable public burner;                          // burner contract to take dpt owners' profit
    address payable public wal;                             // wallet to receive the operational costs
    uint public profitRate;                                 // profit that is sent from fees to dpt owners
    bool locked;                                            // variable to avoid reentrancy attacks against this contract
    uint redeemId;                                          // id of the redeem transaction user can refer to
    uint dust = 1000;                                       // dust value to handle round-off errors

    modifier nonReentrant {
        require(!locked, "dex-reentrancy-detected");
        locked = true;
        _;
        locked = false;
    }

    function () external payable {
    }

    function setConfig(bytes32 what_, bytes32 value_, bytes32 value1_, bytes32 value2_) public nonReentrant auth {
        if (what_ == "asm") {

            require(addr(value_) != address(0x0), "red-zero-asm-address");

            asm = AssetManagement(address(uint160(addr(value_))));

        } else if (what_ == "asc") {

            require(addr(value_) != address(0x0), "red-zero-asc-address");

            asc = AssetManagementCore(address(uint160(addr(value_))));

        } else if (what_ == "dex") {

            require(addr(value_) != address(0x0), "red-zero-dex-address");

            dex = DiamondExchange(address(uint160(addr(value_))));

        } else if (what_ == "burner") {

            require(addr(value_) != address(0x0), "red-wrong-address");

            burner = address(uint160(addr(value_)));

        } else if (what_ == "wal") {

            require(addr(value_) != address(0x0), "red-wrong-address");

            wal = address(uint160(addr(value_)));

        } else if (what_ == "fixFee") {

            fixFee = uint256(value_);

        } else if (what_ == "varFee") {

            varFee = uint256(value_);
            require(varFee <= 1 ether, "red-var-fee-too-high");

        } else if (what_ == "profitRate") {

            profitRate = uint256(value_);

            require(profitRate <= 1 ether, "red-profit-rate-out-of-range");

        }  else if (what_ == "dcdcOfCdc") {

            require(address(asm) != address(0), "red-setup-asm-first");

            address cdc_ = addr(value_);
            address dcdc_ = addr(value1_);

            require(asc.cdcs(cdc_), "red-setup-cdc-in-asm-first");
            require(asc.dcdcs(dcdc_), "red-setup-dcdc-in-asm-first");

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

        } else if (what_ == "dust") {
            dust = uint256(value_);
            require(dust <= 1 ether, "red-pls-decrease-dust");
        } else {
            require(false, "red-invalid-option");
        }

    }

    /*
    * @dev Convert address to bytes32
    */
    function addr(bytes32 b_) public pure returns (address) {
        return address(uint256(b_));
    }
    // TODO: test
    function redeem(
        address sender,
        address redeemToken_,
        uint256 redeemAmtOrId_,
        address feeToken_,
        uint256 feeAmt_,
        address payable custodian_
    ) public payable stoppable nonReentrant returns (uint256) {

        require(feeToken_ != eth || feeAmt_ == msg.value, "red-pls-send-eth");

        if( asc.dpasses(redeemToken_) ) {

            Dpass(redeemToken_).redeem(redeemAmtOrId_);
            require(custodian_ == address(uint160(Dpass(redeemToken_).getCustodian(redeemAmtOrId_))), "red-wrong-custodian-provided");

        } else if ( asc.cdcs(redeemToken_) ) {

            require(
                DSToken(dcdc[redeemToken_])
                    .balanceOf(custodian_) >
                redeemAmtOrId_,
                "red-custodian-has-not-enough-cdc");

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

    function _sendFeeToCdiamondCoin(address redeemToken_, uint256 redeemAmtOrId_, address feeToken_, uint256 feeAmt_) internal returns (uint feeToCustodianT_){
        uint profitV_;
        uint redeemTokenV_;

        if(asc.dpasses(redeemToken_)) {
            redeemTokenV_ = asc.basePrice(redeemToken_, redeemAmtOrId_);
        } else {
            redeemTokenV_ = dex.wmulV(
                redeemAmtOrId_,
                dex.getLocalRate(redeemToken_),
                redeemToken_);
        }

        uint feeT_ = add(
            dex.wdivT(
                fixFee,
                dex.getLocalRate(feeToken_),
                feeToken_),
            dex.wdivT(
                wmul(
                    varFee, 
                    redeemTokenV_),
                dex.getLocalRate(feeToken_),
                feeToken_));

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
    * @dev send token or ether to destination
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
