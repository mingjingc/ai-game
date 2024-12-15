// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IAifeeProtocol {
  function updateFeeRate(uint256 feeRate_) external;
  function feeRate() external view returns (uint256);
  function calcuateFee(uint256 stakeAmount) external view returns (uint256);
  function collectFee(address token,address user, uint256 amount) external;
  function rateBase() external pure returns (uint256);

  function inviteUser(address user,uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;
  function claimIncome(address user) external;

  error FeeTokenNotSupportedErr();
  error UserNotAggreeInvitationErr();
  error ERC2612ExpiredSignatureErr(uint256 deadline);
  error InvitationRelationshipAlreadyExistErr(address user);
}