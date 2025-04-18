// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IBaseToken} from "../interfaces/IBaseToken.sol";

abstract contract BaseToken is ERC20, Ownable, IBaseToken {
    address public admin;

    constructor(string memory name, string memory symbol, address owner_) ERC20(name, symbol) Ownable(owner_) {}

    modifier onlyAdmin() {
        if (msg.sender != admin) {
            revert PermissionDeniedErr();
        }
        _;
    }

    function mint(address to, uint256 amount) external onlyAdmin {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyAdmin {
        _burn(from, amount);
    }

    function changeAdmin(address newAdmin) external onlyOwner {
        admin = newAdmin;
        emit AdminChanged(admin, newAdmin);
    }
}
