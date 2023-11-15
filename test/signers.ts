import type { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/dist/src/signer-with-address";

export interface Signers {
  player1: SignerWithAddress;
  player2: SignerWithAddress;
  carol: SignerWithAddress;
  dave: SignerWithAddress;
  alice: SignerWithAddress;
  bob: SignerWithAddress;
}

export const getSigners = async (ethers: any): Promise<Signers> => {
  const signers = await ethers.getSigners();
  return {
    player1: signers[0],
    player2: signers[1],
    carol: signers[2],
    dave: signers[3],
    alice: signers[4],
    bob: signers[5],
  };
};
