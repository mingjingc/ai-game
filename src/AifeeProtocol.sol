// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IAifeeProtocol} from "./interfaces/IAifeeProtocol.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract AifeeProtocol is IAifeeProtocol, Ownable {
    uint256 public constant rateBase = 1e4; // minimum 0.01 percent
    IERC20 public feeToken;
    uint256 public feeRate; // 0.01 percent
    uint256 public inviterIncomeRate; // 0.01 percent

    // inviter => income, if user stake, his inviter will get inviterIncomeRate of his stake fee
    mapping(address => uint256) public inviterIncome;
    // user => inviter
    mapping(address => address) public inviters;

    // @param owner_ 管理员地址
    // @param feeToken_ 手续费代币地址
    // @param feeRate_ 手续费率，百分比，小数位是2。如feeRate_ = 100，手续费率是100/10000 = 0.01, 表示1%手续费率
    // 如果是手续费率0.01%，则feeRate_ = 1，因为1/1e4 = 0.0001 = 0.01%
    // @param inviterIncomeRate_ 邀请人收益率，百分比，如上
    constructor(address owner_, address feeToken_, uint256 feeRate_, uint256 inviterIncomeRate_) Ownable(owner_) {
        feeToken = IERC20(feeToken_);
        feeRate = feeRate_;
        inviterIncomeRate = inviterIncomeRate_;
    }

    // 更新手续费率
    // @param feeRate_ 手续费率，
    // @param inviterIncomeRate_ 邀请人收益率
    function updateFeeRate(uint256 feeRate_, uint256 inviterIncomeRate_) external onlyOwner {
        feeRate = feeRate_;
        inviterIncomeRate = inviterIncomeRate_;
    }

    // 手续费结算
    // @param token 手续费代币地址
    // @param user 实际交手续的用户
    // @param amount 交手续费的金额
    function settleFee(address user, uint256 amount) external {
        address inviter = inviters[user];
        if (inviter != address(0)) {
            uint256 inviterIncomeAmount = (amount * inviterIncomeRate) / rateBase;
            feeToken.transferFrom(msg.sender, inviter, inviterIncomeAmount);
            emit InviterGotProfit(inviter, user, inviterIncomeAmount);

            // 扣去邀请人的提成
            amount -= inviterIncomeAmount;
        }

        feeToken.transferFrom(msg.sender, address(this), amount);
    }

    // 注册邀请关系, inviter是邀请人的地址
    function registerWithInviter(address inviter) external {
        address user = msg.sender;
        if (inviters[user] != address(0)) {
            revert InvitationRelationshipAlreadyExistErr(user);
        }
        inviters[user] = inviter;
    }

    function claimAllIncome(address to) external onlyOwner {
        uint256 amount = IERC20(feeToken).balanceOf(address(this));
        IERC20(feeToken).transfer(to, amount);

        emit ClaimedAllIncome(to, amount);
    }

    //==========================readers=====================
    function calcuateFee(uint256 stakeAmount) external view returns (uint256) {
        return (stakeAmount * feeRate) / rateBase;
    }
}
