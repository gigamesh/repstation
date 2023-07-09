# Repstation

Repstation is an onchain reputation protocol. Built as a custom [Ethereum Attestation Service](https://attest.sh/) schema resolver, it stores a reputation score ("rep") for each account that is updated via up or down vote attestations made by other accounts. 

The system is bootstrapped by a reputable set of unique account owners (ex: [OP Citizen House](https://community.optimism.io/docs/governance/citizens-house/) badgeholders). To incentivize participation and limit sybil attacks, rep decays over time at a rate determined by how often an account makes attestations. The parameters for calculating rep can be changed via a governance process, with voting power scaled by each voter's rep. 

It is initially being developed for use with the [Optimism Attestation Station](https://community.optimism.io/docs/identity/atst-v1/), but can be deployed to any chain where EAS has been deployed.

## Rationale
Sybil-resistant reputation protocols are a notoriously difficult challenge. Historically, the most successful approaches have managed it off chain via a trusted, centralized 3rd party (ex: [Gitcoin Passport](https://passport.gitcoin.co/)). More recently, zk circuits are being used to validate claims produced by trusted off-chain entities (ex: [Clique](https://clique.social/)). A problem with both approaches is the reputation of each account is only as good as the latest snapshot, and they rely on centralized authorities (ex: Google, Github, Twitter, etc).

Repstation's approach is to leverage existing social capital to bootstrap a reputation network onchain. It is effectively a DAO whose sole function is to steward the reputation of its members.

Key features:
- Unlike traditional DAOs, membership doesn't require buying a token or a vote by existing members. It only requires you know an existing member who thinks you're worthy of an up vote (positive attestation).
- Any social group can deploy their own instance of Repstation with any set of initial parameters for calculating rep. This allows for natural selection to determine the strongest communities. If any Repstation instance grows large enough, it is conceivable network effects will take hold as other protocols will find value in leveraging the reputation of its members. And if any conflicts arise, the community can always fork the protocol and start anew.

## Overview
*Parameters below are provisional. Final values will be ideally determined by agent modeling.*
- Rep ranges between 0 and 1000 (capped to prevent infinite inflation)
- The set of genesis accounts start with 1000 rep.
- Rep decays at a default rate of 1% per day, but the [decay rate decreases exponentially](https://www.desmos.com/calculator/05ddk3db3b) the more freqently an account is making attestations.
- Attestations are a simple up or down vote on any target account.
- Rep increases from receiving positive attestations, scaled by the rep of the attester.
- Rep decreases from receiving negative attestations, scaled by the rep of the attester.
- Rep holders can't make attestations about their own address.
- Rep holders can't make more than one attestation per month about the same account.

## Contracts

### Repstation.sol

- Upgradeable reputation registry
- Is implemented as an [EAS resolver](https://docs.attest.sh/docs/tutorials/resolver-contracts)
- Validates attestation, calculates & updates attestation target's rep

### RepstationGov.sol
- Owner of Repstation.sol
- Implementation of [OpenZeppelin Governor](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/governance/Governor.sol) for compatibility with existing tooling & UIs (subject to change)
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

---
## R&D:
- Should the quorum threshold be adjustable by governance?
- Is there a way to make rep transferable (e.g. in the event that a member's wallet is compromised) in a way that doesn't encourage purchasing of rep & sybil attacks?
- Can Repstation be multichain?
- Ideally, attestations would be private so users aren't discouraged from making negative attestations. A possible way achieving this might bre to use a trusted relayer that accepts attestations and submits them to the chain in batches, hiding the identity of the attester. This would require a way to verify the relayer is not submitting false attestations.
