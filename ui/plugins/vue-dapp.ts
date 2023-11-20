import { VueDapp } from "vue-dapp";
import { ethers } from "ethers";
export default defineNuxtPlugin((nuxtApp) => {
  nuxtApp.vueApp.use(VueDapp, {
    11155111: {
      chainId: ethers.utils.hexValue(11155111),
      name: "Sepolia",
      rpcUrl: "https://ethereum-sepolia.blockpi.network/v1/rpc/public",
    },
  });
});
