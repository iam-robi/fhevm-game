import { defineNuxtPlugin } from "#app";
import { ethers } from "ethers";

export default defineNuxtPlugin((nuxtApp) => {
  nuxtApp.provide("ethers", ethers);
});
