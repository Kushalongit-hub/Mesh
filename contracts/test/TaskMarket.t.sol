// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/TaskMarket.sol";

contract TaskMarketTest is Test {
    TaskMarket public taskMarket;
    address public constant REQUESTER = address(0x1);
    address public constant AGENT_1 = address(0x2);
    address public constant AGENT_2 = address(0x3);
    address public constant STRANGER = address(0x4);

    function setUp() public {
        taskMarket = new TaskMarket();
        vm.deal(REQUESTER, 10 ether);
    }

    function test_CreateTask() public {
        uint256 budget = 0.01 ether;
        bytes32 requestHash = keccak256("test request");

        vm.startPrank(REQUESTER);
        uint256 taskId = taskMarket.createTask{value: budget}(budget, requestHash);
        assertEq(taskId, 0);
        assertEq(taskMarket.tasks(taskId).budget, budget);
        assertEq(taskMarket.tasks(taskId).requester, REQUESTER);
        assertEq(taskMarket.tasks(taskId).status, TaskMarket.TaskStatus.Created);
        vm.stopPrank();
    }

    function testRevert_CreateTaskZeroBudget() public {
        vm.startPrank(REQUESTER);
        vm.expectRevert("Budget must be greater than 0");
        taskMarket.createTask{value: 0}(0, keccak256("test"));
        vm.stopPrank();
    }

    function testRevert_CreateTaskZeroHash() public {
        vm.startPrank(REQUESTER);
        vm.expectRevert("Request hash required");
        taskMarket.createTask{value: 0.01 ether}(0.01 ether, bytes32(0));
        vm.stopPrank();
    }

    function test_AssignAgent() public {
        uint256 budget = 0.01 ether;
        bytes32 requestHash = keccak256("test request");

        vm.startPrank(REQUESTER);
        uint256 taskId = taskMarket.createTask{value: budget}(budget, requestHash);
        taskMarket.assignAgent(taskId, AGENT_1);
        assertEq(taskMarket.tasks(taskId).assignedAgents.length, 1);
        assertEq(taskMarket.tasks(taskId).status, TaskMarket.TaskStatus.Assigned);
        vm.stopPrank();
    }

    function testRevert_AssignAgentNotCreated() public {
        uint256 budget = 0.01 ether;
        bytes32 requestHash = keccak256("test request");

        vm.startPrank(REQUESTER);
        uint256 taskId = taskMarket.createTask{value: budget}(budget, requestHash);
        taskMarket.assignAgent(taskId, AGENT_1);
        taskMarket.startTask(taskId);
        vm.expectRevert("Task not in Created status");
        taskMarket.assignAgent(taskId, AGENT_2);
        vm.stopPrank();
    }

    function testRevert_AssignZeroAddress() public {
        uint256 budget = 0.01 ether;
        bytes32 requestHash = keccak256("test request");

        vm.startPrank(REQUESTER);
        uint256 taskId = taskMarket.createTask{value: budget}(budget, requestHash);
        vm.expectRevert("Invalid agent address");
        taskMarket.assignAgent(taskId, address(0));
        vm.stopPrank();
    }

    function testRevert_DuplicateAgentAssignment() public {
        uint256 budget = 0.01 ether;
        bytes32 requestHash = keccak256("test request");

        vm.startPrank(REQUESTER);
        uint256 taskId = taskMarket.createTask{value: budget}(budget, requestHash);
        taskMarket.assignAgent(taskId, AGENT_1);
        vm.expectRevert("Agent already assigned");
        taskMarket.assignAgent(taskId, AGENT_1);
        vm.stopPrank();
    }

    function test_StartTask() public {
        uint256 budget = 0.01 ether;
        bytes32 requestHash = keccak256("test request");

        vm.startPrank(REQUESTER);
        uint256 taskId = taskMarket.createTask{value: budget}(budget, requestHash);
        taskMarket.assignAgent(taskId, AGENT_1);
        taskMarket.startTask(taskId);
        assertEq(taskMarket.tasks(taskId).status, TaskMarket.TaskStatus.Running);
        vm.stopPrank();
    }

    function testRevert_StartTaskUnauthorized() public {
        uint256 budget = 0.01 ether;
        bytes32 requestHash = keccak256("test request");

        vm.startPrank(REQUESTER);
        uint256 taskId = taskMarket.createTask{value: budget}(budget, requestHash);
        taskMarket.assignAgent(taskId, AGENT_1);
        vm.stopPrank();

        vm.prank(STRANGER);
        vm.expectRevert("Only requester can start");
        taskMarket.startTask(taskId);
    }

    function test_SubmitResult() public {
        uint256 budget = 0.01 ether;
        bytes32 requestHash = keccak256("test request");
        bytes32 resultHash = keccak256("test result");

        vm.startPrank(REQUESTER);
        uint256 taskId = taskMarket.createTask{value: budget}(budget, requestHash);
        taskMarket.assignAgent(taskId, AGENT_1);
        taskMarket.startTask(taskId);
        taskMarket.submitResult(taskId, resultHash);
        assertEq(taskMarket.tasks(taskId).resultHash, resultHash);
        vm.stopPrank();
    }

    function testRevert_ResultHashCannotBeOverwritten() public {
        uint256 budget = 0.01 ether;
        bytes32 requestHash = keccak256("test request");
        bytes32 resultHash1 = keccak256("test result 1");
        bytes32 resultHash2 = keccak256("test result 2");

        vm.startPrank(REQUESTER);
        uint256 taskId = taskMarket.createTask{value: budget}(budget, requestHash);
        taskMarket.assignAgent(taskId, AGENT_1);
        taskMarket.startTask(taskId);
        taskMarket.submitResult(taskId, resultHash1);
        vm.expectRevert("Result already submitted");
        taskMarket.submitResult(taskId, resultHash2);
        vm.stopPrank();
    }

    function test_CompleteTaskAndPayAgents() public {
        uint256 budget = 0.03 ether;
        bytes32 requestHash = keccak256("test request");
        bytes32 resultHash = keccak256("test result");

        vm.startPrank(REQUESTER);
        uint256 taskId = taskMarket.createTask{value: budget}(budget, requestHash);
        taskMarket.assignAgent(taskId, AGENT_1);
        taskMarket.assignAgent(taskId, AGENT_2);
        taskMarket.startTask(taskId);
        taskMarket.submitResult(taskId, resultHash);

        uint256 agent1BalanceBefore = AGENT_1.balance;
        uint256 agent2BalanceBefore = AGENT_2.balance;

        taskMarket.completeTask(taskId);

        assertEq(AGENT_1.balance - agent1BalanceBefore, 0.015 ether);
        assertEq(AGENT_2.balance - agent2BalanceBefore, 0.015 ether);
        assertEq(taskMarket.tasks(taskId).status, TaskMarket.TaskStatus.Completed);
        vm.stopPrank();
    }

    function testRevert_CompleteTaskUnauthorized() public {
        uint256 budget = 0.01 ether;
        bytes32 requestHash = keccak256("test request");

        vm.startPrank(REQUESTER);
        uint256 taskId = taskMarket.createTask{value: budget}(budget, requestHash);
        taskMarket.assignAgent(taskId, AGENT_1);
        taskMarket.startTask(taskId);
        taskMarket.submitResult(taskId, keccak256("result"));
        vm.stopPrank();

        vm.prank(STRANGER);
        vm.expectRevert("Only requester can complete");
        taskMarket.completeTask(taskId);
    }

    function testRevert_DuplicateCompletion() public {
        uint256 budget = 0.01 ether;
        bytes32 requestHash = keccak256("test request");

        vm.startPrank(REQUESTER);
        uint256 taskId = taskMarket.createTask{value: budget}(budget, requestHash);
        taskMarket.assignAgent(taskId, AGENT_1);
        taskMarket.startTask(taskId);
        taskMarket.submitResult(taskId, keccak256("result"));
        taskMarket.completeTask(taskId);
        vm.expectRevert("Task already completed");
        taskMarket.completeTask(taskId);
        vm.stopPrank();
    }

    function test_CancelTask() public {
        uint256 budget = 0.01 ether;
        bytes32 requestHash = keccak256("test request");

        vm.startPrank(REQUESTER);
        uint256 taskId = taskMarket.createTask{value: budget}(budget, requestHash);
        uint256 requesterBalanceBefore = REQUESTER.balance;

        taskMarket.cancelTask(taskId);

        assertEq(REQUESTER.balance - requesterBalanceBefore, budget);
        assertEq(taskMarket.tasks(taskId).status, TaskMarket.TaskStatus.Cancelled);
        vm.stopPrank();
    }

    function testRevert_CancelAfterCompletion() public {
        uint256 budget = 0.01 ether;
        bytes32 requestHash = keccak256("test request");

        vm.startPrank(REQUESTER);
        uint256 taskId = taskMarket.createTask{value: budget}(budget, requestHash);
        taskMarket.assignAgent(taskId, AGENT_1);
        taskMarket.startTask(taskId);
        taskMarket.submitResult(taskId, keccak256("result"));
        taskMarket.completeTask(taskId);
        vm.expectRevert("Cannot cancel");
        taskMarket.cancelTask(taskId);
        vm.stopPrank();
    }

    function testRevert_CompleteAfterCancellation() public {
        uint256 budget = 0.01 ether;
        bytes32 requestHash = keccak256("test request");

        vm.startPrank(REQUESTER);
        uint256 taskId = taskMarket.createTask{value: budget}(budget, requestHash);
        taskMarket.cancelTask(taskId);
        vm.expectRevert("Task not running");
        taskMarket.completeTask(taskId);
        vm.stopPrank();
    }

    function test_ContractBalanceAfterCreation() public {
        uint256 budget = 0.01 ether;
        bytes32 requestHash = keccak256("test request");

        vm.startPrank(REQUESTER);
        uint256 taskId = taskMarket.createTask{value: budget}(budget, requestHash);
        vm.stopPrank();

        assertEq(address(taskMarket).balance, budget);
    }

    function test_ContractBalanceAfterCompletion() public {
        uint256 budget = 0.03 ether;
        bytes32 requestHash = keccak256("test request");

        vm.startPrank(REQUESTER);
        uint256 taskId = taskMarket.createTask{value: budget}(budget, requestHash);
        taskMarket.assignAgent(taskId, AGENT_1);
        taskMarket.assignAgent(taskId, AGENT_2);
        taskMarket.startTask(taskId);
        taskMarket.submitResult(taskId, keccak256("result"));
        taskMarket.completeTask(taskId);
        vm.stopPrank();

        assertEq(address(taskMarket).balance, 0);
    }

    function test_ContractBalanceAfterCancellation() public {
        uint256 budget = 0.01 ether;
        bytes32 requestHash = keccak256("test request");

        vm.startPrank(REQUESTER);
        uint256 taskId = taskMarket.createTask{value: budget}(budget, requestHash);
        taskMarket.cancelTask(taskId);
        vm.stopPrank();

        assertEq(address(taskMarket).balance, 0);
    }

    function test_FailedTransferRevertsSafely() public {
        uint256 budget = 0.03 ether;
        bytes32 requestHash = keccak256("test request");

        address badAgent = address(new BadAgent());

        vm.startPrank(REQUESTER);
        uint256 taskId = taskMarket.createTask{value: budget}(budget, requestHash);
        taskMarket.assignAgent(taskId, badAgent);
        taskMarket.assignAgent(taskId, AGENT_2);
        taskMarket.startTask(taskId);
        taskMarket.submitResult(taskId, keccak256("result"));

        vm.expectRevert("MON transfer failed");
        taskMarket.completeTask(taskId);

        assertEq(taskMarket.tasks(taskId).status, TaskMarket.TaskStatus.Running);
        vm.stopPrank();
    }
}

contract BadAgent {
    receive() external payable {
        revert("bad");
    }
}
