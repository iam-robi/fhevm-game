import { expect } from "chai";
import { ethers } from "hardhat";

import { createInstances } from "../instance";
import { getSigners } from "../signers";
import { createTransaction } from "../utils";
import { deployBunkerWarZFixture } from "./BunkerWarZ.fixture";

describe("BunkerWarZ", function () {
  before(async function () {
    this.signers = await getSigners(ethers);
  });

  beforeEach(async function () {
    const contract = await deployBunkerWarZFixture();
    this.contractAddress = await contract.getAddress();
    this.contract = contract;
    this.instances = await createInstances(this.contractAddress, ethers, this.signers);
  });

  it("should allow to create games", async function () {
    let transaction = await createTransaction(this.contract.new_game, 3,5,this.signers.player1.address,this.signers.player2.address);
    const new_game_id = await this.contract.new_game_id();
    expect(new_game_id).to.equal(1);

    let transaction = await createTransaction(this.contract.new_game, 5,8,this.signers.player1.address,this.signers.player2.address);
    const new_game_id = await this.contract.new_game_id();
    expect(new_game_id).to.equal(2);
  });

  it.only("should allow to build something", async function () {

    //await this.contract.connect(this.signers.alice).new_game(3,5,this.signers.player1.address,this.signers.player2.address);

    let transaction = await createTransaction(this.contract.new_game, 3,5,this.signers.player1.address,this.signers.player2.address);
    await transaction.wait();

    // let game = await this.contract.games(0);
    // console.log(game);

    // const building_type_minus_1 = this.instances.player1.encrypt8(0);
    // //await this.contract.connect(this.signers.player1).build(0, 0, 0, building_type_minus_1);
    // const transaction2 = await createTransaction(this.contract.connect(this.signers.player1).build, 0, 0, 0, building_type_minus_1);
    // await transaction2.wait();

    // game = await this.contract.games(0);
    // console.log(game);
  });


  // it("should mint the contract", async function () {
  //   // const encryptedAmount = this.instances.alice.encrypt32(1000);
  //   // const transaction = await createTransaction(this.contract.mint, encryptedAmount);
  //   // await transaction.wait();
  //   // // Call the method
  //   // const token = this.instances.alice.getTokenSignature(this.contractAddress) || {
  //   //   signature: "",
  //   //   publicKey: "",
  //   // };
  //   // const encryptedBalance = await this.contract.balanceOf(token.publicKey, token.signature);
  //   // // Decrypt the balance
  //   // const balance = this.instances.alice.decrypt(this.contractAddress, encryptedBalance);
  //   // expect(balance).to.equal(1000);

  //   // const encryptedTotalSupply = await this.contract.getTotalSupply(token.publicKey, token.signature);
  //   // // Decrypt the total supply
  //   // const totalSupply = this.instances.alice.decrypt(this.contractAddress, encryptedTotalSupply);
  //   // expect(totalSupply).to.equal(1000);
  // });

  // it("should transfer tokens between two users", async function () {
  //   const encryptedAmount = this.instances.alice.encrypt32(10000);
  //   const transaction = await createTransaction(this.contract.mint, encryptedAmount);
  //   await transaction.wait();

  //   const encryptedTransferAmount = this.instances.alice.encrypt32(1337);
  //   const tx = await createTransaction(
  //     this.contract["transfer(address,bytes)"],
  //     this.signers.bob.address,
  //     encryptedTransferAmount,
  //   );
  //   await tx.wait();

  //   const tokenAlice = this.instances.alice.getTokenSignature(this.contractAddress)!;

  //   const encryptedBalanceAlice = await this.contract.balanceOf(tokenAlice.publicKey, tokenAlice.signature);

  //   // Decrypt the balance
  //   const balanceAlice = this.instances.alice.decrypt(this.contractAddress, encryptedBalanceAlice);

  //   expect(balanceAlice).to.equal(10000 - 1337);

  //   const bobErc20 = this.contract.connect(this.signers.bob);

  //   const tokenBob = this.instances.bob.getTokenSignature(this.contractAddress)!;

  //   const encryptedBalanceBob = await bobErc20.balanceOf(tokenBob.publicKey, tokenBob.signature);

  //   // Decrypt the balance
  //   const balanceBob = this.instances.bob.decrypt(this.contractAddress, encryptedBalanceBob);

  //   expect(balanceBob).to.equal(1337);
  // });
});
