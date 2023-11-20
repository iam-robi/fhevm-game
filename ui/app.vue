<template>
  <div>
    <Navbar></Navbar>
    <LayoutHeroBanner></LayoutHeroBanner>
    <div class="flex justify-center items-center">
      <div
        class="w-full max-w-2xl flex flex-row space-x-6 p-10 card rounded-box"
      >
        <!-- Input section -->
        <div class="flex flex-col space-y-4 w-1/2">
          <label for="input1" class="text-lg font-bold">Input X: </label>
          <input
            id="input1"
            type="text"
            class="input input-primary"
            placeholder="Enter input X"
            v-model.value="gameStore.playPositionX"
          />

          <label for="input2" class="text-lg font-bold">Input Y:</label>
          <input
            id="input2"
            type="text"
            class="input input-primary"
            placeholder="Enter input Y"
            v-model.value="gameStore.playPositionY"
          />
          <button @click="startGame" class="btn">Start Game</button>
        </div>


      </div>
    </div>
    <NuxtSnackbar />
  </div>
</template>

<script setup>
import Navbar from "./components/layout/Navbar.vue";
import LayoutHeroBanner from "./components/layout/HeroBanner.vue";
import { ref, onMounted, onBeforeUnmount } from "vue";
import { useGameStore } from "/store/game/game.index";
const gameStore = useGameStore();

// const toast = useToast();
// Initialize noir when the component is mounted
const snackbar = useSnackbar();

onMounted(async () => {
  console.log("mounted");
});

onBeforeUnmount(() => {
  console.log("befor unmount");
});

const startGame = async function () {
  console.log("startGame");
};

const play = async function () {
  try {
    await gameStore.play();
    snackbar.add({
      type: "success",
      text: "Your proof was successfully verified on-chain !",
    });
  } catch (err) {
    snackbar.add({
      type: "error",
      text: err,
    });
  }
};
</script>
