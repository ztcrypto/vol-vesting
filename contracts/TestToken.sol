// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20, Ownable {
    constructor() ERC20("Test Token", "TEST") {
        _mint(owner(), 1000000 * (10 ** decimals()));
    }
}
