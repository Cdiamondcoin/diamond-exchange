pragma solidity ^0.5.11;

import "ds-math/math.sol";
import "ds-auth/auth.sol";
import "ds-token/token.sol";
import "ds-stop/stop.sol";
import "ds-note/note.sol";
import "dpass/Dpass.sol";


/**
* @dev Contract to get ETH/USD price
*/
contract TrustedFeedLike {
    function peek() external view returns (bytes32, bool);
}


contract SimpleAssetManagement is DSAuth, DSStop {

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

    mapping(
        address => mapping(
            uint => uint)) public basePrice;                // the base price used for collateral valuation
    mapping(address => bool) public custodians;             // returns true for custodians
    mapping(address => uint)                                // total base currency value of custodians collaterals
        public totalDpassCustV;
    mapping(address => uint) private rate;                  // current rate of a token in base currency
    mapping(address => uint) public cdcV;                   // base currency value of cdc token
    mapping(address => uint) public dcdcV;                  // base currency value of dcdc token
    mapping(address => uint) public totalDcdcCustV;         // total value of all dcdcs at custodian
    mapping(
        address => mapping(
            address => uint)) public dcdcCustV;             // dcdcCustV[dcdc][custodian] value of dcdc at custodian
    mapping(address => bool) public payTokens;              // returns true for tokens allowed to make payment to custodians with
    mapping(address => bool) public dpasses;                // returns true for dpass tokens allowed in this contract
    mapping(address => bool) public dcdcs;                  // returns true for tokens representing cdc assets (without gia number) that are allowed in this contract
    mapping(address => bool) public cdcs;                   // returns true for cdc tokens allowed in this contract
    mapping(address => uint) private decimals;              // stores decimals for each ERC20 token
    mapping(address => bool) public decimalsSet;            // stores decimals for each ERC20 token
    mapping(address => address) public priceFeed;           // price feed address for token
    mapping(address => uint) public tokenPurchaseRate;      // the average purchase rate of a token. This is the ...
                                                            // ... price of token at which we send it to custodian
    mapping(address => uint) public paidDpassCustV;         // total amount that has been withdrawn by custodian for dpasses and cdc in base currency
    mapping(address => uint) public paidCdcCustV;           // total amount that has been withdrawn by custodian for dpasses and cdc in base currency
    mapping(address => uint) public soldDpassCustV;         // totoal amount of all dpass tokens that have been sold by custodian
    mapping(address => bool) public manualRate;             // if manual rate is enabled then owner can update rates if feed not available
    mapping(address => bytes32) public domains;             // the domain that connects the set of cdc, dpass, and dcdc tokens, and custodians
    mapping(bytes32 => uint) public totalDpassV;            // total value of dpass collaterals in base currency
    mapping(bytes32 => uint) public totalDcdcV;             // total value of dcdc collaterals in base currency
    mapping(bytes32 => uint) public totalCdcV;              // total value of cdc tokens issued in base currency
    mapping(bytes32 => uint) public totalSoldDpassV;        // total value of cdc tokens issued in base currency
    mapping(bytes32 => uint) public totalSoldCdcV;          // total value of cdc tokens issued in base currency
    mapping(bytes32 => uint) public totalPaidDpassV;        // total value of cdc tokens issued in base currency
    mapping(bytes32 => uint) public totalPaidCdcV;          // total value of cdc tokens issued in base currency
    mapping(bytes32 => uint)
        public overCollRatio;                               // cdc can be minted as long as totalDpassV + totalDcdcV >= overCollRatio * totalCdcV
    mapping(bytes32 => uint)
        public overCollRemoveRatio;                         // dpass can be removed and dcdc burnt as long as totalDpassV + totalDcdcV >= overCollDpassRatio * totalCdcV
    mapping(address => uint) public capCustV;               // maximum value of dpass and dcdc tokens a custodian is allowed to mint

    uint public dust = 1000;                                // dust value is the largest value we still consider 0 ...
    bool public locked;                                     // variable prevents to exploit by recursively calling funcions
    address public eth = address(0xee);                     // we treat eth as DSToken() wherever we can, and this is the dummy address for eth

    struct Audit {                                          // struct storing the results of an audit
        address auditor;                                    // auditor who did the last audit
        uint256 status;                                     // status of audit if 0, all is well, otherwise represents the value of ...
                                                            // diamonds that there are problems with
        bytes32 descriptionHash;                            // hash of the description file that describes the last audit in detail. ...
                                                            // ... Auditors must have a detailed description of all the findings they had at ...
                                                            // ... custodian, and are legally fully responsible for their documents.
        bytes32 descriptionUrl;                             // url of the description file that details the results of the audit. File should be digitally signed. And the files total content should be hashed with keccak256() to make sure unmutability.
        uint nextAuditBefore;                               // proposed time of next audit. The audit should be at least at every 3 months.
    }

    mapping(address => Audit) public audit;                 // containing the last audit reports for all custodians.
    uint32 public auditInterval = 1776000;                  // represents 3 months of audit interwal in which an audit is mandatory for custodian.

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
        } else if (what_ == "overCollRemoveRatio") {
            bytes32 domain = value2_;
            overCollRemoveRatio[domain] = uint(value_);
            require(overCollRemoveRatio[domain] >= 1 ether, "asm-must-be-gt-1-ether");
            require(overCollRemoveRatio[domain] <= overCollRatio[domain], "asm-must-be-lt-overcollratio");

            _requireSystemRemoveCollaterized(domain); // TODO: check if this should hold or sthg else
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
            _updateTotalDcdcV(newDcdc);
        } else if (what_ == "cdcs") {
            bytes32 domain = value2_;
            address newCdc = addr(value_);
            bool enable = uint(value1_) > 0;
            if(enable) domains[newCdc] = domain;
            require(priceFeed[newCdc] != address(0), "asm-add-pricefeed-first");
            require(decimalsSet[newCdc], "asm-add-decimals-first");
            require(newCdc != address(0), "asm-cdc-address-zero");
            cdcs[newCdc] = enable;
            _updateCdcV(newCdc);
            _requireSystemCollaterized(domain);
        } else if (what_ == "dpasses") {
            bytes32 domain = value2_;
            address dpass = addr(value_);
            bool enable = uint(value1_) > 0;
            if(enable) domains[dpass] = domain;
            require(dpass != address(0), "asm-dpass-address-zero");
            dpasses[dpass] = enable;
        } else if (what_ == "approve") {                            // TODO: remove this for security reasons
            address token = addr(value_);
            address dst = addr(value1_);
            uint value = uint(value2_);
            require(decimalsSet[token],"asm-no-decimals-set-for-token");
            require(dst != address(0), "asm-dst-zero-address");
            DSToken(token).approve(dst, value);
        }  else if (what_ == "setApproveForAll") {                  // TODO: remove this for security reasons
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
        return rate[token_];
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
        require(custodians[custodian_], "asm-should-be-custodian");
        capCustV[custodian_] = capCustV_;
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
        require(custodians[custodian_], "asm-audit-not-a-custodian");
        require(auditInterval_ != 0, "asm-audit-interval-zero");

        minInterval_ = uint32(min(auditInterval_, auditInterval));
        Audit memory audit_ = Audit({
            auditor: msg.sender,
            status: status_,
            descriptionHash: descriptionHash_,
            descriptionUrl: descriptionUrl_,
            nextAuditBefore: block.timestamp + minInterval_
        });
        audit[custodian_] = audit_;
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
        bytes32 domain = domains[token_];

        require(
            dpasses[token_] || cdcs[token_] || payTokens[token_],
            "asm-invalid-token");

            require(
            !dpasses[token_] || Dpass(token_).getState(amtOrId_) == "sale",
            "asm-ntf-token-state-not-sale");

        if(dpasses[token_] && src_ == address(this)) {                     // custodian sells dpass to user
            custodian = Dpass(token_).getCustodian(amtOrId_);

            _updateCollateralDpass(
                0,
                basePrice[token_][amtOrId_],
                custodian);

            soldDpassCustV[custodian] = add(
                soldDpassCustV[custodian],
                basePrice[token_][amtOrId_]);

            totalSoldDpassV[domain] = add(                                  // TODO: test
                totalSoldDpassV[domain],
                basePrice[token_][amtOrId_]);      

            Dpass(token_).setState("valid", amtOrId_);

            _requireSystemCollaterized(domain);

        } else if (dst_ == address(this) && !dpasses[token_]) {             // user sells ERC20 token_ to sellers
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


        } else if (dst_ == address(this) && dpasses[token_]) {               // user sells erc721 token_ to custodians

            require(payTokens[token_], "asm-token-not-accepted");

            _updateCollateralDpass(
                basePrice[token_][amtOrId_],
                0,
                Dpass(token_).getCustodian(amtOrId_));

            soldDpassCustV[custodian] = sub(
                soldDpassCustV[custodian],
                min(
                    basePrice[token_][amtOrId_],
                    soldDpassCustV[custodian]));

            totalSoldDpassV[domain] = sub(                                  // TODO: test
                totalSoldDpassV[domain],
                min(
                    basePrice[token_][amtOrId_],
                    totalSoldDpassV[domain]));      

            Dpass(token_).setState("valid", amtOrId_);

        } else if (dpasses[token_]) {                                        // user sells erc721 token_ to other users

            // require(payTokens[token_], "asm-token-not-accepted");        // TODO: test user wants to steal others approved tokens

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
        bytes32 domain = domains[token_];
        require(cdcs[token_], "asm-token-is-not-cdc");
        DSToken(token_).mint(dst_, amt_);
        _updateCdcV(token_);

        totalSoldCdcV[domain] = add(
            totalSoldCdcV[domain], 
            wmulV(amt_, _updateRate(token_), token_)); // TODO: test

        _requireSystemCollaterized(domain);
    }

    /**
    * @dev Mints dcdc tokens for custodians. This function should only be run by custodians.
    * @param token_ address dcdc token_ that needs to be minted
    * @param dst_ address the address for whom dcdc token will be minted for.
    * @param amt_ uint amount to be minted
    */
    function mintDcdc(address token_, address dst_, uint256 amt_) public nonReentrant auth {
        require(custodians[msg.sender], "asm-not-a-custodian");
        require(!custodians[msg.sender] || dst_ == msg.sender, "asm-can-not-mint-for-dst");
        require(dcdcs[token_], "asm-token-is-not-cdc");
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
        bytes32 domain = domains[token_];

        require(custodians[msg.sender], "asm-not-a-custodian");
        require(!custodians[msg.sender] || src_ == msg.sender, "asm-can-not-burn-from-src");
        require(dcdcs[token_], "asm-token-is-not-cdc");
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
        require(dpasses[token_], "asm-mnt-not-a-dpass-token");
        require(custodians[msg.sender], "asm-not-a-custodian");
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

        _setBasePrice(token_, id_, price_);
        _requireCapCustV(custodian_);
    }

    /*
    * @dev Set state for dpass. Should be used primarily by custodians.
    */
    function setStateDpass(address token_, uint256 tokenId_, bytes8 state_) public nonReentrant auth {
        bytes32 prevState_;
        address custodian_;

        require(dpasses[token_], "asm-mnt-not-a-dpass-token");

        custodian_ = Dpass(token_).getCustodian(tokenId_);
        require(
            !custodians[msg.sender] ||
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
            _updateCollateralDpass(0, basePrice[token_][tokenId_], custodian_);
            _requireSystemRemoveCollaterized(domains[token_]);
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
            _updateCollateralDpass(basePrice[token_][tokenId_], 0, custodian_);
        }

        Dpass(token_).setState(state_, tokenId_);
    }

    /*
    * @dev Withdraw tokens for selling dpass, and cdc. Custodians do not receive money directly from selling dpass, ot cdc, but
    * they must withdraw their tokens.
    */
    function withdraw(address token_, uint256 amt_) public nonReentrant auth {
        address custodian = msg.sender;
        bytes32 domain = domains[custodian];
        require(custodians[custodian], "asm-not-a-custodian");
        require(payTokens[token_], "asm-cant-withdraw-token");
        require(tokenPurchaseRate[token_] > 0, "asm-token-purchase-rate-invalid");

        uint tokenV = wmulV(tokenPurchaseRate[token_], amt_, token_);
        uint withdrawDpassV = min(
            tokenV, 
            sub(
                soldDpassCustV[custodian], 
                min(
                    paidDpassCustV[custodian],
                    soldDpassCustV[custodian])
            ));
        paidDpassCustV[custodian] = add(paidDpassCustV[custodian], withdrawDpassV);
        totalPaidDpassV[domain] = add(totalPaidDpassV[domain], withdrawDpassV);
        tokenV -= withdrawDpassV;  // this is never going to underflow
        uint custodianCdcV = cdcCustV(custodian);
        require(tokenV <= 
            add(
                sub(
                    custodianCdcV,
                    min(
                        custodianCdcV,
                        paidCdcCustV[custodian])),
                dust),
            "asm-too-much-to-withdraw");
        paidCdcCustV[custodian] = add(paidCdcCustV[custodian], tokenV);
        totalPaidCdcV[domain] = add(totalPaidCdcV[domain], tokenV);
        _requireTotalPaidIsLessOrEqualThanStockAndSold(custodian);

        sendToken(token_, address(this), msg.sender, amt_);
    }

    /*
    * @dev Return how much cdc token can be minted based on current collaterization.
    * @param token_ address cdc token that we want to find out how much is mintable.
    */
    function getAmtForSale(address token_) external view returns(uint256) {
        bytes32 domain = domains[token_];
        uint maxMintableCdcV = 
            wdiv(
                add(
                    totalDpassV[domain],
                    totalDcdcV[domain]),
                overCollRatio[domain]);
        require(cdcs[token_], "asm-token-is-not-cdc");

        return wdivT(
            sub(
                maxMintableCdcV,
                min(
                    totalCdcV[domain],
                    maxMintableCdcV)),
            _getNewRate(token_),
            token_);
    }

    /*
    * @dev Get the total value share of custodian from the total cdc minted.
    */
    function cdcCustV(address custodian_) public view returns(uint) {
        bytes32 domain_ = domains[custodian_];
        return wmul(
            totalSoldCdcV[domain_],
            add(
                totalDpassV[domain_],
                totalDcdcV[domain_]) 
            > 0 ?
            wdiv(
                add(
                    totalDpassCustV[custodian_],
                    totalDcdcCustV[custodian_]),
                add(
                    totalDpassV[domain_],
                    totalDcdcV[domain_])):
            1 ether);
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
    * @dev Set base price_ for a diamond.
    */
    function _setBasePrice(address token_, uint256 tokenId_, uint256 price_) internal {
        bytes32 state_;
        require(dpasses[token_], "asm-invalid-token-address");
        state_ = Dpass(token_).getState(tokenId_);
        address custodian_ = Dpass(token_).getCustodian(tokenId_);
        require(!custodians[msg.sender] || msg.sender == custodian_, "asm-not-authorized");

        if(Dpass(token_).ownerOf(tokenId_) == address(this) &&
          (state_ == "valid" || state_ == "sale")) {                                        // TODO: test
            _updateCollateralDpass(price_, basePrice[token_][tokenId_], custodian_);
            if(price_ >= basePrice[token_][tokenId_])
                _requireCapCustV(custodian_);
        }

        basePrice[token_][tokenId_] = price_;
        emit LogBasePrice(msg.sender, token_, tokenId_, price_);
    }

    /*
    * @dev  Default function for eth payment. We accept ether as payment.
    */
    function () external payable {
        require(msg.value > 0, "asm-check-the-function-signature");
    }

    function _burn(address token_, uint256 amt_) internal {
        require(cdcs[token_], "asm-token-is-not-cdc");
        DSToken(token_).burn(amt_);
        bytes32 domain = domains[token_];

        totalSoldCdcV[domain] = sub(
            totalSoldCdcV[domain], 
            min(
                wmulV(
                    amt_,
                    _updateRate(token_),
                    token_),
                totalSoldCdcV[domain])); // TODO: test

        _updateCdcV(token_);
    }

    /**
    * @dev Get exchange rate for a token
    */
    function _updateRate(address token_) internal returns (uint256 rate_) {
        require((rate_ = _getNewRate(token_)) > 0, "asm-updateRate-rate-gt-zero");
        rate[token_] = rate_;
    }

    /*
    * @dev Updates totalCdcV and cdcV based on feed price of cdc token, and its total supply.
    */
    function _updateCdcV(address cdc_) internal {
        require(cdcs[cdc_], "asm-not-a-cdc-token");
        bytes32 domain = domains[cdc_];
        uint newCdcV_ = wmulV(DSToken(cdc_).totalSupply(), _updateRate(cdc_), cdc_);

        uint incrTotalCdcV = add(totalCdcV[domain], newCdcV_);

        totalCdcV[domain] = 
            sub(
                incrTotalCdcV,
                min(
                    cdcV[cdc_],
                    incrTotalCdcV));

        cdcV[cdc_] = newCdcV_;

        emit LogCdcValue(totalCdcV[domain], domain, cdcV[cdc_], cdc_);
    }

    /*
    * @dev Updates totalDdcV and dcdcV based on feed price of dcdc token, and its total supply.
    */
    function _updateTotalDcdcV(address dcdc_) internal {
        require(dcdcs[dcdc_], "asm-not-a-dcdc-token");
        bytes32 domain = domains[dcdc_];
        uint newDcdcV = wmulV(DSToken(dcdc_).totalSupply(), _updateRate(dcdc_), dcdc_);
        uint newTotalDcdcV = add(totalDcdcV[domain], newDcdcV);
        totalDcdcV[domain] = 
            sub(
                newTotalDcdcV,
                min(
                    dcdcV[dcdc_],
                    newTotalDcdcV));
        
        dcdcV[dcdc_] = newDcdcV;
        emit LogDcdcValue(totalDcdcV[domain], domain, cdcV[dcdc_], dcdc_);
    }

    /*
    * @dev Updates totalDdcCustV and dcdcCustV for a specific custodian, based on feed price of dcdc token, and its total supply.
    */
    function _updateDcdcV(address dcdc_, address custodian_) internal {
        require(dcdcs[dcdc_], "asm-not-a-dcdc-token");
        require(custodians[custodian_], "asm-not-a-custodian");
        uint newDcdcCustV = wmulV(DSToken(dcdc_).balanceOf(custodian_), _updateRate(dcdc_), dcdc_);
        uint newTotalDcdcCustV = add(totalDcdcCustV[custodian_], newDcdcCustV);

        totalDcdcCustV[custodian_] = 
            sub(
                newTotalDcdcCustV,
                min(
                    dcdcCustV[dcdc_][custodian_],
                    newTotalDcdcCustV));

        dcdcCustV[dcdc_][custodian_] = newDcdcCustV;

        emit LogDcdcCustodianValue(totalDcdcCustV[custodian_], dcdcCustV[dcdc_][custodian_], dcdc_, custodian_);

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

    /**
    * @dev System must be overcollaterized at all time. When it is not, then no cdc can be minted.
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
    * @dev System must be overcollaterized at all time. When total cdc value times overCollRatio is not greater but
    * equal to total dpass value plus total dcdc value: no more cdc can be minted, but since overCollRemoveRatio is
    * less than overCollRatio, diamonds still can be removed by custodians. This is very helpful for them if system
    * is low on collateral.
    */
    function _requireSystemRemoveCollaterized(bytes32 domain_) internal view returns(uint) {
        require(
            add(
                add(
                    totalDpassV[domain_],
                    totalDcdcV[domain_]),
                dust) >=
            wmul(
                overCollRemoveRatio[domain_],
                totalCdcV[domain_])
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
                        totalDpassCustV[custodian_],
                        totalDcdcCustV[custodian_]),
                    soldDpassCustV[custodian_]),
                dust) >=
                add(
                    paidDpassCustV[custodian_],
                    paidCdcCustV[custodian_])
            , "asm-too-much-paid-to-custodian");
    }

    /*
    * @dev This function will revert if custodian has reached his value cap (capCustV - custodian capacity
    * value in base currency). Asset management enables to limit how much total worth
    * of diamonds each custodian can mint. This helps to avoid overexposure to some custodians, and avoid some custodian fraud cases.
    */
    function _requireCapCustV(address custodian_) internal view {
        if(capCustV[custodian_] != uint(-1))
        require(
            add(capCustV[custodian_], dust) >=
                add(
                    totalDpassCustV[custodian_],
                    totalDcdcCustV[custodian_]),
            "asm-custodian-reached-maximum-coll-value");
    }

    /*
    * @dev Updates total dpass value of a custodian, and the total dpass value of a domain.
    */
    function _updateCollateralDpass(uint positiveV_, uint negativeV_, address custodian_) internal {
        require(custodians[custodian_], "asm-not-a-custodian");
        bytes32 domain = domains[custodian_];
        uint newV = add(totalDpassCustV[custodian_], positiveV_);

        totalDpassCustV[custodian_] = 
            sub(
                newV,
                min(
                    negativeV_,
                    newV));

        newV = add(totalDpassV[domain], positiveV_);

        totalDpassV[domain] = sub(
            newV,
            min(
                negativeV_,
                newV));

        emit LogDpassValue(totalDpassCustV[custodian_], totalDpassV[domain], custodian_, domain);
    }

    /**
    * @dev Updates total dcdc customer value and total dcdc value for domain based on custodian collateral change.
    */
    function _updateCollateralDcdc(uint positiveV_, uint negativeV_, address custodian_) internal {
        require(custodians[custodian_], "asm-not-a-custodian");
        bytes32 domain = domains[custodian_];
        uint newV = add(totalDcdcCustV[custodian_], positiveV_);
        totalDcdcCustV[custodian_] = sub(
            newV,
            min(
                negativeV_,
                newV));
        newV = add(totalDcdcV[domain], positiveV_);

        totalDcdcV[domain] = sub(
            newV,
            min(
                negativeV_,
                newV));

        emit LogDcdcTotalCustodianValue(totalDcdcCustV[custodian_], totalDcdcV[domain], custodian_, domain);
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

// TODO: be able to ban custodian sale
// TODO: check price multiplier for base price!! implement it to multiply basePrice and to be able to change the prices with only one tx.
