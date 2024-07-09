// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ICREATE3Factory} from "./ICREATE3Factory.sol";
import {TokenController} from "src/TokenController.sol";
import {UUPSProxy} from "src/UUPSProxy.sol";

contract DeployController is Script {
    address admin = 0x95e3664633A8650CaCD2c80A0F04fb56F65DF300;
    address realLZEndpoint = 0x83c73Da98cf733B03315aFa8758834b36a195b87;
    address _deployer;
    TokenController controller;

    // CREATE3 Factory
    ICREATE3Factory factory = ICREATE3Factory(0xe066Fe3B015Bc9fb9f68050e588831a49Ff40062);

    function run() public returns (address proxy) {
        uint256 _pk = uint256(vm.envBytes32("PRIVATE_KEY"));
        vm.startBroadcast(_pk);
        _deployer = vm.addr(_pk);

        require(block.chainid == 111_188 || block.chainid == 18_233, "realChain");
        require(msg.sender == _deployer, "!deployer");

        controller = new TokenController(realLZEndpoint);
        bytes memory data = abi.encodeWithSelector(TokenController.initialize.selector, _deployer);

        bytes32 salt = keccak256(bytes("real.Controller"));
        bytes memory creationCode =
            abi.encodePacked(type(UUPSProxy).creationCode, abi.encode(address(controller), data));
        proxy = factory.deploy(salt, creationCode);
    }
}
