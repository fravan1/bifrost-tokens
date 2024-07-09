// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ICREATE3Factory} from "./ICREATE3Factory.sol";
import {RealToken} from "src/RealToken.sol";

contract DeployToken is Script {
    address admin = 0x95e3664633A8650CaCD2c80A0F04fb56F65DF300;
    address controller = 0x3B2d4FDc0E8a8E7aa414073287F07BbB1f6620ad;

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

        RealToken token = new RealToken(admin, name, symbol, decimals);
        token.setController(controller);

        return address(token);
    }
}
