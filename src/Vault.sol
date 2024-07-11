// SPDX-License-Identifier: MIT
pragma solidity =0.8.21;

import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {BaseAppUpgradeable} from "src/base/BaseAppUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title Vault
 * @dev A contract for managing token operations with upgradeable functionality and cross-chain capabilities.
 */
contract Vault is UUPSUpgradeable, BaseAppUpgradeable {
    using SafeERC20 for IERC20;

    uint16 immutable dstChainId;

    /// @custom:storage-location erc7201:real.storage.Vault
    struct VaultStorage {
        // srcToken => dstToken
        mapping(address => address) tokenPairs;
    }

    // keccak256(abi.encode(uint256(keccak256("real.storage.Vault")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant VaultStorageLocation = 0xb6416d507a04e2a32445de45abf7290bf3bbe8e9fa76203447827b6ceacc5300;

    event UpdateTokenPairs(address indexed srcToken, address indexed dstToken);

    function _getVaultStorage() private pure returns (VaultStorage storage $) {
        // slither-disable-next-line assembly
        assembly {
            $.slot := VaultStorageLocation
        }
    }

    /**
     * @param endpoint_ The endpoint for Layer Zero operations.
     * @param dstChainId_ The chain id of the controller.
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor(address endpoint_, uint16 dstChainId_) BaseAppUpgradeable(endpoint_) {
        dstChainId = dstChainId_;
    }

    /**
     * @notice Initializes the vault with the initial owner.
     * @param initialOwner The admin address.
     */
    function initialize(address initialOwner) external initializer {
        __UUPSUpgradeable_init();
        __BaseApp_init(initialOwner);
    }

    /**
     * @dev The Vault can only be upgraded by the owner
     * @param v new Vault implementation
     */
    function _authorizeUpgrade(address v) internal override onlyOwner {}

    /**
     * @notice Adds a token pair to the whitelist and updates the token pairs mapping.
     * @param srcToken The address of the source token.
     * @param dstToken The address of the destination token.
     * @dev Only callable by the owner. Reverts if either token address is zero.
     */
    function setWhitelistToken(address srcToken, address dstToken) external onlyOwner {
        if (srcToken == address(0) || dstToken == address(0)) revert ZeroAddress();

        _updateWhitelistToken(srcToken, true);

        VaultStorage storage $ = _getVaultStorage();
        $.tokenPairs[srcToken] = dstToken;
        $.tokenPairs[dstToken] = srcToken;
        emit UpdateTokenPairs(srcToken, dstToken);
    }

    /**
     * @notice Removes a token from the whitelist and updates the token pairs mapping.
     * @param srcToken The address of the source token to remove.
     * @dev Only callable by the owner. Reverts if the token address is zero.
     */
    function removeWhitelistToken(address srcToken) external onlyOwner {
        if (srcToken == address(0)) revert ZeroAddress();

        _updateWhitelistToken(srcToken, false);

        VaultStorage storage $ = _getVaultStorage();
        address dstToken = $.tokenPairs[srcToken];
        $.tokenPairs[srcToken] = address(0);
        $.tokenPairs[dstToken] = address(0);

        emit UpdateTokenPairs(srcToken, address(0));
    }

    // ==================== INTERNAL ====================

    /**
     * @dev Internal function to handle token sending across chains.
     *
     * @param srcToken The address of the source token.
     * @param amount The amount of the token to send.
     * @param _adapterParams Adapter parameters for the Layer Zero send function.
     */
    function _send(uint16, address srcToken, uint256 amount, bytes memory _adapterParams) internal override {
        amount = _safeTransferFrom(srcToken, _msgSender(), address(this), amount);

        if (amount == 0) revert InvalidAmount();

        VaultStorage storage $ = _getVaultStorage();
        address _mainChainToken = $.tokenPairs[srcToken];
        bytes memory _payload = abi.encode(_mainChainToken, _msgSender(), amount);

        _lzSend(dstChainId, _payload, payable(_msgSender()), address(0x0), _adapterParams, msg.value);
    }

    /**
     * @dev Internal function to handle token receiving.
     * @param mainChainToken The address of the main chain token burned.
     * @param recipient The address of the recipient.
     * @param amount The amount of the token received.
     * @return The address of the source token.
     */
    function _receive(address mainChainToken, address recipient, uint256 amount) internal override returns (address) {
        VaultStorage storage $ = _getVaultStorage();
        address srcToken = $.tokenPairs[mainChainToken];
        if (srcToken == address(0) || !isWhitelistedToken(srcToken)) revert TokenNotAllowed();

        IERC20(srcToken).safeTransfer(recipient, amount);

        return srcToken;
    }

    /**
     * @dev Internal function to get the main chain token address from the source token address.
     * @param srcToken The address of the source token.
     * @return mainChainToken The address of the main chain token.
     */
    function _getMainChainToken(address srcToken) internal view override returns (address mainChainToken) {
        VaultStorage storage $ = _getVaultStorage();
        mainChainToken = $.tokenPairs[srcToken];
    }
}
