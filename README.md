# Repstation

Repstation is a generalized onchain reputation protocol. Built as a thin contract layer on the [Ethereum Attestation Service](https://attest.sh/) (aka [Attestation Station](https://community.optimism.io/docs/identity/atst-v1/) on Optimism), it is a self-governing system that stores a simple reputation score for each account which can be referenced by any smart contract.

*Repstation is currently a work-in-progress prototype. Ideas for improving it are welcome via issues or pull requests.*

## Overview

- Each account is assigned a reputation score (hereon referred to as ”rep”)
- Each attestation is simply positive or negative (up or down vote)
- When an account’s rep is initialized, the time is recorded so the age of each account can be used for rep calculations.
- Making any attestation increases the attester’s rep, scaled by the age of the attestation target account
- Rep increases from receiving positive attestations, scaled by the rep of the attester
- Rep decreases from receiving negative attestations, scaled by the rep of the attester
- Frontend app ("[OurSpace](https://github.com/gigamesh/ourspace)")

## Contracts

### Repstation.sol

- Upgradeable reputation registry
- Accepts attestations, calculates rep, and passes the attestations to the EAS

### RepstationGov.sol
*This is a proposed governance design. V1 of Repstation will likely have no decentralized governance.*
- Owner of Repstation.sol
- Only accounts with rep can vote
- Uses a quadratic voting system to counterbalance older accounts having more rep than newer accounts
- Anyone with rep can make a proposal, but proposals require a quorum of TBD% accounts to vote in order for the election to be considered valid.

## Questions:

- Do the initial parameters for calculating rep comport with prevailing knowledge of reputation systems (ex: EigenTrust)?
- Should the quorum threshold be adjustable by governance?
- Should Repstation.sol be immutable?
- Other sybil attack vectors?
