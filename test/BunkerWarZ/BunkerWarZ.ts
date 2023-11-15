import { ethers } from "hardhat";
import { getSigners } from "../signers";

import { shouldBehaveLikeBunkerWarZ } from "./BunkerWarZ.behavior";
import { deployBunkerWarZFixture } from "./BunkerWarZ.fixture";


describe("Unit tests", function () {

  before(async function () {
    this.signers = await getSigners(ethers);
  });

  beforeEach(async function () {
    const contract = await deployBunkerWarZFixture();
    this.contractAddress = await contract.getAddress();
    this.contract = contract;
    this.instances = await createInstances(this.contractAddress, ethers, this.signers);
  });

  describe("BunkerWarZ", function () {
    shouldBehaveLikeBunkerWarZ();
  });

});

// import { ethers } from "hardhat";
// import hre from "hardhat";

// import { waitForBlock } from "../../utils/block";
// import { createFheInstance } from "../../utils/instance";
// import type { Signers } from "../types";
// import { shouldBehaveLikeBunkerWarZ } from "./BunkerWarZ.behavior";
// import { deployBunkerWarZFixture, getTokensFromFaucet } from "./BunkerWarZ.fixture";

//describe("Unit tests", function () {
  // before(async function () {
  //   this.signers = {} as Signers;

  //   // get tokens from faucet if we're on localfhenix and don't have a balance
  //   await getTokensFromFaucet();

  //   // deploy test contract
  //   const { bunkerwarz, address } = await deployBunkerWarZFixture();
  //   this.bunkerwarz = bunkerwarz;

  //   // initiate fhevmjs
  //   this.instance = await createFheInstance(hre, address);

  //   // set admin account/signer
  //   const signers = await ethers.getSigners();
  //   this.signers.admin = signers[0];
  //   this.signers.player1 = signers[0];
  //   this.signers.player2 = signers[1];

  //   // wait for deployment block to finish
  //   await waitForBlock(hre);
  // });
// }
