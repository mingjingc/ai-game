// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {BaseToken} from "./BaseToken.sol";

contract Aimo is BaseToken {
   constructor(address owner_) BaseToken("Aimo", "Aimo", owner_) {}
}
