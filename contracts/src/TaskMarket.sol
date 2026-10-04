// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract TaskMarket is Ownable, ReentrancyGuard {
    enum TaskStatus { Created, Assigned, Running, Completed, Disputed, Cancelled }

    struct Task {
        uint256 id;
        address requester;
        uint256 budget;
        bytes32 requestHash;
        bytes32 resultHash;
        TaskStatus status;
        uint256 createdAt;
        uint256[] assignedAgents;
    }

    uint256 private _nextTaskId;
    mapping(uint256 => Task) public tasks;
    mapping(uint256 => mapping(address => bool)) public agentAssigned;
    mapping(uint256 => bool) public taskCompleted;

    event TaskCreated(uint256 indexed taskId, address indexed requester, uint256 budget, bytes32 requestHash);
    event AgentAssigned(uint256 indexed taskId, address indexed agent);
    event TaskStarted(uint256 indexed taskId);
    event ResultSubmitted(uint256 indexed taskId, bytes32 resultHash);
    event TaskCompleted(uint256 indexed taskId, bytes32 resultHash);
    event TaskCancelled(uint256 indexed taskId);

    constructor() Ownable(msg.sender) {}

    function createTask(uint256 budget, bytes32 requestHash) external payable returns (uint256) {
        require(budget > 0, "Budget must be greater than 0");
        require(requestHash != bytes32(0), "Request hash required");
        require(msg.value == budget, "MON amount must equal budget");

        uint256 taskId = _nextTaskId++;
        tasks[taskId] = Task({
            id: taskId,
            requester: msg.sender,
            budget: budget,
            requestHash: requestHash,
            resultHash: bytes32(0),
            status: TaskStatus.Created,
            createdAt: block.timestamp,
            assignedAgents: new uint256[](0)
        });

        emit TaskCreated(taskId, msg.sender, budget, requestHash);
        return taskId;
    }

    function assignAgent(uint256 taskId, address agent) external {
        Task storage task = tasks[taskId];
        require(task.status == TaskStatus.Created, "Task not in Created status");
        require(agent != address(0), "Invalid agent address");
        require(!agentAssigned[taskId][agent], "Agent already assigned");
        require(msg.sender == task.requester, "Only requester can assign");

        task.assignedAgents.push(uint256(uint160(agent)));
        agentAssigned[taskId][agent] = true;
        task.status = TaskStatus.Assigned;

        emit AgentAssigned(taskId, agent);
    }

    function startTask(uint256 taskId) external {
        Task storage task = tasks[taskId];
        require(task.status == TaskStatus.Assigned, "Task not ready to start");
        require(msg.sender == task.requester, "Only requester can start");

        task.status = TaskStatus.Running;
        emit TaskStarted(taskId);
    }

    function submitResult(uint256 taskId, bytes32 resultHash) external {
        Task storage task = tasks[taskId];
        require(task.status == TaskStatus.Running, "Task not running");
        require(resultHash != bytes32(0), "Result hash required");
        require(task.resultHash == bytes32(0), "Result already submitted");
        require(msg.sender == task.requester, "Only requester can submit");

        task.resultHash = resultHash;
        emit ResultSubmitted(taskId, resultHash);
    }

    function completeTask(uint256 taskId) external nonReentrant {
        Task storage task = tasks[taskId];
        require(task.status == TaskStatus.Running, "Task not running");
        require(task.resultHash != bytes32(0), "Result not submitted");
        require(!taskCompleted[taskId], "Task already completed");
        require(msg.sender == task.requester, "Only requester can complete");

        task.status = TaskStatus.Completed;
        taskCompleted[taskId] = true;

        uint256 agentCount = task.assignedAgents.length;
        if (agentCount > 0) {
            uint256 perAgent = task.budget / agentCount;
            for (uint256 i = 0; i < agentCount; i++) {
                address agent = address(task.assignedAgents[i]);
                (bool sent, ) = agent.call{value: perAgent}("");
                require(sent, "MON transfer failed");
            }
        }

        emit TaskCompleted(taskId, task.resultHash);
    }

    function cancelTask(uint256 taskId) external nonReentrant {
        Task storage task = tasks[taskId];
        require(task.status == TaskStatus.Created || task.status == TaskStatus.Assigned, "Cannot cancel");
        require(msg.sender == task.requester, "Only requester can cancel");

        task.status = TaskStatus.Cancelled;
        (bool sent, ) = task.requester.call{value: task.budget}("");
        require(sent, "MON refund failed");

        emit TaskCancelled(taskId);
    }

    function getTask(uint256 taskId) external view returns (Task memory) {
        return tasks[taskId];
    }
}
