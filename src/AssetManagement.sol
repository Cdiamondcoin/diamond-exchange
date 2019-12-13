pragma solidity ^0.5.11;

import "ds-math/math.sol";
import "ds-auth/auth.sol";
import "ds-token/token.sol";
import "ds-stop/stop.sol";
import "ds-note/note.sol";
import "dpass/Dpass.sol";
import "./AssetManagementCore.sol";


/**
* @dev Contract to get ETH/USD price
*/
contract TrustedFeedLike {
    function peek() external view returns (bytes32, bool);
}


contract AssetManagement is DSAuth, DSStop {

    event LogAudit(address sender, address custodian_, uint256 status_, bytes32 descriptionHash_, bytes32 descriptionUrl_, uint32 auditInterwal_);
    event LogConfigChange(address sender, bytes32 what, bytes32 value, bytes32 value1);
    event LogTransferEth(address src, address dst, uint256 amount);
    event LogBasePrice(address sender_, address token_, uint256 tokenId_, uint256 price_);
    event LogCdcValue(uint256 totalCdcV, bytes32 domain, uint256 cdcValue, address token);
    event LogDcdcValue(uint256 totalDcdcV, bytes32 domain, uint256 ddcValue, address token);
    event LogDcdcCustodianValue(uint256 totalDcdcCustV, uint256 dcdcCustV, address dcdc, address custodian);
    event LogDcdcTotalCustodianValue(uint256 totalDcdcCustV, uint256 totalDcdcV, address custodian, bytes32 domain);
    event LogDpassValue(uint256 totalDpassCustV, uint256 totalDpassV, address custodian, bytes32 domain);
    event LogForceUpdateCollateralDpass(address sender, uint256 positiveV_, uint256 negativeV_, address custodian);
    event LogForceUpdateCollateralDcdc(address sender, uint256 positiveV_, uint256 negativeV_, address custodian);
    //TODO: remove LogTest
    event LogTest(uint256 what);
    event LogTest(bool what);
    event LogTest(address what);
    event LogTest(bytes32 what);

    bool public locked;                               // variable prevents to exploit by recursively calling funcions

    AssetManagementCore asc;                          // core contract holding all values and getters for us
    /**
     * @dev Modifier making sure the function can not be called in a recursive way in one transaction.
     */
    modifier nonReentrant {
        require(!locked, "asm-reentrancy-detected");
        locked = true;
        _;
        locked = false;
    }

//-----------included-from-ds-math---------------------------------begin
    uint constant WAD = 10 ** 18;

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
            require(asc.payTokens(token) || asc.cdcs(token) || asc.dcdcs(token), "asm-token-not-allowed-rate");
            require(value > 0, "asm-rate-must-be-gt-0");
            asc.setRate(token, value);
        } else if (what_ == "custodians") {
            bytes32 domain = value2_;
            address custodian = addr(value_);
            bool enable = uint(value1_) > 0;
            if(enable) asc.setDomains(custodian, domain);
            require(custodian != address(0), "asm-custodian-zero-address");
            asc.setCustodians(addr(value_), enable);
        } else if (what_ == "overCollRatio") {
            bytes32 domain = value2_;
            asc.setOverCollRatio(domain, uint(value_));
            require(asc.overCollRatio(domain) >= 1 ether, "asm-system-must-be-overcollaterized");
            _requireSystemCollaterized(domain);
        } else if (what_ == "overCollRemoveRatio") {
            bytes32 domain = value2_;
            asc.setOverCollRemoveRatio(domain, uint(value_));
            require(asc.overCollRemoveRatio(domain) >= 1 ether, "asm-must-be-gt-1-ether");
            require(asc.overCollRemoveRatio(domain) <= asc.overCollRatio(domain), "asm-must-be-lt-overcollratio");

            _requireSystemRemoveCollaterized(domain); // TODO: check if this should hold or sthg else
        } else if (what_ == "priceFeed") {
            require(addr(value1_) != address(address(0x0)), "asm-wrong-pricefeed-address");
            require(addr(value_) != address(address(0x0)), "asm-wrong-token-address");
            asc.setPriceFeed(addr(value_), addr(value1_));
        } else if (what_ == "decimals") {
            address token = addr(value_);
            uint decimal = uint256(value1_);
            require(token != address(0x0), "asm-wrong-address");
            asc.setDecimals(token, 10 ** decimal);
            asc.setDecimalsSet(token, true);
        } else if (what_ == "manualRate") {
            address token = addr(value_);
            bool enable = uint(value1_) > 0;
            require(token != address(address(0x0)), "asm-wrong-token-address");
            require(asc.priceFeed(token) != address(address(0x0)), "asm-priceFeed-first");
            asc.setManualRate(token, enable);
        } else if (what_ == "payTokens") {
            address token = addr(value_);
            require(token != address(0), "asm-pay-token-address-no-zero");
            asc.setPayTokens(token, uint(value1_) > 0);
        } else if (what_ == "dcdcs") {
            bytes32 domain = value2_;
            address newDcdc = addr(value_);
            bool enable = uint(value1_) > 0;
            if(enable) asc.setDomains(newDcdc, domain);
            require(newDcdc != address(0), "asm-dcdc-address-zero");
            require(asc.priceFeed(newDcdc) != address(0), "asm-add-pricefeed-first");
            require(asc.decimalsSet(newDcdc),"asm-no-decimals-set-for-token");
            asc.setDcdcs(newDcdc, enable);
            _updateTotalDcdcV(newDcdc);
        } else if (what_ == "cdcs") {
            bytes32 domain = value2_;
            address newCdc = addr(value_);
            bool enable = uint(value1_) > 0;
            if(enable) asc.setDomains(newCdc, domain);
            require(asc.priceFeed(newCdc) != address(0), "asm-add-pricefeed-first");
            require(asc.decimalsSet(newCdc), "asm-add-decimals-first");
            require(newCdc != address(0), "asm-cdc-address-zero");
            asc.setCdcs(newCdc, enable);
            _updateCdcV(newCdc);
            _requireSystemCollaterized(domain);
        } else if (what_ == "dpasses") {
            bytes32 domain = value2_;
            address dpass = addr(value_);
            bool enable = uint(value1_) > 0;
            if(enable) asc.setDomains(dpass, domain);
            require(dpass != address(0), "asm-dpass-address-zero");
            asc.setDpasses(dpass, enable);
        } else if (what_ == "approve") {                            // TODO: remove this for security reasons
            address token = addr(value_);
            address dst = addr(value1_);
            uint value = uint(value2_);
            require(asc.decimalsSet(token),"asm-no-decimals-set-for-token");
            require(dst != address(0), "asm-dst-zero-address");
            DSToken(token).approve(dst, value);
        }  else if (what_ == "setApproveForAll") {                  // TODO: remove this for security reasons
            address token = addr(value_);
            address dst = addr(value1_);
            bool enable = uint(value2_) > 0;
            require(asc.dpasses(token),"asm-not-a-dpass-token");
            require(dst != address(0), "asm-dst-zero-address");
            Dpass(token).setApprovalForAll(dst, enable);
        } else if (what_ == "dust") {
            asc.setDust(uint256(value_));
        } else if (what_ == "asc") {
            asc = AssetManagementCore(addr(value_));
        } else {
            require(false, "asm-wrong-config-option");
        }

        emit LogConfigChange(msg.sender, what_, value_, value1_);
    }

    /**
     * @dev Set rate (price in base currency) for token.
     */
    function setRate(address token_, uint256 value_) public auth {  //TODO: change to nonReentrant after it does not use setConfig() anymore
        setConfig("rate", bytes32(uint(token_)), bytes32(value_), "");
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
        return asc.rate(token_);
    }

    /**
    * @dev Retrieve the decimals of a token. As we can store only uint values, the decimals defne how many of the lower digits are part of the fraction part.
    */
    function getDecimals(address token_) public view returns (uint8 dec) {
        require(asc.cdcs(token_) || asc.payTokens(token_) || asc.dcdcs(token_), "asm-token-not-listed");
        require(asc.decimalsSet(token_), "asm-token-with-unset-decimals");
        while(dec <= 77 && asc.decimals(token_) % uint(10) ** uint(dec) == 0){
            dec++;
        }
        dec--;
    }

    /*
    * @dev Convert address to bytes32
    */
    function addr(bytes32 b_) public pure returns (address) {
        return address(uint256(b_));
    }

    /**
    * @dev Set base price_ for a diamond. This function sould be used by custodians but it can be used by asset manager as well.
    */
    function setBasePrice(address token_, uint256 tokenId_, uint256 price_) public nonReentrant auth {
        _setBasePrice(token_, tokenId_, price_);
    }

    /**
    * @dev Returns the current maximum value a custodian can mint from dpass and dcdc tokens.
    */
    function setCapCustV(address custodian_, uint256 capCustV_) public nonReentrant auth {
        require(asc.custodians(custodian_), "asm-should-be-custodian");
        asc.setCapCustV(custodian_, capCustV_);
    }

    /**
    * @dev Updates value of cdc_ token from priceFeed. This function is called by oracles but can be executed by anyone wanting update cdc_ value in the system. This function should be called every time the price of cdc has been updated.
    */
    function setCdcV(address cdc_) public stoppable {
        _updateCdcV(cdc_);
    }

    /**
    * @dev Updates value of a dcdc_ token. This function should be called by oracles but anyone can call it. This should be called every time the price of dcdc token was updated.
    */
    function setTotalDcdcV(address dcdc_) public stoppable {
        _updateTotalDcdcV(dcdc_);
    }

    /**
    * @dev Updates value of a dcdc_ token belonging to a custodian_. This function should be called by oracles or custodians but anyone can call it.
    * @param dcdc_ address the dcdc_ token we want to update the value for
    * @param custodian_ address the custodian_ whose total dcdc_ values will be updated.
    */
    function setDcdcV(address dcdc_, address custodian_) public stoppable {
        _updateDcdcV(dcdc_, custodian_);
    }

    /**
    * @dev Auditors can propagate their independent audit results here in order to make sure that users' diamonds are safe and there.
    * @param custodian_ address the custodian, who the audit was done for.
    * @param status_ uint the status of result. 0 means everything is fine, else should be the value of amount in geopardy or questionable.
    * @param descriptionHash_ bytes32 keccak256() hash of the full audit statement available at descriptionUrl_. In the document all parameters
    *   should be described concerning the availability, and quality of collateral at custodian.
    * @param descriptionUrl_ bytes32 the url of the audit document. Whenever this is published the document must already be online to avoid fraud.
    * @param auditInterval_ uint the proposed time in seconds until next audit. If auditor thinks more frequent audits are required he can express his wish here.
    */

    function setAudit(
        address custodian_,
        uint256 status_,
        bytes32 descriptionHash_,
        bytes32 descriptionUrl_,
        uint32 auditInterval_
    ) public nonReentrant auth {
        uint32 minInterval_;
        require(asc.custodians(custodian_), "asm-audit-not-a-custodian");
        require(auditInterval_ != 0, "asm-audit-interval-zero");

        minInterval_ = uint32(min(auditInterval_, asc.auditInterval()));

        asc.setAudit(
            custodian_,
            msg.sender,
            status_,
            descriptionHash_,
            descriptionUrl_,
            block.timestamp + minInterval_);

        emit LogAudit(msg.sender, custodian_, status_, descriptionHash_, descriptionUrl_, minInterval_);
    }

    /**
    * @dev Allows asset management to be notified about a token_ transfer. If system would get undercollaterized because of transfer it will be reverted.
    * @param token_ address the token_ that has been sent during transaction
    * @param src_ address the source address the token_ has been sent from
    * @param dst_ address the destination address the token_ has been sent to
    * @param amtOrId_ uint the amount of tokens sent if token_ is a DSToken or the id of token_ if token_ is a Dpass token_.
    */
    function notifyTransferFrom(
        address token_,
        address src_,
        address dst_,
        uint256 amtOrId_
    ) external nonReentrant auth {
        uint balance;
        address custodian;
        bytes32 domain = asc.domains(token_);

        require(
            asc.dpasses(token_) || asc.cdcs(token_) || asc.payTokens(token_),
            "asm-invalid-token");

        require(
            !asc.dpasses(token_) || Dpass(token_).getState(amtOrId_) == "sale",
            "asm-ntf-token-state-not-sale");

        if(asc.dpasses(token_) && src_ == address(this)) {                     // custodian sells dpass to user
            custodian = Dpass(token_).getCustodian(amtOrId_);

            _updateCollateralDpass(
                0,
                asc.basePrice(token_, amtOrId_),
                custodian);

            asc.setSoldDpassCustV(custodian, add(
                asc.soldDpassCustV(custodian),
                asc.basePrice(token_, amtOrId_)));

            asc.setTotalSoldDpassV(domain, add(                                  // TODO: test
                asc.totalSoldDpassV(domain),
                asc.basePrice(token_, amtOrId_)));      

            Dpass(token_).setState("valid", amtOrId_);

            _requireSystemCollaterized(domain);

        } else if (dst_ == address(this) && !asc.dpasses(token_)) {             // user sells ERC20 token_ to sellers
            require(asc.payTokens(token_), "asm-we-dont-accept-this-token");

            if (asc.cdcs(token_)) {
                _burn(token_, amtOrId_);
            } else {
                balance = sub(
                    token_ == asc.eth() ?
                        address(this).balance :
                        DSToken(token_).balanceOf(address(this)),
                    amtOrId_);                                              // this assumes that first tokens are sent, than ...
                                                                            // ... notifyTransferFrom is called, if it is the other way ...
                                                                            // ... around then amtOrId_ must not be subrtacted from current ...
                                                                            // ... balance
                asc.setTokenPurchaseRate(token_, wdiv(
                    add(
                        wmulV(
                            asc.tokenPurchaseRate(token_),
                            balance,
                            token_),
                        wmulV(_updateRate(token_), amtOrId_, token_)),
                    add(balance, amtOrId_)));
            }


        } else if (dst_ == address(this) && asc.dpasses(token_)) {               // user sells erc721 token_ to custodians

            require(asc.payTokens(token_), "asm-token-not-accepted");

            _updateCollateralDpass(
                asc.basePrice(token_, amtOrId_),
                0,
                Dpass(token_).getCustodian(amtOrId_));

            asc.setSoldDpassCustV(custodian, sub(
                asc.soldDpassCustV(custodian),
                min(
                    asc.basePrice(token_, amtOrId_),
                    asc.soldDpassCustV(custodian))));

            asc.setTotalSoldDpassV(domain, sub(                                  // TODO: test
                asc.totalSoldDpassV(domain),
                min(
                    asc.basePrice(token_, amtOrId_),
                    asc.totalSoldDpassV(domain))));      

            Dpass(token_).setState("valid", amtOrId_);

        } else if (asc.dpasses(token_)) {                                        // user sells erc721 token_ to other users

            // require(asc.payTokens(token_), "asm-token-not-accepted");        // TODO: test user wants to steal others approved tokens

        }  else {
            require(false, "asm-unsupported-tx");
        }
    }

    /**
    * @dev Burns cdc tokens. Also updates system collaterization. Cdc tokens are burnt when users pay with cdc on exchange or when users redeem cdcs.
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
        bytes32 domain = asc.domains(token_);
        require(asc.cdcs(token_), "asm-token-is-not-cdc");
        DSToken(token_).mint(dst_, amt_);
        _updateCdcV(token_);

        asc.setTotalSoldCdcV(domain, add(
            asc.totalSoldCdcV(domain), 
            wmulV(amt_, _updateRate(token_), token_))); // TODO: test

        _requireSystemCollaterized(domain);
    }

    /**
    * @dev Mints dcdc tokens for custodians. This function should only be run by custodians.
    * @param token_ address dcdc token_ that needs to be minted
    * @param dst_ address the address for whom dcdc token will be minted for.
    * @param amt_ uint amount to be minted
    */
    function mintDcdc(address token_, address dst_, uint256 amt_) public nonReentrant auth {
        require(asc.custodians(msg.sender), "asm-not-a-custodian");
        require(!asc.custodians(msg.sender) || dst_ == msg.sender, "asm-can-not-mint-for-dst");
        require(asc.dcdcs(token_), "asm-token-is-not-cdc");
        DSToken(token_).mint(dst_, amt_);
        _updateDcdcV(token_, dst_);
        _requireCapCustV(dst_);
    }

    /**
    * @dev Burns dcdc token. This function should be used by custodians.
    * @param token_ address dcdc token_ that needs to be burnt.
    * @param src_ address the address from whom dcdc token will be burned.
    * @param amt_ uint amount to be burnt.
    */
    function burnDcdc(address token_, address src_, uint256 amt_) public nonReentrant auth {
        bytes32 domain = asc.domains(token_);

        require(asc.custodians(msg.sender), "asm-not-a-custodian");
        require(!asc.custodians(msg.sender) || src_ == msg.sender, "asm-can-not-burn-from-src");
        require(asc.dcdcs(token_), "asm-token-is-not-cdc");
        DSToken(token_).burn(src_, amt_);
        _updateDcdcV(token_, src_);

        _requireSystemRemoveCollaterized(domain);
        _requireTotalPaidIsLessOrEqualThanStockAndSold(src_);
    }

    /**
    * @dev Mint dpass tokens and update collateral values.
    * @param token_ address that is to be minted. Must be a dpass token address.
    * @param custodian_ address this must be the custodian that we mint the token for. Parameter necessary only for future compatibility.
    * @param issuer_ bytes3 the issuer of the certificate for diamond
    * @param report_ bytes16 the report number of the certificate of the diamond.
    * @param state_ bytes the state of token. Should be "sale" if it is to be sold on market, and "valid" if it is not to be sold.
    * @param cccc_ bytes20 cut, clarity, color, and carat (carat range) values of the diamond. Only a specific values of cccc_ is accepted.
    * @param carat_ uint24 exact weight of diamond in carats with 2 decimal precision.
    * @param attributesHash_ bytes32 the hash of ALL the attributes that are not stored on blockckhain to make sure no one can change them later on.
    * @param currentHashingAlgorithm_ bytes8 the algorithm that is used to construct attributesHash_. Together these values make meddling with diamond data very hard.
    * @param price_ uint256 the base price of diamond (not per carat price)
    */
    function mintDpass(
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
    ) public nonReentrant auth returns (uint256 id_) {
        require(asc.dpasses(token_), "asm-mnt-not-a-dpass-token");
        require(asc.custodians(msg.sender), "asm-not-a-custodian");
        require(!asc.custodians(msg.sender) || custodian_ == msg.sender, "asm-mnt-no-mint-to-others");

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

        _setBasePrice(token_, id_, price_);
    }

    /*
    * @dev Set state for dpass. Should be used primarily by custodians.
    */
    function setStateDpass(address token_, uint256 tokenId_, bytes8 state_) public nonReentrant auth {
        bytes32 prevState_;
        address custodian_;

        require(asc.dpasses(token_), "asm-mnt-not-a-dpass-token");

        custodian_ = Dpass(token_).getCustodian(tokenId_);
        require(
            !asc.custodians(msg.sender) ||
            msg.sender == custodian_,
            "asm-ssd-not-authorized");

        prevState_ = Dpass(token_).getState(tokenId_);

        if(
            prevState_ != "invalid" &&
            prevState_ != "removed" &&
            (
                state_ == "invalid" ||
                state_ == "removed"
            )
        ) {
            _updateCollateralDpass(0, asc.basePrice(token_, tokenId_), custodian_);
            _requireSystemRemoveCollaterized(asc.domains(token_));
            _requireTotalPaidIsLessOrEqualThanStockAndSold(custodian_);

        } else if(
            prevState_ == "redeemed" ||
            prevState_ == "invalid" ||
            prevState_ == "removed" ||
            (
                state_ != "invalid" &&
                state_ != "removed" &&
                state_ != "redeemed"
            )
        ) {
            _updateCollateralDpass(asc.basePrice(token_, tokenId_), 0, custodian_);
        }

        Dpass(token_).setState(state_, tokenId_);
    }

    /*
    * @dev Withdraw tokens for selling dpass, and cdc. Custodians do not receive money directly from selling dpass, ot cdc, but
    * they must withdraw their tokens.
    */
    function withdraw(address token_, uint256 amt_) public nonReentrant auth {
        address custodian = msg.sender;
        bytes32 domain = asc.domains(custodian);
        require(asc.custodians(custodian), "asm-not-a-custodian");
        require(asc.payTokens(token_), "asm-cant-withdraw-token");
        require(asc.tokenPurchaseRate(token_) > 0, "asm-token-purchase-rate-invalid");

        uint tokenV = wmulV(asc.tokenPurchaseRate(token_), amt_, token_);
        uint withdrawDpassV = min(
            tokenV, 
            sub(
                asc.soldDpassCustV(custodian), 
                min(
                    asc.paidDpassCustV(custodian),
                    asc.soldDpassCustV(custodian))
            ));
        asc.setPaidDpassCustV(custodian, add(asc.paidDpassCustV(custodian), withdrawDpassV));
        asc.setTotalPaidDpassV(domain, add(asc.totalPaidDpassV(domain), withdrawDpassV));
        tokenV -= withdrawDpassV;  // this is never going to underflow
        uint custodianCdcV = cdcCustV(custodian);
        require(tokenV <= 
            add(
                sub(
                    custodianCdcV,
                    min(
                        custodianCdcV,
                        asc.paidCdcCustV(custodian))),
                asc.dust()),
            "asm-too-much-to-withdraw");
        asc.setPaidCdcCustV(custodian, add(asc.paidCdcCustV(custodian), tokenV));
        asc.setTotalPaidCdcV(domain, add(asc.totalPaidCdcV(domain), tokenV));
        _requireTotalPaidIsLessOrEqualThanStockAndSold(custodian);

        sendToken(token_, address(this), msg.sender, amt_);
    }

    /*
    * @dev Return how much cdc token can be minted based on current collaterization.
    * @param token_ address cdc token that we want to find out how much is mintable.
    */
    function getAmtForSale(address token_) external view returns(uint256) {
        bytes32 domain = asc.domains(token_);
        uint maxMintableCdcV = 
            wdiv(
                add(
                    asc.totalDpassV(domain),
                    asc.totalDcdcV(domain)),
                asc.overCollRatio(domain));
        require(asc.cdcs(token_), "asm-token-is-not-cdc");

        return wdivT(
            sub(
                maxMintableCdcV,
                min(
                    asc.totalCdcV(domain),
                    maxMintableCdcV)),
            _getNewRate(token_),
            token_);
    }

    /*
    * @dev Get the total value share of custodian from the total cdc minted.
    */
    function cdcCustV(address custodian_) public view returns(uint) {
        bytes32 domain_ = asc.domains(custodian_);
        return wmul(
            asc.totalSoldCdcV(domain_),
            add(
                asc.totalDpassV(domain_),
                asc.totalDcdcV(domain_)) 
            > 0 ?
            wdiv(
                add(
                    asc.totalDpassCustV(custodian_),
                    asc.totalDcdcCustV(custodian_)),
                add(
                    asc.totalDpassV(domain_),
                    asc.totalDcdcV(domain_))):
            1 ether);
    }

    /*
    * @dev calculates multiple with decimals adjusted to match to 18 decimal precision to express base
    *      token Value
    */
    function wmulV(uint256 a_, uint256 b_, address token_) public view returns(uint256) {
        return wdiv(wmul(a_, b_), asc.decimals(token_));
    }

    /*
    * @dev calculates division with decimals adjusted to match to tokens precision
    */
    function wdivT(uint256 a_, uint256 b_, address token_) public view returns(uint256) {
        return wmul(wdiv(a_,b_), asc.decimals(token_));
    }

    /*
    * @dev function should only be used in case of unexpected events at custodian!! It will update the system collateral value and collateral value of dpass tokens at custodian.
    */
    function setCollateralDpass(uint positiveV_, uint negativeV_, address custodian_) public auth {
        _updateCollateralDpass(positiveV_, negativeV_, custodian_);

        emit LogForceUpdateCollateralDpass(msg.sender, positiveV_, negativeV_, custodian_);
    }

    /*
    * @dev function should only be used in case of unexpected events at custodian!! It will update the system collateral value and collateral value of dcdc tokens of custodian.
    */
    function setCollateralDcdc(uint positiveV_, uint negativeV_, address custodian_) public auth {
        _updateCollateralDcdc(positiveV_, negativeV_, custodian_);
        emit LogForceUpdateCollateralDcdc(msg.sender, positiveV_, negativeV_, custodian_);
    }

    /**
    * @dev Get base price_ for a diamond.
    */
    function basePrice(address token_, uint256 tokenId_) public returns  (uint) {
        return asc.basePrice(token_, tokenId_); 
    }
 
    /**
    * @dev Set base price_ for a diamond.
    */
    function _setBasePrice(address token_, uint256 tokenId_, uint256 price_) internal {
        bytes32 state_;
        require(asc.dpasses(token_), "asm-invalid-token-address");
        state_ = Dpass(token_).getState(tokenId_);
        address custodian_ = Dpass(token_).getCustodian(tokenId_);
        require(!asc.custodians(msg.sender) || msg.sender == custodian_, "asm-not-authorized");

        if(Dpass(token_).ownerOf(tokenId_) == address(this) &&
          (state_ == "valid" || state_ == "sale")) {                                        // TODO: test
            _updateCollateralDpass(price_, asc.basePrice(token_, tokenId_), custodian_);
            if(price_ >= asc.basePrice(token_, tokenId_))
                _requireCapCustV(custodian_);
        }

        asc.setBasePrice(token_, tokenId_, price_);
        emit LogBasePrice(msg.sender, token_, tokenId_, price_);
    }

    /*
    * @dev  Default function for eth payment. We accept ether as payment.
    */
    function () external payable {
        require(msg.value > 0, "asm-check-the-function-signature");
    }

    function _burn(address token_, uint256 amt_) internal {
        require(asc.cdcs(token_), "asm-token-is-not-cdc");
        DSToken(token_).burn(amt_);
        bytes32 domain = asc.domains(token_);

        asc.setTotalSoldCdcV(domain, sub(
            asc.totalSoldCdcV(domain), 
            min(
                wmulV(
                    amt_,
                    _updateRate(token_),
                    token_),
                asc.totalSoldCdcV(domain)))); // TODO: test

        _updateCdcV(token_);
    }

    /**
    * @dev Get exchange rate for a token
    */
    function _updateRate(address token_) internal returns (uint256 rate_) {
        require((rate_ = _getNewRate(token_)) > 0, "asm-updateRate-rate-gt-zero");
        asc.setRate(token_, rate_);
    }

    /*
    * @dev Updates totalCdcV and cdcV based on feed price of cdc token, and its total supply.
    */
    function _updateCdcV(address cdc_) internal {
        require(asc.cdcs(cdc_), "asm-not-a-cdc-token");
        bytes32 domain = asc.domains(cdc_);
        uint newCdcV_ = wmulV(DSToken(cdc_).totalSupply(), _updateRate(cdc_), cdc_);

        uint incrTotalCdcV = add(asc.totalCdcV(domain), newCdcV_);

        asc.setTotalCdcV(domain, 
            sub(
                incrTotalCdcV,
                min(
                    asc.cdcV(cdc_),
                    incrTotalCdcV)));

        asc.setCdcV(cdc_, newCdcV_);

        emit LogCdcValue(asc.totalCdcV(domain), domain, asc.cdcV(cdc_), cdc_);
    }

    /*
    * @dev Updates totalDdcV and dcdcV based on feed price of dcdc token, and its total supply.
    */
    function _updateTotalDcdcV(address dcdc_) internal {
        require(asc.dcdcs(dcdc_), "asm-not-a-dcdc-token");
        bytes32 domain = asc.domains(dcdc_);
        uint newDcdcV = wmulV(DSToken(dcdc_).totalSupply(), _updateRate(dcdc_), dcdc_);
        uint newTotalDcdcV = add(asc.totalDcdcV(domain), newDcdcV);
        asc.setTotalDcdcV(domain, 
            sub(
                newTotalDcdcV,
                min(
                    asc.dcdcV(dcdc_),
                    newTotalDcdcV)));
        
        asc.setDcdcV(dcdc_, newDcdcV);
        emit LogDcdcValue(asc.totalDcdcV(domain), domain, asc.cdcV(dcdc_), dcdc_);
    }

    /*
    * @dev Updates totalDdcCustV and dcdcCustV for a specific custodian, based on feed price of dcdc token, and its total supply.
    */
    function _updateDcdcV(address dcdc_, address custodian_) internal {
        require(asc.dcdcs(dcdc_), "asm-not-a-dcdc-token");
        require(asc.custodians(custodian_), "asm-not-a-custodian");
        uint newDcdcCustV = wmulV(DSToken(dcdc_).balanceOf(custodian_), _updateRate(dcdc_), dcdc_);
        uint newTotalDcdcCustV = add(asc.totalDcdcCustV(custodian_), newDcdcCustV);

        asc.setTotalDcdcCustV(custodian_, 
            sub(
                newTotalDcdcCustV,
                min(
                    asc.dcdcCustV(dcdc_, custodian_),
                    newTotalDcdcCustV)));

        asc.setDcdcCustV(dcdc_, custodian_, newDcdcCustV);

        emit LogDcdcCustodianValue(asc.totalDcdcCustV(custodian_), asc.dcdcCustV(dcdc_, custodian_), dcdc_, custodian_);

        _updateTotalDcdcV(dcdc_);
    }

    /**
    * @dev Get token_ / quote_currency rate from priceFeed
    * Revert transaction if not valid feed and manual value not allowed
    */
    function _getNewRate(address token_) private view returns (uint rate_) {
        bool feedValid;
        bytes32 usdRateBytes;

        require(
            address(0) != asc.priceFeed(token_),                            // require token to have a price feed
            "asm-no-price-feed");

        (usdRateBytes, feedValid) =
            TrustedFeedLike(asc.priceFeed(token_)).peek();                  // receive DPT/USD price
        if (feedValid) {                                                    // if feed is valid, load DPT/USD rate from it
            rate_ = uint(usdRateBytes);
        } else {
            require(asc.manualRate(token_), "Manual rate not allowed");     // if feed invalid revert if manualEthRate is NOT allowed
            rate_ = asc.rate(token_);
        }
    }

    /**
    * @dev System must be overcollaterized at all time. When it is not, then no cdc can be minted.
    */
    function _requireSystemCollaterized(bytes32 domain_) internal view returns(uint) {
        require(
            add(
                add(
                    asc.totalDpassV(domain_),
                    asc.totalDcdcV(domain_)),
                asc.dust()) >=
            wmul(
                asc.overCollRatio(domain_),
                asc.totalCdcV(domain_))
            , "asm-system-undercollaterized");
    }

    /**
    * @dev System must be overcollaterized at all time. When total cdc value times overCollRatio is not greater but
    * equal to total dpass value plus total dcdc value: no more cdc can be minted, but since overCollRemoveRatio is
    * less than overCollRatio, diamonds still can be removed by custodians. This is very helpful for them if system
    * is low on collateral.
    */
    function _requireSystemRemoveCollaterized(bytes32 domain_) internal view returns(uint) {
        require(
            add(
                add(
                    asc.totalDpassV(domain_),
                    asc.totalDcdcV(domain_)),
                asc.dust()) >=
            wmul(
                asc.overCollRemoveRatio(domain_),
                asc.totalCdcV(domain_))
            , "asm-sys-remove-undercollaterized");
    }

    /**
    * @dev The total value of tokens withdrawn by custodian as payment for their services must be less 
    *      than the total value of current dpass and dcdc stock, and total of dpass sold.
    */
    function _requireTotalPaidIsLessOrEqualThanStockAndSold(address custodian_) internal view {
        require(
            add(
                add(
                    add(
                        asc.totalDpassCustV(custodian_),
                        asc.totalDcdcCustV(custodian_)),
                    asc.soldDpassCustV(custodian_)),
                asc.dust()) >=
                add(
                    asc.paidDpassCustV(custodian_),
                    asc.paidCdcCustV(custodian_))
            , "asm-too-much-paid-to-custodian");
    }

    /*
    * @dev This function will revert if custodian has reached his value cap (capCustV - custodian capacity
    * value in base currency). Asset management enables to limit how much total worth
    * of diamonds each custodian can mint. This helps to avoid overexposure to some custodians, and avoid some custodian fraud cases.
    */
    function _requireCapCustV(address custodian_) internal view {
        if(asc.capCustV(custodian_) != uint(-1))
        require(
            add(asc.capCustV(custodian_), asc.dust()) >=
                add(
                    asc.totalDpassCustV(custodian_),
                    asc.totalDcdcCustV(custodian_)),
            "asm-custodian-reached-maximum-coll-value");
    }

    /*
    * @dev Updates total dpass value of a custodian, and the total dpass value of a domain.
    */
    function _updateCollateralDpass(uint positiveV_, uint negativeV_, address custodian_) internal {
        require(asc.custodians(custodian_), "asm-not-a-custodian");
        bytes32 domain = asc.domains(custodian_);
        uint newV = add(asc.totalDpassCustV(custodian_), positiveV_);

        asc.setTotalDpassCustV(custodian_, 
            sub(
                newV,
                min(
                    negativeV_,
                    newV)));

        newV = add(asc.totalDpassV(domain), positiveV_);

        asc.setTotalDpassV(domain, sub(
            newV,
            min(
                negativeV_,
                newV)));

        emit LogDpassValue(asc.totalDpassCustV(custodian_), asc.totalDpassV(domain), custodian_, domain);
    }

    /**
    * @dev Updates total dcdc customer value and total dcdc value for domain based on custodian collateral change.
    */
    function _updateCollateralDcdc(uint positiveV_, uint negativeV_, address custodian_) internal {
        require(asc.custodians(custodian_), "asm-not-a-custodian");
        bytes32 domain = asc.domains(custodian_);
        uint newV = add(asc.totalDcdcCustV(custodian_), positiveV_);
        asc.setTotalDcdcCustV(custodian_, sub(
            newV,
            min(
                negativeV_,
                newV)));
        newV = add(asc.totalDcdcV(domain), positiveV_);

        asc.setTotalDcdcV(domain, sub(
            newV,
            min(
                negativeV_,
                newV)));

        emit LogDcdcTotalCustodianValue(asc.totalDcdcCustV(custodian_), asc.totalDcdcV(domain), custodian_, domain);
    }

    /**
    * @dev send token or ether to destination
    */
    function sendToken(
        address token,
        address src,
        address payable dst,
        uint256 amount
    ) internal returns (bool){
        if (token == asc.eth() && amount > 0) {
            require(src == address(this), "wal-ether-transfer-invalid-src");
            dst.transfer(amount);
            emit LogTransferEth(src, dst, amount);
        } else {
            if (amount > 0) DSToken(token).transferFrom(src, dst, amount);   // transfer all of token to dst
        }
        return true;
    }
}

// TODO: be able to ban custodian sale
// TODO: check price multiplier for base price!! implement it to multiply basePrice and to be able to change the prices with only one tx.
