// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ICREATE3Factory} from "./ICREATE3Factory.sol";
import {Vault} from "src/Vault.sol";
import {UUPSProxy} from "src/UUPSProxy.sol";

contract DeployVault is Script {
    address admin = 0x95e3664633A8650CaCD2c80A0F04fb56F65DF300;
    address vaultLZEndpoint = 0xae92d5aD7583AD66E49A0c67BAd18F6ba52dDDc1;
    uint16 realLZChainId = 10_262;

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

        bytes32 salt = keccak256(bytes("real.Vault"));
        bytes memory creationCode = abi.encodePacked(type(UUPSProxy).creationCode, abi.encode(address(vault), data));
        proxy = factory.deploy(salt, creationCode);
    }
}
