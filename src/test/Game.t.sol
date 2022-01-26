// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {Utilities} from "./utils/Utilities.sol";
import {console} from "./utils/Console.sol";
import {Hevm} from "./utils/Hevm.sol";

import "../Game.sol";
import "../Snake.sol";

contract GameTest is DSTest {
    Hevm internal immutable hevm = Hevm(HEVM_ADDRESS);

    Utilities internal utils;
    address payable[] internal users;
    Snake internal snake;
    Game internal game;

    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(10);

        snake = new Snake("snake", "SNK");
        game = new Game(snake, address(1));
    }

    function testExample() public {
        address payable alice = users[0];
        address payable bob = users[1];
        hevm.prank(alice);
        (bool sent, ) = bob.call{value: 10 ether}("");
        assertTrue(sent);
        assertGt(bob.balance, alice.balance);
    }

    function testCreateRoom() public {
        game.createRoom(1);
        game.createRoom(10);
        game.createRoom(100);

        hevm.expectRevert("Cost must be 1, 10 or 100");
        game.createRoom(101);
    }

    function testJoinRoom() public {
        hevm.prank(users[0]);
        // player 0 create a room
        game.createRoom(1);
        hevm.prank(users[1]);
        // player 1 join in
        game.joinRoom(1);

        uint256 players = game.getNumberOfPlayer(1);
        // there are 2 players in the roomId 1
        assertEq(players, 2);

        uint256[] memory notReadyRooms = game.getNotReadyRoom();
        assertEq(notReadyRooms.length, 1);
    }

    function testExitGame() public {
        hevm.startPrank(users[0]);
        game.createRoom(1);

        uint256 curTime = block.timestamp;

        // erlay exit should revert
        hevm.expectRevert("Exit room within 5 minutes");
        game.exitRoom(1);

        // after 5 minutes exit should success
        hevm.warp(curTime + 1 + 5 minutes);
        game.exitRoom(1);
    }

    function testEndGame() public {
        for (uint256 i = 0; i < 10; i++) {
            snake.transfer(users[i], 100 * 1 ether);
        }
        hevm.prank(users[0]);
        snake.approve(address(game), 100 * 1 ether);
        hevm.prank(users[0]);
        game.createRoom(100);

        for (uint256 i = 1; i < 10; i++) {
            hevm.prank(users[i]);
            snake.approve(address(game), 100 * 1 ether);
            hevm.prank(users[i]);
            game.joinRoom(1);
        }

        game.endGame(1, users[1], users[2], users[3]);

        uint256 balanceuser1 = snake.balanceOf(users[1]);
        assertEq(balanceuser1, 450 * 1 ether);

        uint256 balanceuser2 = snake.balanceOf(users[2]);
        assertEq(balanceuser2, 270 * 1 ether);

        uint256 balanceuser3 = snake.balanceOf(users[3]);
        assertEq(balanceuser3, 180 * 1 ether);

        uint256 fee = snake.balanceOf(address(1));
        assertEq(
            100 * 10 * 1 ether - balanceuser1 - balanceuser2 - balanceuser3,
            fee
        );
    }
}
