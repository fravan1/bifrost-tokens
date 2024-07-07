// SPDX-License-Identifier: MIT
pragma solidity =0.8.21;

import {Test, console2 as console} from "forge-std/Test.sol";
import {TokenController} from "src/TokenController.sol";
import {RealToken} from "src/RealToken.sol";

import {UUPSProxy} from "src/UUPSProxy.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ControllerTest is Test {
    string UNREAL_RPC_URL = vm.envString("UNREAL_RPC_URL");
    uint16 remoteChainId = 10_231;

    Account public admin;
    Account public alice;

    TokenController v1;
    TokenController controllerProxy;
    RealToken usdc;

    address public usdt = 0x9aA40Cc99973d8407a2AE7B2237d26E615EcaFd2;
    address public unrealEndpoint = 0x83c73Da98cf733B03315aFa8758834b36a195b87;

    function setUp() public {
        vm.createSelectFork(UNREAL_RPC_URL, 75_064);

        admin = makeAccount("admin");
        alice = makeAccount("alice");

        usdc = new RealToken(admin.addr, "USD Coin", "USDC.e", 6);

        v1 = new TokenController(unrealEndpoint);
        bytes memory controllerData = abi.encodeWithSelector(TokenController.initialize.selector, admin.addr);
        UUPSProxy proxy = new UUPSProxy(address(v1), controllerData);
        controllerProxy = TokenController(address(proxy));

        vm.startPrank(admin.addr);

        // set controller in token
        usdc.grantRole(keccak256("CONTROLLER_ROLE"), address(controllerProxy));

        // set crosschain config
        controllerProxy.setWhitelistToken(address(usdc));
        bytes memory path = abi.encodePacked(address(controllerProxy), address(controllerProxy));
        controllerProxy.setTrustedRemote(remoteChainId, path);
        vm.stopPrank();
    }

    function test_FailBridgeTokenFromL2() public {
        vm.startPrank(alice.addr);
        uint256 bridgeAmount = 100_000_000;
        deal(address(usdc), alice.addr, bridgeAmount);
        deal(alice.addr, 2 ether);
        vm.expectRevert(TokenController.TokenNotAllowed.selector);
        controllerProxy.bridgeToken{value: 0.1 ether}(remoteChainId, usdt, bridgeAmount, "0x");
        vm.stopPrank();
    }

    function test_BridgeTokenFromL2() public {
        vm.startPrank(alice.addr);
        uint256 bridgeAmount = 100_000_000;
        deal(address(usdc), alice.addr, bridgeAmount);
        deal(alice.addr, 2 ether);

        assertEq(IERC20(usdc).balanceOf(alice.addr), bridgeAmount);

        controllerProxy.bridgeToken{value: 0.1 ether}(remoteChainId, address(usdc), bridgeAmount, "0x");
        vm.stopPrank();

        assertEq(IERC20(usdc).balanceOf(alice.addr), 0);
    }

    function test_FailLzRecive() public {
        uint256 bridgeAmount = 100_000_000;
        deal(address(usdc), alice.addr, bridgeAmount);

        bytes memory _srcAddress = abi.encodePacked(address(controllerProxy), address(controllerProxy));
        bytes memory _payload = abi.encode(usdt, alice.addr, bridgeAmount);

        vm.startPrank(unrealEndpoint);
        controllerProxy.lzReceive(remoteChainId, _srcAddress, 1, _payload);
        vm.stopPrank();

        bytes32 msg0x;
        assertNotEq(controllerProxy.failedMessages(remoteChainId, _srcAddress, 1), msg0x);
    }

    function test_LzReceive() public {
        uint256 bridgeAmount = 100_000_000;
        assertEq(IERC20(usdc).balanceOf(alice.addr), 0);

        bytes memory _srcAddress = abi.encodePacked(address(controllerProxy), address(controllerProxy));
        bytes memory _payload = abi.encode(usdc, alice.addr, bridgeAmount);

        vm.startPrank(unrealEndpoint);
        controllerProxy.lzReceive(remoteChainId, _srcAddress, 1, _payload);
        vm.stopPrank();

        bytes32 msg0x;
        assertEq(controllerProxy.failedMessages(remoteChainId, _srcAddress, 1), msg0x);
        assertEq(IERC20(usdc).balanceOf(address(controllerProxy)), 0);
        assertEq(IERC20(usdc).balanceOf(alice.addr), bridgeAmount);
    }
}
