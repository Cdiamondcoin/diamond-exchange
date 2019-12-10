pragma solidity ^0.5.11;

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
    mapping(address =y bool) allowed;                       // contracts that are allowed to use us

    constructor(address owner) {
        allowed[owner] = true;
    }
    
    mi

    setBasePrice() 
