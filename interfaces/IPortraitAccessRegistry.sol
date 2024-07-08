// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IPortraitContractRegistry} from "./IPortraitContractRegistry.sol";
import {IPortraitIdRegistry} from "./IPortraitIdRegistry.sol";
import {IPortraitSigStruct} from "../../lib/IPortraitSigStruct.sol";
import {PortraitSigValidator} from "../../lib/PortraitSigValidator.sol";

interface IPortraitAccessRegistry is IPortraitSigStruct {
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
     * @notice Struct for a delegate data.
     * @dev The hasAssigned boolean is used to check if a delegate has actually been assigned to an address.
     *      The hasAccepted boolean is used to check if a delegate has accepted the role assigned to them.
     */
    struct DelegateData {
        bool hasAssigned;
        bool hasAccepted;
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
     * @notice Returns the address of the PortraitSigValidator contract
     */
    function portraitSigValidator()
        external
        view
        returns (PortraitSigValidator portraitSigValidator);

    /**
     * @notice Returns the address of the delegateServiceAddress
     * @dev This address can be used to pay for gas fees for delegate transactions as a service.
     *      Use `setDelegateServiceAddress` to update this address as the contract owner.
     */
    function delegateServiceAddress()
        external
        view
        returns (address delegateServiceAddress);

    /**
     * @notice Returns the maximum amount of delegates an address/owner can have.
     * @dev Use `setMaxDelegates` to update this value as the contract owner.
     *      The delegateService address is exempt from this limit.
     */
    function maxDelegates() external view returns (uint256 maxDelegates);

    /*//////////////////////////////////////////////////////////////
                                 MAPPINGS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Mapping of an owner/address to the amount of delegates an address has.
     * @dev This mapping is used to check the amount of delegates an address has.
     *      Use `maxDelegates` to check the maximum amount of delegates an address can have.
     *
     * @param owner Address to check the amount of delegates for.
     * @return amountOfDelegates Returns the amount of delegates an address has.
     */
    function ownerToAmountOfDelegates(
        address owner
    ) external view returns (uint256 amountOfDelegates);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @dev Revert with `Unauthorized` if caller is not authorized to perform action
    error Unauthorized();

    /// @dev Revert with `NoRole` if caller has not been assigned a team role
    error NoRole();

    /// @dev Revert with `InvalidRole` if caller has an invalid role
    error InvalidRole();

    /// @dev Revert with `InvalidAction` if caller attempts to perform an invalid action
    error InvalidAction();

    /// @dev Revert with `InvalidSignature` if caller attempts to perform an action with an invalid signature
    error InvalidSignature();

    /// @dev Revert with `ExpiredSignature` if caller attempts to perform an action with an expired signature
    error ExpiredSignature();

    /// @dev Revert with `InvalidAddress` if caller attempts to perform an action with an invalid address
    error InvalidAddress();

    /// @dev Revert with `MaxDelegatesReached` if caller attempts to perform an action with an invalid address
    error MaxDelegatesReached();

    /// @dev Revert with `InvalidArrayLength` if caller attempts to perform an action with an invalid array length
    error InvalidArrayLength();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when a delegate is toggled for a given address.
     * @dev The hasAssigned boolean is used to check if an address has actually been assigned a delegate role.
     *      The hasAccepted boolean is used to check if an address has accepted the delegate role assigned to them.
     *      Both booleans are required to check if an address has a delegate role.
     *      DelegateToggled can be used to track the state of delegates.
     *
     * @param owner Address to toggle delegate status for.
     * @param delegate Address which has delegate rights for a given portraitId.
     * @param hasAssigned Boolean determining if an address has been assigned as a delegate.
     * @param hasAccepted Boolean determining if an address has accepted the role assigned to them.
     */
    event DelegateToggled(
        address indexed owner,
        address indexed delegate,
        bool hasAssigned,
        bool hasAccepted
    );

    /*//////////////////////////////////////////////////////////////
                        DELEGATE ACTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Toggles the delegate status of an address for a given delegate. Can only be called by the owner or delegate.
     * @dev Because the delegate is toggled, the hasAccepted boolean should be set to false, as the delegate has not accepted the role yet.
     *      In the application, the delegate will be notified that they have been assigned as a delegate, and they will have to accept the role.
     *
     *      If the hasAssigned is true, and the request is accepted, the hasAccepted boolean will be set to true.
     *
     *      Important:
     *      If hasAssigned is true, and the request is denied, the hasAccepted boolean will REMAIN false.
     *      There will be no transaction updating the hasAccepted boolean.
     *
     *      It is the responsibility of the application to:
     *       (1) Notify the owner that the request has been rejected by the delegate.
     *       (2) To remove the delegate from the list of pending requests in the application for the owner.
     *       (3) To remove the request from the list of pending requests in the application for the delegate.
     *
     *      In light of the above, different applications may have different ways of handling the rejection of a delegate request.
     *      Nevertheless, it is highly recommended, for the sake of decentralization, to broadcast the state of requests in the application to a
     *      permissionless network, such as Waku. Additionally, using signed messages by the delegate as a way to accept or reject a request is
     *      highly recommended, as it will allow for a tamper-proof method of accepting or rejecting a request.
     *
     *      MUST: Emits a DelegateToggled event to keep track of delegates.
     *
     * @param owner Address to toggle delegate status for.
     * @param delegate Address to toggle delegate status for.
     *
     * @return delegateData Returns the delegate data struct for a given delegate.
     */
    function toggleDelegate(
        address owner,
        address delegate
    ) external returns (DelegateData memory delegateData);

    /**
     * @notice Toggles the delegate status of an array of addresses for a given delegate. Can only be called by the owner or delegate.
     * @dev See toggleDelegate for more information.
     *      Returns nothing because it is called in a loop.
     *
     * @param owner Address to toggle delegate status for.
     * @param delegates Array of addresses to toggle delegate status for.
     */
    function toggleDelegateArray(
        address owner,
        address[] calldata delegates
    ) external;

    /**
     * @notice Toggles the delegate request status (hasAccepted) of an address. Can only be called by the address (or the delegate of that address) who has the delegate assigned.
     *
     * @param owner Owner of the portraitId
     * @param delegate Address to toggle delegate status for as hasAssigned
     *
     * @return delegateData Returns the delegate data struct for a given delegate
     */
    function toggleDelegateRequest(
        address owner,
        address delegate
    ) external returns (DelegateData memory delegateData);

    /**
     * @notice Toggles the delegate status of an array of addresses for a given delegate. Can only be called by the owner or delegate.
     * @dev See toggleDelegate for more information.
     *      Returns nothing because it is called in a loop.
     *
     * @param owner Address to toggle delegate status for.
     * @param delegates Array of addresses to toggle delegate status for.
     */
    function toggleDelegateRequestArray(
        address owner,
        address[] calldata delegates
    ) external;

    /**
     * @notice Toggles the delegate status of an address for a given delegate. Can only be called by the address (or the delegate of that address) who has the delegate assigned.
     * @dev This function is called by a user to toggle the hasAssigned boolean for a proposed delegate with a signed message.
     *      If hasAssigned will become false, the hasAccepted boolean will also become false.
     *
     * @param caller Address which has delegate or owner rights for a given portraitId, also the address which has signed the message.
     * @param owner Owner of the portraitId
     * @param delegate Address which has delegate rights assigned and wants to toggle the hasAssigned boolean
     * @param currentHasAssigned Current hasAssigned boolean of the delegate
     * @param deadline Deadline for the signed message
     * @param sig Signature of the signed message
     *
     * @return delegateData Returns the delegate data struct for a given delegate
     */
    function toggleDelegateFor(
        address caller,
        address owner,
        address delegate,
        bool currentHasAssigned,
        uint256 deadline,
        bytes calldata sig
    ) external returns (DelegateData memory delegateData);

    /**
     * @notice Toggles the delegate request status (hasAccepted) of an address. Can only be called by the address (or the delegate of that address) who has the delegate assigned.
     * @dev This function is called by a user to toggle the hasAccepted boolean for a proposed delegate with a signed message.
     *      The currentHasAccepted boolean prevents replay attacks.
     *
     * @param caller Address which has delegate or owner rights for a given portraitId, also the address which has signed the message.
     * @param owner Owner of the portraitId
     * @param delegate Address which has delegate rights assigned and wants to toggle the hasAccepted boolean
     * @param currentHasAccepted Current hasAccepted boolean of the delegate
     * @param deadline Deadline for the signed message
     * @param sig Signature of the signed message
     *
     * @return delegateData Returns the delegate data struct for a given delegate
     */
    function toggleDelegateRequestFor(
        address caller,
        address owner,
        address delegate,
        bool currentHasAccepted,
        uint256 deadline,
        bytes calldata sig
    ) external returns (DelegateData memory delegateData);

    /*//////////////////////////////////////////////////////////////
                         VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the team role data for a given address.
     * @dev OwnerToAddressToDelegateData is a mapping of address => address => DelegateData.
     *       Because DelegateData is a struct, we cannot define the mapping in the interface.
     *       Additionally, because the mapping is nested, we cannot define the mapping in the interface.
     *
     * @param owner The address which potentially has a delegates assigned to it.
     * @param potentialDelegate The address to get the delegate data for
     *
     * @return delegateData The delegate data for the address
     */
    function getOwnerToAddressToDelegateData(
        address owner,
        address potentialDelegate
    ) external view returns (DelegateData memory delegateData);

    /**
     * @notice Checks if an address is a delegate for a given portraitId.
     * @dev This function is used to check if an address is a delegate for a given portraitId.
     *
     * @param portraitId Portrait ID to check delegate status for.
     * @param delegate Address which has delegate rights for a given portraitId.
     *
     * @return isDelegate Returns if the given address is a delegate for a given portraitId.
     */
    function isDelegateOfPortraitId(
        uint256 portraitId,
        address delegate
    ) external view returns (bool isDelegate);

    /**
     * @notice Checks if an address is a delegate for a given owner/address.
     * @dev This function is used to check if an address is a delegate for a given owner/address.
     *
     * @param owner Address to check delegate status for.
     * @param delegate Address which has delegate rights for a given owner.
     *
     * @return isDelegate Returns if the given address is a delegate for a given owner.
     */
    function isDelegateOfAddress(
        address owner,
        address delegate
    ) external view returns (bool isDelegate);

    /**
     * @notice Checks if an address is a delegate for a given portraitId.
     * @dev This function is used to check if an address is a delegate for a given portraitId or owner.
     *
     * @param portraitId Portrait ID to check delegate status for.
     * @param caller Address which has delegate rights for a given portraitId.
     *
     * @return isDelegateOrOwner Returns if the given address is a delegate or owner for a given portraitId.
     */
    function isDelegateOrOwnerOfPortraitId(
        uint256 portraitId,
        address caller
    ) external view returns (bool isDelegateOrOwner);

    /*//////////////////////////////////////////////////////////////
                         PERMISSIONED ACTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the address of the IPortraitContractRegistry contract
     * @dev This function is permissioned to only be called by the owner of the contract.
     *      The delegateService address can be used to pay for gas fees for delegate transactions as a service.
     *
     * @param newDelegateServiceAddress The address of the delegateService.
     */
    function setDelegateServiceAddress(
        address newDelegateServiceAddress
    ) external;

    /**
     * @notice Sets the maximum amount of delegates an address/owner can have.
     * @dev This function is permissioned to only be called by the owner of the contract.
     *      The maxDelegates is used to check the maximum amount of delegates an address can have.
     *
     * @param newMaxDelegates The new maximum amount of delegates an address/owner can have.
     */
    function setMaxDelegates(uint256 newMaxDelegates) external;

    /*//////////////////////////////////////////////////////////////
                            HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns if a signature is valid for a toggle delegate request (hasAssigned)
     *
     * @param signer The address which has delegate or owner rights for a given portraitId, also the address which has signed the message.
     * @param owner Owner of the portraitId
     * @param delegate Address which the hasAssigned boolean should be toggled for
     * @param currentHasAssigned Current hasAssigned boolean of the delegate
     * @param deadline Deadline for the signed message
     * @param sig Signature of the signed message
     */
    function verifyToggleDelegateFor(
        address signer,
        address owner,
        address delegate,
        bool currentHasAssigned,
        uint256 deadline,
        bytes calldata sig
    ) external returns (bool isValid);

    /**
     * @notice Returns if a signature is valid for a toggle delegate request (hasAccepted)
     *
     * @param signer The address which has delegate or owner rights for a given portraitId, also the address which has signed the message.
     * @param owner Owner of the portraitId
     * @param delegate Address which the hasAccepted boolean should be toggled for
     * @param currentHasAccepted Current hasAccepted boolean of the delegate
     * @param deadline Deadline for the signed message
     * @param sig Signature of the signed message
     */
    function verifyToggleDelegateRequestFor(
        address signer,
        address owner,
        address delegate,
        bool currentHasAccepted,
        uint256 deadline,
        bytes calldata sig
    ) external returns (bool isValid);

    /*//////////////////////////////////////////////////////////////
                            PROTOCOL HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Fetches the latest contract addresses from the PortraitContractRegistry contract and updates the state variables.
     * @dev May be called by anyone, as the state variables of the contract addresses in PortraitContractRegistry are only updatable by the owner.
     */
    function updateProtocolContracts() external;
}
