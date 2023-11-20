<template>
  <div>
    <button @click="onConnect" class="btn">Connect</button>
    {{ wallet.wallet.status }} - {{ address }}
    <vd-board :connectors="connectors" dark>
      <!-- <template #loading>
          <div v-if="wallet.wallet.status === 'loading'">loading...</div>
        </template> -->
    </vd-board>
  </div>
</template>
<script setup lang="ts">
import {
  MetaMaskConnector,
  WalletConnectConnector,
  CoinbaseWalletConnector,
  useBoard,
  useEthers,
  useWallet,
} from "vue-dapp";

const wallet = useWallet();
const board = useBoard();
const { address, chainId, signer } = useEthers();

// board.open();
const onConnect = function () {
  console.log("connect");
  board.open();
};

const connectors = [
  new MetaMaskConnector({
    appUrl: "http://localhost:3000",
  }),
  new WalletConnectConnector({
    qrcode: true,
    rpc: {
      1: `https://eth.llamarpc.com`,
      5: `https://eth-goerli.g.alchemy.com/v2/mb4872MrLwfUdJfLcYfkXKhvsZo3PJsh`,
    },
  }),
  new CoinbaseWalletConnector({
    appName: "Vue Dapp",
    jsonRpcUrl: `https://eth-goerli.g.alchemy.com/v2/mb4872MrLwfUdJfLcYfkXKhvsZo3PJsh`,
  }),
  // new SafeConnector(),
];
</script>
