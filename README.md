# Hyperbridge Forged Proof Mint Trap (hoodi)

This repository is part of Operation Flytrap. It is a Drosera-compatible executable PoC for a historical exploit mechanic.

## Drosera MCP Inputs

- `generate-trap` prompt for `HYPERBRIDGE_PROOF_MUST_BIND_REQUEST`
- `drosera://trappers/creating-a-trap`
- `drosera://trappers/dryrunning-a-trap`
- `drosera://trappers/drosera-cli`
- `drosera://operators/executing-traps`
- `drosera://deployments`

## Scope

This repo uses Drosera MCP rules for trap structure:

- `collect()` is `external view`.
- `shouldRespond(bytes[] calldata data)` is `external pure`.
- samples are newest-first.
- `block_sample_size = 4`.
- response payload is ABI-encoded `TrapAlert`.

## Invariant

`HYPERBRIDGE_PROOF_MUST_BIND_REQUEST`

The response contains the invariant id, target, observed value, expected value, block number, and ABI-encoded context.

## Exploit Mechanic

The Hoodi version deploys all protocol mocks and tokens needed to simulate the exploit. The mainnet version contains production-oriented trap and response contracts with placeholder target addresses until authorized mainnet addresses are supplied.

For this trap, the simulated response is: pause handler dispatch, gateway execution, minting, and unauthorized transfer externalization.

## Run Tests

```bash
forge test
```

## Hoodi Notes

This Hoodi simulation includes mocks, token, attacker, trap, response, and local deployment script contracts. Drosera Hoodi network deployment remains pending until official Hoodi Drosera RPC/proxy details are supplied.
