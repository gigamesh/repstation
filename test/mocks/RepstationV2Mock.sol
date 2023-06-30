// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {UUPSUpgradeable} from "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

contract RepstationV2Mock is UUPSUpgradeable {
    function someNewFunction() public pure returns (uint256) {
        return 1;
    }

    function _authorizeUpgrade(address) internal override {}
}
