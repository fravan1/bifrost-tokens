// SPDX-License-Identifier: MIT
pragma solidity =0.8.21;

import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {BaseAppUpgradeable} from "src/base/BaseAppUpgradeable.sol";
import {IMintableERC20} from "src/interfaces/IMintableERC20.sol";

contract TokenControllerMock is UUPSUpgradeable, BaseAppUpgradeable {
    /**
     * @param endpoint The endpoint for Layer Zero operations.
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor(address endpoint) BaseAppUpgradeable(endpoint) {}

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
