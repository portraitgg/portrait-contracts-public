// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IPortraitContractRegistry} from "./IPortraitContractRegistry.sol";
import {IPortraitIdRegistry} from "./IPortraitIdRegistry.sol";
import {IPortraitAccessRegistry} from "./IPortraitAccessRegistry.sol";
import {IPortraitPlanRegistry} from "./IPortraitPlanRegistry.sol";

interface IPortraitStateRegistry {
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
     * @notice Returns the address of the PortraitPlanRegistry contract
     */
    function portraitPlanRegistry()
        external
        view
        returns (IPortraitPlanRegistry portraitPlanRegistry);

    /*//////////////////////////////////////////////////////////////
                                 MAPPINGS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the hash (string) of a portraitId
     * @dev Mapping of portraitId => string
     */
    function portraitIdToPortraitHash(
        uint256 portraitId
    ) external view returns (string memory portraitHash);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @dev Revert with `InvalidAddress` if caller attempts to perform an action with an invalid address
    error InvalidAddress();

    /// @dev Revert with `Unauthorized` if caller attempts to perform an action without proper authorization
    error Unauthorized();

    /// @dev Revert with `DuplicateState` if caller attempts to set the state of a portrait to the same state
    error DuplicateState();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Emit an event when the state of a portrait is updated.
     *
     * @param portraitIdToSet The id of the portrait to set
     * @param portraitHash The hash of the portrait
     * @param portraitIdFromSender The id of the portrait from the sender
     */
    event PortraitStateUpdated(
        uint256 indexed portraitIdToSet,
        string portraitHash,
        uint256 indexed portraitIdFromSender
    );

    /*//////////////////////////////////////////////////////////////
                                 STATE ACTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the state of a portrait
     * @dev If not a team plan, only the owner or a delegate can set the state of a portrait.
     *      If a team plan, the editor, admin, co-owner can set the state of a portrait, in addition to the owner and delegates.
     *
     * @param portraitIdToSet The id of the portrait to set
     * @param portraitIdFromSender The id of the portrait from the sender
     * @param portraitHash The hash of the portrait
     */
    function setPortraitState(
        uint256 portraitIdToSet,
        uint256 portraitIdFromSender,
        string memory portraitHash
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
