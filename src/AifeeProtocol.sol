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

    function updateFeeRate(uint256 feeRate_) external onlyOwner {
        feeRate = feeRate_;
    }

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

    // user is invitee
    // 绑定邀请人, 只能调用一次，需要收腰人的签名
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

    function claimIncome(address user) external {
        uint256 amount = inviterIncome[user];
        inviterIncome[user] = 0;
        IERC20(feeToken).transfer(msg.sender, amount);
    }


    //==========================readers=====================
    function calcuateFee(uint256 stakeAmount) external view returns (uint256) {
        return stakeAmount * feeRate / rateBase;
    }
}