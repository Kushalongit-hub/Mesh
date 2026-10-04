// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AgentRegistry is ERC721URIStorage, ERC721Enumerable, Ownable {
    struct Agent {
        address owner;
        uint256 reputation;
        uint256 completedTasks;
        uint256 totalEarned;
        bool active;
    }

    uint256 private _nextAgentId;
    mapping(uint256 => Agent) public agents;

    event AgentRegistered(uint256 indexed agentId, address indexed owner, string metadataURI);
    event AgentUpdated(uint256 indexed agentId, string newMetadataURI);
    event AgentStatusChanged(uint256 indexed agentId, bool active);

    constructor() ERC721("Mesh Agent", "MESH") Ownable(msg.sender) {}

    function registerAgent(string calldata metadataURI) external returns (uint256) {
        uint256 agentId = _nextAgentId++;
        _safeMint(msg.sender, agentId);
        _setAgentURI(agentId, metadataURI);
        agents[agentId] = Agent({
            owner: msg.sender,
            reputation: 0,
            completedTasks: 0,
            totalEarned: 0,
            active: true
        });
        emit AgentRegistered(agentId, msg.sender, metadataURI);
        return agentId;
    }

    function updateAgentMetadata(uint256 agentId, string calldata metadataURI) external {
        require(_ownerOf(agentId) == msg.sender, "Not agent owner");
        _setAgentURI(agentId, metadataURI);
        emit AgentUpdated(agentId, metadataURI);
    }

    function getAgent(uint256 agentId) external view returns (Agent memory) {
        require(_ownerOf(agentId) != address(0), "Agent does not exist");
        return agents[agentId];
    }

    function setAgentActive(uint256 agentId, bool active) external {
        require(_ownerOf(agentId) == msg.sender, "Not agent owner");
        agents[agentId].active = active;
        emit AgentStatusChanged(agentId, active);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function _update(address to, uint256 tokenId, address auth) internal override(ERC721, ERC721Enumerable) returns (address) {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value) internal override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, value);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
