// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

contract SayNothingButRevert {
    error SayNothingButRevertError();
    error InitializeRevertError();

    function sayNothingButRevert() public pure returns (string memory) {
        revert SayNothingButRevertError();
    }

    function initializeSayNothingButRevert() public pure {
        revert InitializeRevertError();
    }
}
