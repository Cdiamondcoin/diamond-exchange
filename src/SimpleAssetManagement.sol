pragma solidity ^0.5.11;

import "ds-math/math.sol";
import "ds-auth/auth.sol";
import "ds-token/token.sol";
import "ds-stop/stop.sol";
import "ds-note/note.sol";
import "dpass/Dpass.sol";
import "./Wallet.sol";


/**
* @dev Contract to get ETH/USD price
*/
contract TrustedFeedLike {
    function peek() external view returns (bytes32, bool);
}


contract SimpleAssetManagement is DSAuth, DSStop, DSMath {
    event LogConfigChange(address sender, bytes32 what, bytes32 value, bytes32 value1);
    event LogTransferEth(address src, address dst, uint256 amount);
    event LogBasePrice(address token_, uint256 tokenId_);
    event LogCdcValue(uint256 totalCdcV, bytes32 domain, uint256 cdcValue, address token);
    event LogDcdcValue(uint256 totalDcdcV, bytes32 domain, uint256 ddcValue, address token);
    event LogDcdcCustodianValue(uint256 totalDcdcCustV, uint256 dcdcCustV, address dcdc, address custodian);
    event LogDcdcTotalCustodianValue(uint256 totalDcdcCustV, uint256 totalDcdcV, address custodian, bytes32 domain);
    event LogDpassValue(uint256 totalDpassCustV, uint256 totalDpassV, address custodian, bytes32 domain);
    event LogForceUpdateCollateralDpass(address sender, uint256 positiveV_, uint256 negativeV_, address custodian);
    event LogForceUpdateCollateralDcdc(address sender, uint256 positiveV_, uint256 negativeV_, address custodian);

    // Commented due fit to code size limit 24,576 bytes
    mapping(
        address => mapping(
            uint => uint)) private basePrice;               // the base price used for collateral valuation
    mapping(address => bool) custodians;                    // returns true for custodians
    mapping(address => uint)                                // total base currency value of custodians collaterals
        public totalDpassCustV;
    mapping(address => uint) private rate;                  // current rate of a token in base currency
    mapping(address => uint) private cdcValues;             // base currency value of cdc token
    mapping(address => uint) private dcdcValues;            // base currency value of dcdc token
    mapping(address => uint) private totalDcdcCustV;        // total value of all dcdcs at custodian
    mapping(
        address => mapping(
            address => uint)) private dcdcCustV;            // dcdcCustV[dcdc][custodian] value of dcdc at custodian
    mapping(address => bool) private payTokens;             // returns true for tokens allowed to make payment to custodians with
    mapping(address => bool) private dpasses;               // returns true for dpass tokens allowed in this contract
    mapping(address => bool) private dcdcs;                 // returns true for tokens representing cdc assets (without gia number) that are allowed in this contract
    mapping(address => bool) private cdcs;                  // returns true for cdc tokens allowed in this contract
    mapping(address => uint) private decimals;              // stores decimals for each ERC20 token
    mapping(address => bool) private decimalsSet;           // stores decimals for each ERC20 token
    mapping(address => address) private priceFeed;          // price feed address for token
    mapping(address => uint) private tokenPurchaseRate;     // the average purchase rate of a token. This is the ...
                                                            // ... price of token at which we send it to custodian
    mapping(address => uint) private totalPaidV;            // total amount that has been paid to custodian for dpasses and cdc in base currency
    mapping(address => uint) private totalDpassSoldV;       // totoal amount of all dpass tokens that have been sold by custodian
    mapping(address => bool) public manualRate;             // if manual rate is enabled then owner can update rates if feed not available
    mapping(address => bytes32) public domains;             // the domain that connects the set of cdc, dpass, and dcdc tokens, and custodians
    mapping(bytes32 => uint) private totalDpassV;           // total value of dpass collaterals in base currency
    mapping(bytes32 => uint) private totalDcdcV;            // total value of dcdc collaterals in base currency
    mapping(bytes32 => uint) private totalCdcV;             // total value of cdc tokens issued in base currency
    mapping(bytes32 => uint) private overCollRatio;         // the totalDpassV >= overCollRatio * totalCdcV
    uint public dust = 1000;                                // dust value is the largest value we still consider 0 ...
    bool private locked;                                    // variable prevents to exploit by recursively calling funcions
    address public eth = address(0xee);                     // we treat eth as DSToken() wherever we can, and this is the dummy address for eth
    /**
     * @dev Modifier making sure the function can not be called in a recursive way in one transaction.
     */
    modifier nonReentrant {
        require(!locked, "asm-reentrancy-detected");
        locked = true;
        _;
        locked = false;
    }

    /**
    * @dev Set configuration variables of asset managment contract.
    * @param what_ bytes32 tells to function what to set.
    * @param value_ bytes32 setter variable. Its meaning is dependent on what_.
    * @param value1_ bytes32 setter variable. Its meaning is dependent on what_.
    * @param value2_ bytes32 setter variable. Its meaning is dependent on what_. In most cases it stands for domain.
    *
    */
    function setConfig(bytes32 what_, bytes32 value_, bytes32 value1_, bytes32 value2_) public nonReentrant auth {
        if (what_ == "rate") {
            address token = addr(value_);
            uint256 value = uint256(value1_);
            require(payTokens[token] || cdcs[token] || dcdcs[token], "asm-token-not-allowed-rate");
            require(value > 0, "asm-rate-must-be-gt-0");
            rate[token] = value;
        } else if (what_ == "custodians") {
            bytes32 domain = value2_;
            address custodian = addr(value_);
            bool enable = uint(value1_) > 0;
            if(enable) domains[custodian] = domain;
            require(custodian != address(0), "asm-custodian-zero-address");
            custodians[addr(value_)] = enable;
        } else if (what_ == "overCollRatio") {
            bytes32 domain = value2_;
            overCollRatio[domain] = uint(value_);
            require(overCollRatio[domain] >= 1 ether, "asm-system-must-be-overcollaterized");
            _requireSystemCollaterized(domain);
        } else if (what_ == "priceFeed") {
            require(addr(value1_) != address(address(0x0)), "asm-wrong-pricefeed-address");
            require(addr(value_) != address(address(0x0)), "asm-wrong-token-address");
            priceFeed[addr(value_)] = addr(value1_);
        } else if (what_ == "decimals") {
            address token = addr(value_);
            uint decimal = uint256(value1_);
            require(token != address(0x0), "asm-wrong-address");
            decimals[token] = 10 ** decimal;
            decimalsSet[token] = true;
        } else if (what_ == "manualRate") {
            address token = addr(value_);
            bool enable = uint(value1_) > 0;
            require(token != address(address(0x0)), "asm-wrong-token-address");
            require(priceFeed[token] != address(address(0x0)), "asm-priceFeed-first");
            manualRate[token] = enable;
        } else if (what_ == "payTokens") {
            address token = addr(value_);
            require(token != address(0), "asm-pay-token-address-no-zero");
            payTokens[token] = uint(value1_) > 0;
        } else if (what_ == "dcdcs") {
            bytes32 domain = value2_;
            address newDcdc = addr(value_);
            bool enable = uint(value1_) > 0;
            if(enable) domains[newDcdc] = domain;
            require(newDcdc != address(0), "asm-dcdc-address-zero");
            require(priceFeed[newDcdc] != address(0), "asm-add-pricefeed-first");
            require(decimalsSet[newDcdc],"asm-no-decimals-set-for-token");
            dcdcs[newDcdc] = enable;
            _updateTotalDcdcValue(newDcdc);
        } else if (what_ == "cdcs") {
            bytes32 domain = value2_;
            address newCdc = addr(value_);
            bool enable = uint(value1_) > 0;
            if(enable) domains[newCdc] = domain;
            require(priceFeed[newCdc] != address(0), "asm-add-pricefeed-first");
            require(decimalsSet[newCdc], "asm-add-decimals-first");
            require(newCdc != address(0), "asm-cdc-address-zero");
            cdcs[newCdc] = enable;
            _updateCdcValue(newCdc);
        } else if (what_ == "dpasses") {
            bytes32 domain = value2_;
            address dpass = addr(value_);
            bool enable = uint(value1_) > 0;
            if(enable) domains[dpass] = domain;
            require(dpass != address(0), "asm-dpass-address-zero");
            dpasses[dpass] = enable;
        } else if (what_ == "approve") {
            address token = addr(value_);
            address dst = addr(value1_);
            uint value = uint(value2_);
            require(decimalsSet[token],"asm-no-decimals-set-for-token");
            require(dst != address(0), "asm-dst-zero-address");
            DSToken(token).approve(dst, value);
        }  else if (what_ == "setApproveForAll") {
            address token = addr(value_);
            address dst = addr(value1_);
            bool enable = uint(value2_) > 0;
            require(dpasses[token],"asm-not-a-dpass-token");
            require(dst != address(0), "asm-dst-zero-address");
            Dpass(token).setApprovalForAll(dst, enable);
        } else if (what_ == "dust") {
            dust = uint256(value_);
        } else {
            require(false, "asm-wrong-config-option");
        }

        emit LogConfigChange(msg.sender, what_, value_, value1_);
    }

    /**
     * @dev Returns true if custodian is a valid custodian.
     */
    function isCustodian(address custodian_) public view returns(bool) {
        return custodians[custodian_];
    }

    /**
     * @dev Return the total value of all dpass tokens at custodians.
     */
    function getTotalDpassCustV(address custodian_) public view returns(uint256) {
        require(custodians[custodian_], "asm-not-a-custodian");
        return totalDpassCustV[custodian_];
    }

    /**
     * @dev Get newest rate in base currency from priceFeed for token.
     */
    function getRateNewest(address token_) public view auth returns (uint) {
        return _getNewRate(token_);
    }

    /**
     * @dev Get currently stored rate in base currency from priceFeed for token.
     */
    function getRate(address token_) public view auth returns (uint) {
        return rate[token_];
    }

    /**
     * @dev Get currently stored value in base currency of cdc token.
     */
    function getCdcValues(address cdc_) public view returns(uint256) {
        require(cdcs[cdc_], "asm-token-not-listed");
        return cdcValues[cdc_];
    }

    /**
     * @dev Get currently stored total value of dcdc token.
     */
    function getDcdcValues(address dcdc_) public view returns(uint256) {
        require(dcdcs[dcdc_], "asm-token-not-listed");
        return dcdcValues[dcdc_];
    }

    /**
     * @dev Get the currently stored total value in base currency of all dcdc tokens at a custodian.
     */
    function getTotalDcdcCustV(address custodian_) public view returns(uint256) {
        require(custodians[custodian_], "asm-not-a-custodian");
        return totalDcdcCustV[custodian_];
    }

    /**
     * @dev Get the currently sotored total value in base currency of a certain dcdc token at a custodian.
     */
    function getDcdcCustV(address custodian_, address dcdc_) public view returns(uint256) {
        require(custodians[custodian_], "asm-not-a-custodian");
        require(dcdcs[dcdc_], "asm-not-a-dcdc-token");
        return dcdcCustV[dcdc_][custodian_];
    }

    /**
     * @dev Returns true if token can be used as a payment token.
     */
    function isPayToken(address payToken_) public view returns(bool) {
        return payTokens[payToken_];
    }

    /**
     * @dev Returns true if token is a valid dpass token.
     */
    function isDpass(address dpass_) public view returns(bool) {
        return dpasses[dpass_];
    }

    /**
     * @dev Returns true if token is a valid dcdc token.
     */
    function isDcdc(address dcdc_) public view returns(bool) {
        return dcdcs[dcdc_];
    }

    /**
     * @dev Returns true if token is a valid cdc token.
     */
    function isCdc(address cdc_) public view returns(bool) {
        return cdcs[cdc_];
    }

    /**
    * @dev Retrieve the decimals of a token. As we can store only uint values, the decimals defne how many of the lower digits are part of the fraction part.
    */
    function getDecimals(address token_) public view returns (uint8 dec) {
        require(cdcs[token_] || payTokens[token_] || dcdcs[token_], "asm-token-not-listed");
        require(decimalsSet[token_], "asm-token-with-unset-decimals");
        while(dec <= 77 && decimals[token_] % uint(10) ** uint(dec) == 0){
            dec++;
        }
        dec--;
    }

    /**
    * @dev Returns true if decimals have been set for a certain token.
    */
    function isDecimalsSet(address token) public view returns(bool) {
        return decimalsSet[token];
    }

    /**
    * @dev Returns the price feed address of a token. Price feeds provide pricing info for asset management.
    */
    function getPriceFeed(address token_) public view returns(address) {
        require(dpasses[token_] || cdcs[token_] || dcdcs[token_] || payTokens[token_], "asm-token_-not-listed");
        return priceFeed[token_];
    }

    /**
    * @dev Returns the average purchase rate for a token. Users send
           different tokens several times to asm. Their price in terms of
           base currency is varying. This function returns the avarage value of the token.
    */
    function getTokenPurchaseRate(address token_) public view returns(uint256) {
        require(payTokens[token_], "asm-token-not-listed");
        return tokenPurchaseRate[token_];
    }

    /**
    * @dev  Returns the total value that has been paid out for a custodian
            for its services. The value is calculated in terms of base currency.
    */
    function getTotalPaidV(address custodian_) public view returns(uint256) {
        require(custodians[custodian_], "asm-not-a-custodian");
        return totalPaidV[custodian_];
    }

    /**
    * @dev  Returns the total value of all the dpass diamonds sold by a custodian.
            The value is calculated in base currency.
    */
    function getTotalDpassSoldV(address custodian_) public view returns(uint256) {
        require(custodians[custodian_], "asm-not-a-custodian");
        return totalDpassSoldV[custodian_];
    }

    /*
    * @dev Convert address to bytes32
    */
    function addr(bytes32 b_) public pure returns (address) {
        return address(uint256(b_));
    }

    /**
    * @dev Returns the base price of a diamond. This price is the final value of the diamond. Asset management uses this price to define total collateral value.
    */
    function getBasePrice(address token_, uint256 tokenId_) public view returns(uint) {
        require(dpasses[token_], "asm-invalid-token-address");
        return basePrice[token_][tokenId_];
    }

    /**
    * @dev Set base price_ for a diamond. This function should be used by oracles to update values of diamonds for sale.
    */
    function setBasePrice(address token_, uint256 tokenId_, uint256 price_) public auth {
        require(dpasses[token_], "asm-invalid-token-address");
        address custodian_ = Dpass(token_).getCustodian(tokenId_); 
        require(!custodians[msg.sender] || msg.sender == custodian_, "asm-not-authorized");

        if(Dpass(token_).ownerOf(tokenId_) == address(this)) {
            _updateCollateralDpass(price_, basePrice[token_][tokenId_], custodian_);
        }

        basePrice[token_][tokenId_] = price_;
        emit LogBasePrice(token_, tokenId_);
    }

    /**
    * @dev Returns the total value of all the dpass tokens in a domain_.
    */
    function getTotalDpassV(bytes32 domain_) public view returns(uint) {
        return totalDpassV[domain_];
    }

    /**
    * @dev Returns the total value of all the dcdc tokens in a domain_.
    */
    function getTotalDcdcV(bytes32 domain_) public view returns(uint) {
        return totalDcdcV[domain_];
    }

    /**
    * @dev Returns the total value of all the cdc tokens in a domain_.
    */
    function getTotalCdcV(bytes32 domain_) public view returns(uint) {
        return totalCdcV[domain_];
    }

    /**
    * @dev Returns the required of overcollaterization ratio that is required. The total value of cdc tokens in a domain_ should be less than total value of dpass tokens plus total value of dcdc tokens divided by overcollatrization ratio.
    */
    function getOverCollRatio(bytes32 domain_) public view returns(uint) {
        return overCollRatio[domain_];
    }

    /**
    * @dev Updates value of cdc_ token from priceFeed. This function is called by oracles but can be executed by anyone wanting update cdc_ value in the system.
    */
    function updateCdcValue(address cdc_) public stoppable {
        _updateCdcValue(cdc_);
    }

    /**
    * @dev Updates value of a dcdc_ token. This function should be called by oracles but anyone can call it.
    */
    function updateTotalDcdcValue(address dcdc_) public stoppable {
        _updateTotalDcdcValue(dcdc_);
    }

    /**
    * @dev Updates value of a dcdc_ token belonging to a custodian_. This function should be called by oracles or custodians but anyone can call it.
    * @param dcdc_ address the dcdc_ token we want to update the value for
    * @param custodian_ address the custodian_ whose total dcdc_ values will be updated.
    */
    function updateDcdcValue(address dcdc_, address custodian_) public stoppable {
        _updateDcdcValue(dcdc_, custodian_);
    }

    /**
    * @dev Allows asset management to be notified about a token_ transfer. If system would get undercollaterized because of transfer it will be reverted.
    * @param token_ address the token_ that has been sent during transaction
    * @param src_ address the source address the token_ has been sent from
    * @param dst_ address the destination address the token_ has been sent to
    * @param amtOrId_ uint the amount of tokens sent if token_ is a DSToken or the id of token_ if token_ is a Dpass token_.
    */
    function notifyTransferFrom(address token_, address src_, address dst_, uint256 amtOrId_) external nonReentrant auth {
        uint balance;
        address custodian;
        bytes32 domain = domains[token_];

        require(dpasses[token_] || cdcs[token_] || payTokens[token_], "asm-invalid-token");
        require(!dpasses[token_] || Dpass(token_).getState(amtOrId_) == "sale", "asm-ntf-token-state-not-sale");
        if(dpasses[token_] && src_ == address(this)) {                        // custodian sells dpass to user
            custodian = Dpass(token_).getCustodian(amtOrId_);
            _updateCollateralDpass(0, basePrice[token_][amtOrId_], custodian);
            totalDpassSoldV[custodian] = add(totalDpassSoldV[custodian], basePrice[token_][amtOrId_]);

            _requireCustodianCollaterized(custodian, _getCustodianCdcV(domain, custodian));
            _requireSystemCollaterized(domain);

        } else if (dst_ == address(this) && !dpasses[token_]) {                                  // user sells ERC20 token_ to sellers
            require(payTokens[token_], "asm-we-dont-accept-this-token");

            if (cdcs[token_]) {
                _burn(token_, amtOrId_);
            } else {
                balance = sub(
                    token_ == eth ?
                        address(this).balance :
                        DSToken(token_).balanceOf(address(this)),
                    amtOrId_);                                              // this assumes that first tokens are sent, than ...
                                                                            // ... notifyTransferFrom is called, if it is the other way ...
                                                                            // ... around then amtOrId_ must not be subrtacted from current ...
                                                                            // ... balance
                tokenPurchaseRate[token_] = wdiv(
                    add(
                        wmulV(
                            tokenPurchaseRate[token_],
                            balance,
                            token_),
                        wmulV(_updateRate(token_), amtOrId_, token_)),
                    add(balance, amtOrId_));
            }


        } else if (dst_ == address(this) && dpasses[token_]) {                                        // user sells erc721 token_ to custodians

            require(payTokens[token_], "asm-token-not-accepted");

            _updateCollateralDpass(basePrice[token_][amtOrId_], 0, Dpass(token_).getCustodian(amtOrId_));

        } else {
            require(false, "asm-unsupported-tx");
        }
    }

    /**
    * @dev Burns cdc tokens when users pay with them. Also updates system collaterization.
    * @param token_ address cdc token_ that needs to be burnt
    * @param amt_ uint the amount to burn.
    */
    function burn(address token_, uint256 amt_) public nonReentrant auth {
        _burn(token_, amt_);
    }

    /**
    * @dev Mints cdc tokens when users buy them. Also updates system collaterization.
    * @param token_ address cdc token_ that needs to be minted
    * @param dst_ address the address for whom cdc token_ will be minted for.
    */
    function mint(address token_, address dst_, uint256 amt_) public nonReentrant auth {
        bytes32 domain = domains[token_];
        require(cdcs[token_], "asm-token-is-not-cdc");
        DSToken(token_).mint(dst_, amt_);
        _updateCdcValue(token_);
        _requireSystemCollaterized(domain);
    }

    /**
    * @dev Mints cdc tokens when users buy them. Also updates system collaterization.
    * @param token_ address cdc token_ that needs to be minted
    * @param dst_ address the address for whom cdc token_ will be minted for.
    * @param amt_ uint amount to be minted
    */
    function mintDcdc(address token_, address dst_, uint256 amt_) public nonReentrant auth {
        require(!custodians[msg.sender] || dst_ == msg.sender, "asm-can-not-mint-for-dst");
        require(dcdcs[token_], "asm-token-is-not-cdc");
        require(custodians[msg.sender], "asm-dst-not-a-custodian");
        DSToken(token_).mint(dst_, amt_);
        _updateDcdcValue(token_, dst_);
    }

    function burnDcdc(address token_, address src_, uint256 amt_) public nonReentrant auth {
        bytes32 domain = domains[token_];

        uint custodianCdcV = _getCustodianCdcV(domain, src_);

        require(dcdcs[token_], "asm-token-is-not-cdc");
        require(custodians[src_], "asm-dst-not-a-custodian");
        DSToken(token_).burn(src_, amt_);
        _updateDcdcValue(token_, src_);

        _requireCustodianCollaterized(src_, custodianCdcV);
        _requireSystemCollaterized(domain);
        _requirePaidLessThanSold(src_, custodianCdcV);
    }

    function mintDpass(
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
    ) public nonReentrant auth returns (uint256 id_) {
        require(dpasses[token_], "asm-mnt-not-a-dpass-token");
        require(!custodians[msg.sender] || custodian_ == msg.sender, "asm-mnt-no-mint-to-others");

        id_ = Dpass(token_).mintDiamondTo(
            address(this),                  // owner
            custodian_,
            issuer_,
            report_,
            state_,
            cccc_,
            carat_,
            attributesHash_,
            currentHashingAlgorithm_);

        setBasePrice(token_, id_, price_);
    }

    function setStateDpass(address token_, uint256 tokenId_, bytes32 state_) public nonReentrant auth {
        require(dpasses[token_], "asm-mnt-not-a-dpass-token");
        require(
            !custodians[msg.sender] ||
            msg.sender == Dpass(token_).getCustodian(tokenId_),
            "asm-sds-not-authorized");
        Dpass(token_).changeStateTo(state_, tokenId_);
    }

    function setStateDpass(address token_, uint256[] memory tokenIds_, bytes32 state_) public nonReentrant auth {
        require(dpasses[token_], "asm-sds-not-a-dpass-token");

        for(uint idx_ = 0; idx_ < tokenIds_.length; idx_++) {

            require(
                !custodians[msg.sender] ||
                msg.sender == Dpass(token_).getCustodian(tokenIds_[idx_]),
                "asm-sds-not-authorized");

            Dpass(token_).changeStateTo(state_, tokenIds_[idx_]);
        }
    }

    function getWithdrawValue(address custodian_) public view returns(uint) {
        require(custodians[custodian_], "asm-not-a-custodian");
        uint custodianCdcV_ = _getCustodianCdcV(domains[custodian_], custodian_);
        uint totalSoldV_ = add(
            custodianCdcV_,
            totalDpassSoldV[custodian_]);
        if (add(totalSoldV_, dust) > totalPaidV[custodian_]) {
            return sub(totalSoldV_, totalPaidV[custodian_]);
        } else {
            return 0;
        }
    }

    function withdraw(address token_, uint256 amt_) public nonReentrant auth {
        address custodian = msg.sender;
        bytes32 domain = domains[custodian];
        require(custodians[custodian], "asm-not-a-custodian");
        require(payTokens[token_], "asm-cant-withdraw-token");
        require(tokenPurchaseRate[token_] > 0, "asm-token-purchase-rate-invalid");

        uint tokenV = wmulV(tokenPurchaseRate[token_], amt_, token_);

        totalPaidV[msg.sender] = add(totalPaidV[msg.sender], tokenV);
        _requirePaidLessThanSold(custodian, _getCustodianCdcV(domain, custodian));

        sendToken(token_, address(this), msg.sender, amt_);
    }

    function getAmtForSale(address token_) external view returns(uint256) {
        bytes32 domain = domains[token_];
        require(cdcs[token_], "asm-token-is-not-cdc");
        // Commented due fit to code size limit 24,576 bytes
        return wdivT(
            sub(
                wdiv(
                    add(
                        totalDpassV[domain],
                        totalDcdcV[domain]),
                    overCollRatio[domain]),
                totalCdcV[domain]),
            _getNewRate(token_),
            token_);
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

    /*
    * @dev function should only be used in case of unexpected events at custodian!! It will update the system collateral value and collateral value of dpass tokens at custodian.
    */
    function updateCollateralDpass(uint positiveV_, uint negativeV_, address custodian_) public auth {
        _updateCollateralDpass(positiveV_, negativeV_, custodian_);

        emit LogForceUpdateCollateralDpass(msg.sender, positiveV_, negativeV_, custodian_);
    }

    /*
    * @dev function should only be used in case of unexpected events at custodian!! It will update the system collateral value and collateral value of dpass tokens custodian.
    */
    function updateCollateralDcdc(uint positiveV_, uint negativeV_, address custodian_) public auth {
        _updateCollateralDcdc(positiveV_, negativeV_, custodian_);
        emit LogForceUpdateCollateralDcdc(msg.sender, positiveV_, negativeV_, custodian_);
    }

    function () external payable {
    }

    function _burn(address token_, uint256 amt_) internal {
        require(cdcs[token_], "asm-token-is-not-cdc");
        DSToken(token_).burn(amt_);
        _updateCdcValue(token_);
    }

    /**
    * @dev Get exchange rate for a token
    */
    function _updateRate(address token_) internal returns (uint256 rate_) {
        require((rate_ = _getNewRate(token_)) > 0, "asm-updateRate-rate-gt-zero");
        rate[token_] = rate_;
    }

    function _updateCdcValue(address cdc_) internal {
        require(cdcs[cdc_], "asm-not-a-cdc-token");
        bytes32 domain = domains[cdc_];
        uint newValue = wmulV(DSToken(cdc_).totalSupply(), _updateRate(cdc_), cdc_);

        totalCdcV[domain] = sub(add(totalCdcV[domain], newValue), cdcValues[cdc_]);

        cdcValues[cdc_] = newValue;

        emit LogCdcValue(totalCdcV[domain], domain, cdcValues[cdc_], cdc_);
    }

    function _updateTotalDcdcValue(address dcdc_) internal {
        require(dcdcs[dcdc_], "asm-not-a-dcdc-token");
        bytes32 domain = domains[dcdc_];
        uint newValue = wmulV(DSToken(dcdc_).totalSupply(), _updateRate(dcdc_), dcdc_);
        totalDcdcV[domain] = sub(add(totalDcdcV[domain], newValue), dcdcValues[dcdc_]);
        dcdcValues[dcdc_] = newValue;
        emit LogDcdcValue(totalDcdcV[domain], domain, cdcValues[dcdc_], dcdc_);
    }

    function _updateDcdcValue(address dcdc_, address custodian_) internal {
        require(dcdcs[dcdc_], "asm-not-a-dcdc-token");
        require(custodians[custodian_], "asm-not-a-custodian");
        uint newValue = wmulV(DSToken(dcdc_).balanceOf(custodian_), _updateRate(dcdc_), dcdc_);

        totalDcdcCustV[custodian_] = sub(
            add(
                totalDcdcCustV[custodian_],
                newValue),
            dcdcCustV[dcdc_][custodian_]);

        dcdcCustV[dcdc_][custodian_] = newValue;

        emit LogDcdcCustodianValue(totalDcdcCustV[custodian_], dcdcCustV[dcdc_][custodian_], dcdc_, custodian_);

        _updateTotalDcdcValue(dcdc_);
    }

    /**
    * @dev Get token_ / quote_currency rate from priceFeed
    * Revert transaction if not valid feed and manual value not allowed
    */
    function _getNewRate(address token_) private view returns (uint rate_) {
        bool feedValid;
        bytes32 usdRateBytes;

        require(
            address(0) != priceFeed[token_],                            // require token to have a price feed
            "asm-no-price-feed");

        (usdRateBytes, feedValid) =
            TrustedFeedLike(priceFeed[token_]).peek();                  // receive DPT/USD price
        if (feedValid) {                                                // if feed is valid, load DPT/USD rate from it
            rate_ = uint(usdRateBytes);
        } else {
            require(manualRate[token_], "Manual rate not allowed");     // if feed invalid revert if manualEthRate is NOT allowed
            rate_ = rate[token_];
        }
    }

    function _getCustodianCdcV(bytes32 domain_, address custodian_) internal view returns(uint) {
        return wmul(
            totalCdcV[domain_],
            add(totalDpassV[domain_], totalDcdcV[domain_]) > 0 ?
                wdiv(
                    add(
                        totalDpassCustV[custodian_],
                        totalDcdcCustV[custodian_]),
                    add(
                        totalDpassV[domain_],
                        totalDcdcV[domain_])):
                1 ether);
    }
    /**
    * @dev System must be overcollaterized at all time. Whenever collaterization shrinks this function must be called.
    */

    function _requireSystemCollaterized(bytes32 domain_) internal view returns(uint) {
        require(
            add(
                add(
                    totalDpassV[domain_],
                    totalDcdcV[domain_]),
                dust) >=
            wmul(
                overCollRatio[domain_],
                totalCdcV[domain_])
            , "asm-system-undercollaterized");
    }

    /**
    * @dev Custodian's total collateral value must be more or equal than proportional cdc value and dpasses sold
    */
    function _requireCustodianCollaterized(address custodian_, uint256 custodianCdcV_) internal view {
        require(
            custodianCdcV_
                 <=
            add(
                add(
                    totalDpassCustV[custodian_],
                    totalDcdcCustV[custodian_]),
                dust)
            , "asm-custodian-undercollaterized");
    }

    /**
    * @dev The total value paid to custodian must be less then the total value of sold assets
    */
    function _requirePaidLessThanSold(address custodian_, uint256 custodianCdcV_) internal view returns(uint) {
        require(
            add(
                add(
                    custodianCdcV_,
                    totalDpassSoldV[custodian_]),
                dust) >=
                totalPaidV[custodian_]
            , "asm-too-much-withdrawn");
    }

    function _updateCollateralDpass(uint positiveV_, uint negativeV_, address custodian_) internal {
        require(custodians[custodian_], "asm-not-a-custodian");
        bytes32 domain = domains[custodian_];

        totalDpassCustV[custodian_] = sub(
            add(
                totalDpassCustV[custodian_],
                positiveV_),
            negativeV_);
        
        totalDpassV[domain] = sub(
            add(
                totalDpassV[domain],
                positiveV_),
            negativeV_);

        emit LogDpassValue(totalDpassCustV[custodian_], totalDpassV[domain], custodian_, domain);
    }

    function _updateCollateralDcdc(uint positiveV_, uint negativeV_, address custodian_) internal {
        require(custodians[custodian_], "asm-not-a-custodian");
        bytes32 domain = domains[custodian_];

        totalDcdcCustV[custodian_] = sub(
            add(
                totalDcdcCustV[custodian_],
                positiveV_),
            negativeV_);

        totalDcdcV[domain] = sub(
            add(
                totalDcdcV[domain],
                positiveV_),
            negativeV_);

        emit LogDcdcTotalCustodianValue(totalDcdcCustV[custodian_], totalDcdcV[domain], custodian_, domain);
    }

// TODO: comment out next function if wallet is inherited from
    /**
    * @dev send token or ether to destination
    */
    function sendToken(
        address token,
        address src,
        address payable dst,
        uint256 amount
    ) internal returns (bool){
        TrustedErc20Wallet erc20 = TrustedErc20Wallet(token);
        if (token == eth && amount > 0) {
            require(src == address(this), "wal-ether-transfer-invalid-src");
            dst.transfer(amount);
            emit LogTransferEth(src, dst, amount);
        } else {
            if (amount > 0) erc20.transferFrom(src, dst, amount);   // transfer all of token to dst
        }
        return true;
    }
}

// TODO: be able to ban custodian sale 
// TODO: update Wallet.sol to handle dpass tokens as well
// TODO: document functions
// TODO: auth thests
// TODO: auth thests
