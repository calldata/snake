// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Game is Ownable {
    using SafeERC20 for IERC20;

    struct RoomState {
        uint256 cost;
        address[] players;
    }

    /// @dev triggered when there are exactly 10 players in the room
    event GameStart(uint256 indexed roomId);

    /// @dev triggered when game ended by admin
    event GameEnd(uint256 indexed roomId);

    /// @dev token used in this game
    IERC20 public token;

    /// @dev current allocated max room index
    uint256 public roomIndex;

    /// @dev free room index
    uint256[] public freeRoomIndex;

    /// @dev which room the player is palying
    mapping(address => uint256) public whichRoom;

    /// @dev room id => room state
    mapping(uint256 => RoomState) public roomState;

    /// @dev rooms that not reach to 10 players
    uint256[] public notReadyRoom;

    /// @dev when is the player join in
    mapping(address => uint256) public playerJoinTime;

    constructor(IERC20 _token) {
        token = _token;
    }

    /// @dev rooms that player can join in
    function getNotReadyRoom() external view returns (uint256[] memory) {
        return notReadyRoom;
    }

    /// @dev how many players this room have
    function getNumberOfPlayer(uint256 roomId) public view returns (uint256) {
        return roomState[roomId].players.length;
    }

    /// @dev player join the room. If he is the 10th player joining in,
    /// start the game immediately.
    function joinRoom(uint256 roomId) external {
        address player = msg.sender;
        require(whichRoom[player] == 0, "Already in a room");
        require(getNumberOfPlayer(roomId) > 0, "This room not initialized");
        require(getNumberOfPlayer(roomId) < 10, "Too many players");

        RoomState storage state = roomState[roomId];
        state.players.push(player);

        if (state.players.length == 10) {
            address[] memory players = state.players;
            uint256 playerLength = players.length;
            uint256 cost = state.cost;

            for (uint256 i = 0; i < playerLength; i++) {
                token.safeTransferFrom(players[i], address(this), cost * 1e18);
            }

            emit GameStart(roomId);

            uint256 notReadyRoomLenth = notReadyRoom.length;
            for (uint256 i = 0; i < notReadyRoomLenth; i++) {
                if (notReadyRoom[i] == roomId) {
                    notReadyRoom[i] = notReadyRoom[notReadyRoomLenth - 1];
                    notReadyRoom.pop();
                    break;
                }
            }
        } else {
            whichRoom[player] = roomId;
        }
        playerJoinTime[player] = block.timestamp;
    }

    /// @dev player exit room
    function exitRoom(uint256 roomId) external {
        address player = msg.sender;
        require(whichRoom[player] != 0, "Not in a room");
        require(
            block.timestamp - playerJoinTime[player] > 5 minutes,
            "Exit room within 5 minutes"
        );

        address[] storage players = roomState[roomId].players;
        uint256 playerLength = players.length;

        for (uint256 i = 0; i < playerLength; i++) {
            if (players[i] == player) {
                players[i] = players[playerLength - 1];
                players.pop();
                break;
            }
        }

        delete whichRoom[player];
    }

    /// @dev admin end the game
    function endGame(
        uint256 roomId,
        address firstPlace,
        address secondPlace,
        address thirdPlace
    ) external onlyOwner {
        RoomState memory state = roomState[roomId];
        address[] memory players = state.players;

        for (uint256 i = 0; i < players.length; i++) {
            delete whichRoom[players[i]];
        }

        uint256 total = state.cost * 10;

        uint256 reward1 = (total * 45) / 100;
        token.safeTransfer(firstPlace, reward1 * 1e18);

        uint256 reward2 = (total * 27) / 100;
        token.safeTransfer(secondPlace, reward2 * 1e18);

        uint256 reward3 = (total * 18) / 100;
        token.safeTransfer(thirdPlace, reward3 * 1e18);

        token.safeTransfer(
            address(this),
            (total - reward1 - reward2 - reward3) * 1e18
        );

        delete roomState[roomId];

        freeRoomIndex.push(roomId);

        emit GameEnd(roomId);
    }

    /// @dev create a room by anyone,
    function createRoom(uint256 cost) external {
        require(
            cost == 1 || cost == 10 || cost == 100,
            "Cost must be 1, 10 or 100"
        );
        address player = msg.sender;
        uint256 roomIndex_;

        uint256 index = freeRoomIndex.length;
        if (index == 0) {
            roomIndex++;
            roomIndex_ = roomIndex;
        } else {
            roomIndex_ = freeRoomIndex[index - 1];
            freeRoomIndex.pop();
        }

        roomState[roomIndex_] = RoomState({
            cost: cost,
            players: new address[](0)
        });

        roomState[roomIndex_].players.push(player);
        whichRoom[player] = roomIndex_;
        playerJoinTime[player] = block.timestamp;
        notReadyRoom.push(roomIndex_);
    }

    /// @dev withraw all fee to `to`
    function withdrawFee(address to) external onlyOwner {
        IERC20(token).safeTransfer(to, IERC20(token).balanceOf(address(this)));
    }
}
