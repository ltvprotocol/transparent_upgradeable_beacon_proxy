// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

contract SayHello {
    string message;

    function initializeHello() public {
        message = "Hello";
    }

    function sayHello() public view returns (string memory) {
        return message;
    }
}
