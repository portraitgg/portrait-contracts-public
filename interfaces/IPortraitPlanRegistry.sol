// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IPortraitContractRegistry} from "./IPortraitContractRegistry.sol";
import {IPortraitIdRegistry} from "./IPortraitIdRegistry.sol";
import {IPortraitAccessRegistry} from "./IPortraitAccessRegistry.sol";
import {IPortraitSigStruct} from "../../lib/IPortraitSigStruct.sol";
import {PortraitSigValidator} from "../../lib/PortraitSigValidator.sol";

interface IPortraitPlanRegistry is IPortraitSigStruct {
    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct PlanData {
        PlanType planType;
        uint256 expirationTimestamp;
    }

    struct TeamRoleData {
        TeamRoleType roleType;
        bool hasAssigned;
        bool hasAccepted;
    }

    /*//////////////////////////////////////////////////////////////
                                 ENUMS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Enum for the different types of plans a Portrait may have
     *  @dev Listen for events of `PlanTypeSet` to get the plan type of a Portrait to update your UI.
     *
     *       Important: By default the plan is `IndividualFree`, enum 0.
     *                  Do not rely on getPlanDataForPortraitId.planType to check the plan type of a Portrait ID.
     *                  Use the `getPlanType` function to check the plan type of a Portrait ID.
     */
    enum PlanType {
        IndividualFree,
        IndividualPlus,
        Team
    }

    /**
     * @notice Enum for the different types of team roles a Portrait may have
     *  @dev Listen for events of `RoleToggled to get the team roles of a Portrait to update your UI.
     *
     *       Important: By default the role is `Member`, enum 0. This does not mean that the Portrait ID is a member of a team.
     *                  Do not rely on getTeamPortraitIdToPortraitIdToTeamRoleData.roleType to check if a Portrait ID is a member of a team.
     *                  Use the `getTeamRoleForPortraitId` function to get the role of a Portrait ID.
     *                  Alternatively, you can use the `hasTeamRole` function to check if a Portrait ID has a role.
     */
    enum TeamRoleType {
        Member,
        Editor,
        Admin,
        CoOwner,
        Owner
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
     * @notice Returns the bridge service address
     */
    function bridgeServiceAddress() external view returns (address);

    /**
     * @notice Returns the price of an Individual Plus plan, denominated in USD
     */
    function individualPlusPrice() external view returns (uint256);

    /**
     * @notice Returns the price of a Team plan, denominated in USD
     */
    function teamPrice() external view returns (uint256);

    /**
     * @notice Returns the price of a Team seat, denominated in USD
     */
    function teamSeatPrice() external view returns (uint256);

    /**
     * @notice Returns a month in unix time / seconds
     */
    function oneMonth() external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                                MAPPINGS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the amount of seats for a given portraitId
     * @dev Mapping of portraitId => amountOfSeats
     */
    function portraitIdToAmountOfSeats(
        uint256 portraitId
    ) external view returns (uint256 amountOfSeats);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @dev Revert with `Unauthorized` if caller is not authorized to perform action
    error Unauthorized();

    /// @dev Revert with `InsufficientFunds` if caller does not have enough funds to perform action
    error InsufficientFunds();

    /// @dev Revert with `InvalidAction` if caller attempts to perform an invalid action
    error InvalidAction();

    /// @dev Revert with `InvalidAddress` if caller attempts to set or call an invalid address
    error InvalidAddress();

    /// @dev Revert with `NoTeamRole` if caller does not have a team role
    error NoTeamRole();

    /// @dev Revert with `InvalidPlan` if caller attempts to set an invalid plan
    error InvalidPlan();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Emit an event when a Portrait's plan type is set
     *
     * @param portraitId The portraitId corresponding to the updated plan type
     * @param planType The plan type set for the portraitId
     * @param newExpirationTimestamp The new expiration timestamp for the portraitId
     */
    event PlanTypeSet(
        uint256 indexed portraitId,
        PlanType planType,
        uint256 newExpirationTimestamp
    );

    /**
     * @dev Emit an event when the Individual Plus price is updated.
     *
     * @param timestamp The timestamp of the update.
     * @param individualPlusPrice The new Individual Plus price.
     */
    event IndividualPlusPriceUpdated(
        uint256 indexed timestamp,
        uint256 indexed individualPlusPrice
    );

    /**
     * @dev Emit an event when the Team price is updated.
     *
     * @param timestamp The timestamp of the update.
     * @param teamPrice The new Team price.
     */

    event TeamPriceUpdated(
        uint256 indexed timestamp,
        uint256 indexed teamPrice
    );

    /**
     * @dev Emit an event when the Team seat price is updated.
     *
     * @param timestamp The timestamp of the update.
     * @param teamSeatPrice The new Team seat price.
     */
    event TeamSeatPriceUpdated(
        uint256 indexed timestamp,
        uint256 indexed teamSeatPrice
    );

    /**
     * @notice Emitted when a team role is toggled for a given address.
     * @dev The hasAssigned boolean is used to check if a role has actually been assigned to an address.
     *      The hasAccepted boolean is used to check if a team member has accepted the role assigned to them.
     *      Both booleans are required to check if a team member has a role.
     *      RoleToggled can be used to track the state of team roles.
     *
     * @param portraitId Portrait ID to toggle team role for.
     * @param portraitIdToToggle Portrait ID to toggle team role for.
     * @param role Team role type to toggle.
     * @param hasAssigned Boolean determining if a role has been assigned to an address.
     * @param hasAccepted Boolean determining if an address has accepted the role assigned to them.
     */
    event RoleToggled(
        uint256 indexed portraitId,
        uint256 indexed portraitIdToToggle,
        TeamRoleType role,
        bool hasAssigned,
        bool hasAccepted
    );

    /*//////////////////////////////////////////////////////////////
                                ROLE ACTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Toggles the team role (hasAssigned) of a portraitId in a team portraitId
     * @dev This function is used to toggle the team role of a portraitId in a team portraitId.
     *      Called by the portraitId which has authority to toggle the team role for a given portraitId (portraitIdToToggle).
     *      In essence, it will set hasAssigned to true, if hasAssigned is false.
     *      Conversely, it will set hasAssigned to false, if hasAssigned is true. It will also set hasAccepted to false, if toggled from true to false.
     *
     * @param portraitIdWithAuthority The portraitId with authority to toggle the team role for a given portraitId (portraitIdToToggle).
     * @param portraitIdOfTeam The portraitId of the team
     * @param portraitIdToToggle The portraitId to toggle the team role for.
     * @param roleType The role type to toggle.
     *
     * @return _teamRoleData Returns the team role data struct for a given address.
     */
    function toggleTeamRole(
        uint256 portraitIdWithAuthority,
        uint256 portraitIdOfTeam,
        uint256 portraitIdToToggle,
        TeamRoleType roleType
    ) external returns (TeamRoleData memory _teamRoleData);

    /// @dev Does toggleTeamRole for each portraitId in portraitIdsToToggle
    function toggleTeamRoleArray(
        uint256 portraitIdWithAuthority,
        uint256 portraitIdOfTeam,
        uint256[] calldata portraitIdsToToggle,
        TeamRoleType roleType
    ) external;

    /**
     * @notice Toggles the invite of a team role of a portraitId in a team portraitId
     * @dev This function is used to toggle the team role of a portraitId in a team portraitId.
     *      Called by the portraitId which has received the "invite" to join the team.
     *      In essence, it will set hasAccepted to true, if hasAccepted is false.
     *      Conversely, it will set hasAccepted to false, if hasAccepted is true.
     *
     * @param portraitIdWithRoleAssigned The portraitId with a role assigned to it.
     * @param portraitIdOfTeam The portraitId of the team
     *
     * @return _teamRoleData Returns the team role data struct for a given address.
     */
    function toggleTeamRoleRequest(
        uint256 portraitIdWithRoleAssigned,
        uint256 portraitIdOfTeam
    ) external returns (TeamRoleData memory _teamRoleData);

    /// @dev Does toggleTeamRoleRequest for each portraitId in portraitIdsToToggle
    function toggleTeamRoleRequestArray(
        uint256 portraitIdWithRoleAssigned,
        uint256 portraitIdOfTeam,
        uint256[] calldata portraitIdsToToggle
    ) external;

    /*//////////////////////////////////////////////////////////////
                                VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the plan type for a given portraitId
     * @dev This function is used to check the plan type of a Portrait ID.
     *
     *      Important: By default the plan is `IndividualFree`, enum 0.
     *                  Do not rely on getPlanDataForPortraitId.planType to check the plan type of a Portrait ID.
     *                  Use this function to check the plan type of a Portrait ID.
     *
     * @param portraitId The portraitId to get the plan type for
     *
     * @return planType The plan type for the portraitId
     */
    function getPlanType(uint256 portraitId) external view returns (PlanType);

    /**
     * @notice Returns a boolean indicating if a portraitId is a team portraitId
     * @dev This function is used to check if a Portrait ID is a team.
     *      This function is somewhat redundant, as the `getPlanType` function can be used to check if a Portrait ID is a team.
     *      However, this function may result in more readable code.
     *
     * @param portraitId The portraitId to check if it is a team
     *
     * @return isTeam A boolean indicating if the portraitId is a team
     */
    function isTeamPlan(uint256 portraitId) external view returns (bool isTeam);

    /**
     * @notice Returns the role of a portraitId in a team portraitId
     * @dev This function is used to return the role of a portraitId in a team portraitId.
     *      If the portraitIdWithPotentialRole does not have a role in the team portraitId, the function will revert with `NoTeamRole`.
     *      If the portraitIdOfTeam is not a team portraitId, the function will revert with `InvalidPlan`.
     *
     * @param portraitIdWithPotentialRole The portraitId to get the role for
     * @param portraitIdOfTeam The portraitId of the team which the portraitIdWithPotentialRole is a member of
     *
     * @return role The role of the portraitId
     */
    function getTeamRoleForPortraitId(
        uint256 portraitIdWithPotentialRole,
        uint256 portraitIdOfTeam
    ) external view returns (TeamRoleType role);

    /**
     * @notice Returns if a portraitId has a team role in a team portraitId
     * @dev This function is used to check if a Portrait ID has a role in a team.
     *      Returns true if the portraitId has a role, false if not.
     *
     * @param portraitIdWithPotentialRole The portraitId to check if it has a role.
     * @param portraitIdOfTeam The portraitId of the team to check if the portraitId has a role.
     * @param roleType The role type to check.
     */
    function hasTeamRole(
        uint256 portraitIdWithPotentialRole,
        uint256 portraitIdOfTeam,
        TeamRoleType roleType
    ) external view returns (bool);

    /**
     * @notice Returns the plan data for a portraitId
     * @dev portraitIdToPlanData is a mapping of portraitId => PlanData. Because PlanData is a struct, we cannot define the mapping in the interface.
     *      This function allows other contracts to fetch the plan data for a portraitId when implementing the interface.
     *      Declared as public due to Chainlink data feed contract.
     *
     *      Important: Do not rely on getPlanDataForPortraitId.planType to check the plan type of a Portrait ID.
     *                 Use the `getPlanType` function to check the plan type of a Portrait ID.     *
     *
     * @param portraitId The portraitId to get the plan data for
     *
     * @return planData The plan data for the portraitId
     */
    function getPlanDataForPortraitId(
        uint256 portraitId
    ) external view returns (PlanData memory planData);

    /**
     * @notice Returns the TeamRoleType Data for a given portraitId (portraitIdWithPotentialRole) in a (team) portraitId (portraitIdOfTeam).
     * @dev This function only returns data from the teamPortraitIdToPortraitIdToTeamRoleData mapping, not the actual role of the portraitId.
     *
     *      Important: By default the role is `Member`, enum 0. This does not mean that the Portrait ID is a member of a team.
     *                  Do not rely on getTeamPortraitIdToPortraitIdToTeamRoleData.roleType to check if a Portrait ID is a member of a team.
     *                  Use the `getTeamRoleForPortraitId` function to get the role of a Portrait ID.
     *                  Alternatively, you can use the `hasTeamRole` function to check if a Portrait ID has a role.
     *
     * @param portraitIdWithPotentialRole The portraitId to check if it has a role.
     * @param portraitIdOfTeam The portraitId of the team to check if the portraitId has a role.
     *
     * @return role The role of the portraitId
     */
    function getTeamPortraitIdToPortraitIdToTeamRoleData(
        uint256 portraitIdOfTeam,
        uint256 portraitIdWithPotentialRole
    ) external view returns (TeamRoleData memory);

    /**
     * @notice Returns the price of an Individual Plus plan, denominated in wei
     * @dev This function is used to calculate the amount of ETH to send to the contract when calling `setPlanType` with a plan type of `IndividualPlus`.
     *
     * @return priceInWei The price of an Individual Plus plan, denominated in wei
     */
    function getIndividualPlusPriceInWei()
        external
        view
        returns (uint256 priceInWei);

    /**
     * @notice Returns the price of a Team plan, denominated in wei
     * @dev This function is used to calculate the amount of ETH to send to the contract when calling `setPlanType` with a plan type of `Team`.
     *      Declared as public due to Chainlink data feed contract.
     *
     * @return priceInWei The price of a Team plan, denominated in wei
     */
    function getTeamPriceInWei() external view returns (uint256 priceInWei);

    /**
     * @notice Returns the price of a Team seat, denominated in wei
     * @dev This function is used to calculate the amount of ETH to send to the contract when calling `setPlanType` with a plan type of `Team`.
     *      Declared as public due to Chainlink data feed contract.
     *
     * @return priceInWei The price of a Team seat, denominated in wei
     */
    function getTeamSeatPriceInWei() external view returns (uint256 priceInWei);

    /*//////////////////////////////////////////////////////////////
                         PERMISSIONED ACTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the plan type for a specific portrait ID.
     * @dev This function is used to set the plan type for a Portrait ID.
     *      This function is permissioned to only be called by the bridge service address (bridgeServiceAddress).
     *
     *
     * @param portraitId The portraitId to set the plan type for
     * @param planType The plan type to set for the portraitId
     * @param caller The msg.sender of the transaction sent to the bridge contract (bridgeCalled event in PortraitPlanBridge.sol)
     * @param weiAmount The amount of wei sent the caller sent to the bridge contract (bridgeCalled event in PortraitPlanBridge.sol)
     */
    function setPlanType(
        uint256 portraitId,
        PlanType planType,
        address caller,
        uint256 weiAmount
    ) external;

    /**
     * @notice Sets the price of an Individual Plus plan, denominated in USD
     * @dev This function is permissioned to only be called by the owner of the contract.
     *
     * @param newIndividualPlusPrice The price of an Individual Plus plan, denominated in USD
     */
    function setIndividualPlusPrice(uint256 newIndividualPlusPrice) external;

    /**
     * @notice Sets the price of a Team plan, denominated in USD
     * @dev This function is permissioned to only be called by the owner of the contract.
     *
     * @param newTeamPrice The price of a Team plan, denominated in USD
     */
    function setTeamPrice(uint256 newTeamPrice) external;

    /**
     * @notice Sets the price of a Team seat, denominated in USD
     * @dev This function is permissioned to only be called by the owner of the contract.
     *
     * @param newTeamSeatPrice The price of a Team seat, denominated in USD
     */
    function setTeamSeatPrice(uint256 newTeamSeatPrice) external;

    /**
     * @notice Sets the bridge service address
     * @dev This function is permissioned to only be called by the owner of the contract.
     *
     * @param newBridgeServiceAddress The new bridge service address
     */
    function setBridgeServiceAddress(address newBridgeServiceAddress) external;

    /**
     * @notice Sends funds of the contract to a recipient
     * @dev This function is permissioned to only be called by the owner of the contract.
     *
     * @param recipient The address to send the funds to
     * @param amount The amount of funds to send, denominated in wei
     */
    function sendFunds(address payable recipient, uint256 amount) external;

    /**
     * @notice Sets the address of the Chainlink data feed contract
     * @dev This function is permissioned to only be called by the owner of the contract.
     *      For more information on Chainlink data feeds, see https://docs.chain.link/data-feeds/price-feeds/
     *
     * @param newDataFeed The address of the Chainlink data feed contract
     */
    function setChainlinkDataFeed(address newDataFeed) external;

    /*//////////////////////////////////////////////////////////////
                            PROTOCOL HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Fetches the latest contract addresses from the PortraitContractRegistry contract and updates the state variables.
     * @dev May be called by anyone, as the state variables of the contract addresses in PortraitContractRegistry are only updatable by the owner.
     */
    function updateProtocolContracts() external;
}
