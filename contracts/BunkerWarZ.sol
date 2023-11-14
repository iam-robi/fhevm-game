// SPDX-License-Identifier: BSD-3-Clause-Clear

pragma solidity >=0.8.13 <0.9.0;

import "fhevm/lib/TFHE.sol";
import "hardhat/console.sol";


contract Bunkerwarz {
    address public player1;
    address public player2;
    address public currentPlayer;
    address public winner;
    bool public gameEnded;
    //bool public gameReady;
    bool public player1Ready;
    bool public player2Ready;

    uint8 public constant BOARD_WIDTH = 3;
    uint8 public constant BOARD_HEIGHT = 5;
    uint8 public constant MAX_TURNS = 10;
    uint8 public turns;

    uint8 constant EMPTY = 0;
    uint8 constant HOUSE = 1;
    uint8 constant BUNKER = 2;
    euint8 public player1Houses; // number of houses built by player 1
    euint8 public player2Houses; // number of houses built by player 2
    euint8[BOARD_HEIGHT][BOARD_WIDTH] public player1Board; // board of player 1
    euint8[BOARD_HEIGHT][BOARD_WIDTH] public player2Board; // board of player 2

    event BuildingPlaced(uint8 row, uint8 column, address player);
    event MissileHit(uint8 row, uint8 column, address opponent);
    event GameEnded(address winner);

    modifier onlyPlayers() {
        require(msg.sender == player1 || msg.sender == player2, "Only players can call this function");
        _;
    }

    constructor(address _player1, address _player2) {
        player1 = _player1;
        player2 = _player2;
        currentPlayer = player1;
    }

    // End a turn
    function _endTurn() internal {
        if (currentPlayer == player2){
            // increment turns after player 2 plays
            turns++;
            // end game if MAXTURN is reached
            if (turns == MAX_TURNS){

                gameEnded = true;
                uint8 player1HousesClear = TFHE.decrypt(player1Houses);
                uint8 player2HousesClear = TFHE.decrypt(player1Houses);
                if (player1HousesClear > player2HousesClear){
                    winner = player1;    
                } else if (player1HousesClear < player2HousesClear){
                    winner = player2;    
                }else{
                    winner = address(0); // tie
                }
                
                emit GameEnded(winner);
            }
            // also, change to player1
            currentPlayer = player1;          
        }else{
            // change to player2
            currentPlayer = player2;
        }           
    }

    // Build either a house or a bunker, the location is clear but the building type is encrypted
    // A house gives 1 point, and a bunker securizes all houses bellow it on the column
    function build(uint8 row, uint8 column, bytes calldata encryptedType) public onlyPlayers {

        //require(gameReady, "Game not ready");
        require(!gameEnded, "Game has ended");
        require(msg.sender == currentPlayer, "Not your turn");

        // select player's board
        euint8[BOARD_HEIGHT][BOARD_WIDTH] storage board;
        if (msg.sender == player1) {
            board = player2Board;
        } else {
            board = player1Board;
        }

        // check that the cell is empty
        uint8 cell = TFHE.decrypt(board[row][column]);
        require(cell == EMPTY, "The cell is already built");

        // check that there is something built under the cell if row is >0
        if(row > 0){
            require(TFHE.decrypt(TFHE.ne(board[row-1][column], TFHE.asEuint8(EMPTY))), "The cell below must be built");
        }
       
        // assign the new value, and increment the house counter if it is a house
        euint8 buildingType = TFHE.asEuint8(encryptedType);
        board[row][column] = buildingType;
        if (msg.sender == player1) {
            player1Houses = TFHE.add(player1Houses, TFHE.asEuint8(TFHE.eq(buildingType, TFHE.asEuint8(1))));
        } else {
            player2Houses = TFHE.add(player2Houses, TFHE.asEuint8(TFHE.eq(buildingType, TFHE.asEuint8(1))));
        }

        // emit event, the location of the building is known
        emit BuildingPlaced(row, column, currentPlayer);
        
        _endTurn(); 
    }

    // Or, send a missile toward one of the columns of the opponent
    // The missile will destroy all houses of the column untill it reaches a bunker
    // All constructions below the bunker will stay hidden
    function sendMissile(uint8 column) public onlyPlayers {
        //require(gameReady, "Game not ready");
        require(!gameEnded, "Game has ended");
        require(msg.sender == currentPlayer, "Not your turn");

        // select the board of the opponent
        euint8[BOARD_HEIGHT][BOARD_WIDTH] storage targetBoard;
        address opponent;
        if (msg.sender == player1) {
            opponent = player2;
            targetBoard = player2Board;
        } else {
            targetBoard = player1Board;
            opponent = player1;
        }

        uint8 row_plus_one = BOARD_HEIGHT;
        while (row_plus_one > 0){
           uint8 cell = TFHE.decrypt(targetBoard[row_plus_one-1][column]);
           if(cell == BUNKER){
                // break if the missile hits a bunker
                break;
           }else if(cell == HOUSE){
                // decrease opponent score and destroy the house if there is an unprotected house, and continue
                if (msg.sender == player1) {
                    player2Houses = TFHE.sub(player2Houses, TFHE.asEuint8(1));
                } else {
                    player1Houses = TFHE.sub(player1Houses, TFHE.asEuint8(1));
                }
                targetBoard[row_plus_one-1][column] = TFHE.asEuint8(EMPTY);
           }else{
                // else, the cell is empty, continue
           }
           row_plus_one--;
        }

        // signal where the missile has hit
        // Hit row = row_plus_one-1, this will happen if there was a bunker
        // row_plus_one=0 means the column was empty
        emit MissileHit(row_plus_one, column, opponent);

        _endTurn(); 
    }    
}
