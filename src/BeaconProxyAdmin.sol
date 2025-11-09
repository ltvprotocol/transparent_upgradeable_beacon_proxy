// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {ITransparentUpgradeableBeaconProxy} from "./TransparentUpgradeableBeaconProxy.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

contract BeaconProxyAdmin is Ownable {
    constructor(address initialOwner) Ownable(initialOwner) {}

    function upgradeBeaconToAndCall(ITransparentUpgradeableBeaconProxy beaconProxy, address beacon, bytes memory data)
        public
        payable
        virtual
        onlyOwner
    {
        beaconProxy.upgradeBeaconToAndCall{value: msg.value}(beacon, data);
    }
}
