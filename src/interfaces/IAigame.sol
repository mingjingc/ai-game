// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IAigame {
    struct Game {
      uint256 round;
      uint256 endTime;
      // 给Ai agent分配的初始Aimo数量
      uint256 initAimo;
      uint256 totalStakeAmount; // 本局总押注金额 
      address winner; // which ai agent is winner

      mapping (address => bool) isAiAgent;
      // Ai agent 本局的奖金池, USDT
      mapping(address => uint256)  aiAgentSakeAmounts; // Ai agent 本局的stake amount
      // Ai agent 本局的Aimo数量
      mapping(address => uint256)  aiAgentAimoBalances; 

      // 用户本局押注金额给ai agent, USDT
      mapping (address=> mapping(address=>uint256))  userStakeAmounts;
    }

    event TransferAimoInGame(address indexed from, address indexed to, uint256 amount,bytes noteDate);
    event Staked(uint256 indexed round, address indexed user, uint256 amount, uint256 fee);
    event GameWinnerSet(uint256 indexed round, address indexed winner);

    // errors define
    error NoGameErr();
    error GameEndedErr(uint256 round);
    error GameNotEndErr(uint256 round);
    error CannotStakeAiAgent(uint256 round, address aiAgent);

    error NoAiAgentErr();
    error NotEnoughAimoErr(address);
    error GameWinnerAlreadySetErr(uint256 round);
    error GameWinnerNotSetErr(uint256  round);
    error NoUserGamePrizeErr(address user, uint256 round);
}