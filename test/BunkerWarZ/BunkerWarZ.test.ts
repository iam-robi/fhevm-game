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
const DRAW = 5;

const EMPTY = 0;
const HOUSE = 1;
const BUNKER = 2;


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

    this.alice_builds_at = async (buildingType: uint8, row: uint8, column: uint8) => {
        const building_type_minus_1 = this.instances.alice.encrypt8(buildingType-1);
        const transaction = await createTransaction(
          this.contract.connect(this.signers.alice).build, this.last_game_id, row, column, building_type_minus_1
        );
        await transaction.wait();      
    };

    this.bob_builds_at = async (buildingType: uint8, row: uint8, column: uint8) => {
        const building_type_minus_1 = this.instances.bob.encrypt8(buildingType-1);
        const transaction = await createTransaction(
          this.contract.connect(this.signers.bob).build, this.last_game_id, row, column, building_type_minus_1
        );
        await transaction.wait();      
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

    await this.create_game(5, 8);

    new_game_id = await this.contract.new_game_id();
    expect(new_game_id).to.equal(this.last_game_id+1);
  });

  it("should allow to build something", async function () {

    await this.create_game(3, 5);
    let transaction;

    // build a house
    await this.alice_builds_at(HOUSE, 0,0);

    // check that the turn changed to bob
    let game = await this.contract.games(this.last_game_id);
    expect(game[5]).to.equal(PLAYER2_TURN);

    // // get the corresponding reencrypted board value and decrypt it
    // const tokenAlice = this.instances.alice.getTokenSignature(this.contractAddress)!;
    // const encryptedBoardValueAlice = await this.contract.connect(this.signers.alice).getBoardValue(
    //   this.last_game_id,0,0,tokenAlice.publicKey, tokenAlice.signature
    // );
    // const boardValueAlice = this.instances.alice.decrypt(this.contractAddress, encryptedBoardValueAlice);
    // expect(boardValueAlice).to.equal(HOUSE-1);

    // let bob play so as to return back to alice
    await this.bob_builds_at(HOUSE, 0,0);    

    // // check if prevent to build something onto a non empty spot
    // transaction = await createTransaction(
    //   this.contract.connect(this.signers.alice).build, this.last_game_id, 0, 0, building_type_minus_1
    // );
    // await expect(transaction.wait()).to.be.revertedWith(

    // // check if prevent to build something if there is not a building below
    // transaction = await createTransaction(
    //   this.contract.connect(this.signers.alice).build, this.last_game_id, 2, 0, building_type_minus_1
    // );
    // await expect(transaction.wait()).to.be.revertedWith(
    //   "The cell below must be built"
    // );  

    // // check if can build something right above
    // transaction = await createTransaction(
    //   this.contract.connect(this.signers.alice).build, this.last_game_id, 2, 0, building_type_minus_1
    // );
    // await expect(transaction.wait()).to.be.revertedWith(
    //   "The cell below must be built"
    // );  

  });

  it.only("should allow to send a missile", async function () {

    await this.create_game(3, 5);

    let game = await this.contract.games(this.last_game_id);
    expect(game[7]).to.equal(true);

    // build a bunker
    await this.alice_builds_at(BUNKER, 0,0);

    // let bob play so as to return back to alice
    await this.bob_builds_at(HOUSE, 0,0);

    // build house
    await this.alice_builds_at(HOUSE, 1,0);  

    // bob sends a missile to the column 0:
    await this.bob_sends_missile_at(0);

    // // check that alice's house was destroyed and that she can see where the missile hit
    // let missile_hit, missile_hit_at_row_plus1, missile_hit_at_column;
    // [missile_hit, missile_hit_at_row_plus1, missile_hit_at_column] = await this.contract.getMissileHit(this.last_game_id);
    // expect(missile_hit).to.equal(true);    
    // expect(missile_hit_at_row_plus1).to.equal(1);    
    // expect(missile_hit_at_column).to.equal(0);    

    // // alice plays again, rebulding a destroyed house
    // await this.alice_builds_at(HOUSE, 1,0);

    // // check that bob cannot send a missile
    // game = await this.contract.games(this.last_game_id);
    // expect(game[7]).to.equal(false);

    // // and check that bob sees that no missile hit him
    // [missile_hit_at_row_plus1, missile_hit_at_column] = await this.contract.getMissileHit(this.last_game_id);
    // expect(missile_hit).to.equal(false); 
    // expect(missile_hit_at_row_plus1).to.equal(0);
    // expect(missile_hit_at_column).to.equal(0);

    // // check if prevents to send two missiles in a row
    // // await expect(this.bob_sends_missile_at(0)).to.be.revertedWith(
    // //   "Cannot send two missiles in a row"
    // // );  
  });  


});
