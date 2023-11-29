// SPDX-License-Identifier: BSD-3-Clause-Clear

pragma solidity >=0.8.13 <0.9.0;

import "hardhat/console.sol";
import "fhevm/lib/TFHE.sol";
import "fhevm/abstracts/EIP712WithModifier.sol";

contract BunkerWarZ is EIP712WithModifier{

    struct Game {
        // Addresses
        address player1;
        address player2;

        // Scalars
        uint8 board_width;
        uint8 board_height;
        uint8 turns;

        // GameState
        uint8 game_state;

        // Booleans
        bool player1_can_send_missile; // prevent sending two missiles in a row
        bool player2_can_send_missile;  

        // TODO: remove this sub-graphs are available
        // these variables are used because the event cannot 
        // be queried for now on the tesnet, but the information is in the MissileHit events
        bool missile_hit;
        uint8 missile_hit_at_row_plus_1;
        uint8 missile_hit_at_column;

        // Numbers of houses built by players
        euint8 player1_houses;
        euint8 player2_houses;

        // Boards using mappings
        mapping(uint8 => mapping(uint8 => euint8)) player1_board;
        mapping(uint8 => mapping(uint8 => euint8)) player2_board;

        // TODO: remove this sub-graphs are available
        mapping(uint8 => mapping(uint8 => bool)) player1_buildings;
        mapping(uint8 => mapping(uint8 => bool)) player2_buildings;        
    }

    // Values of min and max board dimensions
    uint8 constant MIN_COLUMNS = 1;
    uint8 constant MAX_COLUMNS = 6;
    uint8 constant MIN_ROWS = 2;
    uint8 constant MAX_ROWS = 6;

    // Values to represent cell contents
    // (using uint8 instead of enum here is better for TFHE compatibility)
    uint8 constant EMPTY = 0;
    uint8 constant HOUSE = 1;
    uint8 constant BUNKER = 2;

    // Values to represent the current state of the game
    // (using uint8 instead of enum here is better for TFHE compatibility)    
    uint8 constant UNINITIALIZED = 0;
    uint8 constant PLAYER1_TURN = 1;
    uint8 constant PLAYER2_TURN = 2;
    uint8 constant PLAYER1_WON = 3;
    uint8 constant PLAYER2_WON = 4;
    uint8 constant TIE = 5;

    // Value to avoid trivial encryption every time
    euint8 ENCRYPTED_EMPTY;

    uint8 public clear_game_result_;

    // Mapping to store games by their IDs
    mapping(uint => Game) public games;
    uint public new_game_id;

    // Event to notify when a new game is created
    event NewGameCreated(uint gameId, uint8 board_width, uint8 board_height, address indexed player1, address indexed player2);
    event BuildingPlaced(uint8 row, uint8 column, bool is_player1, uint indexed gameId);
    event MissileHit(uint8 row, uint8 column, bool opponent_is_player1, uint indexed gameId);
    event GameEnded(uint8 game_end_state, uint indexed gameId);

    modifier onlyPlayers(uint game_id) {
        require(
            msg.sender == games[game_id].player1 || msg.sender == games[game_id].player2,
            "Only players can call this function"
        );
        _;
    }

    constructor() EIP712WithModifier("Authorization token", "1") {
        ENCRYPTED_EMPTY = TFHE.asEuint8(EMPTY);
    }

    // TODO: remove this sub-graphs are available
    // Get some value of an encrypted board (if the player needs to rebuild his game state)
    function getBoardValue(
        uint game_id, 
        uint8 row, 
        uint8 column, 
        bytes32 publicKey, 
        bytes calldata signature)
    external view onlySignedPublicKey(publicKey, signature) returns (bytes memory){
        Game storage game = games[game_id];
        require(row <= game.board_height && column <= game.board_width,
            "row or column is out of board's dimensions");
        if (msg.sender == game.player1){
            return TFHE.reencrypt(game.player1_board[row][column], publicKey, EMPTY);
        }else if(msg.sender == game.player2){
            return TFHE.reencrypt(game.player2_board[row][column], publicKey, EMPTY);
        }else{
            revert("Only players of the game can get board values");
        }
    }

    // TODO: remove this sub-graphs are available
    // Get the state "built or Not built" of cells of a player
    function getBuildingStates(
        uint game_id,
        bool is_player1
        ) external view returns (bool[] memory){
        Game storage game = games[game_id];
        mapping(uint8 => mapping(uint8 => bool)) storage buildings = (is_player1)? game.player1_buildings: game.player2_buildings;
        bool[] memory building_states_array = new bool[](game.board_width*game.board_height);
        for (uint8 i=0; i<game.board_width; i++){
            for (uint8 j=0; j<game.board_height; j++){
                building_states_array[i*game.board_height+j] = buildings[i][j];
            }
        }
        return building_states_array;
    }

    // Get whether the missile hit and where untill event can be querried
    // TODO: remove this sub-graphs are available
    function getMissileHit(uint game_id) public view returns (bool, uint8, uint8){
        Game storage game = games[game_id];
        return (game.missile_hit, game.missile_hit_at_row_plus_1, game.missile_hit_at_column);
    }

    // Create a new game
    function newGame(uint8 _board_width, uint8 _board_height, address _player1, address _player2) public {
        require(_player1 != address(0) && _player2 != address(0), "players must not be null address");
        require(_board_width >= MIN_COLUMNS && _board_width <= MAX_COLUMNS &&
                _board_height >= MIN_ROWS && _board_height <= MAX_ROWS,
                "board size is incorrect");
        // Create a new game with the specified parameters
        Game storage new_game = games[new_game_id];
        new_game.player1 = _player1;
        new_game.player2 = _player2;
        new_game.game_state = PLAYER1_TURN; // player 1 starts
        new_game.board_width = _board_width;
        new_game.board_height = _board_height;
        new_game.player1_can_send_missile = true;
        new_game.player2_can_send_missile = true;

        emit NewGameCreated(new_game_id, _board_width, _board_height, _player1, _player2);

        // Increment the game_id
        new_game_id++;        
    }

    // Start a turn
    function _startTurn(uint game_id) internal view returns (Game storage, bool){
        // load the game from storage:
        Game storage game = games[game_id];
        bool player1_plays;

        if(game.game_state == PLAYER1_TURN && msg.sender == game.player1){
            player1_plays = true;
        }else if (game.game_state == PLAYER2_TURN && msg.sender == game.player2){
            player1_plays = false;
        }else{
            // either the game is not ongoing
            require(game.game_state != UNINITIALIZED && game.game_state < PLAYER1_WON,
                "Game either has ended or does not exist");
            // or, the player is not the right one for this turn
            revert("Not your turn");
        }        
        return (game, player1_plays);
    } 

    // check whether a value was initialized or not, and return
    function _valueOrZero(euint8 value) pure internal returns (euint8) {
        return TFHE.isInitialized(value)? value: TFHE.asEuint8(0);
    }

    // End a turn
    function _endTurn(Game storage game, uint game_id) internal {
        if(game.game_state == PLAYER1_TURN){
            // change to player2
            game.game_state = PLAYER2_TURN;
        }
        else if(game.game_state == PLAYER2_TURN){
            // increment turns after player 2 plays
            game.turns++;
            // end game if game.max_turns is reached
            if (game.turns == game.board_height*game.board_width){

                // keep either PLAYER1_WON, PLAYER2_WON or TIE in game_result
                euint8 houses_1 = _valueOrZero(game.player1_houses);
                euint8 houses_2 = _valueOrZero(game.player2_houses);

                ebool player_1_ge = TFHE.ge(houses_1, houses_2);
                ebool tie = TFHE.eq(game.player1_houses, game.player2_houses);

                euint8 game_result = TFHE.cmux(
                    player_1_ge,
                    TFHE.asEuint8(PLAYER1_WON),
                    TFHE.asEuint8(PLAYER2_WON)
                );
                game_result = TFHE.cmux(tie, TFHE.asEuint8(TIE), game_result);

                // decrypt game_result, save it and emit GameEnded event
                game.game_state = TFHE.decrypt(game_result);
                emit GameEnded(game.game_state, game_id);
            }
            else{
                // also, change to player1
                game.game_state = PLAYER1_TURN;
            }
        }
        else{
            revert("Should not call _endTurn if the game is not ongoing");
        }
    }


    // Build either a house or a bunker, the location is clear but the building type is encrypted
    // A house gives 1 point, and a bunker securizes all houses bellow it on the column
    // encrypted_type_m1: encrypted type minus 1, so 0 for a house and 1 for a bunker (the boolean value ensures we don't provide any other value)
    // to rebuild the UI part of the game in another session if required
    function build( uint game_id, uint8 row, uint8 column, bytes calldata encrypted_type_m1) public onlyPlayers(game_id) {

        // start turn
        Game storage game;
        bool player1_plays;
        (game, player1_plays) = _startTurn(game_id);

        // check row and column
        require(row < game.board_height && column < game.board_width, "row or column is out of board's dimensions");

        // select player's board
        mapping(uint8 => mapping(uint8 => euint8)) storage board = (player1_plays)? game.player1_board: game.player2_board;

        // check that the cell is empty and if row>0 that the cell below is built
        euint8 encrypted_cell = board[row][column];
        if (TFHE.isInitialized(encrypted_cell)){
            // If the cell was initialized, it must have been destroyed to be empty again
            ebool cell_ok = TFHE.eq(encrypted_cell, EMPTY);
            // check that there is something built under the cell if row is >0
            if(row > 0){
                // in this case, the cell below is necessarily initialized
                // check that it is not empty
                ebool cell_below_built = TFHE.ne(board[row-1][column], EMPTY);
                cell_ok = TFHE.and(cell_ok, cell_below_built);
            }
            require(TFHE.decrypt(cell_ok), "The cell is already built or the cell below is not built");
        }else if(row > 0){
            // If the cell is uninitialized, it is empty, so we just check the cell below
            euint8 encrypted_cell_below = board[row-1][column];
            if (TFHE.isInitialized(encrypted_cell_below)){
                // if the cell below is initialized, check if it is not empty
                ebool cell_below_built = TFHE.ne(encrypted_cell_below, EMPTY);
                require(TFHE.decrypt(cell_below_built), "The cell below is not built");                            
            }else{
                // if the cell below is not initialized, it is empty
                revert("The cell below must be built");
            }           
        }      

        // assign the new value, and increment the house counter if it is a house
        // also, after building something, the player can send a missile again
        euint8 building_type = TFHE.add((TFHE.asEuint8(TFHE.asEbool(encrypted_type_m1))) , 1);
        board[row][column] = building_type;
        if (player1_plays) {
            game.player1_houses = TFHE.add(game.player1_houses, TFHE.asEuint8(TFHE.eq(building_type, 1)));
            game.player1_can_send_missile = true;
        } else {
            game.player2_houses = TFHE.add(game.player2_houses, TFHE.asEuint8(TFHE.eq(building_type, 1)));
            game.player2_can_send_missile = true;
        }

        // emit event, the location of the building is known
        emit BuildingPlaced(row, column, player1_plays, game_id);      

        // TODO: remove this block sub-graphs are available
        // also reset the missile hit values in the gamestate untill event can be querried
        game.missile_hit = false;
        game.missile_hit_at_row_plus_1 = 0;
        game.missile_hit_at_column = 0;
        // mark the building as built
        mapping(uint8 => mapping(uint8 => bool)) storage player_buildings = (player1_plays)? game.player1_buildings: game.player2_buildings;
        player_buildings[row][column] = true;
        // End of TODO
        
        _endTurn(game, game_id);
    }

    // Or, send a missile toward one of the columns of the opponent
    // The missile will destroy all houses of the column untill it reaches a bunker
    // All constructions below the bunker will stay hidden
    function sendMissile(uint game_id, uint8 column) public onlyPlayers(game_id) {
        
        // start turn
        Game storage game;
        bool player1_plays;
        (game, player1_plays) = _startTurn(game_id);

        // check that the player can send a missile
        require( (player1_plays && game.player1_can_send_missile) || (!player1_plays && game.player2_can_send_missile),
            "Cannot send two missiles in a row" );

        // select the board of the opponent
        mapping(uint8 => mapping(uint8 => euint8)) storage target_board = (player1_plays)? game.player2_board: game.player1_board;

        uint8 row_plus_1 = game.board_height;
        // save the row (+1) where the missile hits, 0 if never updated by cmux
        euint8 hit_row_plus_1_enc = TFHE.asEuint8(0);
        ebool bunker_not_seen = TFHE.asEbool(true); // wether we did not come accross a bunker yet
        while (row_plus_1 > 0){
            euint8 encrypted_cell = target_board[row_plus_1-1][column];
            // continue if the cell is not initiliazed
            if(TFHE.isInitialized(encrypted_cell)){
                ebool cell_is_bunker = TFHE.eq(encrypted_cell, BUNKER);
                // // compute wheter this is the first bunker seen
                ebool cell_is_first_bunker = TFHE.and(cell_is_bunker, bunker_not_seen);
                // // if the cell is the first bunker seen, keep its row (+1) in hit_row_plus_1_enc:
                hit_row_plus_1_enc = TFHE.cmux(cell_is_first_bunker, TFHE.asEuint8(row_plus_1), hit_row_plus_1_enc);
                // // update whether we saw a bunker
                bunker_not_seen = TFHE.and(TFHE.not(cell_is_bunker), bunker_not_seen);

                // decrease opponent score and destroy the house if the cell is an unprotected house, and continue
                ebool cell_is_house = TFHE.eq(encrypted_cell, HOUSE);
                ebool cell_is_unprotected_house = TFHE.and(cell_is_house, bunker_not_seen);
                if (player1_plays) {
                    game.player2_houses = TFHE.sub(game.player2_houses, TFHE.asEuint8(cell_is_unprotected_house));
                } else {
                    game.player1_houses = TFHE.sub(game.player1_houses, TFHE.asEuint8(cell_is_unprotected_house));
                }
                // empty the cell if it was destroyed
                target_board[row_plus_1-1][column] = TFHE.cmux(cell_is_unprotected_house, ENCRYPTED_EMPTY, encrypted_cell);
            }
            row_plus_1--;
        }

        // signal where the missile has hit
        // Hit row = hit_row_plus_1_enc-1, this will happen if there was a bunker
        // hit_row_plus_1_enc=0 means the column was empty
        uint8 hit_at_row_plus_1= TFHE.decrypt(hit_row_plus_1_enc);
        emit MissileHit(hit_at_row_plus_1, column, player1_plays, game_id);

        // after sending a missile, a player must build something in order to be able to send another one:
        if (player1_plays) {
            game.player1_can_send_missile = false;
        } else {
            game.player2_can_send_missile = false;
        }

        // TODO: remove this block sub-graphs are available
        // also store the missile hit in the gamestate untill event can be querried
        game.missile_hit = true;
        game.missile_hit_at_row_plus_1 = hit_at_row_plus_1;
        game.missile_hit_at_column = column;
        // set houses to not built after they got destroyed
        mapping(uint8 => mapping(uint8 => bool)) storage player_buildings = (player1_plays)? game.player1_buildings: game.player2_buildings;
        for (uint8 i=hit_at_row_plus_1; i<game.board_height; i++){
            player_buildings[i][column] = false;
        }
        // End of TODO

        _endTurn(game, game_id);
    }    
}
