// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Aigame} from "src/Aigame.sol";
import {AifeeProtocol} from "src/AifeeProtocol.sol";
import {Aimo} from "src/tokens/Aimo.sol";
import {USDT} from "src/tokens/Usdt.sol";

contract DeployBaseSepoliaTestnet is Script {
    function run() external {
        address owner = msg.sender;
        console.log("Deploying to Sepolia Testnet, owner: ", owner);
        vm.startBroadcast();

        USDT usdt = new USDT();
        console.log("USDT deployed at: ", address(usdt));

        Aimo aimo = new Aimo(owner, owner);
        console.log("Aimo deployed at: ", address(aimo));

        AifeeProtocol aifeeProtocol = new AifeeProtocol(
            owner,
            address(usdt),
            100,
            100
        );
        console.log("AifeeProtocol deployed at: ", address(aifeeProtocol));

        Aigame aigame = new Aigame(
            address(aifeeProtocol),
            address(usdt),
            address(aimo),
            owner
        );
        console.log("Aigame deployed at: ", address(aigame));

        aimo.changeAdmin(address(aigame));
        console.log("Aimo admin changed to: ", address(aigame));

        vm.stopBroadcast();
    }
}
