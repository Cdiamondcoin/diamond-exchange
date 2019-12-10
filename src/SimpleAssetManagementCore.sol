pragma solidity ^0.5.11;

 contract SimpleAssetManagementCore {

    mapping(
        address => mapping(
            uint => uint)) public basePrice;                // the base price used for collateral valuation
    mapping(address => bool) public custodians;             // returns true for custodians
    mapping(address => uint)                                // total base currency value of custodians collaterals
        public totalDpassCustV;
    mapping(address => uint) private rates;                 // current rate of a token in base currency
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
    mapping(address => uint) private decimal;               // stores decimals for each ERC20 token
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

    mapping(address => Audit) public audits;                 // containing the last audit reports for all custodians.
    uint32 public auditInterval = 1776000;                  // represents 3 months of audit interwal in which an audit is mandatory for custodian.
    mapping(address => bool) allowed;                       // contracts that are allowed to use us

    constructor(address owner) public {
        allowed[owner] = true;
    }
    

    function setBasePrice(address token_, uint tokenId_, uint set) public aut {
        basePrice[token_][tokenId_] = set;
    }

    function setCustodians(address custodian_, bool set) public aut {
        custodians[custodian_] = set;
    }

    function setTotalDpassCustV(address custodian_, uint set) public aut {
        totalDpassCustV[custodian_] = set;
    }
    
    function rate(address token_) public view aut returns(uint) {
        return rates[token_];
    }

    function setRate(address token_, uint set) public aut {
        rates[token_] = set;
    }

    function setCdcV(address cdc_, uint set) public aut {
        cdcV[cdc_] = set;
    }

    function setDcdcV(address dcdc_, uint set) public aut {
        dcdcV[dcdc_] = set;
    }

    function setTotalDcdcCustV(address custodian_, uint set) public aut {
        totalDcdcCustV[custodian_] = set;
    }

    function setDcdcCustV(address dcdc_, address custodian_, uint set) public aut {
        dcdcCustV[dcdc_][custodian_] = set;
    }

    function setPayTokens(address payToken_, bool set) public aut {
        payTokens[payToken_] = set;
    }

    function setDpasses(address dpass_, bool set) public aut {
        dpasses[dpass_] = set;
    }

    function setDcdcs(address dcdc_, bool set) public aut {
        dcdcs[dcdc_] = set;
    }

    function setCdcs(address cdc_, bool set) public aut {
        cdcs[cdc_] = set;
    }

    function decimals(address token_) public view returns(uint) {
        return decimal[token_];
    }

    function setDecimals(address token_, uint set) public aut {
        decimal[token_] = set;
    }

    function setDecimalsSet(address token_, bool set) public aut {
        decimalsSet[token_] = set;
    }

    function setPriceFeed(address token_, address set) public aut {
        priceFeed[token_] = set;
    }

    function setTokenPurchaseRate(address token_, uint set) public aut {
        tokenPurchaseRate[token_] = set;
    }

    // ... price of token at which we send it to custodian
    function setPaidDpassCustV(address custodian_, uint set) public aut {
        paidDpassCustV[custodian_] = set;
    }

    function setPaidCdcCustV(address custodian_, uint set) public aut {
        paidCdcCustV[custodian_] = set;
    }

    function setSoldDpassCustV(address custodian_, uint set) public aut {
        soldDpassCustV[custodian_] = set;
    }

    function setManualRate(address token_, bool set) public aut {
        manualRate[token_] = set;
    }

    function setDomains(address tokenOrActor_, bytes32 set) public aut {
        domains[tokenOrActor_] = set;
    }

    function setTotalDpassV(bytes32 domain_, uint set) public aut {
        totalDpassV[domain_] = set;
    }

    function setTotalDcdcV(bytes32 domain_, uint set) public aut {
        totalDcdcV[domain_] = set;
    }

    function setTotalCdcV(bytes32 domain_, uint set) public aut {
        totalCdcV[domain_] = set;
    }

    function setTotalSoldDpassV(bytes32 domain_, uint set) public aut {
        totalSoldDpassV[domain_] = set;
    }

    function setTotalSoldCdcV(bytes32 domain_, uint set) public aut {
        totalSoldCdcV[domain_] = set;
    }

    function setTotalPaidDpassV(bytes32 domain_, uint set) public aut {
        totalPaidDpassV[domain_] = set;
    }

    function setTotalPaidCdcV(bytes32 domain_, uint set) public aut {
        totalPaidCdcV[domain_] = set;
    }

    function setOverCollRatio(bytes32 domain_, uint set) public aut {
        overCollRatio[domain_] = set;
    }

    function setOverCollRemoveRatio(bytes32 domain_, uint set) public aut {
        overCollRemoveRatio[domain_] = set;
    }

    function setCapCustV(address custodian_, uint set) public aut {
        capCustV[custodian_] = set;
    }

    function setAllowed(address owner_, bool set) public aut {
		allowed[owner_] = set;
    }

    function setAudit(
        address custodian_,        
        address auditor,
        uint256 status,
        bytes32 descriptionHash,
        bytes32 descriptionUrl,
        uint nextAuditBefore
    ) public aut {
        audits[custodian_] = Audit({
            auditor: auditor,
            status: status,
            descriptionHash: descriptionHash,
            descriptionUrl: descriptionUrl,
            nextAuditBefore: nextAuditBefore
        });
    }

    function audit(address custodian_) public returns 
    (
        address auditor,
        uint256 status,
        bytes32 descriptionHash,
        bytes32 descriptionUrl,
        uint nextAuditBefore
    ){
        Audit storage audit_ = audits[custodian_];
        auditor = audit_.auditor;
        status = audit_.status;
        descriptionHash = audit_.descriptionHash;
        descriptionUrl = audit_.descriptionUrl;
    }

//-----------------------------------------------

    modifier aut {
        require(allowed[msg.sender], "asc-not-authorized");
        _;
    } 
}
