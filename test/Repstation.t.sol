// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Repstation.sol";
import {SchemaRegistry} from "eas/SchemaRegistry.sol";
import {ISchemaResolver} from "eas/resolver/ISchemaResolver.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {RepstationV2Mock} from "./mocks/RepstationV2Mock.sol";
import {EAS, AttestationRequest, AttestationRequestData} from "eas/EAS.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

// A zero expiration represents an non-expiring attestation.
uint64 constant NO_EXPIRATION_TIME = 0;

// struct AttestationRequestData {
//     address recipient; // The recipient of the attestation.
//     uint64 expirationTime; // The time when the attestation expires (Unix timestamp).
//     bool revocable; // Whether the attestation is revocable.
//     bytes32 refUID; // The UID of the related attestation.
//     bytes data; // Custom attestation data.
//     uint256 value; // An explicit ETH amount to send to the resolver. This is important to prevent accidental user errors.
// }

// /**
//  * @dev A struct representing the full arguments of the attestation request.
//  */
// struct AttestationRequest {
//     bytes32 schema; // The unique identifier of the schema.
//     AttestationRequestData data; // The arguments of the attestation request.
// }

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

    // // Users can make attestations
    // function testAttestation() public {
    //     bytes32 uid = registerSchema();

    //     address recipient1 = address(123);
    //     address recipient2 = address(456);

    //     eas.attest(
    //         AttestationRequest({
    //             schema: uid,
    //             data: AttestationRequestData({
    //                 recipient: recipient1,
    //                 expirationTime: NO_EXPIRATION_TIME,
    //                 revocable: false,
    //                 refUID: 0x0,
    //                 data: new bytes(1),
    //                 value: 0
    //             })
    //         })
    //     );

    //     assertEq(repstation.accountInfo(recipient1).rep, MAX_REP - 1);
    //     assertEq(repstation.accountInfo(address(this)).attestationCount, 1);
    // }

    // Correctly calculates decayed rep

    // Returns correct attestationCount

    // Users can't attest if they're not registered

    // Users can't make attestations about themselves

    // Users can't make more than one attestation per target account per month

    // HELPERS
    function registerSchema() internal returns (bytes32) {
        bytes32 uid = registry.register(
            "bool upVote",
            ISchemaResolver(address(repstation)),
            false
        );

        return uid;
    }

    function testMath() public {
        uint256 attestationCount = 15;

        uint256 timeTranspired = 30 days;

        // Attestations per day (fraction scaled to 1e18)
        uint256 attestationsPerDay = FixedPointMathLib.divWad(
            attestationCount,
            timeTranspired
        ) * 1 days;

        // https://www.desmos.com/calculator/3rqdk2k1a6
        uint256 decayRatePerSec = FixedPointMathLib.mulDiv(
            1,
            uint256(
                FixedPointMathLib.powWad(0.5e18, int256(attestationsPerDay))
            ),
            86400
        );

        console.log("decayRatePerSec", uint256(decayRatePerSec));
    }
}
