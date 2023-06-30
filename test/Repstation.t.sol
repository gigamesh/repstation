// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Repstation.sol";
import {SchemaRegistry} from "eas/SchemaRegistry.sol";
import {ISchemaResolver} from "eas/resolver/ISchemaResolver.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {RepstationV2Mock} from "./mocks/RepstationV2Mock.sol";
import {EAS} from "eas/EAS.sol";

contract RepstationTest is Test {
    EAS public eas;
    SchemaRegistry public registry;
    Repstation public repstation;

    uint256 constant MAX_REP = 1000e18;

    function setUp() public {
        registry = new SchemaRegistry();
        eas = new EAS(registry);
        Repstation repstationImp = new Repstation();
        repstation = Repstation(
            payable(new ERC1967Proxy(address(repstationImp), bytes("")))
        );

        repstation.initialize(address(eas));
    }

    // Contract can be initialized
    function testInitializes() public {
        Repstation imp = new Repstation();
        Repstation proxy = Repstation(
            payable(new ERC1967Proxy(address(imp), bytes("")))
        );

        proxy.initialize(address(eas));
    }

    // Contract can be upgraded
    function testUpgrade() public {
        RepstationV2Mock v2Mock = new RepstationV2Mock();

        // vm.prank();
        repstation.upgradeTo(address(v2Mock));

        assert(RepstationV2Mock(address(repstation)).someNewFunction() == 1);
    }

    // Can register with schema
    function testRegister() public {
        bytes32 uid = registerSchema();

        assertEq(uid, registry.getSchema(uid).uid);
    }

    // Initializes accounts with max rep
    function testRepInitialization() public {
        registerSchema();

        // assertEq(repstation.getRep(address(this), uid), MAX_REP);
    }

    // Returns correct rep for given accounts

    // Returns correct createdAt for given accounts

    // Correctly calculates decayed rep

    // Users can make attestations

    // Returns correct attestationCount

    // Users can't attest if they're not registered

    // Users can't make attestations about themselves

    // Users can't make more than one attestation per target account per month

    // HELPERS
    function registerSchema() internal returns (bytes32) {
        bytes32 uid = registry.register(
            "bool approve",
            ISchemaResolver(address(repstation)),
            false
        );

        return uid;
    }
}
