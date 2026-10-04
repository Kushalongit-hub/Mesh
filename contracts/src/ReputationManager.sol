// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";

contract ReputationManager is Ownable {
    mapping(address => uint256) public reputation;

    address public immutable taskMarket;

    event ReputationIncreased(address indexed agent, uint256 newReputation);
    event ReputationDecreased(address indexed agent, uint256 newReputation);

    constructor(address _taskMarket) Ownable(msg.sender) {
        taskMarket = _taskMarket;
    }

    function increaseReputation(address agent, uint256 delta) external {
        require(msg.sender == taskMarket, "Only TaskMarket can call");
        require(agent != address(0), "Invalid agent address");
        reputation[agent] += delta;
        emit ReputationIncreased(agent, reputation[agent]);
    }

    function decreaseReputation(address agent, uint256 delta) external {
        require(msg.sender == taskMarket, "Only TaskMarket can call");
        require(agent != address(0), "Invalid agent address");
        require(reputation[agent] >= delta, "Reputation too low");
        reputation[agent] -= delta;
        emit ReputationDecreased(agent, reputation[agent]);
    }

    function getReputation(address agent) external view returns (uint256) {
        return reputation[agent];
    }
}
