// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC1967} from "openzeppelin-contracts/contracts/interfaces/IERC1967.sol";

interface ITransparentUpgradeableBeaconProxy is IERC1967 {
    function upgradeBeaconToAndCall(address newBeacon, bytes calldata data) external payable;
}
