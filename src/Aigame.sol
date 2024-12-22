// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IAigame} from "./interfaces/IAigame.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IBaseToken} from "./interfaces/IBaseToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAifeeProtocol} from "./interfaces/IAifeeProtocol.sol";

contract Aigame is IAigame, Ownable {
    IERC20 public usdt;
    IBaseToken public aimo; // Aimo token
    IAifeeProtocol public aifeeProtocol;
    uint256 public constant minStakeAmount = 10 * 1e6;
    uint256 public constant maxStakeAmount = 5000 * 1e6;

    mapping(uint256 => Game) private games;
    uint256 public round;

    // @param aifeeProtocol 手续费协议合约地址
    // @param usdt USDT合约地址
    // @param aimo Aimo合约地址
    // @param owner 管理员地址
    constructor(IAifeeProtocol aifeeProtocol_, IERC20 usdt_, IBaseToken aimo_, address owner_) Ownable(owner_) {
        aifeeProtocol = IAifeeProtocol(aifeeProtocol_);
        usdt = IERC20(usdt_);
        aimo = IBaseToken(aimo_);
    }

    // 管理员创建一局游戏，
    // @param endTime 游戏结束时间
    // @param aiAgentList 参与游戏的bot
    // @param initAimo 每个bot初始的Aimo数量
    function createGameRound(uint256 startTime, uint256 endTime, address[] memory aiList, uint256 initAimo)
        external
        onlyOwner
    {
        ++round;

        Game storage game = games[round];
        // 初始化游戏基本信息
        GameBaseInfo storage baseInfo = game.baseInfo;
        baseInfo.round = round;
        baseInfo.startTime = startTime;
        baseInfo.endTime = endTime;
        baseInfo.initAimo = initAimo;
        baseInfo.aiList = aiList;
        // 初始化ai信息
        mapping(address => AiInfo) storage aiMap = game.aiMap;
        for (uint256 i = 0; i < aiList.length; i++) {
            address ai = aiList[i];
            AiInfo storage aiInfo = aiMap[ai];

            aiInfo.addr = ai;
            aiInfo.stakeAmount = 0;
            aiInfo.aimoBalance = initAimo;
        }

        emit GameCreated(round, startTime, endTime, aiList, initAimo);
    }

    //  用户押注某个bot，只能押注本轮
    // @param amount 押注金额
    // @param aiAgent 押注的bot
    function stake(uint256 amount, address ai) external {
        Game storage game = games[round]; // 获取本轮游戏
        AiInfo storage aiInfo = game.aiMap[ai]; // 获取本轮游戏的ai信息
        GameBaseInfo storage baseInfo = game.baseInfo; // 本轮游戏基本信息
        UserInfo storage userInfo = game.userMap[msg.sender]; // 获取本轮游戏的用户信息
        address user = msg.sender; // 押注的用户地址

        if (userInfo.totalStakeAmount + amount > maxStakeAmount) {
            revert StakeAmountTooLargeErr(userInfo.totalStakeAmount + amount);
        }
        if (amount < minStakeAmount) {
            revert StakeAmountTooSmallErr(amount);
        }
        if (aiInfo.addr == address(0)) {
            revert NotAiErr();
        }
        if (baseInfo.round == 0) {
            revert NoGameErr();
        }
        if (baseInfo.endTime < block.timestamp || baseInfo.startTime > block.timestamp) {
            revert GameEndOrNotStartErr(round);
        }
        if (aiInfo.addr == address(0)) {
            revert NotAiErr();
        }
        if (_checkCanStake(baseInfo.totalStakeAmount, aiInfo.stakeAmount) == false) {
            revert CannotStakeAiAgent(round, ai);
        }

        usdt.transferFrom(user, address(this), amount);
        uint256 fee = aifeeProtocol.calcuateFee(amount);
        if (fee > 0) {
            usdt.approve(address(aifeeProtocol), fee);
            aifeeProtocol.settleFee(user, fee);
        }
        amount = amount - fee; // 扣除手续费, 实际押注的金额

        unchecked {
            baseInfo.totalStakeAmount += amount;
            aiInfo.stakeAmount += amount;
            userInfo.stakeAmounts[ai] += amount;
            userInfo.totalStakeAmount += amount;
        }

        emit Staked(round, user, amount, 0);
    }

    // bot之间转账，noteData为转账备注
    function transferAimoInGame(uint256 amount, address to, bytes memory noteData) external {
        Game storage game = games[round];
        GameBaseInfo storage baseInfo = game.baseInfo;
        AiInfo storage fromAi = game.aiMap[msg.sender];
        AiInfo storage toAi = game.aiMap[to];

        if (fromAi.addr == address(0) || toAi.addr == address(0)) {
            revert NotAiErr();
        }
        if (baseInfo.round == 0) {
            revert NoGameErr();
        }
        if (baseInfo.endTime < block.timestamp || baseInfo.startTime > block.timestamp) {
            revert GameEndOrNotStartErr(round);
        }

        if (fromAi.aimoBalance < amount) {
            revert NotEnoughAimoErr(msg.sender);
        }
        unchecked {
            fromAi.aimoBalance -= amount;
            toAi.aimoBalance += amount;
        }

        emit TransferAimoInGame(msg.sender, to, amount, noteData);
    }

    // 在游戏结束后，管理员可以设置游戏胜利bot
    function setGameWinner(uint256 round_, address winner) external onlyOwner {
        Game storage game = games[round_];
        GameBaseInfo storage baseInfo = game.baseInfo;

        if (baseInfo.endTime == 0) {
            revert NoGameErr();
        }
        if (baseInfo.endTime >= block.timestamp) {
            revert GameNotEndErr(round_);
        }
        if (game.aiMap[winner].addr == address(0)) {
            revert NotAiErr();
        }
        if (baseInfo.winner != address(0)) {
            revert GameWinnerAlreadySetErr(round_);
        }

        baseInfo.winner = winner;
        emit GameWinnerSetted(round_, winner);
    }

    // 押注胜利者可以领取 USDT 奖金
    function claimPrizes(address user, uint256[] calldata roundList) external {
        for (uint256 i = 0; i < roundList.length; i++) {
            uint256 r = roundList[i];
            Game storage game = games[r];
            _claimPrize(user, game);
        }
    }

    function claimPrize(address user, uint256 round_) external {
        Game storage game = games[round_];
        _claimPrize(user, game);
    }

    // 押注失败者可以领取 Aimo 安慰奖金
    function claimAimo(address user, uint256 round_) external {
        Game storage game = games[round_];
        _claimAimo(user, game);
    }

    function claimAimos(address user, uint256[] calldata rounds) external {
        for (uint256 i = 0; i < rounds.length; i++) {
            uint256 r = rounds[i];
            Game storage game = games[r];
            _claimAimo(user, game);
        }
    }

    //=======================readers=================
    // 获取游戏的基本信息
    function getGameBaseInfo(uint256 round_) external view returns (GameBaseInfo memory) {
        Game storage game = games[round_];
        return game.baseInfo;
    }
    // 获取某个游戏的用户信息
    // @return 1.是否已经领取过USDT奖金
    // @return 2.是否已经领取过Aimo安慰奖金
    // @return 3.ai列表
    // @return 4.用户对每个ai的押注金额

    function getUserInfo(address user, uint256 round_)
        external
        view
        returns (bool, bool, address[] memory, uint256[] memory)
    {
        UserInfo storage userInfo = games[round_].userMap[user];
        GameBaseInfo storage baseInfo = games[round_].baseInfo;

        address[] memory aiList = baseInfo.aiList;
        uint256[] memory stakeAmounts = new uint256[](baseInfo.aiList.length);
        for (uint256 i = 0; i < baseInfo.aiList.length; i++) {
            address ai = aiList[i];
            stakeAmounts[i] = userInfo.stakeAmounts[ai];
        }

        return (userInfo.hasClaimedPrize, userInfo.hasClaimedAimo, aiList, stakeAmounts);
    }

    // 获取某个游戏的ai信息
    // @return 1.ai的押注金额
    // @return 2.ai的Aimo余额
    // @return 3.ai是否是胜利
    function getAiInfo(address ai, uint256 round_) external view returns (uint256, uint256, bool) {
        AiInfo storage aiInfo = games[round_].aiMap[ai];
        GameBaseInfo storage baseInfo = games[round_].baseInfo;
        if (aiInfo.addr == address(0)) {
            revert NotAiErr();
        }

        return (aiInfo.stakeAmount, aiInfo.aimoBalance, aiInfo.addr == baseInfo.winner);
    }

    //=====================internal=======================
    function _claimPrize(address user, Game storage game) internal {
        UserInfo storage userInfo = game.userMap[user];

        if (game.baseInfo.winner == address(0)) {
            revert GameWinnerNotSetErr(game.baseInfo.round);
        }
        if (userInfo.hasClaimedPrize) {
            revert HasClaimedPrizeErr(user, game.baseInfo.round);
        }

        userInfo.hasClaimedPrize = true;
        address winner = game.baseInfo.winner;

        uint256 prize = _calculateUserPrize(
            game.userMap[user].stakeAmounts[winner], game.aiMap[winner].stakeAmount, game.baseInfo.totalStakeAmount
        );
        if (prize == 0) {
            return;
        }
        usdt.transfer(user, prize);
    }

    // 如果失败, 领取Aimo作为安慰奖
    function _claimAimo(address user, Game storage game) internal {
        address winner = game.baseInfo.winner;
        UserInfo storage userInfo = game.userMap[user];
        GameBaseInfo storage baseInfo = game.baseInfo;

        if (winner == address(0)) {
            revert GameWinnerNotSetErr(game.baseInfo.round);
        }
        if (userInfo.hasClaimedAimo) {
            revert HasClaimedAimoErr(user, game.baseInfo.round);
        }
        userInfo.hasClaimedAimo = true;

        uint256 totalPrize = 0;
        for (uint256 i = 0; i < baseInfo.aiList.length; i++) {
            address ai = baseInfo.aiList[i];
            uint256 prize =
                _calculateUserGotAimo(userInfo.stakeAmounts[ai], game.aiMap[ai].stakeAmount, game.aiMap[ai].aimoBalance);
            totalPrize += prize;
        }
        aimo.mint(user, totalPrize);
    }

    function _calculateUserGotAimo(uint256 userStakeAmount, uint256 agentAiStakeAmount, uint256 agentAiAimo)
        internal
        pure
        returns (uint256)
    {
        return userStakeAmount * agentAiAimo / agentAiStakeAmount;
    }

    function _calculateUserPrize(uint256 userStakeAmount, uint256 aiStakeAmount, uint256 gameStakeAmount)
        internal
        pure
        returns (uint256)
    {
        if (aiStakeAmount == 0) {
            return 0;
        }
        return userStakeAmount * gameStakeAmount / aiStakeAmount;
    }

    function _checkCanStake(uint256 totalStakeAmount, uint256 aiAgentStakeAmount) internal view returns (bool) {
        if (totalStakeAmount == 0 || aiAgentStakeAmount == 0) {
            return true;
        }
        return (totalStakeAmount - aiAgentStakeAmount) * (aifeeProtocol.rateBase() - aifeeProtocol.feeRate())
            >= aiAgentStakeAmount * aifeeProtocol.rateBase();
    }
}
