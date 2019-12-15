pragma solidity ^0.5.11;

import "./Wallet.sol";
import "ds-auth/auth.sol";
import "ds-token/token.sol";

contract Liquidity is Wallet {
    bytes32 public symbol = "Liq";                          // set human readable name for contract

    function burn(address dpt, address payable burner, uint256 burnValue) public auth {
        transfer(dpt, burner, burnValue);
    }
}
