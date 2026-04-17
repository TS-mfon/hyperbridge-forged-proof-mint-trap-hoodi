// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MockToken {
    string public name = "Operation Flytrap Mock Token";
    string public symbol = "FLY";
    uint8 public decimals = 18;
    mapping(address => uint256) public balanceOf;
    uint256 public totalSupply;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "INSUFFICIENT_BALANCE");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}
