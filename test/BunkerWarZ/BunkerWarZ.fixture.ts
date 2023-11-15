import axios from "axios";
import { ethers } from "hardhat";
import hre from "hardhat";

import type { BunkerWarZ } from "../../types/contracts/BunkerWarZ";
import { waitForBlock } from "../../utils/block";

export async function deployBunkerWarZFixture(): Promise<{ bunkerwarz: BunkerWarZ; address: string }> {
  const signers = await ethers.getSigners();
  const admin = signers[0];
  const bunkerwarzFactory = await ethers.getContractFactory("BunkerWarZ");
  const bunkerwarz = await bunkerwarzFactory.connect(admin).deploy();
  const address = await bunkerwarz.getAddress();
  return { bunkerwarz, address };
}

export async function getTokensFromFaucet() {
  if (hre.network.name === "localfhenix") {
    const signers = await hre.ethers.getSigners();

    if ((await hre.ethers.provider.getBalance(signers[0].address)).toString() === "0") {
      console.log("Balance for signer is 0 - getting tokens from faucet");
      await axios.get(`http://localhost:6000/faucet?address=${signers[0].address}`);
      await waitForBlock(hre);
    }

    if ((await hre.ethers.provider.getBalance(signers[1].address)).toString() === "0") {
      console.log("Balance for signer is 0 - getting tokens from faucet");
      await axios.get(`http://localhost:6000/faucet?address=${signers[1].address}`);
      await waitForBlock(hre);
    }
  }
}