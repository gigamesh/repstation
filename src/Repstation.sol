// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {Ownable} from "solady/auth/Ownable.sol";

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

    mapping(address => Account) public accounts;

    function initialize() public {
        _initializeOwner(msg.sender);
    }

    function attest() public {
        // TODO: calculate rep change & pass along the attestatoin to EAS
    }
}
