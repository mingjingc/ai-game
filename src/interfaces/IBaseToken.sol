// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IBaseToken is IERC20 {
    function mint(address account, uint256 amount) external;

    function burn(address account, uint256 amount) external;

    function admin() external view returns (address);

    event AdminChanged(address oldAdmin, address newAdmin);

    // errors define
    error PermissionDeniedErr();
}
