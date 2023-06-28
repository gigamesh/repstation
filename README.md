# Repstation

Repstation is an onchain reputation protocol. Built as a custom [Ethereum Attestation Service](https://attest.sh/) schema resolver, it stores a reputation score ("rep") for each account that is updated via up/down vote attestations made by other accounts. 

The system is bootstrapped by a genesis set of users who are trusted to only control one account in the genesis set of accounts (ex: [OP Citizen House](https://community.optimism.io/docs/governance/citizens-house/) badgeholders). To incentivize participation and limit sybil attacks, rep decays over time at a rate determined by how often an account makes attestations. The parameters for calculating rep can be changed via a governance process, with voting power scaled by each voter's rep. 

It is initially being developed for use with the [Optimism Attestation Station](https://community.optimism.io/docs/identity/atst-v1/), but can be deployed to any chain where EAS has been deployed.

## Rationale
Sybil-resistant, decentralized reputation systems are a notoriously difficult challenge. Rather than attempting to be a perfect solution, Repstation can be thought more as an experiment which leverages existing social capital to boostrap a reputation network onchain. It is effectively a DAO whose sole function is to steward the reputation of its members.

Membership in Repstation is more accessible and fluid than a traditional DAO. It doesn't require buying a token or a vote by existing members. It just requires you know an existing member who thinks you're worthy of a positive attestation.

Another key feature of Repstation is any social group can come together to deploy their own instance with any set of parameters for calculating reputation. This allows for natural selection to determine the strongest communities. So governance can happen through voice or exit. If any Repstation instance grows large enough, it is conceivable network effects will take hold as other protocols will find value in leveraging the reputation signal attached to its members. 

## Overview
- Rep ranges between 0 and 1000 (capped to prevent infinite inflation)
- An initial set of accounts are given 1000 rep.
- Rep decays at a default rate of 1% per day, but the [decay rate decreases exponentially](https://www.desmos.com/calculator/05ddk3db3b) the more freqently an account is making attestations.
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
- [ ] Repstation.sol & tests
- [ ] Agent modeling to determine optimal parameters
- [ ] [Frontend](https://github.com/gigamesh/ourspace) that enables users to flex their social capital.
- [ ] Deploy to Optimism goerli.
- [ ] Deploy to mainnet (after [AttestationStation V1](https://community.optimism.io/docs/identity/atst-v1/) is deployed on mainnet).
- [ ] RepstationGov.sol & tests
- [ ] Add governance to frontend.

## Questions:
- Should the quorum threshold be adjustable by governance?
- Should rep be transferable? 
- Can reputation be shared across multiple chains?
