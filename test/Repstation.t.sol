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

    address[] public genesisAccounts = [
        0x5B38Da6a701c568545dCfcB03FcB875f56beddC4,
        0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2,
        0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db,
        0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB
    ];

    function setUp() public {
        registry = new SchemaRegistry();
        eas = new EAS(registry);
        Repstation repstationImp = new Repstation();
        repstation = Repstation(
            payable(new ERC1967Proxy(address(repstationImp), bytes("")))
        );

        repstation.initialize(address(eas), genesisAccounts);
    }

    // Contract can be initialized
    function testInitializes() public {
        Repstation imp = new Repstation();
        Repstation proxy = Repstation(
            payable(new ERC1967Proxy(address(imp), bytes("")))
        );

        proxy.initialize(address(eas), genesisAccounts);

        for (uint256 i = 0; i < genesisAccounts.length; i++) {
            assertEq(repstation.accountInfo(genesisAccounts[i]).rep, MAX_REP);
            assertEq(
                repstation.accountInfo(genesisAccounts[i]).createdAt,
                uint32(block.timestamp)
            );
            assertEq(
                repstation.accountInfo(genesisAccounts[i]).createdAt,
                uint32(block.timestamp)
            );
            assertEq(
                repstation.accountInfo(genesisAccounts[i]).attestationCount,
                0
            );
        }
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
