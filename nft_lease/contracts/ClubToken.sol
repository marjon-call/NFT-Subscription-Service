pragma solidity ^0.8.0;


// Basic ERC20 implementation
// Used as a reward for users who have subscribed w ith nft

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ClubToken is ERC20 {

    address owner;

    event OwnerTransfer(address from, address to);
    event RewardDistribution(uint256 amount, address user);

    constructor() ERC20("Club Token", "CLUB") {
        owner = msg.sender;
    }

    function transferOwnership(address _newOwner) external {
        require(msg.sender == owner, "ClubToken: user is not owner");
        owner = _newOwner;
        emit OwnerTransfer(msg.sender, _newOwner);
    }

    function mint(address _to, uint256 _amount) external {
        require(msg.sender == owner, "ClubToken: user is not owner");
        _mint(_to, _amount);
        emit RewardDistribution(_amount, _to);
    }


}