import { expect } from "chai";
import { ethers } from "hardhat";

import { createInstances } from "../instance";
import { getSigners } from "../signers";
import { createTransaction } from "../utils";
import { deployBunkerWarZFixture } from "./BunkerWarZ.fixture";

const UNINITIALIZED = 0;
const PLAYER1_TURN = 1;
const PLAYER2_TURN = 2;
const PLAYER1_WON = 3;
const PLAYER2_WON = 4;
const TIE = 5;

const EMPTY = 0;
const HOUSE = 1;
const BUNKER = 2;

function assert(boolean: bool, message: str){
  if(!boolean){
    throw new Error(message);
  }
}

describe("BunkerWarZ", function () {
  before(async function () {
    this.signers = await getSigners(ethers);

    this.create_game = async (board_width: uint8, board_height: uint8) => {
        const transaction = await createTransaction(
          this.contract.newGame, board_width, board_height,
          this.signers.alice.address,this.signers.bob.address
        );
        await transaction.wait();
        this.last_game_id++;  
    };

    this._player_builds = async (buildingType: uint8, row: uint8, column: uint8, is_alice: bool) => {
        assert(buildingType==HOUSE || buildingType==BUNKER, "wrong building type");
        const instance = is_alice? this.instances.alice: this.instances.bob;
        const signer = is_alice? this.signers.alice: this.signers.bob;

        const building_type_minus_1 = instance.encrypt8(true*(buildingType-1));
        const transaction = await createTransaction(
          this.contract.connect(signer).build, this.last_game_id, row, column, building_type_minus_1
        );
        await transaction.wait();  
    }

    this.alice_builds = async (buildingType: uint8, row: uint8, column: uint8) => {
        await this._player_builds(buildingType, row, column, true);
    };

    this.bob_builds = async (buildingType: uint8, row: uint8, column: uint8) => {
        await this._player_builds(buildingType, row, column, false);     
    };

    this.bob_sends_missile_at = async (column: uint8) => {
        const transaction = await createTransaction(
          this.contract.connect(this.signers.bob).sendMissile, this.last_game_id, column
        );
        await transaction.wait();      
    };

  });

  beforeEach(async function () {
    const contract = await deployBunkerWarZFixture();
    this.contractAddress = await contract.getAddress();
    this.contract = contract;
    this.instances = await createInstances(this.contractAddress, ethers, this.signers);    
    // this will tell the id of the last created game, it needs to
    // be increased of 1 after every call to contract.new_game
    this.last_game_id = -1;
  });

  it("should allow to create games", async function () {

    const board_width = 3;
    const board_height = 5;

    await this.create_game(board_width, board_height);

    let new_game_id = await this.contract.new_game_id();
    expect(new_game_id).to.equal(this.last_game_id+1);

    let game = await this.contract.games(this.last_game_id);
    expect(game[0]).to.equal(this.signers.alice.address);
    expect(game[1]).to.equal(this.signers.bob.address);
    expect(game[2]).to.equal(board_width);
    expect(game[3]).to.equal(board_height);
    expect(game[4]).to.equal(0);
    expect(game[5]).to.equal(PLAYER1_TURN);    
    expect(game[6]).to.equal(true);
    expect(game[7]).to.equal(true);

    await this.create_game(4, 6);

    new_game_id = await this.contract.new_game_id();
    expect(new_game_id).to.equal(this.last_game_id+1);
  });


  it("should allow to end a game", async function () {

    const board_width = 1;
    const board_height = 2;

    await this.create_game(board_width, board_height);

    // play 2 turns each
    await this.alice_builds(HOUSE, 0,0);    
    await this.bob_builds(HOUSE, 0,0);
    await this.alice_builds(HOUSE, 1,0);
    await this.bob_builds(BUNKER, 1,0);

    // now check that the game has ended and that alice won
    let game = await this.contract.games(this.last_game_id);
    expect(game[5]).to.equal(PLAYER1_WON);

  });  

  it("should allow to build something", async function () {

    await this.create_game(3, 5);

    // build a house
    await this.alice_builds(HOUSE, 0,0);

    // check that the turn changed to bob
    let game = await this.contract.games(this.last_game_id);
    expect(game[5]).to.equal(PLAYER2_TURN);

    // get the corresponding reencrypted board value and decrypt it
    const aliceConnected = this.contract.connect(this.signers.alice);
    const tokenAlice = this.instances.alice.getTokenSignature(this.contractAddress)!;
    const encryptedBoardValueAlice = await aliceConnected.getBoardValue(
      this.last_game_id,0,0,tokenAlice.publicKey, tokenAlice.signature);

    // Decrypt the board value
    const boardValueAlice = this.instances.alice.decrypt(this.contractAddress, encryptedBoardValueAlice);
    expect(boardValueAlice).to.equal(HOUSE);

    // let bob play so as to return back to alice
    await this.bob_builds(HOUSE, 0,0);    

    // check if prevent to build something onto a non empty spot
    await expect(this.alice_builds(HOUSE, 0,0)).to.throw;

    // check if prevent to build something if there is not a building below
    await expect(this.alice_builds(HOUSE, 2,0)).to.throw;

    // check if can build something right above
    this.alice_builds(HOUSE, 1,0);

  });

  it.only("should allow to send a missile", async function () {

    await this.create_game(3, 3);

    // alice builds a bunker
    await this.alice_builds(BUNKER, 0,0);

    // let bob play so as to return back to alice
    await this.bob_builds(HOUSE, 0,0);

    // alice builds a house
    await this.alice_builds(HOUSE, 1,0);  

    // bob sends a missile to the column 0:
    await this.bob_sends_missile_at(0);

    // check that alice's house was destroyed and that she can see where the missile hit
    let missile_hit, missile_hit_at_row_plus1, missile_hit_at_column;
    [missile_hit, missile_hit_at_row_plus1, missile_hit_at_column] = await this.contract.getMissileHit(this.last_game_id);
    expect(missile_hit).to.equal(true);    
    expect(missile_hit_at_row_plus1).to.equal(0+1);    
    expect(missile_hit_at_column).to.equal(0);    
  });  

  it("should destroy unprotected houses after missile", async function () {

    await this.create_game(3, 3);

    // alie builds a house
    await this.alice_builds(HOUSE,0,0);

    // bob sends a missile to the column 0:
    await this.bob_sends_missile_at(0);

    // alice should not be able to build a house on the next row after her first house was destroyed
    await expect(this.alice_builds(HOUSE, 1,0)).to.throw;

    // check that alice can see where the missile hit
    let missile_hit, missile_hit_at_row_plus1, missile_hit_at_column;
    [missile_hit, missile_hit_at_row_plus1, missile_hit_at_column] = await this.contract.getMissileHit(this.last_game_id);
    expect(missile_hit).to.equal(true);    
    expect(missile_hit_at_row_plus1).to.equal(0);    
    expect(missile_hit_at_column).to.equal(0);    

  });

  it("should store the missile hit position", async function () {

    await this.create_game(3, 3);

    // alie builds a bunker
    await this.alice_builds(BUNKER,0,0);

    // bob sends a missile to the column 0:
    await this.bob_sends_missile_at(0);

    // check that alice can see where the missile hit
    let missile_hit, missile_hit_at_row_plus1, missile_hit_at_column;
    [missile_hit, missile_hit_at_row_plus1, missile_hit_at_column] = await this.contract.getMissileHit(this.last_game_id);
    expect(missile_hit).to.equal(true);    
    expect(missile_hit_at_row_plus1).to.equal(1);
    expect(missile_hit_at_column).to.equal(0);    

  });    

  it("should prevent sending two missiles in a row", async function () {

    await this.create_game(3, 3);

    let game = await this.contract.games(this.last_game_id);
    expect(game[7]).to.equal(true);

    // aice builds a house
    await this.alice_builds(HOUSE, 0,0);

    // bob sends a missile to the column 0:
    await this.bob_sends_missile_at(0);

    // alice plays again, rebuilding a destroyed house
    await this.alice_builds(HOUSE, 0,0);

    // check that bob cannot send a missile
    game = await this.contract.games(this.last_game_id);
    expect(game[7]).to.equal(false);

    await expect(this.bob_sends_missile_at(0)).to.throw;
  });      


});
