// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import "forge-std/Script.sol";

import {Aigame} from "src/AiGame.sol";
import {Aimo} from "src/tokens/Aimo.sol";
import {USDT} from "src/tokens/Usdt.sol";
import {AifeeProtocol} from "src/AiFeeProtocol.sol";
import {IAigame} from "src/interfaces/IAigame.sol";

contract AigameTest is Test {
    address owner = address(1001);
    address user = address(1002);

    address aiA = address(1003);
    address aiB = address(1004);

    Aigame public aigame;
    Aimo public aimo;
    USDT public usdt;
    AifeeProtocol public aifee;

    function setUp() public {
        usdt = new USDT();
        aimo = new Aimo(owner);
        aifee = new AifeeProtocol(owner, address(usdt), 100, 100);
        aigame = new Aigame(address(aifee), address(usdt), address(aimo), owner);

        vm.startPrank(owner);
        aimo.changeAdmin(address(aigame));
        vm.stopPrank();
    }

    function testStake() public {
        uint256 approveAmount = 10000 * 1e6;
        address aigameAddress = address(aigame);
        vm.startPrank(user);
        usdt.mint(user, approveAmount);
        usdt.approve(address(aigame), approveAmount);
        vm.stopPrank();
        assertEq(usdt.allowance(user, aigameAddress), approveAmount);

        uint256 stakeAmount = 30 * 1e6;
        uint256 beforeStartTime = 1734795806 - 1000;
        uint256 startTime = 1734795806;
        uint256 endTime = 1734795806 + 1000;
        uint256 initAimo = 400 * 1e18;
        address[] memory ais = new address[](2);
        ais[0] = aiA;
        ais[1] = aiB;

        vm.startPrank(owner);
        vm.warp(beforeStartTime);
        aigame.createGameRound(startTime, endTime, ais, initAimo);
        vm.stopPrank();

        vm.startPrank(user);
        vm.warp(startTime);
        aigame.stake(stakeAmount, aiA);
        vm.stopPrank();

        IAigame.GameBaseInfo memory baseInfo = aigame.getGameBaseInfo(1);
        assertEq(baseInfo.totalStakeAmount, stakeAmount - aifee.calcuateFee(stakeAmount));
    }
}
