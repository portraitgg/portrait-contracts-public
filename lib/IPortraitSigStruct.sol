// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IPortraitSigStruct {
    struct SigData {
        string action;
        string target;
        string targetType;
        uint256 version;
        bytes32 params;
        uint256 expirationTime;
    }
}
