// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import {IAifeeProtocol} from "./interfaces/IAifeeProtocol.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract AifeeProtocol is IAifeeProtocol, Ownable, EIP712, Nonces {
    bytes32 private constant INVITE_TYPEHASH =
        keccak256("Invite(address inviter,user address,uint256 nonce,uint256 deadline)");


    uint256 public constant rateBase = 1e4; // minimum 0.01 percent
    address public feeToken;
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
    constructor(
        address owner_,
        address feeToken_,
        uint256 feeRate_,
        uint256 inviterIncomeRate_
    ) Ownable(owner_) EIP712("AifeeProtocol", "1") {
        feeToken = feeToken_;
        feeRate = feeRate_;
        inviterIncomeRate = inviterIncomeRate_;
    }

    // 更新手续费率
    // @param feeRate_ 手续费率，
    function updateFeeRate(uint256 feeRate_) external onlyOwner {
        feeRate = feeRate_;
    }

    // 收取手续费，这个方法由Aigame合约调用。当然其他人调用免费送钱也是可以的，但是不推荐。
    // @param token 手续费代币地址
    // @param user 实际交手续的用户
    // @param amount 交手续费的金额
    function collectFee(address token, address user, uint256 amount) external {
        if (token != feeToken) {
            revert FeeTokenNotSupportedErr();
        }

        address inviter = inviters[user];
        if (inviter != address(0)) {
            uint256 inviterIncomeAmount = amount * inviterIncomeRate / rateBase;
            inviterIncome[inviter] += inviterIncomeAmount;
        }

        IERC20(token).transferFrom(msg.sender, address(this), amount);
    }

    // 绑定邀请关系，在去中心化世界中，需要你邀请人的签名。
    // 为什么不能用邀请码，因为在去中心化世界，你没办法知道邀请码属于某个地址
    // @param user 被邀请人地址
    // @param deadline 签名过期时间戳
    // @param v 签名v值
    // @param r 签名r值
    // @param s 签名s值
    // @dev 签名数据是由用户签名的，用户签名的数据是：INVITE_TYPEHASH(inviter,user,nonce,deadline)
    // @dev 签名数据的hash是：keccak256(abi.encode(INVITE_TYPEHASH, inviter, user, nonce, deadline))，符合EIP712的标准
    function inviteUser(address user,uint256 deadline, uint8 v, bytes32 r, bytes32 s) external {
        if (deadline < block.timestamp) {
            revert ERC2612ExpiredSignatureErr(deadline);
        }
        if (inviters[user] != address(0)) {
            revert InvitationRelationshipAlreadyExistErr(user);
        }

        uint256 nonce = _useNonce(user);
        address inviter = msg.sender;
        bytes32 structHash = keccak256(abi.encode(INVITE_TYPEHASH, inviter, user, nonce, deadline));
        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(hash, v, r, s);

        if (signer != user) {
            revert UserNotAggreeInvitationErr();
        }
        inviters[user] = inviter;
    }

    // 领取邀收益
    function claimIncome(address user) external {
        uint256 amount = inviterIncome[user];
        inviterIncome[user] = 0;
        
        IERC20(feeToken).transfer(msg.sender, amount);
        emit ClaimedIncome(user, amount);
    }


    //==========================readers=====================
    function calcuateFee(uint256 stakeAmount) external view returns (uint256) {
        return stakeAmount * feeRate / rateBase;
    }
}