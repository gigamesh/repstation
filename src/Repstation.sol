// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IEAS, Attestation} from "eas/IEAS.sol";
import {InvalidEAS, uncheckedInc} from "eas/Common.sol";
import {ISchemaResolver} from "eas/resolver/ISchemaResolver.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

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
    struct Account {
        uint136 rep;
        uint32 attestationCount;
        uint32 createdAt;
    }

    error AttesterNotRegistered();
    error AccessDenied();
    error InsufficientValue();
    error NotPayable();

    mapping(address => Account) public accounts;

    string public constant VERSION = "0.1";

    // TODO: determine if this type makes sense
    uint136 public constant MAX_REP = 1000e18;

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
        Attestation calldata attestation,
        uint256 /* value */
    ) internal returns (bool) {
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
     * @inheritdoc ISchemaResolver
     */
    function attest(
        Attestation calldata attestation
    ) external payable onlyEAS returns (bool) {
        return onAttest(attestation, msg.value);
    }

    /**
     * @inheritdoc ISchemaResolver
     */
    function multiAttest(
        Attestation[] calldata attestations,
        uint256[] calldata values
    ) external payable onlyEAS returns (bool) {
        uint256 length = attestations.length;

        // We are keeping track of the remaining ETH amount that can be sent to resolvers and will keep deducting
        // from it to verify that there isn't any attempt to send too much ETH to resolvers. Please note that unless
        // some ETH was stuck in the contract by accident (which shouldn't happen in normal conditions), it won't be
        // possible to send too much ETH anyway.
        uint256 remainingValue = msg.value;

        for (uint256 i = 0; i < length; i = uncheckedInc(i)) {
            // Ensure that the attester/revoker doesn't try to spend more than available.
            uint256 value = values[i];
            if (value > remainingValue) {
                revert InsufficientValue();
            }

            // Forward the attestation to the underlying resolver and revert in case it isn't approved.
            if (!onAttest(attestations[i], value)) {
                return false;
            }

            unchecked {
                // Subtract the ETH amount, that was provided to this attestation, from the global remaining ETH amount.
                remainingValue -= value;
            }
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
     * @dev Authorizes upgrades. MUST INCLUDE IN EVERY VERSION!
     */
    function _authorizeUpgrade(address) internal override onlyOwner {}
}
