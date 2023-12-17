# Fhevm game bounty: "Bunker War Z" smart contract

## install

```bash
pnpm install
```

## compile contract
```bash
pnpm compile
```

## test contract
In a terminal run: 
```bash
pnpm fhevm:start 
```

Keep the terminal open, and run in another one:
```bash
pnpm test
```

If the signers lack tokens, run:
```bash
pnpm run fhevm:faucet
```