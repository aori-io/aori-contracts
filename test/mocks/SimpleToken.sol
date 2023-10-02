
// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract SimpleToken is ERC20 {
    constructor() ERC20("Mock", "MOCK") {}

    function mint(uint256 amount) public {
        _mint(msg.sender, amount);
    }
}