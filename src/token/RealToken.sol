// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity =0.8.21;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/**
 * @title RealToken
 * @dev ERC20 token with minting and burning capabilities, controllable by a designated controller.
 */
contract RealToken is ERC20, ERC20Permit, Ownable2Step {
    uint8 private immutable _decimals;
    address public controller;

    event UpdateController(address indexed oldContorller, address indexed newController);

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error ConrollereUnauthorizedAccount(address account);

    /**
     * @notice Constructor for the RealToken contract.
     * @param intialOwner_ The address of the initial owner.
     * @param name_ The name of the token.
     * @param symbol_ The symbol of the token.
     * @param decimals_ The number of decimals for the token.
     */
    constructor(address intialOwner_, string memory name_, string memory symbol_, uint8 decimals_)
        ERC20(name_, symbol_)
        ERC20Permit(name_)
        Ownable(intialOwner_)
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

    /**
     * @dev Internal function to check if the caller is the controller.
     * Reverts if the caller is not the controller.
     */
    function _checkController() internal view {
        if (controller != _msgSender()) {
            revert ConrollereUnauthorizedAccount(_msgSender());
        }
    }

    /**
     * @notice Sets a new controller for the contract.
     * @param _controller The address of the new controller.
     * @dev Only callable by the owner.
     */
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

    /**
     * @notice Burns tokens from a specified address.
     * @param user_ The address to burn tokens from.
     * @param amount_ The amount of tokens to burn.
     * @dev Only callable by the controller.
     */
    function burn(address user_, uint256 amount_) external onlyController {
        _burn(user_, amount_);
    }

    /**
     * @notice Mints new tokens to a specified address.
     * @param receiver_ The address to receive the minted tokens.
     * @param amount_ The amount of tokens to mint.
     * @dev Only callable by the controller.
     */
    function mint(address receiver_, uint256 amount_) external onlyController {
        _mint(receiver_, amount_);
    }
}
