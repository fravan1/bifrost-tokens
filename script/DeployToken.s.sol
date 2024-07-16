// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ICREATE3Factory} from "./ICREATE3Factory.sol";
import {RealToken} from "src/token/RealToken.sol";

contract DeployToken is Script {
    address admin = 0xeB658c4Ea908aC4dAF9c309D8f883d6aD758b3A3;
    address controller = 0x7dfe5d23761B7a748e962003e0FC6b4559afED39;

    address _deployer;

    // CREATE3 Factory
    ICREATE3Factory factory = ICREATE3Factory(0xe066Fe3B015Bc9fb9f68050e588831a49Ff40062);

    function run() public returns (address) {
        uint256 _pk = uint256(vm.envBytes32("PRIVATE_KEY"));
        vm.startBroadcast(_pk);
        _deployer = vm.addr(_pk);

        require(block.chainid == 111_188 || block.chainid == 18_233, "realChain");
        require(msg.sender == _deployer, "!deployer");

        string memory name = "USD Coin";
        string memory symbol = "USDC";
        uint8 decimals = 6;

        RealToken token = new RealToken{salt: keccak256(abi.encodePacked("real.usdc"))}(admin, name, symbol, decimals);
        token.setController(controller);

        return address(token);
    }
}
