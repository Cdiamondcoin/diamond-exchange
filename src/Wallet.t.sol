pragma solidity ^0.5.11;

import "ds-test/test.sol";
import "ds-math/math.sol";
import "ds-token/token.sol";
import "dpass/Dpass.sol";
import "./Wallet.sol";

contract TokenUser {
    Wallet wal;

    // Equals to `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`
    // which can be also obtained as `IERC721Receiver(0).onERC721Received.selector`
    bytes4 private constant _ERC721_RECEIVED = 0x150b7a02;
    

    constructor(address payable _wal) public {
        wal = Wallet(_wal);
    }

    function onERC721Received(address sender_, address from_, uint256 tokenId_, bytes memory data_) public pure returns (bytes4) {
        sender_;
        from_;
        tokenId_;
        data_;
        return _ERC721_RECEIVED;    
    } 

    function doTransferWallet(address token_, address payable dst, uint256 amt) public returns (bool) {
        return wal.transfer(token_, dst, amt);
    }

    function doTransferFromWallet(address token_, address src, address payable dst, uint256 amt) public returns (bool) {
        return wal.transferFrom(token_, src, dst, amt);
    }

    function doTotalSupplyWallet(address token_) public view returns (uint) {
        return wal.totalSupply(token_);
    }

    function doBalanceOfWallet(address token_, address src) public view returns (uint) {
        return wal.balanceOf(token_, src);
    }

    function doAllowanceWallet(address token_, address src, address guy) public view returns (uint) {
        return wal.allowance(token_, src, guy);
    }

    function doApproveWallet(address token_, address guy, uint wad) public {
        wal.approve(token_, guy, wad);
    }

    function doTransferToken(address token_, address payable dst, uint256 amt) public {
        DSToken(token_).transfer(dst, amt);
    }

    function doTransferFromToken(address token_, address src, address payable dst, uint256 amt) public returns (bool) {
        DSToken(token_).transferFrom(src, dst, amt);
    }

    function doTransferFrom721(address token_, address src, address payable dst, uint256 amt) public {
        Dpass(token_).transferFrom(src, dst, amt);
    }

    function doTotalSupplyToken(address token_) public view returns (uint) {
        return DSToken(token_).totalSupply();
    }

    function doBalanceOfToken(address token_, address src) public view returns (uint) {
        return DSToken(token_).balanceOf(src);
    }

    function doAllowanceToken(address token_, address src, address guy) public view returns (uint) {
        return DSToken(token_).allowance(src, guy);
    }

    function doApproveToken(address token_, address guy, uint wad) public {
        DSToken(token_).approve(guy, wad);
    }

    function () external payable {}
}


contract WalletTest is DSTest, DSMath {
    event LogTest(uint256 what);
    event LogTest(bool what);
    event LogTest(address what);
    event LogTest(bytes32 what);

    mapping(address => uint) dpassId;
    uint constant initialBalance = 1000;
    DSToken dpt;
    address eth;
    Dpass dpass;
    TokenUser user;
    address payable userAddr;
    Wallet wal;
    address payable walAddr;
    address self;
    address approved;
    address operator;
    uint initEth;
    uint initDpt;
    bool showActualExpected;
    TokenUser public seller;
    mapping(address => uint) dust;
    mapping(address => bool) dustSet;
    address public token;
    address public to;
    address public from;
    uint public tokenId;

    function setUp() public {
        dpt = new DSToken("DPT");
        wal = new Wallet();
        dpass = new Dpass();
        walAddr = address(uint160(address(wal)));
        eth = address(0xee);
        user = new TokenUser(walAddr);
        seller = new TokenUser(walAddr);
        approved = address(new TokenUser(walAddr));
        operator = address(new TokenUser(walAddr));
        to = address(new TokenUser(walAddr));
        userAddr = address(uint160(address(address(user))));
        self = address(this);
        dpt.mint(initialBalance * 1000);

        dpt.transfer(walAddr, initialBalance);
        dpt.transfer(userAddr, initialBalance);
        walAddr.transfer(initialBalance);
        userAddr.transfer(initialBalance);
        dpt.approve(userAddr, 100);
        initEth = address(this).balance;
        initDpt = dpt.balanceOf(address(this));

        Dpass(dpass).setCccc("BR,IF,F,0.01", true);
        dpassId[address(user)] = Dpass(dpass).mintDiamondTo(
            address(user),                                                               // address _to,
            address(seller),                                                             // address _custodian
            "gia",                                                              // bytes32 _issuer,
            "2141438167",                                                       // bytes32 _report,
            "sale",                                                             // bytes32 _state,
            "BR,IF,F,0.01",
            0.2 * 100,
            bytes32(uint(0xc0a5d062e13f99c8f70d19dc7993c2f34020a7031c17f29ce2550315879006d7)), // bytes32 _attributesHash
            "20191101"
        );

        Dpass(dpass).setCccc("BR,IF,G,0.01", true);
        dpassId[address(wal)] = Dpass(dpass).mintDiamondTo(
            address(wal),                                                               // address _to,
            address(seller),                                                             // address _custodian
            "gia",                                                              // bytes32 _issuer,
            "22222222",                                                         // bytes32 _report,
            "sale",                                                             // bytes32 _state,
            "BR,IF,G,0.01",
            0.2 * 100,
            bytes32(uint(0xc0a5d062e13f99c8f70d19dc7993c2f34020a7031c17f29ce2550315879006d7)), // bytes32 _attributesHash
            "20191101"
        );

        _setDust();
    }

    function _setDust() internal {
        dust[address(dpt)] = 10000;
        dust[address(eth)] = 10000;
        dust[address(dpass)] = 10000;

        dustSet[address(dpt)] = true;
        dustSet[address(eth)] = true;
        dustSet[address(dpass)] = true;

    }

    function () external payable {
    }

    function logMsgActualExpected(bytes32 logMsg, uint256 actual_, uint256 expected_, bool showActualExpected_) public {
        emit log_bytes32(logMsg);
        if(showActualExpected_ || showActualExpected) {
            emit log_bytes32("actual");
            emit LogTest(actual_);
            emit log_bytes32("expected");
            emit LogTest(expected_);
        }
    }
    function logMsgActualExpected(bytes32 logMsg, address actual_, address expected_, bool showActualExpected_) public {
        emit log_bytes32(logMsg);
        if(showActualExpected_ || showActualExpected) {
            emit log_bytes32("actual");
            emit LogTest(actual_);
            emit log_bytes32("expected");
            emit LogTest(expected_);
        }
    }

    function assertEqDustLog(bytes32 logMsg, uint256 actual_, uint256 expected_, address decimalToken) public {
        logMsgActualExpected(logMsg, actual_, expected_, !isEqualDust(actual_, expected_, decimalToken));
        assertEqDust(actual_, expected_, decimalToken);
    }

    function assertEqDustLog(bytes32 logMsg, uint256 actual_, uint256 expected_) public {
        logMsgActualExpected(logMsg, actual_, expected_, !isEqualDust(actual_, expected_));
        assertEqDust(actual_, expected_);
    }

    function assertEqLog(bytes32 logMsg, address actual_, address expected_) public {
        logMsgActualExpected(logMsg, actual_, expected_, false);
        assertEq(actual_, expected_);
    }

    function assertEqLog(bytes32 logMsg, uint256 actual_, uint256 expected_) public {
        logMsgActualExpected(logMsg, actual_, expected_, false);
        assertEq(actual_, expected_);
    }

    function assertEqLog(bytes32 logMsg, bool actual_, bool  expected_) public {
        assertEqLog(
            logMsg, 
            actual_ ? uint(1) : uint(0),
            expected_ ? uint(1) : uint(0)
        );
    }

    function assertNotEqualLog(bytes32 logMsg, address actual_, address expected_) public {
        logMsgActualExpected(logMsg, actual_, expected_, actual_ == expected_);
        assertTrue(actual_ != expected_);
    } 

    /*
    * @dev Compare two numbers with round-off errors considered.
    * Assume that the numbers have the decimals of token.
    */
    function assertEqDust(uint a_, uint b_, address token_) public {
        assertTrue(isEqualDust(a_, b_, token_));
    }

    /*
    * @dev Compare two numbers with round-off errors considered.
    * Assume that the numbers are 18 decimals precision.
    */
    function assertEqDust(uint a_, uint b_) public {
        assertEqDust(a_, b_, eth);
    }

    function isEqualDust(uint a_, uint b_) public view returns (bool) {
        return isEqualDust(a_, b_, eth);
    }

    function isEqualDust(uint a_, uint b_, address token_) public view returns (bool) {
        uint diff = a_ - b_;
        require(dustSet[token_], "Dust limit must be set to token_.");
        uint dustT = dust[token_];
        return diff < dustT || uint(-1) - diff < dustT;
    }

    function testWalletTransferWalletWal() public {
        uint sentAmount = 250;
        wal.transfer(address(dpt), userAddr, sentAmount);
        assertEq(wal.balanceOf(address(dpt), userAddr), add(initialBalance, sentAmount));
        assertEq(wal.balanceOf(address(dpt), address(uint160(walAddr))), sub(initialBalance, sentAmount));
    }

    function testWalletTransferEthWalletWal() public {
        uint sentAmount = 250;
        wal.transfer(eth, userAddr, sentAmount);
        assertEq(userAddr.balance,  add(initialBalance, sentAmount));
        assertEq(walAddr.balance, sub(initialBalance, sentAmount));
    }

    function testWalletTransferFromWalletWal() public {
        uint sentAmount = 250;
        user.doApproveToken(address(dpt), walAddr, sentAmount);

        wal.transferFrom(address(dpt), userAddr, address(uint160(address(this))),  sentAmount);
        assertEq(
            wal.balanceOf(address(dpt), address(address(user))), 
            sub(initialBalance, sentAmount));
        assertEq(
            wal.balanceOf(address(dpt), address(uint160(address(this)))),
            add(initDpt, sentAmount));
    }

    function testWalletTotalSupplyWalletWal() public {
        uint totalSupply = wal.totalSupply(address(dpt));
        assertEq(totalSupply, initialBalance * 1000);
    }

    function testFailWalletTotalSupplyEthWalletWal() public view {
        wal.totalSupply(eth);
    }

    function testWalletBalanceOfWalletWal() public {
        assertEq(wal.balanceOf(address(dpt), userAddr), initialBalance);
    }

    function testWalletBalanceOfEthWalletWal() public {
        assertEq(wal.balanceOf(eth, userAddr), initialBalance);
    }

    function testWalletAllowanceWalletWal() public {
        assertEq(wal.allowance(address(dpt), address(this), userAddr), 100);
    }

    function testFailWalletAllowanceEthWalletWal() public view {
        wal.allowance(eth, address(this), userAddr);
    }

    function testWalletApproveWalletWal() public {        

        wal.approve(address(dpt), userAddr, 500);
        assertEq(wal.allowance(address(dpt), walAddr, userAddr), 500);

        user.doTransferFromToken(address(dpt), walAddr, userAddr, 500);
        
        assertEq(wal.balanceOf(address(dpt), userAddr), add(initialBalance, 500));
        assertEq(wal.balanceOf(address(dpt), walAddr), sub(initialBalance, 500));
    }

    function testFailWalletApproveWithoutAuthWalletWal() public {        
        wal.approve(address(dpt), userAddr, 500);
        user.doTransferFromToken(address(dpt), address(this), userAddr, 501);
    }

    function testFailWalletAboveApproveWalletWal() public {
        wal.approve(eth, userAddr, 500);
    }

    function testFailWalletTransferByUserWalletWal() public {
        user.doTransferWallet(address(dpt), userAddr, 500);
    }

    function testFailWalletTransferFromByUserWalletWal() public {
        wal.approve(address(dpt), userAddr, 500);
        user.doTransferFromWallet(address(dpt), walAddr, userAddr, 500);
    }

    function testFailWalletApproveByUserWalletWal() public {
        user.doApproveWallet(address(dpt), userAddr, 500);
    }

    function testWalletSetUserAsOwnerTransferByUserWalletWal() public {
        wal.setOwner(userAddr);
        user.doTransferWallet(address(dpt), userAddr, 500);
    }

    function testWalletSetUserAsOwnerTransferFromByUserWalletWal() public {
        wal.approve(address(dpt), userAddr, 500);
        wal.setOwner(userAddr);
        user.doTransferFromWallet(address(dpt), walAddr, userAddr, 500);
    }

    function testWalletSetUserAsOwnerApproveByUserWalletWal() public {
        wal.setOwner(userAddr);
        user.doApproveWallet(address(dpt), userAddr, 500);
    }

    function testBalanceOf721Wal() public {
        assertEqLog("balanceOf() dpt addr(user) is 1", wal.balanceOf721(address(dpass), address(user)), 1);
        assertEqLog("balanceOf() dpt addr(wal) is 1", wal.balanceOf721(address(dpass), address(wal)), 1);
        wal.transfer721(address(dpass), address(user), dpassId[address(wal)]);
        assertEqLog("balanceOf() dpt addr(user) is 2", wal.balanceOf721(address(dpass), address(user)), 2);
        assertEqLog("balanceOf() dpt addr(wal) is 0", wal.balanceOf721(address(dpass), address(wal)), 0);
    }

    function testOwnerOf721Wal() public {
        assertEqLog("ownerOf() is address(user)", wal.ownerOf721(address(dpass), dpassId[address(user)]), address(user));
        assertEqLog("ownerOf() is address(wal)", wal.ownerOf721(address(dpass), dpassId[address(wal)]), address(wal));
        wal.transfer721(address(dpass), address(user), dpassId[address(wal)]);
        assertEqLog("ownerOf() is address(user)", wal.ownerOf721(address(dpass), dpassId[address(user)]), address(user));
        assertEqLog("ownerOf() is address(user)", wal.ownerOf721(address(dpass), dpassId[address(wal)]), address(user));
    }

    function testApprove721Wal() public {
        wal.approve721(address(dpass), address(user), dpassId[address(wal)]);
        assertEqLog("user approved by address(wal)", dpass.getApproved(dpassId[address(wal)]), address(user));
        
    }

    function testGetApproved721Wal() public {
        
        assertEqLog("user approved by address(wal)", dpass.getApproved(dpassId[address(wal)]), address(0));
        
        wal.approve721(address(dpass), address(user), dpassId[address(wal)]);
        assertEqLog("user approved by address(wal)", dpass.getApproved(dpassId[address(wal)]), address(user));
        user.doTransferFrom721(address(dpass), address(user), address(uint160(address(to))), dpassId[address(user)]);
        assertEqLog("new owner is to", dpass.ownerOf(dpassId[address(user)]), to);
    }

    function testSetApprovalForAll721Wal() public {
        wal.setApprovalForAll721(address(dpass), to, true);
        assertEqLog("addr approved by address(wal)", dpass.isApprovedForAll(address(wal), address(to)), true);
    }

    function testIsApprovedForAll721Wal() public {
        wal.setApprovalForAll721(address(dpass), to, true);
        assertEqLog("addr approved by address(wal)", dpass.isApprovedForAll(address(wal), address(to)), true);
        dpass.isApprovedForAll(address(wal), address(to));
    }

    function testTransferFrom721Wal() public {
        wal.transferFrom721(address(dpass), address(wal), to, dpassId[address(wal)]);
        assertEqLog("new owner is to", dpass.ownerOf(dpassId[address(wal)]), to);
    }

    function testSafeTransferFrom721Wal() public {
        wal.safeTransferFrom721(address(dpass), address(wal), address(to), dpassId[address(wal)]);
        assertEqLog("new owner is to", dpass.ownerOf(dpassId[address(wal)]), to);
    }

    function testSafeTransferFromData721Wal() public {
        bytes memory data_ = new bytes(4);
        data_ = "ercd";
        wal.safeTransferFrom721(address(dpass), address(wal), address(to), dpassId[address(wal)], data_);
        assertEqLog("new owner is to", dpass.ownerOf(dpassId[address(wal)]), to);
    }

    function testTransfer721Wal() public {
        wal.transfer721(address(dpass), to, dpassId[address(wal)]);
    }
}
