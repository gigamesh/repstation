// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IEAS, Attestation} from "eas/IEAS.sol";
import {BaseResolver} from "./BaseResolver.sol";

/**
 * @title Repstation
 * @author @gigamesh
 * @notice An onchain reputation system built as an attestation resolver in the Ethereum Attestation Service
 */
contract Repstation is BaseResolver {
    struct Account {
        uint256 rep;
        uint32 createdAt;
    }

    bytes32 public attestationSchemaId;

    mapping(address => Account) public accounts;

    function initialize(address _eas, bytes32 _attestationSchemaId) public {
        _initialize(_eas);

        attestationSchemaId = _attestationSchemaId;
    }

    function onAttest(
        Attestation calldata attestation,
        uint256 value
    ) internal override returns (bool) {
        /* TODO: 
            - Calculate rep & update Account of attester/sender 
            - Calculate rep & update Account of attested/recipient
        */
    }

    function onRevoke(
        Attestation calldata attestation,
        uint256 value
    ) internal override returns (bool) {
        // TODO
    }

    function updateSchema(bytes32 _attestationSchemaId) public onlyOwner {
        attestationSchemaId = _attestationSchemaId;
    }
}
