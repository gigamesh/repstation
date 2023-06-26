// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Ownable} from "solady/auth/Ownable.sol";
import {IEAS} from "eas/IEAS.sol";

/**
 * @title Repstation
 * @author @gigamesh
 * @notice An onchain reputation system built on the Ethereum Attestation Service
 */
contract Repstation is Ownable {
    struct Account {
        uint256 rep;
        uint32 createdAt;
    }

    IEAS public eas;

    mapping(address => Account) public accounts;

    function initialize(address _eas) public {
        _initializeOwner(msg.sender);

        eas = IEAS(_eas);
    }

    function attest() public {
        // TODO: calculate rep change & pass along the attestatoin to EAS
    }
}
