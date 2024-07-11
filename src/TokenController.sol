// SPDX-License-Identifier: MIT
pragma solidity =0.8.21;

import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {BaseAppUpgradeable} from "src/base/BaseAppUpgradeable.sol";
import {IMintableERC20} from "src/interfaces/IMintableERC20.sol";

/**
 * @title TokenController
 * @dev A contract for managing token operations with upgradeable functionality.
 */
contract TokenController is UUPSUpgradeable, BaseAppUpgradeable {
    /**
     * @param endpoint The endpoint for Layer Zero operations.
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor(address endpoint) BaseAppUpgradeable(endpoint) {}

    /**
     * @notice Initializes the controller with the initial owner.
     * @param initialOwner The admin address.
     */
    function initialize(address initialOwner) external initializer {
        __UUPSUpgradeable_init();
        __BaseApp_init(initialOwner);
    }

    /**
     * @dev The Controller can only be upgraded by the owner
     * @param v new Controller implementation
     */
    function _authorizeUpgrade(address v) internal override onlyOwner {}

    /**
     * @notice Adds a token to the whitelist.
     * @param token The address of the token to whitelist.
     * @dev Only callable by the owner. Reverts if the token address is zero.
     */
    function setWhitelistToken(address token) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        _updateWhitelistToken(token, true);
    }

    /**
     * @notice Removes a token from the whitelist.
     * @param token The address of the token to remove from the whitelist.
     * @dev Only callable by the owner. Reverts if the token address is zero.
     */
    function removeWhitelistToken(address token) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        _updateWhitelistToken(token, false);
    }

    // ==================== INTERNAL ====================

    /**
     * @dev Internal function to handle token sending across chains.
     * @param dstChainId The destination chain ID.
     * @param token The address of the mainChain token to burn.
     * @param amount The amount of the token to send.
     * @param _adapterParams Adapter parameters for the Layer Zero send function.
     */
    function _send(uint16 dstChainId, address token, uint256 amount, bytes memory _adapterParams) internal override {
        // burn token from user
        IMintableERC20(token).burn(_msgSender(), amount);

        bytes memory _payload = abi.encode(token, _msgSender(), amount);
        _lzSend(dstChainId, _payload, payable(_msgSender()), address(0x0), _adapterParams, msg.value);
    }

    /**
     * @dev Internal function to handle token receiving.
     * @param token The address of the mainchain token received.
     * @param recipient The address of the recipient.
     * @param amount The amount of the token received.
     * @return The address of the token received.
     */
    function _receive(address token, address recipient, uint256 amount) internal override returns (address) {
        if (token == address(0) || !isWhitelistedToken(token)) revert TokenNotAllowed();

        // mint token to recipient's account
        IMintableERC20(token).mint(recipient, amount);

        return token;
    }

    /**
     * @dev Internal function to get the main chain token address.
     * @param token The address of the mainchain token.
     * @return The address of the main chain token.
     */
    function _getMainChainToken(address token) internal pure override returns (address) {
        return token;
    }
}
