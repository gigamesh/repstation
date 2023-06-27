# Repstation

Repstation is a simple onchain reputation protocol. Built as a custom [Ethereum Attestation Service](https://attest.sh/) schema resolver, it stores a reputation score for each account that is updated via up/down vote attestations made by other accounts. The system is bootstrapped by a genesis set of accounts and the parameters for updating reputation can be adjusted via a governance process. 

It will initially be developed for use with the [Optimism Attestation Station](https://community.optimism.io/docs/identity/atst-v1/), but can be deployed to any chain where EAS has been deployed.

## Rationale
Sybil-resistant reputation systems are a notoriously difficult challenge that developers have been tackling in a multitude of ways for many years. Rather than attempting to be a universal, ungameable solution, Repstation can be thought more as an experiment which leverages existing social relationships. It is effectively a DAO whose primary function is to provide quantified social capital.

A key feature of Repstation is any social group can come together to deploy their own instance with any set of parameters for calculating reputation. This allows for natural selection to determine the strongest communities. If any grow large enough, it is conceivable network effects will take hold as other protocols will find value in leveraging the reputation signal attached to its members. 

Membership in Repstation is more accessible and fluid than a traditional DAO. It doesn't require buying a token or a vote by existing members. It just requires you know an existing member who thinks you're worthy of a positive attestation.

## Overview

- A set of genesis accounts are each assigned a reputation score (`rep`).
- Attestations can be made by a simple up or down vote on any target account.
- When an account is initialized, the time is recorded.
- Rep decays over time, and the decay rate increases as the account ages.
- Rep increases from receiving positive attestations, scaled by the rep of the attester.
- Rep decreases from receiving negative attestations, scaled by the rep of the attester.
- Rep cannot go below zero.

## Contracts

### Repstation.sol

- Upgradeable reputation registry
- Is implemented as an [EAS resolver](https://docs.attest.sh/docs/tutorials/resolver-contracts)
- Validates attestation, calculates & updates attestation target's rep

### RepstationGov.sol
- Owner of Repstation.sol
- Only accounts with rep can vote
- Uses quadratic voting to counterbalance older accounts having more rep than newer accounts
- Anyone with rep can make a proposal, but proposals require a quorum of TBD% accounts to vote in order for the election to be considered valid.

## Roadmap
1. Write contracts & tests
2. Build [frontend](https://github.com/gigamesh/ourspace) that demonstrates Repstation's features.
3. Assemble initial community of genesis accounts.
4. Deploy to Optimism goerli.
5. Deploy to mainnet (after [AttestationStation V1](https://community.optimism.io/docs/identity/atst-v1/) is deployed on mainnet).

## Questions:

- Do the initial parameters for calculating rep comport with prevailing knowledge of reputation systems (ex: EigenTrust)?
- Should the quorum threshold be adjustable by governance?
- Should Repstation.sol be immutable?
- Should rep be transferable? 
- Other sybil attack vectors?
- Can reputation be shared across multiple chains?
