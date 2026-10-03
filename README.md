# F3 Perp — public contracts

Part of the F3 perpetual DEX, published for the hackathon. The trading engine and the vault stay private;
this repository holds the pieces around them: the price oracle verifier, the rewards distributor,
the testnet faucet token and the shared math library.

Solidity `0.8.30`, EVM `cancun`, `via_ir`, OpenZeppelin Contracts v5.

## Contracts

| File | What it does |
|---|---|
| `OracleVerifier.sol` | Verifies off-chain signed price reports (EIP-712, domain `F3Perp` / `1`) against an M-of-N signer set, with an optional Chainlink-style reference feed per market |
| `RewardsDistributor.sol` | Merkle-root rewards: cumulative claims per token, timelocked roots with a guardian veto |
| `FaucetToken.sol` | Testnet ERC-20 with `permit`: anyone mints up to `MAX_MINT` once a day, the deployer without a cooldown |
| `libraries/PerpMath.sol` | Perp math shared with the engine: price impact (VPI), margin checks, USD ↔ collateral conversion |
| `libraries/PerpTypes.sol` | Shared structs, constants (`WAD = 1e18`) and errors |
| `interfaces/` | `IOracleVerifier`, `IAggregatorV3` |

## OracleVerifier

A price reaches the chain as a `PriceReport` signed by the oracle nodes:

```
PriceReport(uint32 marketId,uint256 price,uint256 confidence,uint64 timestamp,uint8 status,uint64 pauseAt,uint64 unpauseAt)
```

`verify(report, sigs)` reverts unless all of these hold:

- the market status is trading and the price is non-zero;
- at least `threshold` signatures (minimum 2, up to 16 signers) come from active signers, sorted by
  signer address ascending, with no duplicates;
- if the market has a reference feed: the feed answer is fresh (within `heartbeat`) and the report price
  deviates from it by at most `maxDeviation` (WAD-scaled). With `requireReference = true`, a missing or
  stale feed is an error; otherwise the check is skipped.

`reportHash(report)` returns the EIP-712 digest to sign. The admin manages signers, the threshold and the
reference feeds.

## RewardsDistributor

1. `ROOT_SETTER_ROLE` calls `proposeRoot(token, root, epoch, total)`; epochs strictly increase.
2. During `ROOT_DELAY` (1 hour to 30 days), `GUARDIAN_ROLE` can `vetoRoot`.
3. After the delay, anyone calls `activateRoot`. It succeeds only when the contract holds enough tokens
   to cover `total`.
4. Users call `claim(token, account, cumulativeAmount, proof)` and receive `cumulativeAmount - claimed`.

Leaf: `leaf(account, token, cumulativeAmount)`. The guardian can pause claims; only the admin unpauses.

## PerpMath

All amounts are integers, computed with `Math.mulDiv` and an explicit rounding direction; rounding always
favours the protocol.

- `vpi`: price impact = `max(vpiSpread, confidence / price) + vpiCoef · size / depth`, with separate
  long and short depth.
- `withinInitialMargin`: checks equity against `notional / maxLeverage`.
- `toUsd`, `toToken`, `toTokenSigned`, `marginUsd`: convert between collateral and USD at the collateral
  price, with a haircut applied to margin.

## Build

The imports expect OpenZeppelin at `@openzeppelin/contracts/`:

```bash
forge init --no-git . && forge install OpenZeppelin/openzeppelin-contracts
echo '@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/' > remappings.txt
forge build
```
