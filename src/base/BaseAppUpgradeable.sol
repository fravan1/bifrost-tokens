// SPDX-License-Identifier: MIT
pragma solidity =0.8.21;

import {ReentrancyGuardUpgradeable} from
    "openzeppelin-contracts-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {NonblockingLzAppUpgradeable} from "@tangible/layerzero/lzApp/NonblockingLzAppUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title BaseAppUpgradeable
 * @dev A base contract for managing token operations with upgradeable functionality, cross-chain capabilities, and security features.
 */
abstract contract BaseAppUpgradeable is ReentrancyGuardUpgradeable, OwnableUpgradeable, NonblockingLzAppUpgradeable {
    using SafeERC20 for IERC20;

    /// @custom:storage-location erc7201:real.storage.BaseApp
    struct BaseAppStorage {
        bool paused;
        bytes defaultAdapterParams;
        mapping(address => bool) whitelisted;
        mapping(address => address) tokenPairs; // srcToken => dstToken
    }

    // keccak256(abi.encode(uint256(keccak256("real.storage.BaseApp")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant BaseAppStorageLocation = 0x3ae64415efeba844fa889963cef544e4188d2a0d9305c2abef15a53cac216000;

    event Paused(bool isPaused);
    event Whitelisted(address indexed token, bool isWhitelisted);
    event BridgeToken(address indexed token, uint256 amount);
    event TokenClaimed(uint16 indexed srcId, address indexed token, address indexed receiver, uint256 amount);
    event TokenRescued(address indexed token, address indexed receiver, uint256 amount);
    event UpdateLzAdapterParams(uint256 limit);

    error ZeroAddress();
    error TokenNotAllowed();
    error IsPaused();
    error InvalidParam();
    error InvalidAmount();
    error NotAuthorized();

    function _getBaseAppStorage() private pure returns (BaseAppStorage storage $) {
        // slither-disable-next-line assembly
        assembly {
            $.slot := BaseAppStorageLocation
        }
    }

    /**
     * @param endpoint The address of the LayerZero endpoint contract.
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor(address endpoint) NonblockingLzAppUpgradeable(endpoint) {}

    /**
     * @notice BaseApp initializer
     * @param initialOwner The address of the initial owner.
     */
    function __BaseApp_init(address initialOwner) internal initializer {
        __ReentrancyGuard_init();
        __NonblockingLzApp_init(initialOwner);
        __BaseApp_init_unchained();
    }

    function __BaseApp_init_unchained() internal initializer {
        BaseAppStorage storage $ = _getBaseAppStorage();
        $.defaultAdapterParams = abi.encodePacked(uint16(1), uint256(200_000)); // set LayerZero adapter params for native fees
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     */
    modifier whenNotPaused() {
        BaseAppStorage storage $ = _getBaseAppStorage();
        if ($.paused) revert IsPaused();
        _;
    }

    /**
     * @dev Toggles the paused state of the contract.
     * @notice Only callable by the owner.
     */
    function togglePause() external onlyOwner {
        BaseAppStorage storage $ = _getBaseAppStorage();
        bool state = $.paused;
        $.paused = !state;
        emit Paused(!state);
    }

    /**
     * @notice Sets LayerZero adapter parameters.
     * @param limit The limit for the adapter parameters.
     * @dev Only callable by the owner. Reverts if the limit is below 200,000.
     */
    function setLzAdapterParams(uint256 limit) external onlyOwner {
        if (limit < 200_000) revert InvalidParam();
        BaseAppStorage storage $ = _getBaseAppStorage();
        $.defaultAdapterParams = abi.encodePacked(uint16(1), limit);
        emit UpdateLzAdapterParams(limit);
    }

    /**
     * @notice Bridges tokens to another chain.
     * @param _dstChainId The destination chain ID.
     * @param token The address of the source token.
     * @param amount The amount of the token to bridge.
     * @param _adapterParams Adapter parameters for the LayerZero send function.
     * @dev Callable by external accounts. Reverts if the contract is paused, the token is not whitelisted, or if any parameter is invalid.
     */
    function bridgeToken(uint16 _dstChainId, address token, uint256 amount, bytes memory _adapterParams)
        external
        payable
        nonReentrant
        whenNotPaused
    {
        if (token == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidParam();

        BaseAppStorage storage $ = _getBaseAppStorage();
        if (!$.whitelisted[token]) revert TokenNotAllowed();

        _adapterParams = _adapterParams.length != 0 ? _adapterParams : $.defaultAdapterParams;

        _send(_dstChainId, token, amount, _adapterParams);

        emit BridgeToken(token, amount);
    }

    /**
     * @notice Rescues tokens accidentally sent to the contract.
     * @param token The address of the token to rescue.
     * @param to The address to send the rescued tokens to.
     * @param amount The amount of tokens to rescue.
     * @dev Only callable by the owner.
     */
    function rescueToken(address token, address to, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(to, amount);
        emit TokenRescued(token, to, amount);
    }

    // ==================== INTERNAL ====================

    /**
     * @dev Updates the whitelist status of a token.
     * @param token The address of the token.
     * @param isWhitelisted The whitelist status of the token.
     */
    function _updateWhitelistToken(address token, bool isWhitelisted) internal {
        BaseAppStorage storage $ = _getBaseAppStorage();
        $.whitelisted[token] = isWhitelisted;
        emit Whitelisted(token, isWhitelisted);
    }

    /**
     * @dev Handles non-blocking LayerZero receive messages.
     * @param _srcChainId The source chain ID.
     * @param _payload The payload containing the token, recipient, and amount.
     */
    function _nonblockingLzReceive(
        uint16 _srcChainId,
        bytes memory, /*_srcAddress*/
        uint64, /*_nonce*/
        bytes memory _payload
    ) internal override nonReentrant whenNotPaused {
        (address payloadToken, address recipient, uint256 amount) = abi.decode(_payload, (address, address, uint256));

        address chainToken = _receive(payloadToken, recipient, amount);
        emit TokenClaimed(_srcChainId, chainToken, recipient, amount);
    }

    /**
     * @dev Safely transfers tokens from one address to another.
     * @param token The address of the token.
     * @param from The address to transfer tokens from.
     * @param to The address to transfer tokens to.
     * @param amount The amount of tokens to transfer.
     * @return received The amount of tokens received.
     */
    function _safeTransferFrom(address token, address from, address to, uint256 amount)
        internal
        returns (uint256 received)
    {
        uint256 balanceBefore = IERC20(token).balanceOf(to);
        IERC20(token).safeTransferFrom(from, to, amount);
        received = IERC20(token).balanceOf(to) - balanceBefore;
    }

    /**
     * @dev Internal function to handle token sending across chains.
     * @param _dstChainId The destination chain ID.
     * @param _srcToken The address of the chain token to send / burn.
     * @param _amount The amount of the token to send.
     * @param _adapterParams Adapter parameters for the LayerZero send function.
     */
    function _send(uint16 _dstChainId, address _srcToken, uint256 _amount, bytes memory _adapterParams)
        internal
        virtual;

    /**
     * @dev Internal function to handle token receiving.
     * @param token The address of the mainChain token received.
     * @param recipient The address of the recipient.
     * @param amount The amount of the token received.
     * @return The address of the token received.
     */
    function _receive(address token, address recipient, uint256 amount) internal virtual returns (address);

    /**
     * @dev Internal function to get the main chain token address.
     * @param token The address of the mainChain token.
     * @return The address of the main chain token.
     */
    function _getMainChainToken(address token) internal view virtual returns (address);

    // ==================== VIEW ====================

    function isWhitelistedToken(address token) public view returns (bool) {
        BaseAppStorage storage $ = _getBaseAppStorage();
        return $.whitelisted[token];
    }

    function getDefaultLZParam() public view returns (bytes memory) {
        BaseAppStorage storage $ = _getBaseAppStorage();
        return $.defaultAdapterParams;
    }

    /**
     * @notice Estimates the fees for bridging tokens.
     * @param dstChainId The destination chain ID.
     * @param token The address of the source token.
     * @param amount The amount of the token to bridge.
     * @param _adapterParams Adapter parameters for the LayerZero send function.
     * @return nativeFee The native fee for the operation.
     * @return zroFee The ZRO fee for the operation.
     */
    function estimateFees(uint16 dstChainId, address token, uint256 amount, bytes memory _adapterParams)
        public
        view
        returns (uint256 nativeFee, uint256 zroFee)
    {
        BaseAppStorage storage $ = _getBaseAppStorage();

        address mainChainToken = _getMainChainToken(token);
        if (mainChainToken == address(0)) revert ZeroAddress();

        bytes memory _payload = abi.encode(mainChainToken, _msgSender(), amount);
        _adapterParams = _adapterParams.length != 0 ? _adapterParams : $.defaultAdapterParams;

        return lzEndpoint.estimateFees(dstChainId, address(this), _payload, false, _adapterParams);
    }
}
