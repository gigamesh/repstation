// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console.sol";

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

        uint256 secondsSinceCheckpoint = (block.timestamp - checkpoint);
        uint256 decayRatePerSec = repDecayRatePerSec(account);

        // https://medium.com/coinmonks/math-in-solidity-part-5-exponent-and-logarithm-9aef8515136e
        return
            uint256(
                FixedPointMathLib.powWad(
                    2,
                    int256(secondsSinceCheckpoint) *
                        log2(int256(1e18 - decayRatePerSec))
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
            86400
        );

        return decayRatePerSec;
    }

    /**
     * @dev Authorizes upgrades. MUST INCLUDE IN EVERY VERSION!
     */
    function _authorizeUpgrade(address) internal override onlyOwner {}

    // TEMPORARY: REMOVE BEFORE DEPLOYMENT

    /// @notice Finds the zero-based index of the first one in the binary representation of x.
    /// @dev See the note on msb in the "Find First Set" Wikipedia article https://en.wikipedia.org/wiki/Find_first_set
    /// @param x The uint256 number for which to find the index of the most significant bit.
    /// @return msb The index of the most significant bit as an uint256.
    function mostSignificantBit(uint256 x) internal pure returns (uint256 msb) {
        if (x >= 2 ** 128) {
            x >>= 128;
            msb += 128;
        }
        if (x >= 2 ** 64) {
            x >>= 64;
            msb += 64;
        }
        if (x >= 2 ** 32) {
            x >>= 32;
            msb += 32;
        }
        if (x >= 2 ** 16) {
            x >>= 16;
            msb += 16;
        }
        if (x >= 2 ** 8) {
            x >>= 8;
            msb += 8;
        }
        if (x >= 2 ** 4) {
            x >>= 4;
            msb += 4;
        }
        if (x >= 2 ** 2) {
            x >>= 2;
            msb += 2;
        }
        if (x >= 2 ** 1) {
            // No need to shift x any more.
            msb += 1;
        }
    }

    /// @notice Calculates the binary logarithm of x.
    ///
    /// @dev Based on the iterative approximation algorithm.
    /// https://en.wikipedia.org/wiki/Binary_logarithm#Iterative_approximation
    ///
    /// Requirements:
    /// - x must be greater than zero.
    ///
    /// Caveats:
    /// - The results are nor perfectly accurate to the last digit, due to the lossy precision of the iterative approximation.
    ///
    /// @param x The signed 59.18-decimal fixed-point number for which to calculate the binary logarithm.
    function log2(int256 x) internal pure returns (int256 result) {
        require(x > 0);
        unchecked {
            // This works because log2(x) = -log2(1/x).
            int256 sign;
            if (x >= int256(WAD)) {
                sign = 1;
            } else {
                sign = -1;
                // Do the fixed-point inversion inline to save gas. The numerator is WAD * WAD.
                assembly {
                    x := div(1000000000000000000000000000000000000, x)
                }
            }

            // Calculate the integer part of the logarithm and add it to the result and finally calculate y = x * 2^(-n).
            uint256 n = mostSignificantBit(uint256(x / int256(WAD)));

            // The integer part of the logarithm as a signed 59.18-decimal fixed-point number. The operation can't overflow
            // because n is maximum 255, WAD is 1e18 and sign is either 1 or -1.
            result = int256(n) * int256(WAD);

            // This is y = x * 2^(-n).
            int256 y = x >> n;

            // If y = 1, the fractional part is zero.
            if (y == int256(WAD)) {
                return result * sign;
            }

            // Calculate the fractional part via the iterative approximation.
            // The "delta >>= 1" part is equivalent to "delta /= 2", but shifting bits is faster.
            for (int256 delta = int256(WAD / 2); delta > 0; delta >>= 1) {
                y = (y * y) / int256(WAD);

                // Is y^2 > 2 and so in the range [2,4)?
                if (y >= 2 * int256(WAD)) {
                    // Add the 2^(-m) factor to the logarithm.
                    result += delta;

                    // Corresponds to z/2 on Wikipedia.
                    y >>= 1;
                }
            }
            result *= sign;
        }
    }
}
