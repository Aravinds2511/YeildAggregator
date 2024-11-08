// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Strategy} from "../Strategy.sol";
import {ICompoundCToken} from "src/Strategies/Interface/ICompoundCToken.sol";

contract CompoundStrategy is Strategy {
    error TransferFailed();
    error MintFailed();
    error RedeemFailed();

    ICompoundCToken public cToken;
    IERC20 public immutable UNDERLYING;

    constructor(IERC20 _underlyingAsset, address _cToken) Strategy(_underlyingAsset) {
        cToken = ICompoundCToken(_cToken);
        UNDERLYING = _underlyingAsset;
    }

    /**
     * @notice Deposit assets into Compound by minting cTokens.
     * @param amount The amount of underlying asset to deposit.
     */
    function deposit(uint256 amount) external override {
        if (!underlyingAsset.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();
        underlyingAsset.approve(address(cToken), amount);
        if (cToken.mint(amount) != 0) revert MintFailed();
    }

    /**
     * @notice Withdraw assets from Compound by redeeming cTokens.
     * @param amount The amount of underlying asset to withdraw.
     */
    function withdraw(uint256 amount) external override {
        if (cToken.redeemUnderlying(amount) != 0) revert RedeemFailed();
        if (!underlyingAsset.transfer(msg.sender, amount)) revert TransferFailed();
    }

    /**
     * @notice Harvest rewards from Compound (if any additional rewards exist).
     */
    function harvest() external override {
        // Compound generally does not provide a "harvest" function, as interest accrues directly.
    }

    /**
     * @notice Returns the balance of the underlying asset in Compound.
     * @return The balance in the underlying asset.
     */
    function balanceOfUnderlying() public view override returns (uint256) {
        uint256 cTokenBalance = cToken.balanceOf(address(this));
        uint256 exchangeRate = cToken.exchangeRateStored();
        return (cTokenBalance * exchangeRate) / 10 ** 16;
        // return (cTokenBal * exchangeRate) / 10**( decimals + cTokenDecimals);
    }

    function balanceUnderlying() public returns (uint256) {
        return cToken.balanceOfUnderlying(address(this));
    }

    /**
     * @notice Returns the balance of the cTokens in Compound.
     * @return The balance of the cToken.
     */
    function getCTokenBalance() external view returns (uint256) {
        return cToken.balanceOf(address(this));
    }
}
