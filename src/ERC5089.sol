// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import {ERC20} from "yield-utils-v2/contracts/token/ERC20.sol";
import {MinimalTransferHelper} from "yield-utils-v2/contracts/token/MinimalTransferHelper.sol";

contract ERC5089 is ERC20 {
    using MinimalTransferHelper for ERC20;

    /* EVENTS
     *****************************************************************************************************************/

    event Redeem(address indexed from, address indexed to, uint256 underlyingAmount);

    /* MODIFIERS
     *****************************************************************************************************************/

    /// @notice A modifier that ensures the current block timestamp is at or after maturity.
    modifier afterMaturity() virtual {
        require(block.timestamp >= maturity, "BEFORE_MATURITY");
        _;
    }

    /* IMMUTABLES
     *****************************************************************************************************************/

    ERC20 public immutable underlying;
    uint256 public immutable maturity;

    /* CONSTRUCTOR
     *****************************************************************************************************************/

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        ERC20 underlying_,
        uint256 maturity_
    ) ERC20(name_, symbol_, decimals_) {
        underlying = underlying_;
        maturity = maturity_;
    }

    /* CORE FUNCTIONS
     *****************************************************************************************************************/

    /// @notice Burns an exact amount of principal tokens in exchange for an amount of underlying.
    /// @param principalAmount The exact amount of principal tokens to be burned.
    /// @param from The owner of the principal tokens to be redeemed.  If not msg.sender then must have prior approval.
    /// @param to The address to send the underlying tokens.
    /// @return underlyingAmount The total amount of underlying tokens sent.
    function redeem(
        uint256 principalAmount,
        address from,
        address to
    ) public virtual afterMaturity returns (uint256 underlyingAmount) {
        return (_redeem(principalAmount, from, to));
    }

    /// @dev This doesn't revert if before maturity.
    function _redeem(
        uint256 principalAmount,
        address from,
        address to
    ) public virtual returns (uint256 underlyingAmount) {
        _decreaseAllowance(from, principalAmount);

        // Check for rounding error since we round down in previewRedeem.
        require((underlyingAmount = _previewRedeem(principalAmount)) != 0, "ZERO_ASSETS");

        _burn(from, principalAmount);

        emit Redeem(from, to, principalAmount);

        _transferOut(to, underlyingAmount);
    }

    function _transferOut(address to, uint256 amount) internal virtual {
        underlying.safeTransfer(to, amount);
    }

    /// @notice Burns a calculated amount of principal tokens in exchange for an exact amount of underlying.
    /// @dev This doesn't revert if before maturity.
    /// @param underlyingAmount The exact amount of underlying tokens to be received.
    /// @param from The owner of the principal tokens to be redeemed.  If not msg.sender then must have prior approval.
    /// @param to The address to send the underlying tokens.
    /// @return principalAmount The total amount of underlying tokens redeemed.
    function withdraw(
        uint256 underlyingAmount,
        address from,
        address to
    ) public virtual returns (uint256 principalAmount) {
        return _withdraw(underlyingAmount, from, to);
    }

    /// @dev This doesn't revert if before maturity.
    function _withdraw(
        uint256 underlyingAmount,
        address from,
        address to
    ) public virtual returns (uint256 principalAmount) {
        principalAmount = _previewWithdraw(underlyingAmount); // No need to check for rounding error, previewWithdraw rounds up.

        _decreaseAllowance(from, principalAmount);

        _burn(from, principalAmount);

        emit Redeem(from, to, principalAmount);

        _transferOut(to, underlyingAmount);
    }

    /* ACCOUNTING FUNCTIONS
     *****************************************************************************************************************/

    /// @notice Calculates the amount of underlying tokens that would be exchanged for a given amount of principal tokens.
    /// @dev This doesn't revert if before maturity.
    /// @param principalAmount The amount principal on which to calculate conversion.
    /// @return underlyingAmount The total amount of underlying that would be received for the given principal amount..
    function convertToUnderlying(uint256 principalAmount) external view returns (uint256 underlyingAmount) {
        return _convertToUnderlying(principalAmount);
    }

    /// @dev This doesn't revert if before maturity.
    function _convertToUnderlying(uint256 principalAmount) internal view virtual returns (uint256 underlyingAmount) {
        return principalAmount;
    }

    /// @notice Converts a given amount of underlying tokens to principal exclusive of fees.
    /// @dev This doesn't revert if before maturity.
    /// @param underlyingAmount The total amount of underlying on which to calculate the conversion.
    /// @return principalAmount The amount principal tokens required to provide the given amount of underlying.
    function convertToPrincipal(uint256 underlyingAmount) external view returns (uint256 principalAmount) {
        return _convertToPrincipal(underlyingAmount);
    }

    /// @dev This doesn't revert if before maturity.
    function _convertToPrincipal(uint256 underlyingAmount) internal view virtual returns (uint256 principalAmount) {
        return underlyingAmount;
    }

    /// @notice Allows user to simulate redemption of a given amount of principal tokens, inclusive of fees and other
    /// current block conditions.
    /// @dev Reverts prior to maturity.
    /// @param principalAmount The amount of principal that would be redeemed.
    /// @return underlyingAmount The amount of underlying that would be received.
    function previewRedeem(uint256 principalAmount) external view returns (uint256 underlyingAmount) {
        return _previewRedeem(principalAmount);
    }

    /// @dev This doesn't revert if before maturity.
    function _previewRedeem(uint256 principalAmount) internal view virtual returns (uint256 underlyingAmount) {
        return block.timestamp >= maturity ? _convertToUnderlying(principalAmount) : 0; // should include fees/slippage
    }

    /// @notice Calculates the maximum amount of principal tokens that an owner could redeem.
    /// @dev This doesn't revert if before maturity.
    /// @param owner The address for which the redemption is being calculated.
    /// @return maxPrincipalAmount The maximium amount of principal tokens that can be redeemed by the given owner.
    function maxRedeem(address owner) external view returns (uint256 maxPrincipalAmount) {
        return _maxRedeem(owner);
    }

    /// @dev This doesn't revert if before maturity.
    function _maxRedeem(address owner) internal view virtual returns (uint256 maxPrincipalAmount) {
        return block.timestamp >= maturity ? _balanceOf[owner] : 0;
    }

    /// @notice Allows user to simulate withdraw of a given amount of underlying tokens.
    /// @dev This doesn't revert if before maturity.
    /// @param underlyingAmount The amount of underlying tokens that would be withdrawn.
    /// @return principalAmount The amount of principal tokens that would be redeemed.
    function previewWithdraw(uint256 underlyingAmount) external view returns (uint256 principalAmount) {
        return _previewWithdraw(underlyingAmount);
    }

    /// @dev This doesn't revert if before maturity.
    function _previewWithdraw(uint256 underlyingAmount) internal view virtual returns (uint256 principalAmount) {
        return block.timestamp >= maturity ? _convertToPrincipal(underlyingAmount) : 0; // should include fees/slippage
    }

    /// @notice Calculates the maximum amount of underlying tokens that can be withdrawn by a given owner.
    /// @dev This doesn't revert if before maturity.
    /// @param owner The address for which the withdraw is being calculated.
    /// @return maxUnderlyingAmount The maximum amount of underlying tokens that can be withdrawn by a given owner.
    function maxWithdraw(address owner) external view returns (uint256 maxUnderlyingAmount) {
        return _maxWithdraw(owner);
    }

    /// @dev This doesn't revert if before maturity.
    function _maxWithdraw(address owner) internal view virtual returns (uint256 maxUnderlyingAmount) {
        return _previewWithdraw(_maxRedeem(owner));
    }
}
