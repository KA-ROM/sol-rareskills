// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

using SafeERC20 for IERC20;

// Task:
// Solidity contract 4: (hard) Untrusted escrow. 
// Create a contract where a buyer can put an arbitrary ERC20 token into a contract 
// and a seller can withdraw it 3 days later. Based on your readings above, what issues 
// do you need to defend against? Create the safest version of this that you can while 
// guarding against issues that you cannot control. Does your contract handle fee-on 
// transfer tokens or non-standard ERC20 tokens.

/// @title An untrusted escrow contract for ERC20 tokens
/// @dev This contract allows a buyer to deposit arbitrary ERC20 tokens, which a seller can withdraw 3 days later.
/// It is designed to handle fee-on-transfer tokens and non-standard ERC20 tokens.
contract escrow {
    string public name;
    address public admin;

    /// @notice Tracks token holdings for each user by token address
    mapping(address => mapping(address => uint256)) public tokenHoldings;

    /// @notice Tracks withdrawal allowances for tokens
    mapping(address => mapping(address => mapping(address => WithdrawalAllowance))) public WithdrawalAllowances;

    struct WithdrawalAllowance {
        uint256 Amount;
        uint256 Timestamp;
    }

    event Deposit(address indexed depositor, address indexed token, uint256 amount);
    event Withdrawal(address indexed recipient, address indexed token, uint256 amount);
    event AllowanceSet(address indexed owner, address indexed token, address indexed recipient, uint256 amount, uint256 timestamp);

    constructor() {
        name = "weekOneEscrow";
        admin = msg.sender;
    }

    receive() external payable {} // Allows contract to accept donations

    fallback() external payable {} // Fallback to accept ether

    /// @notice Deposits tokens into the escrow contract
    /// @dev Emits a Deposit event upon successful deposit
    /// @param token The address of the token to deposit
    /// @param amount The amount of tokens to deposit
    function depositTokens(address token, uint256 amount) public {
        require(amount > 0, "Deposit amount must be greater than 0");
        require(token != address(0), "Token address cannot be the zero address");

        uint256 beforeBalance = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        uint256 afterBalance = IERC20(token).balanceOf(address(this));
        uint256 actualReceived = afterBalance - beforeBalance;

        tokenHoldings[msg.sender][token] += actualReceived;

        emit Deposit(msg.sender, token, actualReceived);
    }

    /// @notice Sets withdrawal allowance for a recipient
    /// @dev Emits an AllowanceSet event upon setting the allowance
    /// @param token The token address for which to set the allowance
    /// @param recipient The address of the recipient who is allowed to withdraw
    /// @param amount The amount of tokens the recipient is allowed to withdraw
    function setWithdrawalAllowance(address token, address recipient, uint256 amount) public {
        require(token != address(0), "Token address cannot be the zero address");

        WithdrawalAllowances[msg.sender][token][recipient] = WithdrawalAllowance({
            Amount: amount,
            Timestamp: block.timestamp
        });

        emit AllowanceSet(msg.sender, token, recipient, amount, block.timestamp);
    }

    /// @notice Allows a recipient to withdraw tokens after a 3-day waiting period
    /// @dev Ensures the recipient has enough allowance and that 3 days have passed since the allowance was set
    /// @param originalOwner The address of the original owner who set the withdrawal allowance
    /// @param tokenContract The token address to be withdrawn
    /// @param sendTo The address to receive the tokens
    /// @param amount The amount of tokens to withdraw
    function withdrawTokens(address originalOwner, address tokenContract, address sendTo, uint256 amount) public {
        require(tokenContract != address(0), "Token address cannot be the zero address");
        require(WithdrawalAllowances[originalOwner][tokenContract][msg.sender].Amount >= amount, "Not enough allowance");
        require(tokenHoldings[originalOwner][tokenContract] >= amount, "Holder doesn't have enough tokens");
        require(block.timestamp >= WithdrawalAllowances[originalOwner][tokenContract][msg.sender].Timestamp + 3 days, "Withdrawal time is not yet unlocked");

        WithdrawalAllowances[originalOwner][tokenContract][msg.sender].Amount -= amount;
        tokenHoldings[originalOwner][tokenContract] -= amount;
        IERC20(tokenContract).safeTransfer(sendTo, amount);
    }
}
