// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {UniversalSigValidator} from "./EIP6492.sol";
import {IPortraitSigStruct} from "./IPortraitSigStruct.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract PortraitSigValidator is IPortraitSigStruct {
    UniversalSigValidator public immutable universalSigValidator;

    constructor(UniversalSigValidator _universalSigValidator) {
        universalSigValidator = _universalSigValidator;
    }

    string public constant INTRODUCTION =
        "Portrait wants to perform an action with your Ethereum account.";

    function representBytes32AsString(
        bytes32 bytes32Data
    ) public pure returns (string memory) {
        return Strings.toHexString(uint256(bytes32Data), 32);
    }

    function generateHashedSigData(
        SigData memory data
    ) public pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    data.action,
                    data.target,
                    data.targetType,
                    uint2str(data.version),
                    representBytes32AsString(data.params),
                    uint2str(data.expirationTime)
                )
            );
    }

    function createMessage(
        SigData memory data
    ) public pure returns (string memory) {
        bytes32 hashedData = generateHashedSigData(data);

        return
            string(
                abi.encodePacked(
                    INTRODUCTION,
                    "\n\nAction: ",
                    data.action,
                    "\nTarget: ",
                    data.target,
                    "\nTarget Type: ",
                    data.targetType,
                    "\nVersion: ",
                    uint2str(data.version),
                    "\nData: ",
                    representBytes32AsString(hashedData),
                    "\nExpiration Time: ",
                    uint2str(data.expirationTime)
                )
            );
    }

    function uint2str(uint256 i) public pure returns (string memory str) {
        if (i == 0) {
            return "0";
        }
        uint256 j = i;
        uint256 length;
        while (j != 0) {
            length++;
            j /= 10;
        }
        bytes memory bstr = new bytes(length);
        uint256 k = length;
        j = i;
        while (j != 0) {
            bstr[--k] = bytes1(uint8(48 + (j % 10)));
            j /= 10;
        }
        str = string(bstr);
    }

    error Expired();

    function convertStringToUintArray(
        string memory input
    ) public pure returns (uint8[] memory) {
        uint8[] memory result = new uint8[](bytes(input).length);

        for (uint256 i = 0; i < bytes(input).length; i++) {
            result[i] = uint8(bytes(input)[i]);
        }

        return result;
    }

    function isValidSig(
        address signer,
        SigData memory data,
        bytes calldata sig
    ) external returns (bool) {
        if (block.timestamp > data.expirationTime) {
            revert Expired();
        }

        string memory message = createMessage(data);

        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(
            abi.encodePacked(message)
        );

        return
            universalSigValidator.isValidSig(signer, ethSignedMessageHash, sig);
    }

    function isValid(
        address signer,
        bytes32 data,
        bytes calldata sig
    ) external returns (bool) {
        return universalSigValidator.isValidSig(signer, data, sig);
    }
}
