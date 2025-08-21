// SPDX-License-Identifier: SEE LICENSE IN LICENSE
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
pragma solidity ^0.8.0;
contract StableCoin is ERC20, ERC20Burnable {
constructor() ERC20("StableCoin", "STC") {

}
function mint(address to, uint256 amount) external {
    require(to != address(0), "Cannot mint to the zero address");
    require(amount > 0, "Amount must be greater than zero");
    _mint(to,amount);
}
function burn(uint256 amount) public override {
    require(amount > 0, "Amount must be greater than zero");
    require(balanceOf(msg.sender) >= amount, "Insufficient balance to burn");
    super.burn(amount);
}

}