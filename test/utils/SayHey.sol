// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";

contract SayHey {
    using Strings for address;

    string message;

    function initializeHey() public {
        message = "Hey";
    }

    function sayHey() public view returns (string memory) {
        return message;
    }

    function setHeyMessage(string memory name) public {
        message = string.concat("Hey, ", name);
    }

    function transferOwnership(address newOwner) public {
        message = string.concat("Hey, ", newOwner.toChecksumHexString());
    }
}
