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

  mapping(uint256 => Game) private games;
  uint256 public round;

  constructor(address aifeeProtocol_,address usdt_, address aimo_, address owner_) Ownable(owner_) {
    aifeeProtocol = IAifeeProtocol(aifeeProtocol_);
    usdt = IERC20(usdt_);
    aimo = IBaseToken(aimo_);
  }

  function createGameRound(uint256 endTime,address[] memory aiAgentList, uint256 initAimo) external onlyOwner {
    ++round;
  
    Game storage game = games[round];
    game.round = round;
    game.endTime = endTime;
    game.initAimo = initAimo;
    for(uint256 i = 0; i < aiAgentList.length; i++) {
      address aiAgent = aiAgentList[i];
      game.isAiAgent[aiAgent] = true;
      game.aiAgentAimoBalances[aiAgent] = initAimo;
      game.aiAgentList = aiAgentList;
    }

    emit GameCreated(round, endTime, aiAgentList, initAimo);
  }

  //  只能押注本轮
  function stake(uint256 amount, address aiAgent) external {
    Game storage game = games[round];
    if (game.endTime == 0) {
      revert NoGameErr();
    }
    if (game.endTime < block.timestamp) {
      revert GameEndedErr(round);
    }
    if (game.isAiAgent[aiAgent] == false) {
      revert NotAiAgentErr();
    }
    if (_checkCanStake(game.totalStakeAmount, game.aiAgentSakeAmounts[aiAgent]) == false) {
      revert CannotStakeAiAgent(round, aiAgent);
    }

    usdt.transferFrom(msg.sender, address(this), amount);
    uint256 fee = aifeeProtocol.calcuateFee(amount);
    if (fee > 0) {
      // 手续费协议收取手续费
      aifeeProtocol.collectFee(address(usdt), msg.sender, fee);
    }
    amount = amount - fee; // 扣除手续费, 实际押注的金额


    unchecked {
      game.totalStakeAmount += amount;
      game.aiAgentSakeAmounts[aiAgent] += amount;
      game.userStakeAmounts[msg.sender][aiAgent] += amount;
    }
    emit Staked(round, msg.sender, amount, fee);
  }

  function transferAimoInGame(uint256 amount, address to, bytes memory noteData) external  {
    Game storage game = games[round];
    if (game.endTime == 0) {
      revert NoGameErr();
    }
    if (game.endTime < block.timestamp) {
      revert GameEndedErr(round);
    }

    if (game.aiAgentAimoBalances[msg.sender] < amount) {
      revert NotEnoughAimoErr(msg.sender);
    }
    unchecked {
      game.aiAgentAimoBalances[msg.sender] -= amount;
      game.aiAgentAimoBalances[to] += amount;
    }

    emit TransferAimoInGame(msg.sender, to, amount, noteData);
  }

  function setGameWinner(uint256 round_, address winner) external onlyOwner {
    Game storage game = games[round_];
    if (game.endTime == 0) {
      revert NoGameErr();
    }
    if (game.endTime >= block.timestamp) {
      revert GameNotEndErr(round_);
    }
    if (game.isAiAgent[winner] == false) {
      revert NotAiAgentErr();
    }

    if (game.winner != address(0)) {
      revert GameWinnerAlreadySetErr(round_);
    }
    
    game.winner = winner;
    emit GameWinnerSet(round_, winner);
  }

  function claimPrizes(address user,uint256[] calldata roundList) external {
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


  //=======================readers=================
  function getGameBaseInfo(uint256 round_) external view returns (uint256, uint256, uint256, uint256, address) {
    Game storage game  = games[round_];
    return (game.round, game.endTime, game.initAimo, game.totalStakeAmount, game.winner);
  }
  function getUserStakeAmount(address user, uint256 round_) external view returns (uint256) {
    Game storage game = games[round_];
    return game.userStakeAmounts[user][game.winner];
  }
  function getAiAgentStakeAmount(address aiAgent, uint256 round_) external view returns (uint256) {
    Game storage game = games[round_];
    return game.aiAgentSakeAmounts[aiAgent];
  }


  //=====================internal=======================
  function _claimPrize(address user,Game storage game) internal {
    if (game.endTime == 0) {
      revert NoGameErr();
    }
    if (game.winner == address(0)) {
      revert GameWinnerNotSetErr(game.round);
    }
    if (game.hasClaimedPrize[user]) {
      revert HasClaimedPrizeErr(user, game.round);
    }
    game.hasClaimedPrize[user] = true;

    uint256 prize = _calculateUserPrize(game.userStakeAmounts[user][game.winner], 
                        game.aiAgentSakeAmounts[game.winner], game.totalStakeAmount);
    if (prize == 0) {
      return;
    }
    usdt.transfer(user, prize);
  }

  // 如果失败, 领取Aimo作为安慰奖
  function _claimAimo(address user, Game storage game) internal {
    address winner = game.winner;
    if (winner == address(0)) {
      revert GameWinnerNotSetErr(game.round);
    }
    if (game.hasClaimedAimo[user]) {
      revert HasClaimedAimoErr(user, game.round);
    }
    game.hasClaimedAimo[user] = true;

    uint256 totalPrize = 0;
    for(uint256 i = 0; i < game.aiAgentList.length; i++) {
      address aiAgent = game.aiAgentList[i];
      uint256 prize = _calculateUserGotAimo(game.userStakeAmounts[user][aiAgent],
                        game.aiAgentSakeAmounts[aiAgent], game.aiAgentAimoBalances[aiAgent]);
      totalPrize += prize;
    }
    aimo.mint(user, totalPrize);
  }

  function _calculateUserGotAimo(uint256 userStakeAmount, uint256 agentAiStakeAmount, uint256 agentAiAimo) internal pure returns (uint256) {
    return userStakeAmount * agentAiAimo / agentAiStakeAmount;
  }

  function _calculateUserPrize(uint256 userStakeAmount, uint256 agentAiStakeAmount, uint256 gameStakeAmount) internal pure returns (uint256) {
    return userStakeAmount * gameStakeAmount / agentAiStakeAmount;
  }

  function _checkCanStake(uint256 totalStakeAmount, uint256 aiAgentStakeAmount) internal view returns (bool) {
    return (totalStakeAmount - aiAgentStakeAmount)*(aifeeProtocol.rateBase() - aifeeProtocol.feeRate()) >= 
              aiAgentStakeAmount*aifeeProtocol.rateBase();
  }
}