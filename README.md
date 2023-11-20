# Fhevm game bounty: BunkerWarZ

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

If the signers lack tokens, run:

```bash
pnpm run fhevm:faucet
```

Keep the terminal open, and run in another one:

```bash
pnpm test
```
