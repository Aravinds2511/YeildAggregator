// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract ERC20MockToken is ERC20, Ownable {
    constructor(uint256 initialSupply, address addr, string memory name, string memory symbol)
        ERC20(name, symbol)
        Ownable(addr)
    {
        _mint(addr, initialSupply * 1e18);
    }

    function mint(address addr, uint256 amount) external onlyOwner {
        _mint(addr, amount);
    }
}
