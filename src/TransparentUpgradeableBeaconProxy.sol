// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IBeacon} from "openzeppelin-contracts/contracts/proxy/beacon/IBeacon.sol";
import {Proxy} from "openzeppelin-contracts/contracts/proxy/Proxy.sol";
import {ERC1967Utils} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {BeaconProxyAdmin} from "./BeaconProxyAdmin.sol";
import {ITransparentUpgradeableBeaconProxy} from "./interfaces/ITransparentUpgradeableBeaconProxy.sol";

/**
 * @title TransparentUpgradeableBeaconProxy
 * @notice This proxy contract delegates all calls to the implementation provided by a Beacon contract.
 * 
 * @dev Roles and Responsibilities:
 *
 * Beacon Proxy Admin:
 *   The admin of this proxy is authorized to upgrade the Beacon reference address
 *   by calling {upgradeBeaconToAndCall}. The beacon address is stored in the
 *   BEACON_SLOT:
 *   bytes32 internal constant BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;
 *   This operation allows the admin to replace the Beacon used by the proxy entirely.
 *
 * Beacon Owner:
 *   The Beacon contract itself has an owner role responsible for upgrading the
 *   underlying logic implementation address used by all proxies pointing to that Beacon.
 *   The beacon owner can deploy new logic contracts and direct the Beacon to reference them.
 *
 * Important Considerations:
 *
 * The Beacon owner's implementation executes within the proxy's context. 
 * As a result, the implementation can access and modify the proxy's storage,
 * including critical slots such as BEACON_SLOT.
 * 
 * This means that, although the proxy admin controls the Beacon reference,
 * the beacon owner indirectly holds the capability to change the beacon
 * address or other proxy state variables if the implementation code permits it.
 *
 * This is expected behavior under the Ownable Beacon design, but it is crucial
 * to maintain clear separation of operational responsibilities between:
 * - The Beacon Proxy Admin (controls which Beacon is used)
 * - The Beacon Owner (controls which implementation logic is used)
 *
 * Recommendation:
 * Projects using this proxy pattern should clearly define:
 * - Who is assigned as proxy admin and beacon owner.
 * - How these roles are governed or secured (e.g., via multisig or timelock).
 * - That the beacon owner can influence proxy state indirectly via implementation logic.
 */
contract TransparentUpgradeableBeaconProxy is Proxy {
    address private immutable ADMIN;

    error ProxyDeniedAdminAccess();

    constructor(address beacon, address initialOwner, bytes memory data) payable {
        ERC1967Utils.upgradeBeaconToAndCall(beacon, data);

        ADMIN = address(new BeaconProxyAdmin(initialOwner));
        ERC1967Utils.changeAdmin(ADMIN);
    }

    function _implementation() internal view override returns (address) {
        return IBeacon(ERC1967Utils.getBeacon()).implementation();
    }

    function _fallback() internal virtual override {
        if (msg.sender == ADMIN) {
            if (msg.sig != ITransparentUpgradeableBeaconProxy.upgradeBeaconToAndCall.selector) {
                revert ProxyDeniedAdminAccess();
            } else {
                _dispatchUpgradeBeaconToAndCall();
            }
        } else {
            super._fallback();
        }
    }

    function _dispatchUpgradeBeaconToAndCall() private {
        (address newBeacon, bytes memory data) = abi.decode(msg.data[4:], (address, bytes));
        ERC1967Utils.upgradeBeaconToAndCall(newBeacon, data);
    }
}
