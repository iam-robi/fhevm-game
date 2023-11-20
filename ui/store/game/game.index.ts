// following this example https://github.com/productdevbook/oku-nuxt3-template/tree/master/src
import { ethers } from "ethers";
import { defineStore } from "pinia";

// import { bunkerWarZAbi } from "~/abi/BunkerWarZ";
import { GameState } from "./game.types";

export const useGameStore = defineStore("gameStore", {
  state: (): GameState => ({
    gridSizeX: 4,
    gridSizeY: 4,
    playPositionX: 0,
    playPositionY: 0,
    gameContractAddress: "smartcontractaddress",
  }),

  actions: {
    startGame: async function () {
      console.log("startGame");
    },
    playRound: async function () {
      console.log("play round");
    },
  },
  getters: {},
});
