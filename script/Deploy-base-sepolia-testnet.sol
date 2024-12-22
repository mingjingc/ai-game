// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Aigame} from "src/Aigame.sol";
import {AifeeProtocol} from "src/AifeeProtocol.sol";
import {Aimo} from "src/tokens/Aimo.sol";
import {USDT} from "src/tokens/Usdt.sol";

contract DeployBaseSepoliaTestnet is Script {
    function run() external {
        address sender = msg.sender;
        address owner = 0x14FdF30C64DB6bF32199d983Bcb3f73BfD3E3C18;
        console.log("Deploying to Sepolia Testnet, owner: ", owner);
        vm.startBroadcast();

        USDT usdt = new USDT();
        console.log("USDT deployed at: ", address(usdt));

        Aimo aimo = new Aimo(sender);
        console.log("Aimo deployed at: ", address(aimo));

        AifeeProtocol aifeeProtocol = new AifeeProtocol(owner, usdt, 100, 100);
        console.log("AifeeProtocol deployed at: ", address(aifeeProtocol));

        Aigame aigame = new Aigame(aifeeProtocol, usdt, aimo, owner);
        console.log("Aigame deployed at: ", address(aigame));

        aimo.changeAdmin(address(aigame));
        console.log("Aimo admin changed to: ", address(aigame));
        aimo.transferOwnership(owner);
        console.log("Aimo owner changed to: ", owner);

        vm.stopBroadcast();
    }
}
