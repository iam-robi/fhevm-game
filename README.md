# Fhevm game bounty: BunkerWarZ

## install

```bash
pnpm install
```

## compile contract
```bash
pnpm compile
```

## Flatten contract
```bash
cd contracts
./node_modules/.bin/poa-solidity-flattener ./contracts/BunkerWarZ.sol
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