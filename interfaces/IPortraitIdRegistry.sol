// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IPortraitContractRegistry} from "./IPortraitContractRegistry.sol";
import {IPortraitAccessRegistry} from "./IPortraitAccessRegistry.sol";
import {IPortraitNameRegistry} from "./IPortraitNameRegistry.sol";
import {IPortraitSigStruct} from "../../lib/IPortraitSigStruct.sol";
import {PortraitSigValidator} from "../../lib/PortraitSigValidator.sol";

interface IPortraitIdRegistry is IPortraitSigStruct {
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
     * @notice Returns the address of the PortraitAccessRegistry contract
     */
    function portraitAccessRegistry()
        external
        view
        returns (IPortraitAccessRegistry portraitAccessRegistry);

    /**
     * @notice Returns the address of the PortraitNameRegistry contract
     */
    function portraitNameRegistry()
        external
        view
        returns (IPortraitNameRegistry portraitNameRegistry);

    /**
     * @notice Returns the address of the PortraitSigValidator contract
     */
    function portraitSigValidator()
        external
        view
        returns (PortraitSigValidator portraitSigValidator);

    /**
     * @notice Global counter for the total number of Portrait IDs (portraitIds) created.
     * @dev Burned portraitIds are included in this count, this is not the total number of portraitIds in existence.
     */
    function portraitIdCounter()
        external
        view
        returns (uint256 portraitIdCounter);

    /**
     * @notice Returns if the contract is in a controlled registration period
     * @dev During a controlled registration period, only the owner of the contract can register portraitIds
     *      After the controlled registration period, anyone can register portraitIds
     *
     */
    function isControlledRegistrationPeriod()
        external
        view
        returns (bool isControlled);

    /**
     * @notice Returns the base URI for all tokenized portraitIds
     */
    function baseURI() external view returns (string memory baseURI);

    /*//////////////////////////////////////////////////////////////
                                 MAPPINGS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the owner (address) of a portraitId
     * @dev Mapping of portraitId => address
     */
    function portraitIdToOwner(
        uint256 portraitId
    ) external view returns (address owner);

    /**
     * @notice Returns the primary portraitId of an address
     * @dev Mapping of address => uint256
     */
    function ownerToPrimaryPortraitId(
        address owner
    ) external view returns (uint256 portraitId);

    /**
     * @notice Returns the amount of portraitIds owned by an address
     * @dev Mapping of address => uint256
     */
    function ownerToPortraitIdCount(
        address owner
    ) external view returns (uint256 portraitIdCount);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @dev Error when caller is not authorized to perform action
    error Unauthorized();

    /// @dev Error when signature is expired
    error ExpiredSignature();

    /// @dev Error when signature is invalid
    error InvalidSignature();

    /// @dev Error when portraitId is already minted
    error ExceedsSupply();

    /// @dev Error when a tokenized portraitId calls a function that is only allowed for non-tokenized portraitIds
    error AsNFT();

    /// @dev Error when a non-existent portraitId is requested
    error NonExistentPortraitId();

    /// @dev Revert with `InvalidAddress` if caller attempts to perform an action with an invalid address
    error InvalidAddress();

    /// @dev Revert with `ControlledRegistrationPeriod` if caller attempts to register a portraitId during a controlled registration period
    error ControlledRegistrationPeriod();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emit an event when a Portrait is registered
     * @dev This event is used to keep track of portraitIds and their owners
     *
     * @param portraitId The portraitId that was registered
     * @param owner The owner of the portraitId
     */
    event PortraitRegistered(uint256 indexed portraitId, address indexed owner);

    /**
     * @notice Emit an event when a Portrait is transferred
     * @dev This event is used to keep track of the owner of a portraitId
     *
     * @param portraitId The portraitId that was transferred
     * @param from The previous owner of the portraitId
     * @param to The new owner of the portraitId
     */
    event PortraitTransferred(
        uint256 indexed portraitId,
        address indexed from,
        address indexed to
    );

    /*//////////////////////////////////////////////////////////////
                             REGISTRATION ACTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Register a new Portrait ID (portraitId) to the caller.
     *
     * @param owner       Address which will own the portraitId.
     * @param reservationHash The reservation hash of the name to register.
     * @param delegate Address which will have the hasAssigned set to true for the delegate data.
     *
     * @return portraitId registered Portrait ID.
     */
    function register(
        address owner,
        bytes32 reservationHash,
        address delegate
    ) external returns (uint256 portraitId);

    /**
     * @notice Register a new Portrait ID (portraitId) to any address. A signed message from the address
     *         must be provided which approves both the owner.
     *
     * @param signer    Address which signed the message, should be a delegate or owner.
     * @param owner       Address which will own the portraitId.
     * @param reservationHash       The reservation hash of the name to register.
     * @param delegate Address which will have the hasAssigned set to true for the delegate data.
     * @param deadline Expiration timestamp of the signature.
     * @param sig      EIP-6492 Register signature signed by the owner address.
     *
     * @return portraitId registered Portrait ID.
     */
    function registerFor(
        address signer,
        address owner,
        bytes32 reservationHash,
        address delegate,
        uint256 deadline,
        bytes calldata sig
    ) external returns (uint256 portraitId);

    /*//////////////////////////////////////////////////////////////
                         TRANSFER ACTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Transfer a Portrait ID to a new owner.
     * @dev Co-owner can't transfer portraitId.
     *
     * @param portraitId Portrait ID to transfer.
     * @param to        Address to transfer the portraitId to.
     */
    function transferPortraitId(uint256 portraitId, address to) external;

    /**
     * @notice Transfer a Portrait ID to a new owner using a signed message.
     *
     * @param portraitId Portrait ID to transfer.
     * @param from      Address to transfer the portraitId from.
     * @param to        Address to transfer the portraitId to.
     * @param deadline Expiration timestamp of the signature.
     * @param sig      EIP-6492 Transfer signature signed by the from address.
     */
    function transferPortraitIdFor(
        uint256 portraitId,
        address from,
        address to,
        uint256 deadline,
        bytes calldata sig
    ) external;

    /*//////////////////////////////////////////////////////////////
                              STATE ACTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Set the primary portraitId for an address, called by the owner or delegate of the Portrait ID.
     *
     * @param owner       Owner of the portraitId.
     * @param portraitId  The portraitId to set as primary.
     */
    function setPrimaryPortrait(address owner, uint256 portraitId) external;

    /**
     * @notice Set the primary portraitId for an address, called with a signed message.
     * @dev It is not possible to create a signed message as a delegate to set the primary portraitId.
     *
     * @param signer   Address which signed the message, should be a delegate or owner.
     * @param owner      Owner of the portraitId.
     * @param portraitId The portraitId to set as primary.
     * @param deadline Expiration timestamp of the signature.
     * @param sig      EIP-6492 Set Primary signature signed by the owner or delegate address.
     */
    function setPrimaryPortraitFor(
        address signer,
        address owner,
        uint256 portraitId,
        uint256 deadline,
        bytes calldata sig
    ) external;

    /*//////////////////////////////////////////////////////////////
                            HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Verify a register signature.
     *
     * @param signer     Address which signed the message, should be a delegate or owner.
     * @param owner       Address which will own the portraitId.
     * @param reservationHash       The reservation hash of the name to register.
     * @param delegate Address which will have the hasAssigned set to true for the delegate data.
     * @param deadline Expiration timestamp of the signature.
     * @param sig      EIP-6492 Register signature signed by the owner address.
     *
     * @return isValid Returns if the signature is valid.
     */
    function verifyRegisterFor(
        address signer,
        address owner,
        bytes32 reservationHash,
        address delegate,
        uint256 deadline,
        bytes calldata sig
    ) external returns (bool isValid);

    /**
     * @notice Verify a transfer signature.
     *
     * @param portraitId Portrait ID to transfer.
     * @param from      Address to transfer the portraitId from.
     * @param to        Address to transfer the portraitId to.
     * @param deadline Expiration timestamp of the signature.
     * @param sig      EIP-6492 Transfer signature signed by the from address.
     *
     * @return isValid Returns if the signature is valid.
     */
    function verifyTransferFor(
        uint256 portraitId,
        address from,
        address to,
        uint256 deadline,
        bytes calldata sig
    ) external returns (bool isValid);

    /*//////////////////////////////////////////////////////////////
                         VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks if a potential owner owns a portraitId
     *
     * @param potentialOwner The owner which potentially owns the portraitId
     * @param portraitId The portraitId to check if the potential owner owns
     *
     * @return isOwner Boolean indicating if the owner is the owner of the portraitId
     */
    function isOwnerOfPortraitId(
        address potentialOwner,
        uint256 portraitId
    ) external view returns (bool isOwner);

    /**
     * @notice Get owners for an array of portraitIds
     *
     * @param portraitIds Array of portraitIds to check if the potential owner owns
     *
     * @return owners Array of owners for the portraitIds
     */
    function getOwnersForPortraitIds(
        uint256[] calldata portraitIds
    ) external view returns (address[] memory owners);

    /*//////////////////////////////////////////////////////////////
                         PERMISSIONED ACTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Register a new Portrait ID to any address.
     *         Can only be called by the owner of the contract.
     *         This function makes it possible to register a Portrait ID when the contract is paused.
     *
     * @param signer    Address which signed the message, should be a delegate or owner.
     * @param owner The address which will own the portraitId.
     * @param reservationHash       The reservation hash of the name to register.
     * @param delegate       The address which will have the hasAssigned set to true for the delegate data.
     * @param deadline Expiration timestamp of the signature.
     * @param sig      EIP-6492 Register signature signed by the owner address.
     *
     * @return portraitId registered Portrait ID.
     */
    function trustedRegister(
        address signer,
        address owner,
        bytes32 reservationHash,
        address delegate,
        uint256 deadline,
        bytes calldata sig
    ) external returns (uint256 portraitId);

    /**
     * @notice Sets the base URI for all tokenized portraitIds
     * @dev Can only be called by the owner of the contract.
     *
     * @param newBaseURI The base URI to set
     */
    function setBaseURI(string memory newBaseURI) external;

    /**
     * @notice Toggles the controlled registration period
     * @dev Can only be called by the owner of the contract.
     */
    function toggleIsControlledRegistrationPeriod() external;

    /*//////////////////////////////////////////////////////////////
                          PROTOCOL HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Fetches the latest contract addresses from the PortraitContractRegistry contract and updates the state variables.
     * @dev May be called by anyone, as the state variables of the contract addresses in PortraitContractRegistry are only updatable by the owner.
     */
    function updateProtocolContracts() external;
}
