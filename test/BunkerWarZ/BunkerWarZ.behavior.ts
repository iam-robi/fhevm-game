import { expect } from "chai";
import hre from "hardhat";

//import { waitForBlock } from "../../utils/block";

export function shouldBehaveLikeBunkerWarZ(): void {

  it("should allow to create games", async function () {
    await this.contract.connect(this.instances.alice).new_game(3,5,this.signers.player1.address, this.signers.player2.address);
    await this.contract.connect(this.instances.alice).new_game(5,8,this.signers.player1.address, this.signers.player2.address);
  });

  it("should allow to build something", async function () {

    await this.contract.connect(this.signers.alice).new_game(3,5,this.signers.player1.address,this.signers.player2.address);

    const building_type_minus_1 = this.signers.player1.encrypt32(0)
    await this.contract.connect(this.signers.player1).build(0,0,building_type_minus_1);
    //await waitForBlock(hre);

    const currentPlayer = await this.contract.currentPlayer();
    expect(currentPlayer).to.equal(this.signers.player2);
  });

  // const encryptedAmount = this.instances.alice.encrypt32(1000);
  // const transaction = await createTransaction(this.erc20.mint, encryptedAmount);
  // await transaction.wait();
  // // Call the method
  // const token = this.instances.alice.getTokenSignature(this.contractAddress) || {
  //   signature: "",
  //   publicKey: "",
  // };
  // const encryptedBalance = await this.erc20.balanceOf(token.publicKey, token.signature);
  // // Decrypt the balance
  // const balance = this.instances.alice.decrypt(this.contractAddress, encryptedBalance);
  // expect(balance).to.equal(1000);

  // const encryptedTotalSupply = await this.erc20.getTotalSupply(token.publicKey, token.signature);
  // // Decrypt the total supply
  // const totalSupply = this.instances.alice.decrypt(this.contractAddress, encryptedTotalSupply);
  // expect(totalSupply).to.equal(1000);


  // it("should fail when trying to build something on top of something else", async function () {
  //   const building_type_minus_1 = this.instance.instance.encrypt32(0,0)

  //   await this.contract.connect(this.signers.player1).placeShips(0,0,building_type_minus_1);
  //   await waitForBlock(hre);

  //   let currentPlayer = await this.contract.currentPlayer();
  //   expect(currentPlayer).to.equal(this.signers.player2);    

  //   await this.contract.connect(this.signers.player2).placeShips(0,0,building_type_minus_1);
  //   await waitForBlock(hre);

  //   currentPlayer = await this.contract.currentPlayer();
  //   expect(currentPlayer).to.equal(this.signers.player1);    

  //   await this.contract.connect(this.signers.player1).placeShips(0,0,building_type_minus_1);
  //   await waitForBlock(hre);        

  //   // still player 1 turn mean the txn failed
  //   currentPlayer = await this.contract.currentPlayer();
  //   expect(currentPlayer).to.equal(this.signers.player1);
  // });

  // it("should place ships and check game readiness", async function () {
  //   const encodedPlacement = "0101000000010111";
  //   const shipPlacement = this.instance.instance.encrypt32(parseInt(encodedPlacement, 2))

  //   await this.contract.connect(this.signers.player1).placeShips(shipPlacement);
  //   await this.contract.connect(this.signers.player2).placeShips(shipPlacement);
  //   await waitForBlock(hre);

  //   const player1Ready = await this.contract.player1Ready();
  //   const player2Ready = await this.contract.player2Ready();
  //   const gameReady = await this.contract.gameReady();
  //   await waitForBlock(hre);

  //   expect(player1Ready).to.equal(true);
  //   console.log({
  //     player1Ready,
  //     player2Ready,
  //     gameReady
  //   })
  //   expect(player2Ready).to.equal(true);
  // });
}