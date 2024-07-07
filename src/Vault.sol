// SPDX-License-Identifier: MIT
pragma solidity =0.8.21;

import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from
    "openzeppelin-contracts-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";
import {NonblockingLzApp} from "lz/lzApp/NonblockingLzApp.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Vault is UUPSUpgradeable, ReentrancyGuardUpgradeable, NonblockingLzApp {
    using SafeERC20 for IERC20;

    /// @custom:storage-location erc7201:real.storage.Vault
    struct VaultStorage {
        uint16 destinationChainId;
        bytes defaultAdapterParams;
        bool paused;
        mapping(address => bool) whitelisted;
        // L2Token => L1Token
        mapping(address => address) tokenPairs;
    }

    // keccak256(abi.encode(uint256(keccak256("real.storage.Vault")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant VaultStorageLocation = 0xb6416d507a04e2a32445de45abf7290bf3bbe8e9fa76203447827b6ceacc5300;

    function _getVaultStorage() private pure returns (VaultStorage storage $) {
        // slither-disable-next-line assembly
        assembly {
            $.slot := VaultStorageLocation
        }
    }

    /// @notice This event is emitted to set the whitelisted token
    event Whitelisted(address indexed srcToken, address indexed dstToken, bool isWhitelisted);
    event BridgeToken(address indexed token, uint256 amount);
    event TokenClaimed(address indexed token, address indexed receiver, uint256 amount);
    event TokenRescued(address indexed token, address indexed receiver, uint256 amount);
    event UpdateLzAdapterParams(uint256 limit);
    event Paused(bool isPaused);

    error GasLimit();
    error IsPaused();
    error ZeroAddress();
    error NotAuthorized();
    error InvalidParam();
    error TokenNotAllowed();
    error InvalidSourceChain();

    /**
     * @param endpoint The endpoint for Layer Zero operations.
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor(address endpoint) NonblockingLzApp(endpoint) {}

    /**
     * @notice Vault initializer
     * @param _admin The admin address
     */
    function initialize(address _admin, uint16 _dstChainId) external initializer {
        if (_dstChainId == 0) {
            revert InvalidParam();
        }

        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        _transferOwnership(_admin);

        // Set storage
        VaultStorage storage $ = _getVaultStorage();
        $.destinationChainId = _dstChainId;
        $.defaultAdapterParams = abi.encodePacked(uint16(1), uint256(200_000)); //set layerZero adapter params for native fees
    }

    /**
     * @dev The L1DaiEscrow can only be upgraded by the owner
     * @param v new L1DaiEscrow implementation
     */
    function _authorizeUpgrade(address v) internal override onlyOwner {}

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenNotPaused() {
        VaultStorage storage $ = _getVaultStorage();
        if ($.paused) revert IsPaused();
        _;
    }

    // ======================= ACTION =======================

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function togglePause() internal virtual {
        VaultStorage storage $ = _getVaultStorage();
        bool state = $.paused;
        $.paused = !state;
        emit Paused(state);
    }

    function setWhitelistToken(address srcToken, address dstToken) external onlyOwner {
        if (srcToken == address(0) && dstToken == address(0)) revert ZeroAddress();

        VaultStorage storage $ = _getVaultStorage();
        $.whitelisted[srcToken] = true;
        $.tokenPairs[srcToken] = dstToken;
        $.tokenPairs[dstToken] = srcToken;
        emit Whitelisted(srcToken, dstToken, true);
    }

    function removeWhitelistToken(address srcToken) external onlyOwner {
        if (srcToken == address(0)) revert ZeroAddress();

        VaultStorage storage $ = _getVaultStorage();
        address dstToken = $.tokenPairs[srcToken];

        $.whitelisted[srcToken] = false;
        $.tokenPairs[srcToken] = address(0);
        if (dstToken != address(0)) $.tokenPairs[dstToken] = address(0);
        emit Whitelisted(srcToken, address(0), false);
    }

    function setLzAdapterParams(uint256 limit) public onlyOwner {
        if (limit < 200_000) revert GasLimit();
        VaultStorage storage $ = _getVaultStorage();
        $.defaultAdapterParams = abi.encodePacked(uint16(1), limit);
        emit UpdateLzAdapterParams(limit);
    }

    function bridgeToken(address token, uint256 amount, bytes memory _adapterParams) external payable whenNotPaused {
        if (token == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidParam();

        VaultStorage storage $ = _getVaultStorage();
        if (!$.whitelisted[token]) revert TokenNotAllowed();

        amount = _safeTransferFrom(token, _msgSender(), address(this), amount);

        bytes memory _payload = abi.encode(token, _msgSender(), amount);
        _adapterParams = _adapterParams.length > 2 ? _adapterParams : $.defaultAdapterParams;
        _lzSend($.destinationChainId, _payload, payable(_msgSender()), address(0x0), _adapterParams, msg.value);
        emit BridgeToken(token, amount);
    }

    function rescueToken(address token, address to, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(to, amount);
        emit TokenRescued(token, to, amount);
    }

    // ======================= INTERNAL =======================

    /// @dev Internal function to handle incoming Ping messages.
    /// @param _srcChainId The source chain ID from which the message originated.
    /// @param _payload The payload of the incoming message.
    function _nonblockingLzReceive(
        uint16 _srcChainId,
        bytes memory, /*_srcAddress*/
        uint64, /*_nonce*/
        bytes memory _payload
    ) internal override whenNotPaused {
        // decode the token transfer payload
        (address dstToken, address recipient, uint256 amount) = abi.decode(_payload, (address, address, uint256));

        VaultStorage storage $ = _getVaultStorage();

        if ($.destinationChainId != _srcChainId) revert InvalidSourceChain();

        address token = $.tokenPairs[dstToken];

        if (!$.whitelisted[token]) revert TokenNotAllowed();

        IERC20(token).safeTransfer(recipient, amount);
        emit TokenClaimed(token, recipient, amount);
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount)
        internal
        returns (uint256 received)
    {
        uint256 balanceBefore = IERC20(token).balanceOf(to);
        IERC20(token).safeTransferFrom(from, to, amount);
        received = IERC20(token).balanceOf(to) - balanceBefore;
    }

    // ======================= GETTER =======================

    function getDefaultLZParam() public view returns (bytes memory) {
        VaultStorage storage $ = _getVaultStorage();
        return $.defaultAdapterParams;
    }

    function getDestinationChainId() public view returns (uint16) {
        VaultStorage storage $ = _getVaultStorage();
        return $.destinationChainId;
    }
}
