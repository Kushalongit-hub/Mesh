// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/AgentRegistry.sol";

contract AgentRegistryTest is Test {
    AgentRegistry public agentRegistry;
    address public constant OWNER = address(0x1);
    address public constant USER = address(0x2);

    function setUp() public {
        vm.startPrank(OWNER);
        agentRegistry = new AgentRegistry();
        vm.stopPrank();
    }

    function test_RegisterAgent() public {
        vm.prank(USER);
        uint256 agentId = agentRegistry.registerAgent("ipfs://QmTest");
        assertEq(agentId, 0);
        assertEq(agentRegistry.ownerOf(agentId), USER);
    }

    function test_RegisterMultipleAgents() public {
        vm.prank(USER);
        uint256 agentId1 = agentRegistry.registerAgent("ipfs://QmTest1");
        vm.prank(address(0x3));
        uint256 agentId2 = agentRegistry.registerAgent("ipfs://QmTest2");
        assertEq(agentId1, 0);
        assertEq(agentId2, 1);
    }

    function test_GetAgent() public {
        vm.prank(USER);
        uint256 agentId = agentRegistry.registerAgent("ipfs://QmTest");
        AgentRegistry.Agent memory agent = agentRegistry.getAgent(agentId);
        assertEq(agent.reputation, 0);
        assertEq(agent.completedTasks, 0);
        assertEq(agent.totalEarned, 0);
        assertTrue(agent.active);
        assertEq(agent.owner, USER);
    }

    function test_UpdateAgentMetadata() public {
        vm.prank(USER);
        uint256 agentId = agentRegistry.registerAgent("ipfs://QmTest");
        vm.prank(USER);
        agentRegistry.updateAgentMetadata(agentId, "ipfs://QmUpdated");
        assertEq(agentRegistry.tokenURI(agentId), "ipfs://QmUpdated");
    }

    function testRevert_UpdateMetadataNotOwner() public {
        vm.prank(USER);
        uint256 agentId = agentRegistry.registerAgent("ipfs://QmTest");
        vm.prank(address(0x3));
        vm.expectRevert("Not agent owner");
        agentRegistry.updateAgentMetadata(agentId, "ipfs://QmHacked");
    }

    function test_SetAgentActive() public {
        vm.prank(USER);
        uint256 agentId = agentRegistry.registerAgent("ipfs://QmTest");
        vm.prank(USER);
        agentRegistry.setAgentActive(agentId, false);
        AgentRegistry.Agent memory agent = agentRegistry.getAgent(agentId);
        assertFalse(agent.active);
    }

    function testRevert_SetActiveNotOwner() public {
        vm.prank(USER);
        uint256 agentId = agentRegistry.registerAgent("ipfs://QmTest");
        vm.prank(address(0x3));
        vm.expectRevert("Not agent owner");
        agentRegistry.setAgentActive(agentId, false);
    }

    function test_GetNonExistentAgent() public {
        vm.expectRevert("Agent does not exist");
        agentRegistry.getAgent(999);
    }
}
