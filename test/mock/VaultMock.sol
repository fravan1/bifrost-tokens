// SPDX-License-Identifier: MIT
pragma solidity =0.8.21;

import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {BaseAppUpgradeable} from "src/base/BaseAppUpgradeable.sol";

contract VaultMock is UUPSUpgradeable, BaseAppUpgradeable {
    uint16 immutable dstChainId;

    /// @custom:storage-location erc7201:real.storage.Vault
    struct VaultStorage {
        // srcToken => dstToken
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

    /**
     * @param endpoint_ The endpoint for Layer Zero operations.
     * @param dstChainId_ The chain id of the controller.
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor(address endpoint_, uint16 dstChainId_) BaseAppUpgradeable(endpoint_) {
        dstChainId = dstChainId_;
    }

    /**
     * @notice Vault initializer
     * @param initialOwner The admin address
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

    function mockTest() public pure returns (bool) {
        return true;
    }

    function _getMainChainToken(address token) internal view override returns (address) {}

    function _send(uint16 _dstChainId, address _token, uint256 _amount, bytes memory _adapterParams)
        internal
        override
    {}

    function _receive(address token, address recipient, uint256 amount) internal override returns (address) {}
}
