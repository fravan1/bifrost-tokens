// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ICREATE3Factory} from "./ICREATE3Factory.sol";
import {Vault} from "src/Vault.sol";
import {UUPSProxy} from "src/base/UUPSProxy.sol";

contract DeployVault is Script {
    address admin = 0xeB658c4Ea908aC4dAF9c309D8f883d6aD758b3A3;
    address vaultLZEndpoint = 0x3c2269811836af69497E5F486A85D7316753cf62;
    uint16 realLZChainId = 237;

    address _deployer;
    Vault vault;

    // CREATE3 Factory
    ICREATE3Factory factory = ICREATE3Factory(0xe066Fe3B015Bc9fb9f68050e588831a49Ff40062);

    function run() public returns (address proxy) {
        uint256 _pk = uint256(vm.envBytes32("PRIVATE_KEY"));
        vm.startBroadcast(_pk);
        _deployer = vm.addr(_pk);

        // can't be deployed on real chain
        require(block.chainid != 111_188 || block.chainid != 18_233, "!realChain");
        require(msg.sender == _deployer, "!deployer");

        vault = new Vault(vaultLZEndpoint, realLZChainId);
        bytes memory data = abi.encodeWithSelector(Vault.initialize.selector, _deployer);

        console.logBytes(data);

        bytes32 salt = keccak256(bytes("real.bridge.vault"));
        bytes memory creationCode = abi.encodePacked(type(UUPSProxy).creationCode, abi.encode(address(vault), data));
        proxy = factory.deploy(salt, creationCode);
    }
}
