# Repstation

*Repstation is currently a work-in-progress prototype. Ideas for improving it are welcome via issues or pull requests.*

Repstation is a generalized onchain reputation protocol. Built as a custom [Ethereum Attestation Service](https://attest.sh/) schema resolver, it stores a reputation score for each account which can be referenced by any smart contract. The parameters for calculating reputation are configurable by governance.

## Rationale
Onchain sybil-resistant, gas-efficient reputation systems are a notoriously difficult challenge that developers have been trying to solve for many years. The protocols with arguably the most success have historically opted to use offchain, centralized & trusted solutions (ex: [Gitcoin Passport](https://passport.gitcoin.co/)). 

More recently, validity proofs are being adopted as a way of securely proving claims about offchain data that protects the identity of the user (ex: [Clique](https://clique.social/)). However, if we assuming the zk circuits are sound, these systems are still limited in that each account's reputation is only as reliable as the latest snapshot of offchain data. In other words, they don't provide real-time reputation.

Repstation doesn't claim to solve all problems, but rather approach the challenge with in same spirit as EAS by providing a simple building block. It is initially being developed for use with the [Optimism Attestation Station](https://community.optimism.io/docs/identity/atst-v1/), but can be deployed to any chain where EAS has been deployed.

## Overview

- Each account is assigned a reputation score (hereon referred to as ”rep”)
- Each attestation is simply positive or negative (up or down vote)
- When an account’s rep is initialized, the time is recorded so the age of each account can be used for rep calculations.
- Making any attestation increases the attester’s rep, scaled by the age of the attestation target account
- Rep increases from receiving positive attestations, scaled by the rep of the attester
- Rep decreases from receiving negative attestations, scaled by the rep of the attester
- Frontend demo app ("[OurSpace](https://github.com/gigamesh/ourspace)")

## Contracts

### Repstation.sol

- Upgradeable reputation registry
- Is implemented as an [EAS resolver](https://docs.attest.sh/docs/tutorials/resolver-contracts)
- Validates attestation, calculates & updates attestation target's rep

### RepstationGov.sol
- Owner of Repstation.sol
- Only accounts with rep can vote
- Uses a quadratic voting system to counterbalance older accounts having more rep than newer accounts
- Anyone with rep can make a proposal, but proposals require a quorum of TBD% accounts to vote in order for the election to be considered valid.

## Questions:

- Do the initial parameters for calculating rep comport with prevailing knowledge of reputation systems (ex: EigenTrust)?
- Should the quorum threshold be adjustable by governance?
- Should Repstation.sol be immutable?
- Other sybil attack vectors?
- Can reputation be shared across multiple chains?
