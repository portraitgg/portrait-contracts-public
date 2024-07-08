// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../../interfaces/l2/IPortraitPlanRegistry.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/// @custom:security-contact ryan@portrait.gg
contract PortraitPlanRegistry is
    IPortraitPlanRegistry,
    Initializable,
    PausableUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    /*//////////////////////////////////////////////////////////////
                                 VARIABLES
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IPortraitPlanRegistry
     */
    IPortraitContractRegistry public portraitContractRegistry;

    /**
     * @inheritdoc IPortraitPlanRegistry
     */
    IPortraitIdRegistry public portraitIdRegistry;

    /**
     * @inheritdoc IPortraitPlanRegistry
     */
    IPortraitAccessRegistry public portraitAccessRegistry;

    /**
     * @inheritdoc IPortraitPlanRegistry
     */
    PortraitSigValidator public portraitSigValidator;

    /**
     * @inheritdoc IPortraitPlanRegistry
     */
    address public bridgeServiceAddress;

    /**
     * @inheritdoc IPortraitPlanRegistry
     */
    uint256 public individualPlusPrice;

    /**
     * @inheritdoc IPortraitPlanRegistry
     */
    uint256 public teamPrice;

    /**
     * @inheritdoc IPortraitPlanRegistry
     */
    uint256 public teamSeatPrice;

    /**
     * @inheritdoc IPortraitPlanRegistry
     */
    uint256 public oneMonth;

    /// @dev The data feed contract is set in the initialize function, use `setChainlinkDataFeed` to update.
    AggregatorV3Interface internal dataFeed;

    /*//////////////////////////////////////////////////////////////
                                MAPPINGS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IPortraitPlanRegistry
     */
    mapping(uint256 => uint256) public portraitIdToAmountOfSeats;

    /**
     * @notice Mapping of portraitId to a Plan struct
     * @dev Can not be defined in the interface, as structs are not supported.
     *      Use `get
     *
     *      Important: Do not rely on getPlanDataForPortraitId.planType to check if a Portrait ID is a member of a team.
     *
     */
    mapping(uint256 => PlanData) public portraitIdToPlanData;

    /**
     * @notice Mapping of portraitId of a team to portraitId of a team member to TeamRoleData struct
     * @dev Can not be defined in the interface, as structs are not supported. Neither are nested mappings.
     *      Use `getTeamPortraitIdToPortraitIdToTeamRoleData` to access this mapping.
     *
     *      Important: Do not rely on getTeamPortraitIdToPortraitIdToTeamRoleData.roleType to check if a Portrait ID is a member of a team.
     *                 Use the `getTeamRoleForPortraitId` function to get the role of a Portrait ID.
     *                 Alternatively, you can use the `hasTeamRole` function to check if a Portrait ID has a role.
     */
    mapping(uint256 => mapping(uint256 => TeamRoleData))
        public teamPortraitIdToPortraitIdToTeamRoleData;

    /*//////////////////////////////////////////////////////////////
                                ROLE ACTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IPortraitPlanRegistry
     */
    function toggleTeamRole(
        uint256 portraitIdWithAuthority,
        uint256 portraitIdOfTeam,
        uint256 portraitIdToToggle,
        TeamRoleType roleType
    ) external whenNotPaused returns (TeamRoleData memory _teamRoleData) {
        if (
            !portraitAccessRegistry.isDelegateOrOwnerOfPortraitId(
                portraitIdWithAuthority,
                msg.sender
            )
        ) revert Unauthorized();

        return
            _toggleTeamRole(
                portraitIdWithAuthority,
                portraitIdOfTeam,
                portraitIdToToggle,
                roleType
            );
    }

    /**
     * @inheritdoc IPortraitPlanRegistry
     */
    function toggleTeamRoleArray(
        uint256 portraitIdWithAuthority,
        uint256 portraitIdOfTeam,
        uint256[] calldata portraitIdsToToggle,
        TeamRoleType roleType
    ) external whenNotPaused {
        if (
            !portraitAccessRegistry.isDelegateOrOwnerOfPortraitId(
                portraitIdWithAuthority,
                msg.sender
            )
        ) revert Unauthorized();

        uint256 length = portraitIdsToToggle.length;

        for (uint256 i = 0; i < length; i++) {
            _toggleTeamRole(
                portraitIdWithAuthority,
                portraitIdOfTeam,
                portraitIdsToToggle[i],
                roleType
            );
        }
    }

    function _toggleTeamRole(
        uint256 portraitIdWithAuthority,
        uint256 portraitIdOfTeam,
        uint256 portraitIdToToggle,
        TeamRoleType newRoleType
    ) internal returns (TeamRoleData memory _teamRoleData) {
        if (!_isTeamPlan(portraitIdOfTeam)) revert InvalidPlan();

        bool isOwner = _hasTeamRole(
            portraitIdWithAuthority,
            portraitIdOfTeam,
            TeamRoleType.Owner
        );

        // This is to prevent the owner from accidentally removing themselves from the team.
        // In _getTeamRoleForPortraitId() the owner is automatically assigned the owner role, so this is not a security issue, just a UX issue.
        if (isOwner && portraitIdWithAuthority == portraitIdToToggle) {
            revert InvalidAction();
        }

        if (portraitIdWithAuthority != portraitIdOfTeam) {
            bool isCoOwner = _hasTeamRole(
                portraitIdWithAuthority,
                portraitIdOfTeam,
                TeamRoleType.CoOwner
            );

            bool isAdmin = _hasTeamRole(
                portraitIdWithAuthority,
                portraitIdOfTeam,
                TeamRoleType.Admin
            );

            if (!isOwner && !isCoOwner && !isAdmin) {
                revert Unauthorized();
            }

            // If role is lower than current role, automatically accept IF the current role is already accepted.
            // This means that a higher role can demote a team member without their consent.
            // Conversely, if the role is higher than the current role, do not automatically accept:
            // You could envision a scenario in which Vitalik is a team member, and he is promoted to admin, but he does not want to be an admin.
            // And that the forced admin role is being used by bad actors for zero-sum promtionary purposes.
            if (
                newRoleType <
                _getTeamRoleForPortraitId(portraitIdToToggle, portraitIdOfTeam)
            ) {
                teamPortraitIdToPortraitIdToTeamRoleData[portraitIdOfTeam][
                    portraitIdToToggle
                ].roleType = newRoleType;

                emit RoleToggled(
                    portraitIdOfTeam,
                    portraitIdToToggle,
                    newRoleType,
                    teamPortraitIdToPortraitIdToTeamRoleData[portraitIdOfTeam][
                        portraitIdToToggle
                    ].hasAssigned,
                    teamPortraitIdToPortraitIdToTeamRoleData[portraitIdOfTeam][
                        portraitIdToToggle
                    ].hasAccepted
                );

                return
                    teamPortraitIdToPortraitIdToTeamRoleData[portraitIdOfTeam][
                        portraitIdToToggle
                    ];
            }
        }

        teamPortraitIdToPortraitIdToTeamRoleData[portraitIdOfTeam][
            portraitIdToToggle
        ].hasAssigned = !teamPortraitIdToPortraitIdToTeamRoleData[
            portraitIdOfTeam
        ][portraitIdToToggle].hasAssigned;

        teamPortraitIdToPortraitIdToTeamRoleData[portraitIdOfTeam][
            portraitIdToToggle
        ].hasAccepted = !teamPortraitIdToPortraitIdToTeamRoleData[
            portraitIdOfTeam
        ][portraitIdToToggle].hasAccepted;

        teamPortraitIdToPortraitIdToTeamRoleData[portraitIdOfTeam][
            portraitIdToToggle
        ].roleType = newRoleType;

        bool hasAssigned = teamPortraitIdToPortraitIdToTeamRoleData[
            portraitIdOfTeam
        ][portraitIdToToggle].hasAssigned;

        if (hasAssigned) {
            portraitIdToAmountOfSeats[portraitIdOfTeam] += 1;
        } else {
            portraitIdToAmountOfSeats[portraitIdOfTeam] -= 1;
        }

        _calculateAndSetTeamExpirationTimestamp(
            portraitIdOfTeam,
            portraitIdToAmountOfSeats[portraitIdOfTeam]
        );

        emit RoleToggled(
            portraitIdOfTeam,
            portraitIdToToggle,
            newRoleType,
            teamPortraitIdToPortraitIdToTeamRoleData[portraitIdOfTeam][
                portraitIdToToggle
            ].hasAssigned,
            teamPortraitIdToPortraitIdToTeamRoleData[portraitIdOfTeam][
                portraitIdToToggle
            ].hasAccepted
        );

        return
            teamPortraitIdToPortraitIdToTeamRoleData[portraitIdOfTeam][
                portraitIdToToggle
            ];
    }

    /**
     * @inheritdoc IPortraitPlanRegistry
     */
    function toggleTeamRoleRequest(
        uint256 portraitIdWithRoleAssigned,
        uint256 portraitIdOfTeam
    ) external whenNotPaused returns (TeamRoleData memory _teamRoleData) {
        if (
            !portraitAccessRegistry.isDelegateOrOwnerOfPortraitId(
                portraitIdWithRoleAssigned,
                msg.sender
            )
        ) revert Unauthorized();

        return
            _toggleTeamRoleRequest(
                portraitIdWithRoleAssigned,
                portraitIdOfTeam
            );
    }

    /**
     * @inheritdoc IPortraitPlanRegistry
     */
    function toggleTeamRoleRequestArray(
        uint256 portraitIdWithRoleAssigned,
        uint256 portraitIdOfTeam,
        uint256[] calldata portraitIdsToToggle
    ) external {
        uint256 length = portraitIdsToToggle.length;

        for (uint256 i = 0; i < length; i++) {
            _toggleTeamRoleRequest(
                portraitIdWithRoleAssigned,
                portraitIdOfTeam
            );
        }
    }

    function _toggleTeamRoleRequest(
        uint256 portraitIdWithRoleAssigned,
        uint256 portraitIdOfTeam
    ) internal returns (TeamRoleData memory _teamRoleData) {
        if (!_isTeamPlan(portraitIdOfTeam)) revert InvalidPlan();

        // Must be assigned a role to accept a role
        if (
            teamPortraitIdToPortraitIdToTeamRoleData[portraitIdOfTeam][
                portraitIdWithRoleAssigned
            ].hasAssigned
        ) revert InvalidAction();

        teamPortraitIdToPortraitIdToTeamRoleData[portraitIdOfTeam][
            portraitIdWithRoleAssigned
        ].hasAccepted = !teamPortraitIdToPortraitIdToTeamRoleData[
            portraitIdOfTeam
        ][portraitIdWithRoleAssigned].hasAccepted;

        emit RoleToggled(
            portraitIdOfTeam,
            portraitIdWithRoleAssigned,
            teamPortraitIdToPortraitIdToTeamRoleData[portraitIdOfTeam][
                portraitIdWithRoleAssigned
            ].roleType,
            teamPortraitIdToPortraitIdToTeamRoleData[portraitIdOfTeam][
                portraitIdWithRoleAssigned
            ].hasAssigned,
            teamPortraitIdToPortraitIdToTeamRoleData[portraitIdOfTeam][
                portraitIdWithRoleAssigned
            ].hasAccepted
        );

        return
            teamPortraitIdToPortraitIdToTeamRoleData[portraitIdOfTeam][
                portraitIdWithRoleAssigned
            ];
    }

    /*//////////////////////////////////////////////////////////////
                         PLAN TYPE HELPERS
    //////////////////////////////////////////////////////////////*/

    function _setPlanType(
        uint256 portraitId,
        PlanType planType,
        uint256 weiAmount
    ) internal nonReentrant {
        PlanType currentPlan = _getPlanType(portraitId);

        if (planType == PlanType.IndividualFree) {
            _setPlanToIndividualFree(portraitId);
            emit PlanTypeSet(
                portraitId,
                planType,
                portraitIdToPlanData[portraitId].expirationTimestamp
            );
            return;
        }

        if (planType == PlanType.IndividualPlus) {
            _setPlanToIndividualPlus(portraitId, currentPlan, weiAmount);
            emit PlanTypeSet(
                portraitId,
                planType,
                portraitIdToPlanData[portraitId].expirationTimestamp
            );
            return;
        }

        if (planType == PlanType.Team) {
            _setPlanToTeam(portraitId, currentPlan, weiAmount);
            emit PlanTypeSet(
                portraitId,
                planType,
                portraitIdToPlanData[portraitId].expirationTimestamp
            );
            return;
        }
    }

    function getTeamPortraitIdToPortraitIdToTeamRoleData(
        uint256 portraitIdOfTeam,
        uint256 portraitIdWithPotentialRole
    ) external view returns (TeamRoleData memory) {
        return
            teamPortraitIdToPortraitIdToTeamRoleData[portraitIdOfTeam][
                portraitIdWithPotentialRole
            ];
    }

    function _calculateAndSetTeamExpirationTimestamp(
        uint256 portraitId,
        uint256 newAmountOfSeats
    ) internal {
        // if (newAmountOfSeats < 1) revert InvalidAction();

        uint256 currentExpirationTimestamp = portraitIdToPlanData[portraitId]
            .expirationTimestamp;

        uint256 currentAmountOfSeats = portraitIdToAmountOfSeats[portraitId];

        uint256 timeleft = currentExpirationTimestamp - block.timestamp;

        if (timeleft == 0) revert InvalidAction();

        uint256 currentSeatsPrice = currentAmountOfSeats * teamSeatPrice;

        uint256 hundredPercent = currentSeatsPrice + teamPrice;

        uint256 teamPricePercent = (teamPrice * 100) / hundredPercent;

        uint256 expirationTimestampTeamPrice = (timeleft * teamPricePercent) /
            100;

        uint256 expirationTimestampWithoutTeamPrice = timeleft -
            expirationTimestampTeamPrice;

        uint256 expirationTimestampPerSeat = expirationTimestampWithoutTeamPrice /
                currentAmountOfSeats;

        uint256 expirationTimestampNewSeats = expirationTimestampPerSeat *
            newAmountOfSeats;

        uint256 newExpirationTimestamp = block.timestamp +
            expirationTimestampNewSeats +
            expirationTimestampTeamPrice;

        portraitIdToPlanData[portraitId]
            .expirationTimestamp = newExpirationTimestamp;
    }

    /**
     * @notice Sets the plan type to IndividualFree
     * @dev If a user has a paid plan, the expiration timestamp will continue, even when the plan is set to IndividualFree.
     *      The CoOwner, Admin, Editor or TeamMembers, will not be removed.
     *
     */
    function _setPlanToIndividualFree(uint256 portraitId) internal {
        PlanType planType = PlanType.IndividualFree;
        portraitIdToPlanData[portraitId].planType = planType;
    }

    /**
     * @notice Sets the plan type to IndividualPlus
     * @dev If a user has a paid plan, the expiration timestamp will continue, even when the plan is set to IndividualFree.
     *      The CoOwner, Admin, Editor or TeamMembers, will not be removed.
     *
     */
    function _setPlanToIndividualPlus(
        uint256 portraitId,
        PlanType currentPlan,
        uint256 weiAmount
    ) internal {
        uint256 monthlyPrice = _getIndividualPlusPriceInWei();

        if (currentPlan == PlanType.Team) {
            // The function below converts the remaining funds to days and adds it to the expiration timestamp.
            bool hasConverted = _convertExpirationTimestampToIndividualPlusForActiveTeam(
                    portraitId
                );

            // If the conversion was successful, set the plan type to IndividualPlus. The expiration timestamp has already been updated.
            if (hasConverted) {
                portraitIdToPlanData[portraitId].planType = PlanType
                    .IndividualPlus;
            }

            // // If the user just wants to switch to the IndividualPlus plan, without extending the subscription, we can return here.
            if (weiAmount < monthlyPrice) {
                return;
            }
        }

        // A user must pay at least 1 month of IndividualPlus.
        if (weiAmount < monthlyPrice) revert InsufficientFunds();

        // We can set the plan type to IndividualPlus, as the user has paid at least 1 month.
        portraitIdToPlanData[portraitId].planType = PlanType.IndividualPlus;

        // A year is considered 11 months, as the 12th month is free.
        uint256 _years = (weiAmount / monthlyPrice) / 11;

        // If the Portrait already has an active IndividualPlus plan, and wants to extend the subscription, add to the expiration timestamp.
        if (
            portraitIdToPlanData[portraitId].expirationTimestamp >=
            block.timestamp
        ) {
            uint256 additionalDays = (weiAmount * oneMonth) / monthlyPrice; // Divide before multiply
            portraitIdToPlanData[portraitId].expirationTimestamp +=
                (_years * oneMonth) +
                additionalDays;
            return;
        }

        // If the Portrait is not already subscribed, set a new expiration timestamp.
        portraitIdToPlanData[portraitId].expirationTimestamp =
            block.timestamp +
            (_years * oneMonth) +
            ((weiAmount / monthlyPrice) * oneMonth);
    }

    function _convertExpirationTimestampToIndividualPlusForActiveTeam(
        uint256 portraitId
    ) internal returns (bool hasConverted) {
        uint256 monthlyPrice = _getIndividualPlusPriceInWei();
        uint256 timeLeft = portraitIdToPlanData[portraitId]
            .expirationTimestamp - block.timestamp;
        uint256 amountOfSeats = portraitIdToAmountOfSeats[portraitId];

        uint256 priceForSeats = (amountOfSeats == 0)
            ? 0
            : amountOfSeats * _getTeamSeatPriceInWei();
        uint256 monthlyTeamPrice = _getTeamPriceInWei() + priceForSeats;

        // Calculate the remaining funds in months by dividing the timeLeft in seconds by oneMonth.
        uint256 fundsRemainingInMonths = (timeLeft * monthlyTeamPrice) /
            (oneMonth);

        // Calculate the number of days left from the time remaining.
        uint256 daysLeft = timeLeft / (1 days);

        // Calculate the daily price for the subscription.
        uint256 dailyPrice = monthlyPrice / daysLeft;

        // Calculate the remaining days based on the funds remaining and daily price.
        uint256 convertedDays = (fundsRemainingInMonths * (oneMonth)) /
            dailyPrice;

        // If convertedDays is not 0, update the expiration timestamp for the individual plus plan.
        if (convertedDays > 0) {
            portraitIdToPlanData[portraitId].expirationTimestamp =
                block.timestamp +
                convertedDays;
        }

        return convertedDays > 0;
    }

    function _setPlanToTeam(
        uint256 portraitId,
        PlanType currentPlan,
        uint256 weiAmount
    ) internal {
        // Calculate the total cost for the subscription
        uint256 monthlyPrice = _getTeamPriceInWei();
        uint256 amountOfSeats = portraitIdToAmountOfSeats[portraitId];
        uint256 monthlyPriceForSeats = amountOfSeats * _getTeamSeatPriceInWei();

        if (currentPlan == PlanType.IndividualPlus) {
            // The function below converts the remaining funds to days and adds it to the expiration timestamp.
            bool hasConverted = _convertExpirationTimestampToTeamForActiveIndividualPlus(
                    portraitId
                );

            // If the conversion was successful, set the plan type to Team. The expiration timestamp has already been updated.
            if (hasConverted) {
                portraitIdToPlanData[portraitId].planType = PlanType.Team;
            }

            // If the user just wants to switch to the Team plan, without extending the subscription, we can return here.
            if (weiAmount < (monthlyPrice + monthlyPriceForSeats)) {
                return;
            }
        }

        // A minimum of 1 month is required to subscribe to the Team plan.
        if (weiAmount < (monthlyPrice + monthlyPriceForSeats))
            revert InsufficientFunds();

        // We can set the plan type to Team, as the user has paid at least 1 month.
        portraitIdToPlanData[portraitId].planType = PlanType.Team;

        // A year is considered 11 months, as the 12th month is free.
        uint256 _years = (weiAmount / monthlyPrice) / 11;

        // If the Portrait already has an active Team plan, and wants to extend the subscription, add to the expiration timestamp.
        if (
            portraitIdToPlanData[portraitId].expirationTimestamp >=
            block.timestamp
        ) {
            uint256 additionalDays = (weiAmount * oneMonth) / monthlyPrice; // Divide before multiply
            portraitIdToPlanData[portraitId].expirationTimestamp +=
                (_years * oneMonth) +
                additionalDays;
            return;
        }

        // If the Portrait is not already subscribed, set a new expiration timestamp.
        portraitIdToPlanData[portraitId].expirationTimestamp =
            block.timestamp +
            (_years * oneMonth) +
            ((weiAmount / monthlyPrice) * oneMonth);
    }

    function _convertExpirationTimestampToTeamForActiveIndividualPlus(
        uint256 portraitId
    ) internal returns (bool hasConverted) {
        uint256 monthlyPrice = _getIndividualPlusPriceInWei();
        uint256 timeLeft = portraitIdToPlanData[portraitId]
            .expirationTimestamp - block.timestamp;
        uint256 amountOfSeats = portraitIdToAmountOfSeats[portraitId];

        uint256 priceForSeats = (amountOfSeats == 0)
            ? 0
            : amountOfSeats * _getTeamSeatPriceInWei();

        uint256 monthlyTeamPrice = _getTeamPriceInWei() + priceForSeats;

        // Calculate the remaining funds in months by dividing the timeLeft in seconds by oneMonth.
        uint256 fundsRemainingInMonths = (timeLeft * monthlyPrice) / (oneMonth);

        // Calculate the number of days left from the time remaining.
        uint256 daysLeft = timeLeft / (1 days);

        // Calculate the daily price for the subscription.
        uint256 dailyPrice = monthlyTeamPrice / daysLeft;

        // Calculate the remaining days based on the funds remaining and daily price.
        uint256 convertedDays = (fundsRemainingInMonths * (oneMonth)) /
            dailyPrice;

        // If convertedDays is not 0, update the expiration timestamp for the individual plus plan.
        if (convertedDays > 0) {
            portraitIdToPlanData[portraitId].expirationTimestamp =
                block.timestamp +
                convertedDays;
        }

        return convertedDays > 0;
    }

    /*//////////////////////////////////////////////////////////////
                         VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IPortraitPlanRegistry
     */
    function getPlanType(uint256 portraitId) external view returns (PlanType) {
        return _getPlanType(portraitId);
    }

    function _getPlanType(uint256 portraitId) internal view returns (PlanType) {
        // If owner is not set, return defaultPlanType
        if (portraitIdRegistry.portraitIdToOwner(portraitId) == address(0))
            revert NoTeamRole();

        // If plan is expired, return defaultPlanType
        if (
            portraitIdToPlanData[portraitId].expirationTimestamp <
            block.timestamp
        ) return PlanType.IndividualFree;

        return portraitIdToPlanData[portraitId].planType;
    }

    /**
     * @inheritdoc IPortraitPlanRegistry
     */
    function isTeamPlan(
        uint256 portraitId
    ) external view returns (bool isTeam) {
        return _isTeamPlan(portraitId);
    }

    function _isTeamPlan(
        uint256 portraitId
    ) internal view returns (bool isTeam) {
        return _getPlanType(portraitId) == PlanType.Team;
    }

    /**
     * @inheritdoc IPortraitPlanRegistry
     */
    function getTeamRoleForPortraitId(
        uint256 portraitIdWithPotentialRole,
        uint256 portraitIdOfTeam
    ) external view returns (TeamRoleType role) {
        return
            _getTeamRoleForPortraitId(
                portraitIdWithPotentialRole,
                portraitIdOfTeam
            );
    }

    function _getTeamRoleForPortraitId(
        uint256 portraitIdWithPotentialRole,
        uint256 portraitIdOfTeam
    ) internal view returns (TeamRoleType role) {
        if (!_isTeamPlan(portraitIdOfTeam)) revert InvalidPlan();

        if (portraitIdWithPotentialRole == portraitIdOfTeam)
            return TeamRoleType.Owner;

        bool hasAssigned = teamPortraitIdToPortraitIdToTeamRoleData[
            portraitIdOfTeam
        ][portraitIdWithPotentialRole].hasAssigned;

        if (!hasAssigned) revert NoTeamRole();

        bool hasAccepted = teamPortraitIdToPortraitIdToTeamRoleData[
            portraitIdOfTeam
        ][portraitIdWithPotentialRole].hasAccepted;

        if (!hasAccepted) revert NoTeamRole();

        return
            teamPortraitIdToPortraitIdToTeamRoleData[portraitIdOfTeam][
                portraitIdWithPotentialRole
            ].roleType;
    }

    /**
     * @inheritdoc IPortraitPlanRegistry
     */
    function hasTeamRole(
        uint256 portraitIdWithPotentialRole,
        uint256 portraitIdOfTeam,
        TeamRoleType roleType
    ) external view returns (bool) {
        return
            _hasTeamRole(
                portraitIdWithPotentialRole,
                portraitIdOfTeam,
                roleType
            );
    }

    function _hasTeamRole(
        uint256 portraitIdWithPotentialRole,
        uint256 portraitIdOfTeam,
        TeamRoleType roleType
    ) internal view returns (bool) {
        return
            _getTeamRoleForPortraitId(
                portraitIdWithPotentialRole,
                portraitIdOfTeam
            ) == roleType;
    }

    /**
     * @inheritdoc IPortraitPlanRegistry
     */
    function getIndividualPlusPriceInWei() external view returns (uint256) {
        return _getIndividualPlusPriceInWei();
    }

    function _getIndividualPlusPriceInWei() internal view returns (uint256) {
        return
            (individualPlusPrice * 10 ** 18) /
            uint256(getChainlinkDataFeedLatestAnswer());
    }

    /**
     * @inheritdoc IPortraitPlanRegistry
     */
    function getTeamPriceInWei() external view returns (uint256) {
        return _getTeamPriceInWei();
    }

    function _getTeamPriceInWei() internal view returns (uint256) {
        return
            (teamPrice * 10 ** 18) /
            uint256(getChainlinkDataFeedLatestAnswer());
    }

    /**
     * @inheritdoc IPortraitPlanRegistry
     */
    function getTeamSeatPriceInWei() external view returns (uint256) {
        return _getTeamSeatPriceInWei();
    }

    function _getTeamSeatPriceInWei() internal view returns (uint256) {
        return
            (teamSeatPrice * 10 ** 18) /
            uint256(getChainlinkDataFeedLatestAnswer());
    }

    /**
     * @inheritdoc IPortraitPlanRegistry
     */
    function getPlanDataForPortraitId(
        uint256 portraitId
    ) external view returns (PlanData memory planData) {
        return portraitIdToPlanData[portraitId];
    }

    /*//////////////////////////////////////////////////////////////
                         PERMISSIONED ACTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IPortraitPlanRegistry
     */
    function setPlanType(
        uint256 portraitId,
        PlanType planType,
        address caller,
        uint256 weiAmount
    ) external {
        if (msg.sender != bridgeServiceAddress) revert Unauthorized();

        if (weiAmount == 0) revert InsufficientFunds();

        if (caller == address(0)) revert InvalidAddress();

        PlanType currentPlanType = _getPlanType(portraitId);

        // Anyone may extend the subscription.
        if (currentPlanType != planType) {
            if (
                !portraitAccessRegistry.isDelegateOrOwnerOfPortraitId(
                    portraitId,
                    caller
                )
            ) revert Unauthorized();
        }

        _setPlanType(portraitId, planType, weiAmount);
    }

    /**
     * @inheritdoc IPortraitPlanRegistry
     */
    function setIndividualPlusPrice(
        uint256 newIndividualPlusPrice
    ) external onlyOwner {
        individualPlusPrice = newIndividualPlusPrice;

        emit IndividualPlusPriceUpdated(
            block.timestamp,
            newIndividualPlusPrice
        );
    }

    /**
     * @inheritdoc IPortraitPlanRegistry
     */
    function setTeamPrice(uint256 newTeamPrice) external onlyOwner {
        teamPrice = newTeamPrice;

        emit TeamPriceUpdated(block.timestamp, newTeamPrice);
    }

    /**
     * @inheritdoc IPortraitPlanRegistry
     */
    function setTeamSeatPrice(uint256 newTeamSeatPrice) external onlyOwner {
        teamSeatPrice = newTeamSeatPrice;

        emit TeamSeatPriceUpdated(block.timestamp, newTeamSeatPrice);
    }

    /**
     * @inheritdoc IPortraitPlanRegistry
     */
    function setBridgeServiceAddress(
        address newBridgeServiceAddress
    ) external onlyOwner {
        if (newBridgeServiceAddress == address(0)) revert InvalidAddress();

        bridgeServiceAddress = newBridgeServiceAddress;
    }

    /**
     * @inheritdoc IPortraitPlanRegistry
     */
    function sendFunds(
        address payable recipient,
        uint256 amount
    ) external onlyOwner {
        if (recipient == address(0)) revert InvalidAddress();

        recipient.transfer(amount);
    }

    /**
     * @inheritdoc IPortraitPlanRegistry
     */
    function setChainlinkDataFeed(address newDataFeed) external onlyOwner {
        dataFeed = AggregatorV3Interface(newDataFeed);
    }

    /*//////////////////////////////////////////////////////////////
                            PROTOCOL HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IPortraitPlanRegistry
     */
    function updateProtocolContracts() external {
        portraitIdRegistry = portraitContractRegistry.portraitIdRegistry();
        portraitAccessRegistry = portraitContractRegistry
            .portraitAccessRegistry();
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

        bridgeServiceAddress = initialOwner;

        __Pausable_init();
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

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
                portraitSigValidator = PortraitSigValidator(
                    portraitContractRegistry.portraitSigValidator()
                );
            }
        }

        /**
         * @Network: OP Mainnet
         * Aggregator: OP / USD
         * Address: 0x0D276FC14719f9292D5C1eA2198673d1f4269246
         */
        dataFeed = AggregatorV3Interface(
            0x0D276FC14719f9292D5C1eA2198673d1f4269246
        );

        individualPlusPrice = 5;
        teamPrice = 20;
        teamSeatPrice = 2;
        oneMonth = 52 weeks / 12;

        pause();
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

    /*//////////////////////////////////////////////////////////////
                                CHAINLINK
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Returns the latest answer, which is the price of 1 token in USD, with 8 decimals.
     * @dev This is the price of 1 token in USD, with 8 decimals.
     *      This function is not declared in the interface, because of upgradeability purposes.
     *
     *      This function is used to calculate the price of the IndividualPlus, Team, and TeamSeat plans.
     *
     *      The datafeed contract is set in the initialize function.
     *
     *      For more information about the Chainlink data feed, see: https://docs.chain.link/data-feeds/price-feeds/
     *
     * @return price The latest answer, which is the price of 1 token in USD, with 8 decimals.
     */
    function getChainlinkDataFeedLatestAnswer()
        public
        view
        returns (int price)
    {
        // prettier-ignore
        (
        /* uint80 roundID */,
        int answer,
        /*uint startedAt*/,
        /*uint timeStamp*/,
        /*uint80 answeredInRound*/
    ) = dataFeed.latestRoundData();
        price = answer; // Store the answer in the price variable
        return price; // Return the stored price
    }
}
