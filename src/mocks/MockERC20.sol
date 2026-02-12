// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title MockERC20
/// @notice Mock ERC20 token for testing purposes
/// @dev Minters can mint tokens - for testnet/hackathon use
contract MockERC20 is ERC20, Ownable {
    uint8 private _decimals;

    /// @notice Addresses allowed to mint
    mapping(address => bool) public isMinter;

    event MinterAdded(address indexed minter);
    event MinterRemoved(address indexed minter);

    modifier onlyMinter() {
        require(isMinter[msg.sender] || msg.sender == owner(), "MockERC20: not minter");
        _;
    }

    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals_
    ) ERC20(name, symbol) Ownable(msg.sender) {
        _decimals = decimals_;
        isMinter[msg.sender] = true;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    /// @notice Add a minter (e.g., Faucet contract)
    /// @param minter Address to add as minter
    function addMinter(address minter) external onlyOwner {
        isMinter[minter] = true;
        emit MinterAdded(minter);
    }

    /// @notice Remove a minter
    /// @param minter Address to remove
    function removeMinter(address minter) external onlyOwner {
        isMinter[minter] = false;
        emit MinterRemoved(minter);
    }

    /// @notice Mint tokens to any address
    /// @param to Address to mint to
    /// @param amount Amount to mint
    function mint(address to, uint256 amount) external onlyMinter {
        _mint(to, amount);
    }

    /// @notice Mint tokens to caller (for easy testing)
    /// @param amount Amount to mint
    function faucet(uint256 amount) external onlyMinter {
        _mint(msg.sender, amount);
    }
}
