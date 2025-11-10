// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {
    TransparentUpgradeableBeaconProxy,
    ITransparentUpgradeableBeaconProxy
} from "../src/TransparentUpgradeableBeaconProxy.sol";

import {SayHey} from "./utils/SayHey.sol";
import {SayHello} from "./utils/SayHello.sol";
import {PayableSayEther} from "./utils/PayableSayEther.sol";
import {SayNothingButRevert} from "./utils/SayNothingButRevert.sol";

import {UpgradeableBeacon} from "openzeppelin-contracts/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {ERC1967Utils} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Utils.sol";

import {BeaconProxyAdmin} from "../src/BeaconProxyAdmin.sol";

contract TransparentUpgradeableBeaconProxyTest is Test {
    TransparentUpgradeableBeaconProxy public transparentUpgradeableBeaconProxy;
    address public owner = makeAddr("owner");
    SayHey public sayHeyImplementation = new SayHey();
    SayHello public sayHelloImplementation = new SayHello();
    PayableSayEther public payableSayEtherImplementation = new PayableSayEther();
    SayNothingButRevert public sayNothingButRevertImplementation = new SayNothingButRevert();
    UpgradeableBeacon public oldBeacon;

    function setUp() public {
        oldBeacon = new UpgradeableBeacon(address(sayHeyImplementation), owner);

        transparentUpgradeableBeaconProxy = new TransparentUpgradeableBeaconProxy(
            address(oldBeacon), owner, abi.encodeWithSelector(sayHeyImplementation.initializeHey.selector)
        );
    }

    function _getProxyAdmin() internal view returns (address) {
        return address(uint160(uint256(vm.load(address(transparentUpgradeableBeaconProxy), ERC1967Utils.ADMIN_SLOT))));
    }

    function _getBeacon() internal view returns (address) {
        return address(uint160(uint256(vm.load(address(transparentUpgradeableBeaconProxy), ERC1967Utils.BEACON_SLOT))));
    }

    function test_initializationAndReadFunction() public view {
        assertEq(SayHey(address(transparentUpgradeableBeaconProxy)).sayHey(), "Hey");
    }

    function test_writeFunctionForwarding() public {
        SayHey(address(transparentUpgradeableBeaconProxy)).setHeyMessage("John");
        assertEq(SayHey(address(transparentUpgradeableBeaconProxy)).sayHey(), "Hey, John");
    }

    function test_forwardingAdminFunction() public {
        SayHey(address(transparentUpgradeableBeaconProxy)).transferOwnership(address(this));
        assertEq(
            SayHey(address(transparentUpgradeableBeaconProxy)).sayHey(),
            string.concat("Hey, 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496")
        );
    }

    function testRestrictionOnUpgrade() public {
        vm.expectRevert();
        ITransparentUpgradeableBeaconProxy(address(transparentUpgradeableBeaconProxy))
            .upgradeBeaconToAndCall(
                address(sayHelloImplementation), abi.encodeWithSelector(sayHelloImplementation.initializeHello.selector)
            );
    }

    function test_proxyAdminShallNotPass() public {
        address proxyAdmin = _getProxyAdmin();

        vm.prank(proxyAdmin);
        vm.expectRevert(TransparentUpgradeableBeaconProxy.ProxyDeniedAdminAccess.selector);
        SayHey(address(transparentUpgradeableBeaconProxy)).sayHey();
    }

    function test_proxyAdminTransferOwnershipRestricted() public {
        address proxyAdmin = _getProxyAdmin();

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        Ownable(address(proxyAdmin)).transferOwnership(address(this));
    }

    function test_proxyAdminUpgradeRestricted() public {
        address proxyAdmin = _getProxyAdmin();

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        BeaconProxyAdmin(address(proxyAdmin))
            .upgradeBeaconToAndCall(
                ITransparentUpgradeableBeaconProxy(address(transparentUpgradeableBeaconProxy)),
                address(sayHelloImplementation),
                abi.encodeWithSelector(sayHelloImplementation.initializeHello.selector)
            );
    }

    function test_proxyAdminCanTransferOwnership() public {
        address proxyAdmin = _getProxyAdmin();

        vm.prank(owner);
        Ownable(address(proxyAdmin)).transferOwnership(address(this));
        assertEq(Ownable(address(proxyAdmin)).owner(), address(this));
    }

    function test_proxyAdminOwnerCanUpgradeBeacon() public {
        address proxyAdmin = _getProxyAdmin();

        UpgradeableBeacon beacon = new UpgradeableBeacon(address(sayHelloImplementation), owner);

        assertEq(_getBeacon(), address(oldBeacon));
        assertEq(oldBeacon.implementation(), address(sayHeyImplementation));

        vm.prank(owner);
        BeaconProxyAdmin(address(proxyAdmin))
            .upgradeBeaconToAndCall(
                ITransparentUpgradeableBeaconProxy(address(transparentUpgradeableBeaconProxy)),
                address(beacon),
                abi.encodeWithSelector(sayHelloImplementation.initializeHello.selector)
            );

        assertNotEq(address(oldBeacon), address(beacon));
        assertNotEq(address(sayHelloImplementation), address(sayHeyImplementation));
        assertEq(_getBeacon(), address(beacon));
        assertEq(beacon.implementation(), address(sayHelloImplementation));
        assertEq(SayHello(address(transparentUpgradeableBeaconProxy)).sayHello(), "Hello");
    }

    function test_proxyAdminCanUpgradeBeaconWithPayableFunction() public {
        address proxyAdmin = _getProxyAdmin();
        UpgradeableBeacon beacon = new UpgradeableBeacon(address(payableSayEtherImplementation), owner);

        deal(owner, 2 ether);
        vm.prank(owner);
        BeaconProxyAdmin(address(proxyAdmin)).upgradeBeaconToAndCall{value: 1 ether}(
            ITransparentUpgradeableBeaconProxy(address(transparentUpgradeableBeaconProxy)),
            address(beacon),
            abi.encodeWithSelector(payableSayEtherImplementation.initializeSayEther.selector)
        );
        assertEq(PayableSayEther(address(transparentUpgradeableBeaconProxy)).sayEther(), "Ether: 1000000000000000000");
    }

    function test_beaconProxyPayableCreation() public {
        UpgradeableBeacon beacon = new UpgradeableBeacon(address(payableSayEtherImplementation), owner);
        deal(address(this), 1 ether);

        transparentUpgradeableBeaconProxy = new TransparentUpgradeableBeaconProxy{value: 1 ether}(
            address(beacon), owner, abi.encodeWithSelector(payableSayEtherImplementation.initializeSayEther.selector)
        );
        assertEq(PayableSayEther(address(transparentUpgradeableBeaconProxy)).sayEther(), "Ether: 1000000000000000000");
    }

    function test_emptyInitData() public {
        UpgradeableBeacon beacon = new UpgradeableBeacon(address(sayHelloImplementation), owner);
        transparentUpgradeableBeaconProxy = new TransparentUpgradeableBeaconProxy(address(beacon), owner, "");
        assertEq(SayHello(address(transparentUpgradeableBeaconProxy)).sayHello(), "");
    }

    function test_emptyUpgradeInitData() public {
        UpgradeableBeacon beacon = new UpgradeableBeacon(address(sayHelloImplementation), owner);

        vm.prank(owner);
        BeaconProxyAdmin(address(_getProxyAdmin()))
            .upgradeBeaconToAndCall(
                ITransparentUpgradeableBeaconProxy(address(transparentUpgradeableBeaconProxy)), address(beacon), ""
            );
        assertEq(SayHello(address(transparentUpgradeableBeaconProxy)).sayHello(), "Hey");
    }

    function test_invaliadBeaconUpgradeReverts() public {
        vm.expectRevert();
        vm.prank(owner);
        BeaconProxyAdmin(address(_getProxyAdmin()))
            .upgradeBeaconToAndCall(
                ITransparentUpgradeableBeaconProxy(address(transparentUpgradeableBeaconProxy)), address(this), ""
            );
    }

    function test_revertCreation() public {
        UpgradeableBeacon beacon = new UpgradeableBeacon(address(sayNothingButRevertImplementation), owner);
        vm.expectRevert(abi.encodeWithSelector(SayNothingButRevert.InitializeRevertError.selector));
        transparentUpgradeableBeaconProxy = new TransparentUpgradeableBeaconProxy(
            address(beacon),
            owner,
            abi.encodeWithSelector(sayNothingButRevertImplementation.initializeSayNothingButRevert.selector)
        );
    }

    function test_revertUpgrade() public {
        UpgradeableBeacon beacon = new UpgradeableBeacon(address(sayNothingButRevertImplementation), owner);
        vm.expectRevert(abi.encodeWithSelector(SayNothingButRevert.InitializeRevertError.selector));
        vm.prank(owner);
        BeaconProxyAdmin(address(_getProxyAdmin()))
            .upgradeBeaconToAndCall(
                ITransparentUpgradeableBeaconProxy(address(transparentUpgradeableBeaconProxy)),
                address(beacon),
                abi.encodeWithSelector(sayNothingButRevertImplementation.initializeSayNothingButRevert.selector)
            );
    }

    function test_functionForwardingRevert() public {
        UpgradeableBeacon beacon = new UpgradeableBeacon(address(sayNothingButRevertImplementation), owner);
        vm.prank(owner);
        BeaconProxyAdmin(address(_getProxyAdmin()))
            .upgradeBeaconToAndCall(
                ITransparentUpgradeableBeaconProxy(address(transparentUpgradeableBeaconProxy)), address(beacon), ""
            );
        vm.expectRevert(abi.encodeWithSelector(SayNothingButRevert.SayNothingButRevertError.selector));
        SayNothingButRevert(address(transparentUpgradeableBeaconProxy)).sayNothingButRevert();
    }
}
