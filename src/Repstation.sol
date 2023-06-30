// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Attestation} from "eas/IEAS.sol";
import {BaseResolver} from "./BaseResolver.sol";

/**
 * @title Repstation
 * @author @gigamesh
 * @notice An onchain reputation system built as an attestation resolver in the Ethereum Attestation Service
 */
contract Repstation is BaseResolver {
    struct Account {
        uint32 rep;
        uint32 attestationCount;
        uint32 createdAt;
    }

    error AttesterNotRegistered();

    mapping(address => Account) private accounts;

    function onAttest(
        Attestation calldata attestation,
        uint256 /* value */
    ) internal override returns (bool) {
        Account storage attester = accounts[attestation.attester];
        Account storage attested = accounts[attestation.recipient];

        // Only registered attestors can attest
        if (attester.createdAt == 0) {
            revert AttesterNotRegistered();
        }

        // Initialize Account of attested if this is their first attestation
        if (attested.createdAt == 0) {
            attested.createdAt = uint32(block.timestamp);
        }

        // Calculate rep & update Account of attested/recipient
        // uint256 attestorRep = accounts[attestation.attester].rep;

        // Increment attester's attestationCount
        attester.attestationCount = attester.attestationCount + 1;

        return true;
    }

    /**
     * @dev The current rep of an account.
     * @param account The address of the target account.
     */
    function rep(address account) public view returns (uint32) {
        uint256 attestationFrequency = accounts[account].attestationCount /
            (block.timestamp - uint256(accounts[account].createdAt));

        // return accounts[account].rep + uint32(attestationFrequency);
    }
}
