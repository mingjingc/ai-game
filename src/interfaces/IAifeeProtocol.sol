// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IAifeeProtocol {
    function updateFeeRate(uint256 feeRate_, uint256 inviterIncomeRate_) external;
    function feeRate() external view returns (uint256);
    function calcuateFee(uint256 stakeAmount) external view returns (uint256);
    function settleFee(address user, uint256 amount) external;
    function rateBase() external pure returns (uint256);

    function registerWithInviter(address inviter) external;
    function claimAllIncome(address to) external;

    event ClaimedAllIncome(address indexed to, uint256 amount);
    event InviterGotProfit(address indexed inviter, address indexed user, uint256 amount);

    error FeeTokenNotSupportedErr();
    error UserNotAggreeInvitationErr();
    error ERC2612ExpiredSignatureErr(uint256 deadline);
    error InvitationRelationshipAlreadyExistErr(address user);
}
