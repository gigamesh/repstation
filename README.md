# Repstation

Repstation is an onchain reputation protocol. Built as a custom [Ethereum Attestation Service](https://attest.sh/) schema resolver, it stores a reputation score for each account that is updated via up/down vote attestations made by other accounts. The system is bootstrapped by a genesis set of trustworthy accounts (ex: [OP Citizen House](https://community.optimism.io/docs/governance/citizens-house/) badgeholders) and the parameters for updating reputation can be adjusted via a governance process. 

It is initially being developed for use with the [Optimism Attestation Station](https://community.optimism.io/docs/identity/atst-v1/), but can be deployed to any chain where EAS has been deployed.

## Rationale
Sybil-resistant reputation systems are a notoriously difficult challenge that developers have been tackling in a multitude of ways for many years. Rather than attempting to be a universal, ungameable solution, Repstation can be thought more as an experiment which leverages existing social capital. It is effectively a DAO whose sole function is to steward the reputation of its members.

A key feature of Repstation is any social group can come together to deploy their own instance with any set of parameters for calculating reputation. This allows for natural selection to determine the strongest communities. If any grow large enough, it is conceivable network effects will take hold as other protocols will find value in leveraging the reputation signal attached to its members. 

Membership in Repstation is more accessible and fluid than a traditional DAO. It doesn't require buying a token or a vote by existing members. It just requires you know an existing member who thinks you're worthy of a positive attestation.

## Overview
- Rep ranges between 0 and 1000.
- An initial set of accounts are given 1000 rep.
- Rep decays over time. To incentivize active participation, the decay rate decreases the more freqently an account makes attestations.
- Attestations are a simple up or down vote on any target account.
- Rep increases from receiving positive attestations, scaled by the rep of the attester.
- Rep decreases from receiving negative attestations, scaled by the rep of the attester.

## Contracts

### Repstation.sol

- Upgradeable reputation registry
- Is implemented as an [EAS resolver](https://docs.attest.sh/docs/tutorials/resolver-contracts)
- Validates attestation, calculates & updates attestation target's rep

### RepstationGov.sol
- Owner of Repstation.sol
- Vote weight is scaled by rep
- Anyone with rep can make a proposal, but a quorum of TBD% of accounts is required to vote in order for the election to be considered valid.

## Roadmap
- [ ] Contracts & tests
- [ ] Agent modeling to determine optimal parameters
- [ ] [Frontend](https://github.com/gigamesh/ourspace) that enables users to flex their social capital.
- [ ] Deploy to Optimism goerli.
- [ ] Deploy to mainnet (after [AttestationStation V1](https://community.optimism.io/docs/identity/atst-v1/) is deployed on mainnet).
- [ ] Add governance to frontend.
- [ ] Frontend for deploying new instances of Repstation.

## Questions:
- Should the quorum threshold be adjustable by governance?
- Should rep be transferable? 
- Can reputation be shared across multiple chains?
