// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/ReputationManager.sol";

contract ReputationManagerTest is Test {
    ReputationManager public reputationManager;
    address public constant TASK_MARKET = address(0x0000000000000000000000000000000000000002);

    function setUp() public {
        reputationManager = new ReputationManager(TASK_MARKET);
    }

    function test_IncreaseReputation() public {
        address agent = address(0x1234);
        vm.prank(TASK_MARKET);
        reputationManager.increaseReputation(agent, 5);
        assertEq(reputationManager.getReputation(agent), 5);
    }

    function test_DecreaseReputation() public {
        address agent = address(0x1234);
        vm.prank(TASK_MARKET);
        reputationManager.increaseReputation(agent, 10);
        reputationManager.decreaseReputation(agent, 3);
        assertEq(reputationManager.getReputation(agent), 7);
    }

    function testRevert_UnauthorizedReputation() public {
        address agent = address(0x1234);
        vm.prank(address(0x9999));
        vm.expectRevert("Only TaskMarket can call");
        reputationManager.increaseReputation(agent, 5);
    }

    function testRevert_DecreaseBelowZero() public {
        address agent = address(0x1234);
        vm.prank(TASK_MARKET);
        vm.expectRevert("Reputation too low");
        reputationManager.decreaseReputation(agent, 1);
    }

    function testRevert_InvalidAgentAddress() public {
        vm.prank(TASK_MARKET);
        vm.expectRevert("Invalid agent address");
        reputationManager.increaseReputation(address(0), 5);
    }
}
