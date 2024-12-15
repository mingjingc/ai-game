// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IAifeeProtocol {
  function feeRate() external view returns (uint256);
  function calcuateFee(uint256 stakeAmount) external view returns (uint256);
  function collectFee(address token,address user, uint256 amount) external;
  function rateBase() external pure returns (uint256);

  error FeeTokenNotSupportedErr();
  error UserNotAggreeInvitationErr();
  error ERC2612ExpiredSignatureErr(uint256 deadline);
  error InvitationRelationshipAlreadyExistErr(address user);
}