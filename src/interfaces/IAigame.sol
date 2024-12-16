// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IBaseToken} from "./IBaseToken.sol";
import {IAifeeProtocol} from "./IAifeeProtocol.sol";

interface IAigame {
    struct Game {
      uint256 round;
      uint256 endTime;
      // 给Ai agent分配的初始Aimo数量
      uint256 initAimo;
      uint256 totalStakeAmount; // 本局总押注金额 
      address winner; // which ai agent is winner

      // ai agent 列表
      address[] aiAgentList;
      mapping (address => bool) isAiAgent;
      // Ai agent 本局的奖金池, USDT
      mapping(address => uint256)  aiAgentSakeAmounts; // Ai agent 本局的stake amount
      // Ai agent 本局的Aimo数量
      mapping(address => uint256)  aiAgentAimoBalances; 

      // 用户本局押注金额给ai agent, USDT
      mapping (address=> mapping(address=>uint256))  userStakeAmounts;

      mapping (address=> bool)  hasClaimedPrize; // stake win
      mapping (address=> bool) hasClaimedAimo; // stake failed
    }

    function createGameRound(uint256 endTime,address[] memory aiAgentList, uint256 initAimo) external;
    function stake(uint256 amount, address aiAgent) external;
    function setGameWinner(uint256 round_, address winner) external;

    // user claim prize
    function claimPrizes(address user,uint256[] calldata roundList) external;
    function claimPrize(address user, uint256 round_) external;
    function claimAimo(address user, uint256 round_) external;
    function claimAimos(address user, uint256[] calldata rounds) external;

    // readers
    function getGameBaseInfo(uint256 round_) external view returns (uint256, uint256, uint256, uint256, address);
    function getUserStakeAmount(address user, uint256 round_) external view returns (uint256);
    function getAiAgentStakeAmount(address aiAgent, uint256 round_) external view returns (uint256);
    function getAiAgentAimoBalance(address aiAgent, uint256 round_) external view returns (uint256);
    function usdt() external view returns (IERC20);
    function aimo() external view returns (IBaseToken);
    function aifeeProtocol() external view returns (IAifeeProtocol);

    event TransferAimoInGame(address indexed from, address indexed to, uint256 amount,bytes noteDate);
    event Staked(uint256 indexed round, address indexed user, uint256 amount, uint256 fee);
    event GameWinnerSet(uint256 indexed round, address indexed winner);
    event GameCreated(uint256 indexed round, uint256 endTime, address[] aiAgentList, uint256 initAimo);

    // errors define
    error NoGameErr();
    error GameEndedErr(uint256 round);
    error GameNotEndErr(uint256 round);
    error CannotStakeAiAgent(uint256 round, address aiAgent);

    error NotAiAgentErr();
    error NotEnoughAimoErr(address);
    error GameWinnerAlreadySetErr(uint256 round);
    error GameWinnerNotSetErr(uint256  round);
    error NoUserGamePrizeErr(address user, uint256 round);

    error HasClaimedPrizeErr(address user, uint256 round);
    error HasClaimedAimoErr(address user, uint256 round);
}