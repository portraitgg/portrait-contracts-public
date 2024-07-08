// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IPortraitContractRegistry} from "./IPortraitContractRegistry.sol";
import {IPortraitIdRegistry} from "./IPortraitIdRegistry.sol";
import {IPortraitAccessRegistry} from "./IPortraitAccessRegistry.sol";
import {IPortraitSigStruct} from "../../lib/IPortraitSigStruct.sol";
import {PortraitSigValidator} from "../../lib/PortraitSigValidator.sol";

interface IPortraitNameRegistry is IPortraitSigStruct {
    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the name of the contract
     */
    function CONTRACT_NAME() external pure returns (string memory);

    /**
     * @notice Returns the version of the contract
     */
    function VERSION() external pure returns (uint256 version);

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Struct for a name reservation.
     */
    struct Reservation {
        address reservedBy;
        uint256 reservedUntil;
    }

    /*//////////////////////////////////////////////////////////////
                                 VARIABLES
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the address of the PortraitContractRegistry contract
     */
    function portraitContractRegistry()
        external
        view
        returns (IPortraitContractRegistry portraitContractRegistry);

    /**
     * @notice Returns the address of the PortraitIdRegistry contract
     */
    function portraitIdRegistry()
        external
        view
        returns (IPortraitIdRegistry portraitIdRegistry);

    /**
     * @notice Returns the address of the PortraitAccessRegistry contract
     */
    function portraitAccessRegistry()
        external
        view
        returns (IPortraitAccessRegistry portraitAccessRegistry);

    /**
     * @notice Returns the address of the PortraitSigValidator contract
     */
    function portraitSigValidator()
        external
        view
        returns (PortraitSigValidator portraitSigValidator);

    /**
     * @notice Returns the time in seconds that a name reservation lasts.
     */
    function reservationDuration()
        external
        view
        returns (uint256 reservationDuration);

    /*//////////////////////////////////////////////////////////////
                             MAPPINGS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the name of a portraitId.
     * @dev Mapping of portraitId => name
     */
    function portraitIdToName(
        uint256 portraitId
    ) external view returns (string memory);

    /**
     * @notice Returns the portraitId of a name.
     * @dev Mapping of name => portraitId
     */
    function nameToPortraitId(
        string memory name
    ) external view returns (uint256 portraitId);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @dev Error when a name is already registered.
    error NameAlreadyRegistered();

    /// @dev Error when a reservation is already made.
    error DuplicateReservation();

    /// @dev Error when name is not reserved by caller.
    error NameNotReserved();

    /// @dev Error when reservation has expired.
    error ReservationExpired();

    /// @dev Error when signature is expired.
    error SignatureExpired();

    /// @dev Error when signature is invalid.
    error InvalidSignature();

    /// @dev Error when name is invalid.
    error InvalidName();

    /// @dev Error when caller is not owner or delegate of portraitId.
    error Unauthorized();

    /// @dev Revert with `InvalidAddress` if caller attempts to perform an action with an invalid address
    error InvalidAddress();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Emit an event when a name is reserved.
     *
     * @param reservationHash       The reservation hash of the name to register.
     * @param reservedBy The address that reserved the name.
     * @param reservedUntil The timestamp until the name is reserved.
     */
    event NameReserved(
        bytes32 indexed reservationHash,
        address reservedBy,
        uint256 reservedUntil
    );

    /**
     * @dev Emit an event when a name is registered.
     *
     * @param name The name that was registered.
     * @param caller The address that registered the name.
     * @param portraitId The portraitId that was registered.
     */
    event NameRegistered(
        string indexed name,
        address indexed caller,
        uint256 portraitId
    );

    /**
     * @dev Emit an event when the reservation duration is updated.
     *
     * @param timestamp The timestamp of the update.
     * @param reservationDuration The new reservation duration.
     */
    event ReservationDurationUpdated(
        uint256 indexed timestamp,
        uint256 indexed reservationDuration
    );

    /*//////////////////////////////////////////////////////////////
                         NAME ACTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Reserves a name for an address.
     * @dev The reservation lasts for the reservation duration.
     *      In this function, we can not check if a name is available, as that would allow frontrunning.
     *      Before reserving a name, you should check if it is available with the `isAvailableName` function.
     *
     *      The reservationHash may be generated by the frontend, but it is recommended to use the `generateReservationHash` function.
     *      If you generate the reservationHash yourself, use the following format:
     *      keccak256(abi.encode(name, secret));
     *
     *      The reservationHash is used to prevent frontrunning.
     *
     *      Make sure that the secret is a sufficiently random salt/string. This is to prevent brute forcing the reservationHash.
     *      Make sure to store the secret somewhere, as you will need it to register the name.
     *
     *      The reserver must be the
     *
     * @param reservationHash The hash of the reservation.
     * @param reserver The address that reserves the name.
     */
    function reserveName(bytes32 reservationHash, address reserver) external;

    /**
     * @notice Registers a name for a portraitId.
     * @dev The name must be available, this can be checked with the `isAvailableName` function.
     *      The name must be valid syntax, this can be checked with the `isValidName` function.
     *
     *      The name must be reserved with the `reserveName` function.
     *      The reservation must not have expired.
     *
     *      The reservation does not have to be made by the caller, but the caller must know the name, secret, reserver, and portraitId.
     *      Notice that the reserver may not necessarily be the owner of the portraitId, as the reserver may be a delegate of the owner.
     *
     * @param name The name to register.
     * @param secret The secret to register the name with.
     * @param reserver The address that reserved the name.
     * @param portraitId The portraitId to register the name with.
     */
    function registerName(
        string memory name,
        string memory secret,
        address reserver,
        uint256 portraitId
    ) external;

    /*//////////////////////////////////////////////////////////////
                         VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns whether a name is available.
     * @dev A name is available if it is not registered. However, a name may be reserved by someone else, in which case it is still available to the reserver.
     *      That is because a name reservation is an undiscloseable commitment to register a name to prevent frontrunning.
     *      As a result, we can not check if a name is reserved or not, as that would allow frontrunning.
     *      Thus, multiple people may reserve the same name, but only one of them can register it.
     *
     * @param name The name to check.
     *
     * @return isAvailable True if the name is available, false otherwise.
     */
    function isAvailableName(
        string memory name
    ) external view returns (bool isAvailable);

    /**
     * @notice Returns an array of names for an array of portraitIds.
     *
     * @param portraitIds An array of portraitIds to lookup.
     *
     * @return names An array of names.
     */
    function getNamesForPortraitIds(
        uint256[] memory portraitIds
    ) external view returns (string[] memory names);

    /*//////////////////////////////////////////////////////////////
                         PURE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Generates a reservation hash.
     * @dev The reservationHash may be generated by the frontend, but it is recommended to use this function.
     *      If you generate the reservationHash yourself, use the following format:
     *      keccak256(abi.encode(name, secret));
     *
     *      The reservationHash is used to prevent frontrunning.
     *
     *      Make sure that the secret is a sufficiently random salt/string. This is to prevent brute forcing the reservationHash.
     *      Make sure to store the secret somewhere, as you will need it to register the name.
     *
     * @param name The name which may be reserved.
     * @param secret A secret which may be a randomly generated salt.
     *
     * @return reservationHash The reservation hash.
     */
    function generateReservationHash(
        string memory name,
        string memory secret
    ) external pure returns (bytes32 reservationHash);

    /**
     * @notice Checks if a name is valid.
     * @dev Name can only contain lowercase letters (a-z) and digits (0-9).
     *      Name must be between 3 and 15 characters long.
     *      Name cannot start or end with a dash.
     *      Name cannot contain two consecutive dashes.
     *
     * @param name The name to check.
     *
     * @return isValid True if the name is valid, false otherwise.
     */
    function isValidName(
        string memory name
    ) external pure returns (bool isValid);

    /*//////////////////////////////////////////////////////////////
                         PERMISSIONED ACTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the reservation duration in seconds.
     *  @dev Can only be called by the owner of the contract.
     *
     * @param timeInSeconds The time in seconds that a name reservation lasts.
     */
    function setReservationDuration(uint256 timeInSeconds) external;

    /**
     * @notice Registers a name for a portraitId as the owner of the contract.
     * @dev Can only be called by the owner of the contract.
     *
     * @param signer The signer of the signature.
     * @param name The name to register.
     * @param secret The secret to register the name with.
     * @param portraitId The portraitId to register the name with.
     * @param deadline The deadline of the signature.
     * @param owner The owner of the portraitId.
     * @param sig The signature of the owner.
     */
    function trustedRegisterName(
        address signer,
        string memory name,
        string memory secret,
        uint256 portraitId,
        uint256 deadline,
        address owner,
        bytes calldata sig
    ) external;

    /*//////////////////////////////////////////////////////////////
                            PROTOCOL HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Fetches the latest contract addresses from the PortraitContractRegistry contract and updates the state variables.
     * @dev May be called by anyone, as the state variables of the contract addresses in PortraitContractRegistry are only updatable by the owner.
     */
    function updateProtocolContracts() external;
}
