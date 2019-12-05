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
    // TODO: remove all following LogTest()
    event LogTest(uint256 what);
    event LogTest(bool what);
    event LogTest(address what);
    event LogTest(bytes32 what);

    event LogTransferEth(address src, address dst, uint256 amount);
    address public eth = address(0xee);
    
    mapping(address => address) public dcdc;                 // dcdc[cdc] returns the dcdc token associated (having the same values) as cdc token 
    uint256 public fixFee;                                  // Fixed part of fee charged by Cdiamondcoin from redeemToken_ in base currency
    uint256 public varFee;                                  // Variable part of fee charged by Cdiamondcoin from redeemToken_
    address public cdcCustodian;                            // custodian to redeem real cdc diamond
    address public dpt;                                     // dpt token address
    SimpleAssetManagement public asm;                       // asset management contract
    DiamondExchange public dex;
    address payable public liq;                                     // liquidity providing contract address
    bool public liqBuysDpt;                              // true if liquidity contract buys dpt on the fly, false otherwise
    address payable public burner;                                  // burner contract to take dpt owners' profit
    address payable wal;                                    // wallet to receive the operational costs
    uint public profitRate;                                 // profit that is sent from fees to dpt owners
    bool locked;                                            // variable to avoid reentrancy attacks against this contract

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

            asm = SimpleAssetManagement(address(uint160(addr(value_))));

        } else if (what_ == "dex") {

            require(addr(value_) != address(0x0), "red-zero-red-address");

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

            require(asm.cdcs(cdc_), "red-setup-cdc-in-asm-first");
            require(asm.dcdcs(dcdc_), "red-setup-dcdc-in-asm-first");

            dcdc[cdc_] = dcdc_;
        } else if (what_ == "cdcCustodian") {

            require(address(asm) != address(0), "red-setup-asm-first");
            
            cdcCustodian = addr(value_); 
            
            require(asm.custodians(cdcCustodian), "red-custodian-not-in-asm");
        } else if (what_ == "dpt") {

            require(addr(value_) != address(0x0), "red-wrong-address");

            dpt = addr(value_);

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

    function redeem(
        address sender,
        address redeemToken_,
        uint256 redeemAmtOrId_,
        address feeToken_,
        uint256 feeAmt_
    ) public payable stoppable nonReentrant returns (uint256 redeemId) {
        address custodian_;
        if( asm.dpasses(redeemToken_) ) {
            
            Dpass(redeemToken_).redeem(redeemAmtOrId_);
            custodian_ = Dpass(redeemToken_).getCustodian(redeemAmtOrId_);
        
        } else if ( asm.cdcs(redeemToken_) ) {
            
            require(
                DSToken(dcdc[redeemToken_])
                    .balanceOf(cdcCustodian) >
                redeemAmtOrId_,
                "red-custodian-has-not-enough-cdc");

            DSToken(redeemToken_).transfer(address(asm), redeemAmtOrId_);     // cdc token sent to asm to be burned

            asm.notifyTransferFrom(                         // burn cdc token at asm
                redeemToken_,
                address(this),
                address(asm),
                redeemAmtOrId_);

            custodian_ = cdcCustodian;
        } else {
            require(false, "red-token-nor-cdc-nor-dpass");
        }

        uint feeToCustodian_ = _sendFeeToCdiamondCoin(feeToken_, feeAmt_);

        DSToken(feeToken_).transfer(custodian_, feeToCustodian_);
    }
    
    function _sendFeeToCdiamondCoin(address feeToken_, uint256 feeAmt_) internal returns (uint feeToCustodianT_){
        uint dptRate;
        uint profitV_;
        uint profitDpt_;

        uint feeT_ = add(
            dex.wdivT(
                fixFee,
                dex.getLocalRate(feeToken_),
                feeToken_), 
            wmul(varFee, feeAmt_));
        uint profitT_ = wmul(profitRate, feeT_);
        uint costT_ = sub(feeT_, profitT_);

        if( feeToken_ == dpt) {
            
            DSToken(feeToken_).transfer( burner, profitT_);
            DSToken(feeToken_).transfer( wal, costT_);

        } else {
            dptRate = dex.getRate(dpt);
            profitV_ = dex.wmulV(profitT_, dex.getLocalRate(feeToken_), feeToken_);
            profitDpt_ = dex.wdivT(profitV_, dex.getLocalRate(dpt), dpt);

            DSToken(dpt).transferFrom(liq, burner, profitDpt_);
            DSToken(feeToCustodianT_).transfer(wal, feeT_);
        }

        feeToCustodianT_ = sub(feeAmt_, feeT_);
    }
}
