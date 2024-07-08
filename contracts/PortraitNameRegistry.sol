// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../../interfaces/l2/IPortraitNameRegistry.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

/// @custom:security-contact ryan@portrait.gg
contract PortraitNameRegistry is
    IPortraitNameRegistry,
    Initializable,
    PausableUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    string public constant CONTRACT_NAME = "PortraitNameRegistry";

    uint256 public constant VERSION = 1;

    /*//////////////////////////////////////////////////////////////
                                 VARIABLES
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IPortraitNameRegistry
     */
    IPortraitContractRegistry public portraitContractRegistry;

    /**
     * @inheritdoc IPortraitNameRegistry
     */
    IPortraitIdRegistry public portraitIdRegistry;

    /**
     * @inheritdoc IPortraitNameRegistry
     */
    IPortraitAccessRegistry public portraitAccessRegistry;

    /**
     * @inheritdoc IPortraitNameRegistry
     */
    PortraitSigValidator public portraitSigValidator;

    /**
     * @notice Returns the time in seconds that a name reservation lasts.
     */
    uint256 public reservationDuration;

    /*//////////////////////////////////////////////////////////////
                                 MAPPINGS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IPortraitNameRegistry
     */
    mapping(uint256 => string) public portraitIdToName;

    /**
     * @inheritdoc IPortraitNameRegistry
     */
    mapping(string => uint256) public nameToPortraitId;

    /**
     * @notice Mapping of a reservation hash to a Reservation struct
     * @dev Can not be defined in the interface, as structs are not supported.
     *      Use `getReservationForReservationHash` to access this mapping.
     */
    mapping(bytes32 => Reservation) public reservationHashToReservation;

    /*//////////////////////////////////////////////////////////////
                         NAME RESERVATION ACTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IPortraitNameRegistry
     */
    function reserveName(
        bytes32 reservationHash,
        address reserver
    ) external nonReentrant whenNotPaused {
        address _reserver;

        // Give the PortraitIdRegistry contract permission to reserve names.
        if (msg.sender == address(portraitIdRegistry)) {
            _reserver = reserver;
        } else {
            bool isDelegate = portraitAccessRegistry.isDelegateOfAddress(
                reserver,
                msg.sender
            );

            if (msg.sender != reserver && !isDelegate) revert Unauthorized();

            _reserver = msg.sender;
        }

        _reserveName(reservationHash, _reserver);
    }

    function _reserveName(bytes32 reservationHash, address reserver) internal {
        if (
            reservationHashToReservation[reservationHash].reservedBy != reserver
        ) {
            if (
                reservationHashToReservation[reservationHash].reservedUntil >
                block.timestamp
            ) revert DuplicateReservation();
        }

        reservationHashToReservation[reservationHash] = Reservation({
            reservedUntil: block.timestamp + reservationDuration,
            reservedBy: reserver
        });

        emit NameReserved(
            reservationHash,
            reservationHashToReservation[reservationHash].reservedBy,
            reservationHashToReservation[reservationHash].reservedUntil
        );
    }

    /**
     * @inheritdoc IPortraitNameRegistry
     */
    function registerName(
        string memory name,
        string memory secret,
        address reserver,
        uint256 portraitId
    ) external nonReentrant whenNotPaused {
        _registerName(name, secret, reserver, portraitId);
    }

    function _registerName(
        string memory name,
        string memory secret,
        address reserver,
        uint256 portraitId
    ) internal {
        if (!_isValidName(name)) revert InvalidName();
        if (!_isAvailableName(name)) revert NameAlreadyRegistered();

        bytes32 reservation = _generateReservationHash(name, secret);

        if (reservationHashToReservation[reservation].reservedBy == address(0))
            revert NameNotReserved();

        if (
            reservationHashToReservation[reservation].reservedUntil <
            block.timestamp
        ) revert ReservationExpired();

        address reservedBy = reservationHashToReservation[reservation]
            .reservedBy;

        if (
            !portraitAccessRegistry.isDelegateOrOwnerOfPortraitId(
                portraitId,
                reservedBy
            )
        ) revert Unauthorized();

        portraitIdToName[portraitId] = name;
        nameToPortraitId[name] = portraitId;

        delete reservationHashToReservation[reservation];

        emit NameRegistered(name, reserver, portraitId);
    }

    /*//////////////////////////////////////////////////////////////
                         VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IPortraitNameRegistry
     */
    function isAvailableName(
        string memory name
    ) external view returns (bool isAvailable) {
        return _isAvailableName(name);
    }

    function _isAvailableName(
        string memory name
    ) internal view returns (bool isAvailable) {
        return nameToPortraitId[name] == 0;
    }

    /**
     * @inheritdoc IPortraitNameRegistry
     */
    function getNamesForPortraitIds(
        uint256[] memory portraitIds
    ) external view returns (string[] memory names) {
        names = new string[](portraitIds.length);

        for (uint256 i; i < portraitIds.length; i++) {
            names[i] = portraitIdToName[portraitIds[i]];
        }

        return names;
    }

    /*//////////////////////////////////////////////////////////////
                         PURE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IPortraitNameRegistry
     */
    function generateReservationHash(
        string memory name,
        string memory secret
    ) external pure returns (bytes32 reservationHash) {
        return _generateReservationHash(name, secret);
    }

    function _generateReservationHash(
        string memory name,
        string memory secret
    ) internal pure returns (bytes32 reservationHash) {
        return keccak256(abi.encode(name, secret));
    }

    /**
     * @inheritdoc IPortraitNameRegistry
     */
    function isValidName(
        string memory name
    ) external pure returns (bool isValid) {
        return _isValidName(name);
    }

    function _isValidName(
        string memory name
    ) internal pure returns (bool isValid) {
        bytes memory b = bytes(name);
        if (b.length < 3) return false;
        if (b.length > 15) return false;
        if (b[0] == 0x2d) return false; // dash
        if (b[b.length - 1] == 0x2d) return false; // dash

        for (uint256 i; i < b.length; i++) {
            bytes1 char = b[i];
            if (
                !(char >= 0x30 && char <= 0x39) && // 0-9
                !(char >= 0x61 && char <= 0x7A) && // a-z
                !(char == 0x2d) // dash
            ) return false;
            if (char == 0x2d && b[i + 1] == 0x2d) return false; // double dash
        }

        return true;
    }

    /*//////////////////////////////////////////////////////////////
                         PERMISSIONED ACTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IPortraitNameRegistry
     */
    function setReservationDuration(uint256 timeInSeconds) external onlyOwner {
        reservationDuration = timeInSeconds;

        emit ReservationDurationUpdated(block.timestamp, timeInSeconds);
    }

    /**
     * @inheritdoc IPortraitNameRegistry
     */
    function trustedRegisterName(
        address signer,
        string memory name,
        string memory secret,
        uint256 portraitId,
        uint256 deadline,
        address owner,
        bytes calldata sig
    ) external onlyOwner {
        if (signer != owner) {
            bool isDelegate = portraitAccessRegistry.isDelegateOfAddress(
                owner,
                signer
            );
            if (!isDelegate) revert Unauthorized();
        }

        // All but sig
        bytes32 paramsHash = keccak256(
            abi.encode(signer, name, secret, portraitId, deadline, owner)
        );

        SigData memory data = SigData({
            action: "TrustedRegisterName",
            target: CONTRACT_NAME,
            targetType: "Contract",
            version: VERSION,
            params: paramsHash,
            expirationTime: deadline
        });

        if (!portraitSigValidator.isValidSig(signer, data, sig))
            revert Unauthorized();

        _registerName(name, secret, owner, portraitId);
    }

    /*//////////////////////////////////////////////////////////////
                            PROTOCOL HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IPortraitNameRegistry
     */
    function updateProtocolContracts() external {
        portraitIdRegistry = portraitContractRegistry.portraitIdRegistry();
        portraitAccessRegistry = portraitContractRegistry
            .portraitAccessRegistry();
        portraitSigValidator = portraitContractRegistry.portraitSigValidator();
    }

    /*//////////////////////////////////////////////////////////////
                                OPENZEPPELIN
    //////////////////////////////////////////////////////////////*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address initialOwner,
        address portraitContractRegistryAddress
    ) public initializer {
        if (portraitContractRegistryAddress == address(0))
            revert InvalidAddress();

        if (initialOwner == address(0)) revert InvalidAddress();

        __Pausable_init();
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        reservationDuration = 30 minutes;

        _pause();

        portraitContractRegistry = IPortraitContractRegistry(
            portraitContractRegistryAddress
        );

        if (portraitIdRegistry == IPortraitIdRegistry(address(0))) {
            bool hasIdRegistry = portraitContractRegistry
                .portraitIdRegistry() != IPortraitIdRegistry(address(0));

            if (hasIdRegistry) {
                portraitIdRegistry = portraitContractRegistry
                    .portraitIdRegistry();
            }
        }

        if (portraitAccessRegistry == IPortraitAccessRegistry(address(0))) {
            bool hasAccessRegistry = portraitContractRegistry
                .portraitAccessRegistry() !=
                IPortraitAccessRegistry(address(0));

            if (hasAccessRegistry) {
                portraitAccessRegistry = portraitContractRegistry
                    .portraitAccessRegistry();
            }
        }

        if (portraitSigValidator == PortraitSigValidator(address(0))) {
            bool hasPortraitSigValidator = portraitContractRegistry
                .portraitSigValidator() != PortraitSigValidator(address(0));

            if (hasPortraitSigValidator) {
                portraitSigValidator = portraitContractRegistry
                    .portraitSigValidator();
            }
        }
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
