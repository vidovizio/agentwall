// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {AgentWall} from "../contracts/AgentWall.sol";

/// @notice Minimal mock of the Agent ID ERC-721: only mint + balanceOf,
///         which is all AgentWall's holder check depends on.
contract MockAgentId {
    mapping(address => uint256) private _balances;

    function mint(address to) external {
        _balances[to] += 1;
    }

    function balanceOf(address owner) external view returns (uint256) {
        return _balances[owner];
    }
}

contract AgentWallTest is Test {
    // Redeclared here so expectEmit can reference it (events cannot be
    // emitted through another contract's type in Solidity).
    event MessagePosted(address indexed author, uint256 indexed index, string text, uint256 timestamp);

    MockAgentId internal agentId;
    AgentWall internal wall;

    address internal holder = address(0xA11CE);
    address internal stranger = address(0xB0B);

    function setUp() public {
        agentId = new MockAgentId();
        wall = new AgentWall(address(agentId));
        agentId.mint(holder); // holder owns 1 Agent ID, stranger owns none
    }

    // --- writing -----------------------------------------------------------

    function test_HolderCanPost() public {
        vm.prank(holder);
        wall.postMessage("Halo dari pemegang Agent ID!");

        assertEq(wall.postCount(), 1);
        AgentWall.Post memory p = wall.getPost(0);
        assertEq(p.author, holder);
        assertEq(p.text, "Halo dari pemegang Agent ID!");
        assertEq(p.timestamp, block.timestamp);
    }

    function test_PostEmitsEvent() public {
        vm.expectEmit(true, true, false, true);
        emit MessagePosted(holder, 0, "gm", block.timestamp);
        vm.prank(holder);
        wall.postMessage("gm");
    }

    function test_NonHolderReverts() public {
        vm.expectRevert(abi.encodeWithSelector(AgentWall.NotAgentIdHolder.selector, stranger));
        vm.prank(stranger);
        wall.postMessage("saya tidak punya Agent ID");
    }

    function test_EmptyTextReverts() public {
        vm.expectRevert(AgentWall.EmptyText.selector);
        vm.prank(holder);
        wall.postMessage("");
    }

    function test_TooLongTextReverts() public {
        string memory longText = _repeat("a", 281);
        vm.expectRevert(abi.encodeWithSelector(AgentWall.TextTooLong.selector, 281));
        vm.prank(holder);
        wall.postMessage(longText);
    }

    function test_MaxLengthTextOk() public {
        string memory maxText = _repeat("a", 280);
        vm.prank(holder);
        wall.postMessage(maxText);
        assertEq(wall.postCount(), 1);
    }

    // --- reading / pagination ----------------------------------------------

    function test_Pagination() public {
        // Write 5 posts as the holder.
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(holder);
            wall.postMessage(_label(i));
        }
        assertEq(wall.postCount(), 5);

        // First page: 3 items.
        AgentWall.Post[] memory page1 = wall.getPosts(0, 3);
        assertEq(page1.length, 3);
        assertEq(page1[0].text, "pesan 0");
        assertEq(page1[2].text, "pesan 2");

        // Second page: remaining 2 items (limit is clamped).
        AgentWall.Post[] memory page2 = wall.getPosts(3, 10);
        assertEq(page2.length, 2);
        assertEq(page2[0].text, "pesan 3");
        assertEq(page2[1].text, "pesan 4");

        // Offset past the end: empty page, no revert.
        AgentWall.Post[] memory page3 = wall.getPosts(5, 10);
        assertEq(page3.length, 0);
    }

    function test_IsHolder() public view {
        assertTrue(wall.isHolder(holder));
        assertFalse(wall.isHolder(stranger));
    }

    // --- helpers -------------------------------------------------------------

    function _repeat(string memory s, uint256 n) internal pure returns (string memory) {
        bytes memory out;
        for (uint256 i = 0; i < n; i++) {
            out = bytes.concat(out, bytes(s));
        }
        return string(out);
    }

    function _label(uint256 i) internal pure returns (string memory) {
        return string(bytes.concat("pesan ", bytes(_digit(i))));
    }

    function _digit(uint256 i) internal pure returns (string memory) {
        require(i < 10, "single digit only");
        bytes memory b = new bytes(1);
        b[0] = bytes1(uint8(48 + i));
        return string(b);
    }
}
