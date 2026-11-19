// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Minimal ERC-721 interface — only what AgentWall needs to check
///         whether an address holds a SPACE ID Agent ID.
/// @dev    The real Agent ID contract on BNB Chain mainnet is
///         0x60b9262456de011f7d15a54cdd8c48baaa8b022f
///         (SPACE ID Agent ID, symbol "AI", ERC-721, non-transferable).
interface IAgentId {
    function balanceOf(address owner) external view returns (uint256);
}

/// @title  AgentWall
/// @notice A public on-chain message wall that only Agent ID holders can
///         write to. Agent ID is used purely as an identity / access gate:
///         reading is open to everyone, writing requires balanceOf > 0 on
///         the Agent ID contract.
/// @dev    Deliberately minimal by design:
///         - no owner, no admin functions, nothing can be changed after deploy
///         - no payable functions, no token handling, no asset movement
///         - posts are permanent and public, exactly like a wall should be
contract AgentWall {
    /// @notice Maximum message length, measured in bytes (not characters),
    ///         so multi-byte UTF-8 text counts its raw byte size.
    uint256 public constant MAX_TEXT_BYTES = 280;

    /// @notice The Agent ID (ERC-721) contract used for the holder check.
    IAgentId public immutable agentId;

    struct Post {
        address author;
        string text;
        uint256 timestamp;
    }

    Post[] private _posts;

    event MessagePosted(address indexed author, uint256 indexed index, string text, uint256 timestamp);

    error NotAgentIdHolder(address sender);
    error EmptyText();
    error TextTooLong(uint256 length);

    /// @param agentIdAddress Address of the Agent ID ERC-721 contract.
    constructor(address agentIdAddress) {
        require(agentIdAddress != address(0), "AgentWall: zero address");
        agentId = IAgentId(agentIdAddress);
    }

    /// @notice Post a message to the wall. Caller must hold an Agent ID.
    /// @param text Message text, 1..280 bytes.
    function postMessage(string calldata text) external {
        if (agentId.balanceOf(msg.sender) == 0) {
            revert NotAgentIdHolder(msg.sender);
        }
        uint256 len = bytes(text).length;
        if (len == 0) revert EmptyText();
        if (len > MAX_TEXT_BYTES) revert TextTooLong(len);

        uint256 index = _posts.length;
        _posts.push(Post({author: msg.sender, text: text, timestamp: block.timestamp}));
        emit MessagePosted(msg.sender, index, text, block.timestamp);
    }

    /// @notice Total number of posts on the wall.
    function postCount() external view returns (uint256) {
        return _posts.length;
    }

    /// @notice Read a single post by index.
    function getPost(uint256 index) external view returns (Post memory) {
        return _posts[index];
    }

    /// @notice Read a page of posts.
    /// @param offset Index of the first post to return.
    /// @param limit  Maximum number of posts to return (clamped to what exists).
    /// @return page The requested slice of posts (empty if offset is past the end).
    function getPosts(uint256 offset, uint256 limit) external view returns (Post[] memory page) {
        uint256 total = _posts.length;
        if (offset >= total || limit == 0) {
            return new Post[](0);
        }
        uint256 end = offset + limit;
        if (end > total) end = total;
        page = new Post[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            page[i - offset] = _posts[i];
        }
    }

    /// @notice Convenience view: does this address hold an Agent ID?
    function isHolder(address account) external view returns (bool) {
        return agentId.balanceOf(account) > 0;
    }
}
