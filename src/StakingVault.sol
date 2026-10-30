// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract StakingVault {
    mapping(address => uint256) public stakeOf;
    mapping(address => uint256) public stakedAt;
    uint256 public totalStaked;
    uint256 public lockPeriod;
    uint256 public constant VERSION = 2;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);

    constructor() payable {
        stakeOf[msg.sender] = msg.value;
        stakedAt[msg.sender] = block.timestamp;
        totalStaked = msg.value;
        lockPeriod = 0;
    }

    function stake() external payable {
        require(msg.value > 0, "amount is zero");
        stakeOf[msg.sender] += msg.value;
        stakedAt[msg.sender] = block.timestamp;
        totalStaked += msg.value;
        emit Staked(msg.sender, msg.value);
    }

    function unstake() external {
        uint256 amount = stakeOf[msg.sender];
        require(amount > 0, "no position");
        require(block.timestamp >= stakedAt[msg.sender] + lockPeriod, "still locked");
        totalStaked -= amount;
        stakeOf[msg.sender] = 0;
        stakedAt[msg.sender] = 0;
        (bool ok, ) = msg.sender.call{value: amount}("");
        require(ok, "eth transfer failed");
        emit Unstaked(msg.sender, amount);
    }

    function coverageRatio() external view returns (uint256) {
        if (totalStaked == 0) {
            return 0;
        }
        return (address(this).balance * 1e18) / totalStaked;
    }

    function positionOf(address user) external view returns (uint256 amount, uint256 since) {
        return (stakeOf[user], stakedAt[user]);
    }
}
