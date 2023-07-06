// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Repstation.sol";
import {sd} from "@prb/math/SD59x18.sol";
import {intoInt256} from "@prb/math/sd59x18/Casting.sol";
import {SchemaRegistry} from "eas/SchemaRegistry.sol";
import {ISchemaResolver} from "eas/resolver/ISchemaResolver.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {RepstationV2Mock} from "./mocks/RepstationV2Mock.sol";
import {EAS, AttestationRequest, AttestationRequestData} from "eas/EAS.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

// A zero expiration represents an non-expiring attestation.
uint64 constant NO_EXPIRATION_TIME = 0;

contract RepstationTest is Test {
    EAS public eas;
    SchemaRegistry public registry;
    Repstation public repstation;
    bytes32 public schemaUid;

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

    // Attestation timestamp is recorded
    function testLastAttestationGivenAt() public {
        bytes32 uid = registerSchema();

        address recipient = address(123);

        vm.warp(1 days);

        vm.prank(genesisAccounts[0]);
        eas.attest(
            AttestationRequest({
                schema: uid,
                data: AttestationRequestData({
                    recipient: recipient,
                    expirationTime: NO_EXPIRATION_TIME,
                    revocable: false,
                    refUID: 0x0,
                    data: new bytes(1),
                    value: 0
                })
            })
        );

        assertEq(
            repstation.accountInfo(genesisAccounts[0]).lastAttestationGivenAt,
            uint32(block.timestamp)
        );
    }

    // Correctly calculates decayed rep
    function testDecayedRep() public {
        uint256 initialRep = repstation.accountInfo(genesisAccounts[0]).rep;
        uint256 createdAt = repstation
            .accountInfo(genesisAccounts[0])
            .createdAt;
        assertEq(initialRep, MAX_REP);

        vm.warp(createdAt + 1 days);

        uint256 decayedRep = repstation.rep(genesisAccounts[0]);

        // After 1 day, 1% of rep is decayed
        assertEq(decayedRep, 990049833177087907000);

        vm.warp(createdAt + 10 days);

        decayedRep = repstation.rep(genesisAccounts[0]);

        // After 10 days, rep has decayed to ~90.5
        assertEq(decayedRep, 904837412807540732000);

        vm.warp(createdAt + 500 days);

        decayedRep = repstation.rep(genesisAccounts[0]);

        // After 500 days, rep has decayed to ~6.7
        assertEq(decayedRep, 6737945052392980000);
    }

    // TODO: Correctly calculates rep increase from positive attestions
    function testPositiveAttest() public {
        bytes32 uid = registerSchema();

        vm.warp(1 days);

        vm.prank(genesisAccounts[0]);
        eas.attest(
            AttestationRequest({
                schema: uid,
                data: AttestationRequestData({
                    recipient: genesisAccounts[1],
                    expirationTime: NO_EXPIRATION_TIME,
                    revocable: false,
                    refUID: 0x0,
                    data: new bytes(1),
                    value: 0
                })
            })
        );

        uint256 rep = repstation.rep(genesisAccounts[0]);

        assertEq(rep, 1000000000000000000000);
    }

    // TODO: Correcting calculates rep decrease from negative attestations

    // Returns correct attestationCount
    function testAttestationCount() public {
        bytes32 uid = registerSchema();

        vm.warp(1 days);

        for (uint256 i; i < 69; i++) {
            vm.prank(genesisAccounts[0]);
            eas.attest(
                AttestationRequest({
                    schema: uid,
                    data: AttestationRequestData({
                        recipient: vm.addr(i + 1),
                        expirationTime: NO_EXPIRATION_TIME,
                        revocable: false,
                        refUID: 0x0,
                        data: new bytes(1),
                        value: 0
                    })
                })
            );
        }

        assertEq(
            repstation.accountInfo(genesisAccounts[0]).attestationCount,
            69
        );
    }

    function testDecayRatePerSec() public {
        // This test will fail if we check in the genesis block, because a denominator will be zero
        vm.warp(block.timestamp + 1);

        uint256 decayRatePerSec = repstation.repDecayRatePerSec(
            genesisAccounts[0]
        );

        /**
         * Default decay rate == 1% per day, or 1.1574074074e-7 per second (0.01 / 86400)
         * https://www.desmos.com/calculator/3rqdk2k1a6
         */
        assertEq(decayRatePerSec, 115740740740);

        bytes32 uid = registerSchema();

        vm.warp(block.timestamp + 1 days);

        vm.prank(genesisAccounts[0]);
        eas.attest(
            AttestationRequest({
                schema: uid,
                data: AttestationRequestData({
                    recipient: address(123),
                    expirationTime: NO_EXPIRATION_TIME,
                    revocable: false,
                    refUID: 0x0,
                    data: new bytes(1),
                    value: 0
                })
            })
        );

        decayRatePerSec = repstation.repDecayRatePerSec(genesisAccounts[0]);

        /**
         * User now has 1 attestation per day, which means their decay rate
         * should be 0.5% per day, or 5.787037037e-8 per second (0.005 / 86400)
         */
        // TODO: Investigate how to reconfigure math in repDecayRatePerSec to reduce precision loss
        assertEq(decayRatePerSec, 57870834634);

        vm.prank(genesisAccounts[0]);
        eas.attest(
            AttestationRequest({
                schema: uid,
                data: AttestationRequestData({
                    recipient: address(456),
                    expirationTime: NO_EXPIRATION_TIME,
                    revocable: false,
                    refUID: 0x0,
                    data: new bytes(1),
                    value: 0
                })
            })
        );

        decayRatePerSec = repstation.repDecayRatePerSec(genesisAccounts[0]);

        /**
         * User now has 2 attestation per day, which means their decay rate
         * should be 0.25% per day, or 2.8935185185e-8 per second (0.0025 / 86400)
         */
        // TODO: Investigate how to reconfigure math in repDecayRatePerSec to reduce precision loss
        assertEq(decayRatePerSec, 28935649450);
    }

    /*************************************
                    REVERTS 
     ************************************/

    // TODO: Test revert if attestation data is malformed
    function testRevertInvalidData() public {}

    // Users can't attest if they don't have rep
    function testRevertAttesterHasNoRep() public {
        bytes32 uid = registerSchema();

        vm.warp(1 days);

        address attester = address(69);

        vm.prank(attester);
        vm.expectRevert(
            abi.encodeWithSelector(
                Repstation.AttesterHasNoRep.selector,
                attester
            )
        );

        eas.attest(
            AttestationRequest({
                schema: uid,
                data: AttestationRequestData({
                    recipient: vm.addr(1),
                    expirationTime: NO_EXPIRATION_TIME,
                    revocable: false,
                    refUID: 0x0,
                    data: new bytes(1),
                    value: 0
                })
            })
        );

        assertEq(
            repstation.accountInfo(genesisAccounts[0]).attestationCount,
            0
        );
    }

    // Test users can't make attestations about themselves
    function testRevertNoSelfAttestation() public {
        bytes32 uid = registerSchema();

        vm.warp(1 days);

        vm.prank(genesisAccounts[0]);
        vm.expectRevert(Repstation.NoSelfAttestation.selector);

        eas.attest(
            AttestationRequest({
                schema: uid,
                data: AttestationRequestData({
                    recipient: genesisAccounts[0],
                    expirationTime: NO_EXPIRATION_TIME,
                    revocable: false,
                    refUID: 0x0,
                    data: new bytes(1),
                    value: 0
                })
            })
        );

        assertEq(
            repstation.accountInfo(genesisAccounts[0]).attestationCount,
            0
        );
    }

    // Users can't make more than one attestation per target account per month
    function testRevertRecipientRateLimit() public {
        bytes32 uid = registerSchema();
        uint256 createdAt = repstation
            .accountInfo(genesisAccounts[0])
            .createdAt;
        address recipient = address(123);

        vm.warp(createdAt + 1 days);

        vm.prank(genesisAccounts[0]);
        eas.attest(
            AttestationRequest({
                schema: uid,
                data: AttestationRequestData({
                    recipient: recipient,
                    expirationTime: NO_EXPIRATION_TIME,
                    revocable: false,
                    refUID: 0x0,
                    data: new bytes(1),
                    value: 0
                })
            })
        );

        // Can't attest twice before rate limit expires
        vm.expectRevert(Repstation.RecipientRateLimit.selector);
        vm.prank(genesisAccounts[0]);
        eas.attest(
            AttestationRequest({
                schema: uid,
                data: AttestationRequestData({
                    recipient: recipient,
                    expirationTime: NO_EXPIRATION_TIME,
                    revocable: false,
                    refUID: 0x0,
                    data: new bytes(1),
                    value: 0
                })
            })
        );

        // Can attest after rate limit expires
        vm.warp(createdAt + RECIPIENT_RATE_LIMIT + 1);
        vm.prank(genesisAccounts[0]);
        eas.attest(
            AttestationRequest({
                schema: uid,
                data: AttestationRequestData({
                    recipient: recipient,
                    expirationTime: NO_EXPIRATION_TIME,
                    revocable: false,
                    refUID: 0x0,
                    data: new bytes(1),
                    value: 0
                })
            })
        );

        assertEq(
            repstation.accountInfo(genesisAccounts[0]).attestationCount,
            2
        );
    }

    /*************************************
                    HELPERS 
     ************************************/

    function registerSchema() internal returns (bytes32) {
        if (schemaUid != 0x0) {
            return schemaUid;
        }

        bytes32 uid = registry.register(
            "bool upVote",
            ISchemaResolver(address(repstation)),
            false
        );

        schemaUid = uid;

        return uid;
    }
}
