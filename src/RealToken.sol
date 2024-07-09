// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity =0.8.21;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract RealToken is ERC20, ERC20Permit, Ownable2Step {
    uint8 private immutable _decimals;
    address public controller;

    event UpdateController(address indexed oldContorller, address indexed newController);

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error ConrollereUnauthorizedAccount(address account);

    constructor(address intialOwner, string memory name_, string memory symbol_, uint8 decimals_)
        ERC20(name_, symbol_)
        ERC20Permit(name_)
        Ownable(intialOwner)
    {
        _decimals = decimals_;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyController() {
        _checkController();
        _;
    }

    function _checkController() internal view {
        if (controller != _msgSender()) {
            revert ConrollereUnauthorizedAccount(_msgSender());
        }
    }

    function setController(address _controller) external onlyOwner {
        emit UpdateController(controller, _controller);
        controller = _controller;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the default value returned by this function, unless
     * it's overridden.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function burn(address user_, uint256 amount_) external onlyController {
        _burn(user_, amount_);
    }

    function mint(address receiver_, uint256 amount_) external onlyController {
        _mint(receiver_, amount_);
    }
}
