// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IBaseToken} from "./IBaseToken.sol";
import {IAifeeProtocol} from "./IAifeeProtocol.sol";

interface IAigame {
     struct GameBaseInfo {
      uint256 round; // 第几轮游戏
      uint256 startTime; // 开始时间
      uint256 endTime; // 结束时间
      uint256 totalStakeAmount; // 本局总押注金额
      address winner; // 那个ai赢了
      uint256 initAimo; // 每个ai初始的Aimo数量
      address[] aiList; // 参与游戏的ai
    }
    struct UserInfo {
      // 一个用户在一局中可以押注多个ai
      bool hasClaimedPrize; // 当赢的时候
      bool hasClaimedAimo; // 当输的时候
      mapping (address=>uint256) stakeAmounts;
    }

    struct AiInfo {
      address addr;
      uint256 stakeAmount; // AI被押注金额
      uint256 aimoBalance; // AI的Aimo余额，当失败会发给用户当作安慰奖
    }

    // 一局游戏
    struct Game {
      GameBaseInfo baseInfo;
      mapping (address=> UserInfo) userMap;
      mapping (address=> AiInfo) aiMap;
    }

    function createGameRound(uint256 startTime, uint256 endTime,address[] memory aiAgentList, uint256 initAimo) external;
    function stake(uint256 amount, address aiAgent) external;
    function setGameWinner(uint256 round_, address winner) external;

    // user claim prize
    function claimPrizes(address user,uint256[] calldata roundList) external;
    function claimPrize(address user, uint256 round_) external;
    function claimAimo(address user, uint256 round_) external;
    function claimAimos(address user, uint256[] calldata rounds) external;

    // readers
    function getGameBaseInfo(uint256 round_) external view returns (GameBaseInfo memory);
    function getUserInfo(address user, uint256 round_) external view returns (bool, bool,address[] memory, uint256[] memory);
    function getAiInfo(address ai, uint256 round_) external view returns (uint256, uint256, bool);
    function usdt() external view returns (IERC20);
    function aimo() external view returns (IBaseToken);
    function aifeeProtocol() external view returns (IAifeeProtocol);

    event TransferAimoInGame(address indexed from, address indexed to, uint256 amount,bytes noteDate);
    event Staked(uint256 indexed round, address indexed user, uint256 amount, uint256 fee);
    event GameWinnerSet(uint256 indexed round, address indexed winner);
    event GameCreated(uint256 indexed round, uint256 startTime, uint256 endTime, address[] aiAgentList, uint256 initAimo);

    // errors define
    error NoGameErr();
    error GameEndOrNotStartErr(uint256 round);
    error GameNotEndErr(uint256 round);
    error CannotStakeAiAgent(uint256 round, address aiAgent);

    error NotAiErr();
    error NotEnoughAimoErr(address);
    error GameWinnerAlreadySetErr(uint256 round);
    error GameWinnerNotSetErr(uint256  round);
    error NoUserGamePrizeErr(address user, uint256 round);

    error HasClaimedPrizeErr(address user, uint256 round);
    error HasClaimedAimoErr(address user, uint256 round);
}