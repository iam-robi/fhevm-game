// SPDX-License-Identifier: BSD-3-Clause-Clear

pragma solidity >=0.8.13 <0.9.0;

import "fhevm/lib/TFHE.sol";
import "hardhat/console.sol";


contract BunkerWarZ {

    // Enum to represent the current state of the game
    enum GameState {
        UNINITIALIZED,
        PLAYER1_TURN,
        PLAYER2_TURN,
        PLAYER1_WON,
        PLAYER2_WON,
        DRAW
    }

    struct Game {
        // Addresses
        address player1;
        address player2;

        // Scalars
        uint8 board_width;
        uint8 board_height;
        uint8 turns;

        // Booleans
        GameState game_state;

        // Numbers of houses built by players
        euint8 player1_houses;
        euint8 player2_houses;

        // Boards using mappings
        mapping(uint8 => mapping(uint8 => euint8)) player1_board;
        mapping(uint8 => mapping(uint8 => euint8)) player2_board;
    }

    uint8 constant EMPTY = 0;
    uint8 constant HOUSE = 1;
    uint8 constant BUNKER = 2;

    uint8 constant MIN_COLUMNS = 1;
    uint8 constant MAX_COLUMNS = 10;
    uint8 constant MIN_ROWS = 3;
    uint8 constant MAX_ROWS = 10;

    // Mapping to store games by their IDs
    mapping(uint => Game) public games;
    uint public new_game_id;

    // Event to notify when a new game is created
    event NewGameCreated(uint gameId, uint8 board_width, uint8 board_height, address player1, address player2);
    event BuildingPlaced(uint8 row, uint8 column, bool is_player1);
    event MissileHit(uint8 row, uint8 column, bool opponent_is_player1);
    event GameEnded(GameState game_end_state);

    modifier onlyPlayers(uint game_id) {
        require(msg.sender == games[game_id].player1 || msg.sender == games[game_id].player2, "Only players can call this function");
        _;
    }

    constructor() {
    }

    // Create a new game
    function new_game(uint8 _board_width, uint8 _board_height, address _player1, address _player2) public {
        require(_player1 != address(0) && _player2 != address(0), "players must not be null address");
        require(_board_width >= MIN_COLUMNS && _board_width <= MAX_COLUMNS &&
                _board_height >= MIN_ROWS && _board_height <= MAX_ROWS,
                "board size is incorrect");
        // Create a new game with the specified parameters
        Game storage newGame = games[new_game_id];
        newGame.player1 = _player1;
        newGame.player2 = _player2;
        newGame.game_state = GameState.PLAYER1_TURN; // player 1 starts
        newGame.board_width = _board_width;
        newGame.board_height = _board_height;

        emit NewGameCreated(new_game_id, _board_width, _board_height, _player1, _player2);

        // Increment the game_id
        new_game_id++;        
    }

    // start a turn
    function _start_turn(uint game_id) internal view returns (Game storage, bool){
        // load the game from storage:
        Game storage game = games[game_id];
        bool player1_plays;

        if(game.game_state == GameState.PLAYER1_TURN && msg.sender == game.player1){
            player1_plays = true;
        }else if (game.game_state == GameState.PLAYER2_TURN && msg.sender == game.player2){
            player1_plays = false;
        }else{
            // either the game is not ongoing
            require(game.game_state != GameState.UNINITIALIZED && game.game_state < GameState.PLAYER1_WON,
                "Game either has ended or does not exist");
            // or, the player is not the right one for this turn
            revert("Not your turn");
        }        
        return (game, player1_plays);
    } 

    // End a turn
    function _end_turn(Game storage game) internal {
        if(game.game_state == GameState.PLAYER1_TURN){
            // change to player2
            game.game_state = GameState.PLAYER2_TURN;
        }
        else if (game.game_state == GameState.PLAYER2_TURN){
            // increment turns after player 2 plays
            game.turns++;
            // end game if game.max_turns is reached
            if (game.turns == game.board_height*game.board_width){

                uint8 player1_housesClear = TFHE.decrypt(game.player1_houses);
                uint8 player2_housesClear = TFHE.decrypt(game.player1_houses);
                if (player1_housesClear > player2_housesClear){
                    game.game_state = GameState.PLAYER1_WON;    
                } else if (player1_housesClear < player2_housesClear){
                    game.game_state = GameState.PLAYER2_WON;
                }else{
                    game.game_state = GameState.DRAW;
                }
                emit GameEnded(game.game_state);
                return;
            }
            // also, change to player1
            game.game_state = GameState.PLAYER1_TURN;
        }
        else{
            revert("Should not call _end_turn if the game is not ongoing");
        }
    }

    /// check wether some FHE euint8 value was initilized and decrypt it or return EMPTY
    function _empty_or_value(euint8 decrypt_value) internal view returns (uint8) {
        uint8 value = TFHE.isInitialized(decrypt_value) ? TFHE.decrypt(decrypt_value) : EMPTY;
        return value;
    }

    // Build either a house or a bunker, the location is clear but the building type is encrypted
    // A house gives 1 point, and a bunker securizes all houses bellow it on the column
    // encrypted_type_m1: encrypted type minus 1, so 0 for a house and 1 for a bunker
    function build(uint game_id, uint8 row, uint8 column, bytes calldata encrypted_type_m1) public{ // onlyPlayers(game_id) {

        // start turn
        Game storage game;
        bool player1_plays;
        (game, player1_plays) = _start_turn(game_id);

        // check row and column
        require(row <= game.board_height && column <= game.board_width, "row or column is out of board's dimensions");

        // select player's board
        mapping(uint8 => mapping(uint8 => euint8)) storage board = (player1_plays)? game.player1_board: game.player2_board;

        // check that the cell is empty
        uint8 cell = _empty_or_value(board[row][column]);
        require(cell == EMPTY, "The cell is already built");

        // check that there is something built under the cell if row is >0
        if(row > 0){
            uint8 cell_below = _empty_or_value(board[row-1][column]);
            require(cell_below != EMPTY, "The cell below must be built");            
        }
       
        // assign the new value, and increment the house counter if it is a house
        euint8 building_type = TFHE.add((TFHE.asEuint8(TFHE.asEbool(encrypted_type_m1))) , TFHE.asEuint8(1));
        board[row][column] = building_type;
        if (player1_plays) {
            game.player1_houses = TFHE.add(game.player1_houses, TFHE.asEuint8(TFHE.eq(building_type, TFHE.asEuint8(1))));
        } else {
            game.player2_houses = TFHE.add(game.player2_houses, TFHE.asEuint8(TFHE.eq(building_type, TFHE.asEuint8(1))));
        }

        // emit event, the location of the building is known
        emit BuildingPlaced(row, column, player1_plays);
        
        _end_turn(game);
    }

    // Or, send a missile toward one of the columns of the opponent
    // The missile will destroy all houses of the column untill it reaches a bunker
    // All constructions below the bunker will stay hidden
    function sendMissile(uint game_id, uint8 column) public onlyPlayers(game_id) {
        
        // start turn
        Game storage game;
        bool player1_plays;
        (game, player1_plays) = _start_turn(game_id);

        // select the board of the opponent
        mapping(uint8 => mapping(uint8 => euint8)) storage target_board = (player1_plays)? game.player2_board: game.player1_board;

        uint8 row_plus_one = game.board_height;
        while (row_plus_one > 0){
            uint8 cell = _empty_or_value(target_board[row_plus_one-1][column]);
            if(cell == BUNKER){
                // break if the missile hits a bunker
                break;
            }else if(cell == HOUSE){
                // decrease opponent score and destroy the house if there is an unprotected house, and continue
                if (msg.sender == game.player1) {
                    game.player2_houses = TFHE.sub(game.player2_houses, TFHE.asEuint8(1));
                } else {
                    game.player1_houses = TFHE.sub(game.player1_houses, TFHE.asEuint8(1));
                }
                target_board[row_plus_one-1][column] = TFHE.asEuint8(EMPTY);
            }else{
                // else, the cell is empty, continue
            }
            row_plus_one--;
        }

        // signal where the missile has hit
        // Hit row = row_plus_one-1, this will happen if there was a bunker
        // row_plus_one=0 means the column was empty
        emit MissileHit(row_plus_one, column, player1_plays);

        _end_turn(game);
    }    
}
