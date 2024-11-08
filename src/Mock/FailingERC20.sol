// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20MockToken} from "./ERC20MockToken.sol";

contract FailingERC20 is ERC20MockToken {
    constructor(uint256 initialSupply, address addr, string memory name, string memory symbol)
        ERC20MockToken(initialSupply, addr, name, symbol)
    {}

    function transfer(address, uint256) public pure override returns (bool) {
        return false;
    }

    function transferFrom(address, address, uint256) public pure override returns (bool) {
        return false;
    }
}
