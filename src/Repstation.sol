// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console.sol";

import {pow, log2, mul} from "@prb/math/sd59x18/Math.sol";
import {sd} from "@prb/math/SD59x18.sol";
import {intoUint256, intoInt256} from "@prb/math/sd59x18/Casting.sol";
import {PRBMathCastingUint256} from "@prb/math/casting/Uint256.sol";
import {IEAS, Attestation} from "eas/IEAS.sol";
import {InvalidEAS, uncheckedInc} from "eas/Common.sol";
import {ISchemaResolver} from "eas/resolver/ISchemaResolver.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

/// @dev The scalar of ETH and most ERC20s.
uint256 constant WAD = 1e18;

/**
 * @title Repstation
 * @author @gigamesh
 * @notice An onchain reputation system built as an attestation resolver in the Ethereum Attestation Service
 */
contract Repstation is
    ISchemaResolver,
    Ownable2StepUpgradeable,
    UUPSUpgradeable
{
    error AttesterHasNoRep(address attester);
    error AccessDenied();
    error InsufficientValue();
    error NotPayable();

    struct Account {
        // Reputation score
        uint256 rep;
        // Number of attestations given
        uint32 attestationCount;
        // Timestamp of latest attestation given
        uint32 lastAttestationGivenAt;
        // Timestamp of when this account received its first attestation
        uint32 createdAt;
    }

    // Account info for each address
    mapping(address => Account) public accounts;

    // Latest attestation timestamp for each attester-recipient pair
    mapping(address => mapping(address => uint32 latestAttestation))
        public latestAttestations;

    string public constant VERSION = "0.1";

    // TODO: determine if this type makes sense
    uint256 public constant MAX_REP = 1000e18;

    // The global EAS contract.
    IEAS internal _eas;

    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializes the resolver.
     *
     * @param eas The address of the global EAS contract.
     */
    function initialize(
        address eas,
        address[] memory _genesisAccounts
    ) external virtual initializer {
        if (eas == address(0)) {
            revert InvalidEAS();
        }

        _eas = IEAS(eas);

        for (uint256 i = 0; i < _genesisAccounts.length; i++) {
            accounts[_genesisAccounts[i]].createdAt = uint32(block.timestamp);
            accounts[_genesisAccounts[i]].rep = MAX_REP;
        }

        __Ownable2Step_init();
        __UUPSUpgradeable_init();
    }

    /**
     * @dev Ensures that only the EAS contract can make this call.
     */
    modifier onlyEAS() {
        if (msg.sender != address(_eas)) {
            revert AccessDenied();
        }

        _;
    }

    /**
     * @inheritdoc ISchemaResolver
     */
    function isPayable() public pure virtual returns (bool) {
        return false;
    }

    /**
     * @dev ETH callback.
     */
    receive() external payable virtual {
        if (!isPayable()) {
            revert NotPayable();
        }
    }

    function onAttest(
        Attestation calldata attestation
    ) internal returns (bool) {
        Account storage attester = accounts[attestation.attester];
        Account storage attested = accounts[attestation.recipient];

        // Only accounts with rep attestors can attest
        if (attester.rep == 0) {
            revert AttesterHasNoRep(attestation.attester);
        }

        // Calculate rep & update Account of attested/recipient
        uint256 decayedAttestedRep = rep(attestation.recipient);
        uint256 attestorRep = accounts[attestation.attester].rep;

        uint256 newRep = decayedAttestedRep + (1 * (attestorRep / 100));

        if (newRep > MAX_REP) {
            newRep = MAX_REP;
        }

        attested.rep = newRep;

        // Making this attestion changes the decay rate of the attester, so we need
        // to store a snapshot of their current rep for future calculations
        attester.rep = rep(attestation.attester);
        // Increment attester's attestationCount
        attester.attestationCount = attester.attestationCount + 1;
        // Record timestamp of attestation
        attester.lastAttestationGivenAt = uint32(block.timestamp);

        return true;
    }

    /**
     * @inheritdoc ISchemaResolver
     */
    function attest(
        Attestation calldata attestation
    ) external payable onlyEAS returns (bool) {
        return onAttest(attestation);
    }

    /**
     * @inheritdoc ISchemaResolver
     */
    function multiAttest(
        Attestation[] calldata attestations,
        uint256[] calldata /* values */
    ) external payable onlyEAS returns (bool) {
        uint256 length = attestations.length;

        for (uint256 i = 0; i < length; i = uncheckedInc(i)) {
            onAttest(attestations[i]);
        }

        return true;
    }

    /**
     * @dev Processes an attestation revocation and verifies if it can be revoked.
     * @return Whether the attestation can be revoked.
     */
    function revoke(
        Attestation calldata /* attestation */
    ) external payable returns (bool) {
        return true;
    }

    function multiRevoke(
        Attestation[] calldata /* attestations */,
        uint256[] calldata /* values */
    ) external payable returns (bool) {
        return true;
    }

    function accountInfo(address account) public view returns (Account memory) {
        return accounts[account];
    }

    /**
     * @dev Returns the compound decayed reputation of an account.
     */
    function rep(address account) public view returns (uint256) {
        Account memory _accountInfo = accounts[account];

        // If no attestations have been given yet, look at creation time.
        uint256 checkpoint = _accountInfo.lastAttestationGivenAt > 0
            ? _accountInfo.lastAttestationGivenAt
            : _accountInfo.createdAt;

        int256 secondsSinceCheckpoint = int256(block.timestamp - checkpoint);
        uint256 decayRatePerSec = repDecayRatePerSec(account);

        // https://medium.com/coinmonks/math-in-solidity-part-5-exponent-and-logarithm-9aef8515136e
        return
            (_accountInfo.rep / 1e18) *
            intoUint256(
                pow(
                    PRBMathCastingUint256.intoSD59x18(2e18),
                    sd(
                        secondsSinceCheckpoint *
                            intoInt256(
                                log2(
                                    PRBMathCastingUint256.intoSD59x18(
                                        1e18 - decayRatePerSec
                                    )
                                )
                            )
                    )
                )
            );
    }

    function repDecayRatePerSec(address account) public view returns (uint256) {
        Account memory _account = accounts[account];

        uint256 ageOfAccount = block.timestamp - _account.createdAt;

        // Attestations per day (fraction scaled to 1e18)
        uint256 attestationsPerDay = FixedPointMathLib.divWad(
            _account.attestationCount,
            ageOfAccount
        ) * 1 days;

        // https://www.desmos.com/calculator/3rqdk2k1a6
        uint256 decayRatePerSec = FixedPointMathLib.mulDiv(
            1,
            uint256(
                FixedPointMathLib.powWad(0.5e18, int256(attestationsPerDay))
            ),
            // 8640000 instead of 86400 to compensate for not being able to multiply by 0.01
            // (actual formula would be 0.01 * (0.5e18 ** attestationsPerDay) / 86400)
            8640000
        );

        return decayRatePerSec;
    }

    /**
     * @dev Authorizes upgrades. MUST INCLUDE IN EVERY VERSION!
     */
    function _authorizeUpgrade(address) internal override onlyOwner {}
}
