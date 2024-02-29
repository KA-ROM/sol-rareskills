// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Task:
// Token sale and buyback with bonding curve. 
// The more tokens a user buys, the more expensive the token becomes. 
// To keep things simple, use a linear bonding curve.
// Consider the case someone might [sandwhich attack](https://medium.com/coinmonks/defi-sandwich-attack-explain-776f6f43b2fd) 
// a bonding curve. What can you do about it?
// TO DO still:
// - try to use Checks-Effects-Interactions pattern to minimizing reentrancy risks

/// @title A contract for a token sale and buyback with a linear bonding curve
/// @notice This contract allows users to buy tokens at an increasing price and sell them back to the contract.
/// @dev Considerations for sandwich attacks and reentrancy have been addressed in the design.

contract weekOneItemThree {
    using SafeERC20 for IERC20;

    string public name;
    string public symbol;
    uint256 public totalSupply;
    uint8 public decimals;

    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowance;
    address public admin;
    address public treasury;

    uint256 public incrementPriceBy;
    uint256 public currentPrice;

    /// @dev Tracks per-block transaction limitations to prevent sandwich attacks
    mapping(bytes32 => bool) private perBlock;
    /// @notice List of addresses exempt from per-block transaction limitations
    mapping(address => bool) private exceptions;

    event TokensPurchased(address indexed buyer, uint256 amount, uint256 totalCost);
    event TokensBuyback(address indexed buyer, uint256 amount);
    event TokensMinted(uint256 amount);
    event AllowanceApproved(address spender, uint256 amount);
    event TokensTransferred(address from, address to, uint256 amount);

    constructor() {
        name = "weekOne";
        symbol = "WEO";
        decimals = 18;
        incrementPriceBy = 7_000_000_000_000; // ~0.02 USD (Feb 20 2023)
        currentPrice = 300_000_000_000_000; // ~1.00 USD (Feb 20 2023)
        admin = msg.sender;
    }

    receive() external payable {}
    fallback() external payable {}

    /// @notice Buys tokens according to the current price and bonding curve
    /// @param amount The amount of tokens to buy
    /// @dev Refunds excess ETH sent for the token purchase
    function buyTokens(uint256 amount) public payable rateLimit(msg.sender) {
        uint256 totalCost = getBuyPriceOfManyTokens(amount);
        require(msg.value >= totalCost, "Not enough ETH sent for purchase");

        balances[msg.sender] += amount;
        currentPrice += incrementPriceBy * amount;
        totalSupply += amount;

        emit TokensPurchased(msg.sender, amount, totalCost);

        if (msg.value > totalCost) {
            payable(msg.sender).transfer(msg.value - totalCost);
        }
    }

    /// @notice Allows users to sell tokens back to the contract at the current price
    /// @param amount The amount of tokens to sell back
    /// @dev The contract must have enough ETH to buy back the tokens
    function buyback(uint256 amount) public rateLimit(msg.sender) {
        require(balances[msg.sender] >= amount, "Caller doesn't hold enough tokens");
        require(address(this).balance >= amount * currentPrice, "Contract lacks funds for buyback");

        balances[msg.sender] -= amount;
        balances[treasury] += amount;

        emit TokensBuyback(msg.sender, amount);

        payable(msg.sender).transfer(amount * currentPrice);
    }

    /// @notice Transfers tokens from the caller to another address
    /// @param to The recipient address
    /// @param amount The amount of tokens to transfer
    /// @return bool Returns true on successful transfer
    function transfer(address to, uint256 amount) public rateLimit(msg.sender) returns (bool) {
        return helperTransfer(msg.sender, to, amount);
    }

    /// @notice Allows a spender to transfer tokens from one address to another
    /// @param from The address from which tokens are transferred
    /// @param to The recipient address
    /// @param amount The amount of tokens to transfer
    /// @return bool Returns true on successful transfer
    function transferFrom(address from, address to, uint256 amount) public rateLimit(msg.sender) returns (bool) {
        if (msg.sender != from) {
            require(allowance[from][msg.sender] >= amount, "Not enough allowance");

            allowance[from][msg.sender] -= amount;
        }

        return helperTransfer(from, to, amount);
    }

    /// @notice Approves a spender to transfer up to a certain amount of tokens
    /// @param spender The address authorized to spend
    /// @param amount The maximum amount they can spend
    /// @return bool Returns true on successful approval
    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        
        emit AllowanceApproved(spender, amount);

        return true;
    }

    /// @notice Returns the token balance of a specific address
    /// @param addr The address to query the balance of
    /// @return uint256 Returns the amount of tokens held
    function balanceOf(address addr) public view returns (uint256){
        return balances[addr];
    }

    /// @notice Calculates the total cost to buy a specific amount of tokens
    /// @param buyAmount The amount of tokens to buy
    /// @return uint256 Returns the total cost to buy the tokens
    function getBuyPriceOfManyTokens(uint256 buyAmount) public view returns (uint256)  {
        return (buyAmount * currentPrice) + (buyAmount * (buyAmount - 1) * incrementPriceBy / 2);
    }

    /// @dev Internal helper function to transfer tokens
    /// @param from The address from which tokens are transferred
    /// @param to The recipient address
    /// @param amount The amount of tokens to transfer
    /// @return bool Returns true on successful transfer
    function helperTransfer(address from, address to, uint256 amount) internal returns (bool) {
        require(balances[from] >= amount, "Not enough tokens");
        require(to != address(0), "Cannot send to the zero address");

        balances[from] -= amount;
        balances[to] += amount;

        emit TokensTransferred(from, to, amount);

        return true;
    }

    /// @notice Limits token transfer operations to one per block per address to mitigate sandwich attacks
    /// @param from The address attempting to make a transfer
    modifier rateLimit(address from) {
        if (!exceptions[from]) {
            bytes32 key = keccak256(abi.encodePacked(block.number, from));
            require(!perBlock[key], "ERC20: Only one transfer per block per address");
            perBlock[key] = true;
        }

        _;
    }
}
