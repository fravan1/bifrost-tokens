// SPDX-License-Identifier: MIT
pragma solidity =0.8.21;

import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from
    "openzeppelin-contracts-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";
import {NonblockingLzApp} from "lz/lzApp/NonblockingLzApp.sol";

import {IMintableERC20} from "src/interfaces/IMintableERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TokenController is UUPSUpgradeable, ReentrancyGuardUpgradeable, NonblockingLzApp {
    using SafeERC20 for IERC20;

    /// @custom:storage-location erc7201:real.storage.Controller
    struct ControllerStorage {
        bool paused;
        bytes defaultAdapterParams;
        mapping(address => bool) whitelisted;
    }

    // keccak256(abi.encode(uint256(keccak256("real.storage.Controller")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ControllerStorageLocation =
        0x38dd9414040caa499e6f8618dea3a4643d21426b03e08452c6a0e2c3bb47f300;

    function _getControllerStorage() private pure returns (ControllerStorage storage $) {
        // slither-disable-next-line assembly
        assembly {
            $.slot := ControllerStorageLocation
        }
    }

    /// @notice This event is emitted to set the whitelisted token
    event Whitelisted(address indexed srcToken, bool isWhitelisted);
    event BridgeToken(address indexed token, uint256 amount);
    event TokenClaimed(uint16 indexed srcId, address indexed token, address receiver, uint256 amount);
    event Paused(bool isPaused);

    error ZeroAddress();
    error TokenNotAllowed();
    error IsPaused();

    /**
     * @param endpoint The endpoint for Layer Zero operations.
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor(address endpoint) NonblockingLzApp(endpoint) {}

    /**
     * @notice Vault initializer
     * @param _admin The admin address
     */
    function initialize(address _admin) external initializer {
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        _transferOwnership(_admin);

        ControllerStorage storage $ = _getControllerStorage();
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
        ControllerStorage storage $ = _getControllerStorage();
        if ($.paused) revert IsPaused();
        _;
    }

    function setWhitelistToken(address token) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();

        ControllerStorage storage $ = _getControllerStorage();
        $.whitelisted[token] = true;
        emit Whitelisted(token, true);
    }

    function removeWhitelistToken(address token) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();

        ControllerStorage storage $ = _getControllerStorage();
        $.whitelisted[token] = false;
        emit Whitelisted(token, false);
    }

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
        (address token, address recipient, uint256 amount) = abi.decode(_payload, (address, address, uint256));

        ControllerStorage storage $ = _getControllerStorage();
        if (!$.whitelisted[token]) revert TokenNotAllowed();

        // mint token to recipient's account
        IMintableERC20(token).mint(recipient, amount);

        emit TokenClaimed(_srcChainId, token, recipient, amount);
    }

    function bridgeToken(uint16 dstChainId, address token, uint256 amount, bytes memory _adapterParams)
        external
        payable
        whenNotPaused
    {
        // burn token from user
        IMintableERC20(token).burn(_msgSender(), amount);

        ControllerStorage storage $ = _getControllerStorage();

        // send lz message
        bytes memory _payload = abi.encode(token, _msgSender(), amount);
        _adapterParams = _adapterParams.length > 2 ? _adapterParams : $.defaultAdapterParams;
        _lzSend(dstChainId, _payload, payable(_msgSender()), address(0x0), _adapterParams, msg.value);
        emit BridgeToken(token, amount);
    }
}
