// SPDX-License-Identifier: MIT
pragma solidity =0.8.21;

import {Test, console2 as console} from "forge-std/Test.sol";
import {Vault} from "src/Vault.sol";
import {UUPSProxy} from "src/UUPSProxy.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract VaultTest is Test {
    string ARBITRUM_SEPOLIA_RPC_URL = vm.envString("ARBITRUM_SEPOLIA_RPC_URL");

    address public usdt = 0x9aA40Cc99973d8407a2AE7B2237d26E615EcaFd2;
    address public usdc = 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d;
    address public l2Usdc = 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d;
    address public arbEndPoint = 0x6098e96a28E02f27B1e6BD381f870F1C8Bd169d3;
    uint16 public remoteChainId = 10_262;

    address l2Controller;

    Account public admin;
    Account public alice;

    Vault v1;
    Vault vaultProxy;

    function setUp() public {
        vm.createSelectFork(ARBITRUM_SEPOLIA_RPC_URL, 61_813_940);

        admin = makeAccount("admin");
        alice = makeAccount("alice");

        v1 = new Vault(arbEndPoint, remoteChainId);
        bytes memory vaultData = abi.encodeWithSelector(Vault.initialize.selector, admin.addr);
        UUPSProxy proxy = new UUPSProxy(address(v1), vaultData);
        vaultProxy = Vault(address(proxy));

        l2Controller = address(vaultProxy);

        vm.startPrank(admin.addr);
        vaultProxy.setWhitelistToken(usdc, l2Usdc);
        bytes memory path = abi.encodePacked(address(vaultProxy), l2Controller);
        vaultProxy.setTrustedRemote(remoteChainId, path);
        vm.stopPrank();
    }

    function test_FailBridgeToken() public {
        vm.startPrank(alice.addr);
        uint256 bridgeAmount = 100_000_000;
        deal(usdt, alice.addr, bridgeAmount);
        deal(alice.addr, 2 ether);
        vm.expectRevert(Vault.TokenNotAllowed.selector);
        vaultProxy.bridgeToken{value: 0.1 ether}(usdt, bridgeAmount, "0x");
        vm.stopPrank();
    }

    function test_BridgeToken() public {
        vm.startPrank(alice.addr);
        uint256 bridgeAmount = 100_000_000;
        deal(usdc, alice.addr, bridgeAmount);
        deal(alice.addr, 2 ether);

        assertEq(IERC20(usdc).balanceOf(alice.addr), bridgeAmount);

        IERC20(usdc).approve(address(vaultProxy), bridgeAmount);
        vaultProxy.bridgeToken{value: 0.1 ether}(usdc, bridgeAmount, "");
        vm.stopPrank();
        assertEq(IERC20(usdc).balanceOf(alice.addr), 0);
    }

    function test_FailLzRecive() public {
        uint256 bridgeAmount = 100_000_000;
        deal(usdc, address(vaultProxy), bridgeAmount);
        bytes memory _srcAddress = abi.encodePacked(address(vaultProxy), l2Controller);
        bytes memory _payload = abi.encode(usdt, alice.addr, bridgeAmount);

        vm.startPrank(arbEndPoint);
        vaultProxy.lzReceive(remoteChainId, _srcAddress, 1, _payload);
        vm.stopPrank();

        bytes32 msg0x;
        assertNotEq(vaultProxy.failedMessages(remoteChainId, _srcAddress, 1), msg0x);
    }

    function test_FailLzReciveSender() public {
        uint256 bridgeAmount = 100_000_000;
        deal(usdc, address(vaultProxy), bridgeAmount);
        bytes memory _srcAddress = abi.encodePacked(address(vaultProxy), l2Controller);
        bytes memory _payload = abi.encode(usdc, alice.addr, bridgeAmount);

        vm.startPrank(alice.addr);
        vm.expectRevert();
        vaultProxy.lzReceive(remoteChainId, _srcAddress, 1, _payload);
        vm.stopPrank();
    }

    function test_LzReceive() public {
        uint256 bridgeAmount = 100_000_000;
        deal(usdc, address(vaultProxy), bridgeAmount);

        assertEq(IERC20(usdc).balanceOf(alice.addr), 0);
        assertEq(IERC20(usdc).balanceOf(address(vaultProxy)), bridgeAmount);

        vm.startPrank(arbEndPoint);
        bytes memory _srcAddress = abi.encodePacked(address(vaultProxy), l2Controller);
        bytes memory _payload = abi.encode(l2Usdc, alice.addr, bridgeAmount);
        vaultProxy.lzReceive(remoteChainId, _srcAddress, 1, _payload);
        vm.stopPrank();

        bytes32 msg0x;
        assertEq(vaultProxy.failedMessages(remoteChainId, _srcAddress, 1), msg0x);
        assertEq(IERC20(usdc).balanceOf(address(vaultProxy)), 0);
        assertEq(IERC20(usdc).balanceOf(alice.addr), bridgeAmount);
    }

    function test_FailRecueToken() public {
        uint256 bridgeAmount = 100_000_000;
        deal(usdc, address(vaultProxy), bridgeAmount);
        vm.startPrank(alice.addr);
        vm.expectRevert();
        vaultProxy.rescueToken(usdc, alice.addr, bridgeAmount);
        vm.stopPrank();
    }

    function test_RecueToken() public {
        uint256 bridgeAmount = 100_000_000;
        deal(usdc, address(vaultProxy), bridgeAmount);
        vm.startPrank(admin.addr);
        vaultProxy.rescueToken(usdc, alice.addr, bridgeAmount);
        vm.stopPrank();
        assertEq(IERC20(usdc).balanceOf(alice.addr), bridgeAmount);
    }
}
