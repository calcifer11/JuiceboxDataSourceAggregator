// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract DataWeightSource {
    error NOT_ALLOWED();

    uint weightModifier;

    function getWeightModifier() external view returns (uint) {
        return weightModifier;
    }
}
