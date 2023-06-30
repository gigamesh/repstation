// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Repstation.sol";
import {SchemaRegistry} from "eas/SchemaRegistry.sol";
import {ISchemaResolver} from "eas/resolver/ISchemaResolver.sol";
import {EAS} from "eas/EAS.sol";

contract RepstationTest is Test {
    EAS public eas;
    SchemaRegistry public registry;
    Repstation public repstation;

    function setUp() public {
        registry = new SchemaRegistry();
        eas = new EAS(registry);
        repstation = new Repstation();

        registry.register(
            "bool approve",
            ISchemaResolver(address(repstation)),
            false
        );
    }

    // Contract can be initialized

    // Returns correct rep for given accounts

    // Returns correct createdAt for given accounts

    // Correctly calculates decayed rep

    // Users can make attestations

    // Returns correct attestationCount

    // Users can't attest if they're not registered

    // Users can't make attestations about themselves
}
