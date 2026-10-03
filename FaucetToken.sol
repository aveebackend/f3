// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract FaucetToken is ERC20, ERC20Permit {
    uint8 private immutable _decimals;
    uint256 public immutable MAX_MINT;
    uint256 public constant COOLDOWN = 1 days;
    address public immutable owner;
    mapping(address => uint256) public lastMint;

    error MintTooLarge();
    error MintCooldown(uint256 nextAt);

    constructor(string memory name_, string memory symbol_, uint8 decimals_, uint256 maxMint)
        ERC20(name_, symbol_)
        ERC20Permit(name_)
    {
        _decimals = decimals_;
        MAX_MINT = maxMint;
        owner = msg.sender;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount) external {
        if (amount > MAX_MINT) revert MintTooLarge();
        if (msg.sender != owner) {
            uint256 last = lastMint[msg.sender];
            if (last != 0 && block.timestamp < last + COOLDOWN) revert MintCooldown(last + COOLDOWN);
            lastMint[msg.sender] = block.timestamp;
        }
        _mint(to, amount);
    }
}
