// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {BaseToken} from "./BaseToken.sol";

// just for testing
contract USDT is ERC20 {
  constructor() ERC20("USDT", "USDT") {}
  
  function mint(address to, uint256 amount) external {
      _mint(to, amount);
  }
  function burn(address from, uint256 amount) external {
      _burn(from, amount);
  }
}
