// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";

contract PayableSayEther {
    using Strings for uint256;

    function sayEther() public view returns (string memory) {
        return string.concat("Ether: ", address(this).balance.toString());
    }

    function initializeSayEther() public payable {}
}
