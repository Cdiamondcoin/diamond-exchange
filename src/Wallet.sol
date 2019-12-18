pragma solidity ^0.5.11;

import "ds-math/math.sol";
import "ds-auth/auth.sol";
import "ds-token/token.sol";
import "ds-stop/stop.sol";
import "ds-note/note.sol";

/**
* @dev Interface to ERC20 tokens.
*/
contract TrustedErc20Wallet {
    function totalSupply() public view returns (uint);
    function balanceOf(address guy) public view returns (uint);
    function allowance(address src, address guy) public view returns (uint);

    function approve(address guy, uint wad) public returns (bool);
    function transfer(address dst, uint wad) public returns (bool);
    function transferFrom(
        address src, address dst, uint wad
    ) public returns (bool);
}

/**
* @dev Interface to ERC721 tokens.
*/
contract TrustedErci721Wallet {
    function balanceOf(address guy) public view returns (uint);
    function ownerOf(uint256 tokenId) public view returns (address);
    function approve(address to, uint256 tokenId) public;
    function getApproved(uint256 tokenId) public view returns (address);
    function setApprovalForAll(address to, bool approved) public;
    function isApprovedForAll(address owner, address operator) public view returns (bool);
    function transferFrom(address from, address to, uint256 tokenId) public;
    function safeTransferFrom(address from, address to, uint256 tokenId) public;
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) public;
}

/**
 * @title Wallet is a contract to handle erc20 and erc721 tokens and ether.
 * @dev This token is used to store and transfer tokens that were paid as fee by users.
 */
contract Wallet is DSAuth, DSStop, DSMath {
    event LogTransferEth(address src, address dst, uint256 amount);
    address public eth = address(0xee);
    bytes32 public name = "Wal";                          // set human readable name for contract
    bytes32 public symbol = "Wal";                        // set human readable name for contract

    function () external payable {
    }

    function transfer(address token, address payable dst, uint256 amt) public auth returns (bool) {
        return sendToken(token, address(this), dst, amt);
    }

    function transferFrom(address token, address src, address payable dst, uint256 amt) public auth returns (bool) {
        return sendToken(token, src, dst, amt);
    }

    function totalSupply(address token) public view returns (uint){
        if (token == eth) {
            require(false, "wal-no-total-supply-for-ether");
        } else {
            return TrustedErc20Wallet(token).totalSupply();
        }
    }

    function balanceOf(address token, address src) public view returns (uint) {
        if (token == eth) {
            return src.balance;
        } else {
            return TrustedErc20Wallet(token).balanceOf(src);
        }
    }

    function allowance(address token, address src, address guy)
    public view returns (uint) {
        if( token == eth) {
            require(false, "wal-no-allowance-for-ether");
        } else {
            return TrustedErc20Wallet(token).allowance(src, guy);
        }
    }

    function approve(address token, address guy, uint wad)
    public auth returns (bool) {
        if( token == eth) {
            require(false, "wal-can-not-approve-ether");
        } else {
            return TrustedErc20Wallet(token).approve(guy, wad);
        }
    }

    function balanceOf721(address token, address guy) public view returns (uint) {
        return TrustedErci721Wallet(token).balanceOf(guy);
    }

    function ownerOf721(address token, uint256 tokenId) public view returns (address) {
        return TrustedErci721Wallet(token).ownerOf(tokenId);
    }

    function approve721(address token, address to, uint256 tokenId) public {
        TrustedErci721Wallet(token).approve(to, tokenId);
    }

    function getApproved721(address token, uint256 tokenId) public view returns (address) {
        return TrustedErci721Wallet(token).getApproved(tokenId);
    }

    function setApprovalForAll721(address token, address to, bool approved) public auth {
        TrustedErci721Wallet(token).setApprovalForAll(to, approved);
    }

    function isApprovedForAll721(address token, address owner, address operator) public view returns (bool) {
        return TrustedErci721Wallet(token).isApprovedForAll(owner, operator);
    }

    function transferFrom721(address token, address from, address to, uint256 tokenId) public auth {
        TrustedErci721Wallet(token).transferFrom(from, to, tokenId);
    }

    function safeTransferFrom721(address token, address from, address to, uint256 tokenId) public auth {
        TrustedErci721Wallet(token).safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom721(address token, address from, address to, uint256 tokenId, bytes memory _data) public auth {
        TrustedErci721Wallet(token).safeTransferFrom(from, to, tokenId, _data);
    }

    function transfer721(address token, address to, uint tokenId) public auth {
        TrustedErci721Wallet(token).transferFrom(address(this), to, tokenId);
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
