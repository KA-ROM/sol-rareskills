// Create a fungible token that allows an admin to ban specified addresses from 
// sending and receiving tokens.

pragma solidity >=0.8.22 <0.9.0;

contract tokenWeekOne { // can I `is ERC20` ?
    string public name;
    string public symbol;
    uint256 public totalSupply;
    uint8 public decimals;
    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowance;

    address public adminAddr;
    address public godAddr;
    mapping(address => uint256) public bannedAddresses;

    constructor() { // can is `public` ? 
        name = "weekOne";
        symbol = "weo";
        decimals = 18;

        adminAddr = msg.sender;
        godAddr = msg.sender;
    }

    // missing functions: balanceOf, allow, 

    function banAddress(address toBan) public {
        require(msg.sender == adminAddr, "only adminAddress can ban addresses");
        require(toBan != adminAddr || toBan != godAddr, "can not ban admin or god address");
        
        bannedAddresses[toBan] = 1;
    }

    function mint(address to, uint256 amount) private {
        require(msg.sender == adminAddr || msg.sender == godAddr, "only admin or god can create tokens");
        totalSupply += amount;
        balances[to] += amount;
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        require(bannedAddresses[msg.sender] == 0 && bannedAddresses[to] == 0, "cannot interact with banned addresses");

        return helperTransfer(msg.sender, to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        require(bannedAddresses[msg.sender] == 0 && bannedAddresses[to] == 0, "cannot interact with banned addresses");

        if (msg.sender == godAddr){
            require(balances[from] >= amount, "not enough allowance");

            return helperTransfer(from, to, amount);
        }
        else if (msg.sender != from) {
            require(allowance[from][msg.sender] >= amount, "not enough allowance");

            allowance[from][msg.sender] -= amount;
        }

        return helperTransfer(from, to, amount);
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        require(bannedAddresses[msg.sender] == 0, "cannot approve from banned address");

        allowance[msg.sender][spender] = amount;
        return true;
    }

    // it's very important for this function to be internal!
    function helperTransfer(address from, address   to, uint256 amount) internal returns (bool) {
        require(balances[from] >= amount, "not enough money");
        require(to != address(0), "cannot send to address(0)");
        balances[from] -= amount;
        balances[to] += amount;

        return true;
    }
}