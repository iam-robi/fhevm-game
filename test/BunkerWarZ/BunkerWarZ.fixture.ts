import { ethers } from "hardhat";

import type { BunkerWarZ } from "../../types";
import { getSigners } from "../signers";

export async function deployBunkerWarZFixture(): Promise<BunkerWarZ> {
  const signers = await getSigners(ethers);

  const contractFactory = await ethers.getContractFactory("BunkerWarZ");
  const contract = await contractFactory.connect(signers.alice).deploy();
  await contract.waitForDeployment();

  return contract;
}
